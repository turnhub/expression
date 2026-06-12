defmodule Expression.Test.FuzzHelpers do
  @moduledoc """
  StreamData generators and assertion helpers for property-based (fuzz)
  testing of expression functions.

  The goal of fuzz testing here is a single invariant: evaluating any
  expression function with arbitrary inputs must never raise. Returning an
  error map (`__type__ => "expression/v1error"`) is an acceptable outcome.
  """

  import ExUnit.Assertions

  @doc "Generates any value the expression runtime might encounter."
  def any_value do
    StreamData.one_of([
      StreamData.constant(nil),
      StreamData.boolean(),
      StreamData.integer(),
      StreamData.float(),
      string_value(),
      list_value(),
      map_value(),
      date_value(),
      datetime_value(),
      complex_value(scalar_value())
    ])
  end

  @doc """
  Generates values biased toward enumerables (lists and maps), with occasional
  non-enumerable scalars mixed in. Used to fuzz enum-category functions, whose
  interesting code paths only run on lists/maps — `any_value/0` would mostly hit
  the trivial guard branch, overstating coverage relative to the run count.
  """
  def enumerable_value do
    StreamData.frequency([
      {6, list_value()},
      {3, map_value()},
      {2, any_value()}
    ])
  end

  @doc "Generates strings: printable utf8, including empty and numeric-looking."
  def string_value do
    StreamData.one_of([
      StreamData.string(:printable),
      StreamData.string(:alphanumeric),
      StreamData.constant(""),
      StreamData.map(StreamData.integer(), &to_string/1),
      StreamData.map(StreamData.float(), &to_string/1)
    ])
  end

  @doc "Generates integers and floats."
  def numeric_value do
    StreamData.one_of([StreamData.integer(), StreamData.float()])
  end

  @doc "Generates lists of scalar values, possibly nested one level."
  def list_value do
    StreamData.list_of(
      StreamData.one_of([scalar_value(), StreamData.list_of(scalar_value(), max_length: 3)]),
      max_length: 5
    )
  end

  @doc "Generates string-keyed maps of scalar values."
  def map_value do
    StreamData.map_of(StreamData.string(:alphanumeric, min_length: 1), scalar_value(),
      max_length: 4
    )
  end

  @doc "Generates Date values."
  def date_value do
    StreamData.map(
      StreamData.integer(0..3_000),
      &Date.add(~D[2020-01-01], &1 - 1500)
    )
  end

  @doc "Generates DateTime values."
  def datetime_value do
    StreamData.map(
      StreamData.integer(-50_000_000..50_000_000),
      &DateTime.add(~U[2020-01-01 00:00:00Z], &1, :second)
    )
  end

  @doc "Wraps a generator's values in a complex map with a `__value__` key."
  def complex_value(inner_generator) do
    StreamData.map(inner_generator, &%{"__value__" => &1, "label" => "fuzz"})
  end

  defp scalar_value do
    StreamData.one_of([
      StreamData.constant(nil),
      StreamData.boolean(),
      StreamData.integer(),
      StreamData.float(),
      StreamData.string(:printable)
    ])
  end

  @doc """
  Asserts that evaluating `expression` with `context` does not raise.

  Any return value — including error maps — passes. Only a raised exception
  fails the assertion.
  """
  def assert_no_crash(expression, context \\ %{}) do
    Expression.evaluate_block!(expression, context)
  rescue
    exception ->
      flunk("""
      Expression crashed instead of returning a value or an error map.

      Expression: #{inspect(expression)}
      Context: #{inspect(context)}
      Raised: #{Exception.format(:error, exception, __STACKTRACE__)}
      """)
  catch
    kind, reason ->
      flunk("""
      Expression #{kind} instead of returning a value or an error map.

      Expression: #{inspect(expression)}
      Context: #{inspect(context)}
      Caught: #{Exception.format(kind, reason, __STACKTRACE__)}
      """)
  end
end
