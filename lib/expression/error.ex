defmodule Expression.Error do
  @moduledoc """
  A structured error type for expression parsing and evaluation failures.

  Provides a single, consistent error representation across the library,
  replacing the previous mix of `RuntimeError` exceptions, `{:error, string}`
  tuples, and error maps.

  ## Fields

    * `:type` - the category of error (`:parse`, `:eval`, `:type`, `:function`)
    * `:message` - a human-readable description of what went wrong
    * `:expression` - the expression string that caused the error, if available
    * `:position` - the character position in the expression where the error
      occurred, if available

  """

  defexception [:type, :message, :expression, :position]

  @type error_type :: :parse | :eval | :type | :function

  @type t :: %__MODULE__{
          type: error_type(),
          message: String.t(),
          expression: String.t() | nil,
          position: non_neg_integer() | nil
        }

  @impl true
  def message(%__MODULE__{message: message}), do: message
end
