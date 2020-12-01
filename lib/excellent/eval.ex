defmodule Excellent.Eval do
  import Excellent.Ast, only: [fold_infixl: 1]

  def evaluate(ast, context, mod) do
    resp =
      ast
      |> Enum.reduce([], fn
        {:escaped_at, ["@@"]}, acc ->
          ["@" | acc]

        {:substitution, ast}, acc ->
          [eval!(fold_infixl(ast), context, mod) | acc]

        {:text, text}, acc ->
          [text | acc]
      end)

    case resp do
      [value] ->
        {:ok, value}

      values ->
        {:ok,
         values
         |> Enum.map(&to_string/1)
         |> Enum.reverse()
         |> Enum.join()}
    end
  end

  def eval!(ast, _ctx, _mod) when is_number(ast), do: ast
  def eval!(ast, _ctx, _mod) when is_binary(ast), do: ast
  def eval!(ast, _ctx, _mod) when is_boolean(ast), do: ast
  def eval!({:variable, k}, ctx, _mod), do: get_var!(ctx, k)
  def eval!({:literal, value}, _ctx, _mod), do: value
  def eval!({:substitution, ast}, ctx, mod), do: eval!(fold_infixl(ast), ctx, mod)
  def eval!({:block, ast}, ctx, mod), do: eval!(fold_infixl(ast), ctx, mod)
  def eval!({:function, [name]}, ctx, mod), do: mod.handle(name, [], ctx)
  def eval!({:function, [name, ast]}, ctx, mod), do: mod.handle(name, eval!(ast, ctx, mod), ctx)
  def eval!({:arguments, ast}, ctx, mod), do: Enum.map(ast, &eval!(&1, ctx, mod))
  def eval!({:+, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) + eval!(b, ctx, mod, :num)
  def eval!({:-, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) - eval!(b, ctx, mod, :num)
  def eval!({:*, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) * eval!(b, ctx, mod, :num)
  def eval!({:/, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) / eval!(b, ctx, mod, :num)
  def eval!({:>, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) > eval!(b, ctx, mod, :num)
  def eval!({:>=, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) >= eval!(b, ctx, mod, :num)
  def eval!({:<, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) < eval!(b, ctx, mod, :num)
  def eval!({:<=, [a, b]}, ctx, mod), do: eval!(a, ctx, mod, :num) <= eval!(b, ctx, mod, :num)
  def eval!({:==, [a, b]}, ctx, mod), do: eval!(a, ctx, mod) == eval!(b, ctx, mod)
  def eval!({:!=, [a, b]}, ctx, mod), do: eval!(a, ctx, mod) != eval!(b, ctx, mod)
  def eval!({:^, [a, b]}, ctx, mod), do: :math.pow(eval!(a, ctx, mod), eval!(b, ctx, mod))
  def eval!({:&, [a, b]}, ctx, mod), do: [a, b] |> Enum.map(&eval!(&1, ctx, mod)) |> Enum.join("")

  defp eval!(ast, ctx, mod, type), do: ast |> eval!(ctx, mod) |> guard_type!(type)

  defp get_var!(ctx, k), do: get_in(ctx, k) |> guard_nil!(k)
  defp guard_nil!(nil, k), do: raise("variable #{k} undefined or null")
  defp guard_nil!(v, _), do: v

  defp guard_type!(v, :bool) when is_boolean(v), do: v
  defp guard_type!(v, :bool), do: raise("expression is not a boolean: `#{inspect(v)}`")
  defp guard_type!(v, :num) when is_number(v), do: v
  defp guard_type!(v, :num), do: raise("expression is not a number: `#{inspect(v)}`")
end
