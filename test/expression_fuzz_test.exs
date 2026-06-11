defmodule ExpressionFuzzTest do
  @moduledoc """
  Property-based (fuzz) tests for the crash-safety invariant of expression
  functions.

  The invariant: evaluating a function with arbitrary runtime input must never
  RAISE. Returning a normal value, or an `expression/v1error` error map, is an
  acceptable outcome — only an unhandled exception is a failure.

  ## Scope: the crash-safe subset only

  These tests DOCUMENT CURRENT BEHAVIOR, they do not endorse it. The V1 engine
  does NOT uphold the no-crash invariant universally — many functions raise on
  unexpected input types (this is captured, function by function, in the
  `*_functions_type_test.exs` files). Fuzzing every function against
  `any_value/0` would therefore fail immediately and tell us nothing new.

  Instead this suite fuzzes only the functions that were empirically confirmed
  crash-safe across the full type matrix (nil, booleans, numbers, strings,
  lists, maps, complex `__value__` maps, Dates/DateTimes, Decimals, error maps).
  For those functions the property below is a genuine regression guard: if a
  future change makes one of them crash on some input, the property fails.

  ## Known crashers (intentionally excluded — the hardening backlog)

  The following functions currently RAISE on at least some matrix inputs and
  are deliberately not fuzzed for no-crash here. Each is pinned, with the exact
  exception, in the corresponding `*_functions_type_test.exs` file. Moving one
  into `@crash_safe` below should happen only once it has been hardened to
  return an error map instead of raising:

    string  — len, clean, first_word, remove_first_word, remove_last_word,
              word_count, read_digits, url_encode, url_decode, unicode, code,
              char, unichar, left, right, mid, word, word_slice, rept,
              substitute, regex_capture, regex_named_capture
    number  — abs, round, fixed, power, rem, rand_between, percent, sum
    date    — day, month, year, hour, minute, second, weekday, datevalue,
              parse_datevalue, datetime_add, datetime_from_unix, edate, time
    enum    — find, has_member, delete, append, filter, map, reduce, reject,
              sort_by, chunk_every, concatenate

  Run this suite with: `mix test --only fuzz`
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Expression.Test.FuzzHelpers

  @moduletag :fuzz

  # Functions confirmed crash-safe across the entire type matrix. Each entry is
  # {label, expression} where `value` is the fuzzed argument bound in context.
  # Multi-argument functions fuzz the first argument and hold the rest fixed.
  @crash_safe_string [
    {"upper", "upper(value)"},
    {"lower", "lower(value)"},
    {"proper", "proper(value)"},
    {"trim", "trim(value)"}
  ]

  @crash_safe_logical [
    {"not", "not(value)"},
    {"if", "if(value, 1, 2)"},
    {"and", "and(value, true)"},
    {"or", "or(value, false)"},
    {"isnumber", "isnumber(value)"},
    {"isbool", "isbool(value)"},
    {"isstring", "isstring(value)"},
    {"is_error", "is_error(value)"},
    {"is_nil_or_empty", "is_nil_or_empty(value)"}
  ]

  @crash_safe_number [
    {"max", "max(value, 1)"},
    {"min", "min(value, 1)"}
  ]

  @crash_safe_enum [
    {"uniq", "uniq(value)"},
    {"with_index", "with_index(value)"},
    {"has_all_members", "has_all_members(value, [1])"},
    {"has_any_member", "has_any_member(value, [1])"}
  ]

  @crash_safe_other [
    {"json", "json(value)"}
  ]

  describe "string functions never crash on arbitrary input" do
    for {label, expr} <- @crash_safe_string do
      property "#{label}/1" do
        check all(value <- any_value()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "logical functions never crash on arbitrary input" do
    for {label, expr} <- @crash_safe_logical do
      property "#{label}" do
        check all(value <- any_value()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "number functions never crash on arbitrary input" do
    for {label, expr} <- @crash_safe_number do
      property "#{label}" do
        check all(value <- any_value()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "enum functions never crash on arbitrary input" do
    for {label, expr} <- @crash_safe_enum do
      property "#{label}" do
        check all(value <- any_value()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end

  describe "other functions never crash on arbitrary input" do
    for {label, expr} <- @crash_safe_other do
      property "#{label}" do
        check all(value <- any_value()) do
          assert_no_crash(unquote(expr), %{"value" => value})
        end
      end
    end
  end
end
