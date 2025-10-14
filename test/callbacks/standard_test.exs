defmodule ExpressionCallbacksStandardTest do
  use ExUnit.Case, async: true

  doctest Expression.Callbacks.Standard, import: true

  describe "has_phrase" do
    test "has_phrase should return true for enum type having the value provided in its __value__ key." do
      assert Expression.evaluate_block!(
               "has_phrase(contact.title, \"MR\")",
               %{
                 "contact" => %{
                   "title" => %{
                     "display" => "Mr",
                     "value" => "MR",
                     "__value__" => "MR"
                   }
                 }
               }
             ) == true
    end

    test "has_phrase should return false for enum type not having the value provided in its __value__ key." do
      assert Expression.evaluate_block!(
               "has_phrase(contact.title, \"MR\")",
               %{
                 "contact" => %{
                   "title" => %{
                     "display" => "Mr",
                     "value" => "MR",
                     "__value__" => "something_else"
                   }
                 }
               }
             ) == false
    end
  end
end
