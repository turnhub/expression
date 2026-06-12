defmodule DateFunctionsTypeTest do
  @moduledoc """
  Systematic type-matrix tests for the "date" category of expression functions.

  These tests DOCUMENT CURRENT BEHAVIOR of the V1 engine, including crashes.
  Tests marked "Known crash behavior, documented not endorsed" capture cases
  where a function raises instead of returning an error map. They exist so that
  any change to these behaviors is deliberate, not accidental.

  Note on context coercion: `Expression.Context` coerces context values before
  callbacks see them. ISO8601-looking strings become Date/DateTime/Time structs
  and numeric strings become numbers. To exercise a function with an actual
  string argument the string must be embedded as a literal in the expression.

  Covered: datevalue, parse_datevalue, day, month, year, hour, minute, second,
  time, timevalue, datetime_add, datetime_from_unix, weekday, edate, now, today.
  Excluded: date/3 (pilot-covered in expression_test.exs).
  """
  use ExUnit.Case, async: true

  import Expression.Test.TypeTestMatrix

  describe "day/1 type handling" do
    test "extracts day from Date, DateTime and NaiveDateTime" do
      assert 15 == evaluate_with_value("day(value)", ~D[2023-06-15])
      assert 15 == evaluate_with_value("day(value)", ~U[2023-06-15 10:30:00Z])
      assert 15 == evaluate_with_value("day(value)", ~N[2023-06-15 10:30:00])
    end

    test "works on leap day" do
      assert 29 == evaluate_with_value("day(value)", ~D[2024-02-29])
    end

    test "date-looking string passed via context is coerced to a Date first" do
      assert 15 == evaluate_with_value("day(value)", "2023-01-15")
    end

    test "literal string raises MatchError" do
      # Known crash behavior, documented not endorsed: day/1 pattern matches
      # %{day: day} against its argument; a raw string (which bypasses context
      # coercion) does not match and raises MatchError.
      assert_raise MatchError, fn ->
        Expression.evaluate_block!(~s|day("2023-01-15")|)
      end
    end

    test "extracts day from complex value's __value__ key" do
      assert 15 == evaluate_with_value("day(value)", complex_value(~D[2023-06-15]))
    end

    test "nil raises MatchError" do
      # Known crash behavior, documented not endorsed: nil does not match the
      # %{day: day} pattern, so day(nil) raises MatchError.
      assert_raise MatchError, fn -> evaluate_with_value("day(value)", nil) end
    end

    test "non-date garbage raises MatchError" do
      # Known crash behavior, documented not endorsed: integers, booleans,
      # lists, Time structs and string-keyed maps all fail the %{day: day}
      # pattern match and raise.
      for garbage <- [42, true, [1, 2], %{"day" => 9}, ~T[10:30:00]] do
        assert_raise MatchError, fn -> evaluate_with_value("day(value)", garbage) end
      end
    end
  end

  describe "month/1 type handling" do
    test "extracts month from Date, DateTime and NaiveDateTime" do
      assert 6 == evaluate_with_value("month(value)", ~D[2023-06-15])
      assert 6 == evaluate_with_value("month(value)", ~U[2023-06-15 10:30:00Z])
      assert 6 == evaluate_with_value("month(value)", ~N[2023-06-15 10:30:00])
    end

    test "date-looking string passed via context is coerced to a Date first" do
      assert 1 == evaluate_with_value("month(value)", "2023-01-15")
    end

    test "literal string raises MatchError" do
      # Known crash behavior, documented not endorsed: month/1 pattern matches
      # %{month: month}; raw strings do not match and raise MatchError.
      assert_raise MatchError, fn ->
        Expression.evaluate_block!(~s|month("2023-01-15")|)
      end
    end

    test "extracts month from complex value's __value__ key" do
      assert 6 == evaluate_with_value("month(value)", complex_value(~D[2023-06-15]))
    end

    test "nil raises MatchError" do
      # Known crash behavior, documented not endorsed: nil fails the
      # %{month: month} pattern match.
      assert_raise MatchError, fn -> evaluate_with_value("month(value)", nil) end
    end

    test "non-date garbage raises MatchError" do
      # Known crash behavior, documented not endorsed: Time has no month field
      # and scalars/collections fail the map pattern match.
      for garbage <- [42, true, [1, 2], %{"a" => 1}, ~T[10:30:00]] do
        assert_raise MatchError, fn -> evaluate_with_value("month(value)", garbage) end
      end
    end
  end

  describe "year/1 type handling" do
    test "extracts year from Date and DateTime" do
      assert 2023 == evaluate_with_value("year(value)", ~D[2023-06-15])
      assert 2023 == evaluate_with_value("year(value)", ~U[2023-06-15 10:30:00Z])
    end

    test "NaiveDateTime raises FunctionClauseError" do
      # Known crash behavior, documented not endorsed: unlike day/1 and
      # month/1, year/1 routes through DateHelpers.extract_dateish/1 which has
      # no clause for NaiveDateTime.
      assert_raise FunctionClauseError, fn ->
        evaluate_with_value("year(value)", ~N[2023-06-15 10:30:00])
      end
    end

    test "literal date string is parsed (unlike day/month)" do
      # year/1 uses extract_dateish, which parses date strings itself, so the
      # literal-string form works here even though it crashes for day/month.
      assert 2023 == Expression.evaluate_block!(~s|year("2023-01-15")|)
    end

    test "non-date string raises MatchError" do
      # Known crash behavior, documented not endorsed: extract_dateish returns
      # nil for unparseable strings, which then fails the %{year: year} match.
      assert_raise MatchError, fn ->
        Expression.evaluate_block!(~s|year("not a date")|)
      end
    end

    test "extracts year from complex value's __value__ key" do
      assert 2023 == evaluate_with_value("year(value)", complex_value(~D[2023-06-15]))
    end

    test "nil raises MatchError" do
      # Known crash behavior, documented not endorsed: extract_dateish(nil)
      # returns nil, failing the subsequent %{year: year} pattern match.
      assert_raise MatchError, fn -> evaluate_with_value("year(value)", nil) end
    end

    test "non-date garbage raises FunctionClauseError" do
      # Known crash behavior, documented not endorsed: extract_dateish has no
      # clause for integers, booleans or Time structs.
      for garbage <- [42, true, ~T[10:30:00]] do
        assert_raise FunctionClauseError, fn ->
          evaluate_with_value("year(value)", garbage)
        end
      end
    end
  end

  describe "hour/1 type handling" do
    test "extracts hour from DateTime, NaiveDateTime and Time" do
      assert 13 == evaluate_with_value("hour(value)", ~U[2023-06-15 13:45:30Z])
      assert 13 == evaluate_with_value("hour(value)", ~N[2023-06-15 13:45:30])
      assert 13 == evaluate_with_value("hour(value)", ~T[13:45:30])
    end

    test "Date raises MatchError" do
      # Known crash behavior, documented not endorsed: hour/1 pattern matches
      # %{hour: hour} directly; Date has no hour field.
      assert_raise MatchError, fn -> evaluate_with_value("hour(value)", ~D[2023-06-15]) end
    end

    test "extracts hour from complex value's __value__ key" do
      assert 13 == evaluate_with_value("hour(value)", complex_value(~U[2023-06-15 13:45:30Z]))
    end

    test "nil raises MatchError" do
      # Known crash behavior, documented not endorsed: nil fails the
      # %{hour: hour} pattern match.
      assert_raise MatchError, fn -> evaluate_with_value("hour(value)", nil) end
    end

    test "non-date garbage raises MatchError" do
      # Known crash behavior, documented not endorsed: atom-keyed pattern match
      # rejects scalars, lists and string-keyed maps alike.
      for garbage <- [42, true, [], %{"hour" => 5}] do
        assert_raise MatchError, fn -> evaluate_with_value("hour(value)", garbage) end
      end
    end
  end

  describe "minute/1 type handling" do
    test "extracts minute from DateTime" do
      assert 45 == evaluate_with_value("minute(value)", ~U[2023-06-15 13:45:30Z])
    end

    test "Date is upgraded to midnight, returning 0" do
      # minute/1 routes through extract_datetimeish, which converts a Date to
      # a midnight DateTime instead of crashing as hour/1 does.
      assert 0 == evaluate_with_value("minute(value)", ~D[2023-06-15])
    end

    test "Time raises MatchError, unlike hour/1 and second/1" do
      # Known crash behavior, documented not endorsed: extract_datetimeish has
      # no clause for Time (returns nil), so minute(~T[...]) raises even though
      # hour/1 and second/1 accept Time structs. Asymmetric by accident.
      assert_raise MatchError, fn -> evaluate_with_value("minute(value)", ~T[13:45:30]) end
    end

    test "NaiveDateTime raises MatchError" do
      # Known crash behavior, documented not endorsed: extract_datetimeish's
      # catch-all returns nil for NaiveDateTime.
      assert_raise MatchError, fn ->
        evaluate_with_value("minute(value)", ~N[2023-06-15 13:45:30])
      end
    end

    test "extracts minute from complex value's __value__ key" do
      assert 45 == evaluate_with_value("minute(value)", complex_value(~U[2023-06-15 13:45:30Z]))
    end

    test "nil and non-date garbage raise MatchError" do
      # Known crash behavior, documented not endorsed: extract_datetimeish
      # returns nil for these inputs, failing the %{minute: minute} match.
      for garbage <- [nil, 42, true, []] do
        assert_raise MatchError, fn -> evaluate_with_value("minute(value)", garbage) end
      end
    end
  end

  describe "second/1 type handling" do
    test "extracts second from DateTime, NaiveDateTime and Time" do
      assert 30 == evaluate_with_value("second(value)", ~U[2023-06-15 13:45:30Z])
      assert 30 == evaluate_with_value("second(value)", ~N[2023-06-15 13:45:30])
      assert 30 == evaluate_with_value("second(value)", ~T[13:45:30])
    end

    test "Date raises MatchError" do
      # Known crash behavior, documented not endorsed: second/1 pattern matches
      # %{second: second} directly; Date has no second field.
      assert_raise MatchError, fn -> evaluate_with_value("second(value)", ~D[2023-06-15]) end
    end

    test "extracts second from complex value's __value__ key" do
      assert 30 == evaluate_with_value("second(value)", complex_value(~U[2023-06-15 13:45:30Z]))
    end

    test "nil and non-date garbage raise MatchError" do
      # Known crash behavior, documented not endorsed: nil and scalars fail
      # the %{second: second} pattern match.
      for garbage <- [nil, 42, true, []] do
        assert_raise MatchError, fn -> evaluate_with_value("second(value)", garbage) end
      end
    end
  end

  describe "datevalue/1 and datevalue/2 type handling" do
    test "literal date string returns a map with __value__, date and datetime" do
      assert %{
               "__value__" => "2022-01-01 00:00:00",
               "date" => ~D[2022-01-01],
               "datetime" => ~U[2022-01-01 00:00:00Z]
             } == Expression.evaluate_block!(~s|datevalue("2022-01-01")|)
    end

    test "Date input is upgraded to a midnight DateTime" do
      result = evaluate_with_value("datevalue(value)", ~D[2022-01-01])
      assert result["__value__"] == "2022-01-01 00:00:00"
      assert result["date"] == ~D[2022-01-01]
      # Microsecond precision differs from a plain ~U sigil, so compare fields.
      assert %DateTime{year: 2022, month: 1, day: 1, hour: 0} = result["datetime"]
    end

    test "DateTime input preserves the time component" do
      result = evaluate_with_value("datevalue(value)", ~U[2022-01-01 10:30:00Z])
      assert result["__value__"] == "2022-01-01 10:30:00"
      assert result["datetime"] == ~U[2022-01-01 10:30:00Z]
    end

    test "custom strftime format is applied to __value__" do
      result = evaluate_with_value(~s|datevalue(value, "%d/%m/%Y")|, ~U[2022-01-31 10:30:00Z])
      assert result["__value__"] == "31/01/2022"
      assert result["date"] == ~D[2022-01-31]
    end

    test "datevalue/1 raises ArgumentError on nil, non-dates and bad strings" do
      # Known crash behavior, documented not endorsed: extract_datetimeish
      # returns nil for these inputs and datevalue/1 then calls
      # Timex.format!(nil, ...) which raises ArgumentError (:invalid_date).
      # NaiveDateTime is also rejected by extract_datetimeish's catch-all.
      for garbage <- [nil, 42, true, [], ~N[2022-01-01 10:30:00]] do
        assert_raise ArgumentError, fn -> evaluate_with_value("datevalue(value)", garbage) end
      end

      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|datevalue("not a date")|)
      end
    end

    test "datevalue/2 silently returns nil on invalid input, unlike datevalue/1" do
      # The /2 arity guards with `if datetime = extract_datetimeish(...)` and
      # has no else branch, so the same inputs that crash /1 return nil here.
      assert nil == evaluate_with_value(~s|datevalue(value, "%Y")|, nil)
      assert nil == evaluate_with_value(~s|datevalue(value, "%Y")|, 42)
    end

    test "extracts date from complex value's __value__ key" do
      result = evaluate_with_value("datevalue(value)", complex_value(~D[2022-01-01]))
      assert result["date"] == ~D[2022-01-01]
    end
  end

  describe "parse_datevalue/2 type handling" do
    test "parses an ISO8601 string with a matching strftime format" do
      assert ~U[2016-02-29 22:25:00Z] ==
               Expression.evaluate_block!(
                 ~s|parse_datevalue("2016-02-29T22:25:00-00:00", "%FT%T%:z")|
               )
    end

    test "parses a leap day date-only format to midnight UTC" do
      assert ~U[2024-02-29 00:00:00Z] ==
               Expression.evaluate_block!(~s|parse_datevalue("2024-02-29", "%Y-%m-%d")|)
    end

    test "returns nil when the string does not match the format" do
      assert nil == Expression.evaluate_block!(~s|parse_datevalue("garbage", "%FT%T%:z")|)
    end

    test "returns nil for nil and non-string garbage" do
      # Timex.parse returns {:error, _} for non-binary input rather than
      # raising, so every garbage input maps to nil.
      for garbage <- [nil, 42, true, [], ~D[2023-06-15]] do
        assert nil == evaluate_with_value(~s|parse_datevalue(value, "%FT%T%:z")|, garbage)
      end
    end

    test "extracts string from complex value's __value__ key" do
      assert ~U[2016-02-29 22:25:00Z] ==
               evaluate_with_value(
                 ~s|parse_datevalue(value, "%FT%T%:z")|,
                 complex_value("2016-02-29T22:25:00-00:00")
               )
    end
  end

  describe "time/3 type handling" do
    test "builds a Time from integer arguments" do
      assert ~T[12:13:14] == Expression.evaluate_block!("time(12, 13, 14)")
    end

    test "extracts integers from complex values' __value__ keys" do
      assert ~T[12:13:14] == evaluate_with_value("time(value, 13, 14)", complex_value(12))
    end

    test "performs no range validation, returning an invalid Time struct" do
      # Known crash behavior, documented not endorsed: time/3 builds the Time
      # struct directly (no Time.new!), so out-of-range values produce a struct
      # that crashes later, e.g. when inspected or converted to a string.
      assert %Time{hour: 25, minute: 99, second: 99} =
               Expression.evaluate_block!("time(25, 99, 99)")
    end

    test "performs no type validation: nil and strings are embedded as-is" do
      # Known crash behavior, documented not endorsed: nil/string fields make
      # the struct unusable; any downstream rendering raises
      # FunctionClauseError in Calendar.ISO.
      assert %Time{hour: nil, minute: 0, second: 0} =
               evaluate_with_value("time(value, 0, 0)", nil)

      assert %Time{hour: "12", minute: "13", second: "14"} =
               Expression.evaluate_block!(~s|time("12", "13", "14")|)
    end

    test "floats are embedded as-is, producing an invalid struct" do
      # Known crash behavior, documented not endorsed: same lack of validation
      # as above, with float fields.
      assert %Time{hour: 1.5} = Expression.evaluate_block!("time(1.5, 0, 0)")
    end
  end

  describe "timevalue/1 type handling" do
    test "parses H:M and H:M:S strings" do
      assert ~T[02:30:00] == Expression.evaluate_block!(~s|timevalue("2:30")|)
      assert ~T[02:30:55] == Expression.evaluate_block!(~s|timevalue("2:30:55")|)
    end

    test "extracts string from complex value's __value__ key" do
      assert ~T[02:30:00] == evaluate_with_value("timevalue(value)", complex_value("2:30"))
    end

    test "nil and non-string garbage raise FunctionClauseError" do
      # Known crash behavior, documented not endorsed: timevalue/1 calls
      # String.split/3 directly on the input; non-binaries (including an
      # already-parsed Time struct) raise FunctionClauseError.
      for garbage <- [nil, 42, true, ["2:30"], ~T[02:30:00]] do
        assert_raise FunctionClauseError, fn ->
          evaluate_with_value("timevalue(value)", garbage)
        end
      end
    end

    test "non-numeric time string raises ArgumentError" do
      # Known crash behavior, documented not endorsed: String.to_integer/1
      # raises on the non-numeric segment.
      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|timevalue("garbage")|)
      end
    end

    test "out-of-range time string returns an invalid Time struct" do
      # Known crash behavior, documented not endorsed: no range validation, so
      # "25:99" yields a Time struct that crashes when rendered.
      assert %Time{hour: 25, minute: 99, second: 0} =
               Expression.evaluate_block!(~s|timevalue("25:99")|)
    end
  end

  describe "datetime_add/3 type handling" do
    test "clamps month-end arithmetic (Jan 31 + 1 month = Feb 28)" do
      assert ~U[2023-02-28 00:00:00Z] ==
               evaluate_with_value(~s|datetime_add(value, 1, "M")|, ~U[2023-01-31 00:00:00Z])
    end

    test "handles leap day arithmetic" do
      assert ~U[2024-02-29 00:00:00.000000Z] ==
               evaluate_with_value(~s|datetime_add(value, 1, "D")|, ~D[2024-02-28])
    end

    test "Date input is upgraded to a midnight DateTime" do
      assert ~U[2023-02-28 00:00:00.000000Z] ==
               evaluate_with_value(~s|datetime_add(value, 1, "M")|, ~D[2023-01-31])
    end

    test "literal date string is parsed by extract_datetimeish" do
      assert ~U[2023-01-16 00:00:00Z] ==
               Expression.evaluate_block!(~s|datetime_add("2023-01-15", 1, "D")|)
    end

    test "returns an error map for nil, non-dates and NaiveDateTime" do
      # NaiveDateTime falls through extract_datetimeish's catch-all, so it is
      # treated as an invalid date even though it carries date fields.
      for garbage <- [nil, 42, true, [], ~N[2023-01-15 10:00:00]] do
        assert %{"error" => true, "message" => "Invalid date"} =
                 evaluate_with_value(~s|datetime_add(value, 1, "D")|, garbage)
      end
    end

    test "extracts datetime from complex value's __value__ key" do
      assert ~U[2023-02-28 00:00:00Z] ==
               evaluate_with_value(
                 ~s|datetime_add(value, 1, "M")|,
                 complex_value(~U[2023-01-31 00:00:00Z])
               )
    end

    test "unknown unit raises CaseClauseError" do
      # Known crash behavior, documented not endorsed: the unit case statement
      # has no fallback clause for unrecognised units.
      assert_raise CaseClauseError, fn ->
        evaluate_with_value(~s|datetime_add(value, 1, "x")|, ~D[2023-01-15])
      end
    end

    test "literal string or nil offset raises ArithmeticError" do
      # Known crash behavior, documented not endorsed: Timex.shift does not
      # coerce string/nil offsets. A string offset only works when supplied via
      # context, where Expression.Context coerces "1" to the integer 1.
      assert_raise ArithmeticError, fn ->
        evaluate_with_value(~s|datetime_add(value, "1", "D")|, ~D[2023-01-15])
      end

      assert_raise ArithmeticError, fn ->
        evaluate_with_value(~s|datetime_add(value, nil, "D")|, ~D[2023-01-15])
      end
    end
  end

  describe "datetime_from_unix/2 type handling" do
    test "epoch zero in seconds" do
      assert ~U[1970-01-01 00:00:00Z] ==
               Expression.evaluate_block!(~s|datetime_from_unix(0, "second")|)
    end

    test "integer seconds and string milliseconds parse equivalently" do
      assert DateTime.from_unix!(1_701_903_600, :second) ==
               Expression.evaluate_block!(~s|datetime_from_unix(1701903600, "second")|)

      assert DateTime.from_unix!(1_701_903_600_000, :millisecond) ==
               Expression.evaluate_block!(~s|datetime_from_unix("1701903600000", "millisecond")|)
    end

    test "negative timestamps resolve to pre-epoch datetimes" do
      assert ~U[1969-12-31 00:00:00Z] ==
               Expression.evaluate_block!(~s|datetime_from_unix(-86400, "second")|)
    end

    test "extracts timestamp from complex value's __value__ key" do
      assert DateTime.from_unix!(1_701_903_600, :second) ==
               evaluate_with_value(
                 ~s|datetime_from_unix(value, "second")|,
                 complex_value(1_701_903_600)
               )
    end

    test "nil, booleans, floats and unknown units raise FunctionClauseError" do
      # Known crash behavior, documented not endorsed: parse_unix/2 only has
      # clauses for binary/integer timestamps and "second"/"millisecond" units.
      for garbage <- [nil, true, 1.5] do
        assert_raise FunctionClauseError, fn ->
          evaluate_with_value(~s|datetime_from_unix(value, "second")|, garbage)
        end
      end

      assert_raise FunctionClauseError, fn ->
        Expression.evaluate_block!(~s|datetime_from_unix(0, "fortnight")|)
      end
    end

    test "non-numeric string raises ArgumentError" do
      # Known crash behavior, documented not endorsed: String.to_integer/1
      # raises on non-numeric timestamp strings.
      assert_raise ArgumentError, fn ->
        Expression.evaluate_block!(~s|datetime_from_unix("garbage", "second")|)
      end
    end
  end

  describe "weekday/1 type handling" do
    test "returns 1 (Sunday) through 7 (Saturday) across a known week" do
      # 2022-11-06 was a Sunday, 2022-11-07 a Monday, 2022-11-12 a Saturday.
      assert 1 == evaluate_with_value("weekday(value)", ~D[2022-11-06])
      assert 2 == evaluate_with_value("weekday(value)", ~D[2022-11-07])
      assert 7 == evaluate_with_value("weekday(value)", ~D[2022-11-12])
    end

    test "accepts DateTime and NaiveDateTime" do
      assert 1 == evaluate_with_value("weekday(value)", ~U[2022-11-06 10:00:00Z])
      assert 1 == evaluate_with_value("weekday(value)", ~N[2022-11-06 10:00:00])
    end

    test "date-looking string via context is coerced; literal string raises" do
      assert 1 == evaluate_with_value("weekday(value)", "2022-11-06")

      # Known crash behavior, documented not endorsed: Timex.weekday returns an
      # error tuple for raw strings, and the subsequent + 1 raises
      # ArithmeticError.
      assert_raise ArithmeticError, fn ->
        Expression.evaluate_block!(~s|weekday("2022-11-06")|)
      end
    end

    test "extracts date from complex value's __value__ key" do
      assert 1 == evaluate_with_value("weekday(value)", complex_value(~D[2022-11-06]))
    end

    test "nil and non-date garbage raise ArithmeticError" do
      # Known crash behavior, documented not endorsed: Timex.weekday's error
      # tuple flows into integer arithmetic for all invalid inputs.
      for garbage <- [nil, 42, true, []] do
        assert_raise ArithmeticError, fn -> evaluate_with_value("weekday(value)", garbage) end
      end
    end
  end

  describe "edate/2 type handling" do
    test "clamps month-end arithmetic (Jan 31 + 1 month = Feb 28)" do
      assert ~D[2023-02-28] == evaluate_with_value("edate(value, 1)", ~D[2023-01-31])
    end

    test "handles leap-year boundaries" do
      assert ~D[2024-02-29] == evaluate_with_value("edate(value, -1)", ~D[2024-03-31])
      assert ~D[2025-02-28] == evaluate_with_value("edate(value, 12)", ~D[2024-02-29])
    end

    test "DateTime input preserves the time component" do
      assert ~U[2023-02-28 10:00:00Z] ==
               evaluate_with_value("edate(value, 1)", ~U[2023-01-31 10:00:00Z])
    end

    test "literal date string is parsed by extract_dateish" do
      assert ~D[2022-11-10] == Expression.evaluate_block!(~s|edate("2022-10-10", 1)|)
    end

    test "extracts date from complex value's __value__ key" do
      assert ~D[2022-11-10] ==
               evaluate_with_value("edate(value, months)", complex_value("2022-10-10"), %{
                 "months" => 1
               })
    end

    test "nil returns a bare {:error, :invalid_date} tuple" do
      # Surprising: not an error map and not a crash — Timex.shift(nil, ...)
      # returns its error tuple, which leaks straight through to the caller.
      assert {:error, :invalid_date} == evaluate_with_value("edate(value, 1)", nil)
    end

    test "non-date garbage raises FunctionClauseError" do
      # Known crash behavior, documented not endorsed: extract_dateish has no
      # clause for integers, booleans, lists or NaiveDateTime.
      for garbage <- [42, true, [], ~N[2023-01-31 10:00:00]] do
        assert_raise FunctionClauseError, fn ->
          evaluate_with_value("edate(value, 1)", garbage)
        end
      end
    end

    test "literal string month offset raises ArithmeticError" do
      # Known crash behavior, documented not endorsed: Timex.shift does not
      # coerce string offsets.
      assert_raise ArithmeticError, fn ->
        evaluate_with_value(~s|edate(value, "1")|, ~D[2023-01-15])
      end
    end
  end

  describe "now/0 and today/0 return types" do
    test "now() returns a UTC DateTime" do
      assert %DateTime{time_zone: "Etc/UTC"} = Expression.evaluate_block!("now()")
    end

    test "today() returns a Date" do
      assert %Date{} = Expression.evaluate_block!("today()")
    end
  end
end
