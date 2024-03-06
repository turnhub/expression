defmodule Expression.V1.Test do
  use ExUnit.Case, async: true
  doctest Expression.V1
  alias Expression.V1

  describe "evaluate" do
    test "evaluate_as_boolean!" do
      assert true == V1.evaluate_as_boolean!("@(tRuE)")
      assert false == V1.evaluate_as_boolean!("@(fAlSe)")
      assert true == V1.evaluate_as_boolean!("@(1 > 0)")
      assert true == V1.evaluate_as_boolean!("@has_all_words('foo', 'foo')")
      assert true == V1.evaluate_as_boolean!("@or(has_all_words('foo', 'bar'), true)")
      assert false == V1.evaluate_as_boolean!("@and(has_all_words('foo', 'bar'), true)")
      assert true == V1.evaluate_as_boolean!("@and(has_all_words('foo', 'foo'), true)")
      assert true == V1.evaluate_as_boolean!("@has_phrase('foo', 'foo')")
      assert false == V1.evaluate_as_boolean!("@has_phrase('foo', 'bar')")

      assert false ==
               V1.evaluate_as_boolean!("@has_phrase(name, 'bar')", %{"name" => nil})

      assert true ==
               V1.evaluate_as_boolean!("@has_phrase(contact.number, \"456\")", %{
                 "contact" => %{"number" => 123_456}
               })

      assert true == V1.evaluate_as_boolean!("@has_only_phrase('foo bar', 'foo bar')")

      assert false ==
               V1.evaluate_as_boolean!("@has_only_phrase('foo bar baz', 'foo bar')")

      assert false ==
               V1.evaluate_as_boolean!("@has_only_phrase(name, 'bar')", %{"name" => nil})

      assert true ==
               V1.evaluate_as_boolean!("@has_beginning(contact.number, \"123\")", %{
                 "contact" => %{"number" => 123_456}
               })
    end

    test "list with indices" do
      assert "bar" == V1.evaluate_as_string!("@foo[1]", %{"foo" => ["baz", "bar"]})
    end

    test "list with variable" do
      assert "bar" =
               V1.evaluate_as_string!("@foo[cursor]", %{
                 "foo" => ["baz", "bar"],
                 "cursor" => 1
               })
    end

    test "stringify primitives" do
      assert iso_dt = V1.evaluate_as_string!("@NOW()")
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(iso_dt)
      assert "true" == V1.evaluate_as_string!("@(tRuE)")
      assert "false" == V1.evaluate_as_string!("@(FaLsE)")
      assert "1.23" == V1.evaluate_as_string!("@(1.23)")
      assert "2022-06-28" == V1.evaluate_as_string!("@date(2022, 6, 28)")
      assert "123" == V1.evaluate_as_string!("@([1,2,3])")
      assert "1" == V1.evaluate_as_string!(1)
      assert "1.5" == V1.evaluate_as_string!(1.5)
    end

    test "list with attribute" do
      assert "bar" =
               V1.evaluate_as_string!("@foo[0].name", %{"foo" => [%{"name" => "bar"}]})
    end

    test "list with out of bound indicess" do
      assert nil ==
               V1.evaluate!("@foo[cursor]", %{"foo" => ["baz", "bar"], "cursor" => 100})

      assert nil == V1.evaluate!("@foo[100]", %{"foo" => ["baz", "bar"]})
    end

    test "append one item" do
      assert {:ok, ["A", "B", "C"]} ==
               V1.evaluate("@append(list, item)", %{
                 "list" => ["A", "B"],
                 "item" => "C"
               })
    end

    test "append a list of items" do
      assert {:ok, ["A", "B", "C", "D", "E"]} ==
               V1.evaluate("@append(first_list, second_list)", %{
                 "first_list" => ["A", "B", "C"],
                 "second_list" => ["D", "E"]
               })
    end

    test "calculation with explicit precedence" do
      assert {:ok, 8} = V1.evaluate("@(2 + (2 * 3))")
    end

    test "calculation with default precedence" do
      assert {:ok, 8} = V1.evaluate("@(2 + 2 * 3)")
    end

    test "exponent precendence over addition" do
      assert {:ok, 10.0} = V1.evaluate("@(2 + 2 ^ 3)")
    end

    test "exponent precendence over multiplication" do
      assert {:ok, 16.0} = V1.evaluate("@(2 * 2 ^ 3)")
    end

    test "example calculation from floip expression docs" do
      assert {:ok, 0.999744} = V1.evaluate("@(1 + (2 - 3) * 4 / 5 ^ 6)")
    end

    test "evaluate map default value" do
      assert {:ok, "foo"} ==
               V1.evaluate("@map", %{
                 "map" => %{
                   "__value__" => "foo",
                   "bar" => "bar"
                 }
               })

      assert {:ok, "bar"} ==
               V1.evaluate("@map.bar", %{
                 "map" => %{
                   "__value__" => "foo",
                   "bar" => "bar"
                 }
               })
    end

    test "delete an element from a map" do
      assert {:ok, %{"age" => 32}} ==
               V1.evaluate("@delete(patient, \"gender\")", %{
                 "patient" => %{
                   "gender" => "?",
                   "age" => 32
                 }
               })

      assert {:ok, %{"gender" => "?", "age" => 32}} ==
               V1.evaluate("@delete(patient, \"unknown\")", %{
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
               V1.evaluate_block!("datevalue(today(), '%Y-%m-%d')")

      assert V1.evaluate_block!("date == today()", %{
               "date" => Date.utc_today()
             })

      assert V1.evaluate_block!("date == datevalue(today(), '%Y-%m-%d').date", %{
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
               V1.evaluate_block!(
                 "contact.reminder_timestamp < datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert false ==
               V1.evaluate_block!(
                 "contact.reminder_timestamp <= datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               V1.evaluate_block!(
                 "contact.reminder_timestamp > datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               V1.evaluate_block!(
                 "contact.reminder_timestamp >= datetime_add(contact.reminder_timestamp, -1, \"M\")",
                 ctx
               )

      assert true ==
               V1.evaluate_block!(
                 "contact.reminder_timestamp == datetime_add(contact.reminder_timestamp, 0, \"M\")",
                 ctx
               )
    end

    test "example logical comparison between integers" do
      assert {:ok, true} ==
               V1.evaluate("@(contact.age > 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age >= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age < 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <= 30)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age = 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age != 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <> 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 18}})
    end

    test "example logical comparison between decimals" do
      assert {:ok, true} ==
               V1.evaluate("@(contact.age > 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age >= 20.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age < 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <= 20.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <= 30.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age == 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, false} ==
               V1.evaluate("@(contact.age = 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age != 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age <> 18.0)", %{"contact" => %{"age" => "20.0"}})

      assert {:ok, true} ==
               V1.evaluate("@(contact.age == 18.0)", %{"contact" => %{"age" => "18.0"}})
    end

    test "logical comparison with lists" do
      assert {:ok, false} ==
               V1.evaluate("@(18 == answers[cursor])", %{
                 "answers" => ["yes"],
                 "cursor" => 0
               })

      assert {:ok, false} ==
               V1.evaluate("@(answers[cursor] == 18)", %{
                 "answers" => ["yes"],
                 "cursor" => 0
               })
    end

    test "escaping @s" do
      assert "user@example.org" = V1.evaluate_as_string!("user@@example.org")
      assert "user@example.org" = V1.evaluate_as_string!("@('user' & '@example.org')")
    end

    test "trailing full stops" do
      assert "bar." = V1.evaluate_as_string!("@foo.", %{"foo" => "bar"})
      assert "baz." = V1.evaluate_as_string!("@foo.bar.", %{"foo" => %{"bar" => "baz"}})
    end

    test "substitution" do
      assert {:ok, ["hello ", "name"]} =
               V1.evaluate("hello @(contact.name)", %{
                 "contact" => %{
                   "name" => "name"
                 }
               })
    end

    test "addition" do
      assert {:ok, ["next year you are ", 41, " years old"]} =
               V1.evaluate("next year you are @(contact.age + 1) years old", %{
                 "contact" => %{
                   "age" => 40
                 }
               })
    end

    test "function name case insensitivity" do
      assert {:ok, dt} = V1.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
      assert {:ok, dt} = V1.evaluate("@(noW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with zero arguments" do
      assert {:ok, dt} = V1.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with one or more arguments" do
      assert {:ok, dt} = V1.evaluate("@(DATE(2020, 12, 30))")
      assert dt.year == 2020
      assert dt.month == 12
      assert dt.day == 30
    end

    test "function calls default arguments" do
      now = NaiveDateTime.utc_now()
      assert {:ok, returned} = V1.evaluate("@(DATEVALUE(NOW()))")
      parsed = Timex.parse!(returned, "%Y-%m-%d %H:%M:%S", :strftime)
      assert NaiveDateTime.diff(now, parsed) < :timer.seconds(1)

      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d", :strftime)
      assert {:ok, expected} == V1.evaluate("@(DATEVALUE(NOW(), \"%Y-%m-%d\"))")
    end

    test "checking for nil vars with if" do
      assert 1 ==
               V1.evaluate!("@IF(value, value, 0)", %{
                 "value" => 1
               })

      assert 0 ==
               V1.evaluate!("@IF(value, value, 0)", %{
                 "value" => nil
               })

      assert 0 == V1.evaluate!("@IF(value, value, 0)", %{})

      assert 1 ==
               V1.evaluate!("@IF(value.foo, value.foo, 0)", %{
                 "value" => %{
                   "foo" => 1
                 }
               })
    end

    test "function calls with expressions" do
      assert {:ok, ["Dear ", "lovely client"]} =
               V1.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')", %{
                 "contact" => %{"gender" => "O"}
               })
    end

    test "evaluate_block" do
      assert {:ok, true} ==
               V1.evaluate_block("contact.age > 10", %{"contact" => %{"age" => 21}})

      assert {:ok, 2} == V1.evaluate_block("1 + 1")
    end

    test "return an error tuple" do
      assert {:error, "expression is not a number: `\"not a number\"`"} =
               V1.evaluate_block("block.value > 0", %{
                 "block" => %{"value" => "not a number"}
               })
    end

    test "return an error tuple when variables are not defined" do
      assert {:error, "attribute is not found: `value`"} =
               V1.evaluate_block("block.value > 0", %{"block" => %{}})

      assert {:error, "attribute is not found: `block.value`"} =
               V1.evaluate_block("block.value > 0", %{})
    end

    test "throw an error when variables are not defined" do
      assert_raise RuntimeError, "attribute is not found: `value`", fn ->
        V1.evaluate_block!("block.value > 0", %{"block" => %{}})
      end
    end

    test "throw an error" do
      assert_raise RuntimeError, "expression is not a number: `\"not a number\"`", fn ->
        V1.evaluate_block!("block.value > 0", %{"block" => %{"value" => "not a number"}})
      end

      assert_raise Protocol.UndefinedError, ~r/Enumerable not implemented for \"A\"/, fn ->
        V1.evaluate("@append(first_list, second_list)", %{
          "first_list" => "A",
          "second_list" => "B"
        })
      end

      assert_raise BadMapError, "expected a map, got: [\"A\", \"B\", \"C\"]", fn ->
        V1.evaluate("@delete(map, \"key\")", %{
          "map" => ["A", "B", "C"]
        })
      end
    end
  end

  test "escaping" do
    assert "@@if(foo, bar, baz)" == V1.escape("@if(foo, bar, baz)")
    assert "@@bar.baz" == V1.escape("@bar.baz")
    assert "@@if(foo, @bar, baz)" == V1.escape("@if(foo, @bar, baz)")
    assert "@@if(foo, @@bar.baz, baz)" == V1.escape("@if(foo, @bar.baz, baz)")
  end
end
