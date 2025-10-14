defmodule Expression.Callbacks.EvalHelpers do
  @moduledoc false

  @doc """
  Evaluate the given AST against the context and return the value
  after evaluation.
  """
  @spec eval!(term, map) :: term
  def eval!(ast, ctx, with_defaults \\ true) do
    result =
      ast
      |> Expression.Eval.eval!(ctx)

    result =
      if with_defaults do
        Expression.Eval.default_value(result)
      else
        result
      end

    Expression.Eval.not_founds_as_nil(result)
  end

  @doc """
  Evaluate the given AST values against the context and return the
  values after evaluation.
  """
  @spec eval_args!([term], map) :: [term]
  def eval_args!(args, ctx), do: Enum.map(args, &eval!(&1, ctx))
end
