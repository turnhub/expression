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

  @doc false
  def handle_without_stdlib(module, function_name, arguments, context) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    Code.ensure_compiled!(module)
    Code.ensure_loaded!(module)

    result =
      cond do
        not is_nil(exact_function_name) and
            function_exported?(module, exact_function_name, length(arguments) + 1) ->
          {:ok, apply(module, exact_function_name, [context] ++ arguments)}

        not is_nil(vargs_function_name) and function_exported?(module, vargs_function_name, 2) ->
          {:ok, apply(module, vargs_function_name, [context, arguments])}

        true ->
          {:error, "#{function_name} is not implemented."}
      end

    result
  end

  @doc false
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
      find_in_chain(modules, function_name, exact_function_name, vargs_function_name, arguments,
        context: context
      )
    end
  end

  defp find_in_chain([], function_name, _exact, _vargs, _arguments, _opts) do
    {:error, "#{function_name} is not implemented."}
  end

  defp find_in_chain([mod | rest], function_name, exact, vargs, arguments, opts) do
    context = Keyword.fetch!(opts, :context)

    cond do
      not is_nil(exact) and exact in @built_in_operators ->
        {:ok, apply(Kernel, exact, arguments |> Enum.map(&Expression.Eval.eval!(&1, context)))}

      not is_nil(exact) and function_exported?(mod, exact, length(arguments) + 1) ->
        {:ok, apply(mod, exact, [context] ++ arguments)}

      not is_nil(vargs) and function_exported?(mod, vargs, 2) ->
        {:ok, apply(mod, vargs, [context, arguments])}

      true ->
        find_in_chain(rest, function_name, exact, vargs, arguments, opts)
    end
  end

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
      do_implements(module, function_name, exact_function_name, vargs_function_name, arguments)
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp do_implements(module, function_name, exact_function_name, vargs_function_name, arguments) do
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

  defp wrong_arity_but_function_exists?(_module, nil), do: false

  defp wrong_arity_but_function_exists?(module, function_name)
       when is_atom(module) and is_atom(function_name) do
    module.__info__(:functions)[function_name] != nil
  end

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
  defmacro defexpr(fa, ctx_var, rest) do
    define_expr(fa, ctx_var, rest)
  end

  defmacro defexpr(fa, rest) do
    define_expr(fa, nil, rest)
  end

  defp define_expr(fa, ctx_var, do: body) do
    {name, args} = decompose_fa(fa)
    with_ctx? = ctx_var != nil

    # The Elixir def name is what the user writes (e.g., or_, if_, and_, not_)
    def_name = name

    # The expression-facing name strips the _ suffix for reserved words
    # so `defexpr or_(a, b)` registers as expression function `or`
    name_str = to_string(name)

    expr_name =
      if String.ends_with?(name_str, "_") and
           String.trim_trailing(name_str, "_") in @reserved_words do
        String.trim_trailing(name_str, "_") |> String.to_atom()
      else
        name
      end

    exact_ast = gen_exact_def(def_name, expr_name, args, ctx_var, with_ctx?, body)
    vargs_def_name = :"#{def_name}_vargs"
    user_args_var = List.first(args)

    variadic_ast =
      gen_variadic_def(vargs_def_name, expr_name, user_args_var, ctx_var, with_ctx?, body)

    # Read @variadic at caller's compile time (like Lua does)
    quote do
      if Module.delete_attribute(__MODULE__, :variadic) do
        unquote(variadic_ast)
      else
        unquote(exact_ast)
      end
    end
  end

  defp decompose_fa({:when, _, [{name, _, args} | _guards]}) do
    {name, args || []}
  end

  defp decompose_fa({name, _, args}) do
    {name, args || []}
  end

  defp gen_exact_def(def_name, expr_name, args, ctx_var, with_ctx?, body) do
    ast_args = Enum.map(args, fn {arg_name, _, _} -> Macro.var(:"#{arg_name}_ast__", nil) end)
    ctx_param = Macro.var(:expr_ctx__, nil)

    eval_mod = Expression.Callbacks.EvalHelpers

    eval_bindings =
      Enum.zip(args, ast_args)
      |> Enum.map(fn {{arg_name, _, _}, ast_var} ->
        quote do
          unquote(Macro.var(arg_name, nil)) =
            unquote(eval_mod).eval!(unquote(ast_var), unquote(ctx_param))
        end
      end)

    ctx_binding =
      if with_ctx? do
        [quote(do: unquote(ctx_var) = unquote(ctx_param))]
      else
        []
      end

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
      def unquote(def_name)(unquote(ctx_param), unquote_splicing(ast_args)) do
        unquote(full_body)
      end
    end
  end

  defp gen_variadic_def(def_name, expr_name, user_args_var, ctx_var, with_ctx?, body) do
    ctx_param = Macro.var(:expr_ctx__, nil)

    ctx_binding =
      if with_ctx? do
        [quote(do: unquote(ctx_var) = unquote(ctx_param))]
      else
        []
      end

    full_body =
      quote do
        unquote_splicing(ctx_binding)
        unquote(body)
      end

    # The user's first argument name gets bound to the raw arguments list
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
