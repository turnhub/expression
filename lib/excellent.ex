defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`.
  """
  import NimbleParsec
  import Excellent.Helpers

  defparsec(:string, utf8_string([], min: 1))
  defparsec(:decimal, decimal())
  defparsec(:datetime, datetime())
  defparsec(:boolean, boolean())
  defparsec(:logic_comparison, logic_comparison())
  defparsec(:substitution, substitution())
  defparsec(:block, block())
  defparsec(:function, function())
end
