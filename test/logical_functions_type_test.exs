defmodule LogicalFunctionsTypeTest do
  @moduledoc """
  Systematic type-matrix tests for the "logical" category of expression
  functions: if/3, not/1, and/n, or/n, switch/n, isnumber/1, isbool/1,
  isstring/1, is_error/1, is_nil_or_empty/1.

  These tests document CURRENT behavior, they do not endorse it.

  Discovered truthiness model (Elixir semantics, after `__value__` extraction):

    falsy:  nil, false,
            error maps (their `__value__` is nil, so they collapse to nil),
            complex maps whose `__value__` is nil or false
    truthy: everything else, including 0, 0.0, "", [], %{}, "false"

  Context coercion gotcha: `Expression.evaluate_block!/2` coerces context
  values (numeric-looking strings become numbers, "true"/"false" become
  booleans) BEFORE callbacks see them. String-literal behavior is therefore
  tested with strings embedded directly in the expression source.
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix

  # The discovered truthiness table, shared by if/and/or/not.
  # {value, truthy?}
  defp truthiness_table do
    [
      {nil, false},
      {false, false},
      {true, true},
      {0, true},
      {1, true},
      {0.0, true},
      {"", true},
      {"text", true},
      {[], true},
      {%{}, true},
      # error maps carry "__value__" => nil, which eval! extracts -> nil -> falsy
      {error_value(), false},
      {complex_value(false), false},
      {complex_value(nil), false},
      {complex_value(0), true},
      {complex_value("x"), true}
    ]
  end

  describe "if/3 type handling" do
    test "truthiness table: only nil, false and nil/false-valued complex/error maps are falsy" do
      for {value, truthy?} <- truthiness_table() do
        expected = if truthy?, do: "T", else: "F"

        assert evaluate_with_value(~s|if(value, "T", "F")|, value) == expected,
               "if(#{inspect(value)}, ...) expected the #{expected} branch"
      end
    end

    test "nil condition takes the else branch" do
      assert evaluate_with_value(~s|if(value, "T", "F")|, nil) == "F"
    end

    test "unresolved variable in condition acts as nil (else branch)" do
      assert Expression.evaluate_block!(~s|if(does_not_exist, "T", "F")|, %{}) == "F"
    end

    test "complex values are unwrapped to __value__ before the truth test" do
      assert evaluate_with_value(~s|if(value, "T", "F")|, complex_value(false)) == "F"
      assert evaluate_with_value(~s|if(value, "T", "F")|, complex_value("anything")) == "T"
    end

    test "branch values preserve their type" do
      assert Expression.evaluate_block!("if(true, 1, 2)", %{}) == 1
      assert Expression.evaluate_block!("if(false, 1, 2)", %{}) == 2
    end

    test "branches are NOT lazy: the untaken branch is still evaluated and may raise" do
      # Known crash behavior, documented not endorsed: function arguments are
      # evaluated eagerly before dispatch, so a raising expression in the
      # untaken branch still raises (abs("garbage") -> ArgumentError).
      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|if(true, "ok", abs("garbage"))|, %{})
      end

      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|if(false, abs("garbage"), "ok")|, %{})
      end
    end
  end

  describe "not/1 type handling" do
    test "truthiness table: not(x) is the strict boolean negation of x's truthiness" do
      for {value, truthy?} <- truthiness_table() do
        assert evaluate_with_value("not(value)", value) == not truthy?,
               "not(#{inspect(value)}) expected #{not truthy?}"
      end
    end

    test "nil negates to true" do
      assert evaluate_with_value("not(value)", nil) == true
    end

    test "always returns a strict boolean, never the operand" do
      assert evaluate_with_value("not(value)", "text") == false
      assert evaluate_with_value("not(value)", 0) == false
    end

    test "error maps collapse to nil and negate to true" do
      assert evaluate_with_value("not(value)", error_value()) == true
    end
  end

  describe "and/n (and_vargs) type handling" do
    test "truthiness table: each value combined with a true companion" do
      for {value, truthy?} <- truthiness_table() do
        assert evaluate_with_value("and(value, true)", value) == truthy?,
               "and(#{inspect(value)}, true) expected #{truthy?}"
      end
    end

    test "returns a strict boolean even for truthy non-boolean operands" do
      assert Expression.evaluate_block!(~s|and(1, "x")|, %{}) == true
    end

    test "nil operand makes the conjunction false" do
      assert evaluate_with_value("and(true, value)", nil) == false
    end

    test "zero-argument and() is vacuously true" do
      assert Expression.evaluate_block!("and()", %{}) == true
    end

    test "does NOT short-circuit: a raising later argument still raises after false" do
      # Known crash behavior, documented not endorsed: all arguments are
      # evaluated eagerly, so and(false, abs("garbage")) raises ArgumentError
      # instead of returning false.
      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|and(false, abs("garbage"))|, %{})
      end
    end
  end

  describe "or/n (or_vargs) type handling" do
    test "truthiness table: each value combined with a false companion" do
      for {value, truthy?} <- truthiness_table() do
        result = evaluate_with_value("or(value, false)", value)
        # or returns the first truthy VALUE (unwrapped), otherwise false
        expected = if truthy?, do: Expression.Eval.default_value(value), else: false

        assert result == expected,
               "or(#{inspect(value)}, false) expected #{inspect(expected)}, got #{inspect(result)}"
      end
    end

    test "returns the first truthy value itself, not a coerced boolean" do
      assert Expression.evaluate_block!(~s|or(false, "foo")|, %{}) == "foo"
      assert evaluate_with_value(~s|or(value, "fallback")|, complex_value(42)) == 42
    end

    test "returns false (not the last operand) when all operands are falsy" do
      assert Expression.evaluate_block!("or(false, false)", %{}) == false
      assert evaluate_with_value(~s|or(value, value)|, nil) == false
    end

    test "nil and error-map operands are skipped in favour of a later truthy value" do
      assert evaluate_with_value(~s|or(value, "fallback")|, nil) == "fallback"
      assert evaluate_with_value(~s|or(value, "fallback")|, error_value()) == "fallback"
    end

    test "zero-argument or() is false" do
      assert Expression.evaluate_block!("or()", %{}) == false
    end

    test "does NOT short-circuit: a raising later argument raises even after true" do
      # Known crash behavior, documented not endorsed: although or_vargs uses
      # reduce_while internally, arguments are already evaluated eagerly before
      # dispatch, so or(true, abs("garbage")) raises ArgumentError instead of
      # returning true.
      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|or(true, abs("garbage"))|, %{})
      end
    end
  end

  describe "isnumber/1 type handling" do
    test "type matrix" do
      cases = [
        {nil, false},
        {true, false},
        {false, false},
        {0, true},
        {1, true},
        {42, true},
        {-7, true},
        {3.14, true},
        {[], false},
        {%{}, false},
        # Decimal structs are NOT considered numbers
        {Decimal.new("1.5"), false},
        {~D[2023-06-15], false},
        {error_value(), false},
        {complex_value(42), true},
        {complex_value("text"), false}
      ]

      for {value, expected} <- cases do
        assert evaluate_with_value("isnumber(value)", value) == expected,
               "isnumber(#{inspect(value)}) expected #{expected}"
      end
    end

    test "string literals: matched against regex ~r/^\\d+?.?\\d+$/ with quirks" do
      # Multi-digit and decimal strings match
      assert Expression.evaluate_block!(~s|isnumber("123")|, %{}) == true
      assert Expression.evaluate_block!(~s|isnumber("12")|, %{}) == true
      assert Expression.evaluate_block!(~s|isnumber("3.14")|, %{}) == true
      assert Expression.evaluate_block!(~s|isnumber("hello")|, %{}) == false
      assert Expression.evaluate_block!(~s|isnumber("")|, %{}) == false
    end

    test "regex quirk: single-digit string is NOT a number" do
      # The regex requires at least two digit characters, so "5" fails.
      # (Via context this is masked because "5" is coerced to integer 5.)
      assert Expression.evaluate_block!(~s|isnumber("5")|, %{}) == false
    end

    test "regex quirk: negative number string is NOT a number" do
      assert Expression.evaluate_block!(~s|isnumber("-5")|, %{}) == false
    end

    test "regex quirk: the unescaped dot matches any character, so \"1a1\" IS a number" do
      assert Expression.evaluate_block!(~s|isnumber("1a1")|, %{}) == true
    end

    test "context coercion masks string behavior: numeric string via context is a real number" do
      assert evaluate_with_value("isnumber(value)", "5") == true
      assert evaluate_with_value("isnumber(value)", "3.14") == true
    end
  end

  describe "isbool/1 type handling" do
    test "type matrix: only true and false are booleans" do
      cases = [
        {nil, false},
        {true, true},
        {false, true},
        {0, false},
        {1, false},
        {"", false},
        {[], false},
        {%{}, false},
        {error_value(), false},
        {complex_value(true), true},
        {complex_value("text"), false}
      ]

      for {value, expected} <- cases do
        assert evaluate_with_value("isbool(value)", value) == expected,
               "isbool(#{inspect(value)}) expected #{expected}"
      end
    end

    test "string literal \"true\" is not a boolean" do
      assert Expression.evaluate_block!(~s|isbool("true")|, %{}) == false
      assert Expression.evaluate_block!(~s|isbool("false")|, %{}) == false
    end

    test "context coercion masks string behavior: \"true\" via context becomes boolean true" do
      assert evaluate_with_value("isbool(value)", "true") == true
    end
  end

  describe "isstring/1 type handling" do
    test "type matrix" do
      cases = [
        {nil, false},
        {true, false},
        {0, false},
        {3.14, false},
        {"hello", true},
        {"", true},
        {[], false},
        {%{}, false},
        {~D[2023-06-15], false},
        {Decimal.new("1.5"), false},
        # error maps collapse to their nil __value__
        {error_value(), false},
        {complex_value("text"), true},
        {complex_value(42), false}
      ]

      for {value, expected} <- cases do
        assert evaluate_with_value("isstring(value)", value) == expected,
               "isstring(#{inspect(value)}) expected #{expected}"
      end
    end

    test "string literal in expression source is a string" do
      assert Expression.evaluate_block!(~s|isstring("123")|, %{}) == true
    end

    test "context coercion gotcha: numeric string via context is NOT a string anymore" do
      # Expression.Context coerces "123" to integer 123 before the callback
      # sees it, so the same characters answer differently by path.
      assert evaluate_with_value("isstring(value)", "123") == false
    end
  end

  describe "is_error/1 type handling" do
    test "type matrix: only maps with __type__ expression/v1error are errors" do
      cases = [
        {nil, false},
        {true, false},
        {0, false},
        {"hello", false},
        {[], false},
        {%{}, false},
        {error_value(), true},
        {complex_value("text"), false}
      ]

      for {value, expected} <- cases do
        assert evaluate_with_value("is_error(value)", value) == expected,
               "is_error(#{inspect(value)}) expected #{expected}"
      end
    end

    test "error detection survives __value__ extraction (uses with_defaults: false)" do
      # Every other logical function sees error maps as nil; is_error is the
      # one place the raw map is inspected, keyed solely on __type__.
      assert evaluate_with_value("is_error(value)", %{"__type__" => "expression/v1error"}) ==
               true
    end

    test "an ordinary complex map is not an error" do
      assert evaluate_with_value("is_error(value)", complex_value(nil)) == false
    end
  end

  describe "is_nil_or_empty/1 type handling" do
    test "type matrix: nil and empty string only; other empties are not 'empty'" do
      cases = [
        {nil, true},
        {"", true},
        # whitespace is not empty
        {"   ", false},
        {"x", false},
        {0, false},
        {false, false},
        # empty list and empty map are NOT considered empty
        {[], false},
        {%{}, false},
        # error maps collapse to nil __value__ -> true
        {error_value(), true},
        {complex_value(nil), true},
        {complex_value(""), true},
        {complex_value("x"), false}
      ]

      for {value, expected} <- cases do
        assert evaluate_with_value("is_nil_or_empty(value)", value) == expected,
               "is_nil_or_empty(#{inspect(value)}) expected #{expected}"
      end
    end

    test "empty string literal in expression source" do
      assert Expression.evaluate_block!(~s|is_nil_or_empty("")|, %{}) == true
    end

    test "unresolved variables count as nil" do
      assert Expression.evaluate_block!("is_nil_or_empty(does_not_exist)", %{}) == true
    end
  end

  describe "switch/n (switch_vargs) type handling" do
    test "returns the result paired with the matching case" do
      assert Expression.evaluate_block!(~s|switch(1, 1, "one", 2, "two")|, %{}) == "one"
      assert Expression.evaluate_block!(~s|switch("a", "a", "letter-a")|, %{}) == "letter-a"
    end

    test "no match with even argument count returns nil" do
      assert Expression.evaluate_block!(~s|switch(5, 1, "one", 2, "two")|, %{}) == nil
    end

    test "no match with odd argument count returns the trailing default" do
      assert Expression.evaluate_block!(~s|switch(5, 1, "one", 2, "two", "default")|, %{}) ==
               "default"
    end

    test "subject with no cases at all returns nil" do
      assert Expression.evaluate_block!("switch(1)", %{}) == nil
    end

    test "nil subject falls through to the default" do
      assert evaluate_with_value(~s|switch(value, 1, "one", "default")|, nil) == "default"
    end

    test "duplicate cases: the LAST matching pair wins, contradicting the docs" do
      # The docstring promises "the first matching value", but the
      # implementation builds a Map via Map.new/2, where later duplicate keys
      # overwrite earlier ones. Documented, not endorsed.
      assert Expression.evaluate_block!(~s|switch(1, 1, "first", 1, "second")|, %{}) == "second"
    end

    test "matching is exact-term equality: 1.0 and \"1\" do not match case 1" do
      assert Expression.evaluate_block!(~s|switch(1.0, 1, "int-one", "dflt")|, %{}) == "dflt"
      assert Expression.evaluate_block!(~s|switch("1", 1, "int-one", "dflt")|, %{}) == "dflt"
    end

    test "complex subject is unwrapped to __value__; error subject acts as nil" do
      assert evaluate_with_value(~s|switch(value, 1, "one")|, complex_value(1)) == "one"
      assert evaluate_with_value(~s|switch(value, 1, "one", "dflt")|, error_value()) == "dflt"
    end
  end
end
