defmodule Expression.ContextBehaviour do
  defstruct vars: %{}, private: %{}, callback_module: nil

  @type t :: %__MODULE__{
          vars: map,
          private: map,
          callback_module: nil | atom
        }

  @callback new(vars :: map, callback_module :: atom) :: t
  @callback private(t, key :: String.t(), value :: term) :: t
end
