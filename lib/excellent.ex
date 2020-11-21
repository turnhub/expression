defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`.
  """
  import NimbleParsec
  import Excellent.Helpers

  defcombinator(:text, utf8_string([], 1))
  defcombinator(:whitespace, ignore(string(" ")))
  defcombinator(:decimal, decimal())
  defcombinator(:datetime, datetime())
  defcombinator(:boolean, boolean())
  defcombinator(:logic_comparison, logic_comparison())
  defcombinator(:substitution, substitution())
  defcombinator(:variable, variable())
  defcombinator(:integer, integer(min: 1))
  defcombinator(:block, block())

  defparsec(
    :expression,
    choice([
      parsec(:substitution),
      parsec(:function),
      parsec(:datetime),
      parsec(:boolean),
      parsec(:variable),
      parsec(:decimal),
      parsec(:integer),
      parsec(:logic_comparison),
      parsec(:whitespace),
      parsec(:text)
    ])
  )

  function_open =
    utf8_string([not: ?(], min: 1)
    |> string("(")

  function_close = string(")")

  defcombinator(
    :function,
    function_open
    |> repeat(
      lookahead_not(string(")"))
      |> parsec(:expression)
    )
    |> concat(function_close)
  )
end
