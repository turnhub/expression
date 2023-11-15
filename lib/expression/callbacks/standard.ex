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
  Defines a new date value
  """
  @expression_doc doc: "Construct a date from year, month, and day integers",
                  expression: "date(year, month, day)",
                  context: %{
                    "year" => 2022,
                    "month" => 1,
                    "day" => 31
                  },
                  result: ~D[2022-01-31]
  def date(ctx, year, month, day) do
    [year, month, day] = eval_args!([year, month, day], ctx)

    fields = [
      calendar: Calendar.ISO,
      year: year,
      month: month,
      day: day,
      time_zone: "Etc/UTC",
      zone_abbr: "UTC"
    ]

    struct(Date, fields)
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
  def datetime_add(ctx, datetime, offset, unit) do
    datetime = DateHelpers.extract_datetimeish(eval!(datetime, ctx))
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
  end

  @doc """
  Converts date stored in text to an actual date object and
  formats it using `strftime` formatting.

  It will fallback to "%Y-%m-%d %H:%M:%S" if no formatting is supplied

  """
  @expression_doc doc: "Convert a date from a piece of text to a formatted date string",
                  expression: "datevalue(\"2022-01-01\")",
                  result: %{"__value__" => "2022-01-01 00:00:00", "date" => ~D[2022-01-01]}
  @expression_doc doc: "Convert a date from a piece of text and read the date field",
                  expression: "datevalue(\"2022-01-01\").date",
                  result: ~D[2022-01-01]
  @expression_doc doc: "Convert a date value and read the date field",
                  expression: "datevalue(date(2022, 1, 1)).date",
                  result: ~D[2022-01-01]
  def datevalue(ctx, date, format) do
    [date, format] = eval!([date, format], ctx)

    if date = DateHelpers.extract_dateish(date) do
      %{"__value__" => Timex.format!(date, format, :strftime), "date" => date}
    end
  end

  def datevalue(ctx, date) do
    date = DateHelpers.extract_dateish(eval!(date, ctx))

    %{
      "__value__" => Timex.format!(date, "%Y-%m-%d %H:%M:%S", :strftime),
      "date" => date
    }
  end

  @doc """
  Returns only the day of the month of a date (1 to 31)
  """
  @expression_doc doc: "Getting today's day of the month",
                  expression: "day(date(2022, 9, 10))",
                  result: 10
  @expression_doc doc: "Getting today's day of the month",
                  expression: "day(now())",
                  fake_result: DateTime.utc_now().day
  def day(ctx, date) do
    %{day: day} = eval!(date, ctx)
    day
  end

  @doc """
  Moves a date by the given number of months
  """
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
  def edate(ctx, date, months) do
    [date, months] = eval_args!([date, months], ctx)
    DateHelpers.extract_dateish(date) |> Timex.shift(months: months)
  end

  @doc """
  Returns only the hour of a datetime (0 to 23)
  """
  @expression_doc doc: "Get the current hour",
                  expression: "hour(now())",
                  fake_result: DateTime.utc_now().hour
  def hour(ctx, date) do
    %{hour: hour} = eval!(date, ctx)
    hour
  end

  @doc """
  Returns only the minute of a datetime (0 to 59)
  """
  @expression_doc doc: "Get the current minute",
                  expression: "minute(now())",
                  fake_result: DateTime.utc_now().minute
  def minute(ctx, date) do
    %{minute: minute} = DateHelpers.extract_datetimeish(eval!(date, ctx))
    minute
  end

  @doc """
  Returns only the month of a date (1 to 12)
  """
  @expression_doc doc: "Get the current month",
                  expression: "month(now())",
                  fake_result: DateTime.utc_now().month
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
  @expression_doc expression: "second(now)",
                  context: %{"now" => DateTime.utc_now()},
                  fake_result: DateTime.utc_now().second
  def second(ctx, date) do
    %{second: second} = eval!(date, ctx)
    second
  end

  @doc """
  Defines a time value which can be used for time arithmetic
  """
  @expression_doc expression: "time(12, 13, 14)",
                  result: %Time{hour: 12, minute: 13, second: 14}
  def time(ctx, hours, minutes, seconds) do
    [hours, minutes, seconds] = eval_args!([hours, minutes, seconds], ctx)
    %Time{hour: hours, minute: minutes, second: seconds}
  end

  @doc """
  Converts time stored in text to an actual time
  """
  @expression_doc expression: "timevalue(\"2:30\")",
                  result: %Time{hour: 2, minute: 30, second: 0}
  @expression_doc expression: "timevalue(\"2:30:55\")",
                  result: %Time{hour: 2, minute: 30, second: 55}
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
  @expression_doc expression: "today()",
                  fake_result: Date.utc_today()
  def today(_ctx) do
    Date.utc_today()
  end

  @doc """
  Returns the day of the week of a date (1 for Sunday to 7 for Saturday)
  """
  @expression_doc expression: "weekday(today)",
                  context: %{"today" => ~D[2022-11-06]},
                  result: 1
  @expression_doc expression: "weekday(today)",
                  context: %{"today" => ~D[2022-11-01]},
                  result: 3
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
  @expression_doc expression: "year(now)",
                  context: %{"now" => DateTime.utc_now()},
                  fake_result: DateTime.utc_now().year
  def year(ctx, date) do
    %{year: year} = DateHelpers.extract_dateish(eval!(date, ctx))
    year
  end

  @doc """
  Returns `true` if and only if all its arguments evaluate to `true`
  """
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
  def and_vargs(ctx, arguments) do
    arguments = eval_args!(arguments, ctx)
    Enum.all?(arguments, & &1)
  end

  @doc """
  Returns `false` if the argument supplied evaluates to truth-y
  """
  @expression_doc expression: "not(false)", result: true
  def not_(ctx, argument) do
    !eval!(argument, ctx)
  end

  @doc """
  Returns one value if the condition evaluates to `true`, and another value if it evaluates to `false`
  """
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
  def if_(ctx, condition, yes, no) do
    if(eval!(condition, ctx),
      do: eval!(yes, ctx),
      else: eval!(no, ctx)
    )
  end

  @doc """
  Returns `true` if any argument is `true`.
  Returns the first truthy value found or otherwise false.

  Accepts any amount of arguments for testing truthiness.
  """
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
  def or_vargs(ctx, arguments) do
    arguments = eval_args!(arguments, ctx)
    Enum.reduce(arguments, fn a, b -> a || b end)
  end

  @doc """
  Returns the absolute value of a number
  """
  @expression_doc expression: "abs(-1)",
                  result: 1
  def abs(ctx, number) do
    abs(eval!(number, ctx))
  end

  @doc """
  Returns the maximum value of all arguments
  """
  @expression_doc expression: "max(1, 2, 3)",
                  result: 3
  def max_vargs(ctx, arguments) do
    Enum.max(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the minimum value of all arguments
  """
  @expression_doc expression: "min(1, 2, 3)",
                  result: 1
  def min_vargs(ctx, arguments) do
    Enum.min(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the result of a number raised to a power - equivalent to the ^ operator
  """
  @expression_doc expression: "power(2, 3)",
                  fake_result: 8.0
  def power(ctx, a, b) do
    [a, b] = eval_args!([a, b], ctx)
    :math.pow(a, b)
  end

  @doc """
  Returns the sum of all arguments, equivalent to the + operator

  ```
  You have @SUM(contact.reports, contact.forms) reports and forms
  ```
  """
  @expression_doc expression: "sum(1, 2, 3)",
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
  @expression_doc expression: "char(65)",
                  result: "A"
  def char(ctx, code) do
    code = eval!(code, ctx)
    <<code>>
  end

  @doc """
  Removes all non-printable characters from a text string
  """
  @expression_doc expression: "clean(value)",
                  context: %{"value" => <<65, 0, 66, 0, 67>>},
                  result: "ABC"
  def clean(ctx, binary) do
    binary
    |> eval!(ctx)
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
  @expression_doc expression: "code(\"A\")",
                  result: 65
  def code(ctx, code_ast) do
    <<code>> = eval!(code_ast, ctx)
    code
  end

  @doc """
  Joins text strings into one text string

  ```
  > "Your name is @CONCATENATE(contact.first_name, \\" \\", contact.last_name)"
  "Your name is name surname"
  ```
  """
  @expression_doc expression: "concatenate(contact.first_name, \" \", contact.last_name)",
                  context: %{
                    "contact" => %{
                      "first_name" => "name",
                      "last_name" => "surname"
                    }
                  },
                  result: "name surname"
  def concatenate_vargs(ctx, arguments) do
    Enum.join(eval_args!(arguments, ctx), "")
  end

  @doc """
  Formats the given number in decimal format using a period and commas

  ```
  > You have @fixed(contact.balance, 2) in your account
  "You have 4.21 in your account"
  ```
  """
  @expression_doc expression: "fixed(4.209922, 2, false)",
                  result: "4.21"
  @expression_doc expression: "fixed(4000.424242, 4, true)",
                  result: "4,000.4242"
  @expression_doc expression: "fixed(3.7979, 2, false)",
                  result: "3.80"
  @expression_doc expression: "fixed(3.7979, 2)",
                  result: "3.80"
  def fixed(ctx, number, precision) do
    [number, precision] = eval_args!([number, precision], ctx)
    Number.Delimit.number_to_delimited(number, precision: precision)
  end

  def fixed(ctx, number, precision, no_commas) do
    case eval_args!([number, precision, no_commas], ctx) do
      [number, precision, true] ->
        Number.Delimit.number_to_delimited(number,
          precision: precision,
          delimiter: ",",
          separator: "."
        )

      [number, precision, false] ->
        Number.Delimit.number_to_delimited(number, precision: precision)
    end
  end

  @doc """
  Returns the first characters in a text string. This is Unicode safe.
  """
  @expression_doc expression: "left(\"foobar\", 4)",
                  result: "foob"

  @expression_doc expression:
                    "left(\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\", 20)",
                  result: "Умерла Мадлен Олбрай"
  def left(ctx, binary, size) do
    [binary, size] = eval_args!([binary, size], ctx)
    String.slice(binary, 0, size)
  end

  @doc """
  Returns the number of characters in a text string
  """
  @expression_doc expression: "len(\"foo\")",
                  result: 3
  @expression_doc expression: "len(\"zoë\")",
                  result: 3
  def len(ctx, binary) do
    String.length(eval!(binary, ctx))
  end

  @doc """
  Converts a text string to lowercase
  """
  @expression_doc expression: "lower(\"Foo Bar\")",
                  result: "foo bar"
  def lower(ctx, binary) do
    String.downcase(eval!(binary, ctx))
  end

  @doc """
  Capitalizes the first letter of every word in a text string
  """
  @expression_doc expression: "proper(\"foo bar\")",
                  result: "Foo Bar"
  def proper(ctx, binary) do
    binary
    |> eval!(ctx)
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Repeats text a given number of times
  """
  @expression_doc expression: "rept(\"*\", 10)",
                  result: "**********"
  def rept(ctx, value, amount) do
    [value, amount] = eval_args!([value, amount], ctx)
    String.duplicate(value, amount)
  end

  @doc """
  Returns the last characters in a text string.
  This is Unicode safe.
  """
  @expression_doc expression: "right(\"testing\", 3)",
                  result: "ing"
  @expression_doc expression:
                    "right(\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\", 20)",
                  result: "ту главы Госдепа США"
  def right(ctx, binary, size) do
    [binary, size] = eval_args!([binary, size], ctx)
    String.slice(binary, -size, size)
  end

  @doc """
  Substitutes new_text for old_text in a text string. If instance_num is given, then only that instance will be substituted
  """
  @expression_doc expression: "substitute(\"I can't\", \"can't\", \"can do\")",
                  result: "I can do"
  def substitute(ctx, subject, pattern, replacement) do
    [subject, pattern, replacement] = eval_args!([subject, pattern, replacement], ctx)
    String.replace(subject, pattern, replacement)
  end

  @doc """
  Returns the unicode character specified by a number
  """
  @expression_doc expression: "unichar(65)", result: "A"
  @expression_doc expression: "unichar(233)", result: "é"
  def unichar(ctx, code) do
    code = eval!(code, ctx)
    <<code::utf8>>
  end

  @doc """
  Returns a numeric code for the first character in a text string
  """
  @expression_doc expression: "unicode(\"A\")", result: 65
  @expression_doc expression: "unicode(\"é\")", result: 233
  def unicode(ctx, letter) do
    <<code::utf8>> = eval!(letter, ctx)
    code
  end

  @doc """
  Converts a text string to uppercase
  """
  @expression_doc expression: "upper(\"foo\")",
                  result: "FOO"
  def upper(ctx, binary) do
    String.upcase(eval!(binary, ctx))
  end

  @doc """
  Returns the first word in the given text - equivalent to WORD(text, 1)
  """
  @expression_doc expression: "first_word(\"foo bar baz\")",
                  result: "foo"
  def first_word(ctx, binary) do
    [word | _] = String.split(eval!(binary, ctx), " ")
    word
  end

  @doc """
  Formats a number as a percentage
  """
  @expression_doc expression: "percent(2/10)", result: "20%"
  @expression_doc expression: "percent(0.2)", result: "20%"
  @expression_doc expression: "percent(d)", context: %{"d" => "0.2"}, result: "20%"
  def percent(ctx, float) do
    float = eval!(float, ctx)

    with float when is_number(float) <- parse_float(float) do
      Number.Percentage.number_to_percentage(float * 100, precision: 0)
    end
  end

  @doc """
  Formats digits in text for reading in TTS
  """
  @expression_doc expression: "read_digits(\"+271\")", result: "plus two seven one"
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
    |> String.graphemes()
    |> Enum.map(fn grapheme -> Map.get(map, grapheme, nil) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  @doc """
  Removes the first word from the given text. The remaining text will be unchanged
  """
  @expression_doc expression: "remove_first_word(\"foo bar\")", result: "bar"
  @expression_doc expression: "remove_first_word(\"foo-bar\", \"-\")", result: "bar"
  def remove_first_word(ctx, binary) do
    binary = eval!(binary, ctx)
    separator = " "
    tl(String.split(binary, separator)) |> Enum.join(separator)
  end

  def remove_first_word(ctx, binary, separator) do
    [binary, separator] = eval_args!([binary, separator], ctx)
    tl(String.split(binary, separator)) |> Enum.join(separator)
  end

  @doc """
  Extracts the nth word from the given text string. If stop is a negative number,
  then it is treated as count backwards from the end of the text. If by_spaces is
  specified and is `true` then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well
  """
  @expression_doc expression: "word(\"hello cow-boy\", 2)", result: "cow"
  @expression_doc expression: "word(\"hello cow-boy\", 2, true)", result: "cow-boy"
  @expression_doc expression: "word(\"hello cow-boy\", -1)", result: "boy"
  def word(ctx, binary, n) do
    [binary, n] = eval_args!([binary, n], ctx)
    parts = String.split(binary, @punctuation_pattern)

    # This slicing seems off.
    [part] =
      if n < 0 do
        Enum.slice(parts, n, 1)
      else
        Enum.slice(parts, n - 1, 1)
      end

    part
  end

  def word(ctx, binary, n, by_spaces) do
    [binary, n, by_spaces] = eval_args!([binary, n, by_spaces], ctx)
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)
    parts = String.split(binary, splitter)

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
  @expression_doc expression: "word_count(\"hello cow-boy\")", result: 3
  @expression_doc expression: "word_count(\"hello cow-boy\", true)", result: 2
  def word_count(ctx, binary) do
    binary
    |> eval!(ctx)
    |> String.split(@punctuation_pattern)
    |> Enum.count()
  end

  def word_count(ctx, binary, by_spaces) do
    [binary, by_spaces] = eval_args!([binary, by_spaces], ctx)
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    binary
    |> String.split(splitter)
    |> Enum.count()
  end

  @doc """
  Extracts a substring of the words beginning at start, and up to but not-including stop.
  If stop is omitted then the substring will be all words from start until the end of the text.
  If stop is a negative number, then it is treated as count backwards from the end of the text.
  If by_spaces is specified and is `true` then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well
  """
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 2, 4)",
                  result: "expressions are"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 2)",
                  result: "expressions are fun"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", 1, -2)",
                  result: "FLOIP expressions"
  @expression_doc expression: "word_slice(\"FLOIP expressions are fun\", -1)",
                  result: "fun"
  def word_slice(ctx, binary, start) do
    [binary, start] = eval_args!([binary, start], ctx)

    parts =
      binary
      |> String.split(" ")

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

  def word_slice(ctx, binary, start, stop) do
    [binary, start, stop] = eval_args!([binary, start, stop], ctx)

    cond do
      stop > 0 ->
        binary
        |> String.split(@punctuation_pattern)
        |> Enum.slice((start - 1)..(stop - 2))
        |> Enum.join(" ")

      stop < 0 ->
        binary
        |> String.split(@punctuation_pattern)
        |> Enum.slice((start - 1)..(stop - 1))
        |> Enum.join(" ")
    end
  end

  def word_slice(ctx, binary, start, stop, by_spaces) do
    [binary, start, stop, by_spaces] = eval_args!([binary, start, stop, by_spaces], ctx)
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    case stop do
      stop when stop > 0 ->
        binary
        |> String.split(splitter)
        |> Enum.slice((start - 1)..(stop - 2))
        |> Enum.join(" ")

      stop when stop < 0 ->
        binary
        |> String.split(splitter)
        |> Enum.slice((start - 1)..(stop - 1))
        |> Enum.join(" ")
    end
  end

  @doc """
  Returns `true` if the argument is a number.
  """
  @expression_doc expression: "isnumber(1)", result: true
  @expression_doc expression: "isnumber(1.0)", result: true
  @expression_doc expression: "isnumber(\"1.0\")", result: true
  @expression_doc expression: "isnumber(\"a\")", result: false
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
  @expression_doc expression: "isbool(true)", result: true
  @expression_doc expression: "isbool(false)", result: true
  @expression_doc expression: "isbool(1)", result: false
  @expression_doc expression: "isbool(0)", result: false
  @expression_doc expression: "isbool(\"true\")", result: false
  @expression_doc expression: "isbool(\"false\")", result: false
  def isbool(ctx, var) do
    eval!(var, ctx) in [true, false]
  end

  @doc """
  Returns `true` if the argument is a string.
  """
  @expression_doc expression: "isstring(\"hello\")", result: true
  @expression_doc expression: "isstring(false)", result: false
  @expression_doc expression: "isstring(1)", result: false
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
  Tests whether all the words are contained in text

  The words can be in any order and may appear more than once.
  """
  @expression_doc expression: "has_all_words(\"the quick brown FOX\", \"the fox\")", result: true
  @expression_doc expression: "has_all_words(\"the quick brown FOX\", \"red fox\")", result: false
  def has_all_words(ctx, haystack, words) do
    [haystack, words] = eval_args!([haystack, words], ctx)
    {patterns, results} = search_words(haystack, words)
    # future match result: Enum.join(results, " ")
    Enum.count(patterns) == Enum.count(results)
  end

  @doc """
  Tests whether any of the words are contained in the text

  Only one of the words needs to match and it may appear more than once.
  """
  @expression_doc expression: "has_any_word(\"The Quick Brown Fox\", \"fox quick\")",
                  result: %{"__value__" => true, "match" => "Quick Fox"}
  @expression_doc expression: "has_any_word(\"The Quick Brown Fox\", \"yellow\")",
                  result: %{"__value__" => false, "match" => nil}
  def has_any_word(ctx, haystack, words) do
    [haystack, words] = eval_args!([haystack, words], ctx)
    haystack_words = String.split(haystack)
    haystacks_lowercase = Enum.map(haystack_words, &String.downcase/1)
    words_lowercase = String.split(words) |> Enum.map(&String.downcase/1)

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

  @doc """
  Tests whether text starts with beginning

  Both text values are trimmed of surrounding whitespace, but otherwise matching is
  strict without any tokenization.
  """
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"the quick\")", result: true
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"the    quick\")",
                  result: false
  @expression_doc expression: "has_beginning(\"The Quick Brown\", \"quick brown\")", result: false
  def has_beginning(ctx, text, beginning) do
    [text, beginning] = eval_args!([text, beginning], ctx)

    case Regex.run(~r/^#{Regex.escape(beginning)}/i, text) do
      # future match result: first
      [_first | _remainder] -> true
      nil -> false
    end
  end

  @doc """
  Tests whether `expression` contains a date formatted according to our environment

  This is very naively implemented with a regular expression.
  """
  @expression_doc expression: "has_date(\"the date is 15/01/2017\")", result: true
  @expression_doc expression: "has_date(\"there is no date here, just a year 2017\")",
                  result: false
  def has_date(ctx, expression) do
    !!DateHelpers.extract_dateish(eval!(expression, ctx))
  end

  @doc """
  Tests whether `expression` is a date equal to `date_string`
  """
  @expression_doc expression: "has_date_eq(\"the date is 15/01/2017\", \"2017-01-15\")",
                  result: true
  @expression_doc expression:
                    "has_date_eq(\"there is no date here, just a year 2017\", \"2017-01-15\")",
                  result: false
  def has_date_eq(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)
    # Future match result: found_date
    found_date == test_date
  end

  @doc """
  Tests whether `expression` is a date after the date `date_string`
  """
  @expression_doc expression: "has_date_gt(\"the date is 15/01/2017\", \"2017-01-01\")",
                  result: true
  @expression_doc expression: "has_date_gt(\"the date is 15/01/2017\", \"2017-03-15\")",
                  result: false
  def has_date_gt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)
    # future match result: found_date
    Date.compare(found_date, test_date) == :gt
  end

  @doc """
  Tests whether `expression` contains a date before the date `date_string`
  """
  @expression_doc expression: "has_date_lt(\"the date is 15/01/2017\", \"2017-06-01\")",
                  result: true
  @expression_doc expression: "has_date_lt(\"the date is 15/01/2021\", \"2017-03-15\")",
                  result: false
  def has_date_lt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = DateHelpers.extract_dateish(expression)
    test_date = DateHelpers.extract_dateish(date_string)
    # future match result: found_date
    Date.compare(found_date, test_date) == :lt
  end

  @doc """
  Tests whether an email is contained in text
  """
  @expression_doc expression: "has_email(\"my email is foo1@bar.com, please respond\")",
                  result: true
  @expression_doc expression: "has_email(\"i'm not sharing my email\")", result: false
  def has_email(ctx, expression) do
    expression = eval!(expression, ctx)

    case Regex.run(~r/([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)/, expression) do
      # future match result: match
      [_match | _] -> true
      nil -> false
    end
  end

  @doc """
  Returns whether the contact is part of group with the passed in UUID
  """
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
  def has_group(ctx, groups, uuid) do
    [groups, uuid] = eval_args!([groups, uuid], ctx)
    group = Enum.find(groups, nil, &(&1["uuid"] == uuid))
    # future match result: group
    !!group
  end

  defp extract_numberish(expression) do
    with [match] <-
           Regex.run(~r/([0-9]+\.?[0-9]*)/u, replace_arabic_numerals(expression), capture: :first),
         float <- parse_float(match) do
      float
    else
      # Regex can return nil
      nil -> nil
      # Float parsing can return :error
      :error -> nil
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

  def parse_float(number) when is_number(number), do: number

  def parse_float(binary) when is_binary(binary) do
    case Float.parse(binary) do
      {float, ""} -> float
      _ -> nil
    end
  end

  @doc """
  Tests whether `expression` contains a number
  """
  @expression_doc expression: "has_number(\"the number is 42 and 5\")", result: true
  @expression_doc expression: "has_number(\"العدد ٤٢\")", result: true
  @expression_doc expression: "has_number(\"٠.٥\")", result: true
  @expression_doc expression: "has_number(\"0.6\")", result: true

  def has_number(ctx, expression) do
    expression = eval!(expression, ctx)
    number = extract_numberish(expression)
    # future match result: number
    !!number
  end

  @doc """
  Tests whether `expression` contains a number equal to the value
  """

  @expression_doc expression: "has_number_eq(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_eq(\"the number is 42.0\", \"42\")", result: true
  @expression_doc expression: "has_number_eq(\"the number is 40\", \"42\")", result: false
  @expression_doc expression: "has_number_eq(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_eq(\"four hundred\", \"foo\")", result: false
  def has_number_eq(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      float == number
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than min
  """
  @expression_doc expression: "has_number_gt(\"the number is 42\", 40)", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42\", 40.0)", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42\", \"40\")", result: true
  @expression_doc expression: "has_number_gt(\"the number is 42.0\", \"40\")", result: true
  @expression_doc expression: "has_number_gt(\"the number is 40\", \"40\")", result: false
  @expression_doc expression: "has_number_gt(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_gt(\"four hundred\", \"foo\")", result: false
  def has_number_gt(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number > float
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than or equal to min
  """
  @expression_doc expression: "has_number_gte(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_gte(\"the number is 42.0\", \"45\")", result: false
  @expression_doc expression: "has_number_gte(\"the number is 40\", \"45\")", result: false
  @expression_doc expression: "has_number_gte(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_gte(\"four hundred\", \"foo\")", result: false
  def has_number_gte(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number >= float
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than max
  """
  @expression_doc expression: "has_number_lt(\"the number is 42\", 44)", result: true
  @expression_doc expression: "has_number_lt(\"the number is 42\", 44.0)", result: true
  @expression_doc expression: "has_number_lt(\"the number is 42\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 42.0\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 40\", \"40\")", result: false
  @expression_doc expression: "has_number_lt(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_lt(\"four hundred\", \"foo\")", result: false
  def has_number_lt(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number < float
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than or equal to max
  """
  @expression_doc expression: "has_number_lte(\"the number is 42\", 42)", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42\", 42.0)", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42\", \"42\")", result: true
  @expression_doc expression: "has_number_lte(\"the number is 42.0\", \"40\")", result: false
  @expression_doc expression: "has_number_lte(\"the number is 40\", \"foo\")", result: false
  @expression_doc expression: "has_number_lte(\"four hundred\", \"foo\")", result: false
  @expression_doc expression: "has_number_lte(\"@response\", 5)",
                  context: %{"response" => 3},
                  result: true
  def has_number_lte(ctx, expression, float) do
    [expression, float] = eval_args!([expression, float], ctx)

    with number when is_number(number) <- extract_numberish(expression),
         float when is_number(float) <- parse_float(float) do
      # Future match result: number
      number <= float
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether the text contains only phrase

  The phrase must be the only text in the text to match
  """
  @expression_doc expression: "has_only_phrase(\"Quick Brown\", \"quick brown\")", result: true
  @expression_doc expression: "has_only_phrase(\"\", \"\")", result: true
  @expression_doc expression: "has_only_phrase(\"The Quick Brown Fox\", \"quick brown\")",
                  result: false

  def has_only_phrase(ctx, expression, phrase) do
    [expression, phrase] = eval_args!([expression, phrase], ctx)

    case Enum.map([expression, phrase], &String.downcase/1) do
      # Future match result: expression
      [same, same] -> true
      _anything_else -> false
    end
  end

  @doc """
  Returns whether two text values are equal (case sensitive). In the case that they are, it will return the text as the match.
  """
  @expression_doc expression: "has_only_text(\"foo\", \"foo\")", result: true
  @expression_doc expression: "has_only_text(\"\", \"\")", result: true
  @expression_doc expression: "has_only_text(\"foo\", \"FOO\")", result: false
  def has_only_text(ctx, expression_one, expression_two) do
    [expression_one, expression_two] = eval_args!([expression_one, expression_two], ctx)
    expression_one == expression_two
  end

  @doc """
  Tests whether `expression` matches the regex pattern

  Both text values are trimmed of surrounding whitespace and matching is case-insensitive.
  """
  @expression_doc expression: "has_pattern(\"Buy cheese please\", \"buy (\\w+)\")", result: true
  @expression_doc expression: "has_pattern(\"Sell cheese please\", \"buy (\\w+)\")", result: false
  def has_pattern(ctx, expression, pattern) do
    [expression, pattern] = eval_args!([expression, pattern], ctx)

    with {:ok, regex} <- Regex.compile(String.trim(pattern), "i"),
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
  @expression_doc expression: "has_phone(\"my number is +12067799294 thanks\")", result: true
  @expression_doc expression: "has_phone(\"my number is 2067799294 thanks\", \"US\")",
                  result: true
  @expression_doc expression: "has_phone(\"my number is 206 779 9294 thanks\", \"US\")",
                  result: true
  @expression_doc expression: "has_phone(\"my number is none of your business\", \"US\")",
                  result: false
  def has_phone(ctx, expression) do
    [expression] = eval_args!([expression], ctx)
    letters_removed = Regex.replace(~r/[a-z]/i, expression, "")

    case ExPhoneNumber.parse(letters_removed, "") do
      # Future match result: ExPhoneNumber.format(pn, :es164)
      {:ok, _pn} -> true
      _ -> false
    end
  end

  def has_phone(ctx, expression, country_code) do
    [expression, country_code] = eval_args!([expression, country_code], ctx)
    letters_removed = Regex.replace(~r/[a-z]/i, expression, "")

    case ExPhoneNumber.parse(letters_removed, country_code) do
      # Future match result: ExPhoneNumber.format(pn, :es164)
      {:ok, _pn} -> true
      _ -> false
    end
  end

  @doc """
  Tests whether phrase is contained in `expression`

  The words in the test phrase must appear in the same order with no other words in between.
  """
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"brown fox\")", result: true
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"quick fox\")", result: false
  @expression_doc expression: "has_phrase(\"the quick brown fox\", \"\")", result: true
  def has_phrase(ctx, expression, phrase) do
    [expression, phrase] = eval_args!([expression, phrase], ctx)
    lower_expression = String.downcase(expression)
    lower_phrase = String.downcase(phrase)
    found? = String.contains?(lower_expression, lower_phrase)
    # Future match result: phrase
    found?
  end

  @doc """
  Tests whether there the `expression` has any characters in it
  """
  @expression_doc expression: "has_text(\"quick brown\")", result: true
  @expression_doc expression: "has_text(\"\")", result: false
  @expression_doc expression: "has_text(\" \n\")", result: false
  @expression_doc expression: "has_text(123)", result: true
  def has_text(ctx, expression) do
    expression = eval!(expression, ctx) |> to_string()
    String.trim(expression) != ""
  end

  @doc """
  Tests whether `expression` contains a time.
  """
  @expression_doc expression: "has_time(\"the time is 10:30\")",
                  result: %{"__value__" => true, "match" => ~T[10:30:00]}
  @expression_doc expression: "has_time(\"the time is 10:00 pm\")",
                  result: %{"__value__" => true, "match" => ~T[10:00:00]}
  @expression_doc expression: "has_time(\"the time is 10:30:45\")",
                  result: %{"__value__" => true, "match" => ~T[10:30:45]}
  @expression_doc expression: "has_time(\"there is no time here, just the number 25\")",
                  result: false
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
  @expression_doc doc: "Map over the range of numbers, create a date in January for every number",
                  expression: "map(1..3, &date(2022, 1, &1))",
                  result: [~D[2022-01-01], ~D[2022-01-02], ~D[2022-01-03]]
  @expression_doc doc:
                    "Map over the range of numbers, multiple each by itself and return the result",
                  expression: "map(1..3, &(&1 * &1))",
                  result: [1, 4, 9]
  def map(ctx, enumerable, mapper) do
    [enumerable, mapper] = eval_args!([enumerable, mapper], ctx)

    enumerable
    # wrap in a list to be passed as a list of arguments
    |> Enum.map(&[&1])
    # call the mapper with each list of arguments as a single argument
    |> Enum.map(mapper)
  end

  @doc """
  Return the division remainder of two integers.
  """
  @expression_doc expression: "rem(4, 2)",
                  result: 0
  @expression_doc expression: "rem(85, 3)",
                  result: 1
  def rem(ctx, integer1, integer2) do
    [integer1, integer2] = eval_args!([integer1, integer2], ctx)

    rem(integer1, integer2)
  end

  @doc """
  Appends items from one list to another list.
  """
  @expression_doc expression: "append([\"A\", \"B\"], [\"C\", \"B\"])",
                  result: ["A", "B", "C", "B"]
  def append(ctx, first_list, second_list) do
    [first_list, second_list] = eval_args!([first_list, second_list], ctx)

    Enum.concat(first_list, second_list)
  end

  @doc """
  Deletes an element from a map by the given key.
  """
  @expression_doc expression: "delete(contact, \"gender\")",
                  context: %{
                    "contact" => %{
                      "gender" => "?",
                      "age" => 32
                    }
                  },
                  result: %{"age" => 32}
  def delete(ctx, map, key) do
    [map, key] = eval_args!([map, key], ctx)

    Map.delete(map, key)
  end
end
