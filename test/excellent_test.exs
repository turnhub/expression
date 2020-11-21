defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "text" do
      assert {:ok, ["hello"], _, _, _, _} = Excellent.expression("hello")
    end

    test "decimal" do
      assert {:ok, [1, 23], _, _, _, _} = Excellent.expression("1.23")
    end

    test "datetime" do
      assert {:ok, [2020, 11, 21, 20, 13, 51, 921_042, "Z"], _, _, _, _} =
               Excellent.expression("2020-11-21T20:13:51.921042Z")

      assert {:ok, [1, 2, 2020, 23, 23, 23], _, _, _, _} =
               Excellent.expression("01-02-2020 23:23:23")

      assert {:ok, [1, 2, 2020, 23, 23], _, _, _, _} = Excellent.expression("01-02-2020 23:23")
    end

    test "boolean" do
      assert {:ok, [true], _, _, _, _} = Excellent.expression("true")
      assert {:ok, [true], _, _, _, _} = Excellent.expression("True")
      assert {:ok, [false], _, _, _, _} = Excellent.expression("false")
      assert {:ok, [false], _, _, _, _} = Excellent.expression("False")
    end
  end

  describe "logic" do
    test "=" do
      assert {:ok, ["="], _, _, _, _} = Excellent.expression("=")
    end

    test "<>" do
      assert {:ok, ["<>"], _, _, _, _} = Excellent.expression("<>")
    end

    test ">" do
      assert {:ok, [">"], _, _, _, _} = Excellent.expression(">")
    end

    test ">=" do
      assert {:ok, [">="], _, _, _, _} = Excellent.expression(">=")
    end

    test "<" do
      assert {:ok, ["<"], _, _, _, _} = Excellent.expression("<")
    end

    test "<=" do
      assert {:ok, ["<="], _, _, _, _} = Excellent.expression("<=")
    end
  end

  describe "templating" do
    test "substitution" do
      assert {:ok, ["@", "contact"], _, _, _, _} = Excellent.expression("@contact")

      assert {:ok, ["@", "contact", ".", "name"], _, _, _, _} =
               Excellent.expression("@contact.name")
    end
  end

  describe "blocks" do
    test "block" do
      assert {:ok, ["@", "(", "contact", ".", "name", ")"], _, _, _, _} =
               Excellent.expression("@(contact.name)")
    end
  end

  describe "functions" do
    test "nested functions" do
      assert {:ok, ["HOUR", "(", "NOW", "(", ")", ")"], _, _, _, _} =
               Excellent.expression("HOUR(NOW())")
    end

    test "single var argument" do
      assert {:ok, ["YEAR", "(", "contact", ".", "age", ")"], _, _, _, _} =
               Excellent.expression("YEAR(contact.age)")
    end

    test "multiple integer arguments" do
      assert {:ok, ["DATE", "(", 2020, ",", 12, ",", 12, ")"], _, _, _, _} =
               Excellent.expression("DATE(2020, 12, 12)")
    end

    test "mixed var and integer arguments" do
      assert {:ok, ["EDATE", "(", "date", ".", "today", ",", 1, ")"], _, _, _, _} =
               Excellent.expression("EDATE(date.today, 1)")
    end
  end
end
