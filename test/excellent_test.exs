defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "text" do
      assert {:ok, [text: ["hello"]], _, _, _, _} = Excellent.parse("hello")
    end

    @tag :skip
    test "decimal" do
      assert {:ok, [block: [value: 1.23]], _, _, _, _} = Excellent.parse("@(1.23)")
    end

    @tag :skip
    test "datetime" do
      assert {:ok, [2020, 11, 21, 20, 13, 51, 921_042, "Z"], _, _, _, _} =
               Excellent.parse("2020-11-21T20:13:51.921042Z")

      assert {:ok, [1, 2, 2020, 23, 23, 23], _, _, _, _} = Excellent.parse("01-02-2020 23:23:23")

      assert {:ok, [1, 2, 2020, 23, 23], _, _, _, _} = Excellent.parse("01-02-2020 23:23")
    end

    @tag :skip
    test "boolean" do
      assert {:ok, [true], _, _, _, _} = Excellent.parse("true")
      assert {:ok, [true], _, _, _, _} = Excellent.parse("True")
      assert {:ok, [false], _, _, _, _} = Excellent.parse("false")
      assert {:ok, [false], _, _, _, _} = Excellent.parse("False")
    end
  end

  describe "logic" do
    @tag :skip
    test "=" do
      assert {:ok, ["="], _, _, _, _} = Excellent.parse("=")
    end

    @tag :skip
    test "<>" do
      assert {:ok, ["<>"], _, _, _, _} = Excellent.parse("<>")
    end

    @tag :skip
    test ">" do
      assert {:ok, [">"], _, _, _, _} = Excellent.parse(">")
    end

    @tag :skip
    test ">=" do
      assert {:ok, [">="], _, _, _, _} = Excellent.parse(">=")
    end

    @tag :skip
    test "<" do
      assert {:ok, ["<"], _, _, _, _} = Excellent.parse("<")
    end

    @tag :skip
    test "<=" do
      assert {:ok, ["<="], _, _, _, _} = Excellent.parse("<=")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, [substitution: [field: ["contact"]]], _, _, _, _} = Excellent.parse("@contact")

      assert {:ok, [substitution: [field: ["contact", "name"]]], _, _, _, _} =
               Excellent.parse("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, [block: [field: ["contact", "name"]]], _, _, _, _} =
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
                  function: ["HOUR", {:arguments, [field: ["contact", "timestamp"]]}]
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
                      :arguments,
                      [
                        field: ["date", "today"],
                        value: 1
                      ]
                    }
                  ]
                ]
              ], _, _, _, _} = Excellent.parse("@EDATE(date.today, 1)")
    end

    test "with functions" do
      assert {:ok,
              [
                substitution: [
                  function: ["HOUR", {:arguments, [function: ["NOW"]]}]
                ]
              ], _, _, _, _} = Excellent.parse("@HOUR(NOW())")
    end

    @tag :skip
    test "single var argument" do
      assert {:ok, ["YEAR", "(", "contact", ".", "age", ")"], _, _, _, _} =
               Excellent.parse("YEAR(contact.age)")
    end

    @tag :skip
    test "multiple integer arguments" do
      assert {:ok, ["DATE", "(", 2020, ",", 12, ",", 12, ")"], _, _, _, _} =
               Excellent.parse("DATE(2020, 12, 12)")
    end

    @tag :skip
    test "mixed var and integer arguments" do
      assert {:ok, ["EDATE", "(", "date", ".", "today", ",", 1, ")"], _, _, _, _} =
               Excellent.parse("EDATE(date.today, 1)")
    end
  end
end
