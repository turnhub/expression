defmodule Expression.DateHelpers do
  @moduledoc false
  import NimbleParsec

  def us_date do
    integer(2)
    |> ignore(string("-"))
    |> integer(2)
    |> ignore(string("-"))
    |> integer(4)
  end

  def us_time do
    integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> optional(ignore(string(":")))
    |> optional(integer(2))
  end

  def us_datetime do
    us_date()
    |> ignore(string(" "))
    |> concat(us_time())
  end

  def iso_date do
    integer(4)
    |> ignore(string("-"))
    |> integer(2)
    |> ignore(string("-"))
    |> integer(2)
  end

  def iso_time do
    integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> ignore(string(":"))
    |> integer(2)
    |> ignore(optional(string(".")))
    |> optional(integer(min: 1))
    |> optional(
      choice([
        ignore(string("+")) |> integer(min: 1),
        string("Z") |> replace(0)
      ])
    )
  end

  def iso_datetime do
    iso_date()
    |> ignore(string("T"))
    |> concat(iso_time())
  end

  def datetime do
    choice([
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
