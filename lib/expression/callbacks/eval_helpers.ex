defmodule Expression.Callbacks.EvalHelpers do
  @moduledoc false

  @doc """
  Evaluate the given AST against the context and return the value
  after evaluation.
  """
  @spec eval!(term, map) :: term
  def eval!(ast, ctx) do
    ast
    |> Expression.Eval.eval!(ctx)
    |> Expression.Eval.not_founds_as_nil()
  end

  @doc """
  Evaluate the given AST values against the context and return the
  values after evaluation.
  """
  @spec eval_args!([term], map) :: [term]
  def eval_args!(args, ctx), do: Enum.map(args, &eval!(&1, ctx))
end
