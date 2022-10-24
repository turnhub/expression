defmodule ExpressionCustomCallbacksTest do
  use ExUnit.Case

  defmodule CustomCallback do
    use Expression.Callbacks

    def echo(ctx, value) do
      value = eval!(value, ctx)

      "You said #{inspect(value)}"
    end

    def count(ctx, value) do
      case eval!(value, ctx) do
        string when is_binary(string) -> String.length(string)
        list when is_list(list) -> length(list)
        other -> Enum.count(other)
      end
    end
  end

  test "custom callback" do
    assert {:ok, "You said \"foo\""} == Expression.evaluate("@echo(\"foo\")", %{}, CustomCallback)
  end

  test "custom callback inside a common callback" do
    assert {:ok, "You Said \"foo\""} ==
             Expression.evaluate("@proper(echo(\"foo\"))", %{}, CustomCallback)
  end

  test "common callback inside a custom callback" do
    assert {:ok, "You said \"Foo\""} ==
             Expression.evaluate("@echo(proper(\"foo\"))", %{}, CustomCallback)
  end

  test "custom callback inside a block" do
    assert {:ok, 4} == Expression.evaluate("@(count(\"foo\") + 1)", %{}, CustomCallback)
  end

  test "fallback to default callback" do
    assert {:ok, "FOO"} = Expression.evaluate("@upper(\"foo\")", %{}, CustomCallback)
  end
end
