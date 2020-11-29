defmodule Excellent.OperatorHelpers do
  import NimbleParsec

  def arithmatic do
    choice([
      string("+") |> replace(:+),
      string("-") |> replace(:-),
      string("*") |> replace(:*),
      string("/") |> replace(:/),
      string("^") |> replace(:^)
    ])
  end

  def concatenation do
    string("&") |> replace(:&)
  end

  def comparison do
    choice([
      string("=") |> replace(:=),
      string("<>") |> replace(:<>),
      string(">") |> replace(:>),
      string(">=") |> replace(:>=),
      string("<") |> replace(:<),
      string("<=") |> replace(:<=)
    ])
  end

  def operator do
    choice([
      arithmatic(),
      concatenation(),
      comparison()
    ])
  end
end
