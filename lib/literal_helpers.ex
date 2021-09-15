defmodule Expression.LiteralHelpers do
  @moduledoc false
  import NimbleParsec

  def int do
    optional(string("-"))
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})
  end

  def decimal do
    optional(string("-"))
    |> concat(integer(min: 1))
    |> concat(string("."))
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({Decimal, :new, []})
  end

  def numeric do
    choice([int(), decimal()])
  end

  def single_quoted_string do
    ignore(string(~s(')))
    |> repeat(
      lookahead_not(ascii_char([?']))
      |> choice([string(~s(\')), utf8_char([])])
    )
    |> ignore(string(~s(')))
    |> reduce({List, :to_string, []})
  end

  def double_quoted_string do
    ignore(string(~s(")))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([string(~s(\")), utf8_char([])])
    )
    |> ignore(string(~s(")))
    |> reduce({List, :to_string, []})
  end
end
