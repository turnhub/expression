defmodule Expression.ParserTest do
  use ExUnit.Case
  doctest Expression.Parser

  test "text" do
    assert_ast([text: "foo"], "foo")
  end

  test "substitution" do
    assert_ast([substitution: [atom: "foo"]], "@foo")
  end

  def assert_ast(ast, expression) do
    assert {:ok, produced_ast, "", %{}, _, _} = Expression.Parser.parse(expression)
    assert ast == produced_ast
  end

  describe "functions" do
    test "without arguments" do
      assert_ast(
        [
          substitution: [
            function_call: [
              name: [atom: "foo"],
              args: []
            ]
          ]
        ],
        "@foo()"
      )
    end

    test "with single literal argument" do
      assert_ast(
        [
          substitution: [
            function_call: [
              name: [atom: "foo"],
              args: [literal: 1]
            ]
          ]
        ],
        "@foo(1)"
      )
    end

    test "with single variable argument" do
      assert_ast(
        [
          substitution: [
            function_call: [
              name: [atom: "foo"],
              args: [atom: "bar"]
            ]
          ]
        ],
        "@foo(bar)"
      )
    end

    test "with multiple arguments" do
      assert_ast(
        [
          substitution: [
            function_call: [
              name: [atom: "foo"],
              args: [literal: 1, atom: "bar"]
            ]
          ]
        ],
        "@foo(1, bar)"
      )
    end

    test "with functions as arguments" do
      assert_ast(
        [
          substitution: [
            function_call: [
              name: [atom: "if"],
              args: [
                atom: "foo",
                function_call: [name: [atom: "bar"], args: [literal: 1, atom: "auz"]],
                function_call: [name: [atom: "baz"], args: [literal: 2, literal: 3]]
              ]
            ]
          ]
        ],
        "@if(foo, bar(1, auz), baz(2, 3))"
      )
    end
  end

  describe "attributes" do
    test "on variables" do
      assert_ast(
        [
          substitution: [
            attribute: [
              {:subject, [atom: "foo"]},
              {:atom, "bar"}
            ]
          ]
        ],
        "@foo.bar"
      )
    end

    test "on nested variables" do
      assert_ast(
        [],
        "@foo.bar.baz"
      )
    end
  end

  test "junk" do
    # assert_ast(ast, Expression.Parser.parse("@if(foo.bar, bar(1, auz), baz(2, 3))")

    # assert_ast(ast, "@if(bar.bar).baz")

    # assert_ast(ast,              Expression.Parser.parse("text @foo.bar @bar(1,2,3,\"fff\",1.2,true,11)")

    # assert_ast(ast, "foo.bar.baz")
  end
end
