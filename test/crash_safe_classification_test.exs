defmodule CrashSafeClassificationTest do
  @moduledoc """
  Deterministic guard for the crash-safe classification in
  `Expression.Test.CrashSafe`.

  `ExpressionFuzzTest` explores the same set with random inputs, but it is
  excluded from the default suite and uses a fresh seed each run. This test pins
  the classification deterministically: every function claimed crash-safe is
  evaluated against the entire type matrix on every CI run, and must return a
  value or error map rather than raising. If someone adds a function to
  `CrashSafe` that actually crashes on a matrix value, this fails immediately —
  no random seed required.
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix
  alias Expression.Test.CrashSafe

  for {label, expr} <- CrashSafe.all() do
    test "#{label} never raises across the full type matrix" do
      values = all_test_values()

      results =
        for value <- values do
          # Raising here fails the test; a value or error map is acceptable.
          Expression.evaluate_block!(unquote(expr), %{"value" => value})
        end

      assert length(results) == length(values)
    end
  end
end
