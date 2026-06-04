defmodule Expression.Callbacks.Standard do
  @moduledoc """
  The function callbacks for the standard function set available
  in FLOIP expressions.

  This should be relatively swappable with another implementation.
  The only requirement is the `handle/3` function.

  FLOIP functions are case insensitive. All functions in this callback
  module are implemented as lowercase names.

  Some functions accept a variable amount of arguments. Elixir doesn't
  support variable arguments in functions.

  If a function accepts a variable number of arguments the convention
  is to call the `<function_name>_vargs/2` callback where the context
  is given as the first argument and the argument list as a second
  argument.

  Reserved names such as `and`, `if`, and `or` are suffixed with an
  underscore.
  """

  import Expression.Callbacks.EvalHelpers

  use Expression.Callbacks
  use Expression.Autodoc

  alias Expression.DateHelpers

  @punctuation_pattern ~r/\s*[,:;!?.-]\s*|\s/

  @doc """
  Return the number of entries in a list, string, or a map.
  """
  @expression_category "enum"
  @expression_doc expression: "count([1, 2, 3])", result: 3
  @expression_doc expression: "count(\"zoë\")", result: 3
  @expression_doc expression: "count(map)", context: %{"map" => %{"foo" => "bar"}}, result: 1
  @expression_doc expression: "count(nil_value)", context: %{"nil_value" => nil}, result: 0
  @expression_doc doc: "Count value in __value__ key if complex value is provided.",
                  expression: "count(enum)",
                  context: %{
                    "enum" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "value for __value__ key"
                    }
                  },
                  result: 23
  def count(ctx, term) do
    case eval!(term, ctx) do
      list when is_list(list) -> length(list)
      binary when is_binary(binary) -> String.length(binary)
      map when is_map(map) -> Enum.count(map)
      nil -> 0
    end
  end

  @doc """
  Chunk a list into a list of smaller lists.

  This is useful in cases where one has a large list but want
  to process them in smaller chunks.

  """
  @expression_category "enum"
  @expression_doc doc: """
                  Split a large set of sentences into a smaller set of sentences.
                  """,
                  expression: "chunk_every(sentences, 2)",
                  result: [
                    ["the first sentence", "the second sentence"],
                    ["the third sentence", "the fourth sentence"],
                    ["the fifth sentence"]
                  ],
                  context: %{
                    "sentences" => [
                      "the first sentence",
                      "the second sentence",
                      "the third sentence",
                      "the fourth sentence",
                      "the fifth sentence"
                    ]
                  }
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "chunk_every(nil, 2)",
                  result: Expression.error_map("Invalid enumerable")
  @expression_doc doc: "Split enum in __value__ key if complex value is provided.",
                  expression: "chunk_every(complex, 3)",
                  context: %{
                    "complex" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => [
                        "the first sentence",
                        "the second sentence",
                        "the third sentence",
                        "the fourth sentence",
                        "the fifth sentence"
                      ]
                    }
                  },
                  result: [
                    ["the first sentence", "the second sentence", "the third sentence"],
                    ["the fourth sentence", "the fifth sentence"]
                  ]
  def chunk_every(ctx, enumerable, count) do
    [enumerable, count] = eval_args!([enumerable, count], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      Enum.chunk_every(enumerable, count)
    end
  end

  @doc """
  Defines a new date value
  """
  @expression_category "date"
  @expression_doc doc: "Construct a date from year, month, and day integers",
                  expression: "date(year, month, day)",
                  context: %{
                    "year" => 2022,
                    "month" => 1,
                    "day" => 31
                  },
                  result: ~D[2022-01-31]
  @expression_doc doc: "Invalid date inputs",
                  expression: "date(nil, nil, nil)",
                  context: %{},
                  result: %{
                    "__type__" => "expression/v1error",
                    "error" => true,
                    "message" => "Invalid date: date(nil, nil, nil)",
                    "__value__" => nil
                  }
  @expression_doc doc:
                    "Construct date from value in __value__ key if complex values are provided.",
                  expression: "date(year, month, day)",
                  context: %{
                    "year" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2025
                    },
                    "month" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "day" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 15
                    }
                  },
                  result: ~D[2025-01-15]

  def date(ctx, year, month, day) do
    [year, month, day] = eval_args!([year, month, day], ctx)

    with true <- is_integer(year),
         true <- is_integer(month),
         true <- is_integer(day),
         {:ok, date} <- Date.new(year, month, day) do
      date
    else
      _ ->
        Expression.error_map(
          "Invalid date: date(#{inspect(year)}, #{inspect(month)}, #{inspect(day)})"
        )
    end
  end

  @doc """
  Calculates a new datetime based on the offset and unit provided.

  The unit can be any of the following values:

  * "Y" for years
  * "M" for months
  * "W" for weeks
  * "D" for days
  * "h" for hours
  * "m" for minutes
  * "s" for seconds

  Specifying a negative offset results in date calculations back in time.

  """
  @expression_category "date"
  @expression_doc doc: "Calculates a new datetime based on the offset and unit provided.",
                  expression: "datetime_add(datetime, offset, unit)",
                  context: %{
                    "datetime" => ~U[2022-07-31 00:00:00Z],
                    "offset" => "1",
                    "unit" => "M"
                  },
                  result: ~U[2022-08-31 00:00:00Z]
  @expression_doc doc: "Leap year handling in a leap year.",
                  expression: "datetime_add(date(2020, 02, 28), 1, \"D\")",
                  result: ~U[2020-02-29 00:00:00.000000Z]
  @expression_doc doc: "Leap year handling outside of a leap year.",
                  expression: "datetime_add(date(2021, 02, 28), 1, \"D\")",
                  result: ~U[2021-03-01 00:00:00.000000Z]
  @expression_doc doc: "Negative offsets",
                  expression: "datetime_add(date(2020, 02, 29), -1, \"D\")",
                  result: ~U[2020-02-28 00:00:00.000000Z]
  @expression_doc doc: "Invalid date inputs",
                  expression: "datetime_add(\"_..[0]._\", 0, \"h\")",
                  context: %{},
                  result: %{
                    "__type__" => "expression/v1error",
                    "error" => true,
                    "message" => "Invalid date",
                    "__value__" => nil
                  }
  @expression_doc doc:
                    "Calculates date from value in __value__ key if complex values are provided.",
                  expression: "datetime_add(datetime, offset, unit)",
                  context: %{
                    "datetime" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2022-07-31 00:00:00Z]
                    },
                    "offset" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "1"
                    },
                    "unit" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "M"
                    }
                  },
                  result: ~U[2022-08-31 00:00:00Z]
  def datetime_add(ctx, datetime, offset, unit) do
    datetime = DateHelpers.extract_datetimeish(eval!(datetime, ctx))

    if is_struct(datetime, DateTime) do
      [offset, unit] = eval_args!([offset, unit], ctx)

      case unit do
        "Y" -> Timex.shift(datetime, years: offset)
        "M" -> Timex.shift(datetime, months: offset)
        "W" -> Timex.shift(datetime, weeks: offset)
        "D" -> Timex.shift(datetime, days: offset)
        "h" -> Timex.shift(datetime, hours: offset)
        "m" -> Timex.shift(datetime, minutes: offset)
        "s" -> Timex.shift(datetime, seconds: offset)
      end
    else
      Expression.error_map("Invalid date")
    end
  end

  @doc """
  Parses a UNIX time and returns a DateTime
  """
  @expression_category "date"
  @expression_doc expression: "datetime_from_unix(\"1701903600000\", \"millisecond\")",
                  context: %{},
                  result: DateTime.from_unix!(1_701_903_600_000, :millisecond)
  @expression_doc expression: "datetime_from_unix(1701903600000, \"millisecond\")",
                  context: %{},
                  result: DateTime.from_unix!(1_701_903_600_000, :millisecond)
  @expression_doc expression: "datetime_from_unix(\"1701903600\", \"second\")",
                  context: %{},
                  result: DateTime.from_unix!(1_701_903_600, :second)
  @expression_doc doc: "Parses date from value in __value__ key if complex values are provided.",
                  expression: "datetime_from_unix(unix_time, unit)",
                  context: %{
                    "unix_time" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "1701903600000"
                    },
                    "unit" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "millisecond"
                    }
                  },
                  result: DateTime.from_unix!(1_701_903_600_000, :millisecond)
  @spec datetime_from_unix(map, {:literal, String.t() | integer}, {:literal, unit :: String.t()}) ::
          DateTime.t()
  def datetime_from_unix(ctx, unix, unit) do
    [unix, unit] = eval_args!([unix, unit], ctx)
    parse_unix(unix, unit)
  end

  defp parse_unix(unix, unit) when is_binary(unix) and is_binary(unit),
    do: parse_unix(String.to_integer(unix), unit)

  defp parse_unix(unix, "second"), do: parse_unix(unix, :second)
  defp parse_unix(unix, "millisecond"), do: parse_unix(unix, :millisecond)

  defp parse_unix(unix, unit) when is_integer(unix) and is_atom(unit),
    do: DateTime.from_unix!(unix, unit)

  @expression_category "logical"
  @expression_doc doc:
                    ~s[The SWITCH function evaluates one value (called the expression) against a list of values, and returns the result corresponding to the first matching value. If there is no match, an optional default value (the last one in the list if the list is odd) may be returned],
                  expression: ~s[SWITCH(1, 1, "Sunday", 2, "Monday", 3, "Tuesday", "No match")],
                  result: "Sunday"
  @expression_doc doc:
                    ~s[The SWITCH function evaluates one value (called the expression) against a list of values, and returns the result corresponding to the first matching value. If there is no match, an optional default value (the last one in the list if the list is odd) may be returned],
                  expression: ~s[SWITCH(5, 1, "Sunday", 2, "Monday", 3, "Tuesday", "No match")],
                  result: "No match"

  def switch_vargs(ctx, arguments) do
    [key | options] = eval_args!(arguments, ctx)
    optional = if rem(length(options), 2) == 1, do: List.last(options), else: nil

    options
    |> Enum.chunk_every(2, 2, :discard)
    |> Map.new(fn [a, b] -> {a, b} end)
    |> Map.get(key, optional)
  end

  @expression_category "number"
  @expression_doc doc:
                    "The ROUND function rounds a number to a specified number of digits. For example, if cell A1 contains 23.7825, and you want to round that value to two decimal places you can do ROUND(23.7825, 2)",
                  expression: "ROUND(23.7825, 2)",
                  result: "23.78"
  @expression_doc doc:
                    "The ROUND function rounds a number to a specified number of digits. For example, if cell A1 contains 23.7825, and you want to round that value to zero decimal places you can do ROUND(23.7825)",
                  expression: "ROUND(23.7825)",
                  result: "24"
  @expression_doc doc: "Rounds from value in __value__ key if complex values are provided.",
                  expression: "round(value, digits)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 23.7825
                    },
                    "digits" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    }
                  },
                  result: "23.78"
  @expression_category "number"
  def round(ctx, value) do
    [value] = eval_args!([value], ctx)

    value
    |> Decimal.from_float()
    |> Decimal.round(0)
    |> Decimal.to_string(:normal)
  end

  @expression_category "number"
  def round(ctx, value, places) do
    [value, places] = eval_args!([value, places], ctx)

    value
    |> Decimal.from_float()
    |> Decimal.round(places)
    |> Decimal.to_string(:normal)
  end

  @doc """
  MID extracts part of a string, starting at a specified position and for a specified length.

  It correctly handles Unicode characters. For example, taking the first three characters from "héllo" returns "hél".

  If the starting position is beyond the string length, it returns an empty string.

  Implementation based on https://support.microsoft.com/en-us/office/mid-function-2eba57be-0c05-4bdc-bf81-5ecf4421eb8a
  """
  @expression_category "string"
  @expression_doc doc:
                    "MID returns a specific number of characters from a text string, starting at the position you specify, based on the number of characters you specify.",
                  expression: ~s[MID("Fluid", 1, 5)],
                  result: "Fluid"

  @expression_doc expression: ~s[MID("Fluid Flow", 7, 20)],
                  result: "Flow"

  @expression_doc expression: ~s[MID("Fluid Flow", 20, 5)],
                  result: ""

  @expression_doc doc: "Extract from value in __value__ key if complex values are provided.",
                  expression: "mid(value, 7, 20)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "Fluid Flow"
                    },
                    "start_num" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "num_chars" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 5
                    }
                  },
                  result: "Flow"

  def mid(ctx, text, start_num, num_chars) do
    [text, start_num, num_chars] = eval_args!([text, start_num, num_chars], ctx)
    String.slice(to_string(text), start_num - 1, num_chars)
  end

  @doc """
  Converts date stored in text to an actual date object and
  formats it using `strftime` formatting.

  It will fallback to "%Y-%m-%d %H:%M:%S" if no formatting is supplied

  """
  @expression_category "date"
  @expression_doc doc: "Convert a date from a piece of text to a formatted date string",
                  expression: "datevalue(\"2022-01-01\")",
                  result: %{
                    "__value__" => "2022-01-01 00:00:00",
                    "date" => ~D[2022-01-01],
                    "datetime" => ~U[2022-01-01 00:00:00Z]
                  }
  @expression_doc doc: "Convert a date from a piece of text and read the date field",
                  expression: "datevalue(\"2022-01-01\").date",
                  result: ~D[2022-01-01]
  @expression_doc doc: "Convert a date value and read the date field",
                  expression: "datevalue(date(2022, 1, 1)).date",
                  result: ~D[2022-01-01]
  @expression_doc doc: "Convert from value in __value__ key if complex values are provided.",
                  expression: "datevalue(date).date",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2022-01-01"
                    }
                  },
                  result: ~D[2022-01-01]
  def datevalue(ctx, date, format) do
    [date, format] = eval!([date, format], ctx)

    if datetime = DateHelpers.extract_datetimeish(date) do
      %{
        "__value__" => Timex.format!(datetime, format, :strftime),
        "date" => DateTime.to_date(datetime),
        "datetime" => datetime
      }
    end
  end

  @expression_category "date"
  def datevalue(ctx, date) do
    datetime = DateHelpers.extract_datetimeish(eval!(date, ctx))

    %{
      "__value__" => Timex.format!(datetime, "%Y-%m-%d %H:%M:%S", :strftime),
      "date" => DateTime.to_date(datetime),
      "datetime" => datetime
    }
  end

  @doc """
  Parse random dates and times with `strftime` patterns and return a DateTime value
  when it matches.
  """
  @expression_category "date"
  @expression_doc doc: "Parse a date value using strftime formatting and return a DateTime",
                  expression: "parse_datevalue(\"2016-02-29T22:25:00-00:00\", \"%FT%T%:z\")",
                  result: DateTime.new!(~D[2016-02-29], ~T[22:25:00])
  @expression_doc doc: "Attempt to parse a date value and return nil when failing",
                  expression: "parse_datevalue(\"👻👻👻👻\", \"%FT%T%:z\")",
                  result: nil
  @expression_doc doc: "Parse value in __value__ key if complex values are provided.",
                  expression: "parse_datevalue(datetime, format)",
                  context: %{
                    "datetime" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2016-02-29T22:25:00-00:00"
                    },
                    "format" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "%FT%T%:z"
                    }
                  },
                  result: ~U[2016-02-29 22:25:00Z]
  def parse_datevalue(ctx, datetime, format) do
    [datetime, format] = eval_args!([datetime, format], ctx)

    case Timex.parse(datetime, format, :strftime) do
      {:ok, datetime} ->
        Timex.to_datetime(datetime)

      {:error, _} ->
        nil
    end
  end

  @doc """
  Returns only the day of the month of a date (1 to 31)
  """
  @expression_category "date"
  @expression_doc doc: "Getting today's day of the month",
                  expression: "day(date(2022, 9, 10))",
                  result: 10
  @expression_doc doc: "Getting today's day of the month",
                  expression: "day(now())",
                  fake_result: DateTime.utc_now().day
  @expression_doc doc: "Return day from date in __value__ key if complex values are provided.",
                  expression: "day(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2016-02-29 22:25:00Z]
                    }
                  },
                  result: 29
  def day(ctx, date) do
    %{day: day} = eval!(date, ctx)
    day
  end

  @doc """
  Moves a date by the given number of months
  """
  @expression_category "date"
  @expression_doc doc: "Move the date in a date object by 1 month",
                  expression: "edate(right_now, 1)",
                  context: %{right_now: DateTime.new!(Date.new!(2022, 1, 1), Time.new!(0, 0, 0))},
                  result:
                    Timex.shift(DateTime.new!(Date.new!(2022, 1, 1), Time.new!(0, 0, 0)),
                      months: 1
                    )
  @expression_doc doc: "Move the date store in a piece of text by 1 month",
                  expression: "edate(\"2022-10-10\", 1)",
                  result: ~D[2022-11-10]
  @expression_doc doc:
                    "Move the date from value in __value__ key if complex values are provided.",
                  expression: "edate(date, months)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2022-10-10"
                    },
                    "months" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    }
                  },
                  result: ~D[2022-11-10]
  def edate(ctx, date, months) do
    [date, months] = eval_args!([date, months], ctx)
    DateHelpers.extract_dateish(date) |> Timex.shift(months: months)
  end

  @doc """
  Filters a list by returning a new list that contains only the
  elements for which `filter_fun` is truthy.
  """
  @expression_category "enum"
  @expression_doc expression: "filter([\"A\", \"B\", \"C\", \"B\"], & &1 == \"B\")",
                  result: ["B", "B"]
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "filter(nil, & &1 == \"B\")",
                  result: Expression.error_map("Invalid enumerable")
  @expression_doc doc: "Filter from value in __value__ key if complex values are provided.",
                  expression: "filter(list, & &1 == \"B\")",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C", "B"]
                    }
                  },
                  result: ["B", "B"]
  def filter(ctx, enumerable, filter_fun) do
    [enumerable, filter_fun] = eval_args!([enumerable, filter_fun], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      enumerable
      # Wrap each list item in a list because `filter_fun`
      # expects a list of arguments
      |> Enum.map(&[&1])
      |> Enum.filter(filter_fun)
      # Unwrap each list item
      |> Enum.map(fn [item] -> item end)
    end
  end

  @doc """
  Finds the first element in the list for which `filter_fun` is truthy.
  """
  @expression_category "enum"
  @expression_doc expression:
                    "find([[\"Hello\", \"World\"], [\"Hi\", \"World\"]], & &1[0] == \"Hi\")",
                  result: ["Hi", "World"]
  @expression_doc doc: "Find from value in __value__ key if complex values are provided.",
                  expression: "find(list, & &1[0] == \"Hi\")",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => [["Hello", "World"], ["Hi", "World"]]
                    }
                  },
                  result: ["Hi", "World"]
  def find(ctx, enumerable, find_fun) do
    [enumerable, find_fun] = eval_args!([enumerable, find_fun], ctx)

    enumerable
    # Wrap each list item in a list because `find_fun`
    # expects a list of arguments
    |> Enum.map(&[&1])
    |> Enum.find(find_fun)
    # Unwrap element found
    |> then(fn
      nil -> nil
      [element] -> element
    end)
  end

  @doc """
  Returns only the hour of a datetime (0 to 23)
  """
  @expression_category "date"
  @expression_doc doc: "Get the current hour",
                  expression: "hour(now())",
                  fake_result: DateTime.utc_now().hour
  @expression_doc doc: "Get the hour from value in __value__ key if complex values are provided.",
                  expression: "hour(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2022-07-31 03:00:00Z]
                    }
                  },
                  result: 3
  def hour(ctx, date) do
    %{hour: hour} = eval!(date, ctx)
    hour
  end

  @doc """
  Returns only the minute of a datetime (0 to 59)
  """
  @expression_category "date"
  @expression_doc doc: "Get the current minute",
                  expression: "minute(now())",
                  fake_result: DateTime.utc_now().minute
  @expression_doc doc:
                    "Get the minute from value in __value__ key if complex values are provided.",
                  expression: "minute(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2022-07-31 03:23:00Z]
                    }
                  },
                  result: 23
  def minute(ctx, date) do
    %{minute: minute} = DateHelpers.extract_datetimeish(eval!(date, ctx))
    minute
  end

  @doc """
  Returns only the month of a date (1 to 12)
  """
  @expression_category "date"
  @expression_doc doc: "Get the current month",
                  expression: "month(now())",
                  fake_result: DateTime.utc_now().month
  @expression_doc doc:
                    "Get the month from value in __value__ key if complex values are provided.",
                  expression: "month(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2022-07-31 03:23:00Z]
                    }
                  },
                  result: 7
  def month(ctx, date) do
    %{month: month} = eval!(date, ctx)
    month
  end

  @doc """
  Returns the current date time as UTC

  ```
  It is currently @NOW()
  ```
  """
  @expression_category "date"
  @expression_doc doc: "return the current timestamp as a DateTime value",
                  expression: "now()",
                  fake_result: DateTime.utc_now()
  @expression_doc doc: "return the current datetime and format it using `datevalue`",
                  expression: "datevalue(now(), \"%Y-%m-%d\")",
                  fake_result: %{
                    "__value__" => DateTime.utc_now() |> Timex.format!("%Y-%m-%d", :strftime),
                    "date" => DateTime.utc_now()
                  }
  def now(_ctx) do
    DateTime.utc_now()
  end

  @doc """
  Returns only the second of a datetime (0 to 59)
  """
  @expression_category "date"
  @expression_doc expression: "second(now)",
                  context: %{"now" => DateTime.utc_now()},
                  fake_result: DateTime.utc_now().second
  @expression_doc doc:
                    "Get the second from value in __value__ key if complex values are provided.",
                  expression: "second(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~U[2022-07-31 03:23:15Z]
                    }
                  },
                  result: 15
  def second(ctx, date) do
    %{second: second} = eval!(date, ctx)
    second
  end

  @doc """
  Defines a time value which can be used for time arithmetic
  """
  @expression_category "date"
  @expression_doc expression: "time(12, 13, 14)",
                  result: %Time{hour: 12, minute: 13, second: 14}
  @expression_doc doc:
                    "Create a time from value in __value__ key if complex values are provided.",
                  expression: "time(hour, minute, second)",
                  context: %{
                    "hour" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 12
                    },
                    "minute" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 13
                    },
                    "second" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 14
                    }
                  },
                  result: ~T[12:13:14]
  def time(ctx, hours, minutes, seconds) do
    [hours, minutes, seconds] = eval_args!([hours, minutes, seconds], ctx)
    %Time{hour: hours, minute: minutes, second: seconds}
  end

  @doc """
  Converts time stored in text to an actual time
  """
  @expression_category "date"
  @expression_doc expression: "timevalue(\"2:30\")",
                  result: %Time{hour: 2, minute: 30, second: 0}
  @expression_doc expression: "timevalue(\"2:30:55\")",
                  result: %Time{hour: 2, minute: 30, second: 55}
  @expression_doc doc:
                    "Create a time from value in __value__ key if complex values are provided.",
                  expression: "timevalue(time)",
                  context: %{
                    "time" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2:30"
                    }
                  },
                  result: ~T[02:30:00]
  def timevalue(ctx, expression) do
    expression = eval!(expression, ctx)

    parts =
      expression
      |> String.split(":")
      |> Enum.map(&String.to_integer/1)

    defaults = [
      hour: 0,
      minute: 0,
      second: 0
    ]

    fields =
      [:hour, :minute, :second]
      |> Enum.zip(parts)

    struct(Time, Keyword.merge(defaults, fields))
  end

  @doc """
  Returns the current date
  """
  @expression_category "date"
  @expression_doc expression: "today()",
                  fake_result: Date.utc_today()
  def today(_ctx) do
    Date.utc_today()
  end

  @doc """
  Returns the day of the week of a date (1 for Sunday to 7 for Saturday)
  """
  @expression_category "date"
  @expression_doc expression: "weekday(today)",
                  context: %{"today" => ~D[2022-11-06]},
                  result: 1
  @expression_doc expression: "weekday(today)",
                  context: %{"today" => ~D[2022-11-01]},
                  result: 3
  @expression_doc doc:
                    "Return day of week from value in __value__ key if complex values are provided.",
                  expression: "weekday(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~D[2022-11-06]
                    }
                  },
                  result: 1
  def weekday(ctx, date) do
    iso_week_day = Timex.weekday(eval!(date, ctx))

    if iso_week_day == 7 do
      1
    else
      iso_week_day + 1
    end
  end

  @doc """
  Returns only the year of a date
  """
  @expression_category "date"
  @expression_doc expression: "year(now)",
                  context: %{"now" => DateTime.utc_now()},
                  fake_result: DateTime.utc_now().year
  @expression_doc doc: "Return year from value in __value__ key if complex values are provided.",
                  expression: "year(date)",
                  context: %{
                    "date" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ~D[2022-11-06]
                    }
                  },
                  result: 2022
  def year(ctx, date) do
    %{year: year} = DateHelpers.extract_dateish(eval!(date, ctx))
    year
  end

  @doc """
  Returns `true` if and only if all its arguments evaluate to `true`
  """
  @expression_category "logical"
  @expression_doc expression: "and(contact.gender = \"F\", contact.age >= 18)",
                  code_expression: "contact.gender = \"F\" and contact.age >= 18",
                  context: %{
                    "contact" => %{
                      "gender" => "F",
                      "age" => 32
                    }
                  },
                  result: true
  @expression_doc expression: "and(contact.gender = \"F\", contact.age >= 18)",
                  code_expression: "contact.gender = \"F\" and contact.age >= 18",
                  context: %{
                    "contact" => %{
                      "gender" => "?",
                      "age" => 32
                    }
                  },
                  result: false
  @expression_doc doc:
                    "Return true if value in __value__ key if complex values are provided evaluates to true.",
                  expression: "and(gender = \"F\", age >= 18)",
                  code_expression: "gender = \"F\" and age >= 18",
                  context: %{
                    "gender" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "F"
                    },
                    "age" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 18
                    }
                  },
                  result: true
  def and_vargs(ctx, arguments) do
    arguments = eval_args!(arguments, ctx)
    Enum.all?(arguments, & &1)
  end

  @doc """
  Returns `false` if the argument supplied evaluates to truth-y
  """
  @expression_category "logical"
  @expression_doc expression: "not(false)", result: true
  @expression_doc doc:
                    "Return false if value in __value__ key if complex values are provided evaluates to truth-y.",
                  expression: "not(boolean)",
                  context: %{
                    "boolean" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => false
                    }
                  },
                  result: true
  def not_(ctx, argument) do
    !eval!(argument, ctx)
  end

  @doc """
  Returns one value if the condition evaluates to `true`, and another value if it evaluates to `false`
  """
  @expression_category "logical"
  @expression_doc expression: "if(true, \"Yes\", \"No\")",
                  code_expression: """
                  if true do
                    "Yes"
                  else
                    "No"
                  end
                  """,
                  result: "Yes"
  @expression_doc expression: "if(false, \"Yes\", \"No\")",
                  code_expression: "# Shorthand\nif(false, do: \"Yes\", else: \"No\")",
                  result: "No"
  @expression_doc expression: "if(boolean, value1, value2)",
                  context: %{
                    "boolean" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => false
                    },
                    "value1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "Yes"
                    },
                    "value2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "No"
                    }
                  },
                  result: "No"
  def if_(ctx, condition, yes, no) do
    result =
      case eval!(condition, ctx) do
        # Handle complex values
        %{"__value__" => value} -> value
        other -> other
      end

    if result, do: eval!(yes, ctx), else: eval!(no, ctx)
  end

  @doc """
  Returns true if the argument is nil or an empty string
  """
  @expression_category "logical"
  @expression_doc doc: "Check whether the given argument is nil or an empty string",
                  expression: ~S|is_nil_or_empty(nil)|,
                  result: true
  @expression_doc doc:
                    "Return true if value in __value__ key if complex values are provided is nil or an empty string.",
                  expression: "is_nil_or_empty(argument)",
                  context: %{
                    "argument" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ""
                    }
                  },
                  result: true
  # Skipping the Credo check since this is a Stacks DSL Expression, not an
  # Elixir function in Turn
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_nil_or_empty(ctx, arg) do
    [arg] = eval_args!([arg], ctx)
    arg == nil or arg == ""
  end

  @doc """
  Returns `true` if any argument is `true`.
  Returns the first truthy value found or otherwise false.

  Accepts any amount of arguments for testing truthiness.
  """
  @expression_category "logical"
  @expression_doc doc: "Return true if any of the values are true",
                  expression: "or(true, false)",
                  code_expression: "true or false",
                  result: true
  @expression_doc doc: "Return the first value that is truthy",
                  expression: "or(false, \"foo\")",
                  code_expression: "false or \"foo\"",
                  result: "foo"
  @expression_doc expression: "or(true, true)",
                  code_expression: "true or true",
                  result: true
  @expression_doc expression: "or(false, false)",
                  code_expression: "false or false",
                  result: false
  @expression_doc expression: "or(a, b)",
                  context: %{"a" => false, "b" => "bee"},
                  code_expression: "a or b",
                  result: "bee"
  @expression_doc expression: "or(a, b)",
                  context: %{"a" => "a", "b" => false},
                  code_expression: "a or b",
                  result: "a"
  @expression_doc expression: "or(b, b)",
                  context: %{},
                  code_expression: "b or b",
                  result: false
  @expression_doc expression: "or(a, b)",
                  context: %{
                    "a" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => false
                    },
                    "b" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "b"
                    }
                  },
                  result: "b"
  def or_vargs(ctx, arguments) do
    Enum.reduce_while(arguments, false, fn arg, acc ->
      arg = eval!(arg, ctx)
      if(arg, do: {:halt, arg}, else: {:cont, acc})
    end)
  end

  @doc """
  Returns the absolute value of a number
  """
  @expression_category "number"
  @expression_doc expression: "abs(-1)", result: 1
  @expression_doc expression: "abs(-0.5)", result: 0.5
  @expression_doc expression: "abs(number)",
                  context: %{
                    "number" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => -0.5
                    }
                  },
                  result: 0.5
  def abs(ctx, number) do
    abs(eval!(number, ctx))
  end

  @doc """
  Returns the maximum value of all arguments
  """
  @expression_category "number"
  @expression_doc expression: "max(1, 2, 3)",
                  result: 3
  @expression_doc expression: "max(value1, value2, value3)",
                  context: %{
                    "value1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "value2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4
                    },
                    "value3" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    }
                  },
                  result: 4
  def max_vargs(ctx, arguments) do
    Enum.max(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the minimum value of all arguments
  """
  @expression_category "number"
  @expression_doc expression: "min(1, 2, 3)",
                  result: 1
  @expression_doc expression: "min(value1, value2, value3)",
                  context: %{
                    "value1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "value2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4
                    },
                    "value3" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    }
                  },
                  result: 1
  def min_vargs(ctx, arguments) do
    Enum.min(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the result of a number raised to a power - equivalent to the ^ operator
  """
  @expression_category "number"
  @expression_doc expression: "power(2, 3)",
                  fake_result: 8.0
  @expression_doc expression: "power(number, power)",
                  context: %{
                    "number" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    },
                    "power" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 3
                    }
                  },
                  result: 8.0
  def power(ctx, a, b) do
    [a, b] = eval_args!([a, b], ctx)
    :math.pow(a, b)
  end

  @doc """
  Split a string into an array using the pattern as separator.
  Defaults to split the string using a space.
  """
  @expression_category "string"
  @expression_doc expression: "split(\"testing something\")", result: ["testing", "something"]
  @expression_doc expression: "split(\"testing something\", \"e\")",
                  result: ["t", "sting som", "thing"]
  @expression_doc doc: "Split from value in __value__ key if complex values are provided.",
                  expression: "split(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "testing something"
                    }
                  },
                  result: ["testing", "something"]
  @expression_doc doc: "Split from value in __value__ key if complex values are provided.",
                  expression: "split(string, pattern)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "testing something"
                    },
                    "pattern" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "e"
                    }
                  },
                  result: ["t", "sting som", "thing"]
  def split(ctx, binary),
    do: String.split(eval!(binary, ctx), " ")

  @expression_category "string"
  def split(ctx, binary, pattern),
    do: String.split(eval!(binary, ctx), eval!(pattern, ctx))

  @doc """
  Returns the sum of all arguments, equivalent to the + operator

  ```
  You have @SUM(contact.reports, contact.forms) reports and forms
  ```
  """
  @expression_category "number"
  @expression_doc expression: "sum(1, 2, 3)",
                  result: 6
  @expression_doc doc: "Sum from value in __value__ key if complex values are provided.",
                  expression: "sum(val1, val2, val3)",
                  context: %{
                    "val1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "val2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    },
                    "val3" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 3
                    }
                  },
                  result: 6
  def sum_vargs(ctx, arguments) do
    Enum.sum(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the character specified by a number

  ```
  > "As easy as @char(65), @char(66), @char(67)"
  "As easy as A, B, C"
  ```
  """
  @expression_category "string"
  @expression_doc expression: "char(65)",
                  result: "A"
  @expression_doc doc:
                    "Return character from value in __value__ key if complex values are provided.",
                  expression: "char(code)",
                  context: %{
                    "code" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 65
                    }
                  },
                  result: "A"
  def char(ctx, code) do
    code = eval!(code, ctx)
    <<code>>
  end

  @doc """
  Removes all non-printable characters from a text string
  """
  @expression_category "string"
  @expression_doc expression: "clean(value)",
                  context: %{"value" => <<65, 0, 66, 0, 67>>},
                  result: "ABC"
  @expression_doc expression: "clean(nil)",
                  result: ""
  @expression_doc doc:
                    "Return cleaned string from value in __value__ key if complex values are provided.",
                  expression: "clean(value)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => <<65, 0, 66, 0, 67>>
                    }
                  },
                  result: "ABC"
  def clean(ctx, binary) do
    binary
    |> eval!(ctx)
    |> to_string()
    |> String.graphemes()
    |> Enum.filter(&String.printable?/1)
    |> Enum.join("")
  end

  @doc """
  Returns a numeric code for the first character in a text string

  ```
  > "The numeric code of A is @CODE(\\"A\\")"
  "The numeric code of A is 65"
  ```
  """
  @expression_category "string"
  @expression_doc expression: "code(\"A\")",
                  result: 65
  @expression_doc expression: "code(nil)",
                  result: nil
  @expression_doc doc: "Return code from value in __value__ key if complex values are provided.",
                  expression: "code(value)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "A"
                    }
                  },
                  result: 65
  def code(ctx, code_ast) do
    code = eval!(code_ast, ctx)

    if code do
      <<code>> = code
      code
    end
  end

  @doc """
  Joins text strings into one text string

  ```
  > "Your name is @CONCATENATE(contact.first_name, \\" \\", contact.last_name)"
  "Your name is name surname"
  ```
  """
  @expression_category "string"
  @expression_doc expression: "concatenate(contact.first_name, \" \", contact.last_name)",
                  context: %{
                    "contact" => %{
                      "first_name" => "name",
                      "last_name" => "surname"
                    }
                  },
                  result: "name surname"
  @expression_doc doc:
                    "Return concatenated string from value in __value__ key if complex values are provided.",
                  expression: "concatenate(first_name, separator, last_name)",
                  context: %{
                    "first_name" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "name"
                    },
                    "separator" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => " "
                    },
                    "last_name" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "surname"
                    }
                  },
                  result: "name surname"
  def concatenate_vargs(ctx, arguments) do
    arguments
    |> eval_args!(ctx)
    |> Enum.map_join("", &Expression.Eval.default_value/1)
  end

  @doc """
  Formats the given number in decimal format using a period and commas

  ```
  > You have @fixed(contact.balance, 2) in your account
  "You have 4.21 in your account"
  ```
  """
  @expression_category "number"
  @expression_doc expression: "fixed(4.209922, 2, false)", result: "4.21"
  @expression_doc expression: "fixed(4000.424242, 4, true)", result: "4000.4242"
  @expression_doc expression: "fixed(3.7979, 2, false)", result: "3.80"
  @expression_doc expression: "fixed(3.7979, 2)", result: "3.80"
  @expression_doc expression: "fixed(0.0909, 2)", result: "0.09"
  @expression_doc doc: "Format from value in __value__ key if complex values are provided.",
                  expression: "fixed(number, precision, no_commas)",
                  context: %{
                    "number" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4.209922
                    },
                    "precision" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    },
                    "no_commas" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => false
                    }
                  },
                  result: "4.21"
  def fixed(ctx, number, precision) do
    [number, precision] = eval_args!([number, precision], ctx)
    Number.Delimit.number_to_delimited(coerce_to_number!(number), precision: precision)
  end

  @expression_category "number"
  def fixed(ctx, number, precision, no_commas) do
    case eval_args!([number, precision, no_commas], ctx) do
      [number, precision, true] ->
        Number.Delimit.number_to_delimited(coerce_to_number!(number),
          precision: precision,
          delimiter: "",
          separator: "."
        )

      [number, precision, false] ->
        Number.Delimit.number_to_delimited(coerce_to_number!(number), precision: precision)
    end
  end

  # `Number.Delimit.number_to_delimited/2` raises an uncaught `ArgumentError`
  # when handed a value it cannot convert to a float (for example a `nil` or a
  # non-numeric string that has bubbled up from a failed sub-expression).
  # Coerce numeric strings to numbers and otherwise raise the library's
  # standard "expression is not a number" error, so callers using
  # `Expression.evaluate_block/4` receive a graceful `{:error, _}` tuple instead
  # of a crash.
  defp coerce_to_number!(number) when is_number(number), do: number

  defp coerce_to_number!(value) when is_binary(value) do
    case Expression.Eval.parse_number(value) do
      number when is_number(number) -> number
      _not_a_number -> raise "expression is not a number: `#{inspect(value)}`"
    end
  end

  defp coerce_to_number!(value), do: raise("expression is not a number: `#{inspect(value)}`")

  @doc """
  Returns the first characters in a text string. This is Unicode safe.

  It will return `nil` if the given string is `nil`
  """
  @expression_category "string"
  @expression_doc expression: "left(\"foobar\", 4)",
                  result: "foob"

  @expression_doc expression:
                    "left(\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\", 20)",
                  result: "Умерла Мадлен Олбрай"
  @expression_doc expression: "left(nil, 4)",
                  result: nil
  @expression_doc doc: "Return left from value in __value__ key if complex values are provided.",
                  expression: "left(value, size)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foobar"
                    },
                    "size" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4
                    }
                  },
                  result: "foob"
  def left(ctx, binary, size) do
    [binary, size] = eval_args!([binary, size], ctx)

    if is_binary(binary) do
      String.slice(binary, 0, size)
    end
  end

  @doc """
  Returns the number of characters in a text string,
  returns 0 if the string is null or empty
  """
  @expression_category "string"
  @expression_doc expression: "len(\"foo\")",
                  result: 3
  @expression_doc expression: "len(\"zoë\")",
                  result: 3
  @expression_doc expression: "len(nil)",
                  result: 0
  @expression_doc doc:
                    "Return length from value in __value__ key if complex values are provided.",
                  expression: "len(value)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo"
                    }
                  },
                  result: 3
  def len(ctx, binary) do
    String.length(to_string(eval!(binary, ctx)))
  end

  @doc """
  Converts a text string to lowercase
  """
  @expression_category "string"
  @expression_doc expression: "lower(\"Foo Bar\")",
                  result: "foo bar"
  @expression_doc expression: "lower(nil)",
                  result: nil
  @expression_doc doc:
                    "
                    Return lowercased string from value in __value__ key if complex values are provided.",
                  expression: "lower(value)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "Foo Bar"
                    }
                  },
                  result: "foo bar"
  def lower(ctx, binary) do
    text = eval!(binary, ctx)

    if is_binary(text) do
      String.downcase(text)
    end
  end

  @doc """
  Capitalizes the first letter of every word in a text string
  """
  @expression_category "string"
  @expression_doc expression: "proper(\"foo bar\")",
                  result: "Foo Bar"
  @expression_doc expression: "proper(nil)",
                  result: nil
  @expression_doc doc:
                    "Return first letter of every word capitalized string from value in __value__ key if complex values are provided.",
                  expression: "proper(value)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo bar"
                    }
                  },
                  result: "Foo Bar"
  def proper(ctx, binary) do
    text = eval!(binary, ctx)

    if is_binary(text) do
      text
      |> String.capitalize()
      |> String.split(" ")
      |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  @doc """
  Repeats text a given number of times
  """
  @expression_category "string"
  @expression_doc expression: "rept(\"*\", 10)",
                  result: "**********"
  @expression_doc expression: "rept(nil, 10)",
                  result: nil
  @expression_doc doc:
                    "Return repeated string from value in __value__ key if complex values are provided.",
                  expression: "rept(value, amount)",
                  context: %{
                    "value" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "*"
                    },
                    "amount" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 10
                    }
                  },
                  result: "**********"
  def rept(ctx, value, amount) do
    text = eval!(value, ctx)

    if is_binary(text) do
      [amount] = eval_args!([amount], ctx)
      String.duplicate(text, amount)
    end
  end

  @doc """
  Returns the last characters in a text string.
  This is Unicode safe.
  """
  @expression_category "string"
  @expression_doc expression: "right(\"testing\", 3)",
                  result: "ing"
  @expression_doc expression:
                    "right(\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\", 20)",
                  result: "ту главы Госдепа США"
  @expression_doc expression: "right(nil, 3)",
                  result: nil
  @expression_doc doc: "Return right from value in __value__ key if complex values are provided.",
                  expression: "right(string, size)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "testing"
                    },
                    "size" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 3
                    }
                  },
                  result: "ing"
  def right(ctx, binary, size) do
    text = eval!(binary, ctx)

    if is_binary(text) do
      size = eval!(size, ctx)
      String.slice(text, -size, size)
    end
  end

  @doc """
  Substitutes new_text for old_text in a text string. If instance_num is given, then only that instance will be substituted
  """
  @expression_category "string"
  @expression_doc expression: "substitute(\"I can't\", \"can't\", \"can do\")",
                  result: "I can do"
  @expression_doc expression: "substitute(nil, \"can't\", \"can do\")",
                  result: nil
  @expression_doc doc:
                    "Return substituted string from value in __value__ key if complex values are provided.",
                  expression: "substitute(subject, pattern, replacement)",
                  context: %{
                    "subject" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "I can't"
                    },
                    "pattern" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "can't"
                    },
                    "replacement" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "can do"
                    }
                  },
                  result: "I can do"
  def substitute(ctx, subject, pattern, replacement) do
    text = eval!(subject, ctx)

    if is_binary(text) do
      [pattern, replacement] = eval_args!([pattern, replacement], ctx)
      String.replace(text, pattern, replacement)
    end
  end

  @doc """
  Returns the unicode character specified by a number
  """
  @expression_category "string"
  @expression_doc expression: "unichar(65)", result: "A"
  @expression_doc expression: "unichar(233)", result: "é"
  @expression_doc doc:
                    "Return unicode character from value in __value__ key if complex values are provided.",
                  expression: "unichar(code)",
                  context: %{
                    "code" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "233"
                    }
                  },
                  result: "é"
  def unichar(ctx, code) do
    code = eval!(code, ctx)
    <<code::utf8>>
  end

  @doc """
  Returns a numeric code for the first character in a text string
  """
  @expression_category "string"
  @expression_doc expression: "unicode(\"A\")", result: 65
  @expression_doc expression: "unicode(\"é\")", result: 233
  @expression_doc doc:
                    "Return unicode code from value in __value__ key if complex values are provided.",
                  expression: "unicode(char)",
                  context: %{
                    "char" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "é"
                    }
                  },
                  result: 233
  def unicode(ctx, letter) do
    <<code::utf8>> = eval!(letter, ctx)
    code
  end

  @doc """
  Converts a text string to uppercase
  """
  @expression_category "string"
  @expression_doc expression: "upper(\"foo\")",
                  result: "FOO"
  @expression_doc expression: "upper(nil)",
                  result: nil
  @expression_doc doc:
                    "Return uppercased string from value in __value__ key if complex values are provided.",
                  expression: "upper(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo"
                    }
                  },
                  result: "FOO"
  def upper(ctx, binary) do
    text = eval!(binary, ctx)

    if is_binary(text) do
      String.upcase(text)
    end
  end

  @doc """
  Returns the first word in the given text - equivalent to WORD(text, 1)
  """
  @expression_category "string"
  @expression_doc expression: "first_word(\"foo bar baz\")",
                  result: "foo"
  @expression_doc expression: "first_word(nil)",
                  result: ""
  @expression_doc doc:
                    "Return first word from value in __value__ key if complex values are provided.",
                  expression: "first_word(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo bar baz"
                    }
                  },
                  result: "foo"
  def first_word(ctx, binary) do
    [word | _] = String.split(to_string(eval!(binary, ctx)), " ")
    word
  end

  @doc """
  Formats a number as a percentage
  """
  @expression_category "number"
  @expression_doc expression: "percent(2/10)", result: "20%"
  @expression_doc expression: "percent(0.2)", result: "20%"
  @expression_doc expression: "percent(d)", context: %{"d" => "0.2"}, result: "20%"
  @expression_doc doc:
                    "Return percentage from value in __value__ key if complex values are provided.",
                  expression: "percent(number)",
                  context: %{
                    "number" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2 / 10
                    }
                  },
                  result: "20%"
  def percent(ctx, float) do
    float = eval!(float, ctx)

    with float when is_number(float) <- parse_float(float) do
      Number.Percentage.number_to_percentage(float * 100, precision: 0)
    end
  end

  @doc """
  Formats digits in text for reading in TTS
  """
  @expression_category "string"
  @expression_doc expression: "read_digits(\"+271\")", result: "plus two seven one"
  @expression_doc expression: "read_digits(nil)", result: ""
  @expression_doc doc:
                    "Return read digits from value in __value__ key if complex values are provided.",
                  expression: "read_digits(digits)",
                  context: %{
                    "digits" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "+271"
                    }
                  },
                  result: "plus two seven one"
  def read_digits(ctx, binary) do
    map = %{
      "+" => "plus",
      "0" => "zero",
      "1" => "one",
      "2" => "two",
      "3" => "three",
      "4" => "four",
      "5" => "five",
      "6" => "six",
      "7" => "seven",
      "8" => "eight",
      "9" => "nine"
    }

    binary
    |> eval!(ctx)
    |> to_string()
    |> String.graphemes()
    |> Enum.map(fn grapheme -> Map.get(map, grapheme, nil) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  @doc """
  Removes the first word from the given text. The remaining text will be unchanged
  """
  @expression_category "string"
  @expression_doc expression: "remove_first_word(\"foo bar\")", result: "bar"
  @expression_doc expression: "remove_first_word(\"foo-bar\", \"-\")", result: "bar"
  @expression_doc expression: "remove_first_word(nil)", result: ""
  @expression_doc expression: "remove_first_word(nil, \"-\")", result: ""
  @expression_doc doc:
                    "Return string with first word removed from value in __value__ key if complex values are provided.",
                  expression: "remove_first_word(string, seperator)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo-bar"
                    },
                    "seperator" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "-"
                    }
                  },
                  result: "bar"
  def remove_first_word(ctx, binary) do
    separator = " "

    binary
    |> eval!(ctx)
    |> to_string()
    |> String.split(separator)
    |> tl()
    |> Enum.join(separator)
  end

  @expression_category "string"
  def remove_first_word(ctx, binary, separator) do
    [binary, separator] = eval_args!([binary, separator], ctx)

    binary
    |> to_string()
    |> String.split(separator)
    |> tl()
    |> Enum.join(separator)
  end

  @expression_category "string"
  @expression_doc doc:
                    "Remove the last word from a list of words, using the specified separator ",
                  expression: ~s{remove_last_word("foo-bar", "-")},
                  result: "foo"
  @expression_doc doc:
                    "Remove the last word from a list of words, using spaces as separator between words ",
                  expression: "remove_last_word(\"foo bar\")",
                  result: "foo"
  @expression_doc doc:
                    "Return string with last word removed from value in __value__ key if complex values are provided.",
                  expression: "remove_last_word(string, seperator)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo-bar"
                    },
                    "seperator" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "-"
                    }
                  },
                  result: "foo"
  def remove_last_word(ctx, binary) do
    [binary] = eval_args!([binary], ctx)
    separator = " "

    binary
    |> String.split(separator)
    |> Enum.reverse()
    |> tl()
    |> Enum.reverse()
    |> Enum.join(separator)
  end

  @expression_category "string"
  def remove_last_word(ctx, binary, separator) do
    [binary, separator] = eval_args!([binary, separator], ctx)

    binary
    |> String.split(separator)
    |> Enum.reverse()
    |> tl()
    |> Enum.reverse()
    |> Enum.join(separator)
  end

  @doc """
  Capture values out of a string using a regex.
  Returns the list of captures in a list.
  Returns `nil` if there was nothing to match
  """
  @expression_category "string"
  @expression_doc expression: "regex_capture(\"testing\", \"test(.+)\")", result: ["ing"]
  @expression_doc expression: "regex_capture(\"testing\", \"foo(.+)\")", result: nil
  @expression_doc doc:
                    "Return captures from value in __value__ key if complex values are provided.",
                  expression: "regex_capture(string, pattern)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "testing"
                    },
                    "pattern" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "test(.+)"
                    }
                  },
                  result: ["ing"]
  def regex_capture(ctx, binary, pattern) do
    [binary, pattern] = eval_args!([binary, pattern], ctx)

    if is_binary(binary) do
      regex = Regex.compile!(pattern)

      case Regex.run(regex, binary) do
        nil -> nil
        [_matched_text | captures] -> captures
      end
    end
  end

  @doc """
  Captures named values out of a string using a regex.
  In contrast to `regex_capture()` this returns a map
  where the keys are the names of the captures and the
  values are the captured values.
  """
  @expression_category "string"
  @expression_doc expression: "regex_named_capture(\"testing\", \"test(?P<match>.+)\")",
                  result: %{"match" => "ing"}
  @expression_doc expression: "regex_named_capture(\"testing\", \"foo(?P<match>.+)\")",
                  result: %{}
  @expression_doc doc:
                    "Return captures from value in __value__ key if complex values are provided.",
                  expression: "regex_named_capture(string, pattern)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "testing"
                    },
                    "pattern" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "test(?P<match>.+)"
                    }
                  },
                  result: %{"match" => "ing"}
  def regex_named_capture(ctx, binary, pattern) do
    [binary, pattern] = eval_args!([binary, pattern], ctx)

    if is_binary(binary) do
      regex = Regex.compile!(pattern)
      Regex.named_captures(regex, binary) || %{}
    else
      %{}
    end
  end

  @doc """
  Wraps each item of the list in a new list with the item itself and its
  index in the original list.
  """
  @expression_category "enum"
  @expression_doc expression: "with_index([\"A\", \"B\", \"C\"])",
                  result: [["A", 0], ["B", 1], ["C", 2]]
  @expression_doc doc:
                    "Return list with indexes from value in __value__ key if complex values are provided.",
                  expression: "with_index([val1, val2, val3])",
                  context: %{
                    "val1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "A"
                    },
                    "val2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "B"
                    },
                    "val3" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "C"
                    }
                  },
                  result: [["A", 0], ["B", 1], ["C", 2]]
  def with_index(ctx, enumerable) do
    [enumerable] = eval_args!([enumerable], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      []
    else
      enumerable
      |> Enum.with_index()
      |> Enum.map(fn {element, index} -> [element, index] end)
    end
  end

  @doc """
  Extracts the nth word from the given text string. If stop is a negative number,
  then it is treated as count backwards from the end of the text. If by_spaces is
  specified and is `true` then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well
  """
  @expression_category "string"
  @expression_doc expression: "word(\"hello cow-boy\", 2)", result: "cow"
  @expression_doc expression: "word(\"hello cow-boy\", 2, true)", result: "cow-boy"
  @expression_doc expression: "word(\"hello cow-boy\", -1)", result: "boy"
  @expression_doc expression: "word(nil, 1)", result: ""
  @expression_doc doc:
                    "Return nth word from value in __value__ key if complex values are provided.",
                  expression: "word(string, n)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello cow-boy"
                    },
                    "n" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    }
                  },
                  result: "cow"
  def word(ctx, binary, n) do
    [binary, n] = eval_args!([binary, n], ctx)
    parts = String.split(to_string(binary), @punctuation_pattern)

    # This slicing seems off.
    # but we copy it from the standard lib
    [part] =
      if n < 0 do
        Enum.slice(parts, n, 1)
      else
        Enum.slice(parts, n - 1, 1)
      end

    part
  end

  @expression_category "string"
  def word(ctx, binary, n, by_spaces) do
    [binary, n, by_spaces] = eval_args!([binary, n, by_spaces], ctx)
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)
    parts = String.split(to_string(binary), splitter)

    # This slicing seems off.
    [part] =
      if n < 0 do
        Enum.slice(parts, n, 1)
      else
        Enum.slice(parts, n - 1, 1)
      end

    part
  end

  @doc """
  Returns the number of words in the given text string. If by_spaces is specified and is `true` then the function splits the text into words only by spaces. Otherwise the text is split by punctuation characters as well

  ```
  > You entered @word_count("one two three") words
  You entered 3 words
  ```
  """
  @expression_category "string"
  @expression_doc expression: "word_count(\"hello cow-boy\")", result: 3
  @expression_doc expression: "word_count(\"hello cow-boy\", true)", result: 2
  @expression_doc expression: "word_count(nil)", result: 0
  @expression_doc doc:
                    "Return word count from value in __value__ key if complex values are provided.",
                  expression: "word_count(string, by_spaces)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello cow-boy"
                    },
                    "by_spaces" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => true
                    }
                  },
                  result: 2
  def word_count(ctx, binary) do
    text = eval!(binary, ctx)

    if is_nil(text) do
      0
    else
      text
      |> String.split(@punctuation_pattern)
      |> Enum.count()
    end
  end

  @expression_category "string"
  def word_count(ctx, binary, by_spaces) do
    text = eval!(binary, ctx)

    if is_nil(text) do
      0
    else
      [by_spaces] = eval_args!([by_spaces], ctx)
      splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

      text
      |> String.split(splitter)
      |> Enum.count()
    end
  end

  @doc """
  Extracts a substring of the words beginning at start, and up to but not-including stop.
  If stop is omitted then the substring will be all words from start until the end of the text.
  If stop is a negative number, then it is treated as count backwards from the end of the text.
  If by_spaces is specified and is `true` then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well
  """
  @expression_category "string"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 2, 4)",
                  result: "expressions are"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 2)",
                  result: "expressions are fun"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 1, -2)",
                  result: "FLOIP expressions"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", -1)",
                  result: "fun"
  @expression_doc expression: "word_slice(nil, -1)",
                  result: ""
  @expression_doc doc:
                    "Return word slice from value in __value__ key if complex values are provided.",
                  expression: "word_slice(string, start, stop)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "FLOIP expressions are fun"
                    },
                    "start" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    },
                    "stop" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4
                    }
                  },
                  result: "expressions are"
  def word_slice(ctx, binary, start) do
    [binary, start] = eval_args!([binary, start], ctx)

    parts =
      String.split(to_string(binary), " ")

    cond do
      start > 0 ->
        parts
        |> Enum.slice(start - 1, length(parts))
        |> Enum.join(" ")

      start < 0 ->
        parts
        |> Enum.slice(start..length(parts))
        |> Enum.join(" ")
    end
  end

  @expression_category "string"
  def word_slice(ctx, binary, start, stop) do
    [binary, start, stop] = eval_args!([binary, start, stop], ctx)

    cond do
      stop > 0 ->
        binary
        |> to_string()
        |> String.split(@punctuation_pattern)
        |> Enum.slice((start - 1)..(stop - 2)//1)
        |> Enum.join(" ")

      stop < 0 ->
        binary
        |> to_string()
        |> String.split(@punctuation_pattern)
        |> Enum.slice((start - 1)..(stop - 1)//1)
        |> Enum.join(" ")
    end
  end

  @expression_category "string"
  def word_slice(ctx, binary, start, stop, by_spaces) do
    [binary, start, stop, by_spaces] = eval_args!([binary, start, stop, by_spaces], ctx)
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    case stop do
      stop when stop > 0 ->
        binary
        |> to_string()
        |> String.split(splitter)
        |> Enum.slice((start - 1)..(stop - 2))
        |> Enum.join(" ")

      stop when stop < 0 ->
        binary
        |> to_string()
        |> String.split(splitter)
        |> Enum.slice((start - 1)..(stop - 1))
        |> Enum.join(" ")
    end
  end

  @doc """
  Returns `true` if the argument is a number.
  """
  @expression_category "logical"
  @expression_doc expression: "isnumber(1)", result: true
  @expression_doc expression: "isnumber(1.0)", result: true
  @expression_doc expression: "isnumber(\"1.0\")", result: true
  @expression_doc expression: "isnumber(\"a\")", result: false
  @expression_doc doc:
                    "Return boolean indicating if value in __value__ key is a number if complex values are provided.",
                  expression: "isnumber(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "1"
                    }
                  },
                  result: true
  def isnumber(ctx, var) do
    var = eval!(var, ctx)

    case var do
      var when is_float(var) or is_integer(var) ->
        true

      var when is_binary(var) ->
        String.match?(var, ~r/^\d+?.?\d+$/)

      _var ->
        false
    end
  end

  @doc """
  Returns `true` if the argument is a boolean.
  """
  @expression_category "logical"
  @expression_doc expression: "isbool(true)", result: true
  @expression_doc expression: "isbool(false)", result: true
  @expression_doc expression: "isbool(1)", result: false
  @expression_doc expression: "isbool(0)", result: false
  @expression_doc expression: "isbool(\"true\")", result: false
  @expression_doc expression: "isbool(\"false\")", result: false
  @expression_doc doc:
                    "Return boolean indicating if value in __value__ key is a boolean if complex values are provided.",
                  expression: "isbool(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "true"
                    }
                  },
                  result: true
  def isbool(ctx, var) do
    eval!(var, ctx) in [true, false]
  end

  @doc """
  Returns `true` if the argument is a string.
  """
  @expression_category "logical"
  @expression_doc expression: "isstring(\"hello\")", result: true
  @expression_doc expression: "isstring(false)", result: false
  @expression_doc expression: "isstring(1)", result: false
  @expression_doc doc:
                    "Return boolean indicating if value in __value__ key is a string if complex values are provided.",
                  expression: "isstring(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello"
                    }
                  },
                  result: true
  def isstring(ctx, binary), do: is_binary(eval!(binary, ctx))

  defp search_words(haystack, words) do
    patterns =
      words
      |> String.split(" ")
      |> Enum.map(&Regex.escape/1)
      |> Enum.map(&Regex.compile!(&1, "i"))

    results =
      patterns
      |> Enum.map(&Regex.run(&1, to_string(haystack)))
      |> Enum.map(fn
        [match] -> match
        nil -> nil
      end)
      |> Enum.reject(&is_nil/1)

    {patterns, results}
  end

  @doc """
  Return true if a list contains all the provided items
  """
  @expression_category "enum"
  @expression_doc doc: "Check whether the given list contains all the provided items",
                  expression: ~S|has_all_members(["A", "B", "C"], ["C", "B"])|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if a list contains all items from value in __value__ key if complex values are provided.",
                  expression: "has_all_members(list, items)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C"]
                    },
                    "items" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["C", "B"]
                    }
                  },
                  result: true
  def has_all_members(ctx, list, items) do
    [list, items] = eval_args!([list, items], ctx)

    if is_list(list) and is_list(items) do
      Enum.all?(items, &Enum.member?(list, &1))
    else
      false
    end
  end

  @doc """
  Tests whether all the words are contained in text

  The words can be in any order and may appear more than once.
  """
  @expression_category "string"
  @expression_doc expression: "has_all_words(\"the quick brown FOX\", \"the fox\")", result: true
  @expression_doc expression: "has_all_words(\"the quick brown FOX\", \"red fox\")", result: false
  @expression_doc expression: "has_all_words(nil, \"red fox\")", result: false
  @expression_doc doc:
                    "Return boolean whether all the words are contained in text value in __value__ key if complex values are provided.",
                  expression: "has_all_words(haystack, words)",
                  context: %{
                    "haystack" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the quick brown FOX"
                    },
                    "words" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the fox"
                    }
                  },
                  result: true
  def has_all_words(ctx, haystack, words) do
    [haystack, words] = eval_args!([haystack, words], ctx)

    if is_binary(haystack) and is_binary(words) do
      {patterns, results} = search_words(haystack, words)
      # future match result: Enum.join(results, " ")
      Enum.count(patterns) == Enum.count(results)
    else
      false
    end
  end

  @doc """
  Checks if the given text starts with any of the provided prefixes. The function performs a case-insensitive match.
  """
  @expression_category "string"
  @expression_doc expression:
                    ~S|has_any_beginning("HEY HOW ARE YOU?", ["hello", "hey how are you"])|,
                  result: true
  @expression_doc expression: ~S|has_any_beginning("كيف حالك؟", ["كيف حالك", "hey how are you"])|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if text starts with any of the provided prefixes from value in __value__ key if complex values are provided.",
                  expression: "has_any_beginning(text, prefixes)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "HEY HOW ARE YOU?"
                    },
                    "prefixes" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["hello", "hey how are you"]
                    }
                  },
                  result: true
  def has_any_beginning(ctx, text, prefixes) do
    [text, prefixes] = eval_args!([text, prefixes], ctx)
    parsed_text = String.downcase(to_string(text))
    parsed_prefixes = Enum.map(prefixes, &String.downcase(to_string(&1)))

    String.starts_with?(parsed_text, parsed_prefixes)
  end

  @doc """
  Check whether the given text exactly matches any of the provided phrases. The function performs a case-insensitive exact match.
  """
  @expression_category "string"
  @expression_doc expression:
                    ~S|has_any_exact_phrase("HEY HOW ARE YOU?", ["hello", "hey how are you?"])|,
                  result: true
  @expression_doc expression:
                    ~S|has_any_exact_phrase("كيف حالك؟", ["كيف حالك", "hey how are you"])|,
                  result: false
  @expression_doc doc:
                    "Return boolean indicating if text exactly matches any of the provided phrases from value in __value__ key if complex values are provided.",
                  expression: "has_any_exact_phrase(text, phrases)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "HEY HOW ARE YOU?"
                    },
                    "phrases" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["hello", "hey how are you?"]
                    }
                  },
                  result: true
  def has_any_exact_phrase(ctx, text, phrases) do
    [text, phrases] = eval_args!([text, phrases], ctx)

    phrases
    |> Enum.map(&String.downcase(to_string(&1)))
    |> Enum.member?(String.downcase(to_string(text)))
  end

  @doc """
  Return true if a list contains any of the provided items
  """
  @expression_category "enum"
  @expression_doc doc: "Check whether the given list contains any of the provided items",
                  expression: ~S|has_any_member(["A", "B", "C"], ["Z", "C"])|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if a list contains any items from value in __value__ key if complex values are provided.",
                  expression: "has_any_member(list, items)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C"]
                    },
                    "items" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["Z", "C"]
                    }
                  },
                  result: true
  def has_any_member(ctx, list, items) do
    [list, items] = eval_args!([list, items], ctx)

    if is_list(list) and is_list(items) do
      Enum.any?(items, &Enum.member?(list, &1))
    else
      false
    end
  end

  @expression_category "string"
  @expression_doc doc:
                    "Check whether the given text ends with the provided string. The function performs a case-insensitive match.",
                  expression: ~S|has_end("I would like to book a vaccine", "vaccine")|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if text ends with provided string from value in __value__ key if complex values are provided.",
                  expression: "has_end(text, end_text)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "I would like to book a vaccine"
                    },
                    "end_text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "vaccine"
                    }
                  },
                  result: true
  def has_end(ctx, text, end_text) do
    [text, end_text] = eval_args!([text, end_text], ctx)

    String.ends_with?(
      String.downcase(to_string(text)),
      String.downcase(to_string(end_text))
    )
  end

  @expression_category "string"
  @expression_doc doc:
                    "Check whether the given text ends with any of the provided strings. The function performs a case-insensitive match.",
                  expression:
                    ~S|has_any_end("I would like to book a vaccine", ["appointment", "visit", "vaccine"])|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if text ends with any of the provided strings from value in __value__ key if complex values are provided.",
                  expression: "has_any_end(text, end_texts)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "I would like to book a vaccine"
                    },
                    "end_texts" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["appointment", "visit", "vaccine"]
                    }
                  },
                  result: true
  def has_any_end(ctx, text, end_texts) do
    [text, end_texts] = eval_args!([text, end_texts], ctx)

    String.ends_with?(
      String.downcase(to_string(text)),
      Enum.map(end_texts, fn end_text -> String.downcase(to_string(end_text)) end)
    )
  end

  @doc """
  URL encode an expression
  """
  @expression_category "string"
  @expression_doc expression: "url_encode(\"hello world\")",
                  result: URI.encode("hello world")
  @expression_doc doc: "URL encode an integer by first converting it to a string.",
                  expression: "url_encode(42)",
                  result: "42"
  @expression_doc doc: "URL encode a float by first converting it to a string.",
                  expression: "url_encode(3.14)",
                  result: "3.14"
  @expression_doc doc: "URL encode a boolean by first converting it to a string.",
                  expression: "url_encode(true)",
                  result: "true"
  @expression_doc doc: "URL encode nil returns an empty string.",
                  expression: "url_encode(nil)",
                  result: ""
  @expression_doc doc: "URL encode a date by first converting it to a string.",
                  expression: "url_encode(date)",
                  context: %{"date" => ~D[2024-01-15]},
                  result: "2024-01-15"
  @expression_doc doc:
                    "Return URL encoded string from value in __value__ key if complex values are provided.",
                  expression: "url_encode(url)",
                  context: %{
                    "url" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello world"
                    }
                  },
                  result: URI.encode("hello world")
  @expression_doc doc:
                    "URL encode an integer from value in __value__ key if complex values are provided.",
                  expression: "url_encode(number)",
                  context: %{
                    "number" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    }
                  },
                  result: "1"
  def url_encode(ctx, thing) do
    eval!(thing, ctx)
    |> to_string()
    |> URI.encode()
  end

  @doc """
  URL decode an expression
  """
  @expression_category "string"
  @expression_doc expression: "url_decode(\"hello%20world\")",
                  result: "hello world"
  @expression_doc doc:
                    "Return URL decoded string from value in __value__ key if complex values are provided.",
                  expression: "url_decode(url)",
                  context: %{
                    "url" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello%20world"
                    }
                  },
                  result: "hello world"
  def url_decode(ctx, thing) do
    eval!(thing, ctx)
    |> URI.decode()
  end

  @doc """
  Base64 encode an expression
  """
  @expression_category "string"
  @expression_doc expression: "base64_encode(\"hello world\")",
                  result: "aGVsbG8gd29ybGQ="
  @expression_doc doc:
                    "Return Base64 encoded string from value in __value__ key if complex values are provided.",
                  expression: "base64_encode(text)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hello world"
                    }
                  },
                  result: "aGVsbG8gd29ybGQ="
  def base64_encode(ctx, thing) do
    thing = eval!(thing, ctx)
    Base.encode64(thing)
  end

  @doc """
  Base64 decode an expression
  """
  @expression_category "string"
  @expression_doc expression: "base64_decode(\"aGVsbG8gd29ybGQ=\")",
                  result: "hello world"
  @expression_doc doc:
                    "Return Base64 decoded string from value in __value__ key if complex values are provided.",
                  expression: "base64_decode(text)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "aGVsbG8gd29ybGQ="
                    }
                  },
                  result: "hello world"
  def base64_decode(ctx, thing) do
    thing = eval!(thing, ctx)

    case Base.decode64(thing) do
      {:ok, decoded_thing} -> decoded_thing
      :error -> Expression.error_map("Unable to decode")
    end
  end

  @doc """
  Rejects elements from a list by returning a new list that contains only the
  elements for which `reject_fun` is truthy.
  """
  @expression_category "enum"
  @expression_doc expression: "reject([\"A\", \"B\", \"C\", \"B\"], & &1 == \"B\")",
                  result: ["A", "C"]
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "reject(nil, & &1 == \"B\")",
                  result: Expression.error_map("Invalid enumerable")
  @expression_doc doc:
                    "Return list with rejected items from value in __value__ key if complex values are provided.",
                  expression: "reject(list, & &1 == \"B\")",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C", "B"]
                    }
                  },
                  result: ["A", "C"]
  def reject(ctx, enumerable, reject_fun) do
    [enumerable, reject_fun] = eval_args!([enumerable, reject_fun], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      enumerable
      # Wrap each list item in a list because `reject_fun`
      # expects a list of arguments
      |> Enum.map(&[&1])
      |> Enum.reject(reject_fun)
      # Unwrap each list item
      |> Enum.map(fn [item] -> item end)
    end
  end

  @doc """
  Removes duplicate values from a list.
  """
  @expression_category "enum"
  @expression_doc expression: "uniq([\"A\", \"B\", \"C\", \"B\"])", result: ["A", "B", "C"]
  @expression_doc doc:
                    "Return list with unique items from value in __value__ key if complex values are provided.",
                  expression: "uniq(list)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C", "B"]
                    }
                  },
                  result: ["A", "B", "C"]
  def uniq(ctx, enumerable) do
    [enumerable] = eval_args!([enumerable], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      []
    else
      Enum.uniq(enumerable)
    end
  end

  @doc """
  Sorts a list of values using the result of the sorter function
  """
  @expression_category "enum"
  @expression_doc expression: "sort_by([\"a\", \"b\", \"c\"], &rand_between(1, 5))",
                  fake_result: ["b", "c", "a"]
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "sort_by(nil, &rand_between(1, 5))",
                  result: Expression.error_map("Invalid enumerable")
  @expression_doc doc:
                    "Return list with unique items from value in __value__ key if complex values are provided.",
                  expression: "sort_by(list, & &1 < &2)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["a", "c", "b"]
                    }
                  },
                  result: ["a", "c", "b"]
  def sort_by(ctx, enumerable, sorter_fun) do
    [enumerable, sorter_fun] = eval_args!([enumerable, sorter_fun], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      enumerable
      |> Enum.map(&[&1])
      |> Enum.sort_by(sorter_fun)
      # Unwrap each list item
      |> Enum.map(fn [item] -> item end)
    end
  end

  @doc """
  Tests whether any of the words are contained in the text

  Only one of the words needs to match and it may appear more than once.
  """
  @expression_category "string"
  @expression_doc expression: "has_any_word(\"The Quick Brown Fox\", \"fox quick\")",
                  result: %{"__value__" => true, "match" => "Quick Fox"}
  @expression_doc expression: "has_any_word(\"The Quick Brown Fox\", \"yellow\")",
                  result: %{"__value__" => false, "match" => nil}
  @expression_doc doc:
                    "Tests whether any of the words are contained in text value in __value__ key if complex values are provided.",
                  expression: "has_any_word(haystack, words)",
                  context: %{
                    "haystack" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "The Quick Brown Fox"
                    },
                    "words" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "fox quick"
                    }
                  },
                  result: %{"__value__" => true, "match" => "Quick Fox"}
  def has_any_word(ctx, haystack, words) do
    haystack = eval!(haystack, ctx)

    if is_binary(haystack) do
      [words] = eval_args!([words], ctx)
      words = to_string(words)
      haystack_words = String.split(haystack)
      haystacks_lowercase = Enum.map(haystack_words, &String.downcase/1)
      words_lowercase = words |> String.split() |> Enum.map(&String.downcase/1)

      matched_indices =
        haystacks_lowercase
        |> Enum.with_index()
        |> Enum.filter(fn {haystack_word, _index} ->
          Enum.member?(words_lowercase, haystack_word)
        end)
        |> Enum.map(fn {_haystack_word, index} -> index end)

      matched_haystack_words = Enum.map(matched_indices, &Enum.at(haystack_words, &1))

      match? = Enum.any?(matched_haystack_words)

      %{
        "__value__" => match?,
        "match" => if(match?, do: Enum.join(matched_haystack_words, " "), else: nil)
      }
    end
  end

  @doc """
  Check whether the given text contains any of the provided strings. The function performs a case-insensitive exact match.
  The second argument expects either a list of strings or a single string with comma-separated phrases.
  """
  @expression_category "string"
  @expression_doc expression:
                    ~S|has_any_phrase("hey how are you?", ["hello", "bye bye", "how are you"])|,
                  result: true
  @expression_doc expression: ~S|has_any_phrase("مرحباً كيف حالك؟", ["كيف حالك", "how are you"])|,
                  result: true
  @expression_doc expression:
                    ~S|has_any_phrase("hey how are you?", "hello, bye bye, how are you")|,
                  result: true
  @expression_doc doc:
                    "Return boolean indicating if text contains any of the provided phrases from value in __value__ key if complex values are provided.",
                  expression: "has_any_phrase(text, phrases)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "hey how are you?"
                    },
                    "phrases" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["hello", "bye bye", "how are you"]
                    }
                  },
                  result: true
  def has_any_phrase(ctx, text, phrases) do
    [text, phrases] = eval_args!([text, phrases], ctx)

    phrases =
      cond do
        is_binary(phrases) ->
          phrases
          |> String.split(",")
          |> Enum.map(&String.trim/1)

        is_list(phrases) ->
          phrases

        true ->
          []
      end

    String.contains?(
      String.downcase(to_string(text)),
      Enum.map(phrases, fn phrase -> String.downcase(to_string(phrase)) end)
    )
  end

  @doc """
  Tests whether text starts with beginning

  Both text values are trimmed of surrounding whitespace, but otherwise matching is
  strict without any tokenization.
  """
  @expression_category "string"
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"the quick\")", result: true
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"the    quick\")",
                  result: false
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"quick brown\")", result: false
  @expression_doc doc:
                    "Tests whether text starts with beginning value in __value__ key if complex values are provided.",
                  expression: "has_beginning(text, beginning)",
                  context: %{
                    "text" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "The Quick Brown"
                    },
                    "beginning" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the quick"
                    }
                  },
                  result: true
  def has_beginning(ctx, text, beginning) do
    [text, beginning] = eval_args!([text, beginning], ctx)

    case Regex.run(~r/^#{Regex.escape(beginning)}/i, to_string(text)) do
      # future match result: first
      [_first | _remainder] -> true
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a date formatted according to our environment

  This is very naively implemented with a regular expression.
  """
  @expression_category "string"
  @expression_doc expression: "has_date(\"the date is 15/01/2017 05:50\")",
                  result: %{
                    "__value__" => true,
                    "match" => ~U[2017-01-15 05:50:00Z],
                    "date" => ~D[2017-01-15],
                    "datetime" => ~U[2017-01-15 05:50:00Z]
                  }
  @expression_doc expression: "has_date(\"the date is 15/01/2017\").date", result: ~D[2017-01-15]
  @expression_doc expression: "has_date(\"the date is 15/01/2017 05:50\").datetime",
                  result: ~U[2017-01-15 05:50:00Z]
  @expression_doc expression: "has_date(\"there is no date here, just a year 2017\")",
                  result: %{
                    "__value__" => false,
                    "match" => nil,
                    "date" => nil,
                    "datetime" => nil
                  }
  @expression_doc expression: "has_date(1)",
                  result: %{
                    "__value__" => false,
                    "date" => nil,
                    "datetime" => nil,
                    "match" => nil
                  }
  @expression_doc expression: "has_date(var)",
                  context: %{"var" => 1},
                  result: %{
                    "__value__" => false,
                    "date" => nil,
                    "datetime" => nil,
                    "match" => nil
                  }
  @expression_doc doc:
                    "Tests whether expression contains a date from value in __value__ key if complex values are provided.",
                  expression: "has_date(expression)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the date is 15/01/2017 05:50"
                    }
                  },
                  result: %{
                    "__value__" => true,
                    "date" => ~D[2017-01-15],
                    "datetime" => ~U[2017-01-15 05:50:00Z],
                    "match" => ~U[2017-01-15 05:50:00Z]
                  }
  def has_date(ctx, expression) do
    {date, datetime} =
      if datetime = DateHelpers.extract_datetimeish(eval!(expression, ctx)) do
        {DateTime.to_date(datetime), datetime}
      else
        {nil, nil}
      end

    %{
      "__value__" => !!(date || datetime),
      "match" => datetime || date,
      "date" => date,
      "datetime" => datetime
    }
  end

  @doc """
  Tests whether `expression` is a date equal to `date_string`
  """
  @expression_category "string"
  @expression_doc expression: "has_date_eq(\"the date is 15/01/2017\", \"2017-01-15\")",
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-01-15]
                  }
  @expression_doc expression:
                    "has_date_eq(\"there is no date here, just a year 2017\", \"2017-01-15\")",
                  result: %{
                    "error" => %{
                      "__type__" => "expression/v1error",
                      "error" => true,
                      "message" => "The first argument is nil",
                      "__value__" => nil
                    },
                    "__value__" => false,
                    "match" => nil,
                    "test" => ~D[2017-01-15]
                  }

  @expression_doc doc:
                    "Tests whether expression is equal to date from value in __value__ key if complex values are provided.",
                  expression: "has_date_eq(\"the date is 15/01/2017\", \"2017-01-15\")",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the date is 15/01/2017"
                    },
                    "date_string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2017-01-15"
                    }
                  },
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-01-15]
                  }
  def has_date_eq(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)

    case date_compare(found_date, test_date) do
      {:ok, match} ->
        matched_date_value(match == :eq, found_date, test_date)

      {:error, error} ->
        matched_date_value(false, found_date, test_date, error: error)
    end
  end

  @doc """
  Tests whether `expression` is a date after the date `date_string`
  """
  @expression_category "string"
  @expression_doc expression: "has_date_gt(\"the date is 15/01/2017\", \"2017-01-01\")",
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-01-01]
                  }
  @expression_doc expression: "has_date_gt(\"the date is 15/01/2017\", \"2017-03-15\")",
                  result: %{
                    "__value__" => false,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-03-15]
                  }
  @expression_doc doc:
                    "Tests whether expression is greater than date from value in __value__ key if complex values are provided.",
                  expression: "has_date_gt(expression, date_string)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the date is 15/01/2017"
                    },
                    "date_string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2017-01-01"
                    }
                  },
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-01-01]
                  }
  def has_date_gt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)

    case date_compare(found_date, test_date) do
      {:ok, match} ->
        matched_date_value(match == :gt, found_date, test_date)

      {:error, error} ->
        matched_date_value(false, found_date, test_date, error: error)
    end
  end

  @doc """
  Tests whether `expression` contains a date before the date `date_string`
  """
  @expression_category "string"
  @expression_doc expression: "has_date_lt(\"the date is 15/01/2017\", \"2017-06-01\")",
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-06-01]
                  }
  @expression_doc expression: "has_date_lt(\"the date is 15/01/2021\", \"2017-03-15\")",
                  result: %{
                    "__value__" => false,
                    "match" => ~D[2021-01-15],
                    "test" => ~D[2017-03-15]
                  }
  @expression_doc doc:
                    "Tests whether expression is less than date from value in __value__ key if complex values are provided.",
                  expression: "has_date_lt(expression, date_string)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the date is 15/01/2017"
                    },
                    "date_string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "2017-06-01"
                    }
                  },
                  result: %{
                    "__value__" => true,
                    "match" => ~D[2017-01-15],
                    "test" => ~D[2017-06-01]
                  }
  def has_date_lt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)

    case date_compare(found_date, test_date) do
      {:ok, match} ->
        matched_date_value(match == :lt, found_date, test_date)

      {:error, error} ->
        matched_date_value(false, found_date, test_date, error: error)
    end
  end

  @spec matched_date_value(
          boolean(),
          match :: DateTime.t() | Date.t() | nil,
          test :: DateTime.t() | Date.t() | nil,
          opts :: Keyword.t()
        ) :: %{required(String.t()) => term}
  defp matched_date_value(value, match, test, opts \\ []) do
    value = %{"__value__" => value, "match" => match, "test" => test}

    if error = opts[:error] do
      Map.put(value, "error", error)
    else
      value
    end
  end

  @spec date_compare(DateTime.t() | nil, DateTime.t() | nil) ::
          {:ok, :gt | :lt | :eq}
          | {:error, %{required(String.t()) => term}}
  defp date_compare(nil, _date2), do: {:error, Expression.error_map("The first argument is nil")}
  defp date_compare(_date1, nil), do: {:error, Expression.error_map("The second argument is nil")}
  defp date_compare(date1, date2), do: {:ok, Date.compare(date1, date2)}

  @doc """
  Tests whether an email is contained in text
  """
  @expression_category "string"
  @expression_doc expression: "has_email(\"my email is foo1@bar.com, please respond\")",
                  result: %{"__value__" => true, "email" => "foo1@bar.com"}
  @expression_doc expression: "has_email(\"i'm not sharing my email\")",
                  result: %{"__value__" => false, "email" => nil}
  @expression_doc expression: "has_email(nil)",
                  result: %{"__value__" => false, "email" => nil}
  @expression_doc doc:
                    "Tests whether an email is contained in expression from value in __value__ key if complex values are provided.",
                  expression: "has_email(expression)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "my email is foo1@bar.com, please respond"
                    }
                  },
                  result: %{"__value__" => true, "email" => "foo1@bar.com"}
  def has_email(ctx, expression) do
    expression = eval!(expression, ctx)

    email =
      case Regex.run(~r/([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)/, to_string(expression)) do
        # future match result: match
        [match | _] -> match
        nil -> nil
      end

    %{"__value__" => !!email, "email" => email}
  end

  @doc """
  Returns whether the contact is part of group with the passed in UUID
  """
  @expression_category "enum"
  @expression_doc expression:
                    "has_group(contact.groups, \"b7cf0d83-f1c9-411c-96fd-c511a4cfa86d\")",
                  context: %{
                    "contact" => %{
                      "groups" => [
                        %{
                          "uuid" => "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d"
                        }
                      ]
                    }
                  },
                  result: true
  @expression_doc expression:
                    "has_group(contact.groups, \"00000000-0000-0000-0000-000000000000\")",
                  context: %{
                    "contact" => %{
                      "groups" => [
                        %{
                          "uuid" => "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d"
                        }
                      ]
                    }
                  },
                  result: false
  @expression_doc doc:
                    "Returns whether the groups contain the given uuid from value in __value__ key if complex values are provided.",
                  expression: "has_group(groups, uuid)",
                  context: %{
                    "groups" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => [
                        %{
                          "uuid" => "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d"
                        }
                      ]
                    },
                    "uuid" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "00000000-0000-0000-0000-000000000000"
                    }
                  },
                  result: false
  def has_group(ctx, groups, uuid) do
    [groups, uuid] = eval_args!([groups, uuid], ctx)
    group = Enum.find(groups, nil, &(&1["uuid"] == uuid))
    # future match result: group
    !!group
  end

  defp extract_numberish(nil), do: nil
  defp extract_numberish(value) when is_number(value), do: value

  defp extract_numberish(expression) do
    with [match] <-
           Regex.run(~r/([0-9]+\.?[0-9]*)/u, replace_arabic_numerals(expression), capture: :first) do
      parse_float(match)
    end
  end

  defp replace_arabic_numerals(expression) do
    replace_numerals(expression, %{
      "٠" => "0",
      "١" => "1",
      "٢" => "2",
      "٣" => "3",
      "٤" => "4",
      "٥" => "5",
      "٦" => "6",
      "٧" => "7",
      "٨" => "8",
      "٩" => "9"
    })
  end

  defp replace_numerals(expression, mapping) do
    mapping
    |> Enum.reduce(expression, fn {rune, replacement}, expression ->
      String.replace(expression, rune, replacement)
    end)
  end

  @expression_category "number"
  def parse_float(number) when is_number(number), do: number

  @expression_category "number"
  def parse_float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} -> float
      _ -> nil
    end
  end

  @doc """
  Parses a string as JSON when given a String which is assumed
  to be JSON encoded.

  Will return whatever was supplied as is when the given
  argument is not a String.
  """
  @expression_category "enum"
  @expression_doc expression: "parse_json('[1,2,3]')",
                  result: [1, 2, 3]
  @expression_doc expression: "parse_json('[1,2,3]')",
                  result: [1, 2, 3]
  @expression_doc doc: "Parses JSON from value in __value__ key if complex values are provided.",
                  expression: "parse_json(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "[1,2,3]"
                    }
                  },
                  result: [1, 2, 3]
  def parse_json(ctx, data) do
    case eval!(data, ctx) do
      binary when is_binary(binary) -> Jason.decode!(binary)
      other -> other
    end
  end

  @doc """
  Converts a data structure to JSON
  """
  @expression_category "enum"
  @expression_doc expression: "json(data)",
                  context: %{"data" => %{"foo" => "bar"}},
                  result: Jason.encode!(%{"foo" => "bar"})
  @expression_doc doc: "Converts data from __value__ key to JSON if complex values are provided.",
                  expression: "json(data)",
                  context: %{
                    "data" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => %{"foo" => "bar"}
                    }
                  },
                  result: "{\"foo\":\"bar\"}"
  def json(ctx, data) do
    data = eval!(data, ctx)
    Jason.encode!(data)
  end

  @doc """
  Return true if a list has the given item as a member
  """
  @expression_category "enum"
  @expression_doc doc: "Check whether the given list has the item as a member",
                  expression: ~S|has_member(["A", "B", "C"], "C")|,
                  result: true
  @expression_doc doc:
                    "Check whether the given list has the item as a member from __value__ keys if complex values are provided.",
                  expression: "has_member(list, item)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B", "C"]
                    },
                    "item" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "C"
                    }
                  },
                  result: true
  def has_member(ctx, list, item) do
    [list, item] = eval_args!([list, item], ctx)
    Enum.member?(list, item)
  end

  @doc """
  Tests whether `expression` contains a number
  """
  @expression_category "string"
  @expression_doc expression: "has_number(\"the number is 42 and 5\")",
                  result: %{"__value__" => true, "number" => 42.0}
  @expression_doc expression: "has_number(\"العدد ٤٢\")",
                  result: %{"__value__" => true, "number" => 42.0}
  @expression_doc expression: "has_number(\"٠.٥\")",
                  result: %{"__value__" => true, "number" => 0.5}
  @expression_doc expression: "has_number(\"0.6\")",
                  result: %{"__value__" => true, "number" => 0.6}
  @expression_doc doc:
                    "Tests whether expression contains a number from value in __value__ key if complex values are provided.",
                  expression: "has_number(string)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42 and 5"
                    }
                  },
                  result: %{"__value__" => true, "number" => 42.0}
  def has_number(ctx, expression) do
    expression = eval!(expression, ctx)
    number = extract_numberish(expression)
    # future match result: number
    !!number
    %{"__value__" => !!number, "number" => number}
  end

  @doc """
  Tests whether `expression` contains a number equal to the value
  """
  @expression_category "string"
  @expression_doc expression: "has_number_eq(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_eq(\"the number is 0.5\", \"0.5\")", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42.0\", \"42\")", result: true
  @expression_doc expression: "has_number_eq(\"the number is 40\", \"42\")", result: false
  @expression_doc expression: "has_number_eq(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_eq(\"four hundred\", \"foo\")", result: false
  @expression_doc doc:
                    "Tests whether expression is equal to number from value in __value__ key if complex values are provided.",
                  expression: "has_number_eq(string, float)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42"
                    },
                    "float" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 42
                    }
                  },
                  result: true
  def has_number_eq(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      float == number
    else
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than min
  """
  @expression_category "string"
  @expression_doc expression: "has_number_gt(\"the number is 42\", 40)", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42\", 40.0)", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42\", \"40\")", result: true
  @expression_doc expression: "has_number_gt(\"the number is 0.6\", \"0.5\")", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42.0\", \"40\")", result: true
  @expression_doc expression: "has_number_gt(\"the number is 40\", \"40\")", result: false
  @expression_doc expression: "has_number_gt(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_gt(\"four hundred\", \"foo\")", result: false
  @expression_doc doc:
                    "Tests whether expression is greater than number from value in __value__ key if complex values are provided.",
                  expression: "has_number_gt(string, float)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42"
                    },
                    "float" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 40
                    }
                  },
                  result: true
  def has_number_gt(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number > float
    else
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than or equal to min
  """
  @expression_category "string"
  @expression_doc expression: "has_number_gte(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_gte(\"the number is 0.5\", \"0.5\")", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42.0\", \"45\")", result: false
  @expression_doc expression: "has_number_gte(\"the number is 40\", \"45\")", result: false
  @expression_doc expression: "has_number_gte(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_gte(\"four hundred\", \"foo\")", result: false
  @expression_doc doc:
                    "Tests whether expression is greater than or equal to number from value in __value__ key if complex values are provided.",
                  expression: "has_number_gte(string, float)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42"
                    },
                    "float" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 42
                    }
                  },
                  result: true
  def has_number_gte(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number >= float
    else
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than max
  """
  @expression_category "string"
  @expression_doc expression: "has_number_lt(\"the number is 42\", 44)", result: true
  @expression_doc expression: "has_number_lt(\"the number is 42\", 44.0)", result: true
  @expression_doc expression: "has_number_lt(\"the number is 42\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 0.6\", \"0.5\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 42.0\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 40\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_lt(\"four hundred\", \"foo\")", result: false
  @expression_doc doc:
                    "Tests whether expression is less than number from value in __value__ key if complex values are provided.",
                  expression: "has_number_lt(string, float)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42"
                    },
                    "float" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 44
                    }
                  },
                  result: true
  def has_number_lt(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number < float
    else
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than or equal to max
  """
  @expression_category "string"
  @expression_doc expression: "has_number_lte(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_lte(\"the number is 0.5\", \"0.5\")", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42.0\", \"40\")", result: false
  @expression_doc expression: "has_number_lte(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_lte(\"four hundred\", \"foo\")", result: false
  @expression_doc expression: "has_number_lte(\"@response\", 5)",
                  context: %{"response" => 3},
                  result: true
  @expression_doc doc:
                    "Tests whether expression is less or equal than number from value in __value__ key if complex values are provided.",
                  expression: "has_number_lte(string, float)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the number is 42"
                    },
                    "float" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 42
                    }
                  },
                  result: true
  def has_number_lte(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number <= float
    else
      nil -> false
    end
  end

  @doc """
  Tests whether the text contains only phrase

  The phrase must be the only text in the text to match
  """
  @expression_category "string"
  @expression_doc expression: "has_only_phrase(\"Quick Brown\", \"quick brown\")", result: true
  @expression_doc expression: "has_only_phrase(\"\", \"\")", result: true
  @expression_doc expression: "has_only_phrase(\"The Quick Brown Fox\", \"quick brown\")",
                  result: false
  @expression_doc doc:
                    "Tests whether expression contains only phrase from value in __value__ keys if complex values are provided.",
                  expression: "has_only_phrase(string, phrase)",
                  context: %{
                    "string" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "Quick Brown"
                    },
                    "phrase" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "quick brown"
                    }
                  },
                  result: true
  def has_only_phrase(ctx, expression, phrase) do
    [expression, phrase] = eval_args!([expression, phrase], ctx)
    result = Enum.map([expression, phrase], &String.downcase(String.trim(to_string(&1))))

    case result do
      # Future match result: expression
      [same, same] -> true
      _anything_else -> false
    end
  end

  @doc """
  Returns whether two text values are equal (case sensitive). In the case that they are, it will return the text as the match.
  """
  @expression_category "string"
  @expression_doc expression: "has_only_text(\"foo\", \"foo\")", result: true
  @expression_doc expression: "has_only_text(\"\", \"\")", result: true
  @expression_doc expression: "has_only_text(\"foo\", \"FOO\")", result: false
  @expression_doc doc:
                    "Returns whether two text values are equal from value in __value__ keys if complex values are provided.",
                  expression: "has_only_text(string, phrase)",
                  context: %{
                    "expression_one" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo"
                    },
                    "expression_two" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "foo"
                    }
                  },
                  result: true
  def has_only_text(ctx, expression_one, expression_two) do
    [expression_one, expression_two] = eval_args!([expression_one, expression_two], ctx)
    to_string(expression_one) == to_string(expression_two)
  end

  @doc """
  Tests whether `expression` matches the regex pattern

  Both text values are trimmed of surrounding whitespace and matching is case-insensitive.
  """
  @expression_category "string"
  @expression_doc expression: "has_pattern(\"Buy cheese please\", \"buy (\\w+)\")", result: true
  @expression_doc expression: "has_pattern(\"Sell cheese please\", \"buy (\\w+)\")", result: false
  @expression_doc expression: "has_pattern(nil, \"buy (\\w+)\")", result: false
  @expression_doc doc:
                    "Returns whether two text values are equal from value in __value__ keys if complex values are provided.",
                  expression: "has_pattern(expression, pattern)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "Buy cheese please"
                    },
                    "pattern" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "buy (\\w+)"
                    }
                  },
                  result: true
  def has_pattern(ctx, expression, pattern) do
    [expression, pattern] = eval_args!([expression, pattern], ctx)

    with true <- is_binary(expression),
         {:ok, regex} <- Regex.compile(String.trim(pattern), "i"),
         [[_first | _remainder]] <- Regex.scan(regex, String.trim(expression), capture: :all) do
      # Future match result: first
      true
    else
      _ -> false
    end
  end

  @doc """
  Tests whether `expresssion` contains a phone number.
  The optional country_code argument specifies the country to use for parsing.
  """
  @expression_category "string"
  @expression_doc expression: "has_phone(\"my number is +12067799294 thanks\")",
                  result: %{"__value__" => true, "phonenumber" => "+12067799294"}
  @expression_doc expression: "has_phone(\"my number is 2067799294 thanks\", \"US\")",
                  result: %{"__value__" => true, "phonenumber" => "+12067799294"}
  @expression_doc expression: "has_phone(\"my number is 206 779 9294 thanks\", \"US\")",
                  result: %{"__value__" => true, "phonenumber" => "+12067799294"}
  @expression_doc expression: "has_phone(\"my number is none of your business\", \"US\")",
                  result: %{"__value__" => false, "phonenumber" => nil}
  @expression_doc expression: "has_phone(nil, \"US\")",
                  result: %{"__value__" => false, "phonenumber" => nil}
  @expression_doc expression: "has_phone(\"+27\")",
                  result: %{"__value__" => false, "phonenumber" => nil}
  @expression_doc expression: "has_phone(\"+27\", \"ZA\")",
                  result: %{"__value__" => false, "phonenumber" => nil}
  @expression_category "string"
  @expression_doc doc:
                    "Tests whether expression contains a phone number from value in __value__ key if complex values are provided.",
                  expression: "has_phone(expression)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "my number is +12067799294 thanks"
                    }
                  },
                  result: %{"__value__" => true, "phonenumber" => "+12067799294"}
  def has_phone(ctx, expression) do
    [expression] = eval_args!([expression], ctx)
    letters_removed = Regex.replace(~r/[a-z]/i, to_string(expression), "")

    parse_phone_number(letters_removed, "")
  end

  @expression_category "string"
  def has_phone(ctx, expression, country_code) do
    [expression, country_code] = eval_args!([expression, country_code], ctx)
    letters_removed = Regex.replace(~r/[a-z]/i, to_string(expression), "")

    parse_phone_number(letters_removed, country_code)
  end

  defp parse_phone_number(string, country_code) do
    pn =
      with {:ok, pn} <- ExPhoneNumber.parse(string, country_code),
           true <- ExPhoneNumber.is_possible_number?(string, country_code),
           true <- ExPhoneNumber.is_valid_number?(pn) do
        ExPhoneNumber.format(pn, :e164)
      else
        _ -> nil
      end

    %{"__value__" => !!pn, "phonenumber" => pn}
  end

  @doc """
  Tests whether phrase is contained in `expression`

  The words in the test phrase must appear in the same order with no other words in between.
  """
  @expression_category "string"
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"brown fox\")", result: true
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"quick fox\")", result: false
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"\")", result: true
  @expression_doc doc:
                    "Tests whether expression contains phrase from value in __value__ keys if complex values are provided.",
                  expression: "has_phrase(expression, phrase)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the quick brown fox"
                    },
                    "phrase" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "brown fox"
                    }
                  },
                  result: true
  def has_phrase(ctx, expression, phrase) do
    [expression, phrase] = eval_args!([expression, phrase], ctx)
    lower_expression = String.downcase(to_string(expression))
    lower_phrase = String.downcase(to_string(phrase))

    String.contains?(lower_expression, lower_phrase)
  end

  @doc """
  Tests whether there the `expression` has any characters in it
  """
  @expression_category "string"
  @expression_doc expression: "has_text(\"quick brown\")", result: true
  @expression_doc expression: "has_text(\"\")", result: false
  @expression_doc expression: "has_text(\" \n\")", result: false
  @expression_doc expression: "has_text(123)", result: true
  @expression_doc expression: "has_text(nil)", result: false
  @expression_doc doc:
                    "Tests whether expression has text from value in __value__ key if complex values are provided.",
                  expression: "has_text(expression)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "quick brown"
                    }
                  },
                  result: true
  def has_text(ctx, expression) do
    expression =
      expression
      |> eval!(ctx)
      |> to_string()

    String.trim(to_string(expression)) != ""
  end

  @doc """
  Tests whether `expression` contains a time.
  """
  @expression_category "string"
  @expression_doc expression: "has_time(\"the time is 10:30\")",
                  result: %{"__value__" => true, "match" => ~T[10:30:00]}
  @expression_doc expression: "has_time(\"the time is 10:00 pm\")",
                  result: %{"__value__" => true, "match" => ~T[10:00:00]}
  @expression_doc expression: "has_time(\"the time is 10:30:45\")",
                  result: %{"__value__" => true, "match" => ~T[10:30:45]}
  @expression_doc expression: "has_time(\"there is no time here, just the number 25\")",
                  result: false
  @expression_doc doc:
                    "Tests whether expression contains time from value in __value__ key if complex values are provided.",
                  expression: "has_time(expression)",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "the time is 10:30"
                    }
                  },
                  result: %{"__value__" => true, "match" => ~T[10:30:00]}
  def has_time(ctx, expression) do
    if time = DateHelpers.extract_timeish(eval!(expression, ctx)) do
      %{
        "__value__" => true,
        "match" => time
      }
    else
      false
    end
  end

  @doc """
  map over a list of items and apply the mapper function to every item, returning
  the result.
  """
  @expression_category "enum"
  @expression_doc doc: "Map over the range of numbers, create a date in January for every number",
                  expression: "map(1..3, &date(2022, 1, &1))",
                  result: [~D[2022-01-01], ~D[2022-01-02], ~D[2022-01-03]]
  @expression_doc doc:
                    "Map over the range of numbers, multiple each by itself and return the result",
                  expression: "map(1..3, &(&1 * &1))",
                  result: [1, 4, 9]
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "map(nil, &(&1 * &1))",
                  result: Expression.error_map("Invalid enumerable")
  @expression_doc doc:
                    "Map over a list of items from value in __value__ key if complex values are provided.",
                  expression: "map(expression, &date(2022, 1, &1))",
                  context: %{
                    "expression" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1..3
                    }
                  },
                  result: [~D[2022-01-01], ~D[2022-01-02], ~D[2022-01-03]]
  def map(ctx, enumerable, mapper) do
    [enumerable, mapper] = eval_args!([enumerable, mapper], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      enumerable
      # wrap in a list to be passed as a list of arguments
      |> Enum.map(&[&1])
      # call the mapper with each list of arguments as a single argument
      |> Enum.map(mapper)
    end
  end

  @doc """
  Generate a random number between `min` and `max`
  """
  @expression_category "number"
  @expression_doc doc: "Generate a number between 1 and 10",
                  expression: "rand_between(1, 10)",
                  fake_result: 3
  @expression_doc doc:
                    "Generate a number between min and max from value in __value__ keys if complex values are provided.",
                  expression: "rand_between(min, max)",
                  context: %{
                    "min" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 1
                    },
                    "max" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 10
                    }
                  },
                  fake_result: 3
  def rand_between(ctx, min, max) do
    [min, max] = eval_args!([min, max], ctx)
    Enum.random(min..max)
  end

  @doc """
  Return the division remainder of two integers.
  """
  @expression_category "number"
  @expression_doc expression: "rem(4, 2)",
                  result: 0
  @expression_doc expression: "rem(85, 3)",
                  result: 1
  @expression_doc doc:
                    "Return the division remainder of two integers from value in __value__ keys if complex values are provided.",
                  expression: "rem(int1, int2)",
                  context: %{
                    "int1" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 4
                    },
                    "int2" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => 2
                    }
                  },
                  result: 0
  def rem(ctx, integer1, integer2) do
    [integer1, integer2] = eval_args!([integer1, integer2], ctx)

    rem(integer1, integer2)
  end

  @doc """
  Reduces elements from a list by applying a function and collecting the
  results in an accumulator.

  The first argument to the lambda function is the item from the list,
  the second argument is the accumulator.
  """
  @expression_category "enum"
  @expression_doc expression: "reduce(1..3, 0, & &1 + &2)", result: 6
  @expression_doc doc: "If an invalid, non-enumerable value is passed, return an error",
                  expression: "reduce(nil, 0, & &1 + &2)",
                  result: Expression.error_map("Invalid enumerable")
  def reduce(ctx, enumerable, accumulator, reducer) do
    [enumerable, accumulator, reducer] = eval_args!([enumerable, accumulator, reducer], ctx)

    if is_nil(enumerable) or is_nil(Enumerable.impl_for(enumerable)) do
      Expression.error_map("Invalid enumerable")
    else
      Enum.reduce(enumerable, accumulator, &reducer.([&1, &2]))
    end
  end

  @doc """
  Appends an item or a list of items to a given list.
  """
  @expression_category "enum"
  @expression_doc expression: "append([\"A\", \"B\"], \"C\")",
                  result: ["A", "B", "C"]
  @expression_doc expression: "append([\"A\", \"B\"], [\"C\", \"B\"])",
                  result: ["A", "B", "C", "B"]
  @expression_doc doc:
                    "Appends an item or a list of items to a given list from __value__ keys if complex values are provided.",
                  expression: "append(list, payload)",
                  context: %{
                    "list" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => ["A", "B"]
                    },
                    "payload" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "C"
                    }
                  },
                  result: ["A", "B", "C"]
  def append(ctx, list, payload) do
    [list, payload] = eval_args!([list, payload], ctx)
    enumerable = if is_list(payload), do: payload, else: [payload]

    Enum.concat(list, enumerable)
  end

  @doc """
  Deletes an element from a map by the given key.
  """
  @expression_category "enum"
  @expression_doc expression: "delete(patient, \"gender\")",
                  context: %{"patient" => %{"gender" => "?", "age" => 32}},
                  result: %{"age" => 32}
  @expression_doc doc:
                    "Deletes an element from a map by the given key from __value__ keys if complex values are provided.",
                  expression: "delete(map, key)",
                  context: %{
                    "map" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => %{"gender" => "?", "age" => 32}
                    },
                    "key" => %{
                      "display" => "value for display key",
                      "value" => "value for value key",
                      "__value__" => "gender"
                    }
                  },
                  result: %{"age" => 32}
  def delete(ctx, map, key) do
    [map, key] = eval_args!([map, key], ctx)

    Map.delete(map, key)
  end

  @doc """
  Checks whether `value` is an error
  """
  @expression_category "logical"
  @expression_doc expression: "is_error(error)",
                  context: %{"error" => Expression.error_map("the error")},
                  result: true
  @expression_doc expression: "is_error(\"not an error\")",
                  context: %{},
                  result: false
  @spec is_error(Expression.Context.t(), %{required(String.t()) => term}) :: boolean
  # Disable credo as the expression function is standardised to has an `is_*` predicate
  # credo:disable-for-next-line Credo.Check.Readability.PredicateFunctionNames
  def is_error(ctx, value) do
    case eval!(
           value,
           ctx,
           # Do not have enums describing errors be casted to the default
           # value (which is nil), which would make it impossible to
           # detect errors.
           false
         ) do
      %{"__type__" => "expression/v1error"} -> true
      _other -> false
    end
  end
end
