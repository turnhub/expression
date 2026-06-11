# Testing Guide

This document describes how the Expression library is tested and how to add
tests when you change or add a function.

## Test layout

| Location | Purpose |
|----------|---------|
| `@expression_doc` annotations in `lib/expression/callbacks/standard.ex` | Happy-path examples that double as doctests |
| `test/expression_test.exs` | Core engine + hand-written edge cases (incl. the pilot type tests for `upper`, `lower`, `abs`, `round`, `date`) |
| `test/*_functions_type_test.exs` | Systematic **type-matrix** tests, one file per function category |
| `test/expression_fuzz_test.exs` | Property-based **crash-safety** tests (tagged `:fuzz`) |
| `test/support/*.ex` | Reusable test helpers |

The category type-test files are:

- `test/string_functions_type_test.exs`
- `test/number_functions_type_test.exs`
- `test/date_functions_type_test.exs`
- `test/logical_functions_type_test.exs`
- `test/enum_functions_type_test.exs`

## Running tests

```bash
# Everything except fuzz tests (the default, fast suite)
mix test

# A single file
mix test test/string_functions_type_test.exs

# A single test by line number
mix test test/string_functions_type_test.exs:42

# Watch mode during development
mix test.watch

# Property-based fuzz tests ONLY (see "Fuzz tests" below)
mix test --only fuzz
```

Fuzz tests are **excluded from the default suite** via
`ExUnit.start(exclude: [:fuzz])` in `test/test_helper.exs`. You opt into them
explicitly with `--only fuzz`.

## Guiding philosophy: document current behavior

The type-test and fuzz files **document the V1 engine's actual behavior — they
do not endorse it.** Many functions raise on unexpected input rather than
returning an error map. Where that happens, the test pins the exact exception
so that any future change to the behavior is deliberate, not accidental:

```elixir
test "nil raises ArithmeticError" do
  # Known crash behavior, documented not endorsed: Kernel.rem/2 with nil.
  assert_raise ArithmeticError, fn -> evaluate_with_value("rem(value, 3)", nil) end
end
```

When you read `# Known crash behavior, documented not endorsed: ...` or
`# Surprising: ...` in a test, it is recording a real, observed behavior — not
the behavior we wish the function had. If you *fix* such a behavior, update the
corresponding test to assert the new (better) result.

## Test support helpers

### `Expression.Test.TypeTestMatrix`

Imported by every type-test file. Provides a canonical set of sample values for
each runtime type, plus convenience evaluators:

- `evaluate_with_value(expr, value, extra_context \\ %{})` — evaluate a block
  expression (no leading `@`) with `value` bound to the `value` key.
- `complex_value(value, extra \\ %{})` — build a "complex" map carrying a
  `__value__` key, as produced by flow results.
- `error_value(message \\ ...)` — build a V1 error map.
- `all_test_values/0`, `test_values_for/1`, `invalid_values_for/1` — the matrix
  values themselves.

### `Expression.Test.FuzzHelpers`

Imported by the fuzz file. Provides `StreamData` generators (`any_value/0`,
`string_value/0`, `list_value/0`, …) and `assert_no_crash/2`, which fails only
if evaluating an expression *raises* (returning an error map is fine).

## The context-coercion gotcha

`Expression.Context` coerces context values **before callbacks see them**:

- numeric-looking strings (`"123"`, `"3.14"`) become numbers,
- ISO-date-looking strings become `Date`/`DateTime`/`Time` structs,
- `"true"`/`"false"` become booleans.

So `evaluate_with_value("upper(value)", "123")` does **not** pass the string
`"123"` to `upper` — it passes the integer `123`. To test a function with a
genuine string argument, embed a **string literal in the expression source**:

```elixir
# context-coerced: "123" -> 123 before the callback
evaluate_with_value("fixed(value, 2)", "123")   # => "123.00"

# literal string survives to the callback
Expression.evaluate_block!(~s|fixed("3.14", 2)|) # => "3.14"
```

## Fuzz tests

`test/expression_fuzz_test.exs` enforces a single invariant: **the function must
never raise** on arbitrary input (returning a value or an error map is fine).

The V1 engine does **not** uphold this invariant universally, so the suite
fuzzes only the subset of functions empirically confirmed crash-safe across the
whole type matrix. The functions that currently *do* crash are listed in the
file's moduledoc as a hardening backlog; each is pinned with its exact exception
in the relevant `*_functions_type_test.exs` file.

These tests are **not** run in CI. They use a random seed each run and exist to
*discover* new crashing inputs, so they can legitimately go red when they find
one — useful locally, but a poor fit for a branch-protection gate. Run them
manually:

```bash
mix test --only fuzz
```

If you harden a known-crashing function so it returns an error map instead of
raising, move it into the appropriate `@crash_safe_*` list at the top of the
fuzz file (and update its type test).

## Adding tests for a new function

When you add a function to `Expression.Callbacks.Standard`:

1. **Add `@expression_doc` examples** in the source for the happy path. These
   run as doctests automatically.
2. **Add type-matrix tests** to the matching `test/<category>_functions_type_test.exs`
   file. Cover, at minimum:
   - `nil`,
   - the type(s) the function is meant to accept,
   - wrong types (numbers, strings, booleans, lists, maps),
   - a complex value via `complex_value/1` to confirm `__value__` extraction,
   - any function-specific edge cases (empty string/list, unicode, zero,
     negatives, leap years, …).
   **Discover the real behavior by running it** — do not guess. If it crashes,
   pin the exact exception with `assert_raise` and a `# Known crash behavior`
   comment.
3. **If the function is crash-safe**, add it to the relevant `@crash_safe_*`
   list in `test/expression_fuzz_test.exs` so the no-crash invariant is guarded.
4. Run `mix format` and make sure `mix test` is green.
