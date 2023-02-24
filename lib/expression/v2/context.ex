defmodule Expression.V2.Context do
  defstruct vars: %{}

  @type t :: %__MODULE__{
          vars: map
        }

  def new(vars \\ %{}), do: %__MODULE__{vars: vars}
end
