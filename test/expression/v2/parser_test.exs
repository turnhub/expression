defmodule Expression.V2.ParserTest do
  use ExUnit.Case, async: true
  doctest Expression.V2.Parser

  alias Expression.V2.Parser

  describe "mixed" do
    test "expression/1 with plain text" do
      assert {:ok, ["hi"], "", _, _, _} = Parser.parse("hi")
      assert {:ok, ["hi ", [1]], "", _, _, _} = Parser.parse("hi @(1)")
    end

    test "escaping @" do
      assert {:ok, ["foo", "@", "bar.com"], "", _, _, _} = Parser.parse("foo@@bar.com")
    end

    test "lone @" do
      assert {:ok, ["foo ", "@", " something is bar"], "", _, _, _} =
               Parser.parse("foo @ something is bar")
    end
  end

  describe "expression/1 primitives" do
    test "int" do
      assert {:ok, [[1]], "", _, _, _} = Parser.parse("@(1)")
    end

    test "string" do
      assert {:ok, [["\"hello\""]], "", _, _, _} = Parser.parse("@(\"hello\")")
    end

    test "float" do
      assert {:ok, [[1.123456789]], "", _, _, _} = Parser.parse("@(1.1234567890)")
    end

    test "atom" do
      assert {:ok, [["foo"]], "", _, _, _} = Parser.parse("@(foo)")
    end
  end

  describe "functions" do
    test "expression/1" do
      assert {:ok, ["hi ", [{"now", []}]], "", _, _, _} = Parser.parse("hi @now()")
      assert {:ok, ["hi ", [{"now", [1, 2]}]], "", _, _, _} = Parser.parse("hi @now(1, 2)")
      assert {:ok, ["hi ", [{"now", [1, 2]}]], "", _, _, _} = Parser.parse("hi @(now(1, 2))")
    end

    test "expression/1 nested" do
      assert {:ok, [[{"now", [1, 2, {"foo", [1, 2, 3]}]}]], "", _, _, _} =
               Parser.parse("@(now(1, 2, foo(1, 2, 3)))")
    end
  end

  describe "groups" do
    test "expression/1" do
      assert {:ok, [[{"+", [1, 1]}]], "", _, _, _} = Parser.parse("@(1 + 1)")
    end

    test "expression/1 with functions" do
      assert {:ok, [[{"+", [{"+", [{"foo", []}, 1]}, 1]}]], "", _, _, _} =
               Parser.parse("@(foo() + 1 + 1)")
    end

    test "operator precedence" do
      assert {:ok, [[{"+", [1, {"*", [2, 3]}]}]], "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    end

    test "grouping" do
      assert {:ok, [[{"*", [1, {"+", [2, 3]}]}]], "", _, _, _} = Parser.parse("@(1 * (2 + 3))")
    end

    test "grouping with function calls" do
      assert {:ok, [[{"+", [{"*", [1, {"+", [2, 3]}]}, {"foo", []}]}]], "", _, _, _} =
               Parser.parse("@(1 * (2 + 3) + foo())")
    end

    test "grouping in function arguments" do
      assert {:ok,
              [
                [
                  {"function", [1, {"*", [{"+", [2, 3]}, 4]}, {"other_function", []}]}
                ]
              ], "", _, _, _} = Parser.parse("@(function(1, (2 + 3) * 4, other_function()))")
    end
  end

  describe "properties" do
    test "direct" do
      assert {:ok, [[{:__property__, ["foo", "bar"]}]], "", _, _, _} = Parser.parse("@(foo.bar)")
    end

    test "nested" do
      assert {:ok,
              [
                [
                  {:__property__, [{:__property__, ["foo", "bar"]}, "baz"]}
                ]
              ], "", _, _, _} = Parser.parse("@(foo.bar.baz)")
    end

    test "when called on function results" do
      assert {:ok, [[{:__property__, [{"function", []}, "bar"]}]], "", _, _, _} =
               Parser.parse("@(function().bar)")
    end
  end

  describe "lists" do
    test "plain" do
      assert {:ok, [[[1, 2, 3]]], "", _, _, _} = Parser.parse("@([1,2,3])")
    end

    test "in lambda" do
      assert {:ok, [[{"map", ["foo", {"&", [["&1", "\"Button\""]]}]}]], "", _, _, _} =
               Parser.parse("@map(foo, &([&1, \"Button\"]))")
    end
  end

  describe "ranges" do
    test "range" do
      assert {:ok, [[1..10]], "", _, _, _} = Parser.parse("@(1..10)")
    end

    test "range with step" do
      assert {:ok, [[1..10//5]], "", _, _, _} = Parser.parse("@(1..10//5)")
    end
  end

  describe "lambdas" do
    test "parsing lambdas" do
      assert {:ok, [[{"map", ["foo", {"&", ["&1"]}]}]], "", _, _, _} =
               Parser.parse("@map(foo, &(&1))")
    end
  end

  describe "attributes" do
    test "when nested" do
      assert {:ok,
              [
                [
                  {:__attribute__, [{:__attribute__, ["foo", "bar"]}, "baz"]}
                ]
              ], "", _, _, _} = Parser.parse("@(foo[bar][baz])")
    end

    test "when indexed" do
      assert {:ok, [[{:__attribute__, ["foo", 1]}]], "", _, _, _} = Parser.parse("@(foo[1])")
    end

    test "when string keys" do
      assert {:ok, [[{:__attribute__, ["foo", "\"bar\""]}]], "", _, _, _} =
               Parser.parse("@(foo[\"bar\"])")
    end

    test "when function values" do
      assert {:ok, [[{:__attribute__, ["foo", {"today", []}]}]], "", _, _, _} =
               Parser.parse("@(foo[today()])")
    end

    test "when called on function results" do
      assert {:ok, [[{:__attribute__, [{"function", []}, 0]}]], "", _, _, _} =
               Parser.parse("@(function()[0])")
    end

    test "when called on properties" do
      assert {:ok,
              [
                [
                  {:__attribute__, [{:__property__, [{:__property__, ["foo", "bar"]}, "baz"]}, 0]}
                ]
              ], "", _, _, _} = Parser.parse("@(foo.bar.baz[0])")
    end
  end

  describe "shorthand" do
    test "mixed with function" do
      assert {:ok, ["hi ", [{"now", []}]], "", _, _, _} = Parser.parse("hi @now()")
    end

    test "function" do
      assert {:ok, [[{"now", []}]], "", _, _, _} = Parser.parse("@now()")
    end

    test "function with arguments" do
      assert {:ok, [[{"now", [1, 2.3]}]], "", _, _, _} = Parser.parse("@now(1, 2.3)")
    end

    test "nested functions" do
      assert {:ok, [[{"first", [{"second", [1, 2, 3]}, 4]}]], "", _, _, _} =
               Parser.parse("@first(second(1, 2, 3), 4)")
    end

    test "short hand properties" do
      assert {:ok, [[{:__property__, ["bar", "com"]}]], "", _, _, _} = Parser.parse("@bar.com")
    end

    test "short hand attributes" do
      assert {:ok, [[{:__attribute__, ["bar", "com"]}]], "", _, _, _} = Parser.parse("@bar[com]")
    end
  end

  describe "error handling" do
    test "bad expression" do
      assert {:ok, ["foo"], " is bar", _, _, _} = Parser.expression("foo is bar")
    end

    test "bad grammar" do
      assert {:error, "expected an atom while processing an expression", "?", _, _, _} =
               Parser.expression("?")
    end
  end
end
