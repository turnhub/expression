defmodule Expression do
  @moduledoc """
  The default implementation of the Expression library.

  This delegates the required functions to `Expression.V1`.
  """

  @behaviour Expression.Behaviour

  defdelegate evaluate!(expression, context, callback), to: Expression.V1
  defdelegate evaluate_as_string!(expression, context, callback), to: Expression.V1
  defdelegate evaluate_block!(expression, context, callback), to: Expression.V1
end
