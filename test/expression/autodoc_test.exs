defmodule Expression.AutodocTest do
  use ExUnit.Case, async: true
  alias Expression.Callbacks.Standard

  test "docs_for" do
    all_expression_docs = Standard.expression_docs()

    assert [{"date", args, docstring, expression_docs}] =
             Enum.filter(all_expression_docs, &(elem(&1, 0) == "date"))

    assert docstring =~ "Defines a new date value"

    assert ["year", "month", "day"] = args

    assert expression_docs == [
             %{
               doc: "Construct a date from year, month, and day integers",
               expression: "@date(year, month, day)",
               context: %{"day" => 31, "month" => 1, "year" => 2022},
               result: "2022-01-31T00:00:00Z"
             }
           ]
  end
end
