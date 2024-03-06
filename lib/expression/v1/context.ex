defmodule Expression.V1.Context do
  @moduledoc """

  A helper module for creating a context that can be
  used with Expression.Eval

  # Example

    iex> Expression.V1.Context.new(%{foo: "bar"})
    %{"foo" => "bar"}
    iex> Expression.V1.Context.new(%{FOO: "bar"})
    %{"foo" => "bar"}
    iex> Expression.V1.Context.new(%{foo: %{bar: "baz"}})
    %{"foo" => %{"bar" => "baz"}}
    iex> Expression.V1.Context.new(%{Foo: %{Bar: "baz"}})
    %{"foo" => %{"bar" => "baz"}}
    iex> Expression.V1.Context.new(%{foo: %{bar: 1}})
    %{"foo" => %{"bar" => 1}}
    iex> Expression.V1.Context.new(%{date: "2020-12-13T23:34:45"})
    %{"date" => ~U[2020-12-13 23:34:45.0Z]}
    iex> Expression.V1.Context.new(%{boolean: "true"})
    %{"boolean" => true}
    iex> Expression.V1.Context.new(%{float: 1.234})
    %{"float" => 1.234}
    iex> now = DateTime.utc_now()
    iex> ctx = Expression.V1.Context.new(%{float: "1.234", nested: %{date: now}})
    iex> ctx["float"]
    1.234
    iex> now == ctx["nested"]["date"]
    true
    iex> Expression.V1.Context.new(%{mixed: ["2020-12-13T23:34:45", 1, "true", "binary"]})
    %{"mixed" => [~U[2020-12-13 23:34:45.0Z], 1, true, "binary"]}

  """
  @type t :: map

  @spec new(map) :: t
  def new(ctx) when is_map(ctx) do
    ctx
    # Ensure all keys are lower case strings
    |> Enum.map(&downcase_string_key/1)
    |> Enum.map(&iterate(&1))
    |> Enum.into(%{})
  end

  defp downcase_string_key({key, value}), do: {String.downcase(to_string(key)), value}

  defp iterate({key, value}) when is_map(value) or is_list(value) do
    {key, evaluate!(value)}
  end

  defp iterate({key, value}) when is_binary(value), do: {key, evaluate!(value)}

  defp iterate({key, value}), do: {key, value}

  defp evaluate!(ctx) when is_map(ctx) and not is_struct(ctx) do
    new(ctx)
  end

  defp evaluate!(ctx) when is_list(ctx) do
    ctx
    |> Enum.map(&evaluate!(&1))
  end

  defp evaluate!(binary) when is_binary(binary) do
    case Expression.V1.Parser.literal(binary) do
      {:ok, [{:literal, literal}], "", _, _, _} -> literal
      # when we're not parsing the full literal
      {:ok, [{:literal, _literal}], _, _, _, _} -> binary
      # when we're getting something entirely unexpected
      {:error, _reason, _, _, _, _} -> binary
    end
  rescue
    ArgumentError -> binary
  end

  defp evaluate!(value), do: value
end
