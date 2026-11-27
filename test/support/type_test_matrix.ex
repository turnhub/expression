defmodule Expression.Test.TypeTestMatrix do
  @moduledoc """
  Standard test values for systematic type testing of expression functions.

  Provides a canonical set of sample values for every type the expression
  language can encounter at runtime, so type-handling tests across functions
  exercise the same inputs consistently.
  """

  @doc "All sample values across every category, as a flat list."
  def all_test_values do
    Enum.flat_map(categories(), &test_values_for/1)
  end

  @doc "The list of value categories available in the matrix."
  def categories do
    [
      :nil_value,
      :boolean,
      :integer,
      :float,
      :string,
      :list,
      :map,
      :complex,
      :date,
      :decimal,
      :error
    ]
  end

  @doc "Sample values for a single category."
  def test_values_for(:nil_value), do: [nil]
  def test_values_for(:boolean), do: [true, false]
  def test_values_for(:integer), do: [0, 1, 42, -7, 1_000_000_000_000]
  def test_values_for(:float), do: [0.0, 3.14, -2.5, 1.0e-10]

  def test_values_for(:string),
    do: ["", "hello", "123", "3.14", "héllo wörld", "👋🌍", "   ", "hello world"]

  def test_values_for(:list),
    do: [[], [1, 2, 3], ["a", "b"], [1, "two", true, nil], [[1, 2], [3, 4]]]

  def test_values_for(:map),
    do: [%{}, %{"key" => "value"}, %{"outer" => %{"inner" => 1}}]

  def test_values_for(:complex),
    do: [complex_value("text"), complex_value(42), complex_value(nil)]

  def test_values_for(:date),
    do: [~D[2023-06-15], ~T[10:30:00], ~U[2023-06-15 10:30:00Z], ~N[2023-06-15 10:30:00]]

  def test_values_for(:decimal), do: [Decimal.new("1.5"), Decimal.new(0)]
  def test_values_for(:error), do: [error_value()]

  @doc """
  Values generally invalid for the given function category — useful for
  asserting graceful handling of type mismatches.
  """
  def invalid_values_for(:string), do: test_values_for(:list) ++ test_values_for(:map)

  def invalid_values_for(:number),
    do: ["hello", true, [], %{}, ~D[2023-06-15]]

  def invalid_values_for(:date), do: ["not a date", 123, true, [], %{}]
  def invalid_values_for(:enum), do: ["hello", 123, true, %{"key" => "value"}]
  def invalid_values_for(:logical), do: [[], %{}, ~D[2023-06-15]]

  @doc """
  A complex value: a map carrying a `__value__` key, as produced by flow
  results. Functions are expected to extract `__value__` as the default value.
  """
  def complex_value(value, extra \\ %{}) do
    Map.merge(%{"__value__" => value, "label" => "complex"}, extra)
  end

  @doc "An error map as returned by the V1 engine when evaluation fails."
  def error_value(message \\ "Something went wrong") do
    %{
      "__type__" => "expression/v1error",
      "__value__" => nil,
      "error" => true,
      "message" => message
    }
  end

  @doc """
  Evaluates `expression` (block syntax, no leading `@`) with `value` bound to
  the `value` key in the context. Convenience for type matrix tests.
  """
  def evaluate_with_value(expression, value, extra_context \\ %{}) do
    Expression.evaluate_block!(expression, Map.merge(%{"value" => value}, extra_context))
  end
end
