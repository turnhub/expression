defmodule EnumFunctionsTypeTest do
  @moduledoc """
  Systematic type-matrix tests for the ENUM (list/collection) category of
  expression functions.

  These tests DOCUMENT CURRENT BEHAVIOR of the V1 engine — they do not endorse
  it. Crashes are pinned with `assert_raise` so behavioral changes surface in
  CI. Surprising-but-real behaviors get a `# Surprising:` comment explaining
  the mechanism.

  Covered: filter, find, map, reduce, chunk_every, reject, uniq, sort_by,
  with_index, append, delete, has_member, has_all_members, has_any_member,
  concatenate (concatenate_vargs). Plus a dispatch finding for `first`.

  Lambda syntax in THIS engine uses Elixir's capture form:
    * single-argument predicates/mappers: `& &1 == "B"`, `&(&1 * &1)`
    * indexing into a list item:           `& &1[0] == "Hi"`
    * reduce reducers get item then acc:    `& &1 + &2` (item = &1, acc = &2)
  NOTE: the parser reads `<>` as the `!=` operator, so string-concatenation
  lambdas silently become comparisons — arithmetic (`+`) is used here instead.

  A recurring theme: the "Invalid enumerable" guard is applied INCONSISTENTLY.
  filter/map/reduce/reject/sort_by/chunk_every return an error map for a
  non-enumerable input; uniq/with_index quietly return `[]`; and find/has_member
  have NO guard at all, so they raise Protocol.UndefinedError on the same input.

  NOTE on context coercion: `Expression.Context` coerces context values BEFORE
  callbacks see them — numeric-looking strings ("123", "3.14") become numbers,
  and ISO-date / "true"/"false" strings become structs/booleans. To exercise a
  function with a genuine string argument, the string is embedded as a LITERAL
  in the expression source, not passed via context.
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix

  @invalid_enumerable_error %{
    "__type__" => "expression/v1error",
    "__value__" => nil,
    "error" => true,
    "message" => "Invalid enumerable"
  }

  describe "filter/2 type handling" do
    test "keeps only items for which the lambda is truthy" do
      assert ["B", "B"] ==
               Expression.evaluate_block!(~s|filter(["A", "B", "C", "B"], & &1 == "B")|)
    end

    test "empty list returns empty list" do
      assert [] == Expression.evaluate_block!(~s|filter([], & &1 == "B")|)
    end

    test "non-enumerable inputs (nil, number, literal string) return an Invalid enumerable error map" do
      # filter guards with is_nil/Enumerable.impl_for, returning an error map
      # rather than raising. Strings are NOT Enumerable in Elixir.
      assert @invalid_enumerable_error == evaluate_with_value(~s|filter(value, & &1 == "B")|, nil)
      assert @invalid_enumerable_error == evaluate_with_value(~s|filter(value, & &1 == "B")|, 42)

      assert @invalid_enumerable_error ==
               Expression.evaluate_block!(~s|filter("hi", & &1 == "B")|)
    end

    test "a map IS enumerable: it filters its key/value tuples" do
      # Surprising: maps satisfy Enumerable, so filter iterates {key, value}
      # tuples; none equal the scalar "B", giving an empty list.
      assert [] == evaluate_with_value(~s|filter(value, & &1 == "B")|, %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert ["B", "B"] ==
               evaluate_with_value(
                 ~s|filter(value, & &1 == "B")|,
                 complex_value(["A", "B", "C", "B"])
               )
    end

    test "error-map argument collapses to nil __value__ and returns the error map" do
      assert @invalid_enumerable_error ==
               evaluate_with_value(~s|filter(value, & &1 == "B")|, error_value())
    end
  end

  describe "find/2 type handling" do
    test "returns the first item for which the lambda is truthy" do
      assert ["Hi", "World"] ==
               Expression.evaluate_block!(
                 ~s|find([["Hello", "World"], ["Hi", "World"]], & &1[0] == "Hi")|
               )
    end

    test "no match returns nil; empty list returns nil" do
      assert nil == Expression.evaluate_block!(~s|find([1, 2, 3], & &1 == 9)|)
      assert nil == Expression.evaluate_block!(~s|find([], & &1 == 1)|)
    end

    test "non-enumerable inputs raise Protocol.UndefinedError (NO guard, unlike filter)" do
      # Surprising asymmetry, documented not endorsed: find has no is_nil /
      # Enumerable.impl_for guard, so nil and literal strings reach Enum.map and
      # crash instead of returning an Invalid enumerable error map.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|find(value, & &1 == 1)|, nil)
      end

      assert_raise Protocol.UndefinedError, fn ->
        Expression.evaluate_block!(~s|find("hi", & &1 == "h")|)
      end
    end

    test "error-map argument collapses to nil and therefore also raises" do
      # The error map's __value__ is nil, which then hits the unguarded Enum.map.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|find(value, & &1 == 1)|, error_value())
      end
    end

    test "extracts __value__ from complex values" do
      assert 2 == evaluate_with_value(~s|find(value, & &1 == 2)|, complex_value([1, 2, 3]))
    end
  end

  describe "map/2 type handling" do
    test "applies the mapper to every item, including over a Range" do
      assert [1, 4, 9] == Expression.evaluate_block!("map(1..3, &(&1 * &1))")
      assert [1, 4, 9] == Expression.evaluate_block!("map([1, 2, 3], &(&1 * &1))")
    end

    test "empty list returns empty list" do
      assert [] == Expression.evaluate_block!("map([], &(&1 * &1))")
    end

    test "non-enumerable inputs (nil, literal string) return an Invalid enumerable error map" do
      assert @invalid_enumerable_error == evaluate_with_value("map(value, &(&1 * &1))", nil)
      assert @invalid_enumerable_error == Expression.evaluate_block!(~s|map("hi", &(&1))|)
    end

    test "a map IS enumerable: the mapper receives {key, value} tuples" do
      # Surprising: maps satisfy Enumerable, so the identity mapper yields the
      # underlying key/value tuples rather than an error.
      assert [{"a", 1}] == evaluate_with_value("map(value, &(&1))", %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert [1, 4, 9] == evaluate_with_value("map(value, &(&1 * &1))", complex_value([1, 2, 3]))
    end
  end

  describe "reduce/3 type handling" do
    test "reduces with the item as &1 and the accumulator as &2" do
      assert 6 == Expression.evaluate_block!("reduce(1..3, 0, & &1 + &2)")
      assert 11 == Expression.evaluate_block!("reduce([1, 2, 3], 5, & &1 + &2)")
    end

    test "empty list returns the initial accumulator unchanged" do
      assert 5 == Expression.evaluate_block!("reduce([], 5, & &1 + &2)")
    end

    test "non-enumerable inputs (nil, literal string) return an Invalid enumerable error map" do
      assert @invalid_enumerable_error == evaluate_with_value("reduce(value, 0, & &1 + &2)", nil)
      assert @invalid_enumerable_error == Expression.evaluate_block!(~s|reduce("hi", 0, & &1)|)
    end

    test "extracts __value__ from complex values" do
      assert 6 == evaluate_with_value("reduce(value, 0, & &1 + &2)", complex_value([1, 2, 3]))
    end
  end

  describe "chunk_every/2 type handling" do
    test "splits an enumerable into chunks of the given size" do
      assert [[1, 2], [3, 4], [5]] ==
               Expression.evaluate_block!("chunk_every([1, 2, 3, 4, 5], 2)")

      assert [] == Expression.evaluate_block!("chunk_every([], 2)")
    end

    test "non-enumerable inputs (nil, literal string, number) return an Invalid enumerable error map" do
      assert @invalid_enumerable_error == evaluate_with_value("chunk_every(value, 2)", nil)
      assert @invalid_enumerable_error == Expression.evaluate_block!(~s|chunk_every("hello", 2)|)
      assert @invalid_enumerable_error == evaluate_with_value("chunk_every(value, 2)", 42)
    end

    test "a map IS enumerable: it chunks its key/value tuples" do
      # Surprising: maps satisfy Enumerable, so they chunk into lists of tuples
      # rather than returning an error.
      assert [[{"a", 1}]] == evaluate_with_value("chunk_every(value, 2)", %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert [[1, 2, 3], [4, 5]] ==
               evaluate_with_value("chunk_every(value, 3)", complex_value([1, 2, 3, 4, 5]))
    end
  end

  describe "reject/2 type handling" do
    test "drops items for which the lambda is truthy" do
      assert ["A", "C"] ==
               Expression.evaluate_block!(~s|reject(["A", "B", "C", "B"], & &1 == "B")|)

      assert [] == Expression.evaluate_block!(~s|reject([], & &1 == "B")|)
    end

    test "non-enumerable inputs (nil, literal string) return an Invalid enumerable error map" do
      assert @invalid_enumerable_error == evaluate_with_value(~s|reject(value, & &1 == "B")|, nil)

      assert @invalid_enumerable_error ==
               Expression.evaluate_block!(~s|reject("hi", & &1 == "B")|)
    end

    test "extracts __value__ from complex values" do
      assert ["A"] ==
               evaluate_with_value(~s|reject(value, & &1 == "B")|, complex_value(["A", "B"]))
    end
  end

  describe "uniq/1 type handling" do
    test "removes duplicate values, preserving first-seen order" do
      assert ["A", "B", "C"] == Expression.evaluate_block!(~s|uniq(["A", "B", "C", "B"])|)
      assert [] == Expression.evaluate_block!("uniq([])")
    end

    test "non-enumerable inputs return [] (NOT an error map, unlike filter/map)" do
      # Surprising asymmetry, documented not endorsed: uniq's guard returns an
      # empty list for nil / literal string / number, where filter and map would
      # return an Invalid enumerable error map.
      assert [] == evaluate_with_value("uniq(value)", nil)
      assert [] == Expression.evaluate_block!(~s|uniq("hello")|)
      assert [] == evaluate_with_value("uniq(value)", 42)
    end

    test "a map IS enumerable: it de-duplicates its key/value tuples" do
      assert [{"a", 1}, {"b", 1}] == evaluate_with_value("uniq(value)", %{"a" => 1, "b" => 1})
    end

    test "error-map argument collapses to nil __value__ and returns []" do
      assert [] == evaluate_with_value("uniq(value)", error_value())
    end

    test "extracts __value__ from complex values" do
      assert [1, 2] == evaluate_with_value("uniq(value)", complex_value([1, 1, 2]))
    end
  end

  describe "sort_by/2 type handling" do
    test "sorts by the result of the (single-argument) sorter lambda" do
      # The sorter receives each item; & &1 sorts by the item itself.
      assert ["a", "b", "c"] == Expression.evaluate_block!(~s|sort_by(["c", "a", "b"], & &1)|)
      assert [] == Expression.evaluate_block!(~s|sort_by([], & &1)|)
    end

    test "non-enumerable inputs (nil, literal string) return an Invalid enumerable error map" do
      assert @invalid_enumerable_error == evaluate_with_value(~s|sort_by(value, & &1)|, nil)
      assert @invalid_enumerable_error == Expression.evaluate_block!(~s|sort_by("hi", & &1)|)
    end

    test "extracts __value__ from complex values" do
      assert [1, 2, 3] == evaluate_with_value("sort_by(value, & &1)", complex_value([3, 1, 2]))
    end
  end

  describe "with_index/1 type handling" do
    test "wraps each item with its zero-based index" do
      assert [["A", 0], ["B", 1], ["C", 2]] ==
               Expression.evaluate_block!(~s|with_index(["A", "B", "C"])|)

      assert [] == Expression.evaluate_block!("with_index([])")
    end

    test "non-enumerable inputs return [] (NOT an error map)" do
      # Like uniq, with_index's guard quietly returns [] for nil / literal
      # string / number rather than an Invalid enumerable error map.
      assert [] == evaluate_with_value("with_index(value)", nil)
      assert [] == Expression.evaluate_block!(~s|with_index("hi")|)
      assert [] == evaluate_with_value("with_index(value)", 42)
    end

    test "a map IS enumerable: it indexes its key/value tuples" do
      assert [[{"a", 1}, 0]] == evaluate_with_value("with_index(value)", %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert [["A", 0], ["B", 1]] ==
               evaluate_with_value("with_index(value)", complex_value(["A", "B"]))
    end
  end

  describe "append/2 type handling" do
    test "appends a scalar item, or concatenates a list payload" do
      assert ["A", "B", "C"] == Expression.evaluate_block!(~s|append(["A", "B"], "C")|)

      assert ["A", "B", "C", "B"] ==
               Expression.evaluate_block!(~s|append(["A", "B"], ["C", "B"])|)

      assert ["C"] == Expression.evaluate_block!(~s|append([], "C")|)
    end

    test "a nil payload is appended as a single nil element" do
      # Surprising: nil is not a list, so it is wrapped in [nil] and appended
      # rather than being ignored.
      assert ["A", nil] == evaluate_with_value(~s|append(["A"], value)|, nil)
    end

    test "a non-list FIRST argument raises Protocol.UndefinedError" do
      # Known crash behavior, documented not endorsed: Enum.concat/2 requires the
      # first argument to be enumerable; nil, numbers and literal strings fail.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|append(value, "C")|, nil)
      end

      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|append(value, "C")|, 42)
      end

      assert_raise Protocol.UndefinedError, fn ->
        Expression.evaluate_block!(~s|append("ab", "C")|)
      end
    end

    test "a map FIRST argument IS enumerable: its tuples are concatenated" do
      assert [{"a", 1}, "C"] == evaluate_with_value(~s|append(value, "C")|, %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert ["A", "B", "C"] ==
               evaluate_with_value(~s|append(value, "C")|, complex_value(["A", "B"]))
    end
  end

  describe "delete/2 type handling" do
    test "deletes a key from a map; a missing key leaves the map unchanged" do
      assert %{"age" => 32} ==
               evaluate_with_value(~s|delete(value, "gender")|, %{"gender" => "?", "age" => 32})

      assert %{"age" => 32} == evaluate_with_value(~s|delete(value, "missing")|, %{"age" => 32})
    end

    test "non-map inputs (nil, list, literal string, number) raise BadMapError" do
      # Known crash behavior, documented not endorsed: Map.delete/2 requires a
      # map and has no graceful fallback in delete/3.
      assert_raise BadMapError, fn -> evaluate_with_value(~s|delete(value, "k")|, nil) end
      assert_raise BadMapError, fn -> evaluate_with_value(~s|delete(value, "k")|, [1, 2, 3]) end
      assert_raise BadMapError, fn -> Expression.evaluate_block!(~s|delete("hi", "k")|) end
      assert_raise BadMapError, fn -> evaluate_with_value(~s|delete(value, "k")|, 42) end
    end

    test "extracts the inner map from complex values" do
      assert %{"a" => 2} ==
               evaluate_with_value(~s|delete(value, "g")|, complex_value(%{"g" => 1, "a" => 2}))
    end
  end

  describe "has_member/2 type handling" do
    test "returns whether the list contains the item" do
      assert true == Expression.evaluate_block!(~s|has_member(["A", "B", "C"], "C")|)
      assert false == Expression.evaluate_block!(~s|has_member(["A", "B"], "Z")|)
      assert false == Expression.evaluate_block!(~s|has_member([], "C")|)
    end

    test "non-enumerable first arguments raise Protocol.UndefinedError (NO guard)" do
      # Surprising asymmetry, documented not endorsed: has_member calls
      # Enum.member?/2 directly with no is_list guard, so nil, numbers and
      # literal strings crash — unlike has_all_members/has_any_member which guard.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|has_member(value, "C")|, nil)
      end

      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|has_member(value, "C")|, 42)
      end

      assert_raise Protocol.UndefinedError, fn ->
        Expression.evaluate_block!(~s|has_member("abc", "a")|)
      end
    end

    test "a map IS enumerable: membership is tested against its key/value tuples" do
      # Surprising: a bare key is not a member; only a {key, value} tuple would be.
      assert false == evaluate_with_value(~s|has_member(value, "a")|, %{"a" => 1})
    end

    test "error-map first argument collapses to nil and raises" do
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|has_member(value, "C")|, error_value())
      end
    end

    test "extracts __value__ from complex values" do
      assert true ==
               evaluate_with_value(~s|has_member(value, "C")|, complex_value(["A", "B", "C"]))
    end
  end

  describe "has_all_members/2 type handling" do
    test "returns whether the list contains every provided item" do
      assert true == Expression.evaluate_block!(~s|has_all_members(["A", "B", "C"], ["C", "B"])|)
      assert false == Expression.evaluate_block!(~s|has_all_members(["A", "B"], ["C", "B"])|)
    end

    test "an empty items list is vacuously true" do
      # Surprising: Enum.all?/2 over an empty list is true, so every list
      # "contains all" of nothing.
      assert true == Expression.evaluate_block!(~s|has_all_members(["A"], [])|)
    end

    test "non-list arguments return false (guarded, never raises)" do
      # has_all_members guards with is_list on BOTH arguments, so any non-list
      # input degrades to false rather than crashing.
      assert false == evaluate_with_value(~s|has_all_members(value, ["C"])|, nil)
      assert false == evaluate_with_value(~s|has_all_members(["A"], value)|, nil)
      assert false == Expression.evaluate_block!(~s|has_all_members("ab", ["a"])|)
      assert false == evaluate_with_value(~s|has_all_members(value, ["a"])|, %{"a" => 1})
    end

    test "extracts __value__ from complex values" do
      assert true ==
               evaluate_with_value(
                 "has_all_members(value, items)",
                 complex_value(["A", "B", "C"]),
                 %{"items" => complex_value(["C", "B"])}
               )
    end
  end

  describe "has_any_member/2 type handling" do
    test "returns whether the list contains any provided item" do
      assert true == Expression.evaluate_block!(~s|has_any_member(["A", "B", "C"], ["Z", "C"])|)
      assert false == Expression.evaluate_block!(~s|has_any_member(["A", "B"], ["Z"])|)
    end

    test "an empty items list is false" do
      # Mirror of has_all_members: Enum.any?/2 over an empty list is false.
      assert false == Expression.evaluate_block!(~s|has_any_member(["A"], [])|)
    end

    test "non-list arguments return false (guarded, never raises)" do
      assert false == evaluate_with_value(~s|has_any_member(value, ["C"])|, nil)
      assert false == evaluate_with_value(~s|has_any_member(["A"], value)|, nil)
    end

    test "extracts __value__ from complex values" do
      assert true ==
               evaluate_with_value(
                 "has_any_member(value, items)",
                 complex_value(["A", "B"]),
                 %{"items" => complex_value(["Z", "B"])}
               )
    end
  end

  describe "concatenate/N (concatenate_vargs) type handling" do
    test "joins string arguments into one string" do
      assert "abc" == Expression.evaluate_block!(~s|concatenate("a", "b", "c")|)
      assert "" == Expression.evaluate_block!(~s|concatenate()|)
    end

    test "nil, numbers and booleans are stringified via default_value/to_string" do
      # nil contributes the empty string; numbers and booleans are stringified.
      assert "ac" == evaluate_with_value(~s|concatenate("a", value, "c")|, nil)
      assert "a42" == evaluate_with_value(~s|concatenate("a", value)|, 42)
      assert "atrue" == evaluate_with_value(~s|concatenate("a", value)|, true)
    end

    test "a list argument is interpreted as a charlist (raw bytes), not its text form" do
      # Surprising: to_string([1, 2]) treats the list as a charlist, so the
      # numbers become raw bytes appended to "a".
      assert <<97, 1, 2>> == evaluate_with_value(~s|concatenate("a", value)|, [1, 2])
    end

    test "a map argument raises Protocol.UndefinedError (no String.Chars for Map)" do
      # Known crash behavior, documented not endorsed: to_string/1 has no
      # String.Chars implementation for a plain map.
      assert_raise Protocol.UndefinedError, fn ->
        evaluate_with_value(~s|concatenate("a", value)|, %{"x" => 1})
      end
    end

    test "extracts __value__ from complex values" do
      assert "aZ" == evaluate_with_value(~s|concatenate("a", value)|, complex_value("Z"))
    end
  end

  describe "first/N dispatch (enum-ish, but NOT implemented)" do
    # FINDING: there is no `first` callback in Expression.Callbacks.Standard, so
    # the dispatcher returns the "not implemented" error string for every call.
    # FLOIP-style `first` is simply not provided by this engine.
    test "every invocation returns the 'first is not implemented' error string" do
      assert ~s|ERROR: "first is not implemented."| ==
               Expression.evaluate_block!("first([1, 2, 3])")

      assert ~s|ERROR: "first is not implemented."| ==
               evaluate_with_value("first(value)", nil)
    end
  end
end
