defmodule Expression.ContextBehaviour do
  @moduledoc """
  The context supplied to a function generated by `Expression.V2.Compile.compile/1`

  This will be expanded with support for more attributes that a callback function
  can access but normal Expression evaluation can not.
  """
  defstruct vars: %{}, private: %{}, callback_module: nil

  @type t :: %{
          __struct__: atom(),
          vars: map,
          private: map,
          callback_module: nil | atom
        }

  @callback new(vars :: map, callback_module :: atom) :: t
  @callback private(t, key :: String.t(), value :: term) :: t
end
