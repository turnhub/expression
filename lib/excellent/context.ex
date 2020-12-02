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
    iex> now = DateTime.utc_now()
    iex> ctx = Excellent.Context.new(%{decimal: "1.234", nested: %{date: now}})
    iex> ctx["decimal"]
    #Decimal<1.234>
    iex> now == ctx["nested"]["date"]
    true
    iex> Excellent.Context.new(%{mixed: ["2020-12-13T23:34:45", 1, "true", "binary"]})
    %{"mixed" => [~U[2020-12-13 23:34:45.0Z], 1, true, "binary"]}

  """
  def new(ctx) when is_map(ctx) do
    ctx
    # Ensure all keys are strings
    |> Enum.map(&string_key/1)
    |> Enum.map(&iterate(&1))
    |> Enum.into(%{})
  end

  defp string_key({key, value}), do: {to_string(key), value}

  defp iterate({key, value}) when is_map(value) or is_list(value) do
    {key, evaluate(value)}
  end

  defp iterate({key, value}) when is_binary(value), do: {key, evaluate(value)}

  defp iterate({key, value}), do: {key, value}

  defp evaluate(ctx) when is_map(ctx) and not is_struct(ctx) do
    new(ctx)
  end

  defp evaluate(ctx) when is_list(ctx) do
    ctx
    |> Enum.map(&evaluate(&1))
  end

  defp evaluate(value) when not is_binary(value), do: value

  defp evaluate(binary) when is_binary(binary) do
    case Excellent.parse_literal(binary) do
      {:literal, literal} -> literal
      {:error, _reason} -> binary
    end
  end
end
