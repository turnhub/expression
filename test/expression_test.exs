defmodule ExpressionTest do
  use ExUnit.Case, async: true
  doctest Expression

  describe "types" do
    test "text" do
      assert {:ok, [text: "hello"]} = Expression.parse("hello")
    end

    test "decimal" do
      value = Decimal.new("1.23")

      assert {:ok, [substitution: [block: [literal: ^value]]]} = Expression.parse("@(1.23)")
    end

    test "datetime" do
      {:ok, value, 0} = DateTime.from_iso8601("2020-11-21T20:13:51.921042Z")

      assert {:ok, [substitution: [block: [literal: ^value]]]} =
               Expression.parse("@(2020-11-21T20:13:51.921042Z)")

      {:ok, value, 0} = DateTime.from_iso8601("2020-02-01T23:23:23Z")

      assert {:ok, [substitution: [block: [literal: ^value]]]} =
               Expression.parse("@(01-02-2020 23:23:23)")

      full_minute = %{value | second: 0}

      assert {:ok, [substitution: [block: [literal: ^full_minute]]]} =
               Expression.parse("@(01-02-2020 23:23)")
    end

    test "boolean" do
      assert {:ok, [substitution: [block: [literal: true]]]} = Expression.parse("@(true)")

      assert {:ok, [substitution: [block: [literal: true]]]} = Expression.parse("@(True)")

      assert {:ok, [substitution: [block: [literal: false]]]} = Expression.parse("@(false)")

      assert {:ok, [substitution: [block: [literal: false]]]} = Expression.parse("@(False)")
    end
  end

  describe "case insensitive" do
    test "variables" do
      assert {:ok, [substitution: [variable: ["contact", "name"]]]} =
               Expression.parse("@CONTACT.Name")
    end

    test "functions" do
      assert {:ok, [substitution: [function: ["hour"]]]} = Expression.parse("@hour()")

      assert {:ok, [substitution: [function: ["hour", {:arguments, [function: ["now"]]}]]]} =
               Expression.parse("@hour(Now())")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, [substitution: [variable: ["contact"]]]} = Expression.parse("@contact")

      assert {:ok, [substitution: [variable: ["contact", "name"]]]} =
               Expression.parse("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, [substitution: [block: [variable: ["contact", "name"]]]]} =
               Expression.parse("@(contact.name)")
    end
  end

  describe "functions" do
    test "without arguments" do
      assert {:ok, [substitution: [function: ["hour"]]]} = Expression.parse("@HOUR()")
    end

    test "with a single argument" do
      assert {:ok,
              [
                substitution: [
                  function: ["hour", {:arguments, [variable: ["contact", "timestamp"]]}]
                ]
              ]} = Expression.parse("@HOUR(contact.timestamp)")
    end

    test "with a multiple argument" do
      assert {:ok,
              [
                substitution: [
                  function: [
                    "edate",
                    {:arguments,
                     [
                       {
                         :variable,
                         ["date", "today"]
                       },
                       {
                         :literal,
                         1
                       }
                     ]}
                  ]
                ]
              ]} = Expression.parse("@EDATE(date.today, 1)")
    end

    test "with functions" do
      assert {:ok,
              [
                substitution: [function: ["hour", {:arguments, [{:function, ["now"]}]}]]
              ]} = Expression.parse("@HOUR(NOW())")
    end
  end

  describe "logic" do
    test "lte" do
      assert {
               :ok,
               [
                 {:substitution, [block: [<=: [variable: ["block", "value"], literal: 30]]]}
               ]
             } == Expression.parse("@(block.value <= 30)")
    end

    test "add" do
      assert {:ok,
              [
                substitution: [
                  block: [+: [literal: 1, variable: ["a"]]]
                ]
              ]} = Expression.parse("@(1 + a)")

      assert {:ok,
              [
                substitution: [
                  block: [+: [{:variable, ["contact", "age"]}, {:literal, 1}]]
                ]
              ]} = Expression.parse("@(contact.age+1)")
    end

    test "join" do
      assert {:ok,
              [
                substitution: [
                  block: [
                    &: [
                      {:&, [variable: ["contact", "first_name"], literal: " "]},
                      {:variable, ["contact", "last_name"]}
                    ]
                  ]
                ]
              ]} = Expression.parse("@(contact.first_name & \" \" & contact.last_name)")
    end
  end

  describe "evaluate" do
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

    test "example logical comparison" do
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

    test "escaping @s" do
      assert {:ok, "user@example.org"} = Expression.evaluate("user@@example.org")
      assert {:ok, "user@example.org"} = Expression.evaluate("@('user' & '@example.org')")
    end

    test "substitution" do
      assert {:ok, "hello name"} =
               Expression.evaluate("hello @(contact.name)", %{
                 "contact" => %{
                   "name" => "name"
                 }
               })
    end

    test "addition" do
      assert {:ok, "next year you are 41 years old"} =
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
      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S", :strftime)
      assert {:ok, expected} == Expression.evaluate("@(DATEVALUE(NOW()))")

      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d", :strftime)
      assert {:ok, expected} == Expression.evaluate("@(DATEVALUE(NOW(), \"%Y-%m-%d\"))")
    end

    test "function calls with expressions" do
      assert {:ok,
              [
                text: "Dear ",
                substitution: [
                  function: [
                    "if",
                    {:arguments,
                     [
                       {
                         :==,
                         [variable: ["contact", "gender"], literal: "M"]
                       },
                       {:literal, "Sir"},
                       {:literal, "lovely client"}
                     ]}
                  ]
                ]
              ]} = Expression.parse("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')")

      assert {:ok, "Dear lovely client"} =
               Expression.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')", %{
                 "contact" => %{"gender" => "O"}
               })
    end

    test "evaluate_block" do
      assert {:ok, true} ==
               Expression.evaluate_block("contact.age > 10", %{contact: %{age: 21}})

      assert {:ok, 2} == Expression.evaluate_block("1 + 1")
    end

    test "return an error tuple" do
      assert {:error, "expression is not a number: `\"not a number\"`"} =
               Expression.evaluate_block("block.value > 0", %{block: %{value: "not a number"}})
    end

    test "return an error tuple when variables are not defined" do
      assert {:error, "variable \"block.value\" is undefined or null"} =
               Expression.evaluate_block("block.value > 0", %{block: %{}})
    end

    test "throw an error when variables are not defined" do
      assert_raise RuntimeError, "variable \"block.value\" is undefined or null", fn ->
        Expression.evaluate_block!("block.value > 0", %{block: %{}})
      end
    end

    test "throw an error" do
      assert_raise RuntimeError, "expression is not a number: `\"not a number\"`", fn ->
        Expression.evaluate_block!("block.value > 0", %{block: %{value: "not a number"}})
      end
    end
  end
end
