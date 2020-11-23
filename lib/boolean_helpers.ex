defmodule Excellent.BooleanHelpers do
  import NimbleParsec

  def boolean_true do
    choice([string("t"), string("T")])
    |> choice([string("r"), string("R")])
    |> choice([string("u"), string("U")])
    |> choice([string("e"), string("E")])
    |> replace(true)
  end

  def boolean_false do
    choice([string("f"), string("F")])
    |> choice([string("a"), string("A")])
    |> choice([string("l"), string("L")])
    |> choice([string("s"), string("S")])
    |> choice([string("e"), string("E")])
    |> replace(false)
  end

  def boolean do
    choice([
      boolean_true(),
      boolean_false()
    ])
  end

  # def cast_boolean("true"), do: true
  # def cast_boolean("false"), do: false
  # def cast_boolean(binary), do: binary |> String.downcase() |> cast_boolean()
end
