# Critical Analysis: Expression Library

*A review of the architecture, design trade-offs, and production realities*

---

## Executive Summary

Expression is a ~5,000-line Elixir library implementing an Excel-like expression language for FLOIP. It works. It's in production. But it has accumulated structural debt that manifests not in the library itself, but in its consumers — engage wraps every `evaluate_*` call in `try/rescue`, maintains a dedicated `PublicExceptions` module to translate Expression crashes into user-facing messages, and has built a parallel validation pipeline using V2's parser to compensate for V1's lack of static analysis capabilities.

The core issues are:

1. **Three error channels** — exceptions, `{:error, _}` tuples, and error maps — with no consistent contract
2. **Implicit type coercion** at every layer — context, evaluation, and callbacks — making behavior unpredictable
3. **A 4,000-line callbacks module** that mixes pure functions with side-effect-prone operations under identical dispatch
4. **An abandoned V2 that solved the right problems** (compilation to Elixir AST, structured contexts, better error handling) but whose compatibility layer is now dead code returning V1 results
5. **No private state separation** — callbacks access sensitive data (UUIDs, tokens, database records) from the same map that user-authored expressions can read via `@variable` syntax

**Constraint on all recommendations:** This library is in production. Backwards compatibility is non-negotiable. Every proposed change follows the pattern: add the new way alongside the old, deprecate the old with warnings and migration guidance, remove only in a future major version after consumers have migrated. No flag days, no silent behavior changes, no "just update your code."

---

## 1. The Parser: Solid Foundation, Wrong Abstraction Level

The NimbleParsec-based parser (`lib/expression/parser.ex`, 264 lines) is one of the stronger parts of the codebase. The combinator approach is idiomatic, the operator precedence via `fold_infixl/1` works correctly, and the distinction between `@(...)` blocks (full expressions) and `@var` shorthand (no spaces/arithmetic) is a pragmatic design choice for template safety.

**What works well:**
- Clean separation of `aexpr` -> `aexpr_term` -> `aexpr_exponent` -> `aexpr_factor` for precedence
- The `attribute_or_key_with_primitives_only` guard preventing `info@support.com for` from being parsed as an expression
- Escaped `@@` handling via lookahead

**The problem is the AST format.** Keyword lists were a reasonable prototype choice but they create ambiguity:

```elixir
# This is both a valid AST node AND a valid Elixir keyword list
[name: "sum", args: [literal: 1, literal: 2]]

# And this nesting is hard to pattern match reliably
{:attribute, [{:attribute, {:atom, "foo"}}, {:literal, "bar"}]}
```

V2 moved to `{"sum", [arg1, arg2]}` tuples — a better choice because it's unambiguous and aligns with how Elixir's own AST works (`{function, meta, args}`). The engage codebase proves this matters: `ElasticsearchConverter.format/2` has to pattern match on deeply nested keyword lists, and every new function support requires a new clause that knows the exact V1 AST shape.

