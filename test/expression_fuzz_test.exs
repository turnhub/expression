defmodule ExpressionFuzzTest do
  @moduledoc """
  Property-based (fuzz) tests for the crash-safety invariant of expression
  functions.

  The invariant: evaluating a function with arbitrary runtime input must never
  RAISE. Returning a normal value, or an `expression/v1error` error map, is an
  acceptable outcome — only an unhandled exception is a failure.

  ## Scope: the crash-safe subset only

  These tests DOCUMENT CURRENT BEHAVIOR, they do not endorse it. The V1 engine
  does NOT uphold the no-crash invariant universally — many functions raise on
  unexpected input types (this is captured, function by function, in the
  `*_functions_type_test.exs` files). Fuzzing every function against
  `any_value/0` would therefore fail immediately and tell us nothing new.

  Instead this suite fuzzes only the functions that were empirically confirmed
  crash-safe across the full type matrix (nil, booleans, numbers, strings,
  lists, maps, complex `__value__` maps, Dates/DateTimes, Decimals, error maps).
  That set lives in `Expression.Test.CrashSafe` — a single source shared with
  `CrashSafeClassificationTest`, which pins the same classification
  deterministically against the type matrix on every CI run. This suite adds
  random exploration on top: if a future change makes one of those functions
  crash on some input, the property fails.

  Functions NOT in `Expression.Test.CrashSafe` currently raise on at least some
  inputs; each such crash is pinned, with its exact exception, in the
  corresponding `*_functions_type_test.exs` file. Moving a function into the
  crash-safe set is only valid once it returns an error map instead of raising.

  ## Running

  These tests are excluded from the default suite and are NOT a merge gate (a
  property test uses a fresh random seed each run, so it can legitimately go red
  when it discovers a new crashing input — unsuitable for blocking PRs). They
  run on a schedule instead, via `.github/workflows/fuzz.yml`. Run locally with:

      mix test --only fuzz

  Generations per property default to 100; set `FUZZ_MAX_RUNS` higher for a
  deeper search (the scheduled job uses 1000):

      FUZZ_MAX_RUNS=1000 mix test --only fuzz

  When a run fails, ExUnit prints the seed and StreamData prints the shrunk
  failing input; reproduce with `mix test --only fuzz --seed <N>`.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Expression.Test.FuzzHelpers
  alias Expression.Test.CrashSafe

  @moduletag :fuzz

  # Number of generations StreamData runs per property. Defaults to 100 for a
  # fast local run; the scheduled CI fuzz job sets FUZZ_MAX_RUNS higher (e.g.
  # 1000) to explore more of the input space, since it is not latency-bound.
  # A non-numeric or unset value falls back to the default rather than crashing
  # every property at setup.
  defp max_runs do
    case Integer.parse(System.get_env("FUZZ_MAX_RUNS", "100")) do
      {n, _} when n > 0 -> n
      _ -> 100
    end
  end

  # Crash-safe function lists come from Expression.Test.CrashSafe (single source,
  # shared with CrashSafeClassificationTest). Enum functions are fuzzed with an
  # enumerable-biased generator so the list/map code paths actually get
  # exercised; the others use any_value/0.

  describe "string functions never crash on arbitrary input" do
    for {label, expr} <- CrashSafe.group("string") do
      property "#{label}/1" do
        check all(value <- any_value(), max_runs: max_runs()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "logical functions never crash on arbitrary input" do
    for {label, expr} <- CrashSafe.group("logical") do
      property "#{label}" do
        check all(value <- any_value(), max_runs: max_runs()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "number functions never crash on arbitrary input" do
    for {label, expr} <- CrashSafe.group("number") do
      property "#{label}" do
        check all(value <- any_value(), max_runs: max_runs()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "enum functions never crash on arbitrary input" do
    for {label, expr} <- CrashSafe.group("enum") do
      property "#{label}" do
        check all(value <- enumerable_value(), max_runs: max_runs()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "other functions never crash on arbitrary input" do
    for {label, expr} <- CrashSafe.group("other") do
      property "#{label}" do
        check all(value <- any_value(), max_runs: max_runs()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end
end
