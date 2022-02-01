defmodule Expression.Callbacks do
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

  @reserved_words ~w[and if or]

  @punctuation_pattern ~r/\s*[,:;!?.-]\s*|\s/

  @doc """
  Convert a string function name into an atom meant to handle
  that function

  Reserved words such as `and`, `if`, and `or` are automatically suffixed
  with an `_` underscore.
  """
  def atom_function_name(function_name) when function_name in @reserved_words,
    do: atom_function_name("#{function_name}_")

  def atom_function_name(function_name) do
    String.to_atom(function_name)
  end

  @doc """
  Handle a function call while evaluating the AST.

  Handlers in this module are either:

  1. The function name as is
  2. The function name with an underscore suffix if the function name is a reserved word
  3. The function name suffixed with `_vargs` if the takes a variable set of arguments
  """
  @spec handle(function_name :: binary, arguments :: [any], context :: map) ::
          {:ok, any} | {:error, :not_implemented}
  def handle(function_name, arguments, context) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    cond do
      # Check if the exact function signature has been implemented
      function_exported?(__MODULE__, exact_function_name, length(arguments) + 1) ->
        {:ok, apply(__MODULE__, exact_function_name, [context] ++ arguments)}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(__MODULE__, vargs_function_name, 2) ->
        {:ok, apply(__MODULE__, vargs_function_name, [context, arguments])}

      # Otherwise fail
      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  @doc """
  Defines a new date value

  ```
  This is a date @DATE(2012, 12, 25)
  ```

  # Example

      iex> to_string(Expression.Callbacks.date(%{}, 2012, 12, 25))
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

      iex> date = Expression.Callbacks.date(%{}, 2020, 12, 20)
      iex> Expression.Callbacks.datevalue(%{}, date)
      "2020-12-20 00:00:00"
      iex> Expression.Callbacks.datevalue(%{}, date, "%Y-%m-%d")
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
      iex> day = Expression.Callbacks.day(%{}, now)
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
      iex> date = Expression.Callbacks.edate(%{}, now, 1)
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
      iex> hour = Expression.Callbacks.hour(%{}, now)
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
      iex> minute = Expression.Callbacks.minute(%{}, now)
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
      iex> month = Expression.Callbacks.month(%{}, now)
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

    iex> DateTime.utc_now() == Expression.Callbacks.now(%{})
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
      iex> second = Expression.Callbacks.second(%{}, now)
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

      iex> Expression.Callbacks.time(%{}, 12, 13, 14)
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

      iex> Expression.Callbacks.timevalue(%{}, "2:30")
      %Time{hour: 2, minute: 30, second: 0}

      iex> Expression.Callbacks.timevalue(%{}, "2:30:55")
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
      iex> today == Expression.Callbacks.today(%{})
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
      iex> weekday = Expression.Callbacks.weekday(%{}, today)
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
      iex> year == Expression.Callbacks.year(%{}, now)

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

      iex> Expression.Callbacks.handle("and", [true, true], %{})
      {:ok, true}
      iex> Expression.Callbacks.and_vargs(%{}, [true, true])
      true
      iex> Expression.Callbacks.and_vargs(%{}, [true, false])
      false
      iex> Expression.Callbacks.and_vargs(%{}, [false, false])
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

      iex> Expression.Callbacks.handle("if", [true, "Yes", "No"], %{})
      {:ok, "Yes"}
      iex> Expression.Callbacks.handle("if", [false, "Yes", "No"], %{})
      {:ok, "No"}
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

      iex> Expression.Callbacks.handle("or", [true, false], %{})
      {:ok, true}
      iex> Expression.Callbacks.handle("or", [true, true], %{})
      {:ok, true}
      iex> Expression.Callbacks.handle("or", [false, false], %{})
      {:ok, false}
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

      iex> Expression.Callbacks.abs(%{}, -1)
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

      iex> Expression.Callbacks.handle("max", [1, 2, 3], %{})
      {:ok, 3}
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

      iex> Expression.Callbacks.handle("min", [1, 2, 3], %{})
      {:ok, 1}
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

      iex> Expression.Callbacks.handle("sum", [1, 2, 3], %{})
      {:ok, 6}

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

      iex> Expression.Callbacks.char(%{}, 65)
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

      iex> Expression.Callbacks.clean(%{}, <<65, 0, 66, 0, 67>>)
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

      iex> Expression.Callbacks.code(%{}, "A")
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

      iex> Expression.Callbacks.handle("concatenate", ["name", " ", "surname"], %{})
      {:ok, "name surname"}
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

      iex> Expression.Callbacks.fixed(%{}, 4.209922, 2, false)
      "4.21"
      iex> Expression.Callbacks.fixed(%{}, 4000.424242, 4, true)
      "4,000.4242"
      iex> Expression.Callbacks.fixed(%{}, 3.7979, 2, false)
      "3.80"
      iex> Expression.Callbacks.fixed(%{}, 3.7979, 2)
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

      iex> Expression.Callbacks.left(%{}, "foobar", 4)
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

      iex> Expression.Callbacks.len(%{}, "foo")
      3
      iex> Expression.Callbacks.len(%{}, "zoë")
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

      iex> Expression.Callbacks.lower(%{}, "Foo Bar")
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

      iex> Expression.Callbacks.proper(%{}, "foo bar")
      "Foo Bar"
  """
  def proper(_ctx, binary) do
    binary
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Repeats text a given number of times

  ```
  Stars! @REPT("*", 10)
  ```

  # Example

      iex> Expression.Callbacks.rept(%{}, "*", 10)
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

      iex> Expression.Callbacks.right(%{}, "testing", 3)
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

    iex> Expression.Callbacks.substitute(%{}, "I can't", "can't", "can do")
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

    iex> Expression.Callbacks.unichar(%{}, 65)
    "A"
    iex> Expression.Callbacks.unichar(%{}, 233)
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

      iex> Expression.Callbacks.unicode(%{}, "A")
      65
      iex> Expression.Callbacks.unicode(%{}, "é")
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

      iex> Expression.Callbacks.upper(%{}, "foo")
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

      iex> Expression.Callbacks.first_word(%{}, "foo bar baz")
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

      iex> Expression.Callbacks.percent(%{}, 2/10)
      "20%"
      iex> Expression.Callbacks.percent(%{}, "0.2")
      "20%"
      iex> Expression.Callbacks.percent(%{}, Decimal.new("0.2"))
      "20%"
  """
  @spec percent(Expression.Context.t(), float) :: binary
  def percent(ctx, float) when is_float(float) do
    percent(ctx, Decimal.from_float(float))
  end

  @spec percent(Expression.Context.t(), binary) :: binary
  def percent(ctx, binary) when is_binary(binary) do
    percent(ctx, Decimal.new(binary))
  end

  @spec percent(Expression.Context.t(), Decimal.t()) :: binary
  def percent(_ctx, decimal) do
    Number.Percentage.number_to_percentage(Decimal.mult(decimal, 100), precision: 0)
  end

  @doc """
  Formats digits in text for reading in TTS

  ```
  Your number is @READ_DIGITS(contact.tel_e164)
  ```

  # Example

      iex> Expression.Callbacks.read_digits(%{}, "+271")
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

      iex> Expression.Callbacks.remove_first_word(%{}, "foo bar")
      "bar"
      iex> Expression.Callbacks.remove_first_word(%{}, "foo-bar", "-")
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

      iex> Expression.Callbacks.word(%{}, "hello cow-boy", 2)
      "cow"
      iex> Expression.Callbacks.word(%{}, "hello cow-boy", 2, true)
      "cow-boy"
      iex> Expression.Callbacks.word(%{}, "hello cow-boy", -1)
      "boy"

  """
  def word(ctx, binary, n, by_spaces \\ false)

  def word(_ctx, binary, n, by_spaces) do
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
  Returns the number of words in the given text string. If by_spaces is specified and is TRUE then the function splits the text into words only by spaces. Otherwise the text is split by punctuation characters as well

  ```
  You entered @WORD_COUNT(step.value) words
  ```

  # Example

      iex> Expression.Callbacks.word_count(%{}, "hello cow-boy")
      3
      iex> Expression.Callbacks.word_count(%{}, "hello cow-boy", true)
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

      iex> Expression.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2, 4)
      "expressions are"
      iex> Expression.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 2)
      "expressions are fun"
      iex> Expression.Callbacks.word_slice(%{}, "RapidPro expressions are fun", 1, -2)
      "RapidPro expressions"
      iex> Expression.Callbacks.word_slice(%{}, "RapidPro expressions are fun", -1)
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

  @doc """
  Returns TRUE if the argument is a number.

  ```
  @ISNUMBER(contact.age) will return TRUE if the contact's age is a number.
  ```

  # Example

      iex> Expression.Callbacks.isnumber(%{}, 1)
      true
      iex> Expression.Callbacks.isnumber(%{}, 1.0)
      true
      iex> Expression.Callbacks.isnumber(%{}, Decimal.new("1.0"))
      true
      iex> Expression.Callbacks.isnumber(%{}, "1.0")
      true
      iex> Expression.Callbacks.isnumber(%{}, "a")
      false

  """
  def isnumber(_ctx, var) when is_float(var) or is_integer(var), do: true

  def isnumber(_ctx, %{__struct__: Decimal}), do: true

  def isnumber(_ctx, var) when is_binary(var) do
    Decimal.new(var)
    true
  rescue
    Decimal.Error ->
      false
  end

  def isnumber(_ctx, _var), do: false

  @doc """
  Returns TRUE if the argument is a boolean.

  ```
  @ISBOOL(block.value) will return TRUE if the block returned a boolean value.
  ```

  # Example

      iex> Expression.Callbacks.isbool(%{}, true)
      true
      iex> Expression.Callbacks.isbool(%{}, false)
      true
      iex> Expression.Callbacks.isbool(%{}, 1)
      false
      iex> Expression.Callbacks.isbool(%{}, 0)
      false
      iex> Expression.Callbacks.isbool(%{}, "true")
      false
      iex> Expression.Callbacks.isbool(%{}, "false")
      false
  """
  def isbool(_ctx, var) when var in [true, false], do: true
  def isbool(_ctx, _var), do: false

  @doc """
  Returns TRUE if the argument is a string.

  ```
  @ISSTRING(contact.name) will return TRUE if the contact's name is a string.
  ```

  # Example

      iex> Expression.Callbacks.isstring(%{}, "hello")
      true
      iex> Expression.Callbacks.isstring(%{}, false)
      false
      iex> Expression.Callbacks.isstring(%{}, 1)
      false
      iex> Expression.Callbacks.isstring(%{}, Decimal.new("1.0"))
      false
  """
  def isstring(_ctx, binary), do: is_binary(binary)

  defp search_words(haystack, words) do
    patterns =
      words
      |> String.split(" ")
      |> Enum.map(&Regex.escape/1)
      |> Enum.map(&Regex.compile!(&1, "i"))

    results =
      patterns
      |> Enum.map(&Regex.run(&1, haystack))
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

  ```
  @(has_all_words("the quick brown FOX", "the fox")) → true
  @(has_all_words("the quick brown fox", "red fox")) → false
  ```

  NOTE: the flowspec supports `.match` which isn't support here yet.

  ```
  @(has_all_words("the quick brown FOX", "the fox").match) → the FOX
  ```

  # Example

    iex> Expression.Callbacks.has_all_words(%{}, "the quick brown FOX", "the fox")
    {:ok, true}
    iex> Expression.Callbacks.has_all_words(%{}, "the quick brown FOX", "red fox")
    {:ok, false}

  """
  def has_all_words(_ctx, haystack, words) do
    {patterns, results} = search_words(haystack, words)
    # future match result: Enum.join(results, " ")
    {:ok, Enum.count(patterns) == Enum.count(results)}
  end

  @doc """
  Tests whether any of the words are contained in the text

  Only one of the words needs to match and it may appear more than once.

  ```
  @(has_any_word("The Quick Brown Fox", "fox quick")) → true
  ```

  Unsupported:

  ```
  @(has_any_word("The Quick Brown Fox", "fox quick").match) → Quick Fox
  @(has_any_word("The Quick Brown Fox", "red fox").match) → Fox
  ```

  # Example

    iex> Expression.Callbacks.has_any_word(%{}, "The Quick Brown Fox", "fox quick")
    {:ok, true}
    iex> Expression.Callbacks.has_any_word(%{}, "The Quick Brown Fox", "yellow")
    {:ok, false}

  """
  def has_any_word(_ctx, haystack, words) do
    {_patterns, results} = search_words(haystack, words)

    # future match result Enum.join(results, " ")
    {:ok, Enum.any?(results)}
  end

  @doc """
  Tests whether text starts with beginning

  Both text values are trimmed of surrounding whitespace, but otherwise matching is
  strict without any tokenization.

  Supported:

  ```
  @(has_beginning("The Quick Brown", "the quick")) → true
  @(has_beginning("The Quick Brown", "the   quick")) → false
  @(has_beginning("The Quick Brown", "quick brown")) → false
  ```

  Unsupported

  ```
  @(has_beginning("The Quick Brown", "the quick").match) → The Quick
  ```

  # Example

    iex> Expression.Callbacks.has_beginning(%{}, "The Quick Brown", "the quick")
    {:ok, true}
    iex> Expression.Callbacks.has_beginning(%{}, "The Quick Brown", "the    quick")
    {:ok, false}
    iex> Expression.Callbacks.has_beginning(%{}, "The Quick Brown", "quick brown")
    {:ok, false}

  """
  def has_beginning(_ctx, text, beginning) do
    case Regex.run(~r/^#{Regex.escape(beginning)}/i, text) do
      # future match result: first
      [_first | _remainder] -> {:ok, true}
      nil -> {:ok, false}
    end
  end

  defp extract_dateish(expression) do
    expression = Regex.replace(~r/[a-z]/u, expression, "")

    case DateTimeParser.parse_date(expression) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  @doc """
  Tests whether `expression` contains a date formatted according to our environment

  This is very naively implemented with a regular expression.

  Supported:

  ```
  @(has_date("the date is 15/01/2017")) → true
  @(has_date("there is no date here, just a year 2017")) → false
  ```

  Unsupported:

  ```
  @(has_date("the date is 15/01/2017").match) → 2017-01-15T13:24:30.123456-05:00
  ```

  # Example

    iex> Expression.Callbacks.has_date(%{}, "the date is 15/01/2017")
    {:ok, true}
    iex> Expression.Callbacks.has_date(%{}, "there is no date here, just a year 2017")
    {:ok, false}

  """
  def has_date(_, expression) do
    date = extract_dateish(expression)
    # future match result: date
    {:ok, !!date}
  end

  @doc """
  Tests whether `expression` is a date equal to `date_string`

  Supported:

  ```
  @(has_date_eq("the date is 15/01/2017", "2017-01-15")) → true
  @(has_date_eq("there is no date here, just a year 2017", "2017-06-01")) → false
  @(has_date_eq("there is no date here, just a year 2017", "not date")) → ERROR
  ```

  Not supported:

  ```
  @(has_date_eq("the date is 15/01/2017", "2017-01-15").match) → 2017-01-15T13:24:30.123456-05:00
  @(has_date_eq("the date is 15/01/2017 15:00", "2017-01-15").match) → 2017-01-15T15:00:00.000000-05:00
  ```

  # Examples

    iex> Expression.Callbacks.has_date_eq(%{}, "the date is 15/01/2017", "2017-01-15")
    {:ok, true}
    iex> Expression.Callbacks.has_date_eq(%{}, "there is no date here, just a year 2017", "2017-01-15")
    {:ok, false}
  """
  def has_date_eq(_ctx, expression, date_string) do
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)
    # Future match result: found_date
    {:ok, found_date == test_date}
  end

  @doc """
  Tests whether `expression` is a date after the date `date_string`

  ```
  @(has_date_gt("the date is 15/01/2017", "2017-01-01")) → true
  @(has_date_gt("the date is 15/01/2017", "2017-03-15")) → false
  @(has_date_gt("there is no date here, just a year 2017", "2017-06-01")) → false
  @(has_date_gt("there is no date here, just a year 2017", "not date")) → ERROR
  ```

  Not supported:

  ```
  @(has_date_gt("the date is 15/01/2017", "2017-01-01").match) → 2017-01-15T13:24:30.123456-05:00
  ```

  # Example

    iex> Expression.Callbacks.has_date_gt(%{}, "the date is 15/01/2017", "2017-01-01")
    {:ok, true}
    iex> Expression.Callbacks.has_date_gt(%{}, "the date is 15/01/2017", "2017-03-15")
    {:ok, false}

  """
  def has_date_gt(_ctx, expression, date_string) do
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)
    # future match result: found_date
    {:ok, Date.compare(found_date, test_date) == :gt}
  end

  @doc """
  Tests whether `expression` contains a date before the date `date_string`

  ```
  @(has_date_lt("the date is 15/01/2017", "2017-06-01")) → true
  @(has_date_lt("there is no date here, just a year 2017", "2017-06-01")) → false
  @(has_date_lt("there is no date here, just a year 2017", "not date")) → ERROR
  ```

  Not supported:

  ```
  @(has_date_lt("the date is 15/01/2017", "2017-06-01").match) → 2017-01-15T13:24:30.123456-05:00
  ```

  # Example

    iex> Expression.Callbacks.has_date_lt(%{}, "the date is 15/01/2017", "2017-06-01")
    {:ok, true}
    iex> Expression.Callbacks.has_date_lt(%{}, "the date is 15/01/2021", "2017-03-15")
    {:ok, false}

  """
  def has_date_lt(_ctx, expression, date_string) do
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)
    # future match result: found_date
    {:ok, Date.compare(found_date, test_date) == :lt}
  end

  @doc """
  Tests whether an email is contained in text

  ```
  @(has_email("my email is foo1@bar.com, please respond")) → true
  @(has_email("i'm not sharing my email")) → false
  ```

  Not supported:

  ```
  @(has_email("my email is foo1@bar.com, please respond").match) → foo1@bar.com
  @(has_email("my email is <foo@bar2.com>").match) → foo@bar2.com
  ```

  # Example:

    iex> Expression.Callbacks.has_email(%{}, "my email is foo1@bar.com, please respond")
    {:ok, true}
    iex> Expression.Callbacks.has_email(%{}, "i'm not sharing my email")
    {:ok, false}

  """
  def has_email(_ctx, expression) do
    case Regex.run(~r/([a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+)/, expression) do
      # future match result: match
      [_match | _] -> {:ok, true}
      nil -> {:ok, false}
    end
  end

  @doc """
  Returns whether the contact is part of group with the passed in UUID

  ```
  @(has_group(array(), "97fe7029-3a15-4005-b0c7-277b884fc1d5")) → false
  ```

  Not supported:

  ```
  @(has_group(contact.groups, "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d").match) → {name: Testers, uuid: b7cf0d83-f1c9-411c-96fd-c511a4cfa86d}
  ```

  # Example:

    iex> contact = %{
    ...>   "groups" => [%{
    ...>     "uuid" => "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d"
    ...>   }]
    ...> }
    iex> Expression.Callbacks.has_group(%{}, contact["groups"], "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d")
    {:ok, true}
    iex> Expression.Callbacks.has_group(%{}, contact["groups"], "00000000-0000-0000-0000-000000000000")
    {:ok, false}

  """
  def has_group(_ctx, groups, uuid) do
    group = Enum.find(groups, nil, &(&1["uuid"] == uuid))
    # future match result: group
    {:ok, !!group}
  end

  defp extract_numberish(expression) do
    with [match] <-
           Regex.run(~r/([0-9]+\.?[0-9]+)/u, replace_arabic_numerals(expression), capture: :first),
         {decimal, ""} <- Decimal.parse(match) do
      decimal
    else
      # Regex can return nil
      nil -> nil
      # Decimal parsing can return :error
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

  defp parse_decimal(float) when is_float(float), do: Decimal.from_float(float)

  defp parse_decimal(number) when is_number(number), do: Decimal.new(number)

  defp parse_decimal(binary) when is_binary(binary) do
    case Decimal.parse(binary) do
      {decimal, ""} -> decimal
      :error -> :error
    end
  end

  @doc """
  Tests whether `expression` contains a number

  ```
  @(has_number("the number is 42")) → true
  @(has_number("the number is forty two")) → false
  ```

  Not supported:

  ```
  @(has_number("the number is 42").match) → 42
  @(has_number("العدد ٤٢").match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number(%{}, "the number is 42 and 5")
    iex> {:ok, true} = Expression.Callbacks.has_number(%{}, "العدد ٤٢")
    iex> {:ok, true} = Expression.Callbacks.has_number(%{}, "٠.٥")
    iex> {:ok, true} = Expression.Callbacks.has_number(%{}, "0.6")

  """
  def has_number(_ctx, expression) do
    number = extract_numberish(expression)
    # future match result: number
    {:ok, !!number}
  end

  @doc """
  Tests whether `expression` contains a number equal to the value

  ```
  @(has_number_eq("the number is 42", 42)) → true
  @(has_number_eq("the number is 42", 40)) → false
  @(has_number_eq("the number is not there", 40)) → false
  @(has_number_eq("the number is not there", "foo")) → ERROR
  ```

  Not supported:

  ```
  @(has_number_eq("the number is 42", 42).match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number_eq(%{}, "the number is 42", 42)
    iex> {:ok, true} = Expression.Callbacks.has_number_eq(%{}, "the number is 42", 42.0)
    iex> {:ok, true} = Expression.Callbacks.has_number_eq(%{}, "the number is 42", "42")
    iex> {:ok, true} = Expression.Callbacks.has_number_eq(%{}, "the number is 42.0", "42")
    iex> {:ok, false} = Expression.Callbacks.has_number_eq(%{}, "the number is 40", "42")
    iex> {:ok, false} = Expression.Callbacks.has_number_eq(%{}, "the number is 40", "foo")
    iex> {:ok, false} = Expression.Callbacks.has_number_eq(%{}, "four hundred", "foo")

  """
  def has_number_eq(_ctx, expression, decimal) do
    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      {:ok, Decimal.eq?(number, decimal)}
    else
      nil -> {:ok, false}
      :error -> {:ok, false}
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than min

  ```
  @(has_number_gt("the number is 42", 40)) → true
  @(has_number_gt("the number is 42", 42)) → false
  @(has_number_gt("the number is not there", 40)) → false
  @(has_number_gt("the number is not there", "foo")) → ERROR
  ```

  Not supported:

  ```
  @(has_number_gt("the number is 42", 40).match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number_gt(%{}, "the number is 42", 40)
    iex> {:ok, true} = Expression.Callbacks.has_number_gt(%{}, "the number is 42", 40.0)
    iex> {:ok, true} = Expression.Callbacks.has_number_gt(%{}, "the number is 42", "40")
    iex> {:ok, true} = Expression.Callbacks.has_number_gt(%{}, "the number is 42.0", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_gt(%{}, "the number is 40", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_gt(%{}, "the number is 40", "foo")
    iex> {:ok, false} = Expression.Callbacks.has_number_gt(%{}, "four hundred", "foo")
  """
  def has_number_gt(_ctx, expression, decimal) do
    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      {:ok, Decimal.gt?(number, decimal)}
    else
      nil -> {:ok, false}
      :error -> {:ok, false}
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than or equal to min

  ```
  @(has_number_gte("the number is 42", 42)) → true
  @(has_number_gte("the number is 42", 45)) → false
  @(has_number_gte("the number is not there", 40)) → false
  @(has_number_gte("the number is not there", "foo")) → ERROR
  ```

  Not supported:

  ```
  @(has_number_gte("the number is 42", 42).match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number_gte(%{}, "the number is 42", 42)
    iex> {:ok, true} = Expression.Callbacks.has_number_gte(%{}, "the number is 42", 42.0)
    iex> {:ok, true} = Expression.Callbacks.has_number_gte(%{}, "the number is 42", "42")
    iex> {:ok, false} = Expression.Callbacks.has_number_gte(%{}, "the number is 42.0", "45")
    iex> {:ok, false} = Expression.Callbacks.has_number_gte(%{}, "the number is 40", "45")
    iex> {:ok, false} = Expression.Callbacks.has_number_gte(%{}, "the number is 40", "foo")
    iex> {:ok, false} = Expression.Callbacks.has_number_gte(%{}, "four hundred", "foo")
  """
  def has_number_gte(_ctx, expression, decimal) do
    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      {:ok, Decimal.gt?(number, decimal) || Decimal.eq?(number, decimal)}
    else
      nil -> {:ok, false}
      :error -> {:ok, false}
    end
  end

  @doc """
  Tests whether `expression` contains a number less than max

  ```
  @(has_number_lt("the number is 42", 44)) → true
  @(has_number_lt("the number is 42", 40)) → false
  @(has_number_lt("the number is not there", 40)) → false
  @(has_number_lt("the number is not there", "foo")) → ERROR
  ```

  Not supported:

  ```
  @(has_number_lt("the number is 42", 44).match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number_lt(%{}, "the number is 42", 44)
    iex> {:ok, true} = Expression.Callbacks.has_number_lt(%{}, "the number is 42", 44.0)
    iex> {:ok, false} = Expression.Callbacks.has_number_lt(%{}, "the number is 42", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_lt(%{}, "the number is 42.0", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_lt(%{}, "the number is 40", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_lt(%{}, "the number is 40", "foo")
    iex> {:ok, false} = Expression.Callbacks.has_number_lt(%{}, "four hundred", "foo")
  """
  def has_number_lt(_ctx, expression, decimal) do
    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      {:ok, Decimal.lt?(number, decimal)}
    else
      nil -> {:ok, false}
      :error -> {:ok, false}
    end
  end

  @doc """
  Tests whether `expression` contains a number less than or equal to max

  ```
  @(has_number_lte("the number is 42", 42)) → true
  @(has_number_lte("the number is 42", 40)) → false
  @(has_number_lte("the number is not there", 40)) → false
  @(has_number_lte("the number is not there", "foo")) → ERROR
  ```

  Not supported:

  ```
  @(has_number_lte("the number is 42", 42).match) → 42
  ```

  # Example

    iex> {:ok, true} = Expression.Callbacks.has_number_lte(%{}, "the number is 42", 42)
    iex> {:ok, true} = Expression.Callbacks.has_number_lte(%{}, "the number is 42", 42.0)
    iex> {:ok, true} = Expression.Callbacks.has_number_lte(%{}, "the number is 42", "42")
    iex> {:ok, false} = Expression.Callbacks.has_number_lte(%{}, "the number is 42.0", "40")
    iex> {:ok, false} = Expression.Callbacks.has_number_lte(%{}, "the number is 40", "foo")
    iex> {:ok, false} = Expression.Callbacks.has_number_lte(%{}, "four hundred", "foo")

  """
  def has_number_lte(_ctx, expression, decimal) do
    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      {:ok, Decimal.lt?(number, decimal) || Decimal.eq?(number, decimal)}
    else
      nil -> {:ok, false}
      :error -> {:ok, false}
    end
  end

  @doc """
  Tests whether the text contains only phrase

  The phrase must be the only text in the text to match

  ```
  @(has_only_phrase("Quick Brown", "quick brown")) → true
  @(has_only_phrase("The Quick Brown Fox", "quick brown")) → false
  @(has_only_phrase("the Quick Brown fox", "")) → false
  @(has_only_phrase("", "").match) →
  @(has_only_phrase("The Quick Brown Fox", "red fox")) → false
  ```

  Not supported:

  ```
  @(has_only_phrase("Quick Brown", "quick brown").match) → Quick Brown
  ```

  # Example

    iex> Expression.Callbacks.has_only_phrase(%{}, "Quick Brown", "quick brown")
    {:ok, true}
    iex> Expression.Callbacks.has_only_phrase(%{}, "", "")
    {:ok, true}
    iex> Expression.Callbacks.has_only_phrase(%{}, "The Quick Brown Fox", "quick brown")
    {:ok, false}

  """
  def has_only_phrase(_ctx, expression, phrase) do
    case Enum.map([expression, phrase], &String.downcase/1) do
      # Future match result: expression
      [same, same] -> {:ok, true}
      _anything_else -> {:ok, false}
    end
  end

  @doc """
  Returns whether two text values are equal (case sensitive). In the case that they are, it will return the text as the match.

  ```
  @(has_only_text("foo", "foo")) → true
  @(has_only_text("foo", "FOO")) → false
  @(has_only_text("foo", "bar")) → false
  @(has_only_text("foo", " foo ")) → false
  @(has_only_text(results.webhook.category, "Failure")) → false
  ```

  Not supported:

  ```
  @(has_only_text("foo", "foo").match) → foo
  @(has_only_text(run.status, "completed").match) → completed
  @(has_only_text(results.webhook.category, "Success").match) → Success
  ```

  # Example

    iex> Expression.Callbacks.has_only_text(%{}, "foo", "foo")
    {:ok, true}
    iex> Expression.Callbacks.has_only_text(%{}, "", "")
    {:ok, true}
    iex> Expression.Callbacks.has_only_text(%{}, "foo", "FOO")
    {:ok, false}

  """
  def has_only_text(_ctx, expression, expression) when is_binary(expression),
    # future match result: expression
    do: {:ok, true}

  def has_only_text(_ctx, _expression, _something_else),
    # Future match result: expression
    do: {:ok, false}

  @doc """
  Tests whether `expression` matches the regex pattern

  Both text values are trimmed of surrounding whitespace and matching is case-insensitive.

  ```
  @(has_pattern("Buy cheese please", "buy (\w+)")) → true
  @(has_pattern("Sell cheese please", "buy (\w+)")) → false
  ```

  Not supported:

  ```
  @(has_pattern("Buy cheese please", "buy (\w+)").match) → Buy cheese
  @(has_pattern("Buy cheese please", "buy (\w+)").extra) → {0: Buy cheese, 1: cheese}
  ```

  # Examples

    iex> Expression.Callbacks.has_pattern(%{}, "Buy cheese please", "buy (\\\\w+)")
    {:ok, true}
    iex> Expression.Callbacks.has_pattern(%{}, "Sell cheese please", "buy (\\\\w+)")
    {:ok, false}

  """
  def has_pattern(_ctx, expression, pattern) do
    with {:ok, regex} <- Regex.compile(String.trim(pattern), "i"),
         [[_first | _remainder]] <- Regex.scan(regex, String.trim(expression), capture: :all) do
      # Future match result: first
      {:ok, true}
    else
      _ -> {:ok, false}
    end
  end

  @doc """
  Tests whether `expresssion` contains a phone number.
  The optional country_code argument specifies the country to use for parsing.

  ```
  @(has_phone("my number is +12067799294 thanks")) → true
  @(has_phone("my number is none of your business", "US")) → false
  ```

  Not supported:

  ```
  @(has_phone("my number is +12067799294").match) → +12067799294
  @(has_phone("my number is 2067799294", "US").match) → +12067799294
  @(has_phone("my number is 206 779 9294", "US").match) → +12067799294
  ```

  # Example

    iex> Expression.Callbacks.has_phone(%{}, "my number is +12067799294 thanks")
    {:ok, true}
    iex> Expression.Callbacks.has_phone(%{}, "my number is 2067799294 thanks", "US")
    {:ok, true}
    iex> Expression.Callbacks.has_phone(%{}, "my number is 206 779 9294 thanks", "US")
    {:ok, true}
    iex> Expression.Callbacks.has_phone(%{}, "my number is none of your business", "US")
    {:ok, false}

  """
  def has_phone(%{}, expression, country_code \\ "") do
    letters_removed = Regex.replace(~r/[a-z]/i, expression, "")

    case ExPhoneNumber.parse(letters_removed, country_code) do
      # Future match result: ExPhoneNumber.format(pn, :es164)
      {:ok, _pn} -> {:ok, true}
      _ -> {:ok, false}
    end
  end

  @doc """
  Tests whether phrase is contained in `expression`

  The words in the test phrase must appear in the same order with no other words in between.

  ```
  @(has_phrase("the quick brown fox", "brown fox")) → true
  @(has_phrase("the Quick Brown fox", "quick fox")) → false
  @(has_phrase("the Quick Brown fox", "").match) →
  ```

  Not supported:

  ```
  @(has_phrase("the quick brown fox", "brown fox").match) → brown fox
  ```

  # Examples

    iex> Expression.Callbacks.has_phrase(%{}, "the quick brown fox", "brown fox")
    {:ok, true}
    iex> Expression.Callbacks.has_phrase(%{}, "the quick brown fox", "quick fox")
    {:ok, false}
    iex> Expression.Callbacks.has_phrase(%{}, "the quick brown fox", "")
    {:ok, true}

  """
  def has_phrase(_ctx, expression, phrase) do
    lower_expression = String.downcase(expression)
    lower_phrase = String.downcase(phrase)
    found? = String.contains?(lower_expression, lower_phrase)
    # Future match result: phrase
    {:ok, found?}
  end

  @doc """
  Tests whether there the `expression` has any characters in it

  ```
  @(has_text("quick brown")) → true
  @(has_text("")) → false
  @(has_text(" \n")) → false
  @(has_text(contact.fields.not_set)) → false
  ```

  Not supported:

  ```
  @(has_text("quick brown").match) → quick brown
  @(has_text(123).match) → 123
  ```

  # Examples

    iex> Expression.Callbacks.has_text(%{}, "quick brown")
    {:ok, true}
    iex> Expression.Callbacks.has_text(%{}, "")
    {:ok, false}
    iex> Expression.Callbacks.has_text(%{}, " \\n")
    {:ok, false}
    iex> Expression.Callbacks.has_text(%{}, 123)
    {:ok, true}
    iex> Expression.Callbacks.has_text(%{}, nil)
    {:ok, false}
  """
  def has_text(ctx, expression) when not is_binary(expression),
    do: has_text(ctx, to_string(expression))

  def has_text(_ctx, expression) when is_binary(expression) do
    case String.trim(expression) do
      "" -> {:ok, false}
      # Future match result: any_other_binary
      _any_other_binary -> {:ok, true}
    end
  end

  @doc """
  Tests whether `expression` contains a time.

  ```
  @(has_time("the time is 10:30")) → true
  @(has_time("the time is 10:30:45").match) → 10:30:45.000000
  @(has_time("there is no time here, just the number 25")) → false
  ```

  Not supported:

  ```
  @(has_time("the time is 10:30").match) → 10:30:00.000000
  @(has_time("the time is 10 PM").match) → 22:00:00.000000
  ```

  # Examples

    iex> Expression.Callbacks.has_time(%{}, "the time is 10:30")
    {:ok, true}
    iex> Expression.Callbacks.has_time(%{}, "the time is 10:00 pm")
    {:ok, true}
    iex> Expression.Callbacks.has_time(%{}, "the time is 10:30:45")
    {:ok, true}
    iex> Expression.Callbacks.has_time(%{}, "there is no time here, just the number 25")
    {:ok, false}

  """
  def has_time(_ctx, expression) do
    case DateTimeParser.parse_time(expression) do
      # Future match result: time
      {:ok, _time} -> {:ok, true}
      _ -> {:ok, false}
    end
  end
end
