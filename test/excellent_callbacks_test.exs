defmodule ExcellentCallbacksTest do
  use ExUnit.Case
  doctest Excellent.Callbacks

  describe "word_slice" do
    test "2, 4" do
      assert "expressions are" =
               Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2, 4)
    end

    test "2" do
      assert "expressions are fun" =
               Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2)
    end

    test "1, -2" do
      assert "RapidPro expressions" =
               Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 1, -2)
    end
  end
end
