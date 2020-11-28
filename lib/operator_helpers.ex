defmodule Excellent.OperatorHelpers do
  import NimbleParsec

  def arithmatic do
    choice([
      string("+"),
      string("-"),
      string("*"),
      string("/"),
      string("^")
    ])
  end

  def concatenation do
    string("&")
  end

  def comparison do
    choice([
      string("="),
      string("<>"),
      string(">"),
      string(">="),
      string("<"),
      string("<=")
    ])
  end

  def operator do
    choice([
      arithmatic(),
      concatenation(),
      comparison()
    ])
    |> tag(:operator)
  end
end
