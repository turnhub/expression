defmodule Expression.BooleanHelpers do
  @moduledoc false
  import NimbleParsec

  def boolean_true(combinator \\ empty()) do
    combinator
    |> choice([string("t"), string("T")])
    |> choice([string("r"), string("R")])
    |> choice([string("u"), string("U")])
    |> choice([string("e"), string("E")])
    |> replace(true)
  end

  def boolean_false(combinator \\ empty()) do
    combinator
    |> choice([string("f"), string("F")])
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
end
