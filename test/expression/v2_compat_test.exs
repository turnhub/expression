defmodule Expression.V2CompatTest do
  @moduledoc """
  Proves that `mode: :v2` on the evaluation entry points restores the v2
  evaluation semantics that changed in v3:

    1. context keys are lowercased (`lowercase_keys: true`)
    2. string values are coerced to typed equivalents (`coerce_strings: true`)

  Also pins down what did NOT change: operator semantics are identical in
  v2 and v3. In particular the parser collapses `=` and `==` into the same
  operator (see `OperatorHelpers.eq/1`), so the "date-only `=`" behavior
  documented for v2 was unreachable — DateTime equality always compares the
  full value, in both versions and both modes.
  """
  use ExUnit.Case, async: true

  @morning ~U[2023-01-15 10:00:00Z]
  @evening ~U[2023-01-15 22:30:00Z]

  describe "context string coercion" do
    test "evaluate!/4 coerces string values under mode: :v2" do
      ctx = %{"age" => "30", "opted_in" => "true", "date" => "2020-12-13T23:34:45"}

      assert Expression.evaluate!("@age", ctx, Expression.Callbacks, mode: :v2) == 30
      assert Expression.evaluate!("@opted_in", ctx, Expression.Callbacks, mode: :v2) == true

      assert Expression.evaluate!("@date", ctx, Expression.Callbacks, mode: :v2) ==
               ~U[2020-12-13 23:34:45.0Z]
    end

    test "evaluate!/4 preserves string values by default" do
      ctx = %{"age" => "30", "opted_in" => "true", "date" => "2020-12-13T23:34:45"}

      assert Expression.evaluate!("@age", ctx) == "30"
      assert Expression.evaluate!("@opted_in", ctx) == "true"
      assert Expression.evaluate!("@date", ctx) == "2020-12-13T23:34:45"
    end

    test "evaluate_as_string!/4 renders coerced datetimes in the v2 shape" do
      ctx = %{"date" => "2020-12-13T23:34:45"}

      assert Expression.evaluate_as_string!("@date", ctx, Expression.Callbacks, mode: :v2) ==
               "2020-12-13T23:34:45.0Z"

      assert Expression.evaluate_as_string!("@date", ctx) == "2020-12-13T23:34:45"
    end

    test "coerced values participate in comparisons under mode: :v2" do
      ctx = %{"age" => "30"}

      assert Expression.evaluate!("@(age > 21)", ctx, Expression.Callbacks, mode: :v2) == true
    end
  end

  describe "context key lowercasing" do
    test "maps resolved under mode: :v2 have lowercased keys" do
      ctx = %{"Contact" => %{"Name" => "Jane"}}

      assert Expression.evaluate!("@contact", ctx, Expression.Callbacks, mode: :v2) ==
               %{"name" => "Jane"}

      assert Expression.evaluate!("@contact", ctx) == %{"Name" => "Jane"}
    end

    test "variable lookup is case-insensitive in both modes" do
      ctx = %{"Contact" => %{"Name" => "Jane"}}

      assert Expression.evaluate!("@contact.name", ctx, Expression.Callbacks, mode: :v2) ==
               "Jane"

      assert Expression.evaluate!("@contact.name", ctx) == "Jane"
    end
  end

  describe "operator semantics are mode-independent" do
    test "`=` and `==` on DateTimes compare the full value in both modes" do
      ctx = %{"a" => @morning, "b" => @evening, "same" => @morning}

      for opts <- [[], [mode: :v2]] do
        assert Expression.evaluate!("@(a = b)", ctx, Expression.Callbacks, opts) == false
        assert Expression.evaluate!("@(a == b)", ctx, Expression.Callbacks, opts) == false
        assert Expression.evaluate!("@(a = same)", ctx, Expression.Callbacks, opts) == true
        assert Expression.evaluate!("@(a == same)", ctx, Expression.Callbacks, opts) == true
      end
    end
  end

  describe "entry point coverage" do
    test "evaluate_block!/4 and evaluate_block/4 accept the mode" do
      ctx = %{"age" => "30"}

      assert Expression.evaluate_block!("age", ctx, Expression.Callbacks, mode: :v2) == 30
      assert Expression.evaluate_block!("age", ctx) == "30"

      assert Expression.evaluate_block("age", ctx, Expression.Callbacks, mode: :v2) ==
               {:ok, 30}
    end

    test "evaluate/4 accepts the mode" do
      ctx = %{"age" => "30"}

      assert Expression.evaluate("@age", ctx, Expression.Callbacks, mode: :v2) == {:ok, 30}
      assert Expression.evaluate("@age", ctx) == {:ok, "30"}
    end

    test "evaluate_as_boolean!/4 accepts the mode" do
      ctx = %{"opted_in" => "true"}

      assert Expression.evaluate_as_boolean!("@opted_in", ctx, Expression.Callbacks, mode: :v2) ==
               true
    end

    test "evaluate_template!/4 accepts the mode" do
      ctx = %{"date" => "2020-12-13T23:34:45"}

      assert Expression.evaluate_template!("on @date", ctx, Expression.Callbacks, mode: :v2) ==
               "on 2020-12-13T23:34:45.0Z"
    end

    test "nested template literals see the v2-normalized context" do
      ctx = %{"Date" => "2020-12-13T23:34:45"}

      assert Expression.evaluate_as_string!(
               ~s[@if(true, "on @date", "")],
               ctx,
               Expression.Callbacks,
               mode: :v2
             ) == "on 2020-12-13T23:34:45.0Z"
    end
  end

  describe "explicit flags vs mode expansion" do
    test "explicitly passed flags override the mode expansion" do
      ctx = %{"age" => "30", "Contact" => %{"Name" => "Jane"}}

      assert Expression.evaluate!("@age", ctx, Expression.Callbacks,
               mode: :v2,
               coerce_strings: false
             ) == "30"

      assert Expression.evaluate!("@contact", ctx, Expression.Callbacks,
               mode: :v2,
               lowercase_keys: false
             ) == %{"Name" => "Jane"}
    end

    test "mode: :v3 keeps the v3 defaults" do
      ctx = %{"age" => "30"}

      assert Expression.evaluate!("@age", ctx, Expression.Callbacks, mode: :v3) == "30"
    end

    test "individual flags work without the mode sugar" do
      ctx = %{"age" => "30"}

      assert Expression.evaluate!("@age", ctx, Expression.Callbacks, coerce_strings: true) == 30
    end
  end
end
