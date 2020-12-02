defmodule Excellent.Callbacks do
  @reserved_words ~w[and if]
  @punctuation_pattern ~r/\s*[,:;!?.-]\s*|\s/

  def atom_function_name(function_name) when function_name in @reserved_words,
    do: atom_function_name("#{function_name}_")

  def atom_function_name(function_name) do
    function_name
    |> String.downcase()
    |> String.to_atom()
  end

  def handle(function_name, arguments, context) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    cond do
      # Check if the exact function signature has been implemented
      function_exported?(__MODULE__, exact_function_name, length(arguments) + 1) ->
        apply(__MODULE__, exact_function_name, [context] ++ arguments)

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(__MODULE__, vargs_function_name, 2) ->
        apply(__MODULE__, vargs_function_name, [context, arguments])

      # Otherwise fail
      true ->
        {:error, :not_implemented}
    end
  end

  @doc """
  Defines a new date value

  ```
  This is a date @DATE(2012, 12, 25)
  ```

  # Example

      iex> to_string(Excellent.Callbacks.date(%{}, 2012, 12, 25))
      "2012-12-25 00:00:00Z"

  """
  def date(_ctx, year, month, day) do
    fields = [
      calendar: Calendar.ISO,
      year: year,
      month: month,
      day: day,
      hour: 0,
      minute: 0,
      second: 0,
      time_zone: "Etc/UTC",
      zone_abbr: "UTC",
      utc_offset: 0,
      std_offset: 0
    ]

    struct(DateTime, fields)
  end

  @doc """
  Converts date stored in text to an actual date,
  using `strftime` formatting.

  It will fallback to "%Y-%m-%d %H:%M:%S" if no formatting is supplied

  ```
  You joined on @DATEVALUE(contact.joined_date, "%Y-%m%-d")
  ```

  # Example

      iex> date = Excellent.Callbacks.date(%{}, 2020, 12, 20)
      iex> Excellent.Callbacks.datevalue(%{}, date)
      "2020-12-20 00:00:00"
      iex> Excellent.Callbacks.datevalue(%{}, date, "%Y-%m-%d")
      "2020-12-20"
  """
  def datevalue(ctx, date, format \\ "%Y-%m-%d %H:%M:%S")

  def datevalue(_ctx, date, format) do
    Timex.format!(date, format, :strftime)
  end

  @doc """
  Returns only the day of the month of a date (1 to 31)

  ```
  The current day is @DAY(contact.joined_date)
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> day = Excellent.Callbacks.day(%{}, now)
      iex> day == now.day
      true
  """
  def day(_ctx, %{day: day} = _date) do
    day
  end

  @doc """
  Moves a date by the given number of months

  ```
  Next month's meeting will be on @EDATE(date.today, 1)
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> future = Timex.shift(now, months: 1)
      iex> date = Excellent.Callbacks.edate(%{}, now, 1)
      iex> future == date
      true
  """
  def edate(_ctx, date, months) do
    date |> Timex.shift(months: months)
  end

  @doc """
  Returns only the hour of a datetime (0 to 23)

  ```
  The current hour is @HOUR(NOW())
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> hour = Excellent.Callbacks.hour(%{}, now)
      iex> now.hour == hour
      true
  """
  def hour(_ctx, %{hour: hour} = _date) do
    hour
  end

  @doc """
  Returns only the minute of a datetime (0 to 59)

  ```
  The current minute is @MINUTE(NOW())
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> minute = Excellent.Callbacks.minute(%{}, now)
      iex> now.minute == minute
      true
  """
  def minute(_ctx, %{minute: minute} = _date) do
    minute
  end

  @doc """
  Returns only the month of a date (1 to 12)

  ```
  The current month is @MONTH(NOW())
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> month = Excellent.Callbacks.month(%{}, now)
      iex> now.month == month
      true
  """
  def month(_ctx, %{month: month} = _date) do
    month
  end

  @doc """
  Returns the current date time as UTC

  ```
  It is currently @NOW()
  ```

  # Example

    iex> DateTime.utc_now() == Excellent.Callbacks.now(%{})
  """
  def now(_ctx) do
    DateTime.utc_now()
  end

  @doc """
  Returns only the second of a datetime (0 to 59)

  ```
  The current second is @SECOND(NOW())
  ```

  # Example

      iex> now = DateTime.utc_now()
      iex> second = Excellent.Callbacks.second(%{}, now)
      iex> now.second == second
      true

  """
  def second(_ctx, %{second: second} = _date) do
    second
  end

  @doc """
  Defines a time value which can be used for time arithmetic

  ```
  2 hours and 30 minutes from now is @(date.now + TIME(2, 30, 0))
  ```

  # Example

      iex> Excellent.Callbacks.time(%{}, 12, 13, 14)
      %Time{hour: 12, minute: 13, second: 14}

  """
  def time(_ctx, hours, minutes, seconds) do
    %Time{hour: hours, minute: minutes, second: seconds}
  end

  @doc """
  Converts time stored in text to an actual time

  ```
  Your appointment is at @(date.today + TIME("2:30"))
  ```

  # Example

      iex> Excellent.Callbacks.timevalue(%{}, "2:30")
      %Time{hour: 2, minute: 30, second: 0}

      iex> Excellent.Callbacks.timevalue(%{}, "2:30:55")
      %Time{hour: 2, minute: 30, second: 55}
  """
  def timevalue(_ctx, expression) do
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

  ```
  Today's date is @TODAY()
  ```

  # Example

      iex> today = Date.utc_today()
      iex> today == Excellent.Callbacks.today(%{})
      true

  """
  def today(_ctx) do
    Date.utc_today()
  end

  @doc """
  Returns the day of the week of a date (1 for Sunday to 7 for Saturday)

  ```
  Today is day no. @WEEKDAY(TODAY()) in the week
  ```

  # Example

      iex> today = DateTime.utc_now()
      iex> expected = Timex.weekday(today)
      iex> weekday = Excellent.Callbacks.weekday(%{}, today)
      iex> weekday == expected
      true
  """
  def weekday(_ctx, date) do
    Timex.weekday(date)
  end

  @doc """
  Returns only the year of a date

  ```
  The current year is @YEAR(NOW())
  ```

  # Example

      iex> %{year: year} = now = DateTime.utc_now()
      iex> year == Excellent.Callbacks.year(%{}, now)

  """
  def year(_ctx, %{year: year} = _date) do
    year
  end

  @doc """
  Returns TRUE if and only if all its arguments evaluate to TRUE

  ```
  @AND(contact.gender = "F", contact.age >= 18)
  ```

  # Example

      iex> Excellent.Callbacks.handle("and", [true, true], %{})
      true
      iex> Excellent.Callbacks.and_vargs(%{}, [true, true])
      true
      iex> Excellent.Callbacks.and_vargs(%{}, [true, false])
      false
      iex> Excellent.Callbacks.and_vargs(%{}, [false, false])
      false

  """
  def and_vargs(_ctx, arguments) do
    Enum.all?(arguments, fn
      true -> true
      _other -> false
    end)
  end

  @doc """
  Returns one value if the condition evaluates to TRUE, and another value if it evaluates to FALSE

  ```
  Dear @IF(contact.gender = "M", "Sir", "Madam")
  ```

  # Example

      iex> Excellent.Callbacks.handle("if", [true, "Yes", "No"], %{})
      "Yes"
      iex> Excellent.Callbacks.handle("if", [false, "Yes", "No"], %{})
      "No"
  """
  def if_(_ctx, condition, yes, no) do
    if(condition, do: yes, else: no)
  end

  @doc """
  Returns TRUE if any argument is TRUE

  ```
  @OR(contact.state = "GA", contact.state = "WA", contact.state = "IN")
  ```

  # Example

      iex> Excellent.Callbacks.handle("or", [true, false], %{})
      true
      iex> Excellent.Callbacks.handle("or", [true, true], %{})
      true
      iex> Excellent.Callbacks.handle("or", [false, false], %{})
      false
  """
  def or_vargs(_ctx, arguments) do
    Enum.any?(arguments, fn
      true -> true
      _anything_else -> false
    end)
  end

  @doc """
  Returns the absolute value of a number

  ```
  The absolute value of -1 is @ABS(-1)
  ```

  # Example

      iex> Excellent.Callbacks.abs(%{}, -1)
      1
  """
  def abs(_ctx, number) do
    abs(number)
  end

  @doc """
  Returns the maximum value of all arguments

  ```
  Please complete at most @MAX(flow.questions, 10) questions
  ```

  # Example

      iex> Excellent.Callbacks.handle("max", [1, 2, 3], %{})
      3
  """
  def max_vargs(_ctx, arguments) do
    Enum.max(arguments)
  end

  @doc """
  Returns the minimum value of all arguments

  ```
  Please complete at least @MIN(flow.questions, 10) questions
  ```

  #  Example

      iex> Excellent.Callbacks.handle("min", [1, 2, 3], %{})
      1
  """
  def min_vargs(_ctx, arguments) do
    Enum.min(arguments)
  end

  @doc """
  Returns the result of a number raised to a power - equivalent to the ^ operator

  ```
  2 to the power of 3 is @POWER(2, 3)
  ```
  """
  def power(_ctx, a, b) do
    :math.pow(a, b)
  end

  @doc """
  Returns the sum of all arguments, equivalent to the + operator

  ```
  You have @SUM(contact.reports, contact.forms) reports and forms
  ```

  # Example

      iex> Excellent.Callbacks.handle("sum", [1, 2, 3], %{})
      6

  """
  def sum_vargs(_ctx, arguments) do
    Enum.sum(arguments)
  end

  @doc """
  Returns the character specified by a number

  ```
  As easy as @CHAR(65), @CHAR(66), @CHAR(67)
  ```

  # Example

      iex> Excellent.Callbacks.char(%{}, 65)
      "A"

  """
  def char(_ctx, code) do
    <<code>>
  end

  @doc """
  Removes all non-printable characters from a text string

  ```
  You entered @CLEAN(step.value)
  ```

  # Example

      iex> Excellent.Callbacks.clean(%{}, <<65, 0, 66, 0, 67>>)
      "ABC"
  """
  def clean(_ctx, binary) do
    binary
    |> String.graphemes()
    |> Enum.filter(&String.printable?/1)
    |> Enum.join("")
  end

  @doc """
  Returns a numeric code for the first character in a text string

  ```
  The numeric code of A is @CODE("A")
  ```

  # Example

      iex> Excellent.Callbacks.code(%{}, "A")
      65
  """
  def code(_ctx, <<code>>) do
    code
  end

  @doc """
  Joins text strings into one text string

  ```
  Your name is @CONCATENATE(contact.first_name, " ", contact.last_name)
  ```

  # Example

      iex> Excellent.Callbacks.handle("concatenate", ["name", " ", "surname"], %{})
      "name surname"
  """
  def concatenate_vargs(_ctx, arguments) do
    Enum.join(arguments, "")
  end

  @doc """
  Formats the given number in decimal format using a period and commas

  ```
  You have @FIXED(contact.balance, 2) in your account
  ```

  # Example

      iex> Excellent.Callbacks.fixed(%{}, 4.209922, 2, false)
      "4.21"
      iex> Excellent.Callbacks.fixed(%{}, 4000.424242, 4, true)
      "4,000.4242"
      iex> Excellent.Callbacks.fixed(%{}, 3.7979, 2, false)
      "3.80"
      iex> Excellent.Callbacks.fixed(%{}, 3.7979, 2)
      "3.80"

  """
  def fixed(_ctx, number, precision, no_commas \\ false)

  def fixed(_ctx, number, precision, true) do
    Number.Delimit.number_to_delimited(number,
      precision: precision,
      delimiter: ",",
      separator: "."
    )
  end

  def fixed(_ctx, number, precision, false) do
    Number.Delimit.number_to_delimited(number, precision: precision)
  end

  @doc """
  Returns the first characters in a text string

  ```
  You entered PIN @LEFT(step.value, 4)
  ```

  # Example

      iex> Excellent.Callbacks.left(%{}, "foobar", 4)
      "foob"
  """
  def left(_ctx, binary, size) do
    binary_part(binary, 0, size)
  end

  @doc """
  Returns the number of characters in a text string

  ```
  You entered @LEN(step.value) characters
  ```

  # Example

      iex> Excellent.Callbacks.len(%{}, "foo")
      3
      iex> Excellent.Callbacks.len(%{}, "zoë")
      3
  """
  def len(_ctx, binary) do
    String.length(binary)
  end

  @doc """
  Converts a text string to lowercase

  ````
  Welcome @LOWER(contact)
  ```

  # Example

      iex> Excellent.Callbacks.lower(%{}, "Foo Bar")
      "foo bar"

  """
  def lower(_ctx, binary) do
    String.downcase(binary)
  end

  @doc """
  Capitalizes the first letter of every word in a text string

  ```
  Your name is @PROPER(contact)
  ```

  # Example

      iex> Excellent.Callbacks.proper(%{}, "foo bar")
      "Foo Bar"
  """
  def proper(_ctx, binary) do
    binary
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Repeats text a given number of times

  ```
  Stars! @REPT("*", 10)
  ```

  # Example

      iex> Excellent.Callbacks.rept(%{}, "*", 10)
      "**********"
  """
  def rept(_ctx, value, amount) do
    String.duplicate(value, amount)
  end

  @doc """
  Returns the last characters in a text string

  ```
  Your input ended with ...@RIGHT(step.value, 3)
  ```

  # Example

      iex> Excellent.Callbacks.right(%{}, "testing", 3)
      "ing"

  """
  def right(_ctx, binary, size) do
    String.slice(binary, -size, size)
  end

  @doc """
  Substitutes new_text for old_text in a text string. If instance_num is given, then only that instance will be substituted

  ```
  @SUBSTITUTE(step.value, "can't", "can")
  ```

  # Example

    iex> Excellent.Callbacks.substitute(%{}, "I can't", "can't", "can do")
    "I can do"

  """
  def substitute(%{}, subject, pattern, replacement) do
    String.replace(subject, pattern, replacement)
  end

  @doc """
  Returns the unicode character specified by a number

  ```
  As easy as @UNICHAR(65), @UNICHAR(66) , @UNICHAR(67)
  ```

  # Example

    iex> Excellent.Callbacks.unichar(%{}, 65)
    "A"
    iex> Excellent.Callbacks.unichar(%{}, 233)
    "é"

  """
  def unichar(_ctx, code) do
    <<code::utf8>>
  end

  @doc """
  Returns a numeric code for the first character in a text string

  ```
  The numeric code of A is @UNICODE("A")
  ```

  # Example

      iex> Excellent.Callbacks.unicode(%{}, "A")
      65
      iex> Excellent.Callbacks.unicode(%{}, "é")
      233
  """
  def unicode(_ctx, <<code::utf8>>) do
    code
  end

  @doc """
  Converts a text string to uppercase

  ```
  WELCOME @UPPER(contact)!!
  ```

  # Example

      iex> Excellent.Callbacks.upper(%{}, "foo")
      "FOO"
  """
  def upper(_ctx, binary) do
    String.upcase(binary)
  end

  @doc """
  Returns the first word in the given text - equivalent to WORD(text, 1)

  ```
  The first word you entered was @FIRST_WORD(step.value)
  ```

  # Example

      iex> Excellent.Callbacks.first_word(%{}, "foo bar baz")
      "foo"

  """
  def first_word(_ctx, binary) do
    [word | _] = String.split(binary, " ")
    word
  end

  @doc """
  Formats a number as a percentage

  ```
  You've completed @PERCENT(contact.reports_done / 10) reports
  ```

  # Example

      iex> Excellent.Callbacks.percent(%{}, 2/10)
      "20%"
      iex> Excellent.Callbacks.percent(%{}, "0.2")
      "20%"
      iex> Excellent.Callbacks.percent(%{}, Decimal.new("0.2"))
      "20%"
  """
  def percent(ctx, float) when is_float(float) do
    percent(ctx, Decimal.from_float(float))
  end

  def percent(ctx, binary) when is_binary(binary) do
    percent(ctx, Decimal.new(binary))
  end

  def percent(_ctx, decimal) do
    Number.Percentage.number_to_percentage(Decimal.mult(decimal, 100), precision: 0)
  end

  @doc """
  Formats digits in text for reading in TTS

  ```
  Your number is @READ_DIGITS(contact.tel_e164)
  ```

  # Example

      iex> Excellent.Callbacks.read_digits(%{}, "+271")
      "plus two seven one"

  """
  def read_digits(_ctx, binary) do
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
    |> String.graphemes()
    |> Enum.map(fn grapheme -> Map.get(map, grapheme, nil) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
  end

  @doc """
  Removes the first word from the given text. The remaining text will be unchanged

  ```
  You entered @REMOVE_FIRST_WORD(step.value)
  ```

  # Example

      iex> Excellent.Callbacks.remove_first_word(%{}, "foo bar")
      "bar"
      iex> Excellent.Callbacks.remove_first_word(%{}, "foo-bar", "-")
      "bar"
  """
  def remove_first_word(_ctx, binary, separator \\ " ")

  def remove_first_word(_ctx, binary, separator) do
    tl(String.split(binary, separator)) |> Enum.join(separator)
  end

  @doc """
  Extracts the nth word from the given text string. If stop is a negative number,
  then it is treated as count backwards from the end of the text. If by_spaces is
  specified and is TRUE then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well

  # Example

      iex> Excellent.Callbacks.word(%{}, "hello cow-boy", 2)
      "cow"
      iex> Excellent.Callbacks.word(%{}, "hello cow-boy", 2, true)
      "cow-boy"
      iex> Excellent.Callbacks.word(%{}, "hello cow-boy", -1)
      "boy"

  """
  def word(ctx, binary, n, by_spaces \\ false)

  def word(_ctx, binary, n, by_spaces) do
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)
    parts = String.split(binary, splitter)

    # This slicing seems off.
    [part] =
      cond do
        n < 0 -> Enum.slice(parts, n, 1)
        true -> Enum.slice(parts, n - 1, 1)
      end

    part
  end

  @doc """
  Returns the number of words in the given text string. If by_spaces is specified and is TRUE then the function splits the text into words only by spaces. Otherwise the text is split by punctuation characters as well

  ```
  You entered @WORD_COUNT(step.value) words
  ```

  # Example

      iex> Excellent.Callbacks.word_count(%{}, "hello cow-boy")
      3
      iex> Excellent.Callbacks.word_count(%{}, "hello cow-boy", true)
      2
  """
  def word_count(ctx, binary, by_spaces \\ false)

  def word_count(_ctx, binary, by_spaces) do
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    binary
    |> String.split(splitter)
    |> Enum.count()
  end

  @doc """
  Extracts a substring of the words beginning at start, and up to but not-including stop.
  If stop is omitted then the substring will be all words from start until the end of the text.
  If stop is a negative number, then it is treated as count backwards from the end of the text.
  If by_spaces is specified and is TRUE then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well

  # Example

      iex> Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2, 4)
      "expressions are"
      iex> Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2)
      "expressions are fun"
      iex> Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 1, -2)
      "RapidPro expressions"
      iex> Excellent.Callbacks.word_slice(%{}, "RapidPro expressions are fun", -1)
      "fun"
  """
  def word_slice(_ctx, binary, start) when start > 0 do
    parts =
      binary
      |> String.split(" ")

    parts
    |> Enum.slice(start - 1, length(parts))
    |> Enum.join(" ")
  end

  def word_slice(_ctx, binary, start) when start < 0 do
    parts =
      binary
      |> String.split(" ")

    parts
    |> Enum.slice(start..length(parts))
    |> Enum.join(" ")
  end

  def word_slice(_ctx, binary, start, stop, by_spaces \\ false)

  def word_slice(_ctx, binary, start, stop, by_spaces) when stop > 0 do
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    binary
    |> String.split(splitter)
    |> Enum.slice((start - 1)..(stop - 2))
    |> Enum.join(" ")
  end

  def word_slice(_ctx, binary, start, stop, by_spaces) when stop < 0 do
    splitter = if(by_spaces, do: " ", else: @punctuation_pattern)

    binary
    |> String.split(splitter)
    |> Enum.slice((start - 1)..(stop - 1))
    |> Enum.join(" ")
  end
end
