defmodule ExpressionTest do
  use ExUnit.Case, async: true
  doctest Expression

  @doc """
  Test evaluation of an expression both as a block and as a string in the same
  way to how the autodoc generated tests work. This is useful when creating unit
  tests (instead of doc tests) or when trying to debug doc tests.

  Note that there is a subtle difference here however in that for each eval
  (evaluate_block! and evaluate_as_string!) an explicit expected result should be
  provided (instead of result being stringified and used to assert the result of
  evaluate_as_string!). This is to more clearly separate the two tests and ensure that
  the expected string result is explicitly defined as exactly what is expected.
  """
  def test_expression(
        expression: expression,
        expected_block_result: expected_block_result,
        expected_string_result: expected_string_result,
        context: context
      ) do
    evaluate_block_result =
      Expression.evaluate_block!(
        expression,
        context
      )

    assert evaluate_block_result == expected_block_result

    evaluate_as_string_result =
      Expression.evaluate_as_string!(
        "@" <> expression,
        context
      )

    assert evaluate_as_string_result == expected_string_result
  end

  describe "evaluate" do
    test "evaluate_as_boolean!" do
      assert true == Expression.evaluate_as_boolean!("@(tRuE)")
      assert false == Expression.evaluate_as_boolean!("@(fAlSe)")
      assert true == Expression.evaluate_as_boolean!("@(1 > 0)")
      assert true == Expression.evaluate_as_boolean!("@has_all_words('foo', 'foo')")
      assert true == Expression.evaluate_as_boolean!("@or(has_all_words('foo', 'bar'), true)")
      assert false == Expression.evaluate_as_boolean!("@and(has_all_words('foo', 'bar'), true)")
      assert true == Expression.evaluate_as_boolean!("@and(has_all_words('foo', 'foo'), true)")
      assert true == Expression.evaluate_as_boolean!("@has_phrase('foo', 'foo')")
      assert false == Expression.evaluate_as_boolean!("@has_phrase('foo', 'bar')")

      assert false ==
               Expression.evaluate_as_boolean!("@has_phrase(name, 'bar')", %{"name" => nil})

      assert true ==
               Expression.evaluate_as_boolean!("@has_phrase(contact.number, \"456\")", %{
                 "contact" => %{"number" => 123_456}
               })

      assert true == Expression.evaluate_as_boolean!("@has_only_phrase('foo bar', 'foo bar')")

      assert false ==
               Expression.evaluate_as_boolean!("@has_only_phrase('foo bar baz', 'foo bar ')")

      assert false ==
               Expression.evaluate_as_boolean!("@has_only_phrase(name, 'bar')", %{"name" => nil})

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_any_phrase('hello', phrases)",
                 %{"phrases" => nil}
               )

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_all_members(list, items)",
                 %{"list" => nil, "items" => ["a"]}
               )

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_all_members(list, items)",
                 %{"list" => ["a"], "items" => nil}
               )

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_any_member(list, items)",
                 %{"list" => nil, "items" => ["a"]}
               )

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_any_member(list, items)",
                 %{"list" => ["a"], "items" => nil}
               )

      assert true ==
               Expression.evaluate_as_boolean!("@has_beginning(contact.number, \"123\")", %{
                 "contact" => %{"number" => 123_456}
               })

      assert true ==
               Expression.evaluate_as_boolean!(
                 "@has_pattern('Buy cheese please', 'buy (\\w+)')",
                 %{}
               )

      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_pattern('Sell cheese please', 'buy (\\w+)')",
                 %{}
               )

      assert false ==
               Expression.evaluate_as_boolean!("@has_pattern(nil, 'buy (\\w+)')", %{})
    end

    test "evaluate_as_boolean! with kernel operators" do
      assert true == Expression.evaluate_as_boolean!("@(123 == 123)")
      assert true == Expression.evaluate_as_boolean!("@(\"123\" == a)", %{"a" => "123"})
      assert true == Expression.evaluate_as_boolean!("@(123 == \"123\")")
      assert true == Expression.evaluate_as_boolean!("@(\"123\" == 123)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.123\" == 0.123)")

      assert true == Expression.evaluate_as_boolean!("@(2 > 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" > a)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(2 > \"1\")")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" > 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.2\" > 0.1)")

      assert true == Expression.evaluate_as_boolean!("@(2 >= 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" >= a)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(2 >= \"1\")")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" >= 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.1\" >= 0.1)")

      assert true == Expression.evaluate_as_boolean!("@(1 < 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" < a)", %{"a" => "2"})
      assert true == Expression.evaluate_as_boolean!("@(1 < \"2\")")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" < 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.1\" < 0.2)")

      assert true == Expression.evaluate_as_boolean!("@(1 <= 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" <= a)", %{"a" => "2"})
      assert true == Expression.evaluate_as_boolean!("@(1 <= \"2\")")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" <= 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.1\" <= 0.1)")

      assert true == Expression.evaluate_as_boolean!("@(2 + 1 == 3)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" + a == 3)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(2 + \"1\" == 3)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" + 1 == 3)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.2\" + 0.1 == 0.30000000000000004)")

      assert true == Expression.evaluate_as_boolean!("@(2 - 1 == 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" - a == 1)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(2 - \"1\" == 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" - 1 == 1)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.2\" - 0.1 == 0.1)")

      assert true == Expression.evaluate_as_boolean!("@(-2 + 1 == -1)")
      assert true == Expression.evaluate_as_boolean!("@(\"-2\" + a == -1)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(-2 + \"1\" == -1)")
      assert true == Expression.evaluate_as_boolean!("@(\"-2\" + 1 == -1)")
      assert true == Expression.evaluate_as_boolean!("@(\"-0.2\" + 0.1 == -0.1)")

      assert true == Expression.evaluate_as_boolean!("@(2 / 1 == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" / a == 2)", %{"a" => "1"})
      assert true == Expression.evaluate_as_boolean!("@(2 / \"1\" == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"2\" / 1 == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.2\" / 0.1 == 2.0)")

      assert true == Expression.evaluate_as_boolean!("@(1 * 2 == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" * a == 2)", %{"a" => "2"})
      assert true == Expression.evaluate_as_boolean!("@(1 * \"2\" == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"1\" * 2 == 2)")
      assert true == Expression.evaluate_as_boolean!("@(\"0.1\" * 0.2 == 0.020000000000000004)")

      assert true == Expression.evaluate_as_boolean!("@(\"1. A\" == x)", %{"x" => "1. A"})
      assert false == Expression.evaluate_as_boolean!("@(\"1. A wrong\" == x)", %{"x" => "1. A"})

      assert_raise Expression.Error, "expression is not a number: `\"NaN\"`", fn ->
        Expression.evaluate_as_boolean!("@(1 * \"NaN\" == 2)")
      end

      assert_raise Expression.Error, "expression is not a number: `\"NaN\"`", fn ->
        Expression.evaluate_as_boolean!("@(\"1\" * a == 2)", %{"a" => "NaN"})
      end

      assert_raise Expression.Error, "expression is not a number: `\"NaN\"`", fn ->
        Expression.evaluate_as_boolean!("@(\"NaN\" * 0.2 == 0.02)")
      end
    end

    test "list with indices" do
      assert "baz" == Expression.evaluate_as_string!("@foo[0]", %{"foo" => ["baz", "bar"]})
      assert "bar" == Expression.evaluate_as_string!("@foo[1]", %{"foo" => ["baz", "bar"]})
    end

    test "list with variable" do
      assert "bar" =
               Expression.evaluate_as_string!("@foo[cursor]", %{
                 "foo" => ["baz", "bar"],
                 "cursor" => 1
               })

      assert "hello" ==
               Expression.evaluate_block!("content_units_response.body[current_activity]", %{
                 "content_units_response" => %{
                   "body" => ["hello", "bye"]
                 },
                 "current_activity" => 0
               })

      assert "hello" ==
               Expression.evaluate_block!(
                 "content_units_response.body[current_activity]",
                 %{
                   "content_units_response" => %{
                     "body" => ["hello", "bye"]
                   },
                   "current_activity" => "0"
                 }
               )
    end

    test "stringify primitives" do
      assert iso_dt = Expression.evaluate_as_string!("@NOW()")
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(iso_dt)
      assert "true" == Expression.evaluate_as_string!("@(tRuE)")
      assert "false" == Expression.evaluate_as_string!("@(FaLsE)")
      assert "1.23" == Expression.evaluate_as_string!("@(1.23)")
      assert "2022-06-28" == Expression.evaluate_as_string!("@date(2022, 6, 28)")
      assert "123" == Expression.evaluate_as_string!("@([1,2,3])")
      assert "1" == Expression.evaluate_as_string!(1)
      assert "1.5" == Expression.evaluate_as_string!(1.5)
      assert "true" == Expression.evaluate_as_string!(true)
      assert "false" == Expression.evaluate_as_string!(false)
      assert "" == Expression.evaluate_as_string!(nil)
    end

    test "list with attribute" do
      assert "bar" =
               Expression.evaluate_as_string!("@foo[0].name", %{"foo" => [%{"name" => "bar"}]})
    end

    test "Stringify time sigil" do
      assert "11:00:00" =
               Expression.evaluate_as_string!(~T[11:00:00])
    end

    test "stringify time reached via context substitution" do
      assert "11:00:00" ==
               Expression.evaluate_as_string!("@appointment", %{"appointment" => ~T[11:00:00]})
    end

    test "stringify time embedded in surrounding text" do
      assert "Your slot is 11:00:00 today" ==
               Expression.evaluate_as_string!(
                 "Your slot is @appointment today",
                 %{"appointment" => ~T[11:00:00]}
               )
    end

    test "list with out of bound indicess" do
      assert nil ==
               Expression.evaluate!("@foo[cursor]", %{"foo" => ["baz", "bar"], "cursor" => 100})

      assert nil == Expression.evaluate!("@foo[100]", %{"foo" => ["baz", "bar"]})
    end

    test "append one item" do
      assert {:ok, ["A", "B", "C"]} ==
               Expression.evaluate("@append(list, item)", %{
                 "list" => ["A", "B"],
                 "item" => "C"
               })
    end

    test "append a list of items" do
      assert {:ok, ["A", "B", "C", "D", "E"]} ==
               Expression.evaluate("@append(first_list, second_list)", %{
                 "first_list" => ["A", "B", "C"],
                 "second_list" => ["D", "E"]
               })
    end

    test "calculation with explicit precedence" do
      assert {:ok, 8} = Expression.evaluate("@(2 + (2 * 3))")
    end

    test "calculation with default precedence" do
      assert {:ok, 8} = Expression.evaluate("@(2 + 2 * 3)")
    end

    test "exponent precendence over addition" do
      assert {:ok, 10.0} = Expression.evaluate("@(2 + 2 ^ 3)")
    end

    test "exponent precendence over multiplication" do
      assert {:ok, 16.0} = Expression.evaluate("@(2 * 2 ^ 3)")
    end

    test "example calculation from floip expression docs" do
      assert {:ok, 0.999744} = Expression.evaluate("@(1 + (2 - 3) * 4 / 5 ^ 6)")
    end

    test "evaluate map default value" do
      assert {:ok, "foo"} ==
               Expression.evaluate("@map", %{
                 "map" => %{
                   "__value__" => "foo",
                   "bar" => "bar"
                 }
               })

      assert {:ok, "bar"} ==
               Expression.evaluate("@map.bar", %{
                 "map" => %{
                   "__value__" => "foo",
                   "bar" => "bar"
                 }
               })
    end

    test "delete an element from a map" do
      assert {:ok, %{"age" => 32}} ==
               Expression.evaluate("@delete(patient, \"gender\")", %{
                 "patient" => %{
                   "gender" => "?",
                   "age" => 32
                 }
               })

      assert {:ok, %{"gender" => "?", "age" => 32}} ==
               Expression.evaluate("@delete(patient, \"unknown\")", %{
                 "patient" => %{
                   "gender" => "?",
                   "age" => 32
                 }
               })
    end

    test "operators against default values" do
      assert %{
               "__value__" => to_string(Date.utc_today()),
               "date" => Date.utc_today(),
               "datetime" => Timex.beginning_of_day(DateTime.utc_now())
             } ==
               Expression.evaluate_block!("datevalue(today(), '%Y-%m-%d')")

      assert Expression.evaluate_block!("date == today()", %{
               "date" => Date.utc_today()
             })

      assert Expression.evaluate_block!("date == datevalue(today(), '%Y-%m-%d').date", %{
               "date" => to_string(Date.utc_today())
             })
    end

    test "operators against datetimes" do
      ctx = %{
        "contact" => %{
          "reminder_timestamp" => "2023-01-12T14:49:18.957984Z"
        }
      }

      assert false ==
               Expression.evaluate_block!(
                 "contact.reminder_timestamp < datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert false ==
               Expression.evaluate_block!(
                 "contact.reminder_timestamp <= datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               Expression.evaluate_block!(
                 "contact.reminder_timestamp > datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               Expression.evaluate_block!(
                 "contact.reminder_timestamp >= datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               Expression.evaluate_block!(
                 "contact.reminder_timestamp == datetime_add(contact.reminder_timestamp, 0, \"M\")",
                 ctx
               )
    end

    test "example logical comparison between integers" do
      assert {:ok, true} ==
               Expression.evaluate("@(contact.age > 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age >= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age < 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <= 30)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age = 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age != 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <> 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 18}})
    end

    test "example logical comparison between decimals" do
      assert {:ok, true} ==
               Expression.evaluate("@(contact.age > 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age >= 20.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age < 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <= 20.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <= 30.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age == 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               Expression.evaluate("@(contact.age = 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age != 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age <> 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               Expression.evaluate("@(contact.age == 18.0)", %{"contact" => %{"age" => "18.0"}})
    end

    test "logical comparison with lists" do
      assert {:ok, false} ==
               Expression.evaluate("@(18 == answers[cursor])", %{
                 "answers" => ["yes"],
                 "cursor" => 0
               })

      assert {:ok, false} ==
               Expression.evaluate("@(answers[cursor] == 18)", %{
                 "answers" => ["yes"],
                 "cursor" => 0
               })
    end

    test "escaping @s" do
      assert "user@example.org" = Expression.evaluate_as_string!("user@@example.org")
      assert "user@example.org" = Expression.evaluate_as_string!("@('user' & '@example.org')")
    end

    test "trailing full stops" do
      assert "bar." = Expression.evaluate_as_string!("@foo.", %{"foo" => "bar"})
      assert "baz." = Expression.evaluate_as_string!("@foo.bar.", %{"foo" => %{"bar" => "baz"}})
    end

    test "substitution" do
      assert {:ok, ["hello ", "name"]} =
               Expression.evaluate("hello @(contact.name)", %{
                 "contact" => %{
                   "name" => "name"
                 }
               })
    end

    test "addition" do
      assert {:ok, ["next year you are ", 41, " years old"]} =
               Expression.evaluate("next year you are @(contact.age + 1) years old", %{
                 "contact" => %{
                   "age" => 40
                 }
               })
    end

    test "function name case insensitivity" do
      assert {:ok, dt} = Expression.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
      assert {:ok, dt} = Expression.evaluate("@(noW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with zero arguments" do
      assert {:ok, dt} = Expression.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with one or more arguments" do
      assert {:ok, dt} = Expression.evaluate("@(DATE(2020, 12, 30))")
      assert dt.year == 2020
      assert dt.month == 12
      assert dt.day == 30
    end

    test "function calls default arguments" do
      now = NaiveDateTime.utc_now()
      assert {:ok, returned} = Expression.evaluate("@(DATEVALUE(NOW()))")
      parsed = Timex.parse!(returned, "%Y-%m-%d %H:%M:%S", :strftime)
      assert NaiveDateTime.diff(now, parsed) < :timer.seconds(1)

      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d", :strftime)
      assert {:ok, expected} == Expression.evaluate("@(DATEVALUE(NOW(), \"%Y-%m-%d\"))")
    end

    test "lazy argument evaluation in ifs" do
      context = %{
        "status" => nil
      }

      assert false ==
               Expression.evaluate!(~S|@if(status, left(status, 2), false)|, context)

      assert false ==
               Expression.evaluate!(~S|@if(isstring(status), left(status, 2), false)|, context)

      assert false ==
               Expression.evaluate!(~S|@if(LEN(status) > 0, LEFT(status, 2), false)|, context)
    end

    test "checking for nil vars with if" do
      assert 1 ==
               Expression.evaluate!("@IF(value, value, 0)", %{
                 "value" => 1
               })

      assert 0 ==
               Expression.evaluate!("@IF(value, value, 0)", %{
                 "value" => nil
               })

      assert 0 == Expression.evaluate!("@IF(value, value, 0)", %{})

      assert 1 ==
               Expression.evaluate!("@IF(value.foo, value.foo, 0)", %{
                 "value" => %{
                   "foo" => 1
                 }
               })
    end

    test "checking for complex values with if" do
      assert Expression.evaluate!("@IF(var, var, 0)", %{
               "var" => %{
                 "__value__" => 1,
                 "error" => false,
                 "message" => "some message"
               }
             }) == 1

      assert Expression.evaluate!("@IF(var, var, 0)", %{
               "var" => %{
                 "__value__" => nil,
                 "error" => true,
                 "message" => "some message"
               }
             }) == 0

      assert Expression.evaluate!("@IF(var, var, 0)", %{}) == 0

      assert Expression.evaluate!("@IF(var.foo, var.foo, 0)", %{
               "var" => %{
                 "foo" => %{
                   "__value__" => 1,
                   "error" => false,
                   "message" => "some message"
                 }
               }
             }) == 1
    end

    test "function calls with expressions" do
      assert {:ok, ["Dear ", "lovely client"]} =
               Expression.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')", %{
                 "contact" => %{"gender" => "O"}
               })
    end

    test "evaluate_block" do
      assert {:ok, true} ==
               Expression.evaluate_block("contact.age > 10", %{"contact" => %{"age" => 21}})

      assert {:ok, 2} == Expression.evaluate_block("1 + 1")
    end

    test "return an error tuple" do
      assert {:error, "expression is not a number: `\"not a number\"`"} =
               Expression.evaluate_block("block.value > 0", %{
                 "block" => %{"value" => "not a number"}
               })
    end

    test "return an error tuple when variables are not defined" do
      assert {:error, "attribute is not found: `value`"} =
               Expression.evaluate_block("block.value > 0", %{"block" => %{}})

      assert {:error, "attribute is not found: `block.value`"} =
               Expression.evaluate_block("block.value > 0", %{})
    end

    test "throw an error when variables are not defined" do
      assert_raise Expression.Error, "attribute is not found: `value`", fn ->
        Expression.evaluate_block!("block.value > 0", %{"block" => %{}})
      end
    end

    test "throw an error" do
      assert_raise Expression.Error, "expression is not a number: `\"not a number\"`", fn ->
        Expression.evaluate_block!("block.value > 0", %{"block" => %{"value" => "not a number"}})
      end

      assert_raise Protocol.UndefinedError,
                   ~r/protocol Enumerable not implemented for .*\s*"A"/s,
                   fn ->
                     Expression.evaluate("@append(first_list, second_list)", %{
                       "first_list" => "A",
                       "second_list" => "B"
                     })
                   end

      assert_raise BadMapError, ~r/expected a map, got:.*\["A", "B", "C"\]/s, fn ->
        Expression.evaluate("@delete(map, \"key\")", %{
          "map" => ["A", "B", "C"]
        })
      end
    end
  end

  test "escaping" do
    assert "@@if(foo, bar, baz)" == Expression.escape("@if(foo, bar, baz)")
    assert "@@bar.baz" == Expression.escape("@bar.baz")
    assert "@@bar" == Expression.escape("@bar")
    assert "@@bar[0]" == Expression.escape("@bar[0]")
    assert "@@if(foo, bar, baz)" == Expression.escape("@if(foo, bar, baz)")
    assert "@@if(foo, bar.baz, baz)" == Expression.escape("@if(foo, bar.baz, baz)")
  end

  describe "parse!/1" do
    test "parses string expressions" do
      assert [text: "hello"] = Expression.parse!("hello")
      assert [expression: [atom: "foo"]] = Expression.parse!("@foo")
    end

    test "parses number primitives by converting to string" do
      assert [text: "42"] = Expression.parse!(42)
      assert [text: "3.14"] = Expression.parse!(3.14)
    end

    test "parses boolean primitives by converting to string" do
      assert [text: "true"] = Expression.parse!(true)
      assert [text: "false"] = Expression.parse!(false)
    end

    test "parses Time struct by converting to string" do
      assert [text: "11:00:00"] = Expression.parse!(~T[11:00:00])
    end
  end

  describe "context is parsed correctly when using the skip_context_evaluation? option" do
    test "string values in context that resemble booleans should not be parsed as booleans" do
      assert true ==
               Expression.evaluate_block!(
                 "block.response = \"True\"",
                 %{
                   "block" => %{"response" => "True"}
                 },
                 Expression.Callbacks,
                 skip_context_evaluation?: true
               )
    end

    test "string values in context that resemble numbers should not be parsed as numbers" do
      assert true ==
               Expression.evaluate_block!(
                 "ref_Buttons_7bef16 == \"2\"",
                 %{
                   "ref_Buttons_7bef16" => %{
                     "__value__" => "2",
                     "index" => 1,
                     "label" => "2",
                     "name" => "2"
                   }
                 },
                 Expression.Callbacks,
                 skip_context_evaluation?: true
               )
    end
  end

  describe "evaluate_block!" do
    test "should return a map with error details when an error occurred" do
      assert Expression.evaluate_block!("chunk_every(nil, 2)") == %{
               "__type__" => "expression/v1error",
               "__value__" => nil,
               "error" => true,
               "message" => "Invalid enumerable"
             }
    end
  end

  describe "evaluate_as_string!" do
    test "should return the empty string when an error occurred" do
      # This avoids situations where people started accidentally receiving things like
      # "Your registration is ERROR: TOKEN XXX IS INVALID" which was worse than sending
      # the empty string.
      assert Expression.evaluate_as_string!("@chunk_every(nil, 2)") == ""
    end
  end

  describe "evaluate_block! vs evaluate_as_string!" do
    test "evaluate_block! should return raw error data map and evaluate_as_string! should return the empty string when an error occurred" do
      test_expression(
        expression: "chunk_every(nil, 2)",
        expected_block_result: %{
          "__type__" => "expression/v1error",
          "__value__" => nil,
          "error" => true,
          "message" => "Invalid enumerable"
        },
        # This is to avoid end users receiving messages containing internal error details.
        expected_string_result: "",
        context: %{}
      )
    end
  end

  describe "nil safety for callbacks" do
    test "with_index returns empty list for nil" do
      assert [] == Expression.evaluate!("@with_index(items)", %{"items" => nil})
    end

    test "uniq returns empty list for nil" do
      assert [] == Expression.evaluate!("@uniq(items)", %{"items" => nil})
    end

    test "regex_capture returns nil for nil input" do
      assert nil == Expression.evaluate!("@regex_capture(text, \"test(.+)\")", %{"text" => nil})
    end

    test "regex_named_capture returns empty map for nil input" do
      assert %{} ==
               Expression.evaluate!(
                 "@regex_named_capture(text, \"test(?P<match>.+)\")",
                 %{"text" => nil}
               )
    end

    test "has_any_word returns false for nil words" do
      assert false ==
               Expression.evaluate_as_boolean!(
                 "@has_any_word('hello world', words)",
                 %{"words" => nil}
               )
    end
  end
end
