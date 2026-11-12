defmodule Expression.DatePartsTest do
  use ExUnit.Case, async: true

  @functions ~w(day month year hour minute second weekday)

  @spec evaluate(String.t(), map, :v2 | :v3) :: term
  defp evaluate(expression, ctx, mode),
    do: Expression.evaluate!(expression, ctx, Expression.Callbacks, mode: mode)

  @spec error?(String.t(), map, :v2 | :v3) :: boolean
  defp error?(call, ctx, mode), do: evaluate("@is_error(#{call})", ctx, mode)

  for mode <- [:v2, :v3] do
    describe "date parts in #{mode} mode" do
      for function <- @functions do
        test "#{function} returns an error for nil" do
          assert error?("#{unquote(function)}(date)", %{"date" => nil}, unquote(mode))
        end

        test "#{function} returns an error for a missing key" do
          assert error?("#{unquote(function)}(contact.date)", %{"contact" => %{}}, unquote(mode))
        end

        test "#{function} returns an error for text that is not a date" do
          assert error?(~s|#{unquote(function)}("not a date")|, %{}, unquote(mode))
        end

        test "#{function} returns an error for a number" do
          assert error?("#{unquote(function)}(5)", %{}, unquote(mode))
        end

        test "#{function} renders an invalid date as empty text" do
          assert Expression.evaluate_as_string!(
                   "on @#{unquote(function)}(date)",
                   %{"date" => nil},
                   Expression.Callbacks,
                   mode: unquote(mode)
                 ) == "on "
        end
      end

      test "reads parts from a datetime string" do
        ctx = %{}
        value = ~s|"2024-03-05T10:20:30Z"|

        assert evaluate("@day(#{value})", ctx, unquote(mode)) == 5
        assert evaluate("@month(#{value})", ctx, unquote(mode)) == 3
        assert evaluate("@year(#{value})", ctx, unquote(mode)) == 2024
        assert evaluate("@hour(#{value})", ctx, unquote(mode)) == 10
        assert evaluate("@minute(#{value})", ctx, unquote(mode)) == 20
        assert evaluate("@second(#{value})", ctx, unquote(mode)) == 30
        assert evaluate("@weekday(#{value})", ctx, unquote(mode)) == 3
      end

      test "reads parts from a date string, at midnight" do
        ctx = %{}
        value = ~s|"2024-03-05"|

        assert evaluate("@day(#{value})", ctx, unquote(mode)) == 5
        assert evaluate("@month(#{value})", ctx, unquote(mode)) == 3
        assert evaluate("@year(#{value})", ctx, unquote(mode)) == 2024
        assert evaluate("@hour(#{value})", ctx, unquote(mode)) == 0
        assert evaluate("@minute(#{value})", ctx, unquote(mode)) == 0
        assert evaluate("@second(#{value})", ctx, unquote(mode)) == 0
        assert evaluate("@weekday(#{value})", ctx, unquote(mode)) == 3
      end

      test "reads parts from a date string in the context" do
        ctx = %{"date" => "2024-03-05T10:20:30Z"}

        assert evaluate("@day(date)", ctx, unquote(mode)) == 5
        assert evaluate("@hour(date)", ctx, unquote(mode)) == 10
        assert evaluate("@weekday(date)", ctx, unquote(mode)) == 3
      end

      test "reads parts from a naive datetime" do
        ctx = %{"date" => ~N[2024-03-05 10:20:30]}

        assert evaluate("@day(date)", ctx, unquote(mode)) == 5
        assert evaluate("@month(date)", ctx, unquote(mode)) == 3
        assert evaluate("@year(date)", ctx, unquote(mode)) == 2024
        assert evaluate("@hour(date)", ctx, unquote(mode)) == 10
        assert evaluate("@minute(date)", ctx, unquote(mode)) == 20
        assert evaluate("@second(date)", ctx, unquote(mode)) == 30
        assert evaluate("@weekday(date)", ctx, unquote(mode)) == 3
      end

      test "reads time parts from a time" do
        assert evaluate("@hour(time(12, 13, 14))", %{}, unquote(mode)) == 12
        assert evaluate("@minute(time(12, 13, 14))", %{}, unquote(mode)) == 13
        assert evaluate("@second(time(12, 13, 14))", %{}, unquote(mode)) == 14
      end

      test "reads time parts from a date, at midnight" do
        assert evaluate("@hour(date(2024, 3, 5))", %{}, unquote(mode)) == 0
        assert evaluate("@minute(date(2024, 3, 5))", %{}, unquote(mode)) == 0
        assert evaluate("@second(date(2024, 3, 5))", %{}, unquote(mode)) == 0
      end

      test "returns an error for date parts of a time" do
        assert error?("day(time(12, 13, 14))", %{}, unquote(mode))
        assert error?("weekday(time(12, 13, 14))", %{}, unquote(mode))
      end
    end
  end
end
