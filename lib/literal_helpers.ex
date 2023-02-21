defmodule Expression.LiteralHelpers do
  @moduledoc false
  import NimbleParsec

  def int do
    optional(string("-"))
    |> times(
      choice([
        integer(min: 1),
        ignore(utf8_char([?_]))
      ]),
      min: 1
    )
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})
  end

  def float do
    optional(string("-"))
    |> concat(utf8_string([?0..?9], min: 1))
    |> concat(string("."))
    |> concat(utf8_string([?0..?9], min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_float, []})
  end

  def numeric do
    choice([int(), float()])
  end

  def single_quoted_string do
    ignore(ascii_char([?']))
    |> repeat_while(
      choice([
        string(~S(\')) |> replace(?'),
        utf8_char([])
      ]),
      {:not_single_quote, []}
    )
    |> ignore(ascii_char([?']))
    |> reduce({List, :to_string, []})
  end

  def double_quoted_string do
    ignore(ascii_char([?"]))
    |> repeat_while(
      choice([
        string(~S(\")) |> replace(?"),
        utf8_char([])
      ]),
      {:not_double_quote, []}
    )
    |> ignore(ascii_char([?"]))
    |> reduce({List, :to_string, []})
  end

  def not_double_quote(<<?", _::binary>>, context, _, _), do: {:halt, context}
  def not_double_quote(_, context, _, _), do: {:cont, context}
  def not_single_quote(<<?', _::binary>>, context, _, _), do: {:halt, context}
  def not_single_quote(_, context, _, _), do: {:cont, context}
end
