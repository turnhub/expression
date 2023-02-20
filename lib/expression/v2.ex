defmodule Expression.V2 do
  @moduledoc """
  A second attempt at the parser, hopefully a little easier to read & maintain
  """
  alias Expression.V2.Parser
  alias Expression.V2.Eval

  @spec parse(String.t()) ::
          {:ok, [term]}
          | {:error, reason :: String.t(), bad_parts :: String.t()}
  def parse(expression) do
    case Parser.parse(expression) do
      {:ok, ast, "", _, _, _} ->
        {:ok, ast}

      {:ok, _ast, remaining, _, _, _} ->
        {:error, "Unable to parse remainder", remaining}
    end
  end

  @spec eval(String.t() | [term], context :: map, callback_module :: atom) :: [term]
  def eval(expression, context, callback_module) when is_binary(expression) do
    with {:ok, parts} <- parse(expression) do
      Enum.map(parts, fn
        part when is_list(part) -> eval([part], context, callback_module)
        other -> other
      end)
    end
  end

  def eval(ast, context, callback_module) when is_list(ast) do
    Eval.eval(ast, Enum.into(context, []), callback_module)
  end
end
