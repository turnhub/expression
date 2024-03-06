defmodule ExpressionContextTest do
  use ExUnit.Case, async: true
  doctest Expression.V1.Context

  test "context with underscores" do
    assert %{
             "trouble" => "_she_calls_me_princes___🤔",
             "integer" => 1,
             "string_integer" => 1
           } ==
             Expression.V1.Context.new(%{
               "string_integer" => "1",
               "integer" => 1,
               "trouble" => "_she_calls_me_princes___🤔"
             })
  end
end
