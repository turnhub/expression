defmodule Expression.V1.OperatorHelpers do
  @moduledoc false
  import NimbleParsec

  def plus(combinator \\ empty()), do: combinator |> ascii_char([?+]) |> replace(:+) |> label("+")

  def minus(combinator \\ empty()),
    do: combinator |> ascii_char([?-]) |> replace(:-) |> label("-")

  def times(combinator \\ empty()),
    do: combinator |> ascii_char([?*]) |> replace(:*) |> label("*")

  def divide(combinator \\ empty()),
    do: combinator |> ascii_char([?/]) |> replace(:/) |> label("/")

  def concatenate(combinator \\ empty()),
    do: combinator |> ascii_char([?&]) |> replace(:&) |> label("&")

  def exponent(combinator \\ empty()),
    do: combinator |> ascii_char([?^]) |> replace(:^) |> label("^")

  def gte(combinator \\ empty()), do: combinator |> string(">=") |> replace(:>=) |> label(">=")
  def lte(combinator \\ empty()), do: combinator |> string("<=") |> replace(:<=) |> label("<=")

  def neq(combinator \\ empty()),
    do: combinator |> choice([string("!="), string("<>")]) |> replace(:!=) |> label("!=")

  def eq(combinator \\ empty()),
    do: combinator |> choice([string("=="), string("=")]) |> replace(:==) |> label("==")

  def gt(combinator \\ empty()), do: combinator |> ascii_char([?>]) |> replace(:>) |> label(">")
  def lt(combinator \\ empty()), do: combinator |> ascii_char([?<]) |> replace(:<) |> label("<")
end
