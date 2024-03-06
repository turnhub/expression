defmodule ExpressionCustomCallbacksTest do
  use ExUnit.Case, async: true

  defmodule CustomCallback do
    use Expression.V1.Callbacks
    use Expression.Autodoc

    def echo(ctx, value) do
      value = eval!(value, ctx)

      "You said #{inspect(value)}"
    end

    def length_vargs(_ctx, args) do
      Enum.count(args)
    end

    def count(ctx, value) do
      case eval!(value, ctx) do
        string when is_binary(string) -> String.length(string)
        list when is_list(list) -> length(list)
        other -> Enum.count(other)
      end
    end
  end

  describe "implements" do
    test "defined functions" do
      assert {:exact, ExpressionCustomCallbacksTest.CustomCallback, :echo, 2} ==
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "echo",
                 [1]
               )
    end

    test "undefined functions" do
      assert {:error, "boo is not implemented."} ==
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "boo",
                 [1]
               )
    end

    test "wrong arity functions" do
      assert {:error, "echo is not implemented."} ==
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "echo",
                 [1, 2, 3]
               )
    end

    test "variable args functions" do
      assert {:vargs, ExpressionCustomCallbacksTest.CustomCallback, :length_vargs, 2} ==
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "length",
                 [1, 2, 3]
               )

      assert {:vargs, ExpressionCustomCallbacksTest.CustomCallback, :length_vargs, 2} ==
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "length",
                 []
               )
    end

    test "built in operators" do
      assert {:exact, ExpressionCustomCallbacksTest.CustomCallback, :!=, 2} =
               Expression.V1.Callbacks.implements(
                 ExpressionCustomCallbacksTest.CustomCallback,
                 "!=",
                 [1, 1]
               )
    end
  end

  test "custom callback" do
    assert {:ok, "You said \"foo\""} == Expression.evaluate("@echo(\"foo\")", %{}, CustomCallback)
  end

  test "custom callback inside a common callback" do
    assert {:ok, "You Said \"foo\""} ==
             Expression.evaluate("@proper(echo(\"foo\"))", %{}, CustomCallback)
  end

  test "custom callback with kernel operator" do
    assert {:ok, "You said true"} == Expression.evaluate("@echo(1 == 1)", %{}, CustomCallback)
  end

  test "custom callback with numeric kernel operator inside a common callback" do
    assert {:ok, "D"} == Expression.evaluate("@char(count(\"foo\") + 65)", %{}, CustomCallback)
  end

  test "custom callback with numeric kernel operator inside a custom callback" do
    assert {:ok, "You said 2"} ==
             Expression.evaluate("@echo(count(\"foo\") - 1)", %{}, CustomCallback)
  end

  test "custom callbacks with numeric kernel operator inside a common callback" do
    assert {:ok, "You Said 4"} ==
             Expression.evaluate("@proper(echo(count(\"foo\") + 1))", %{}, CustomCallback)
  end

  test "custom callback with numeric kernel operator with a list" do
    assert {:ok, 1} ==
             Expression.evaluate("@([1, 2, 3][count(\"foo\") - 3])", %{}, CustomCallback)
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
