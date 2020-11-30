defmodule Excellent.OperatorHelpers do
  import NimbleParsec

  def plus, do: ascii_char([?+]) |> replace(:+) |> label("+")
  def minus, do: ascii_char([?-]) |> replace(:-) |> label("-")
  def times, do: ascii_char([?*]) |> replace(:*) |> label("*")
  def divide, do: ascii_char([?/]) |> replace(:/) |> label("/")
  def concatenate, do: ascii_char([?&]) |> replace(:&) |> label("&")
  def exponent, do: ascii_char([?^]) |> replace(:^) |> label("^")
  def silly, do: ascii_char([?!]) |> replace(:!) |> label("!")
end
