defmodule Expression.OperatorHelpers do
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

  def and_op(combinator \\ empty()),
    do:
      combinator
      |> string("and")
      |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
      |> replace(:and)
      |> label("and")

  def or_op(combinator \\ empty()),
    do:
      combinator
      |> string("or")
      |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
      |> replace(:or)
      |> label("or")

  def not_op(combinator \\ empty()),
    do:
      combinator
      |> string("not")
      |> lookahead_not(ascii_char([?a..?z, ?A..?Z, ?0..?9, ?_]))
      |> replace(:not)
      |> label("not")
end
