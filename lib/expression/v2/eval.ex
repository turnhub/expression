defmodule Expression.V2.Eval do
  @moduledoc """
  An evaluator for AST returned by Expression.V2.Parser.

  This reads the AST output returned by `Expression.V2.parse/1` and
  evaluates it according to the given variable bindings and functions
  available in the callback module specified.

  It does this by emitting valid Elixir AST, mimicking what `quote/2` does.

  The Elixir AST is then supplied to `Code.eval_quoted_with_env/3` with the binding
  and Elixir evaluates it for us, reducing the need for us to ensure that our 
  eval is correct and instead relying on us to generate correct AST instead.

  The callback module referenced is inserted as the module for any function
  that is called. So if an expression uses a function called `foo(1, 2, 3)`
  then the callback module **must** provide a `foo/3` function.

  There is some special handling of some functions that either requires lazy
  loading or have specific Elixir AST syntax requirements.

  These are documented in the `to_quoted/2` function.
  """

  @doc """
  Accepts AST as emitted by `Expression.V2.parse/1` and evaluates it against
  the given variable binding and the functions defined in the callback module.
  """
  @spec eval([any], binding :: Keyword.t(), callback_module :: atom) :: [any]
  def eval(ast, binding, callback_module) do
    # NOTE: I'm still not sure if the context is needed in this new approach
    #       like it is in the current approach...
    binding = Keyword.put(binding, :context, %{})

    # convert to valid Elixir AST
    quoted = to_quoted(ast, callback_module)

    {term, _binding, _env} =
      {:__block__, [], quoted}
      |> Code.eval_quoted_with_env(binding, Code.env_for_eval([]))

    term
  end

  @doc """
  Convert the AST returned from `Expression.V2.parse/1` into valid Elixir AST
  that can be used by `Code.eval_quoted_with_env/3`.

  There is some special handling here:

  1. Lists are recursed into to ensure that all list items are properly quoted.
  2. "\"Quoted strings\"" are unquoted and returned as regular strings to the AST.
  3. "Normal strings" are converted into Atoms and treated as such during eval.
  4. Literals such as numbers & booleans are left as is.
  5. Range.t items are converted to valid Elixir AST.
  6. `&` and `&1` captures are generated into valid Elixir AST captures.
  7. `if` and similar lazy functions such as `or` are evaluated lazily depending
     on the output of the test. As an example the AST for `if(foo, bar, baz)` would
     only attempt to quote `baz` if `foo` resolves to `false`.
  8. Any functions are generated as being function calls for the given callback module.
  """
  @spec to_quoted([term] | term, callback_module :: atom) :: [term]
  def to_quoted(ast, callback_module) when is_list(ast) do
    Enum.reduce(ast, [], fn element, acc ->
      [quoted(element, callback_module) | acc]
    end)
  end

  defp quoted("\"" <> _ = binary, _callback_module) when is_binary(binary),
    do: String.replace(binary, "\"", "")

  defp quoted(number, _callback_module) when is_number(number), do: number
  defp quoted(boolean, _callback_module) when is_boolean(boolean), do: boolean

  defp quoted([:__property__, [a, b]], callback_module) when is_binary(b),
    do: {{:., [], [Access, :get]}, [], [quoted(a, callback_module), b]}

  defp quoted([:__attribute__, [a, b]], callback_module),
    do: {{:., [], [Access, :get]}, [], [quoted(a, callback_module), quoted(b, callback_module)]}

  defp quoted(["if", [test, yes, no]], callback_module) do
    if(quoted(test, callback_module),
      do: quoted(yes, callback_module),
      else: quoted(no, callback_module)
    )
  end

  defp quoted(["&", args], callback_module) do
    {:&, [], Enum.map(args, &quoted(&1, callback_module))}
  end

  defp quoted("&" <> index, _callback_module) do
    {:&, [], [String.to_integer(index)]}
  end

  defp quoted([function_name, arguments], callback_module)
       when is_binary(function_name) and is_list(arguments) do
    module_as_atoms =
      callback_module
      |> Module.split()
      |> Enum.map(&String.to_existing_atom/1)

    {:apply, [],
     [
       {:__aliases__, [], module_as_atoms},
       :callback,
       # NOTE:  not sure if we need this, probably do, but we'd need to expose this
       #        to the function and not to the whole expression.
       [{:context, [], nil}, function_name, Enum.map(arguments, &quoted(&1, callback_module))]
     ]}
  end

  defp quoted(list, callback_module) when is_list(list),
    do: Enum.map(list, &quoted(&1, callback_module))

  defp quoted(atom, _callback_module) when is_binary(atom),
    do: {String.to_atom(atom), [], nil}

  defp quoted(%Range{first: first, last: last, step: step}, _callback_module) do
    {:%, [],
     [
       {:__aliases__, [], [:Range]},
       {:%{}, [], [first: first, last: last, step: step]}
     ]}
  end
end
