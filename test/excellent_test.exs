defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "text" do
      assert {:ok, [text: ["hello"]], _, _, _, _} = Excellent.parse("hello")
    end

    test "decimal" do
      value = Decimal.new("1.23")
      assert {:ok, [block: [value: ^value]], _, _, _, _} = Excellent.parse("@(1.23)")
    end

    test "datetime" do
      {:ok, value, 0} = DateTime.from_iso8601("2020-11-21T20:13:51.921042Z")

      assert {:ok, [block: [value: ^value]], _, _, _, _} =
               Excellent.parse("@(2020-11-21T20:13:51.921042Z)")

      {:ok, value, 0} = DateTime.from_iso8601("2020-02-01T23:23:23Z")

      assert {:ok, [block: [value: ^value]], _, _, _, _} =
               Excellent.parse("@(01-02-2020 23:23:23)")

      full_minute = %{value | second: 0}

      assert {:ok, [block: [value: ^full_minute]], _, _, _, _} =
               Excellent.parse("@(01-02-2020 23:23)")
    end

    test "boolean" do
      assert {:ok, [block: [value: true]], _, _, _, _} = Excellent.parse("@(true)")
      assert {:ok, [block: [value: true]], _, _, _, _} = Excellent.parse("@(True)")
      assert {:ok, [block: [value: false]], _, _, _, _} = Excellent.parse("@(false)")
      assert {:ok, [block: [value: false]], _, _, _, _} = Excellent.parse("@(False)")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, [substitution: [field: ["contact"]]], _, _, _, _} =
               Excellent.parse_substitution("@contact")

      assert {:ok, [substitution: [field: ["contact", "name"]]], _, _, _, _} =
               Excellent.parse_substitution("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, [block: [field: ["contact", "name"]]], _, _, _, _} =
               Excellent.parse_block("@(contact.name)")
    end
  end

  describe "functions" do
    test "without arguments" do
      assert {:ok, [function: ["HOUR"]], _, _, _, _} = Excellent.parse_function("HOUR()")
    end

    test "with a single argument" do
      assert {:ok,
              [
                function: ["HOUR", {:arguments, [field: ["contact", "timestamp"]]}]
              ], _, _, _, _} = Excellent.parse_function("HOUR(contact.timestamp)")
    end

    test "with a multiple argument" do
      assert {:ok,
              [
                function: [
                  "EDATE",
                  {
                    :arguments,
                    [
                      field: ["date", "today"],
                      value: 1
                    ]
                  }
                ]
              ], _, _, _, _} = Excellent.parse_function("EDATE(date.today, 1)")
    end

    test "with functions" do
      assert {:ok,
              [
                function: ["HOUR", {:arguments, [function: ["NOW"]]}]
              ], _, _, _, _} = Excellent.parse_function("HOUR(NOW())")
    end
  end

  describe "logic" do
    test "add" do
      assert {:ok, [block: [{:value, 1}, {:operator, ["+"]}, {:field, ["a"]}]], _, _, _, _} =
               Excellent.parse("@(1 + a)")

      assert {:ok, [block: [{:field, ["contact", "age"]}, {:operator, ["+"]}, {:value, 1}]], _, _,
              _, _} = Excellent.parse("@(contact.age+1)")
    end

    test "join" do
      assert {:ok,
              [
                block: [
                  {:field, ["contact", "first_name"]},
                  {:operator, ["&"]},
                  {:value, {:string, [" "]}},
                  {:operator, ["&"]},
                  {:field, ["contact", "last_name"]}
                ]
              ], _, _, _,
              _} = Excellent.parse("@(contact.first_name & \" \" & contact.last_name)")
    end
  end

  describe "evaluate" do
    test "substitution" do
      assert "hello name" =
               Excellent.evaluate("hello @(contact.name)", %{
                 "contact" => %{
                   "name" => "name"
                 }
               })
    end

    @tag :skip
    test "addition" do
      assert {:ok, [block: [{:field, ["contact", "age"]}, {:operator, ["+"]}, {:value, 1}]], _, _,
              _,
              _} =
               Excellent.evaluate("hello @(contact.age+1)", %{
                 "contact" => %{
                   "age" => 40
                 }
               })
    end
  end
end
