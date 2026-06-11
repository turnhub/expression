defmodule NumberFunctionsTypeTest do
  @moduledoc """
  Systematic type-matrix tests for the NUMBER category of expression functions.

  These tests DOCUMENT CURRENT BEHAVIOR of the V1 engine — they do not endorse
  it. Crashes are pinned with `assert_raise` so behavioral changes surface in CI.

  Covered: fixed, power, rem, rand_between, percent, parse_float (dispatch
  finding), max (max_vargs), min (min_vargs), sum (sum_vargs).
  Excluded: abs and round — already covered by the pilot in expression_test.exs.

  NOTE on context coercion: Expression.Context coerces numeric-looking strings
  ("123", "3.14") into numbers BEFORE callbacks see them. Tests that need a
  true string argument embed a literal in the expression itself.
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix

  describe "fixed/2 and fixed/3 type handling" do
    test "formats numbers as strings with thousands separators by default" do
      assert "4.21" == Expression.evaluate_block!("fixed(4.209922, 2)")
      assert "1,234,567.89" == Expression.evaluate_block!("fixed(1234567.891, 2)")
      assert "1234567.89" == Expression.evaluate_block!("fixed(1234567.891, 2, true)")
      assert "1,234,567.89" == Expression.evaluate_block!("fixed(1234567.891, 2, false)")
    end

    test "nil raises Expression.Error (graceful 'not a number' coercion error)" do
      # Known crash behavior, documented not endorsed: coerce_to_number!/1
      # raises for nil; evaluate_block!/2 re-raises it as Expression.Error.
      assert_raise Expression.Error, ~r/expression is not a number: `nil`/, fn ->
        evaluate_with_value("fixed(value, 2)", nil)
      end
    end

    test "numeric-looking strings work (literal and context-coerced), other strings raise" do
      # Context coercion turns "123" into the integer 123 before the callback.
      assert "123.00" == evaluate_with_value("fixed(value, 2)", "123")
      # A literal numeric string survives as a string and is coerced by fixed itself.
      assert "3.14" == Expression.evaluate_block!(~s|fixed("3.14", 2)|)

      assert_raise Expression.Error, ~r/expression is not a number: `"hello"`/, fn ->
        Expression.evaluate_block!(~s|fixed("hello", 2)|)
      end
    end

    test "booleans, lists, maps and Decimals all raise Expression.Error" do
      for value <- [true, false, [1, 2], %{}, Decimal.new("1.5")] do
        assert_raise Expression.Error, ~r/expression is not a number/, fn ->
          evaluate_with_value("fixed(value, 2)", value)
        end
      end
    end

    test "extracts __value__ from complex values" do
      assert "4.21" == evaluate_with_value("fixed(value, 2)", complex_value(4.209922))
    end

    test "edge cases: zero, negatives, very large ints, very small floats" do
      assert "0.00" == Expression.evaluate_block!("fixed(0, 2)")
      assert "-5.56" == Expression.evaluate_block!("fixed(-5.555, 2)")

      assert "10,000,000,000,000,000,000.00" ==
               evaluate_with_value("fixed(value, 2)", 10 ** 19)

      assert "0.00" == evaluate_with_value("fixed(value, 2)", 1.0e-10)

      # Known crash behavior, documented not endorsed: the PARSER cannot read
      # scientific-notation literals, so this fails before fixed/3 is called.
      assert_raise Expression.Error, ~r/Unable to parse block/, fn ->
        Expression.evaluate_block!("fixed(1.0e-10, 2)")
      end
    end

    test "fixed/3 with a non-boolean no_commas raises CaseClauseError" do
      # Known crash behavior, documented not endorsed: fixed/4 only matches
      # literal true/false for no_commas; nil falls through the case.
      assert_raise CaseClauseError, fn ->
        evaluate_with_value("fixed(1.5, 2, value)", nil)
      end
    end
  end

  describe "power/2 type handling" do
    test "always returns a float, even for integer inputs" do
      assert 8.0 == Expression.evaluate_block!("power(2, 3)")
      assert 1.0 == Expression.evaluate_block!("power(0, 0)")
    end

    test "nil raises ArgumentError from :math.pow/2" do
      # Known crash behavior, documented not endorsed: nil is passed straight
      # to :math.pow/2 which rejects non-numbers.
      assert_raise ArgumentError, fn -> evaluate_with_value("power(value, 2)", nil) end
    end

    test "context-coerced numeric strings work, literal strings raise" do
      # "123" becomes the integer 123 via context coercion before power sees it.
      assert 15_129.0 == evaluate_with_value("power(value, 2)", "123")

      # Known crash behavior, documented not endorsed: power does no string
      # coercion of its own — even a numeric-looking literal string raises.
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|power("2", 3)|) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|power("hello", 3)|) end
    end

    test "booleans, lists, maps and Decimals raise ArgumentError" do
      for value <- [true, [1], %{}, Decimal.new("2")] do
        assert_raise ArgumentError, fn -> evaluate_with_value("power(value, 2)", value) end
      end
    end

    test "extracts __value__ from complex values" do
      assert 4.0 == evaluate_with_value("power(value, 2)", complex_value(2))
    end

    test "edge cases: negative base with fractional exponent, huge values" do
      # Known crash behavior, documented not endorsed: sqrt of a negative
      # number raises ArithmeticError rather than returning an error map.
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!("power(-2, 0.5)") end

      assert 1.0e38 == evaluate_with_value("power(value, 2)", 10 ** 19)
      assert 1.0715086071862673e301 == Expression.evaluate_block!("power(2, 1000)")
      assert 1.0000000000000001e-20 == evaluate_with_value("power(value, 2)", 1.0e-10)
    end
  end

  describe "rem/2 type handling" do
    test "returns integer remainder; sign follows the dividend" do
      assert 1 == Expression.evaluate_block!("rem(85, 3)")
      assert -1 == Expression.evaluate_block!("rem(-7, 3)")
    end

    test "nil raises ArithmeticError" do
      # Known crash behavior, documented not endorsed: Kernel.rem/2 with nil.
      assert_raise ArithmeticError, fn -> evaluate_with_value("rem(value, 3)", nil) end
    end

    test "context-coerced numeric strings work, literal strings raise" do
      assert 1 == evaluate_with_value("rem(value, 3)", "85")

      # Known crash behavior, documented not endorsed: no string coercion.
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!(~s|rem("85", 3)|) end
    end

    test "floats, booleans and lists raise ArithmeticError (integers only)" do
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!("rem(85.5, 3)") end

      for value <- [true, [1], %{}] do
        assert_raise ArithmeticError, fn -> evaluate_with_value("rem(value, 3)", value) end
      end
    end

    test "division by zero raises ArithmeticError" do
      # Known crash behavior, documented not endorsed: rem(85, 0) crashes
      # instead of returning an error map.
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!("rem(85, 0)") end
    end

    test "extracts __value__ from complex values and handles big integers" do
      assert 1 == evaluate_with_value("rem(value, 3)", complex_value(85))
      assert 3 == evaluate_with_value("rem(value, 7)", 10 ** 19)
    end
  end

  describe "rand_between/2 type handling" do
    test "returns an integer within the inclusive range" do
      for _ <- 1..20 do
        result = Expression.evaluate_block!("rand_between(1, 10)")
        assert is_integer(result)
        assert result in 1..10
      end
    end

    test "degenerate range returns the single member" do
      assert 5 == Expression.evaluate_block!("rand_between(5, 5)")
    end

    test "nil, floats, literal strings and booleans raise ArgumentError" do
      # Known crash behavior, documented not endorsed: Range construction
      # (min..max) requires integers on both sides.
      assert_raise ArgumentError, fn -> evaluate_with_value("rand_between(value, 10)", nil) end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!("rand_between(1.5, 10)") end
      assert_raise ArgumentError, fn -> Expression.evaluate_block!(~s|rand_between("1", 10)|) end
      assert_raise ArgumentError, fn -> evaluate_with_value("rand_between(value, 3)", true) end
    end

    test "reversed bounds still produce a value within the bounds" do
      # Surprising but current: 10..1 builds a descending range (with a
      # deprecation warning) rather than raising.
      result = Expression.evaluate_block!("rand_between(10, 1)")
      assert result in 1..10
    end

    test "extracts __value__ from complex values" do
      assert 1 == evaluate_with_value("rand_between(value, 1)", complex_value(1))
    end
  end

  describe "percent/1 type handling" do
    test "formats numbers as percentage strings with 0 precision" do
      assert "20%" == Expression.evaluate_block!("percent(0.2)")
      assert "20%" == Expression.evaluate_block!("percent(2/10)")
      assert "0%" == Expression.evaluate_block!("percent(0)")
      assert "-50%" == Expression.evaluate_block!("percent(-0.5)")
      # No clamping: values above 1.0 simply exceed 100%.
      assert "200%" == Expression.evaluate_block!("percent(2)")
    end

    test "numeric-looking strings work (both context-coerced and literal)" do
      assert "20%" == evaluate_with_value("percent(value)", "0.2")
      # percent/2 runs its argument through parse_float/1, so even a true
      # literal string is parsed.
      assert "20%" == Expression.evaluate_block!(~s|percent("0.2")|)
    end

    test "unparseable literal string returns nil (with-clause passthrough)" do
      # Surprising: parse_float/1 returns nil for unparseable strings and the
      # `with` in percent/2 passes that nil through as the result.
      assert nil == Expression.evaluate_block!(~s|percent("hello")|)
    end

    test "nil, booleans, lists and Decimals raise FunctionClauseError" do
      # Known crash behavior, documented not endorsed: parse_float/1 only has
      # clauses for numbers and binaries.
      for value <- [nil, true, [1], %{}, Decimal.new("0.2")] do
        assert_raise FunctionClauseError, fn -> evaluate_with_value("percent(value)", value) end
      end
    end

    test "extracts __value__ from complex values" do
      assert "20%" == evaluate_with_value("percent(value)", complex_value(0.2))
    end

    test "very small floats round down to 0%" do
      assert "0%" == evaluate_with_value("percent(value)", 1.0e-10)
    end
  end

  describe "parse_float/1 dispatch (number category, but not callable)" do
    # FINDING: parse_float is annotated @expression_category "number" but is
    # defined WITHOUT the ctx argument (arity 1). The callback dispatcher looks
    # for parse_float/2 (args + ctx), misses, and returns an error string. The
    # function is therefore unreachable from expressions; it only serves as an
    # internal helper (e.g. for percent/2).
    test "every invocation returns the 'wrong number of arguments' error string" do
      for expr <- ["parse_float(1.5)", ~s|parse_float("1.5")|, ~s|parse_float("abc")|] do
        assert ~s|ERROR: "wrong number of arguments to parse_float."| ==
                 Expression.evaluate_block!(expr)
      end

      assert ~s|ERROR: "wrong number of arguments to parse_float."| ==
               evaluate_with_value("parse_float(value)", nil)
    end
  end

  describe "max/N (max_vargs) type handling" do
    test "returns the maximum of numeric arguments, preserving type" do
      assert 3 == Expression.evaluate_block!("max(1, 2, 3)")
      assert 2.0 == Expression.evaluate_block!("max(1, 2.0)")
      assert 2 == Expression.evaluate_block!("max(1.5, 2, 0)")
      assert 1 == Expression.evaluate_block!("max(1)")
    end

    test "nil WINS over any number (Erlang term ordering: number < atom)" do
      # Surprising: Enum.max/1 uses term ordering, so nil (an atom) is
      # considered greater than every number.
      assert nil == evaluate_with_value("max(1, value, 3)", nil)
      assert nil == evaluate_with_value("max(value, value2)", nil, %{"value2" => nil})
    end

    test "strings, booleans, lists and maps beat numbers via term ordering" do
      # number < atom < ... < map < list < bitstring
      assert "2" == Expression.evaluate_block!(~s|max(1, "2", 3)|)
      assert "b" == Expression.evaluate_block!(~s|max(1, "b", 3)|)
      assert true == Expression.evaluate_block!("max(1, true, 3)")
      assert [9, 1] == evaluate_with_value("max(value, 1)", [9, 1])
      assert %{} == evaluate_with_value("max(1, value, 3)", %{})
      # Decimal structs are maps, so they also beat plain numbers — but the
      # comparison is structural, not numeric.
      assert Decimal.new("99") == evaluate_with_value("max(value, 1)", Decimal.new("99"))
    end

    test "extracts __value__ from complex values" do
      assert 5 == evaluate_with_value("max(value, 2)", complex_value(5))
    end
  end

  describe "min/N (min_vargs) type handling" do
    test "returns the minimum of numeric arguments" do
      assert 1 == Expression.evaluate_block!("min(1, 2, 3)")
    end

    test "numbers WIN over nil, strings, booleans and maps (term ordering)" do
      # Mirror image of max: numbers sort lowest, so non-numeric junk among
      # the arguments is silently ignored rather than raising.
      assert 1 == evaluate_with_value("min(1, value, 3)", nil)
      assert 2 == evaluate_with_value("min(value, 2)", nil)
      assert 1 == Expression.evaluate_block!(~s|min(1, "b", 3)|)
      assert 1 == Expression.evaluate_block!("min(1, true)")
      assert 1 == evaluate_with_value("min(1, value)", %{})
    end

    test "extracts __value__ from complex values" do
      assert 0 == evaluate_with_value("min(value, 2)", complex_value(0))
    end
  end

  describe "sum/N (sum_vargs) type handling" do
    test "sums numeric arguments, preserving integer/float types" do
      assert 6 == Expression.evaluate_block!("sum(1, 2, 3)")
      assert 6.5 == Expression.evaluate_block!("sum(1.5, 2, 3)")
      assert 1 == Expression.evaluate_block!("sum(1)")
    end

    test "nil raises ArithmeticError (unlike max/min which tolerate it)" do
      # Known crash behavior, documented not endorsed: Enum.sum/1 does real
      # arithmetic, so a single nil argument crashes the whole expression.
      assert_raise ArithmeticError, fn -> evaluate_with_value("sum(1, value, 3)", nil) end
    end

    test "literal strings, booleans, lists and Decimals raise ArithmeticError" do
      # Even a numeric-looking literal string is not coerced.
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!(~s|sum(1, "2", 3)|) end
      assert_raise ArithmeticError, fn -> Expression.evaluate_block!("sum(1, true, 3)") end

      for value <- [[1, 2], Decimal.new("1.5")] do
        assert_raise ArithmeticError, fn -> evaluate_with_value("sum(value, 1)", value) end
      end
    end

    test "context-coerced numeric strings work" do
      assert 6 == evaluate_with_value("sum(1, value, 3)", "2")
    end

    test "extracts __value__ from complex values" do
      assert 7 == evaluate_with_value("sum(value, 2)", complex_value(5))
    end

    test "big integers sum with exact arithmetic" do
      assert 10_000_000_000_000_000_001 == evaluate_with_value("sum(value, 1)", 10 ** 19)
    end
  end
end
