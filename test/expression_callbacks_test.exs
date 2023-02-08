defmodule ExpressionCallbacksTest do
  @moduledoc false
  use ExUnit.Case, async: true
  doctest Expression.Callbacks, import: true
  doctest Expression.Callbacks.Standard, import: true

  @context %{
    "base_date" => ~U[2023-02-03 20:18:03Z],
    "number" => %{"from_addr" => "+552197295926"}
  }

  describe "next/4" do
    test "Shifts a datetime to the next occurrence of a given day of the week and a set time." do
      assert Expression.evaluate_block!(~s(next\(monday, 10:00, base_date\)), @context) ==
               DateTime.new!(~D[2023-02-06], ~T[10:00:00], "America/Sao_Paulo")
    end

    test "If the day of the week is the same as the base date, the next occurrence is 7 days later." do
      assert Expression.evaluate_block!(~s(next\(thursday, 10:30, base_date\)), @context) ==
               DateTime.new!(~D[2023-02-09], ~T[10:30:00], "America/Sao_Paulo")
    end

    test "Day of the week is after the base date." do
      assert Expression.evaluate_block!(~s(next\(friday, 22:20, base_date\)), @context) ==
               DateTime.new!(~D[2023-02-10], ~T[22:20:00], "America/Sao_Paulo")
    end

    test "Works if given a date as base date instead of a datetime" do
      assert Expression.evaluate_block!(
               ~s(next\(sunday, 22:20, date\(2023, 2, 08\)\)),
               %{"number" => %{"from_addr" => "+552197295926"}}
             ) ==
               DateTime.new!(~D[2023-02-12], ~T[22:20:00.000000], "America/Sao_Paulo")
    end

    test "Works across different timezones" do
      assert Expression.evaluate_block!(
               ~s(next\(saturday, 08:45, base_date\)),
               %{
                 "base_date" =>
                   DateTime.new!(~D[2023-02-08], ~T[22:20:00], "Africa/Johannesburg"),
                 "number" => %{"from_addr" => "+552197295926"}
               }
             ) ==
               DateTime.new!(~D[2023-02-11], ~T[08:45:00], "America/Sao_Paulo")
    end
  end
end
