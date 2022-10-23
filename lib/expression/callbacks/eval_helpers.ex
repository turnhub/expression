defmodule Expression.Callbacks.EvalHelpers do
  @moduledoc false

  @doc """
  Evaluate the given AST against the context and return the value
  after evaluation.
  """
  @spec eval!(term, map, module) :: term
  def eval!(ast, ctx, module \\ __MODULE__) do
    ast
    |> Expression.Eval.eval!(ctx, module)
    |> Expression.Eval.not_founds_as_nil()
  end

  @doc """
  Evaluate the given AST values against the context and return the
  values after evaluation.
  """
  @spec eval_args!([term], map, module) :: [term]
  def eval_args!(args, ctx, module \\ __MODULE__), do: Enum.map(args, &eval!(&1, ctx, module))
end
