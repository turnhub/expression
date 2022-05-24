defmodule Expression.Eval2 do
  def eval!(ast, context, mod \\ Expression.Callbacks)

  def eval!({:expression, ast}, context, mod) do
    Enum.reduce(ast, [], fn ast, acc -> [eval!(ast, context, mod) || acc] end)
  end

  def eval!(
        {:variable, [{:atom, key}, {:attribute, {:atom, attribute_key}}]},
        context,
        _mod
      ) do
    get_in(context, [key, attribute_key])
  end

  def eval!({:variable, [{:atom, key}]}, context, _mod) do
    get_in(context, [key])
  end

  def eval!(ast, context, mod) do
    ast
    |> Enum.reduce([], fn ast, acc -> [eval!(ast, context, mod) | acc] end)
    |> Enum.join("")
  end
end
