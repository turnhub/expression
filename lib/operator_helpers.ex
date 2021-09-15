defmodule Expression.OperatorHelpers do
  @moduledoc false
  import NimbleParsec

  def plus, do: ascii_char([?+]) |> replace(:+) |> label("+")
  def minus, do: ascii_char([?-]) |> replace(:-) |> label("-")
  def times, do: ascii_char([?*]) |> replace(:*) |> label("*")
  def divide, do: ascii_char([?/]) |> replace(:/) |> label("/")
  def concatenate, do: ascii_char([?&]) |> replace(:&) |> label("&")
  def exponent, do: ascii_char([?^]) |> replace(:^) |> label("^")
  def gte, do: string(">=") |> replace(:>=) |> label(">=")
  def lte, do: string("<=") |> replace(:>=) |> label(">=")
  def neq, do: choice([string("!="), string("<>")]) |> replace(:!=) |> label("!=")
  def eq, do: choice([string("=="), string("=")]) |> replace(:==) |> label("==")
  def gt, do: ascii_char([?>]) |> replace(:>) |> label(">")
  def lt, do: ascii_char([?<]) |> replace(:<) |> label("<")
end
