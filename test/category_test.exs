defmodule CategoryTest do
  use ExUnit.Case

  alias Expression.Callbacks.Standard

  test "expression_docs includes categories" do
    docs = Standard.expression_docs()

    # Check that we have docs
    assert length(docs) > 0

    # Check the structure of the first doc
    [first | _] = docs
    assert tuple_size(first) == 6, "Expected 6-element tuple, got #{tuple_size(first)}"

    # Check specific functions have correct categories
    count_doc = Enum.find(docs, fn doc -> elem(doc, 0) == "count" end)
    assert count_doc != nil
    assert elem(count_doc, 2) == "enum"

    abs_doc = Enum.find(docs, fn doc -> elem(doc, 0) == "abs" end)
    assert abs_doc != nil
    assert elem(abs_doc, 2) == "number"

    date_doc = Enum.find(docs, fn doc -> elem(doc, 0) == "date" end)
    assert date_doc != nil
    assert elem(date_doc, 2) == "date"

    # Check category distribution
    categories = Enum.frequencies_by(docs, &elem(&1, 2))

    # Verify we have all expected categories
    assert Map.has_key?(categories, "string")
    assert Map.has_key?(categories, "number")
    assert Map.has_key?(categories, "date")
    assert Map.has_key?(categories, "enum")
    assert Map.has_key?(categories, "logical")
  end
end
