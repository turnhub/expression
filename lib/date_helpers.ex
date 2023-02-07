defmodule Expression.DateHelpers do
  @moduledoc false
  use Expression.TimezoneHelpers

  import NimbleParsec

  def date_separator(combinator \\ empty()) do
    combinator
    |> choice([
      string("-"),
      string("/")
    ])
  end

  def us_date(combinator \\ empty()) do
    combinator
    |> integer(2)
    |> ignore(date_separator())
    |> integer(2)
    |> ignore(date_separator())
    |> integer(4)
  end

  def us_time(combinator \\ empty()) do
    combinator
    |> integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> optional(ignore(string(":")))
    |> optional(integer(2))
  end

  def us_datetime(combinator \\ empty()) do
    combinator
    |> us_date()
    |> ignore(string(" "))
    |> concat(us_time())
  end

  def iso_date(combinator \\ empty()) do
    combinator
    |> integer(4)
    |> ignore(date_separator())
    |> integer(2)
    |> ignore(date_separator())
    |> integer(2)
  end

  def iso_time(combinator \\ empty()) do
    combinator
    |> integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> ignore(optional(string(".")))
    |> optional(integer(min: 1))
    |> choice([
      ignore(string("+")) |> integer(min: 1),
      string("Z") |> replace(0),
      empty()
    ])
  end

  def iso_datetime(combinator \\ empty()) do
    combinator
    |> iso_date()
    |> ignore(string("T"))
    |> concat(iso_time())
  end

  def date(combinator \\ empty()) do
    combinator
    |> choice([
      tag(us_date(), :us_format),
      tag(iso_date(), :iso_format)
    ])
    |> reduce(:to_date)
  end

  def datetime(combinator \\ empty()) do
    combinator
    |> choice([
      tag(us_datetime(), :us_format),
      tag(iso_datetime(), :iso_format)
    ])
    |> reduce(:to_date)
  end

  def to_date(opts) do
    values =
      case opts do
        [iso_format: parsed_value] ->
          values =
            [:year, :month, :day, :hour, :minute, :second, :microsecond, :utc_offset]
            |> Enum.zip(parsed_value)

          {microseconds, values} = Keyword.pop(values, :microsecond, 0)

          microsecond_entry =
            {microseconds,
             microseconds
             |> to_string()
             |> String.length()}

          Keyword.put(values, :microsecond, microsecond_entry)

        [us_format: parsed_value] ->
          [:day, :month, :year, :hour, :minute, :second]
          |> Enum.zip(parsed_value)
      end

    fields =
      [
        calendar: Calendar.ISO,
        hour: 0,
        minute: 0,
        second: 0,
        time_zone: "Etc/UTC",
        zone_abbr: "UTC",
        utc_offset: 0,
        std_offset: 0
      ]
      |> Keyword.merge(values)

    struct(DateTime, fields)
  end
end
