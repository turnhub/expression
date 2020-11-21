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
end
