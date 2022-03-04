defmodule Expression.Eval do
  @moduledoc """
  Take an AST and evaluate it.
  """
  import Expression.Ast, only: [fold_infixl: 1]

  def evaluate(ast, context, mod) do
    {:ok, evaluate!(ast, context, mod)}
  rescue
    error in RuntimeError -> {:error, error.message}
  end

  def evaluate!(ast, context, mod) do
    context = Expression.Context.new(context)

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
        default_value(value)

      values ->
        values
        |> Enum.map(&default_value/1)
        |> Enum.map(&to_string/1)
        |> Enum.reverse()
        |> Enum.join()
    end
  end

  def eval!(ast, _ctx, _mod) when is_number(ast), do: ast
  def eval!(ast, _ctx, _mod) when is_binary(ast), do: ast
  def eval!(ast, _ctx, _mod) when is_boolean(ast), do: ast

  def eval!({:variable, [k | remainder]}, ctx, mod) do
    value = get_var!(ctx, [k])

    Enum.reduce(remainder, value, fn
      {:list, index}, context_value when is_integer(index) ->
        Enum.at(context_value, index)

      {:list, value}, context_value ->
        index = eval!(value, ctx, mod)

        Enum.at(context_value, index)

      {:attribute, key}, context_value ->
        Map.get(context_value, key)
    end)
  end

  # def eval!({:list, value}, ctx, _mod), do: Enum.at(ctx, value)
  def eval!({:literal, value}, _ctx, _mod), do: value
  def eval!({:substitution, ast}, ctx, mod), do: eval!(fold_infixl(ast), ctx, mod)
  def eval!({:block, ast}, ctx, mod), do: eval!(fold_infixl(ast), ctx, mod)
  #  function calls without arguments
  def eval!({:function, [name]}, ctx, mod),
    do: eval!({:function, [name, {:arguments, []}]}, ctx, mod)

  def eval!({:function, [name, ast]}, ctx, mod) do
    case mod.handle(name, eval!(ast, ctx, mod), ctx) do
      {:ok, value} -> value
      {:error, reason} -> "ERROR: #{inspect(reason)}"
    end
  end

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
  def eval!({:&, [a, b]}, ctx, mod), do: [a, b] |> Enum.map_join("", &eval!(&1, ctx, mod))

  defp eval!(ast, ctx, mod, type), do: ast |> eval!(ctx, mod) |> guard_type!(type)

  defp get_var!(ctx, k), do: get_in(ctx, k) |> guard_nil!(k)

  defp default_value(%{"__value__" => default_value}), do: default_value
  defp default_value(value), do: value

  defp guard_nil!(nil, k),
    do: raise("variable #{inspect(Enum.join(k, "."))} is undefined or null")

  defp guard_nil!(v, _), do: v

  defp guard_type!(v, :num) when is_number(v), do: v
  defp guard_type!(v, :num), do: raise("expression is not a number: `#{inspect(v)}`")
end
