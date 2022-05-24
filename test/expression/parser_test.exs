defmodule Expression.ParserTest do
  use ExUnit.Case, async: true
  doctest Expression.Parser

  test "text" do
    assert_ast([text: "foo"], "foo")
  end

  test "expression" do
    assert_ast([expression: [atom: "foo"]], "@foo")
  end

  test "escaped at" do
    assert_ast([text: "user", text: "@", text: "example.org"], "user@@example.org")
  end

  def assert_ast(ast, expression) do
    assert {:ok, produced_ast, "", %{}, _, _} = Expression.Parser.parse(expression)
    assert ast == produced_ast
  end

  describe "expression blocks" do
    test "variables" do
      assert_ast([expression: [atom: "foo"]], "@(foo)")
    end

    test "literals" do
      assert_ast([expression: [literal: 1]], "@(1)")
      assert_ast([expression: [literal: -1]], "@(-1)")
      assert_ast([expression: [literal: true]], "@(tRuE)")
      assert_ast([expression: [literal: false]], "@(fAlSe)")
      assert_ast([expression: [literal: Decimal.new("1.23")]], "@(1.23)")
      assert_ast([expression: [literal: Decimal.new("-1.23")]], "@(-1.23)")

      assert_ast(
        [expression: [literal: ~U[2022-05-24 00:00:00.0Z]]],
        "@(2022-05-24T00:00:00)"
      )
    end

    test "functions" do
      assert_ast(
        [expression: [function: [name: "now", args: [literal: 1]]]],
        "@(now(1))"
      )
    end

    test "attributes" do
      assert_ast(
        [
          expression: [
            attribute: [
              function: [
                {:name, "now"},
                {:args, [literal: 1]}
              ],
              atom: "year"
            ]
          ]
        ],
        "@(now(1).year)"
      )

      assert_ast(
        [
          expression: [
            attribute: [atom: "foo", atom: "bar"]
          ]
        ],
        "@(foo.bar)"
      )
    end

    test "arithmatic" do
      assert_ast([expression: [+: [literal: 1, literal: 1]]], "@(1 + 1)")

      assert_ast(
        [expression: [+: [literal: 1, *: [literal: 2, literal: 3]]]],
        "@(1 + (2 * 3))"
      )

      assert_ast(
        [expression: [+: [literal: 1, *: [literal: 2, literal: 3]]]],
        "@(1 + 2 * 3)"
      )

      assert_ast(
        [expression: [*: [literal: 1, +: [literal: 2, literal: 3]]]],
        "@(1 * (2 + 3))"
      )

      assert_ast(
        [expression: [+: [*: [literal: 1, literal: 2], literal: 3]]],
        "@(1 * 2 + 3)"
      )

      assert_ast(
        [
          expression: [
            +: [
              {:*, [literal: 1, literal: 2]},
              {:attribute, [function: [name: "foo"], atom: "year"]}
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
          expression: [
            function: [
              name: "foo"
            ]
          ]
        ],
        "@foo()"
      )
    end

    test "with single literal argument" do
      assert_ast(
        [
          expression: [
            function: [
              name: "foo",
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
          expression: [
            function: [
              name: "foo",
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
          expression: [
            function: [
              name: "foo",
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
          expression: [
            function: [
              name: "if",
              args: [
                atom: "foo",
                function: [name: "bar", args: [literal: 1, atom: "auz"]],
                function: [name: "baz", args: [literal: 2, literal: 3]]
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
        [expression: [attribute: [atom: "foo", atom: "bar"]]],
        "@foo.bar"
      )
    end

    test "on nested variables" do
      assert_ast(
        [
          expression: [
            attribute: [
              attribute: [atom: "foo", atom: "bar"],
              atom: "baz"
            ]
          ]
        ],
        "@foo.bar.baz"
      )
    end

    test "on functions" do
      assert_ast(
        [
          expression: [
            attribute: [
              function: [
                {:name, "regex"},
                {:args, [atom: "haystack", atom: "needle"]}
              ],
              atom: "match"
            ]
          ]
        ],
        "@regex(haystack, needle).match"
      )
    end

    test "on functions with nested attributes" do
      assert_ast(
        [
          expression: [
            attribute: [
              attribute: [
                {
                  :function,
                  [name: "regex", args: [atom: "haystack", atom: "needle"]]
                },
                {:atom, "match"}
              ],
              atom: "deep"
            ]
          ]
        ],
        "@regex(haystack, needle).match.deep"
      )
    end
  end
end
