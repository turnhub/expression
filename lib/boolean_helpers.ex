defmodule Expression.BooleanHelpers do
  @moduledoc false
  import NimbleParsec

  def boolean_true(combinator \\ empty()) do
    combinator
    |> string("t")
    |> string("r")
    |> string("u")
    |> string("e")
    |> replace(true)
  end

  def boolean_false(combinator \\ empty()) do
    combinator
    |> string("f")
    |> string("a")
    |> string("l")
    |> string("s")
    |> string("e")
    |> replace(false)
  end

  def boolean do
    choice([
      boolean_true(),
      boolean_false()
    ])
  end
end
