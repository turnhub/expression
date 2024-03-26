defmodule Expression.ContextTest do
  use ExUnit.Case
  alias Expression.Context

  test "new context from a context containing a datetime string" do
    context = %{"block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.921378"}}}

    assert %{"block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}} =
             Context.new(context)
  end

  test "new context from a context containing a datetime string with microseconds precision 7" do
    context = %{"block" => %{"value" => %{"program_start_date" => "2022-11-10T13:40:05.9213782"}}}

    # Assert that the microseconds are truncated to precision 6 (the maximum precision supported by Elixir's DateTime)
    assert %{"block" => %{"value" => %{"program_start_date" => ~U[2022-11-10 13:40:05.921378Z]}}} =
             Context.new(context)
  end

  describe "context is parsed correctly when using the `skip_context_evaluation?` option" do
    test "string values in context that resemble booleans should not be parsed as booleans" do
      # By default (without the flag) boolean-ish string values as parsed as booleans
      assert %{"block" => %{"response" => true}} ==
               Context.new(%{
                 "block" => %{"response" => "True"}
               })

      # With the flag set to true they are kept as strings
      assert %{"block" => %{"response" => "True"}} ==
               Context.new(%{"block" => %{"response" => "True"}},
                 skip_context_evaluation?: true
               )

      assert %{"block" => %{"response" => "true"}} ==
               Context.new(
                 %{"block" => %{"response" => "true"}},
                 skip_context_evaluation?: true
               )
    end

    test "string values in context that resemble numbers should not be parsed as numbers" do
      assert %{
               "ref_buttons_7bef16" => %{
                 "__value__" => "2",
                 "index" => 1,
                 "label" => "2",
                 "name" => "2"
               }
             } ==
               Context.new(
                 %{
                   "ref_Buttons_7bef16" => %{
                     "__value__" => "2",
                     "index" => 1,
                     "label" => "2",
                     "name" => "2"
                   }
                 },
                 skip_context_evaluation?: true
               )
    end
  end
end
