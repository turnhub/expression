defmodule ExpressionCustomCallbacksTest do
  use ExUnit.Case

  defmodule CustomCallback do
    @behaviour Expression.Callbacks

    @impl true
    def handle(function_name, arguments, context) do
      case Expression.Callbacks.implements(__MODULE__, function_name, arguments) do
        {:exact, function_name, _arity} ->
          apply(__MODULE__, function_name, [context] ++ arguments)

        {:vars, function_name, _arity} ->
          apply(__MODULE__, function_name, [context, arguments])

        {:error, _not_implemented} ->
          Expression.Callbacks.handle(function_name, arguments, context)
      end
    end

    def echo(ctx, value) do
      value = Expression.Eval.eval!(value, ctx, __MODULE__)
      {:ok, "You said #{inspect(value)}"}
    end
  end

  test "custom callback" do
    assert {:ok, "You said \"foo\""} == Expression.evaluate("@echo(\"foo\")", %{}, CustomCallback)
  end

  test "fallback to default callback" do
    assert {:ok, "FOO"} = Expression.evaluate("@upper(\"foo\")", %{}, CustomCallback)
  end
end
