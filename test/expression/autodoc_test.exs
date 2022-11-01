defmodule Expression.AutodocTest do
  use ExUnit.Case, async: true
  alias Expression.Callbacks.Standard

  defp find_docs(module, name) do
    Enum.filter(module.expression_docs(), &(elem(&1, 0) == name))
  end

  test "expression docs" do
    assert [{"date", :direct, args, docstring, expression_docs}] = find_docs(Standard, "date")

    assert docstring =~ "Defines a new date value"

    assert ["year", "month", "day"] = args

    assert expression_docs == [
             %{
               doc: "Construct a date from year, month, and day integers",
               expression: "date(year, month, day)",
               context: %{"day" => 31, "month" => 1, "year" => 2022},
               result: ~D[2022-01-31]
             }
           ]
  end

  test "regular docstrings" do
    assert [{"has_time", :direct, args, docstring, _expression_docs}] =
             find_docs(Standard, "has_time")

    assert docstring =~ "Tests whether `expression` contains a time."

    assert ["expression"] = args
  end

  test "vargs" do
    assert [{"or", :vargs, args, docstring, expression_docs}] = find_docs(Standard, "or")

    assert docstring =~ "Returns `true` if any argument is `true`"

    assert ["arguments"] = args

    assert expression_docs
  end

  test "replace _ctx" do
    assert [{"now", :direct, [], docstring, expression_docs}] = find_docs(Standard, "now")

    assert docstring =~ "Returns the current date time as UTC"

    assert expression_docs
  end

  test "private functions excluded" do
    assert [] = find_docs(Standard, "extract_dateish")
  end
end
