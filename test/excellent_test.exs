defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "text" do
      assert {:ok, [text: ["hello"]]} = Excellent.parse("hello")
    end

    test "decimal" do
      value = Decimal.new("1.23")

      assert {:ok, [substitution: [block: [literal: ^value]]]} = Excellent.parse("@(1.23)")
    end

    test "datetime" do
      {:ok, value, 0} = DateTime.from_iso8601("2020-11-21T20:13:51.921042Z")

      assert {:ok, [substitution: [block: [literal: ^value]]]} =
               Excellent.parse("@(2020-11-21T20:13:51.921042Z)")

      {:ok, value, 0} = DateTime.from_iso8601("2020-02-01T23:23:23Z")

      assert {:ok, [substitution: [block: [literal: ^value]]]} =
               Excellent.parse("@(01-02-2020 23:23:23)")

      full_minute = %{value | second: 0}

      assert {:ok, [substitution: [block: [literal: ^full_minute]]]} =
               Excellent.parse("@(01-02-2020 23:23)")
    end

    test "boolean" do
      assert {:ok, [substitution: [block: [literal: true]]]} = Excellent.parse("@(true)")

      assert {:ok, [substitution: [block: [literal: true]]]} = Excellent.parse("@(True)")

      assert {:ok, [substitution: [block: [literal: false]]]} = Excellent.parse("@(false)")

      assert {:ok, [substitution: [block: [literal: false]]]} = Excellent.parse("@(False)")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, [substitution: [variable: ["contact"]]]} = Excellent.parse("@contact")

      assert {:ok, [substitution: [variable: ["contact", "name"]]]} =
               Excellent.parse("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, [substitution: [block: [variable: ["contact", "name"]]]]} =
               Excellent.parse("@(contact.name)")
    end
  end

  describe "functions" do
    test "without arguments" do
      assert {:ok, [substitution: [function: ["HOUR"]]]} = Excellent.parse("@HOUR()")
    end

    test "with a single argument" do
      assert {:ok,
              [
                substitution: [
                  function: ["HOUR", {:arguments, [variable: ["contact", "timestamp"]]}]
                ]
              ]} = Excellent.parse("@HOUR(contact.timestamp)")
    end

    test "with a multiple argument" do
      assert {:ok,
              [
                substitution: [
                  function: [
                    "EDATE",
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
              ]} = Excellent.parse("@EDATE(date.today, 1)")
    end

    test "with functions" do
      assert {:ok,
              [
                substitution: [function: ["HOUR", {:arguments, [{:function, ["NOW"]}]}]]
              ]} = Excellent.parse("@HOUR(NOW())")
    end
  end

  describe "logic" do
    test "add" do
      assert {:ok,
              [
                substitution: [
                  block: [+: [literal: 1, variable: ["a"]]]
                ]
              ]} = Excellent.parse("@(1 + a)")

      assert {:ok,
              [
                substitution: [
                  block: [+: [{:variable, ["contact", "age"]}, {:literal, 1}]]
                ]
              ]} = Excellent.parse("@(contact.age+1)")
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
              ]} = Excellent.parse("@(contact.first_name & \" \" & contact.last_name)")
    end
  end

  describe "evaluate" do
    test "calculation with explicit precedence" do
      assert {:ok, 8} = Excellent.evaluate("@(2 + (2 * 3))")
    end

    test "calculation with default precedence" do
      assert {:ok, 8} = Excellent.evaluate("@(2 + 2 * 3)")
    end

    test "exponent precendence over addition" do
      assert {:ok, 10.0} = Excellent.evaluate("@(2 + 2 ^ 3)")
    end

    test "exponent precendence over multiplication" do
      assert {:ok, 16.0} = Excellent.evaluate("@(2 * 2 ^ 3)")
    end

    test "example calculation from floip expression docs" do
      assert {:ok, 0.999744} = Excellent.evaluate("@(1 + (2 - 3) * 4 / 5 ^ 6)")
    end

    test "example logical comparison" do
      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age > 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age >= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Excellent.evaluate("@(contact.age < 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age <= 20)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Excellent.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, false} ==
               Excellent.evaluate("@(contact.age = 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age != 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age <> 18)", %{"contact" => %{"age" => 20}})

      assert {:ok, true} ==
               Excellent.evaluate("@(contact.age == 18)", %{"contact" => %{"age" => 18}})
    end

    test "escaping @s" do
      assert {:ok, "user@example.org"} = Excellent.evaluate("user@@example.org")
      assert {:ok, "user@example.org"} = Excellent.evaluate("@(\"user\" & \"@example.org\")")
    end

    test "substitution" do
      assert {:ok, "hello name"} =
               Excellent.evaluate("hello @(contact.name)", %{
                 "contact" => %{
                   "name" => "name"
                 }
               })
    end

    test "addition" do
      assert {:ok, "next year you are 41 years old"} =
               Excellent.evaluate("next year you are @(contact.age + 1) years old", %{
                 "contact" => %{
                   "age" => 40
                 }
               })
    end

    test "function name case insensitivity" do
      assert {:ok, dt} = Excellent.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
      assert {:ok, dt} = Excellent.evaluate("@(noW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with zero arguments" do
      assert {:ok, dt} = Excellent.evaluate("@(NOW())")
      assert dt.year == DateTime.utc_now().year
    end

    test "function calls with one or more arguments" do
      assert {:ok, dt} = Excellent.evaluate("@(DATE(2020, 12, 30))")
      assert dt.year == 2020
      assert dt.month == 12
      assert dt.day == 30
    end

    test "function calls default arguments" do
      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d %H:%M:%S", :strftime)
      assert {:ok, expected} == Excellent.evaluate("@(DATEVALUE(NOW()))")

      expected = Timex.format!(DateTime.utc_now(), "%Y-%m-%d", :strftime)
      assert {:ok, expected} == Excellent.evaluate("@(DATEVALUE(NOW(), \"%Y-%m-%d\"))")
    end

    test "function calls with expressions" do
      assert {:ok,
              [
                text: ["Dear "],
                substitution: [
                  function: [
                    "IF",
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
              ]} = Excellent.parse("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')")

      assert {:ok, "Dear lovely client"} =
               Excellent.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'lovely client')", %{
                 "contact" => %{"gender" => "O"}
               })
    end

    test "evaluate_expression" do
      assert {:ok, true} ==
               Excellent.evaluate_expression("contact.age > 10", %{contact: %{age: 21}})

      assert {:ok, 2} == Excellent.evaluate_expression("1 + 1")
    end
  end
end
