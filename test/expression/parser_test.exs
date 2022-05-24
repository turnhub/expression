defmodule Expression.ParserTest do
  use ExUnit.Case
  doctest Expression.Parser

  test "text" do
    assert_ast([text: "foo"], "foo")
  end

  test "substitution" do
    assert_ast([substitution: [variable: [atom: "foo"]]], "@foo")
  end

  def assert_ast(ast, expression) do
    assert {:ok, produced_ast, "", %{}, _, _} = Expression.Parser.parse(expression)
    assert ast == produced_ast
  end

  describe "expression blocks" do
    test "variables" do
      assert_ast([block: [variable: [atom: "foo"]]], "@(foo)")
    end

    test "literals" do
      assert_ast([block: [literal: 1]], "@(1)")
      assert_ast([block: [literal: -1]], "@(-1)")
      assert_ast([block: [literal: true]], "@(tRuE)")
      assert_ast([block: [literal: false]], "@(fAlSe)")
      assert_ast([block: [literal: Decimal.new("1.23")]], "@(1.23)")
      assert_ast([block: [literal: Decimal.new("-1.23")]], "@(-1.23)")
      assert_ast([block: [literal: ~U[2022-05-24 00:00:00.0Z]]], "@(2022-05-24T00:00:00)")
    end

    test "functions" do
      assert_ast([block: [function: [name: [atom: "now"], args: [literal: 1]]]], "@(now(1))")
    end

    test "attributes" do
      assert_ast(
        [
          block: [
            function: [name: [atom: "now"], args: [literal: 1], attribute: [atom: "year"]]
          ]
        ],
        "@(now(1).year)"
      )

      assert_ast(
        [block: [variable: [atom: "foo", attribute: [atom: "bar"]]]],
        "@(foo.bar)"
      )
    end

    test "arithmatic" do
      assert_ast([block: [+: [literal: 1, literal: 1]]], "@(1 + 1)")
      assert_ast([block: [+: [literal: 1, *: [literal: 2, literal: 3]]]], "@(1 + (2 * 3))")
      assert_ast([block: [+: [literal: 1, *: [literal: 2, literal: 3]]]], "@(1 + 2 * 3)")
      assert_ast([block: [*: [literal: 1, +: [literal: 2, literal: 3]]]], "@(1 * (2 + 3))")
      assert_ast([block: [+: [*: [literal: 1, literal: 2], literal: 3]]], "@(1 * 2 + 3)")

      assert_ast(
        [
          block: [
            +: [
              *: [literal: 1, literal: 2],
              function: [name: [atom: "foo"], args: [], attribute: [atom: "year"]]
            ]
          ]
        ],
        "@(1 * 2 + foo().year)"
      )
    end
  end

  describe "functions" do
    test "without arguments" do
      assert_ast(
        [
          substitution: [
            function: [
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
            function: [
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
            function: [
              name: [atom: "foo"],
              args: [variable: [atom: "bar"]]
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
            function: [
              name: [atom: "foo"],
              args: [literal: 1, variable: [atom: "bar"]]
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
            function: [
              name: [atom: "if"],
              args: [
                variable: [atom: "foo"],
                function: [name: [atom: "bar"], args: [literal: 1, variable: [atom: "auz"]]],
                function: [name: [atom: "baz"], args: [literal: 2, literal: 3]]
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
            variable: [atom: "foo", attribute: [atom: "bar"]]
          ]
        ],
        "@foo.bar"
      )
    end

    test "on nested variables" do
      assert_ast(
        [
          substitution: [
            variable: [
              atom: "foo",
              attribute: [
                atom: "bar",
                attribute: [atom: "baz"]
              ]
            ]
          ]
        ],
        "@foo.bar.baz"
      )
    end

    test "on functions" do
      assert_ast(
        [
          substitution: [
            function: [
              name: [atom: "regex"],
              args: [
                variable: [atom: "haystack"],
                variable: [atom: "needle"]
              ],
              attribute: [atom: "match"]
            ]
          ]
        ],
        "@regex(haystack, needle).match"
      )
    end

    test "on functions with nested attributes" do
      assert_ast(
        [
          substitution: [
            function: [
              name: [atom: "regex"],
              args: [variable: [atom: "haystack"], variable: [atom: "needle"]],
              attribute: [atom: "match", attribute: [atom: "deep"]]
            ]
          ]
        ],
        "@regex(haystack, needle).match.deep"
      )
    end
  end
end
