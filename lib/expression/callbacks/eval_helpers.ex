defmodule Expression.Callbacks.EvalHelpers do
  @doc """
  Evaluate the given AST against the context and return the value
  after evaluation.
  """

  defmacro __using__(_opts) do
    quote do
      def eval!(ast, ctx),
        do: Expression.Callbacks.EvalHelpers.eval!(ast, ctx, __MODULE__)

      def eval_args!(ast, ctx),
        do: Expression.Callbacks.EvalHelpers.eval_args!(ast, ctx, __MODULE__)
    end
  end

  @spec eval!(term, map, module) :: term
  def eval!(ast, ctx, module) do
    ast
    |> Expression.Eval.eval!(ctx, module)
    |> Expression.Eval.not_founds_as_nil()
  end

  @doc """
  Evaluate the given AST values against the context and return the
  values after evaluation.
  """
  @spec eval_args!([term], map, module) :: [term]
  def eval_args!(args, ctx, module), do: Enum.map(args, &eval!(&1, ctx, module))
end
