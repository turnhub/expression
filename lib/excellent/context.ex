defmodule Excellent.Context do
  @moduledoc """

  A helper module for creating a context that can be
  used with Excellent.Eval

  # Example

    iex> Excellent.Context.new(%{foo: "bar"})
    %{"foo" => "bar"}
    iex> Excellent.Context.new(%{foo: %{bar: "baz"}})
    %{"foo" => %{"bar" => "baz"}}
    iex> Excellent.Context.new(%{foo: %{bar: 1}})
    %{"foo" => %{"bar" => 1}}
    iex> Excellent.Context.new(%{date: "2020-12-13T23:34:45"})
    %{"date" => ~U[2020-12-13 23:34:45.0Z]}
    iex> Excellent.Context.new(%{boolean: "true"})
    %{"boolean" => true}
    iex> Excellent.Context.new(%{float: 1.234})
    %{"float" => 1.234}
    iex> ctx = Excellent.Context.new(%{decimal: "1.234"})
    iex> ctx["decimal"]
    #Decimal<1.234>
    iex> Excellent.Context.new(%{mixed: ["2020-12-13T23:34:45", 1, "true", "binary"]})
    %{"mixed" => [~U[2020-12-13 23:34:45.0Z], 1, true, "binary"]}

  """
  def new(ctx, mod \\ Excellent.Callbacks)

  def new(ctx, mod) when is_map(ctx) do
    ctx
    # Ensure all keys are strings
    |> Enum.map(&string_key/1)
    |> Enum.map(&iterate(&1, mod))
    |> Enum.into(%{})
  end

  defp string_key({key, value}), do: {to_string(key), value}

  defp iterate({key, value}, mod) when is_map(value) or is_list(value) do
    {key, evaluate(value, mod)}
  end

  defp iterate({key, value}, mod) when is_binary(value), do: {key, evaluate(value, mod)}

  defp iterate({key, value}, _mod), do: {key, value}

  defp evaluate(ctx, mod) when is_map(ctx) do
    new(ctx, mod)
  end

  defp evaluate(ctx, mod) when is_list(ctx) do
    ctx
    |> Enum.map(&evaluate(&1, mod))
  end

  defp evaluate(value, _mod) when not is_binary(value), do: value

  defp evaluate(binary, mod) when is_binary(binary) do
    with {:ok, ast} <- Excellent.parse_expression(binary),
         {:ok, value} <- Excellent.Eval.evaluate([substitution: ast], %{}, mod) do
      value
    else
      _ -> binary
    end
  rescue
    RuntimeError -> binary
  end
end
