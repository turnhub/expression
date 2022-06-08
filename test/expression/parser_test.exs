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

  test "lambda" do
    assert_ast(
      [
        {:expression,
         [
           function: [
             name: "map",
             args: [
               atom: "foo",
               lambda: [
                 args: [
                   list: [args: [capture: 1, atom: "button"]]
                 ]
               ]
             ]
           ]
         ]}
      ],
      "@map(foo, &([&1,Button]))"
    )
  end

  test "lambda with joins" do
    assert_ast(
      [
        {:expression,
         [
           function: [
             name: "map",
             args: [
               atom: "choices",
               lambda: [
                 args: [
                   list: [
                     args: [
                       capture: 1,
                       &: [literal: "Button", capture: 1]
                     ]
                   ]
                 ]
               ]
             ]
           ]
         ]}
      ],
      "@map(choices, &([&1, 'Button' & &1]))"
    )
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

    test "lists" do
      assert_ast(
        [
          expression: [
            list: [
              args: [literal: 1, atom: "foo", function: [name: "now"]]
            ]
          ]
        ],
        "@([1, foo, now()])"
      )
    end

    test "functions" do
      assert_ast(
        [expression: [function: [name: "now", args: [literal: 1]]]],
        "@(now(1))"
      )
    end

    test "functions with white space" do
      assert_ast(
        [expression: [function: [name: "now", args: [literal: 1, literal: 2, literal: 3]]]],
        "@(now(1,\n   2,\n3))"
      )
    end

    test "attributes" do
      assert_ast(
        [
          expression: [
            attribute: [
              {:function,
               [
                 {:name, "now"},
                 {:args, [literal: 1]}
               ]},
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

  describe "logic" do
    test "lte" do
      assert_ast(
        [
          expression: [
            <=: [
              attribute: [atom: "block", atom: "value"],
              literal: 30
            ]
          ]
        ],
        "@(block.value <= 30)"
      )
    end

    test "add" do
      assert_ast(
        [expression: [+: [literal: 1, atom: "a"]]],
        "@(1 + a)"
      )

      assert_ast(
        [
          expression: [
            +: [
              attribute: [atom: "contact", atom: "age"],
              literal: 1
            ]
          ]
        ],
        "@(contact.age+1)"
      )
    end

    test "join" do
      assert_ast(
        [
          expression: [
            &: [
              {
                :&,
                [
                  attribute: [
                    atom: "contact",
                    atom: "first_name"
                  ],
                  literal: " "
                ]
              },
              attribute: [atom: "contact", atom: "last_name"]
            ]
          ]
        ],
        "@(contact.first_name & \" \" & contact.last_name)"
      )
    end
  end

  describe "access" do
    test "as function arguments" do
      assert_ast(
        [
          expression: [
            function: [
              name: "if",
              args: [
                key: [atom: "record", atom: "a"],
                key: [atom: "record", atom: "a"],
                literal: ""
              ]
            ]
          ]
        ],
        "@if(record[a], record[a], \"\")"
      )
    end

    test "with integers" do
      assert_ast(
        [expression: [key: [atom: "foo", literal: 0]]],
        "@foo[0]"
      )
    end

    test "with variables" do
      assert_ast(
        [expression: [key: [atom: "foo", atom: "bar"]]],
        "@foo[bar]"
      )
    end

    test "with function call" do
      assert_ast(
        [expression: [key: [atom: "foo", function: [name: "date"]]]],
        "@foo[date()]"
      )
    end

    test "with literals as keys" do
      assert_ast(
        [
          expression: [
            attribute: [
              attribute: [attribute: [atom: "foo", atom: "bar"], literal: 123],
              atom: "baz"
            ]
          ]
        ],
        "@foo.bar.123.baz"
      )
    end

    test "with function call and attribute" do
      assert_ast(
        [
          expression: [
            key: [
              atom: "foo",
              attribute: [
                function: [name: "date"],
                atom: "month"
              ]
            ]
          ]
        ],
        "@foo[date().month]"
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

  describe "types" do
    test "decimal" do
      assert_ast([expression: [literal: Decimal.new("1.23")]], "@(1.23)")
    end

    test "datetime" do
      assert_ast(
        [expression: [literal: ~U[2020-11-21 20:13:51.921042Z]]],
        "@(2020-11-21T20:13:51.921042Z)"
      )

      assert_ast(
        [expression: [literal: ~U[2020-02-01T23:23:23Z]]],
        "@(01-02-2020 23:23:23)"
      )

      assert_ast([expression: [literal: ~U[2020-02-01T23:23:00Z]]], "@(01-02-2020 23:23)")
    end

    test "booleans" do
      assert_ast([expression: [literal: true]], "@(true)")
      assert_ast([expression: [literal: true]], "@(True)")
      assert_ast([expression: [literal: false]], "@(false)")
      assert_ast([expression: [literal: false]], "@(False)")
    end
  end

  describe "case insensitive" do
    test "variables" do
      assert_ast(
        [expression: [attribute: [atom: "contact", atom: "name"]]],
        "@CONTACT.Name"
      )
    end

    test "functions" do
      assert_ast(
        [
          expression: [
            function: [
              name: "hour",
              args: [function: [name: "now"]]
            ]
          ]
        ],
        "@hour(Now())"
      )
    end
  end
end
