defmodule Expression.V2.Compile do
  @moduledoc """
  An compiler for AST returned by Expression.V2.Parser.

  This reads the AST output returned by `Expression.V2.parse/1` and
  compiles it to Elixir code. 

  It does this by emitting valid Elixir AST, mimicking what `quote/2` does.

  The Elixir AST is then supplied to `Code.eval_quoted_with_env/3` without any
  variable binding. What is returned is an anonymous function that accepts an 
  `Expression.V2.Context.t` struct and evaluates the code against that context.

  Any function calls are applied to the callback module referenced in the context.
  So if an expression uses a function called `foo(1, 2, 3)` then the callback's 
  `callback/3` function will be called as follows:

  ```elixir
  apply(context.callback_module, :callback, ["foo", [1, 2, 3]])
  ```

  There is some special handling of some functions that have specific Elixir AST 
  syntax requirements.

  These are documented in the `to_quoted/2` function.

  All variables referenced by the expression are scoped to `context.vars`.
  However the full context is supplied to any function calls, giving
  functions the privilege of doing more than the `context.vars` scope alone
  would allow them to do.
  """

  @doc """
  Accepts AST as emitted by `Expression.V2.parse/1` and returns an anonymous function
  that accepts a Context.t as an argument and returns the result  of the expression 
  against the given Context.

  If the callback functions defined in the callback module are pure then this function
  is also pure and is suitable for caching.
  """
  @spec compile([any]) ::
          (Expression.V2.Context.t() -> any)
  def compile(ast) do
    # convert to valid Elixir AST
    quoted = wrap_in_context(to_quoted(ast))
    {term, _binding, _env} = Code.eval_quoted_with_env(quoted, [], Code.env_for_eval([]))

    term
  end

  @doc """
  Wrap an AST block into an anonymous function that accepts
  a single argument called context.

  This happens _after_ all the code generation completes. The code
  generated expects a variable called `context` to exist, wrapping
  it in this function ensures that it does.

  This is the anonymous function that is returned to the caller.
  The caller is then responsible to call it with the correct context
  variables.
  """
  @spec wrap_in_context(Macro.t()) :: Macro.t()
  def wrap_in_context(quoted) do
    # Check to see if the generated AST makes a reference to the context.
    # If that is the case then generate an AST that makes it available.
    # If there are no references to the context then prefix the variable
    # with an underscore to keep the compiler happy and not emit warnings
    # at runtime
    {quoted, uses_context?} =
      Macro.prewalk(quoted, false, fn
        {:context, _, _} = node, _acc -> {node, true}
        other, acc -> {other, acc}
      end)

    context_var = if uses_context?, do: :context, else: :_context

    {:fn, [],
     [
       {:->, [],
        [
          [{context_var, [], nil}],
          {:__block__, [],
           [
             quoted
           ]}
        ]}
     ]}
  end

  @doc """
  Convert the AST returned from `Expression.V2.parse/1` into valid Elixir AST
  that can be used by `Code.eval_quoted_with_env/3`.

  There is some special handling here:

  1. Lists are recursed to ensure that all list items are properly quoted.
  2. "\"Quoted strings\"" are unquoted and returned as regular strings to the AST.
  3. "Normal strings" are converted into Atoms and treated as such during eval.
  4. Literals such as numbers & booleans are left as is.
  5. Range.t items are converted to valid Elixir AST.
  6. `&` and `&1` captures are generated into valid Elixir AST captures.
  7. Any functions are generated as being function calls for the given callback module.
  """
  @spec to_quoted([term] | term) :: Macro.t()
  def to_quoted(ast) when is_list(ast) do
    quoted_block =
      Enum.reduce(ast, [], fn element, acc ->
        [quoted(element) | acc]
      end)

    {:__block__, [], quoted_block}
  end

  defp quoted("\"" <> _ = binary) when is_binary(binary),
    do: String.replace(binary, "\"", "")

  defp quoted(number) when is_number(number), do: number
  defp quoted(boolean) when is_boolean(boolean), do: boolean

  defp quoted({"__property__", [a, b]}) when is_binary(b) do
    # When the property we're trying to read is a binary then we're doing
    # `foo.bar` in an expression and we convert this to a `foo["bar"]`
    {{:., [], [Access, :get]}, [], [quoted(a), b]}
  end

  defp quoted({"__attribute__", [a, b]}) do
    # Since Map keys in Expressions can either be integers or strings
    # we use the helper in Expression.V2.read_attribute to read
    # the correct value using Elixir function guards in compiled
    # code rather than attempting to generate the AST for that here.
    {{:., [], [{:__aliases__, [alias: false], [:Expression, :V2]}, :read_attribute]}, [],
     [quoted(a), quoted(b)]}
  end

  defp quoted({"if", [test, yes, no]}) do
    # This is not handled as a callback function in the callback module
    # because the arguments need to be evaluated lazily.
    {:if, [],
     [
       quoted(test),
       [
         do: quoted(yes),
         else: quoted(no)
       ]
     ]}
  end

  defp quoted({"&", args}) do
    {:&, [], Enum.map(args, &quoted(&1))}
  end

  defp quoted("&" <> index) do
    {:&, [], [String.to_integer(index)]}
  end

  defp quoted({function_name, arguments})
       when is_binary(function_name) and is_list(arguments) do
    {:apply, [],
     [
       context_dot_callback_module(),
       :callback,
       [{:context, [], nil}, function_name, Enum.map(arguments, &quoted(&1))]
     ]}
  end

  defp quoted(list) when is_list(list) do
    Enum.map(list, &quoted(&1))
  end

  defp quoted(atom) when is_binary(atom) do
    {{:., [], [Access, :get]}, [], [context_dot_vars(), atom]}
  end

  defp quoted(%Range{first: first, last: last, step: step}) do
    {:%, [],
     [
       {:__aliases__, [], [:Range]},
       {:%{}, [], [first: first, last: last, step: step]}
     ]}
  end

  defp context_dot_callback_module do
    # Short hand function to generate `context.callback_module`
    {{:., [], [{:context, [], nil}, :callback_module]}, [no_parens: true], []}
  end

  defp context_dot_vars do
    # Short hand function to generate `context.vars`
    {{:., [], [{:context, [], nil}, :vars]}, [no_parens: true], []}
  end
end
