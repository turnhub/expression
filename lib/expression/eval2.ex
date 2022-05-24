defmodule Expression.Eval2 do
  def eval!(ast, context, mod \\ Expression.Callbacks)

  def eval!({:expression, ast}, context, mod) do
    Enum.reduce(ast, [], fn ast, acc -> [eval!(ast, context, mod) || acc] end)
  end

  def eval!({:atom, atom}, context, _mod) do
    get_in(context, [atom])
  end

  def eval!({:attribute, [ast, {:atom, key}]}, context, mod) do
    get_in(eval!(ast, context, mod), [key])
  end

  def eval!({:function, [name: name, args: arguments]}, context, mod) do
    evaluated_arguments = Enum.reduce(arguments, [], &[eval!(&1, context, mod) | &2])

    case mod.handle(name, evaluated_arguments, context) do
      {:ok, value} -> value
      {:error, reason} -> "ERROR: #{inspect(reason)}"
    end
  end

  def eval!({:literal, literal}, _context, _mod), do: literal
  def eval!({:text, text}, _context, _mod), do: text
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

  def eval!(ast, context, mod) do
    output =
      ast
      |> Enum.reduce([], fn ast, acc -> [eval!(ast, context, mod) | acc] end)
      |> List.flatten()

    case output do
      [value] ->
        default_value(value)

      list ->
        list
        |> Enum.map(&default_value/1)
        |> Enum.map(&to_string/1)
        |> Enum.reverse()
        |> Enum.join()
    end
  end

  defp eval!(ast, ctx, mod, type), do: ast |> eval!(ctx, mod) |> guard_type!(type)

  defp guard_type!(v, :num) when is_number(v) or is_struct(v, Decimal), do: v
  defp guard_type!(v, :num), do: raise("expression is not a number: `#{inspect(v)}`")

  defp default_value(%{"__value__" => default_value}), do: default_value
  defp default_value(value), do: value
end