**Missing:** The parser has no error recovery. A single malformed character causes the entire expression to fail. For a user-facing template language, partial parsing with error markers (like Elixir's own parser does) would be far more useful than "Unable to parse block: ...".

---

## 2. The Evaluator: Where Type Safety Goes to Die

`Expression.Eval` (`lib/expression/eval.ex`, 341 lines) is the heart of the system, and it has fundamental design issues.

### 2.1 The Binary Literal Recursion Bomb

Line 115-117:
```elixir
def eval!({:literal, literal}, context, mod) when is_binary(literal) do
  Expression.evaluate_as_string!(literal, context, mod)
end
```

This means **every string literal is re-parsed as an expression**. If a user writes `"hello @world"` as a literal inside an expression, it gets recursively evaluated. This is not documented behavior — it's an implicit feature that makes reasoning about evaluation order impossible.

In engage, `Build.Callbacks` relies on this for nested template resolution, but it means:
- You cannot have a literal string containing `@` without it being treated as a variable reference
- Error messages from inner evaluations bubble up as strings, not structured errors
- Stack depth is unbounded for pathological inputs

### 2.2 The `{:not_found, path}` Sentinel

When a variable lookup fails, the evaluator returns `{:not_found, [atom]}` (line 47). This tuple then propagates through the entire evaluation tree:

```elixir
# Line 43-44: not_found chains through attribute access
def eval!({:atom, atom}, {:not_found, history}, _mod),
  do: {:not_found, history ++ [atom]}
```

This is a sentinel value masquerading as a type. It's not `nil`, it's not an error tuple, it's not an exception — it's a special value that some code handles and other code doesn't. `default_value/2` (line 302-312) converts it to either `nil` or `"@path.to.var"` depending on a flag. The `not_founds_as_nil/1` helper converts it in list contexts. `guard_type!/2` raises on it in numeric contexts.

The engage codebase deals with this by always calling `evaluate_as_string!/3` (which calls `default_value(handle_not_found: true)`) rather than `evaluate!/3`, because the alternative is having `{:not_found, [...]}` tuples leak into user-visible output.

### 2.3 Operator Dispatch: A Combinatorial Explosion

The `op/3` function (lines 159-271) has **17 clauses** handling every combination of types for every operator. The ordering matters because guards overlap:

```elixir
# Line 159-165: numeric types -> apply Kernel operator
def op(operator, a, b) when operator in @numeric_kernel_operators and ...

# Line 167-201: DateTime structs -> Date/DateTime.compare
def op(:>, a, b) when is_struct(a, DateTime) ...

# Line 203-210: nil handling -> false for all comparisons
def op(operator, a, b) when ... and (is_nil(a) or is_nil(b)) ...

# Line 214-251: Date/DateTime vs string -> parse and compare
def op(operator, a, b) when ... and is_binary(b) ...

# Line 254-262: fallback -> parse_number then apply
def op(operator, a, b) when operator in @numeric_kernel_operators ...

# Line 265-272: final fallback -> parse_number for equality
def op(operator, a, b) when operator in @kernel_operators ...
```

This means `"5" > "3"` goes through `parse_number/1`, converts both to integers, then compares numerically. `"hello" > "goodbye"` also goes through `parse_number/1`, fails to convert, and falls through to `Kernel.>/2` for string comparison. Neither behavior is documented. Neither is what a user of an "Excel-like" language would expect.

### 2.4 The `=` vs `==` Ambiguity

The parser generates both `:=` and `:==` as operators. The evaluator handles both, but they have subtly different behavior for DateTime comparisons:

```elixir
# Line 182-183: = on DateTime uses Date.compare (!)
def op(:=, a, b) when is_struct(a, DateTime) and is_struct(b, DateTime),
  do: Date.compare(a, b) == :eq

# Line 179-180: == on DateTime uses DateTime.compare
def op(:==, a, b) when is_struct(a, DateTime) and is_struct(b, DateTime),
  do: DateTime.compare(a, b) == :eq
```

So `=` on two DateTimes compares only the date portion (via `Date.compare`), while `==` compares the full DateTime. This is almost certainly a bug that's become a feature. The FLOIP spec likely doesn't distinguish between `=` and `==`, but the implementation does in this one specific case.

---

## 3. Error Handling: Three Systems, No Contract

The library uses three incompatible error mechanisms:

### Channel 1: Exceptions (raise)

```elixir
# eval.ex:320 — guard_type! raises on missing attributes
defp guard_type!({:not_found, attributes}, :num),
  do: raise("attribute is not found: `#{Enum.join(attributes, ".")}`")

# expression.ex:74 — parse_expression! raises on bad input
raise "Unable to parse block: ..."
```

### Channel 2: Tagged tuples

```elixir
# callbacks.ex:59-60 — function dispatch returns {:error, reason}
{:error, reason} -> {:error, reason}

# expression.ex:116-118 — evaluate_block rescues into {:error, message}
rescue
  e in RuntimeError -> {:error, e.message}
```

### Channel 3: Error maps

```elixir
# expression.ex:178-184 — error/1 creates a magic map
def error(message),
  do: %{
    "__type__" => "expression/v1error",
    "error" => true,
    "message" => to_string(message),
    "__value__" => nil
  }
```

The error map is the most insidious because it's a regular map that flows through evaluation as a "value". The `__value__` key being `nil` means that when this error map reaches `default_value/2`, it returns `nil`. When it reaches `stringify/1`, it gets `inspect/1`'d into a string containing the raw map.

In engage, `triggers.ex:532-539` deals with this by wrapping every `evaluate_as_boolean!` in a `try/rescue` that returns `false` on any exception. The `PublicExceptions` module (line 66-71) has specific pattern matches for Expression's error shapes. This is the library pushing error handling responsibility entirely onto the consumer.

**What should exist:** A single error type. Either `{:error, %Expression.Error{type: :parse | :eval | :type, ...}}` or a protocol. The current situation means every consumer must independently discover and handle all three channels.

---

## 4. The Context Module: Helpful Until It Isn't

`Expression.Context.new/2` (89 lines) performs two implicit transformations on every context map: **key lowercasing** and **string value coercion**. Both have caused production issues.

### 4.1 Automatic Key Lowercasing

Every key in the context is lowercased via `downcase_string_key/1` (context.ex:46):

```elixir
defp downcase_string_key({key, value}), do: {String.downcase(to_string(key)), value}
```

This means `%{"firstName" => "Jane"}` becomes `%{"firstname" => "Jane"}`. The original casing is destroyed — there is no way to recover it.

This is a problem when:
- **External systems use case-sensitive keys** — contact schema fields, webhook payloads, and API responses often use camelCase or PascalCase. After `Context.new/2`, these keys are irrecoverably lowercased. If a callback needs to send data back to the source system with the original casing, the information is gone.
- **Key collisions** — `%{"Name" => "Alice", "name" => "Bob"}` silently collapses to `%{"name" => "Bob"}`. The first value is dropped with no warning. In engage, contact schema fields are customer-defined — collisions from different casing are entirely possible.
- **Nested maps are also lowercased** — the recursive `evaluate!/2` call on map values means the entire context tree is flattened to lowercase, including deeply nested structures from API responses or JSON payloads that may need to preserve their original shape.

The FLOIP spec says expressions are case-insensitive (`CONTACT.NAME` equals `contact.name`), but this should be handled at **lookup time** (case-insensitive matching), not at **storage time** (destructive lowercasing). The parser already lowercases variable names in the AST (`atom` combinator uses `String.downcase`), so lookups against a case-preserving context would still work — the context doesn't need to be mutated.

### 4.2 Automatic String Value Coercion

String values are parsed as literals via the Expression parser (context.ex:75-85):

```elixir
defp evaluate!(binary, _) when is_binary(binary) do
  case Expression.Parser.literal(binary) do
    {:ok, [{:literal, literal}], "", _, _, _} -> literal
    ...
  end
end
```

This means `%{date: "2020-12-13T23:34:45"}` becomes `%{"date" => ~U[2020-12-13 23:34:45.0Z]}`. Convenient — until your context contains a string like `"2023"` which becomes the integer `2023`, or `"true"` which becomes `true`.

The special case at line 53 is telling:

```elixir
# Implictly convert the string "0" as a number
defp iterate({key, "0"}, _opts), do: {key, 0}
```

This exists because the general rule at line 57-59 prevents strings starting with `"0"` from being parsed as numbers (to protect phone numbers and zero-padded codes), but `"0"` itself needs to be numeric. This is exactly the kind of edge case that accumulates when implicit coercion is the default.

The engage codebase has a documented workaround for this in `channels.ex`:

> *"the Expression library's parse_json coerces numeric strings to integers/floats. Meta's WhatsApp Flows API expects all values as strings."*

The `skip_context_evaluation?` option exists to disable string coercion, but it's all-or-nothing — you can't selectively preserve types for some keys. And it does **not** disable key lowercasing — there is no way to opt out of that.

---

## 5. The Callbacks Module: 4,000 Lines of Implicit Contracts

`Expression.Callbacks.Standard` at 4,069 lines is the largest module in the library. It implements 80+ functions across string manipulation, date arithmetic, collection operations, numeric functions, and logical operators.

### 5.1 The `String.to_atom/1` Problem

`callbacks.ex:36-38`:
```elixir
def atom_function_name(function_name) do
  String.to_atom(function_name)
end
```

Every function call in every expression creates an atom from user input. Atoms are not garbage collected. In a system processing user-authored templates at scale (which is exactly what engage does), this is a memory leak waiting to happen. The BEAM has a default limit of ~1M atoms; after that, the VM crashes.

In practice, the set of function names is bounded by what's implemented, but the `String.to_atom/1` call happens *before* the check whether the function exists — meaning invalid function names also create atoms.

This should use `String.to_existing_atom/1` with a fallback, or pre-register the valid function names.

### 5.2 The `eval!` Helper in Callbacks

The `EvalHelpers` module provides an `eval!/2` macro used extensively in callbacks:

```elixir
def count(ctx, term) do
  case eval!(term, ctx) do
    list when is_list(list) -> length(list)
    ...
  end
end
```

This means callbacks are re-evaluating their arguments. The evaluator already evaluated the arguments in `Eval.eval!/3` via `args_reducer/5`, but the callbacks need to unwrap the `[literal: value]` tuples. This double-evaluation is wasteful and error-prone — a callback author must understand the AST wrapper format, not just the values.

### 5.3 The `__value__` Protocol

Complex values are maps with a `__value__` key that acts as a default representation. This is checked in:
- `Eval.parse_number/1` (line 278)
- `Eval.default_value/2` (line 303)
- Dozens of callback functions

It's an ad-hoc protocol without the benefits of an actual Elixir protocol. If this used `Access` or a dedicated behaviour, the dispatch would be formalized and extensible.

---

## 6. V2: The Right Ideas, Abandoned Too Early

V2's key innovation was **compiling to Elixir AST** rather than interpreting:

```elixir
# v2/compile.ex — to_quoted converts Expression AST to Elixir quoted form
def to_quoted(ast) -> Elixir AST -> fn context -> result end
```

This approach:
- Enables Elixir's own optimizations on the generated code
- Makes type information available at compile time
- Produces functions that can be cached and reused
- Allows `Macro.traverse/4` for static analysis (which engage actually uses for validation)

The engage validation system (`validation.ex:840-873`) uses `Expression.V2.parse_block/1` and `Compile.to_quoted/1` to walk the AST and validate function calls against registered callbacks — **at definition time, not evaluation time**. This is exactly the kind of static analysis V1 cannot support.

**What V2 got right:**
- Structured `%Expression.V2.Context{}` instead of a raw map
- Compilation to Elixir AST enabling analysis and optimization
- Cleaner AST format (`{"function", [args]}` instead of keyword lists)

**What killed V2:**
- The compatibility layer (`compat.ex`) ran both V1 and V2 and compared results — doubling the work
- String comparison used Jaro distance >0.9 as "equal enough", which is nonsensical for an expression evaluator
- Known incompatibilities (`rand_between`, `@if`, `@left`) were hacked around with string matching
- The effort required to achieve 100% compatibility with V1's undocumented edge cases was prohibitive

The compat module is now dead code — every function returns V1's result with V2 code commented out. But it's still `alias`'d and called from engage's codebase, adding indirection for no benefit.

---

## 7. How Engage Compensates

The engage codebase reveals exactly where the library falls short, because it's built workarounds for each gap:

### 7.1 The FLOIP Transpiler

`DSL.Parser.convert_to_expression/1` is a remarkable piece of code that converts Elixir `and`/`or`/`not` operators into FLOIP function calls. It does this by:

1. Parsing Elixir code to AST via `Code.string_to_quoted`
2. Walking the AST to rename `:and` -> `:_and`, `:or` -> `:_or` (because `and`/`or` are special forms)
3. Converting to algebra document via `Code.quoted_to_algebra`
4. Rewriting the algebra document to swap `_and` back to `and`
5. Formatting to string

This is clever but fragile. The `rewrite_algebra/1` function had to be updated for Elixir 1.19 because the algebra document format changed from tuples to lists. Every Elixir version bump is a risk.

**The deeper question:** Why does the library require FLOIP syntax (`and(a, b)`) when the user-facing language allows `a and b`? The library should parse both. The transpilation step exists only because Expression's parser doesn't support infix `and`/`or`.

### 7.2 The Elasticsearch Converter

`ElasticsearchConverter.trigger_expression_to_es_query/1` takes an Expression V1 AST and converts it to Elasticsearch query strings. This works by pattern matching on the AST structure:

```elixir
def format(:function, [{:name, "and"}, {:args, [a, b]}]),
  do: "(#{format([a])} AND #{format([b])})"

def format(:==, [a, {:atom, "nil"}]),
  do: "(NOT _exists_:#{format([a])})"
```

This is an AST-to-AST transpilation that proves the Expression AST is being used as an intermediate representation, not just for evaluation. The library should formalize this use case — the AST format should be documented as a public API, not an implementation detail that consumers reverse-engineer.

### 7.3 Error Wrapping Everywhere

```elixir
# triggers.ex:532-539
Expression.evaluate_as_boolean!(expression, context, Build.Callbacks)
rescue
  exception ->
    Logger.error(Exception.format(:error, exception, __STACKTRACE__))
    false
```

```elixir
# lua_app/api/expression.ex:55-69
try do
  result = Expression.evaluate_as_string!(expression, ctx, Callbacks)
  Lua.encode_list!(state, [result, true])
rescue
  e -> Lua.encode_list!(state, [Exception.message(e), false])
end
```

Every single call site wraps Expression in `try/rescue`. This is the library saying "I might crash, deal with it" instead of "here's a structured result you can handle".

---

## 8. The Private State Problem

Expression callbacks frequently need access to trusted, internal state — database records, API tokens, internal UUIDs — that must not be readable or writable from user-authored expressions. The library has no concept of this separation. The entire context is a flat map, and callbacks receive the same map that `@variable` lookups resolve against.

### 8.1 How It Manifests in Engage

In engage, `Build.default_context/1` constructs the evaluation context by merging user-visible data with internal operational data into a single map:

```elixir
# build.ex:2388-2398
"contact" => Map.put_new(contact.details, "uuid", contact.uuid),
"number" => %{
  "uuid" => number.uuid,
  "from_addr" => number.from_addr,
  ...
},
"chat" => %{
  "uuid" => chat.uuid,
  "owner" => chat.owner,
  ...
}
```

Callbacks then extract sensitive data from this same map:

```elixir
# callbacks.ex:178-190 — generate_ott needs number UUID and contact whatsapp_id
def generate_ott(ctx, data) do
  with %{"number" => %{"uuid" => number_uuid},
         "contact" => %{"whatsapp_id" => whatsapp_id}} <- ctx,
       {:ok, number} <- Organisations.get_number_by_uuid(number_uuid),
       ...
```

```elixir
# callbacks.ex:1236-1247 — attachment_url needs number UUID for authorization
def attachment_url(ctx, media_id, ttl) do
  with %{"number" => %{"uuid" => number_uuid}} <- ctx,
       {:ok, number} <- Organisations.get_number_by_uuid(number_uuid),
       ...
```

The consequence: an expression author can write `@number.uuid` or `@contact.uuid` and extract internal database identifiers. The `privileged_context/1` function (build.ex:2262-2303) attempts to address this for API tokens by keeping them in a separate map that's only merged in for webhook blocks:

```elixir
@doc """
Generate the Expression evaluation context for a privileged execution.
This context gives access to information that one would not want accessible
in blocks that are able to generate output which could be sent to users so
as to prevent accidental leaking of these tokens via a WhatsApp message interaction
"""
```

But this is a manual, caller-side discipline — not a library-enforced boundary. The Expression library itself has no concept of "this data is for callbacks only, not for variable resolution."

### 8.2 What the Lua Package Does Right

The [Lua](https://hexdocs.pm/lua/Lua.html) Elixir package solves this problem architecturally with a clean separation between user-visible state and callback-private state:

**Private state storage:**
```elixir
# Setup phase — before any user code runs
lua =
  lua
  |> Lua.put_private(:number, number)
  |> Lua.put_private(:app_definition, app_definition)
  |> Lua.put_private(:app_install, app_install)
```

**Callback access:**
```elixir
# Inside a deflua function — Elixir code, not Lua
deflua request(req), state do
  number = Lua.get_private!(state, :number)
  # ... use number to build authenticated HTTP client
  # Lua script never sees :number — only the response
end
```

**The key architectural decision:** Private data is stored in the underlying Luerl VM state structure, not in any Lua table. User scripts have no API, no syntax, no mechanism to reach it. Only Elixir `deflua` functions receive the full state and can call `Lua.get_private!/2`. The isolation is structural, not conventional.

This gives three properties Expression lacks:

1. **Storage isolation** — private data lives in a separate namespace, not mixed into the variable resolution map
2. **Access isolation** — only callback code (Elixir) can read private state; user expressions cannot
3. **Selective exposure** — callbacks decide what to return; the user only sees return values, never internal state

### 8.3 The Sigil: Compile-Time Validation

Lua provides a `~LUA` sigil that validates syntax at compile time:

```elixir
defmacro sigil_LUA(code, opts) do
  chunk = case :luerl_comp.string(code, [:return]) do
    {:ok, chunk} -> %Lua.Chunk{instructions: chunk}
    {:error, error, _warnings} -> raise Lua.CompilerException, error
  end

  case opts do
    [?c] -> Macro.escape(chunk)  # Pre-compiled, no runtime parse cost
    _    -> code                  # Validated string, parsed at runtime
  end
end
```

Two modes:
- `~LUA"code"` — validates syntax at compile time, returns the string for runtime parsing
- `~LUA"code"c` — pre-compiles to a `%Lua.Chunk{}` struct, eliminating runtime parse overhead entirely

Expression has no equivalent. Every `Expression.parse!/1` call is a runtime operation. For expressions embedded in Elixir source (which is common in engage's DSL blocks and test fixtures), this is wasted work — the expression string is known at compile time, but parsing happens every time.

### 8.4 What Expression Should Adopt

**A. Private state on the context (structural, not conventional):**

The Expression context should have two distinct compartments:

```elixir
defmodule Expression.Context do
  defstruct [
    :vars,           # User-accessible: @contact.name resolves here
    :private,        # Callback-only: invisible to expressions
    :callback_module
  ]
end
```

Variable resolution (`@foo`) only looks in `vars`. Callbacks receive the full context struct and can access `ctx.private`.

**Backwards compatibility:** The critical constraint is that this must not break existing callers that pass a plain map as context. The evaluator should handle both:

```elixir
# New struct path — expressions only see vars
def eval!({:atom, atom}, %Expression.Context{vars: vars}, _mod),
  do: Map.get(vars, atom, {:not_found, [atom]})

# Legacy map path — existing behavior preserved exactly
def eval!({:atom, atom}, context, _mod) when is_map(context),
  do: Map.get(context, atom, {:not_found, [atom]})
```

`Context.new/2` should continue to return a plain map by default. A new `Context.new/3` or `Context.build/2` can return the struct when private state is needed. Existing callers passing `%{}` see zero change. Callers that want isolation opt in.

Similarly, callbacks must continue to work with plain map contexts. A callback that wants private state can pattern match on the struct, with a fallback for plain maps:

```elixir
# Works with both old and new callers
def generate_ott(%Expression.Context{private: %{number: number}} = ctx, data) do
  ...
end

def generate_ott(ctx, data) when is_map(ctx) do
  # Legacy path: extract from the flat map as before
  with %{"number" => %{"uuid" => number_uuid}} <- ctx, ...
end
```

Note: V2 already has `%Expression.V2.Context{vars: ..., private: ..., callback_module: ...}`. The design exists — it just was never adopted by V1.

**B. A `~EXPR` sigil for compile-time validation and pre-parsing:**

```elixir
defmacro sigil_EXPR(code, opts) do
  code = extract_literal(code)

  case Expression.parse_expression(code) do
    {:ok, ast} ->
      case opts do
        [?c] -> Macro.escape(ast)  # Pre-parsed AST, zero runtime cost
        _    -> code               # Validated string
      end

    {:error, reason} ->
      raise CompileError, description: "invalid expression: #{reason}"
  end
end
```

Usage:
```elixir
# Compile-time syntax validation
expr = ~EXPR"SUM(contact.age, 10)"

# Pre-parsed AST — no runtime parsing
ast = ~EXPR"SUM(contact.age, 10)"c

# Compile error if invalid
bad = ~EXPR"SUM(contact.age,"  # ** (CompileError) invalid expression: ...
```

This catches expression syntax errors during compilation rather than at runtime in production. For engage's DSL blocks, which define expressions in Elixir source, this would surface errors at build time instead of when a user triggers the flow.

---

## 9. Callback Ergonomics: Lessons from `deflua`

The Lua package's `deflua` macro provides a dramatically better developer experience for defining callback functions than Expression's current pattern. Understanding why reveals actionable improvements.

### 9.1 The Boilerplate Problem

Every Expression callback today requires the same manual ceremony:

```elixir
# Standard pattern — repeated in every single function
def chunk_every(ctx, enumerable, count) do
  [enumerable, count] = eval_args!([enumerable, count], ctx)  # <-- boilerplate
  # ... actual logic
end

def levenshtein_distance(ctx, first_phrase, second_phrase),
  do: Peach.levenshtein_distance(eval!(first_phrase, ctx), eval!(second_phrase, ctx))
  #                                ^^^^^^^^^^^^^^^^^^^       ^^^^^^^^^^^^^^^^^^^
  #                                boilerplate everywhere

def openai_add_image(ctx, connection, role, prompt, image_url, max_tokens) do
  [connection, role, prompt, image_url, max_tokens] =
    eval_args!([connection, role, prompt, image_url, max_tokens], ctx)  # <-- 5 args repeated
  # ... actual logic
end
```

This is not just tedious — it's a source of bugs. The `eval!` calls are scattered inconsistently:
- Some functions use `eval_args!` at the top (batch evaluation)
- Some inline `eval!` mid-pipeline
- Some embed `eval!` inside conditionals: `if phrase = eval!(phrase, ctx), do: ...`
- Some need `eval!(value, ctx, false)` to disable `__value__` unwrapping — a non-obvious opt-out

The Lua package solves this completely. A `deflua` function receives pre-decoded values:

```elixir
# Lua approach — no manual decoding
deflua encode(term, opts \\ nil), state do
  term = Lua.decode!(state, term)   # explicit decode when needed
  # ... actual logic
end
```

### 9.2 What `deflua` Does Right

The `deflua` macro (`deps/lua/lib/lua/api.ex:228-270`) provides:

**A. Automatic state parameter injection:**
```elixir
# deflua/3 — state parameter appended at compile time
deflua request(req), state do
  # `state` is available, injected by the macro
  number = Lua.get_private!(state, :number)
end

# deflua/2 — no state needed
deflua encode(data) do
  Jason.encode!(data)
end
```

The macro uses `Macro.prewalk` to append the state parameter to the function signature. The callback author doesn't write `def request(req, state)` — they write `deflua request(req), state` and the macro handles it.

**B. Compile-time function registration:**
```elixir
# Each deflua call accumulates into @lua_function
@lua_function validate_func!({name, with_state?, variadic?}, __MODULE__, @lua_function)

# @before_compile generates:
def __lua_functions__ do
  [{:request, true, false}, {:encode, false, false}, ...]
end
```

No runtime `function_exported?` checks. The module knows its own functions at compile time.

**C. Consistency validation:**
```elixir
# validate_func! ensures all clauses agree on state usage
validate_func!({name, state, variadic}, module, values)
# Raises CompileError if function has both state and no-state clauses
```

**D. Scoped namespacing:**
```elixir
use Lua.API, scope: "turn.http"

# Functions land in turn.http.* namespace
# Multiple modules compose into a single namespace hierarchy
```

**E. Variadic support via attribute:**
```elixir
@variadic true
deflua print_all(args), state do
  # args is a list of all arguments
end
# @variadic auto-resets for next function
```

### 9.3 A `defexpr` Macro for Expression

Expression should adopt the same pattern. A `defexpr` macro that eliminates the `eval!` boilerplate and provides compile-time registration:

```elixir
defmodule Expression.Callbacks.Standard do
  use Expression.Callbacks

  @expression_doc expression: "count([1, 2, 3])", result: 3
  defexpr count(list) do
    # `list` is already evaluated — no eval! call needed
    case list do
      list when is_list(list) -> length(list)
      binary when is_binary(binary) -> String.length(binary)
      map when is_map(map) -> Enum.count(map)
      nil -> 0
    end
  end

  @expression_doc expression: "chunk_every(sentences, 2)", result: [...]
  defexpr chunk_every(enumerable, count) do
    # Both args pre-evaluated
    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error("Invalid enumerable")
    else
      Enum.chunk_every(enumerable, count)
    end
  end
end
```

**With context access** (like `deflua/3` with state):

```elixir
defexpr generate_ott(data), ctx do
  # `data` is pre-evaluated
  # `ctx` is the full Expression.Context struct (with private state)
  with %{number: number} <- ctx.private,
       {:ok, token} <- Tokens.generate(number, data) do
    token.token
  end
end
```

**Without context** (pure functions):

```elixir
defexpr upper(text) do
  String.upcase(to_string(text))
end
```

### 9.4 What the Macro Should Do

The `defexpr` macro should:

1. **Auto-evaluate arguments** — wrap each argument with `eval!(arg, ctx)` at compile time, so the function body receives values, not AST nodes
2. **Inject context optionally** — `defexpr foo(a, b), ctx do` gives access to context; `defexpr foo(a, b) do` doesn't. Like `deflua/3` vs `deflua/2`
3. **Register functions at compile time** — accumulate `@expression_function` attributes, generate `__expression_functions__/0` in a `@before_compile` hook. No more runtime `function_exported?` checks
4. **Validate consistency** — ensure all clauses of a function agree on whether they use context (same as `validate_func!` in Lua)
5. **Preserve `@expression_doc` integration** — the autodoc system should work unchanged with `defexpr`
6. **Support guards** — `defexpr count(list) when is_list(list) do` should work

What the macro generates:

```elixir
# Input:
defexpr chunk_every(enumerable, count), ctx do
  Enum.chunk_every(enumerable, count)
end

# Generated:
@expression_function {:chunk_every, true, false}
def chunk_every(ctx, enumerable_ast, count_ast) do
  enumerable = eval!(enumerable_ast, ctx)
  count = eval!(count_ast, ctx)
  Enum.chunk_every(enumerable, count)
end
```

The generated code is identical to what callback authors write today — the macro is pure sugar. Existing handwritten callbacks continue to work alongside `defexpr` callbacks.

### 9.5 Stdlib and Custom Callbacks: Composition, Not Inheritance

The current dispatch chain in `Expression.Callbacks.implements/3` checks:

1. Custom module exact arity
2. Custom module vargs
3. Standard module exact arity
4. Standard module vargs

This implicit fallback is workable but has two problems:
- Callback authors don't know the ordering exists
- You can't compose multiple custom callback modules (it's one custom + Standard)

**The Lua approach** is different — `Lua.load_api/2` loads multiple modules as peers into a flat namespace. But Expression doesn't have namespacing (functions are flat like Excel), so this doesn't map directly.

**Proposed approach — explicit composition via `use` options:**

```elixir
defmodule MyApp.Callbacks do
  use Expression.Callbacks  # imports stdlib by default

  # Override a stdlib function
  defexpr now(), ctx do
    # custom implementation that respects timezone from private state
    ctx.private[:timezone]
    |> DateTime.now!()
  end

  # Add a new function
  defexpr lookup_user(email), ctx do
    MyApp.Users.find_by_email(email)
  end
end
```

The `use Expression.Callbacks` macro should:

1. **Import stdlib by default** — `use Expression.Callbacks` gives you all of `Standard` plus your own functions. Custom functions override stdlib on name collision. This is what happens today, just made explicit.

2. **Allow opting out of stdlib** — `use Expression.Callbacks, stdlib: false` for a module that defines only its own functions (useful for testing or specialized contexts).

3. **Allow composing multiple modules** — `use Expression.Callbacks, also: [MyApp.DateCallbacks, MyApp.AICallbacks]`. Dispatch checks each module in order. This replaces the current "one custom module + Standard" with "N modules in declared order + Standard".

**Backwards compatibility:** The existing `use Expression.Callbacks` continues to work unchanged. The `defdelegate handle/4` it generates still falls back to `Standard`. Modules that define callbacks with plain `def` continue to work — `defexpr` is additive. The compile-time registry (`__expression_functions__/0`) supplements the existing `function_exported?` checks; it doesn't replace them.

The migration path is:
1. Add `defexpr` macro alongside existing `def` pattern
2. New callbacks use `defexpr`; existing callbacks stay as `def` until someone touches them
3. The `also:` composition option is additive — existing single-module setups are unaffected

### 9.6 Comparison Table

| Aspect | Expression today | `deflua` in Lua | Proposed `defexpr` |
|--------|-----------------|-----------------|-------------------|
| **Arg evaluation** | Manual `eval!`/`eval_args!` every time | Manual `Lua.decode!` when needed | Auto-evaluated by macro |
| **Context/state** | Always passed as first arg, always a map | Opt-in via `deflua/3`, injected by macro | Opt-in via `defexpr/3`, injected by macro |
| **Registration** | Runtime `function_exported?` | Compile-time `__lua_functions__/0` | Compile-time `__expression_functions__/0` |
| **Consistency check** | None | `validate_func!` at compile time | Same pattern at compile time |
| **Reserved words** | `_` suffix convention | N/A (Lua has no reserved conflicts) | Handled by macro (transparent) |
| **Vargs** | `function_vargs/2` convention | `@variadic true` attribute | `@variadic true` attribute |
| **Namespacing** | Flat (single module) | Hierarchical (`scope: "turn.http"`) | Flat with composition (`also: [...]`) |
| **Documentation** | `@expression_doc` attributes | Standard `@doc`/`@spec` | `@expression_doc` preserved |
| **Stdlib** | Implicit fallback to `Standard` | Explicit `load_api` per module | `use Expression.Callbacks` imports stdlib |

---

## 10. Recommendations

> **Guiding principle:** Every recommendation below must preserve backwards compatibility. The library is in production; engage and potentially other consumers depend on its current behavior. Breaking changes are only acceptable when the trade-off is explicit, communicated via deprecation warnings, and accompanied by a migration path. "Add a new way, deprecate the old way, remove later" is the pattern — never "replace and hope."

### 10.1 Unify Error Handling (High Priority)

Define a single error type:

```elixir
defmodule Expression.Error do
  defexception [:type, :message, :expression, :position]
  @type t :: %__MODULE__{
    type: :parse | :eval | :type | :function,
    message: String.t(),
    expression: String.t() | nil,
    position: non_neg_integer() | nil
  }
end
```

**Backwards compatibility:** The existing public API (`evaluate!/3`, `evaluate_as_string!/3`, `parse!/1`) must continue to work unchanged. New functions with consistent error returns should be added alongside, not as replacements:

- Add `Expression.evaluate/3` returning `{:ok, result} | {:error, Expression.Error.t()}` (the current `evaluate/3` already exists but returns `{:error, string}` — change it to return the struct, wrapping the string in the `:message` field so pattern matches on `{:error, _}` still work)
- The bang variants continue to raise, but raise `Expression.Error` instead of bare `RuntimeError`. Consumer `rescue` blocks matching on `RuntimeError` need to also match `Expression.Error` — add a note in the changelog
- The error map (`Expression.error/1`) stays as-is for now, but `Expression.Error` should be the canonical type going forward. Deprecate `Expression.error/1` with a warning pointing to the new type
- The `{:not_found, path}` sentinel should eventually become an `Expression.Error` with `type: :not_found`, but this is deep in the evaluator — tackle it after the public API is clean

### 10.2 Make Context Normalization Opt-In (High Priority)

`Context.new/2` performs two destructive transformations: key lowercasing and string value coercion. Both should be opt-in.

**Backwards compatibility:** Inverting either default directly would break every caller. Instead:

- Keep `Context.new/2` behavior unchanged for now
- Add explicit options: `Context.new(ctx, lowercase_keys: false, coerce_strings: false)`
- Emit a deprecation warning when `Context.new/2` is called without explicit options, guiding callers to choose
- In a future major version, flip both defaults to `false`
- For key lowercasing specifically: move to case-insensitive lookup at evaluation time rather than destructive lowercasing at storage time. The parser already lowercases variable names in the AST, so `@Contact.Name` resolves to `"contact.name"` — a case-insensitive `Map.get` against the original keys would preserve casing while maintaining the same expression behavior

This gives every caller time to audit their dependencies on both transformations.

### 10.3 Fix `String.to_atom/1` (High Priority)

Replace with `String.to_existing_atom/1` or a pre-registered function name lookup.

**Backwards compatibility:** This is a safe change — all valid function names already exist as atoms (they're defined as function names in `Standard` and custom callback modules). The only behavior change is that typo'd function names now return `{:error, "function_name is not implemented."}` without creating an atom, which is already the error path. No consumer should notice.

One caveat: if any consumer relies on calling `Expression.Callbacks.implements/3` to check arbitrary strings (e.g., for autocomplete), the atom would need to exist first. Guard this with a `try/rescue ArgumentError` fallback that returns `{:error, ...}` without creating the atom.

### 10.4 Formalize the AST as Public API (Medium Priority)

Document the AST format. Add typespecs.

**Backwards compatibility:** This is purely additive — documentation and types don't change runtime behavior. The question of moving to struct-based AST nodes (`%Expression.AST.Function{}` vs keyword lists) is a separate, breaking change that should only happen in a major version. For now, document and typespec what exists. Engage's `ElasticsearchConverter` pattern-matches against the current shape; changing that shape without a migration path would break it.

### 10.5 Remove the Binary Literal Re-evaluation (Medium Priority)

The `eval!({:literal, literal}, context, mod) when is_binary(literal)` clause that recursively evaluates string literals is a footgun.

**Backwards compatibility:** This is the most dangerous recommendation to implement because engage's `Build.Callbacks` relies on this behavior for nested template resolution. Removing it outright would break production flows.

Approach:
- Add an explicit `Expression.evaluate_template/3` (or similar) that does what the current implicit behavior does
- Add a context option or configuration flag: `nested_literal_evaluation: true` (defaulting to `true` to preserve current behavior)
- Log a deprecation warning when the implicit path is hit, pointing callers to the explicit function
- In a future version, change the default to `false`

This is a multi-version migration. Do not remove the clause until consumers have migrated.

### 10.6 Support Infix `and`/`or`/`not` in the Parser (Medium Priority)

Add these as operators with appropriate precedence.

**Backwards compatibility:** This is purely additive — the parser currently does not accept `a and b`, so adding it breaks nothing. The existing `and(a, b)` function call syntax must continue to work. Both forms should produce the same AST. The engage transpilation pipeline (`convert_to_expression`) can be simplified to a no-op over time, but doesn't need to change immediately — it will just produce output the parser already accepts.

### 10.7 Clean Up the Compatibility Layer (Low Priority, Easy Win)

`Expression.V2.Compat` is dead code that adds confusion.

**Backwards compatibility:** Before removing, audit engage for all call sites that reference `V2.Compat`. If engage calls `V2.Compat.evaluate_as_string!/3` (which just delegates to V1), changing those call sites to use `Expression.evaluate_as_string!/3` directly is a one-line change per site. Do this in engage first, then deprecate the compat module, then remove it. Never remove the module while callers still reference it.

### 10.8 Add Private State to Context (High Priority)

Adopt the Lua package's private state pattern. See section 8.4 for the concrete design.

**Backwards compatibility:** This is the recommendation most carefully designed for backwards compatibility. The key decisions:

- The evaluator must continue to accept plain maps as context (the `when is_map(context)` clause stays). The new `%Expression.Context{}` struct is an additional code path, not a replacement.
- `Context.new/2` continues to return a plain map. A new function (e.g., `Context.build/3` or `Context.new/3` with a `:private` option) returns the struct.
- Callbacks receive either a map or a struct. Callback authors who want private state add a function head matching `%Expression.Context{}` and keep the existing `when is_map(ctx)` head as a fallback. This is a gradual opt-in for each callback, not a flag day.
- The `handle/4` function in `Expression.Callbacks` passes the context through unchanged — it doesn't need to know whether it's a map or struct.

Migration path for engage:
1. Bump expression dependency
2. Change `Build.default_context` to return `%Expression.Context{vars: existing_map, private: %{number: number, ...}}`
3. Update callbacks one at a time to pattern match on the struct for private data
4. Each callback keeps the old map clause as a fallback until all call sites have migrated

### 10.9 Add a `~EXPR` Sigil (Medium Priority)

Provide compile-time expression validation and optional pre-parsing. See section 8.4 for the design.

**Backwards compatibility:** Purely additive. No existing code is affected. Consumers opt in by `import Expression` (or `import Expression.Sigil`) and using `~EXPR"..."` in their source. The sigil produces the same types (string or AST keyword list) that `Expression.parse!/1` already returns — no new types to handle.

### 10.10 Add a `defexpr` Macro (High Priority)

Adopt the `deflua` pattern for callback definition. See section 9.3-9.4 for the concrete design.

**Backwards compatibility:** Purely additive. Existing callbacks defined with plain `def` continue to work unchanged. The `defexpr` macro generates identical `def` functions under the hood — it's sugar, not a new dispatch mechanism. Modules can mix `def` and `defexpr` freely. The compile-time registry (`__expression_functions__/0`) supplements the existing `function_exported?` checks; dispatch falls back to the runtime check for functions defined with `def`.

### 10.11 Split Standard Callbacks (Low Priority)

4,069 lines in one module is too much.

**Backwards compatibility:** This is a refactor that must be invisible to consumers. `Expression.Callbacks.Standard` must continue to exist and export every function it currently exports. The split modules (`Expression.Callbacks.String`, etc.) are internal organization. `Standard` can delegate to them or `use` them. No consumer should need to change any code. The callback dispatch in `Expression.Callbacks.handle/4` already checks `Standard` as a fallback — this must continue to work.

---

## 11. What I Would NOT Change

- **NimbleParsec as the parser foundation** — it's the right tool, well-used
- **The pluggable callbacks architecture** — `use Expression.Callbacks` is a clean extension point
- **The `@expression_doc` autodoc system** — self-documenting functions with examples that serve as both docs and tests is excellent
- **The template syntax** (`@var`, `@(expr)`, `@@` escape) — pragmatic, user-friendly, well-tested
- **The `prewalk/traverse` delegation** — giving consumers AST manipulation via Macro is smart

The library works. It has handled production traffic. The recommendations above are about reducing the operational burden on consumers (primarily engage) and preventing the class of bugs that come from implicit behavior and inconsistent contracts.

---

## 12. Test Suite Assessment

The test suite has 247 tests across 15 files (~3,800 lines). Coverage is solid for happy paths and basic edge cases, but has notable gaps:

**Strengths:**
- Extensive type coercion testing (nil, mixed types, string-to-number)
- Good nil/missing value handling coverage
- Callback composition well-tested (custom within standard, standard within custom)
- DateTime/Date comparison edge cases covered

**Gaps:**
- No property-based testing (StreamData would improve parser robustness confidence)
- No security/injection tests (expression injection, deeply nested recursion)
- No performance benchmarks or regression tests
- Division by zero not tested
- Unicode edge cases not covered
- V1/V2 compat test has a skipped test for "substitutions in substitutions" (the binary literal recursion issue from section 2.1)
- `evaluate_as_string!` silently returns empty string on errors while `evaluate_block!` returns raw error maps — documented as intentional but creates inconsistent consumer experience

---

## 13. Implementation Checklist

Ordered by priority. Items within the same phase can be worked on in parallel. Each item references the section with the full design and backwards compatibility analysis.

### Phase 1: Safety and Foundation ✅ COMPLETE (2026-04-03)

These are production safety fixes and the structural foundation everything else builds on.

- [x] **Fix `String.to_atom/1` in callback dispatch** — `atom_function_name/1` now uses `String.to_existing_atom/1` with rescue fallback returning `nil`. `implements/3` restructured with nil-safe guards. Extracted `do_implements/5`. All expression tests (558 doctests + 255 tests) and engage tests (301 tests) pass. *(Section 10.3)*
- [x] **Add `%Expression.Context{}` struct with private state** — struct with `vars` and `private` fields. `Context.new/2` unchanged (returns plain map, passes through existing struct). New `Context.build/2` returns struct with `private:` option. Eval dual-path: struct reads from `vars`, map path unchanged. Lambdas/captures work with struct. 8 new tests verify private state isolation (`@secret` in private is not resolvable via expressions). *(Sections 8.4, 10.8)*
- [x] **Define `Expression.Error` exception struct** — `lib/expression/error.ex` with `type`, `message`, `expression`, `position` fields. Purely additive, no existing code uses it yet. *(Section 10.1)*

### Phase 2: Developer Experience

The `defexpr` macro and related ergonomics. Depends on Phase 1 (`%Expression.Context{}` must exist for context access to work).

- [ ] **Implement `defexpr` macro** — auto-evaluates arguments, optional context injection, compile-time function registration via `@before_compile`. Generates standard `def` under the hood. *(Sections 9.3, 9.4, 10.10)*
- [ ] **Add compile-time consistency validation** — ensure all clauses of a `defexpr` function agree on context usage. Modeled on Lua's `validate_func!`. *(Section 9.4)*
- [ ] **Add `@variadic true` attribute support** — replaces the `_vargs` suffix convention with an explicit attribute that auto-resets per function. *(Section 9.4)*
- [ ] **Add `use Expression.Callbacks` composition options** — `stdlib: false` to opt out of Standard, `also: [ModuleA, ModuleB]` for multi-module dispatch. Default behavior unchanged. *(Section 9.5)*

### Phase 3: Error Handling Migration

Depends on Phase 1 (`Expression.Error` must exist). This is a multi-version migration.

- [ ] **Make `evaluate/3` return `{:error, Expression.Error.t()}`** — wrap existing string errors in the struct so `{:error, _}` pattern matches still work. *(Section 10.1)*
- [ ] **Make bang functions raise `Expression.Error`** — instead of bare `RuntimeError`. Add changelog note for consumers with `rescue RuntimeError` blocks. *(Section 10.1)*
- [ ] **Deprecate `Expression.error/1` map constructor** — emit warning pointing to `Expression.Error`. Keep the function working. *(Section 10.1)*

### Phase 4: Parser Improvements

Independent of other phases. Purely additive.

- [ ] **Add infix `and`/`or`/`not` operator support** — new precedence level below comparison operators. Existing `and(a, b)` function call syntax unchanged. Both produce the same AST. *(Section 10.6)*
- [ ] **Add `~EXPR` sigil** — compile-time syntax validation, optional pre-parsing with `c` modifier. Purely opt-in. *(Sections 8.3, 10.9)*

### Phase 5: Context Normalization

Can be started in parallel with Phase 4. Requires careful testing against engage.

- [ ] **Add explicit `lowercase_keys` and `coerce_strings` options to `Context.new/2`** — when omitted, behave as today but emit deprecation warning. Passing either option explicitly suppresses the warning. *(Section 10.2)*
- [ ] **Move to case-insensitive lookup instead of destructive lowercasing** — the parser already lowercases variable names in the AST; a case-insensitive `Map.get` at evaluation time preserves original key casing while maintaining expression behavior. *(Sections 4.1, 10.2)*
- [ ] **Audit engage for normalization dependencies** — determine which call sites rely on auto-parsing (DateTime strings) and lowercased keys. Update each to pass options explicitly. *(Section 10.2)*

### Phase 6: Cleanup

Low-risk housekeeping. Do when convenient.

- [ ] **Remove `Expression.V2.Compat` dead code** — audit engage for references first, update call sites to use `Expression` directly, then deprecate and remove the compat module. *(Section 10.7)*
- [ ] **Document the AST format as public API** — add typespecs for AST nodes. No runtime changes. Formalizes what engage's `ElasticsearchConverter` already depends on. *(Section 10.4)*
- [ ] **Split `Standard` callbacks into category modules** — `Standard` continues to exist and export everything, delegating to `Expression.Callbacks.String`, `.Math`, `.DateTime`, `.Collection`, `.Logic`. No consumer impact. *(Section 10.11)*

### Phase 7: Careful Deprecations

These change existing behavior. Only after consumers have migrated.

- [ ] **Add explicit `evaluate_template/3` function** — extracts the binary literal re-evaluation into a named function. Add `nested_literal_evaluation: false` option defaulting to `true`. Log deprecation when implicit path is hit. *(Section 10.5)*
- [ ] **Flip `coerce_strings` and `lowercase_keys` defaults to `false`** — only in a major version, after all consumers pass options explicitly. *(Section 10.2)*
- [ ] **Remove `nested_literal_evaluation` implicit path** — only in a major version, after consumers have migrated to explicit `evaluate_template/3`. *(Section 10.5)*

---

*The strongest signal for what needs fixing isn't in this library's code — it's in every `try/rescue` block, every type check, and every conversion workaround in the code that calls it.*
