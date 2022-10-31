defmodule ExpressionTest do
  use ExUnit.Case, async: true
  doctest Expression

  describe "evaluate_as_boolean!" do
    assert true == Expression.evaluate_as_boolean!("@(tRuE)")
    assert false == Expression.evaluate_as_boolean!("@(fAlSe)")
    assert true == Expression.evaluate_as_boolean!("@(1 > 0)")
    assert true == Expression.evaluate_as_boolean!("@has_all_words('foo', 'foo')")
    assert true == Expression.evaluate_as_boolean!("@or(has_all_words('foo', 'bar'), true)")
    assert false == Expression.evaluate_as_boolean!("@and(has_all_words('foo', 'bar'), true)")
    assert true == Expression.evaluate_as_boolean!("@and(has_all_words('foo', 'foo'), true)")
  end

  describe "evaluate" do
    test "list with indices" do
      assert "bar" == Expression.evaluate_as_string!("@foo[1]", %{"foo" => ["baz", "bar"]})
    end

    test "list with variable" do
      assert "bar" =
               Expression.evaluate_as_string!("@foo[cursor]", %{
                 "foo" => ["baz", "bar"],
                 "cursor" => 1
               })
    end

    test "stringify primitives" do
      assert iso_dt = Expression.evaluate_as_string!("@NOW()")
      assert {:ok, %DateTime{}, 0} = DateTime.from_iso8601(iso_dt)
      assert "true" == Expression.evaluate_as_string!("@(tRuE)")
      assert "false" == Expression.evaluate_as_string!("@(FaLsE)")
      assert "1.23" == Expression.evaluate_as_string!("@(1.23)")
      assert "2022-06-28" == Expression.evaluate_as_string!("@date(2022, 6, 28)")
      assert "123" == Expression.evaluate_as_string!("@([1,2,3])")
    end

    test "list with attribute" do
      assert "bar" =
               Expression.evaluate_as_string!("@foo[0].name", %{"foo" => [%{"name" => "bar"}]})
    end

    test "list with out of bound indicess" do
      assert nil ==
               Expression.evaluate!("@foo[cursor]", %{"foo" => ["baz", "bar"], "cursor" => 100})

      assert nil == Expression.evaluate!("@foo[100]", %{"foo" => ["baz", "bar"]})
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
      assert_raise RuntimeError, "attribute is not found: `value`", fn ->
        Expression.evaluate_block!("block.value > 0", %{"block" => %{}})
      end
    end

    test "throw an error" do
      assert_raise RuntimeError, "expression is not a number: `\"not a number\"`", fn ->
        Expression.evaluate_block!("block.value > 0", %{"block" => %{"value" => "not a number"}})
      end
    end
  end
end
