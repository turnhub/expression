defmodule Expression.Behaviour do
  @moduledoc """
  A behaviour that all Expression implementations should implement.
  """
  @doc """
  Evaluate the expression and return the complete value of the full expression as a string.
  """
  @callback evaluate_as_string!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: String.t()

  @doc """
  Evaluate the expressions in a string and return the result
  """
  @callback evaluate!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: term

  @doc """
  Evaluate the expression block and return the result
  """
  @callback evaluate_block!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: term
end
