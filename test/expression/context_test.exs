defmodule Expression.ContextTest do
  use ExUnit.Case
  alias Expression.V1.Context

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
end
