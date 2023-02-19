defmodule Expression.V2.Eval do
  def eval(quoted, binding) do
    binding = Keyword.put(binding, :context, %{})

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

  def quoted(string, _callback_module) when is_binary(string) do
    {String.to_atom(string), [], nil}
  end

  def quoted(number, _callback_module) when is_number(number), do: number

  def quoted([:__property__, [a, b]], callback_module) when is_binary(b),
    do: {{:., [], [quoted(a, callback_module), String.to_atom(b)]}, [], []}

  def quoted([:__attribute__, [a, b]], callback_module),
    do: {{:., [], [quoted(a, callback_module), String.to_atom(b)]}, [], []}

  def quoted([function_name, arguments], callback_module) when is_binary(function_name) do
    module_as_atoms =
      callback_module
      |> Module.split()
      |> Enum.map(&String.to_atom/1)

    {:apply, [],
     [
       {:__aliases__, [], module_as_atoms},
       :callback,
       [{:context, [], nil}, function_name, Enum.map(arguments, &quoted(&1, callback_module))]
     ]}
  end
end
