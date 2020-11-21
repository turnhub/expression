defmodule ExcellentTest do
  use ExUnit.Case
  doctest Excellent

  describe "types" do
    test "string" do
      assert {:ok, ["hello"], _, _, _, _} = Excellent.string("hello")
    end

    test "decimal" do
      assert {:ok, [1, 23], _, _, _, _} = Excellent.decimal("1.23")
    end

    test "datetime" do
      assert {:ok, [2020, 11, 21, 20, 13, 51, 921_042, "Z"], _, _, _, _} =
               Excellent.datetime("2020-11-21T20:13:51.921042Z")

      assert {:ok, [1, 2, 2020, 23, 23, 23], _, _, _, _} =
               Excellent.datetime("01-02-2020 23:23:23")

      assert {:ok, [1, 2, 2020, 23, 23], _, _, _, _} = Excellent.datetime("01-02-2020 23:23")
    end

    test "boolean" do
      assert {:ok, [true], _, _, _, _} = Excellent.boolean("true")
      assert {:ok, [true], _, _, _, _} = Excellent.boolean("True")
      assert {:ok, [false], _, _, _, _} = Excellent.boolean("false")
      assert {:ok, [false], _, _, _, _} = Excellent.boolean("False")
    end
  end
end
