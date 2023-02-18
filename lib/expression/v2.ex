defmodule Expression.V2 do
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

  @spec eval(String.t() | [term], context :: map) :: [term]
  def eval(expression, context) when is_binary(expression) do
    with {:ok, ast} <- parse(expression) do
      eval(ast, context)
    end
  end

  def eval(ast, context) when is_list(ast),
    do: Eval.eval(ast, context)
end
