defmodule Expression.V2.Eval do
  def eval(ast, binding, callback_module) do
    binding = Keyword.put(binding, :context, %{"a" => 1})

    # convert to valid Elixir AST
    quoted = to_quoted(ast, callback_module)

    {term, _binding, _env} =
      {:__block__, [], quoted}
      |> Code.eval_quoted_with_env(binding, Code.env_for_eval([]))

    term
  end

  def to_quoted(ast, callback_module) when is_list(ast) do
    Enum.reduce(ast, [], fn element, acc ->
      [quoted(element, callback_module) | acc]
    end)
  end

  def quoted("\"" <> _ = binary, _callback_module) when is_binary(binary),
    do: String.replace(binary, "\"", "")

  def quoted(number, _callback_module) when is_number(number), do: number
  def quoted(boolean, _callback_module) when is_boolean(boolean), do: boolean

  def quoted([:__property__, [a, b]], callback_module) when is_binary(b),
    do: {{:., [], [Access, :get]}, [], [quoted(a, callback_module), b]}

  def quoted([:__attribute__, [a, b]], callback_module),
    do: {{:., [], [Access, :get]}, [], [quoted(a, callback_module), quoted(b, callback_module)]}

  def quoted(["if", [test, yes, no]], callback_module) do
    if(quoted(test, callback_module),
      do: quoted(yes, callback_module),
      else: quoted(no, callback_module)
    )
  end

  def quoted(["&", args], callback_module) do
    {:&, [], Enum.map(args, &quoted(&1, callback_module))}
  end

  def quoted("&" <> index, _callback_module) do
    {:&, [], [String.to_integer(index)]}
  end

  def quoted([function_name, arguments], callback_module)
      when is_binary(function_name) and is_list(arguments) do
    module_as_atoms =
      callback_module
      |> Module.split()
      |> Enum.map(&String.to_existing_atom/1)

    {:apply, [],
     [
       {:__aliases__, [], module_as_atoms},
       :callback,
       [{:context, [], nil}, function_name, Enum.map(arguments, &quoted(&1, callback_module))]
     ]}
  end

  def quoted(list, callback_module) when is_list(list),
    do: Enum.map(list, &quoted(&1, callback_module))

  def quoted(atom, _callback_module) when is_binary(atom),
    do: {String.to_atom(atom), [], nil}

  def quoted(%Range{first: first, last: last, step: step}, _callback_module) do
    {:%, [],
     [
       {:__aliases__, [], [:Range]},
       {:%{}, [], [first: first, last: last, step: step]}
     ]}
  end
end
