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

  @doc """
  Evaluate the given AST against the context and return the value
  after evaluation.
  """
  @spec eval!(term, map) :: term
  def eval!(ast, ctx) do
    ast
    |> Expression.Eval.eval!(ctx, __MODULE__)
    |> Expression.Eval.not_founds_as_nil()
  end

  @doc """
  Evaluate the given AST values against the context and return the
  values after evaluation.
  """
  @spec eval_args!([term], map) :: [term]
  def eval_args!(args, ctx), do: Enum.map(args, &eval!(&1, ctx))

  defmacro __using__(_opts) do
    quote do
      defdelegate handle(function_name, arguments, context), to: Expression.Callbacks
    end
  end

  @reserved_words ~w[and if or not]

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
  @callback handle(function_name :: binary, arguments :: [any], context :: map) ::
              {:ok, any} | {:error, :not_implemented}
  @spec handle(function_name :: binary, arguments :: [any], context :: map) ::
          {:ok, any} | {:error, :not_implemented}
  def handle(function_name, arguments, context) do
    case implements(function_name, arguments) do
      {:exact, function_name, _arity} ->
        {:ok, apply(__MODULE__, function_name, [context] ++ arguments)}

      {:vargs, function_name, _arity} ->
        {:ok, apply(__MODULE__, function_name, [context, arguments])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def implements(module \\ __MODULE__, function_name, arguments) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    cond do
      # Check if the exact function signature has been implemented
      function_exported?(module, exact_function_name, length(arguments) + 1) ->
        {:exact, exact_function_name, length(arguments) + 1}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(module, vargs_function_name, 2) ->
        {:vargs, vargs_function_name, 2}

      # Otherwise fail
      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  @doc """
  Defines a new date value

  # Example

      iex> Expression.evaluate!("@date(2012, 12, 15)")
      ~U[2012-12-15 00:00:00Z]

  """
  def date(ctx, year, month, day) do
    [year, month, day] = eval_args!([year, month, day], ctx)

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

  # Example

      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"Y\\")")
      ~U[2023-11-01 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"M\\")")
      ~U[2022-12-01 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"W\\")")
      ~U[2022-11-08 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"D\\")")
      ~U[2022-11-02 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"h\\")")
      ~U[2022-11-01 01:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"m\\")")
      ~U[2022-11-01 00:01:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2022, 11, 1), 1, \\"s\\")")
      ~U[2022-11-01 00:00:01Z]

  # Examples with leap year handling

      iex> Expression.evaluate!("@datetime_add(date(2020, 02, 28), 1, \\"D\\")")
      ~U[2020-02-29 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2021, 02, 28), 1, \\"D\\")")
      ~U[2021-03-01 00:00:00Z]

  # Examples with negative offsets

      iex> Expression.evaluate!("@datetime_add(date(2020, 02, 29), -1, \\"D\\")")
      ~U[2020-02-28 00:00:00Z]
      iex> Expression.evaluate!("@datetime_add(date(2021, 03, 1), -1, \\"D\\")")
      ~U[2021-02-28 00:00:00Z]

  """
  def datetime_add(ctx, datetime, offset, unit) do
    datetime = extract_dateish(eval!(datetime, ctx))
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
  Converts date stored in text to an actual date,
  using `strftime` formatting.

  It will fallback to "%Y-%m-%d %H:%M:%S" if no formatting is supplied

  # Example

      iex> Expression.evaluate!("@datevalue(date(2020, 12, 20))")
      "2020-12-20 00:00:00"
      iex> Expression.evaluate!("@datevalue(date(2020, 12, 20), '%Y-%m-%d')")
      "2020-12-20"

  """
  def datevalue(ctx, date, format) do
    [date, format] = eval!([date, format], ctx)
    Timex.format!(date, format, :strftime)
  end

  def datevalue(ctx, date) do
    Timex.format!(eval!(date, ctx), "%Y-%m-%d %H:%M:%S", :strftime)
  end

  @doc """
  Returns only the day of the month of a date (1 to 31)

  # Example

      iex> now = DateTime.utc_now()
      iex> day = Expression.evaluate!("@day(now())")
      iex> day == now.day
      true
  """
  def day(ctx, date) do
    %{day: day} = eval!(date, ctx)
    day
  end

  @doc """
  Moves a date by the given number of months

  # Example

      iex> now = DateTime.utc_now()
      iex> future = Timex.shift(now, months: 1)
      iex> date = Expression.evaluate!("@edate(now(), 1)")
      iex> future.month == date.month
      true
  """
  def edate(ctx, date, months) do
    [date, months] = eval_args!([date, months], ctx)
    date |> Timex.shift(months: months)
  end

  @doc """
  Returns only the hour of a datetime (0 to 23)

  # Example

      iex> now = DateTime.utc_now()
      iex> hour = Expression.evaluate!("@hour(now())")
      iex> now.hour == hour
      true
  """
  def hour(ctx, date) do
    %{hour: hour} = eval!(date, ctx)
    hour
  end

  @doc """
  Returns only the minute of a datetime (0 to 59)

  # Example

      iex> now = DateTime.utc_now()
      iex> minute = Expression.evaluate!("@minute(now)", %{"now" => now})
      iex> now.minute == minute
      true
  """
  def minute(ctx, date) do
    %{minute: minute} = eval!(date, ctx)
    minute
  end

  @doc """
  Returns only the month of a date (1 to 12)

  # Example

      iex> now = DateTime.utc_now()
      iex> month = Expression.evaluate!("@month(now)", %{"now" => now})
      iex> now.month == month
      true
  """
  def month(ctx, date) do
    %{month: month} = eval!(date, ctx)
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

  # Example

      iex> now = DateTime.utc_now()
      iex> second = Expression.evaluate!("@second(now)", %{"now" => now})
      iex> now.second == second
      true

  """
  def second(ctx, date) do
    %{second: second} = eval!(date, ctx)
    second
  end

  @doc """
  Defines a time value which can be used for time arithmetic

  # Example

      iex> Expression.evaluate!("@time(12, 13, 14)")
      %Time{hour: 12, minute: 13, second: 14}

  """
  def time(ctx, hours, minutes, seconds) do
    [hours, minutes, seconds] = eval_args!([hours, minutes, seconds], ctx)
    %Time{hour: hours, minute: minutes, second: seconds}
  end

  @doc """
  Converts time stored in text to an actual time

  # Example

      iex> Expression.evaluate!("@timevalue(\\"2:30\\")")
      %Time{hour: 2, minute: 30, second: 0}

      iex> Expression.evaluate!("@timevalue(\\"2:30:55\\")")
      %Time{hour: 2, minute: 30, second: 55}
  """
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

  # Example

      iex> today = DateTime.utc_now()
      iex> expected = Timex.weekday(today)
      iex> weekday = Expression.evaluate!("@weekday(today)", %{"today" => today})
      iex> weekday == expected
      true
  """
  def weekday(ctx, date) do
    Timex.weekday(eval!(date, ctx))
  end

  @doc """
  Returns only the year of a date


  # Example

      iex> %{year: year} = now = DateTime.utc_now()
      iex> year == Expression.evaluate!("@year(now)", %{"now" => now})

  """
  def year(ctx, date) do
    %{year: year} = eval!(date, ctx)
    year
  end

  @doc """
  Returns TRUE if and only if all its arguments evaluate to TRUE

  # Example

      iex> Expression.evaluate_as_boolean!("@AND(contact.gender = \\"F\\", contact.age >= 18)", %{
      iex>  "contact" => %{
      iex>    "gender" => "F",
      iex>    "age" => 32
      iex>  }})
      true

      iex> Expression.evaluate_as_boolean!("@AND(contact.gender = \\"F\\", contact.age >= 18)", %{
      iex>  "contact" => %{
      iex>    "gender" => "?",
      iex>    "age" => 32
      iex>  }})
      false
  """
  def and_vargs(ctx, arguments) do
    arguments = eval_args!(arguments, ctx)
    Enum.all?(arguments, & &1)
  end

  @doc """
  Returns FALSE if the argument supplied evaluates to truth-y

  # Example

      iex> Expression.evaluate!("@and(not(false), true)")
      true

  """
  def not_(ctx, argument) do
    !eval!(argument, ctx)
  end

  @doc """
  Returns one value if the condition evaluates to TRUE, and another value if it evaluates to FALSE

  # Example

      iex> Expression.evaluate!("@if(true, \\"Yes\\", \\"No\\")")
      "Yes"
      iex> Expression.evaluate!("@if(false, \\"Yes\\", \\"No\\")")
      "No"
  """
  def if_(ctx, condition, yes, no) do
    if(eval!(condition, ctx),
      do: eval!(yes, ctx),
      else: eval!(no, ctx)
    )
  end

  @doc """
  Returns TRUE if any argument is TRUE

  # Example

      iex> Expression.evaluate!("@or(true, false)")
      true
      iex> Expression.evaluate!("@or(true, true)")
      true
      iex> Expression.evaluate!("@or(false, false)")
      false
      iex> Expression.evaluate!("@or(false, \\"foo\\")")
      "foo"
  """
  def or_vargs(ctx, arguments) do
    arguments = eval_args!(arguments, ctx)
    Enum.reduce(arguments, fn a, b -> a || b end)
  end

  @doc """
  Returns the absolute value of a number

  # Example

      iex> Expression.evaluate_as_string!("The absolute value of -1 is @ABS(-1)")
      "The absolute value of -1 is 1"

  """
  def abs(ctx, number) do
    abs(eval!(number, ctx))
  end

  @doc """
  Returns the maximum value of all arguments

  # Example

      iex> Expression.evaluate!("@max(1, 2, 3)")
      3
  """
  def max_vargs(ctx, arguments) do
    Enum.max(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the minimum value of all arguments

  #  Example

      iex> Expression.evaluate!("@min(1, 2, 3)")
      1
  """
  def min_vargs(ctx, arguments) do
    Enum.min(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the result of a number raised to a power - equivalent to the ^ operator

  ```
  2 to the power of 3 is @POWER(2, 3)
  ```
  """
  def power(ctx, a, b) do
    [a, b] = eval_args!([a, b], ctx)
    :math.pow(a, b)
  end

  @doc """
  Returns the sum of all arguments, equivalent to the + operator

  ```
  You have @SUM(contact.reports, contact.forms) reports and forms
  ```

  # Example

      iex> Expression.evaluate!("@sum(1, 2, 3)")
      6

  """
  def sum_vargs(ctx, arguments) do
    Enum.sum(eval_args!(arguments, ctx))
  end

  @doc """
  Returns the character specified by a number


  # Example

      iex> Expression.evaluate_as_string!("As easy as @CHAR(65), @CHAR(66), @CHAR(67)")
      "As easy as A, B, C"

  """
  def char(ctx, code) do
    code = eval!(code, ctx)
    <<code>>
  end

  @doc """
  Removes all non-printable characters from a text string

  ```

  ```

  # Example

      iex> Expression.evaluate_as_string!("You entered @CLEAN(step.value)", %{
      iex>   "step" => %{
      iex>     "value" => <<65, 0, 66, 0, 67>>
      iex>   }
      iex> })
      "You entered ABC"
  """
  def clean(ctx, binary) do
    binary
    |> eval!(ctx)
    |> String.graphemes()
    |> Enum.filter(&String.printable?/1)
    |> Enum.join("")
  end

  @doc """
  Returns a numeric code for the first character in a text string

  # Example

      iex> Expression.evaluate_as_string!("The numeric code of A is @CODE(\\"A\\")")
      "The numeric code of A is 65"
  """
  def code(ctx, code_ast) do
    <<code>> = eval!(code_ast, ctx)
    code
  end

  @doc """
  Joins text strings into one text string


  # Example

      iex> Expression.evaluate_as_string!("Your name is @CONCATENATE(contact.first_name, \\" \\", contact.last_name)", %{
      iex>   "contact" => %{
      iex>     "first_name" => "name",
      iex>     "last_name" => "surname"
      iex>    }
      iex> })
      "Your name is name surname"
  """
  def concatenate_vargs(ctx, arguments) do
    Enum.join(eval_args!(arguments, ctx), "")
  end

  @doc """
  Formats the given number in decimal format using a period and commas

  ```
  You have @FIXED(contact.balance, 2) in your account
  ```

  # Example

      iex> Expression.evaluate!("@fixed(4.209922, 2, false)")
      "4.21"
      iex> Expression.evaluate!("@fixed(4000.424242, 4, true)")
      "4,000.4242"
      iex> Expression.evaluate!("@fixed(3.7979, 2, false)")
      "3.80"
      iex> Expression.evaluate!("@fixed(3.7979, 2)")
      "3.80"

  """
  def fixed(ctx, number, precision) do
    [number, precision] = eval_args!([number, precision], ctx)
    Number.Delimit.number_to_delimited(number, precision: precision)
  end

  def fixed(ctx, number, precision, boolean) do
    case eval_args!([number, precision, boolean], ctx) do
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

  # Example

      iex> Expression.evaluate!("@left(\\"foobar\\", 4)")
      "foob"

      iex> Expression.evaluate!("@left(\\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\\", 20)")
      "Умерла Мадлен Олбрай"

  """
  def left(ctx, binary, size) do
    [binary, size] = eval_args!([binary, size], ctx)
    String.slice(binary, 0, size)
  end

  @doc """
  Returns the number of characters in a text string

  # Example

      iex> Expression.evaluate!("@len(\\"foo\\")")
      3
      iex> Expression.evaluate!("@len(\\"zoë\\")")
      3
  """
  def len(ctx, binary) do
    String.length(eval!(binary, ctx))
  end

  @doc """
  Converts a text string to lowercase

  # Example

      iex> Expression.evaluate!("@lower(\\"Foo Bar\\")")
      "foo bar"

  """
  def lower(ctx, binary) do
    String.downcase(eval!(binary, ctx))
  end

  @doc """
  Capitalizes the first letter of every word in a text string

  # Example

      iex> Expression.evaluate!("@proper(\\"foo bar\\")")
      "Foo Bar"
  """
  def proper(ctx, binary) do
    binary
    |> eval!(ctx)
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Repeats text a given number of times

  # Example

      iex> Expression.evaluate!("@rept(\\"*\\", 10)")
      "**********"
  """
  def rept(ctx, value, amount) do
    [value, amount] = eval_args!([value, amount], ctx)
    String.duplicate(value, amount)
  end

  @doc """
  Returns the last characters in a text string.
  This is Unicode safe.

  # Example

      iex> Expression.evaluate!("@right(\\"testing\\", 3)")
      "ing"

      iex> Expression.evaluate!("@right(\\"Умерла Мадлен Олбрайт - первая женщина на посту главы Госдепа США\\", 20)")
      "ту главы Госдепа США"

  """
  def right(ctx, binary, size) do
    [binary, size] = eval_args!([binary, size], ctx)
    String.slice(binary, -size, size)
  end

  @doc """
  Substitutes new_text for old_text in a text string. If instance_num is given, then only that instance will be substituted

  # Example

      iex> Expression.evaluate!("@substitute(\\"I can't\\", \\"can't\\", \\"can do\\")")
      "I can do"

  """
  def substitute(ctx, subject, pattern, replacement) do
    [subject, pattern, replacement] = eval_args!([subject, pattern, replacement], ctx)
    String.replace(subject, pattern, replacement)
  end

  @doc """
  Returns the unicode character specified by a number

  # Example

      iex> Expression.evaluate!("@unichar(65)")
      "A"
      iex> Expression.evaluate!("@unichar(233)")
      "é"

  """
  def unichar(ctx, code) do
    code = eval!(code, ctx)
    <<code::utf8>>
  end

  @doc """
  Returns a numeric code for the first character in a text string

  # Example

      iex> Expression.evaluate!("@unicode(\\"A\\")")
      65
      iex> Expression.evaluate!("@unicode(\\"é\\")")
      233
  """
  def unicode(ctx, letter) do
    <<code::utf8>> = eval!(letter, ctx)
    code
  end

  @doc """
  Converts a text string to uppercase

  # Example

      iex> Expression.evaluate!("@upper(\\"foo\\")")
      "FOO"
  """
  def upper(ctx, binary) do
    String.upcase(eval!(binary, ctx))
  end

  @doc """
  Returns the first word in the given text - equivalent to WORD(text, 1)

  # Example

      iex> Expression.evaluate!("@first_word(\\"foo bar baz\\")")
      "foo"

  """
  def first_word(ctx, binary) do
    [word | _] = String.split(eval!(binary, ctx), " ")
    word
  end

  @doc """
  Formats a number as a percentage

  # Example

      iex> Expression.evaluate!("@percent(2/10)")
      "20%"
      iex> Expression.evaluate!("@percent(0.2)")
      "20%"
      iex> Expression.evaluate!("@percent(d)", %{"d" => Decimal.new("0.2")})
      "20%"
  """
  def percent(ctx, decimal) do
    decimal =
      case eval!(decimal, ctx) do
        float when is_float(float) -> Decimal.from_float(float)
        binary when is_binary(binary) -> Decimal.new(binary)
        decimal when is_struct(decimal, Decimal) -> decimal
      end

    decimal
    |> Decimal.mult(100)
    |> Decimal.to_float()
    |> Number.Percentage.number_to_percentage(precision: 0)
  end

  @doc """
  Formats digits in text for reading in TTS

  # Example

      iex> Expression.evaluate!("@read_digits(\\"+271\\")")
      "plus two seven one"

  """
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

  # Example

      iex> Expression.evaluate!("@remove_first_word(\\"foo bar\\")")
      "bar"
      iex> Expression.evaluate!("@remove_first_word(\\"foo-bar\\", \\"-\\")")
      "bar"
  """

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
  specified and is TRUE then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well

  # Example

      iex> Expression.evaluate!("@word(\\"hello cow-boy\\", 2)")
      "cow"
      iex> Expression.evaluate!("@word(\\"hello cow-boy\\", 2, true)")
      "cow-boy"
      iex> Expression.evaluate!("@word(\\"hello cow-boy\\", -1)")
      "boy"

  """
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
  Returns the number of words in the given text string. If by_spaces is specified and is TRUE then the function splits the text into words only by spaces. Otherwise the text is split by punctuation characters as well

  ```
  You entered @WORD_COUNT(step.value) words
  ```

  # Example

      iex> Expression.evaluate!("@word_count(\\"hello cow-boy\\")")
      3
      iex> Expression.evaluate!("@word_count(\\"hello cow-boy\\", true)")
      2
  """
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
  If by_spaces is specified and is TRUE then the function splits the text into words only by spaces.
  Otherwise the text is split by punctuation characters as well

  # Example

      iex> Expression.evaluate!("@word_slice(\\"RapidPro expressions are fun\\", 2, 4)")
      "expressions are"
      iex> Expression.evaluate!("@word_slice(\\"RapidPro expressions are fun\\", 2)")
      "expressions are fun"
      iex> Expression.evaluate!("@word_slice(\\"RapidPro expressions are fun\\", 1, -2)")
      "RapidPro expressions"
      iex> Expression.evaluate!("@word_slice(\\"RapidPro expressions are fun\\", -1)")
      "fun"
  """
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
  Returns TRUE if the argument is a number.

  # Example

      iex> Expression.evaluate!("@isnumber(1)")
      true
      iex> Expression.evaluate!("@isnumber(1.0)")
      true
      iex> Expression.evaluate!("@isnumber(dec)", %{"dec" => Decimal.new("1.0")})
      true
      iex> Expression.evaluate!("@isnumber(\\"1.0\\")")
      true
      iex> Expression.evaluate!("@isnumber(\\"a\\")")
      false

  """
  def isnumber(ctx, var) do
    var = eval!(var, ctx)

    case var do
      var when is_float(var) or is_integer(var) ->
        true

      var when is_struct(var, Decimal) ->
        true

      var when is_binary(var) ->
        Decimal.new(var)
        true

      _var ->
        false
    end
  rescue
    Decimal.Error -> false
  end

  @doc """
  Returns TRUE if the argument is a boolean.

  # Example

      iex> Expression.evaluate!("@isbool(true)")
      true
      iex> Expression.evaluate!("@isbool(false)")
      true
      iex> Expression.evaluate!("@isbool(1)")
      false
      iex> Expression.evaluate!("@isbool(0)")
      false
      iex> Expression.evaluate!("@isbool(\\"true\\")")
      false
      iex> Expression.evaluate!("@isbool(\\"false\\")")
      false
  """
  def isbool(ctx, var) do
    eval!(var, ctx) in [true, false]
  end

  @doc """
  Returns TRUE if the argument is a string.

  # Example

      iex> Expression.evaluate!("@isstring(\\"hello\\")")
      true
      iex> Expression.evaluate!("@isstring(false)")
      false
      iex> Expression.evaluate!("@isstring(1)")
      false
      iex> Expression.evaluate!("@isstring(d)", %{"d" => Decimal.new("1.0")})
      false
  """
  def isstring(ctx, binary), do: is_binary(eval!(binary, ctx))

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

  # Example

      iex> Expression.evaluate!("@has_all_words(\\"the quick brown FOX\\", \\"the fox\\")")
      true
      iex> Expression.evaluate!("@has_all_words(\\"the quick brown FOX\\", \\"red fox\\")")
      false

  """
  def has_all_words(ctx, haystack, words) do
    [haystack, words] = eval_args!([haystack, words], ctx)
    {patterns, results} = search_words(haystack, words)
    # future match result: Enum.join(results, " ")
    Enum.count(patterns) == Enum.count(results)
  end

  @doc """
  Tests whether any of the words are contained in the text

  Only one of the words needs to match and it may appear more than once.

  # Example

      iex> Expression.evaluate!("@has_any_word(\\"The Quick Brown Fox\\", \\"fox quick\\")")
      true
      iex> Expression.evaluate!("@has_any_word(\\"The Quick Brown Fox\\", \\"yellow\\")")
      false

  """
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

    %{
      "__value__" => Enum.any?(matched_haystack_words),
      "match" => Enum.join(matched_haystack_words, " ")
    }
  end

  @doc """
  Tests whether text starts with beginning

  Both text values are trimmed of surrounding whitespace, but otherwise matching is
  strict without any tokenization.

  # Example

      iex> Expression.evaluate!("@has_beginning(\\"The Quick Brown\\", \\"the quick\\")")
      true
      iex> Expression.evaluate!("@has_beginning(\\"The Quick Brown\\", \\"the    quick\\")")
      false
      iex> Expression.evaluate!("@has_beginning(\\"The Quick Brown\\", \\"quick brown\\")")
      false

  """
  def has_beginning(ctx, text, beginning) do
    [text, beginning] = eval_args!([text, beginning], ctx)

    case Regex.run(~r/^#{Regex.escape(beginning)}/i, text) do
      # future match result: first
      [_first | _remainder] -> true
      nil -> false
    end
  end

  defp extract_dateish(date_time) when is_struct(date_time, DateTime), do: date_time
  defp extract_dateish(date) when is_struct(date, Date), do: date

  defp extract_dateish(expression) when is_binary(expression) do
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

  # Example

      iex> Expression.evaluate!("@has_date(\\"the date is 15/01/2017\\")")
      true
      iex> Expression.evaluate!("@has_date(\\"the date is 15/01/2017\\").match")
      ~D[2017-01-15]
      iex> Expression.evaluate!("@has_date(\\"there is no date here, just a year 2017\\")")
      false

  """
  def has_date(ctx, expression) do
    dateish = extract_dateish(eval!(expression, ctx))
    %{"__value__" => !!dateish, "match" => dateish}
  end

  @doc """
  Tests whether `expression` is a date equal to `date_string`

  # Examples

      iex> Expression.evaluate!("@has_date_eq(\\"the date is 15/01/2017\\", \\"2017-01-15\\")")
      true
      iex> Expression.evaluate!("@has_date_eq(\\"there is no date here, just a year 2017\\", \\"2017-01-15\\")")
      false
      iex> Expression.evaluate!("@has_date_eq(date(2022, 12, 12), date(2022, 12, 12))")
      true
      iex> Expression.evaluate!("@has_date_eq(\\"the date is 15/01/2017\\", \\"2017-01-15\\").match")
      ~D[2017-01-15]

  """
  def has_date_eq(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)

    result =
      case found_date do
        found_date when is_struct(found_date, DateTime) ->
          DateTime.compare(found_date, test_date) == :eq

        found_date when is_struct(found_date, Date) ->
          Date.compare(found_date, test_date) == :eq

        found_date ->
          found_date == test_date
      end

    %{"__value__" => result, "match" => found_date}
  end

  @doc """
  Tests whether `expression` is a date after the date `date_string`

  # Example

      iex> Expression.evaluate!("@has_date_gt(\\"the date is 15/01/2017\\", \\"2017-01-01\\")")
      true
      iex> Expression.evaluate!("@has_date_gt(\\"the date is 15/01/2017\\", \\"2017-03-15\\")")
      false
      iex> Expression.evaluate!("@has_date_gt(\\"2000-01-01\\", now())")
      false
      iex> Expression.evaluate!("@has_date_gt(\\"the date is 15/01/2017\\", \\"2017-01-01\\").match")
      ~D[2017-01-15]

  """
  def has_date_gt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)
    result = Date.compare(found_date, test_date) == :gt
    %{"__value__" => result, "match" => found_date}
  end

  @doc """
  Tests whether `expression` contains a date before the date `date_string`

  # Example

      iex> Expression.evaluate!("@has_date_lt(\\"the date is 15/01/2017\\", \\"2017-06-01\\")")
      true
      iex> Expression.evaluate!("@has_date_lt(\\"the date is 15/01/2021\\", \\"2017-03-15\\")")
      false
      iex> Expression.evaluate!("@has_date_lt(now(), \\"2000-01-01\\")")
      false
      iex> Expression.evaluate!("@has_date_lt(\\"the date is 15/01/2017\\", \\"2017-06-01\\").match")
      ~D[2017-01-15]

  """
  def has_date_lt(ctx, expression, date_string) do
    [expression, date_string] = eval_args!([expression, date_string], ctx)
    found_date = extract_dateish(expression)
    test_date = extract_dateish(date_string)
    result = Date.compare(found_date, test_date) == :lt
    %{"__value__" => result, "match" => found_date}
  end

  @doc """
  Tests whether an email is contained in text

  # Example:

      iex> Expression.evaluate!("@has_email(\\"my email is foo1@bar.com, please respond\\")")
      true
      iex> Expression.evaluate!("@has_email(\\"i'm not sharing my email\\")")
      false

  """
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

  # Example:

      iex> contact = %{
      ...>   "groups" => [%{
      ...>     "uuid" => "b7cf0d83-f1c9-411c-96fd-c511a4cfa86d"
      ...>   }]
      ...> }
      iex> Expression.evaluate!("@has_group(contact.groups, \\"b7cf0d83-f1c9-411c-96fd-c511a4cfa86d\\")", %{"contact" => contact})
      true
      iex> Expression.evaluate!("@has_group(contact.groups, \\"00000000-0000-0000-0000-000000000000\\")", %{"contact" => contact})
      false

  """
  def has_group(ctx, groups, uuid) do
    [groups, uuid] = eval_args!([groups, uuid], ctx)
    group = Enum.find(groups, nil, &(&1["uuid"] == uuid))
    # future match result: group
    !!group
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

  defp parse_decimal(decimal) when is_struct(decimal, Decimal), do: decimal
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

  # Example

      iex> true = Expression.evaluate!("@has_number(\\"the number is 42 and 5\\")")
      iex> true = Expression.evaluate!("@has_number(\\"العدد ٤٢\\")")
      iex> true = Expression.evaluate!("@has_number(\\"٠.٥\\")")
      iex> true = Expression.evaluate!("@has_number(\\"0.6\\")")

  """
  def has_number(ctx, expression) do
    expression = eval!(expression, ctx)
    number = extract_numberish(expression)
    # future match result: number
    !!number
  end

  @doc """
  Tests whether `expression` contains a number equal to the value

  # Example

      iex> true = Expression.evaluate!("@has_number_eq(\\"the number is 42\\", 42)")
      iex> true = Expression.evaluate!("@has_number_eq(\\"the number is 42\\", 42.0)")
      iex> true = Expression.evaluate!("@has_number_eq(\\"the number is 42\\", \\"42\\")")
      iex> true = Expression.evaluate!("@has_number_eq(\\"the number is 42.0\\", \\"42\\")")
      iex> false = Expression.evaluate!("@has_number_eq(\\"the number is 40\\", \\"42\\")")
      iex> false = Expression.evaluate!("@has_number_eq(\\"the number is 40\\", \\"foo\\")")
      iex> false = Expression.evaluate!("@has_number_eq(\\"four hundred\\", \\"foo\\")")

  """
  def has_number_eq(ctx, expression, decimal) do
    [expression, decimal] = eval_args!([expression, decimal], ctx)

    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      Decimal.eq?(number, decimal)
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than min

  # Example

      iex> true = Expression.evaluate!("@has_number_gt(\\"the number is 42\\", 40)")
      iex> true = Expression.evaluate!("@has_number_gt(\\"the number is 42\\", 40.0)")
      iex> true = Expression.evaluate!("@has_number_gt(\\"the number is 42\\", \\"40\\")")
      iex> true = Expression.evaluate!("@has_number_gt(\\"the number is 42.0\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_gt(\\"the number is 40\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_gt(\\"the number is 40\\", \\"foo\\")")
      iex> false = Expression.evaluate!("@has_number_gt(\\"four hundred\\", \\"foo\\")")
  """
  def has_number_gt(ctx, expression, decimal) do
    [expression, decimal] = eval_args!([expression, decimal], ctx)

    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      Decimal.gt?(number, decimal)
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number greater than or equal to min

  # Example

      iex> true = Expression.evaluate!("@has_number_gte(\\"the number is 42\\", 42)")
      iex> true = Expression.evaluate!("@has_number_gte(\\"the number is 42\\", 42.0)")
      iex> true = Expression.evaluate!("@has_number_gte(\\"the number is 42\\", \\"42\\")")
      iex> false = Expression.evaluate!("@has_number_gte(\\"the number is 42.0\\", \\"45\\")")
      iex> false = Expression.evaluate!("@has_number_gte(\\"the number is 40\\", \\"45\\")")
      iex> false = Expression.evaluate!("@has_number_gte(\\"the number is 40\\", \\"foo\\")")
      iex> false = Expression.evaluate!("@has_number_gte(\\"four hundred\\", \\"foo\\")")
  """
  def has_number_gte(ctx, expression, decimal) do
    [expression, decimal] = eval_args!([expression, decimal], ctx)

    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      Decimal.gt?(number, decimal) || Decimal.eq?(number, decimal)
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than max

  # Example

      iex> true = Expression.evaluate!("@has_number_lt(\\"the number is 42\\", 44)")
      iex> true = Expression.evaluate!("@has_number_lt(\\"the number is 42\\", 44.0)")
      iex> false = Expression.evaluate!("@has_number_lt(\\"the number is 42\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_lt(\\"the number is 42.0\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_lt(\\"the number is 40\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_lt(\\"the number is 40\\", \\"foo\\")")
      iex> false = Expression.evaluate!("@has_number_lt(\\"four hundred\\", \\"foo\\")")
  """
  def has_number_lt(ctx, expression, decimal) do
    [expression, decimal] = eval_args!([expression, decimal], ctx)

    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      Decimal.lt?(number, decimal)
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether `expression` contains a number less than or equal to max

  # Example

      iex> true = Expression.evaluate!("@has_number_lte(\\"the number is 42\\", 42)")
      iex> true = Expression.evaluate!("@has_number_lte(\\"the number is 42\\", 42.0)")
      iex> true = Expression.evaluate!("@has_number_lte(\\"the number is 42\\", \\"42\\")")
      iex> false = Expression.evaluate!("@has_number_lte(\\"the number is 42.0\\", \\"40\\")")
      iex> false = Expression.evaluate!("@has_number_lte(\\"the number is 40\\", \\"foo\\")")
      iex> false = Expression.evaluate!("@has_number_lte(\\"four hundred\\", \\"foo\\")")

  """
  def has_number_lte(ctx, expression, decimal) do
    [expression, decimal] = eval_args!([expression, decimal], ctx)

    with %Decimal{} = number <- extract_numberish(expression),
         %Decimal{} = decimal <- parse_decimal(decimal) do
      # Future match result: number
      Decimal.lt?(number, decimal) || Decimal.eq?(number, decimal)
    else
      nil -> false
      :error -> false
    end
  end

  @doc """
  Tests whether the text contains only phrase

  The phrase must be the only text in the text to match

  # Example

      iex> Expression.evaluate!("@has_only_phrase(\\"Quick Brown\\", \\"quick brown\\")")
      true
      iex> Expression.evaluate!("@has_only_phrase(\\"\\", \\"\\")")
      true
      iex> Expression.evaluate!("@has_only_phrase(\\"The Quick Brown Fox\\", \\"quick brown\\")")
      false

  """
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

  # Example

      iex> Expression.evaluate!("@has_only_text(\\"foo\\", \\"foo\\")")
      true
      iex> Expression.evaluate!("@has_only_text(\\"\\", \\"\\")")
      true
      iex> Expression.evaluate!("@has_only_text(\\"foo\\", \\"FOO\\")")
      false

  """
  def has_only_text(ctx, expression_one, expression_two) do
    [expression_one, expression_two] = eval_args!([expression_one, expression_two], ctx)
    expression_one == expression_two
  end

  @doc """
  Tests whether `expression` matches the regex pattern

  Both text values are trimmed of surrounding whitespace and matching is case-insensitive.

  # Examples

      iex> Expression.evaluate!("@has_pattern(\\"Buy cheese please\\", \\"buy (\\\\w+)\\")")
      true
      iex> Expression.evaluate!("@has_pattern(\\"Sell cheese please\\", \\"buy (\\\\w+)\\")")
      false

  """
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

  # Example

      iex> Expression.evaluate!("@has_phone(\\"my number is +12067799294 thanks\\")")
      true
      iex> Expression.evaluate!("@has_phone(\\"my number is 2067799294 thanks\\", \\"US\\")")
      true
      iex> Expression.evaluate!("@has_phone(\\"my number is 206 779 9294 thanks\\", \\"US\\")")
      true
      iex> Expression.evaluate!("@has_phone(\\"my number is none of your business\\", \\"US\\")")
      false

  """
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

  # Examples

      iex> Expression.evaluate!("@has_phrase(\\"the quick brown fox\\", \\"brown fox\\")")
      true
      iex> Expression.evaluate!("@has_phrase(\\"the quick brown fox\\", \\"quick fox\\")")
      false
      iex> Expression.evaluate!("@has_phrase(\\"the quick brown fox\\", \\"\\")")
      true

  """
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

  # Examples

      iex> Expression.evaluate!("@has_text(\\"quick brown\\")")
      true
      iex> Expression.evaluate!("@has_text(\\"\\")")
      false
      iex> Expression.evaluate!("@has_text(\\" \\n\\")")
      false
      iex> Expression.evaluate!("@has_text(123)")
      true
  """
  def has_text(ctx, expression) do
    expression = eval!(expression, ctx) |> to_string()
    String.trim(expression) != ""
  end

  @doc """
  Tests whether `expression` contains a time.

  # Examples

      iex> Expression.evaluate!("@has_time(\\"the time is 10:30\\")")
      true
      iex> Expression.evaluate!("@has_time(\\"the time is 10:00 pm\\")")
      true
      iex> Expression.evaluate!("@has_time(\\"the time is 10:30:45\\")")
      true
      iex> Expression.evaluate!("@has_time(\\"there is no time here, just the number 25\\")")
      false

  """
  def has_time(ctx, expression) do
    case DateTimeParser.parse_time(eval!(expression, ctx)) do
      # Future match result: time
      {:ok, _time} -> true
      _ -> false
    end
  end

  def map(ctx, enumerable, mapper) do
    [enumerable, mapper] = eval_args!([enumerable, mapper], ctx)

    enumerable
    # wrap in a list to be passed as a list of arguments
    |> Enum.map(&[&1])
    # call the mapper with each list of arguments as a single argument
    |> Enum.map(mapper)
  end
end
