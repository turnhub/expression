defmodule Expression.AutodocTest do
  use ExUnit.Case, async: true
  alias Expression.Callbacks.Standard

  defp find_docs(module, name) do
    Enum.filter(module.expression_docs(), &(elem(&1, 0) == name))
  end

  test "expression docs" do
    assert [{"date", :direct, category, args, docstring, expression_docs}] =
             find_docs(Standard, "date")

    assert category == "date"

    assert docstring =~ "Defines a new date value"

    assert ["year", "month", "day"] = args

    assert expression_docs == [
             %{
               context: %{},
               doc: "Invalid date inputs",
               result: %{
                 "__type__" => "expression/v1error",
                 "error" => true,
                 "message" => "Invalid date: date(nil, nil, nil)",
                 "__value__" => nil
               },
               expression: "date(nil, nil, nil)"
             },
             %{
               doc: "Construct a date from year, month, and day integers",
               expression: "date(year, month, day)",
               context: %{"day" => 31, "month" => 1, "year" => 2022},
               result: ~D[2022-01-31]
             }
           ]
  end

  test "regular docstrings" do
    assert [{"has_time", :direct, category, args, docstring, _expression_docs}] =
             find_docs(Standard, "has_time")

    assert category == "string"

    assert docstring =~ "Tests whether `expression` contains a time."

    assert ["expression"] = args
  end

  test "vargs" do
    assert [{"or", :vargs, category, args, docstring, expression_docs}] =
             find_docs(Standard, "or")

    assert category == "logical"

    assert docstring =~ "Returns `true` if any argument is `true`"

    assert ["arguments"] = args

    assert expression_docs
  end

  test "replace _ctx" do
    assert [{"now", :direct, category, [], docstring, expression_docs}] =
             find_docs(Standard, "now")

    assert category == "date"

    assert docstring =~ "Returns the current date time as UTC"

    assert expression_docs
  end

  test "private functions excluded" do
    assert [] = find_docs(Standard, "search_words")
  end

  test "function categories are correctly assigned" do
    # Test various categories
    assert [{"abs", :direct, "number", _, _, _}] = find_docs(Standard, "abs")
    # Find the single-argument round function
    round_docs = find_docs(Standard, "round")

    assert Enum.any?(round_docs, fn {name, type, cat, args, _, _} ->
             name == "round" && type == :direct && cat == "number" && length(args) == 1
           end)

    assert [{"max", :vargs, "number", _, _, _}] = find_docs(Standard, "max")

    assert [{"upper", :direct, "string", _, _, _}] = find_docs(Standard, "upper")
    assert [{"lower", :direct, "string", _, _, _}] = find_docs(Standard, "lower")
    # Split has multiple arities, check both have string category
    split_docs = find_docs(Standard, "split")
    assert Enum.all?(split_docs, fn {_, _, cat, _, _, _} -> cat == "string" end)

    assert [{"append", :direct, "enum", _, _, _}] = find_docs(Standard, "append")
    assert [{"count", :direct, "enum", _, _, _}] = find_docs(Standard, "count")
    assert [{"filter", :direct, "enum", _, _, _}] = find_docs(Standard, "filter")

    assert [{"and", :vargs, "logical", _, _, _}] = find_docs(Standard, "and")
    assert [{"if", :reserved, "logical", _, _, _}] = find_docs(Standard, "if")
    assert [{"not", :reserved, "logical", _, _, _}] = find_docs(Standard, "not")

    assert [{"today", :direct, "date", _, _, _}] = find_docs(Standard, "today")
    assert [{"year", :direct, "date", _, _, _}] = find_docs(Standard, "year")
    assert [{"month", :direct, "date", _, _, _}] = find_docs(Standard, "month")
  end
end
