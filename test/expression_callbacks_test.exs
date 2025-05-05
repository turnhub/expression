defmodule ExpressionCallbacksTest do
  use ExUnit.Case, async: true
  doctest Expression.Callbacks, import: true
  doctest Expression.Callbacks.Standard, import: true

  alias Expression.Callbacks.Standard

  describe "parse_json/2" do
    test "should return an error if json is invalid" do
      assert Standard.parse_json(
               %{
                 "new_weight" =>
                   "{\n   \"date\": 2025-05-05T02:11:52.901303Z,\n   \"weight\": ref_weight\n }\n"
               },
               {:atom, "new_weight"}
             ) == %{
               "__type__" => "expression/v1error",
               "__value__" => nil,
               "error" => true,
               "message" =>
                 "Unable to decode JSON \"{\n   \"date\": 2025-05-05T02:11:52.901303Z,\n   \"weight\": ref_weight\n }\n\" due to an invalid byte at position 17"
             }
    end
  end
end
