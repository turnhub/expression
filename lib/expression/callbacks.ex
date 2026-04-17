defmodule Expression.Callbacks do
  @moduledoc """
  Use this module to implement one's own callbacks.
  The standard callbacks available are implemented in `Expression.Callbacks.Standard`.

  ## Using `defexpr`

  `defexpr` auto-evaluates arguments from their AST form before the body executes:

  ```elixir
  defmodule MyCallbacks do
    use Expression.Callbacks

    defexpr dice_roll() do
      Enum.random(1..6)
    end

    defexpr greet(name), ctx do
      prefix = ctx.private[:prefix] || "Hello"
      "\#{prefix}, \#{name}!"
    end
  end
  ```

  ## Using plain `def`

  Traditional `def` callbacks still work — `defexpr` is optional sugar.
  With plain `def`, you must manually call `eval!` on each argument:

  ```elixir
  defmodule MyCallbacks do
    use Expression.Callbacks

    def dice_roll(_ctx) do
      Enum.random(1..6)
    end
  end
  ```

  ## Options

    * `stdlib: false` — don't fall back to `Expression.Callbacks.Standard`
    * `also: [ModuleA, ModuleB]` — compose multiple callback modules;
      dispatch checks each in order before falling back to Standard

  """

  alias Expression.Callbacks.Standard

  @built_in_operators [:+, :-, :*, :/, :>, :>=, :<, :<=, :==, :!=]
  @reserved_words ~w[and if or not]

  @doc """
  Convert a string function name into an atom meant to handle
  that function

  Reserved words such as `and`, `if`, and `or` are automatically suffixed
  with an `_` underscore.
  """
  def atom_function_name(function_name) when function_name in @reserved_words,
    do: atom_function_name("#{function_name}_")

  def atom_function_name(function_name) do
    String.to_existing_atom(function_name)
  rescue
    ArgumentError -> nil
  end

  @doc """
  Handle a function call while evaluating the AST.

  Handlers in this module are either:

  1. The function name as is
  2. The function name with an underscore suffix if the function name is a reserved word
  3. The function name suffixed with `_vargs` if the takes a variable set of arguments
  """
  @spec handle(module :: module, function_name :: binary, arguments :: [any], context :: map) ::
          {:ok, any} | {:error, :not_implemented}
  def handle(module \\ Standard, function_name, arguments, context) do
    case implements(module, function_name, arguments) do
      {:exact, module, function_name, _arity} ->
        {:ok, apply(module, function_name, [context] ++ arguments)}

      {:vargs, module, function_name, _arity} ->
        {:ok, apply(module, function_name, [context, arguments])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @typedoc "The result of a callback function dispatch"
  @type handle_result :: {:ok, any} | {:error, String.t()}

  @typedoc "The result of checking whether a function is implemented"
  @type implements_result ::
          {:exact, module, atom, arity}
          | {:vargs, module, atom, arity}
          | {:error, String.t()}

  @doc """
  Handle a function call without falling back to `Standard`.

  Used when a callback module is configured with `stdlib: false`.
  Only checks the given module for exact-arity and vargs implementations.
  """
  @spec handle_without_stdlib(module, String.t(), [any], map) :: handle_result
  def handle_without_stdlib(module, function_name, arguments, context) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    Code.ensure_compiled!(module)
    Code.ensure_loaded!(module)

    cond do
      not is_nil(exact_function_name) and
          function_exported?(module, exact_function_name, length(arguments) + 1) ->
        {:ok, apply(module, exact_function_name, [context] ++ arguments)}

      not is_nil(vargs_function_name) and function_exported?(module, vargs_function_name, 2) ->
        {:ok, apply(module, vargs_function_name, [context, arguments])}

      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  @doc """
  Handle a function call by searching through a chain of callback modules.

  Checks each module in order for an exact-arity or vargs implementation.
  Returns `{:ok, result}` from the first module that implements the function,
  or `{:error, reason}` if no module in the chain implements it.

  Used when a callback module is configured with `also: [ModA, ModB]`.
  """
  @spec handle_chain([module], String.t(), [any], map) :: handle_result
  def handle_chain(modules, function_name, arguments, context) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    modules
    |> Enum.uniq()
    |> Enum.each(fn mod ->
      Code.ensure_compiled!(mod)
      Code.ensure_loaded!(mod)
    end)

    if is_nil(exact_function_name) and is_nil(vargs_function_name) do
      {:error, "#{function_name} is not implemented."}
    else
      find_in_chain(
        modules,
        function_name,
        exact_function_name,
        vargs_function_name,
        arguments,
        context
      )
    end
  end

  @doc """
  Walk a list of callback modules looking for one that implements the
  given function.

  Tries each module in order. For each module, checks:
  1. Built-in operators (`:+`, `:-`, etc.) — dispatched to `Kernel`
  2. Exact-arity match — `module.function(ctx, arg1, arg2, ...)`
  3. Variable-args match — `module.function_vargs(ctx, [arg1, arg2, ...])`

  Returns `{:ok, result}` from the first match, or `{:error, reason}`
  when the list is exhausted.
  """
  @spec find_in_chain([module], String.t(), atom | nil, atom | nil, [any], map) :: handle_result
  def find_in_chain([], function_name, _exact, _vargs, _arguments, _context) do
    {:error, "#{function_name} is not implemented."}
  end

  def find_in_chain([mod | rest], function_name, exact, vargs, arguments, context) do
    cond do
      not is_nil(exact) and exact in @built_in_operators ->
        evaluated_args = Enum.map(arguments, &Expression.Eval.eval!(&1, context))
        {:ok, apply(Kernel, exact, evaluated_args)}

      not is_nil(exact) and function_exported?(mod, exact, length(arguments) + 1) ->
        {:ok, apply(mod, exact, [context] ++ arguments)}

      not is_nil(vargs) and function_exported?(mod, vargs, 2) ->
        {:ok, apply(mod, vargs, [context, arguments])}

      true ->
        find_in_chain(rest, function_name, exact, vargs, arguments, context)
    end
  end

  @doc """
  Check whether a function is implemented in the given module or in `Standard`.

  Returns a tagged tuple describing where and how the function is implemented:
  - `{:exact, module, function_atom, arity}` — exact arity match
  - `{:vargs, module, function_atom, 2}` — variable arguments match
  - `{:error, reason}` — not found or wrong arity
  """
  @spec implements(module, String.t(), [any]) :: implements_result
  def implements(module \\ Standard, function_name, arguments) do
    # Make sure the module supplied and the default module are compiled
    # & loaded before attempting to find out what functions it may
    # support as part of validation / implementation checks
    [Standard, module]
    |> Enum.uniq()
    |> Enum.map(&Code.ensure_compiled!/1)
    |> Enum.each(&Code.ensure_loaded!/1)

    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    # If neither the exact name nor the vargs name correspond to any
    # existing atom, this function can't be implemented — fail early
    # without creating atoms from arbitrary user input
    if is_nil(exact_function_name) and is_nil(vargs_function_name) do
      {:error, "#{function_name} is not implemented."}
    else
      resolve_implementation(
        module,
        function_name,
        exact_function_name,
        vargs_function_name,
        arguments
      )
    end
  end

  @doc """
  Resolve which module and calling convention implements a function.

  Checks in priority order:
  1. Built-in operators in the custom module
  2. Exact-arity in the custom module
  3. Variable-args in the custom module
  4. Exact-arity in `Standard`
  5. Variable-args in `Standard`
  6. Wrong-arity error (function exists but with different arity)
  7. Not implemented error
  """
  @spec resolve_implementation(module, String.t(), atom | nil, atom | nil, [any]) ::
          implements_result
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def resolve_implementation(
        module,
        function_name,
        exact_function_name,
        vargs_function_name,
        arguments
      ) do
    cond do
      not is_nil(exact_function_name) and exact_function_name in @built_in_operators ->
        {:exact, module, exact_function_name, 2}

      # Check if the exact function signature has been implemented
      not is_nil(exact_function_name) and
          function_exported?(module, exact_function_name, length(arguments) + 1) ->
        {:exact, module, exact_function_name, length(arguments) + 1}

      # Check if it's been implemented to accept a variable amount of arguments
      not is_nil(vargs_function_name) and function_exported?(module, vargs_function_name, 2) ->
        {:vargs, module, vargs_function_name, 2}

      # Check if the exact function signature has been implemented in Standard
      not is_nil(exact_function_name) and
          function_exported?(Standard, exact_function_name, length(arguments) + 1) ->
        {:exact, Standard, exact_function_name, length(arguments) + 1}

      # Check if it's been implemented to accept a variable amount of arguments in Standard
      not is_nil(vargs_function_name) and function_exported?(Standard, vargs_function_name, 2) ->
        {:vargs, Standard, vargs_function_name, 2}

      # Check if the wrong number of arguments was provided
      wrong_arity_but_function_exists?(module, exact_function_name) ->
        {:error, "wrong number of arguments to #{function_name}."}

      # Check if the wrong number of arguments was provided
      wrong_arity_but_function_exists?(Standard, exact_function_name) ->
        {:error, "wrong number of arguments to #{function_name}."}

      # Otherwise fail
      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  @doc """
  Check whether a module defines a function with the given name at any arity,
  even if the specific arity being requested doesn't match.

  Used to produce "wrong number of arguments" errors instead of
  "not implemented" errors.
  """
  @spec wrong_arity_but_function_exists?(module, atom | nil) :: boolean
  def wrong_arity_but_function_exists?(_module, nil), do: false

  def wrong_arity_but_function_exists?(module, function_name)
      when is_atom(module) and is_atom(function_name) do
    module.__info__(:functions)[function_name] != nil
  end

  # ── Metaprogramming glossary ────────────────────────────────────────
  #
  # If you're not familiar with Elixir macros, here's a quick reference
  # for the four tools used in the code below:
  #
  #   quote do ... end
  #     Captures a block of Elixir code as its AST representation
  #     (a nested tuple structure) instead of executing it. Think of
  #     it as "template this code for later."
  #
  #   unquote(value)
  #     Inside a `quote` block, injects a compile-time value into the
  #     template. Like string interpolation but for code.
  #
  #   unquote_splicing(list)
  #     Like `unquote`, but splices a list of AST nodes inline.
  #     Turns [a, b, c] into three separate statements.
  #
  #   Macro.var(name, nil)
  #     Creates a variable reference in the AST. The `nil` context
  #     makes it "hygienic" — it won't collide with variables the
  #     user defined in their code.
  #
  # ───────────────────────────────────────────────────────────────────

  @doc """
  Macro for defining expression callback functions with automatic
  argument evaluation.

  ## Without context (pure functions)

      defexpr upper(text) do
        String.upcase(to_string(text))
      end

  Generates a standard callback where `text` is automatically
  evaluated from its AST form before the body executes.

  ## With context access

      defexpr generate_ott(data), ctx do
        with %{number: number} <- ctx.private, ...
      end

  The second argument names the context variable, giving access to
  `ctx.vars`, `ctx.private`, and the full `Expression.Context` struct
  (or plain map for legacy callers).

  ## Variadic functions

      @variadic true
      defexpr switch(args), ctx do
        # args is a list of all pre-evaluated arguments
      end

  ## Reserved words

  Expression function names that are Elixir reserved words (`and`, `if`,
  `or`, `not`) are automatically suffixed with `_` in the generated
  function name.
  """
  defmacro defexpr(function_head, ctx_var, rest) do
    define_expr(function_head, ctx_var, rest)
  end

  defmacro defexpr(function_head, rest) do
    define_expr(function_head, nil, rest)
  end

  # ── Code generation entry point ───────────────────────────────────
  #
  # `define_expr` is the main orchestrator. It:
  #   1. Extracts the function name and arguments from the function head
  #   2. Determines the expression-facing name (stripping reserved word suffixes)
  #   3. Generates both exact-arity and variadic versions of the function
  #   4. Emits a compile-time `if` that picks the right one based on @variadic
  #
  defp define_expr(function_head, ctx_var, do: body) do
    {def_name, args} = decompose_function_head(function_head)
    with_ctx? = ctx_var != nil
    expr_name = expression_facing_name(def_name)

    exact_ast = gen_exact_def(def_name, expr_name, args, ctx_var, with_ctx?, body)

    vargs_def_name = :"#{def_name}_vargs"
    user_args_var = List.first(args)

    variadic_ast =
      gen_variadic_def(vargs_def_name, expr_name, user_args_var, ctx_var, with_ctx?, body)

    # ── Why Module.delete_attribute is inside `quote` ──────────────
    #
    # Code inside `quote do ... end` runs at the *caller module's*
    # compile time, not when this macro is expanded. We need to read
    # @variadic at that moment because:
    #
    #   @variadic true          # ← set by the user right before defexpr
    #   defexpr concat(args)... # ← macro expands here
    #
    # `Module.delete_attribute(__MODULE__, :variadic)` reads the value
    # AND clears it in one step (so it doesn't leak to the next defexpr).
    # If @variadic was set, it returns `true` and we emit the variadic
    # function. Otherwise we emit the exact-arity function.
    #
    # This pattern comes from the Lua package's `deflua` macro.
    #
    quote do
      if Module.delete_attribute(__MODULE__, :variadic) do
        unquote(variadic_ast)
      else
        unquote(exact_ast)
      end
    end
  end

  # Extracts {name, args} from the function head AST.
  #
  #   decompose_function_head(quote(do: foo(a, b)))
  #   #=> {:foo, [{:a, [], nil}, {:b, [], nil}]}
  #
  defp decompose_function_head({:when, _, [{name, _, args} | _guards]}) do
    {name, args || []}
  end

  defp decompose_function_head({name, _, args}) do
    {name, args || []}
  end

  # The expression-facing name strips the `_` suffix for reserved words.
  # Users write `defexpr or_(a, b)` (because `or` is an Elixir keyword),
  # but the expression language knows it as `or`.
  defp expression_facing_name(def_name) do
    name_str = to_string(def_name)

    if String.ends_with?(name_str, "_") and
         String.trim_trailing(name_str, "_") in @reserved_words do
      name_str |> String.trim_trailing("_") |> String.to_atom()
    else
      def_name
    end
  end

  # ── Exact-arity function generation ───────────────────────────────
  #
  # Given this input:
  #
  #     defexpr chunk_every(enumerable, count), ctx do
  #       Enum.chunk_every(enumerable, count)
  #     end
  #
  # Generates this output:
  #
  #     @expression_function {:chunk_every, true, false}
  #     def chunk_every(expr_ctx__, enumerable_ast__, count_ast__) do
  #       ctx = expr_ctx__
  #       enumerable = Expression.Callbacks.EvalHelpers.eval!(enumerable_ast__, expr_ctx__)
  #       count = Expression.Callbacks.EvalHelpers.eval!(count_ast__, expr_ctx__)
  #       Enum.chunk_every(enumerable, count)
  #     end
  #
  # The `@expression_function` attribute is an accumulating module
  # attribute that registers metadata about each defexpr function.
  # The tuple `{:chunk_every, true, false}` means:
  #   - :chunk_every  — the expression-facing function name
  #   - true          — this function uses context (defexpr/3)
  #   - false         — this is NOT a variadic function
  #
  # At compile time, `@before_compile` collects all these tuples and
  # generates `__expression_functions__/0`, which returns the full
  # list. This enables introspection — e.g. listing all registered
  # callbacks, checking context usage, or building documentation.
  #
  # The key transformation: each user argument (e.g. `enumerable`) gets
  # a hidden `_ast__` parameter in the actual function signature, and a
  # binding at the top of the body that evaluates it. The user's code
  # then sees `enumerable` as an already-evaluated value.
  #
  defp gen_exact_def(def_name, expr_name, args, ctx_var, with_ctx?, body) do
    ctx_param = hygienic_var(:expr_ctx__)
    ast_params = build_ast_params(args)
    eval_bindings = build_eval_bindings(args, ast_params, ctx_param)
    ctx_binding = build_ctx_binding(ctx_var, ctx_param, with_ctx?)

    full_body =
      quote do
        unquote_splicing(ctx_binding)
        unquote_splicing(eval_bindings)
        unquote(body)
      end

    quote do
      @expression_function Expression.Callbacks.validate_expression_func!(
                             {unquote(expr_name), unquote(with_ctx?), false},
                             __MODULE__,
                             @expression_function
                           )
      def unquote(def_name)(unquote(ctx_param), unquote_splicing(ast_params)) do
        unquote(full_body)
      end
    end
  end

  # ── Variadic function generation ──────────────────────────────────
  #
  # Given this input:
  #
  #     @variadic true
  #     defexpr concat(args), ctx do
  #       Enum.map_join(args, "", &EvalHelpers.eval!(&1, ctx))
  #     end
  #
  # Generates this output:
  #
  #     @expression_function {:concat, true, true}
  #                          # ↑ name   ↑ ctx  ↑ variadic=true
  #     def concat_vargs(expr_ctx__, args) do
  #       ctx = expr_ctx__
  #       Enum.map_join(args, "", &EvalHelpers.eval!(&1, ctx))
  #     end
  #
  # The user's first argument name (`args`) is bound directly to the
  # raw arguments list. Unlike exact-arity functions, arguments are NOT
  # auto-evaluated — the user controls evaluation (since the argument
  # count is dynamic).
  #
  defp gen_variadic_def(def_name, expr_name, user_args_var, ctx_var, with_ctx?, body) do
    ctx_param = hygienic_var(:expr_ctx__)
    ctx_binding = build_ctx_binding(ctx_var, ctx_param, with_ctx?)

    full_body =
      quote do
        unquote_splicing(ctx_binding)
        unquote(body)
      end

    quote do
      @expression_function Expression.Callbacks.validate_expression_func!(
                             {unquote(expr_name), unquote(with_ctx?), true},
                             __MODULE__,
                             @expression_function
                           )
      def unquote(def_name)(unquote(ctx_param), unquote(user_args_var)) do
        unquote(full_body)
      end
    end
  end

  # ── Helpers for code generation ───────────────────────────────────

  # Creates a variable reference that won't collide with user-defined
  # variables. The `nil` context makes it hygienic — even if the user
  # has a variable called `expr_ctx__`, it won't conflict.
  defp hygienic_var(name), do: Macro.var(name, nil)

  # For each user argument like `text`, creates a corresponding hidden
  # parameter like `text_ast__` that will appear in the generated
  # function signature.
  defp build_ast_params(args) do
    Enum.map(args, fn {arg_name, _, _} ->
      hygienic_var(:"#{arg_name}_ast__")
    end)
  end

  # Generates the `arg = eval!(arg_ast__, ctx)` bindings that appear
  # at the top of the function body, one per argument.
  defp build_eval_bindings(args, ast_params, ctx_param) do
    eval_mod = Expression.Callbacks.EvalHelpers

    Enum.zip(args, ast_params)
    |> Enum.map(fn {{arg_name, _, _}, ast_var} ->
      quote do
        unquote(Macro.var(arg_name, nil)) =
          unquote(eval_mod).eval!(unquote(ast_var), unquote(ctx_param))
      end
    end)
  end

  # If the user requested context access (`defexpr foo(a), ctx do`),
  # generates `ctx = expr_ctx__` so the user's chosen name is bound.
  # If not, returns an empty list (no binding generated).
  defp build_ctx_binding(_ctx_var, _ctx_param, false = _with_ctx?), do: []

  defp build_ctx_binding(ctx_var, ctx_param, true = _with_ctx?) do
    [quote(do: unquote(ctx_var) = unquote(ctx_param))]
  end

  # ── Compile-time validation ───────────────────────────────────────

  @doc false
  def validate_expression_func!({name, with_ctx?, variadic?}, module, existing) do
    conflict =
      Enum.find(existing, fn
        {^name, other_ctx?, _} -> other_ctx? != with_ctx?
        _ -> false
      end)

    if conflict do
      raise CompileError,
        description:
          "#{inspect(module)}.#{name} has inconsistent context usage across clauses. " <>
            "All defexpr clauses for the same function must consistently use or omit context."
    end

    {name, with_ctx?, variadic?}
  end

  defmacro __using__(opts \\ []) do
    also_modules = Keyword.get(opts, :also, [])
    stdlib? = Keyword.get(opts, :stdlib, true)

    handle_def =
      if also_modules == [] do
        # Default: delegate to Expression.Callbacks (checks self, then Standard)
        if stdlib? do
          quote do
            defdelegate handle(module \\ __MODULE__, function_name, arguments, context),
              to: Expression.Callbacks
          end
        else
          quote do
            def handle(module \\ __MODULE__, function_name, arguments, context) do
              Expression.Callbacks.handle_without_stdlib(
                module,
                function_name,
                arguments,
                context
              )
            end
          end
        end
      else
        # Compose: check self, then each `also` module, then Standard (if enabled)
        modules =
          if stdlib?,
            do: also_modules ++ [Expression.Callbacks.Standard],
            else: also_modules

        quote do
          def handle(module \\ __MODULE__, function_name, arguments, context) do
            Expression.Callbacks.handle_chain(
              [module | unquote(modules)],
              function_name,
              arguments,
              context
            )
          end
        end
      end

    quote do
      import Expression.Callbacks.EvalHelpers
      import Expression.Callbacks, only: [defexpr: 2, defexpr: 3]

      Module.register_attribute(__MODULE__, :expression_function, accumulate: true)
      @before_compile Expression.Callbacks

      unquote(handle_def)
    end
  end

  defmacro __before_compile__(env) do
    functions =
      env.module
      |> Module.get_attribute(:expression_function)
      |> Enum.uniq()
      |> Enum.reverse()

    quote do
      def __expression_functions__ do
        unquote(Macro.escape(functions))
      end
    end
  end
end
