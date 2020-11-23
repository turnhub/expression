defmodule Excellent.OperatorHelpers do
  import NimbleParsec

  def operator do
    choice([
      string("+"),
      string("-"),
      string("*"),
      string("/"),
      string("^"),
      string("="),
      string("<>"),
      string(">"),
      string(">="),
      string("<"),
      string("<="),
      string("&")
    ])
    |> tag(:operator)
  end
end
