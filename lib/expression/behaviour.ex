defmodule Expression.Behaviour do
  @callback evaluate_as_string!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: String.t()

  @callback evaluate!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: term

  @callback evaluate_block!(
              expression :: String.t(),
              context :: Expression.ContextBehaviour.t(),
              callback_module :: atom
            ) :: term
end
