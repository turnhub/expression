defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "text" do
      assert {:ok, [text: ["hello"]], _, _, _, _} = Excellent.parse("hello")
    end

    test "decimal" do
      value = Decimal.new("1.23")

      assert {:ok, [substitution: [block: [literal: [^value]]]], _, _, _, _} =
               Excellent.parse("@(1.23)")
    end

    test "datetime" do
      {:ok, value, 0} = DateTime.from_iso8601("2020-11-21T20:13:51.921042Z")

      assert {:ok, [substitution: [block: [literal: [^value]]]], _, _, _, _} =
               Excellent.parse("@(2020-11-21T20:13:51.921042Z)")

      {:ok, value, 0} = DateTime.from_iso8601("2020-02-01T23:23:23Z")

      assert {:ok, [substitution: [block: [literal: [^value]]]], _, _, _, _} =
               Excellent.parse("@(01-02-2020 23:23:23)")

      full_minute = %{value | second: 0}

      assert {:ok, [substitution: [block: [literal: [^full_minute]]]], _, _, _, _} =
               Excellent.parse("@(01-02-2020 23:23)")
    end

    test "boolean" do
      assert {:ok, [substitution: [block: [literal: [true]]]], _, _, _, _} =
               Excellent.parse("@(true)")

      assert {:ok, [substitution: [block: [literal: [true]]]], _, _, _, _} =
               Excellent.parse("@(True)")

      assert {:ok, [substitution: [block: [literal: [false]]]], _, _, _, _} =
               Excellent.parse("@(false)")

      assert {:ok, [substitution: [block: [literal: [false]]]], _, _, _, _} =
               Excellent.parse("@(False)")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, [substitution: [variable: ["contact"]]], _, _, _, _} =
               Excellent.parse("@contact")

      assert {:ok, [substitution: [variable: ["contact", "name"]]], _, _, _, _} =
               Excellent.parse("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, [substitution: [block: [variable: ["contact", "name"]]]], _, _, _, _} =
               Excellent.parse("@(contact.name)")
    end
  end

  describe "functions" do
    test "without arguments" do
      assert {:ok, [substitution: [function: ["HOUR"]]], _, _, _, _} = Excellent.parse("@HOUR()")
    end

    test "with a single argument" do
      assert {:ok,
              [
                substitution: [
                  function: ["HOUR", {:variable, ["contact", "timestamp"]}]
                ]
              ], _, _, _, _} = Excellent.parse("@HOUR(contact.timestamp)")
    end

    test "with a multiple argument" do
      assert {:ok,
              [
                substitution: [
                  function: [
                    "EDATE",
                    {
                      :variable,
                      ["date", "today"]
                    },
                    {
                      :literal,
                      [1]
                    }
                  ]
                ]
              ], _, _, _, _} = Excellent.parse("@EDATE(date.today, 1)")
    end

    test "with functions" do
      assert {:ok,
              [
                substitution: [function: ["HOUR", {:function, ["NOW"]}]]
              ], _, _, _, _} = Excellent.parse("@HOUR(NOW())")
    end
  end

  describe "logic" do
    test "add" do
      assert {:ok,
              [substitution: [block: [{:literal, [1]}, {:operator, ["+"]}, {:variable, ["a"]}]]],
              _, _, _, _} = Excellent.parse("@(1 + a)")

      assert {:ok,
              [
                substitution: [
                  block: [{:variable, ["contact", "age"]}, {:operator, ["+"]}, {:literal, [1]}]
                ]
              ], _, _, _, _} = Excellent.parse("@(contact.age+1)")
    end

    test "join" do
      assert {:ok,
              [
                substitution: [
                  block: [
                    {:variable, ["contact", "first_name"]},
                    {:operator, ["&"]},
                    {:literal, [" "]},
                    {:operator, ["&"]},
                    {:variable, ["contact", "last_name"]}
                  ]
                ]
              ], _, _, _,
              _} = Excellent.parse("@(contact.first_name & \" \" & contact.last_name)")
    end
  end

  describe "evaluate" do
    test "operator precedence" do
      assert {:ok, "7"} = Excellent.evaluate("@(1 + 2 * 3)")
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
  end
end
