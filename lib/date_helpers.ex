defmodule Expression.DateHelpers do
  @moduledoc false
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

  def plain_time(combinator \\ empty()) do
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
    |> concat(plain_time())
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

  def time(combinator \\ empty()) do
    combinator
    |> plain_time()
    |> reduce(:to_time)
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
    |> reduce(:to_datetime)
  end

  def to_time(parsed_values) do
    values =
      [:hour, :minute, :second]
      |> Enum.zip(parsed_values)

    Time.new!(values[:hour], values[:minute], values[:second] || 0)
  end

  def to_datetime(opts) do
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

  def to_date(opts) do
    values =
      case opts do
        [iso_format: parsed_value] ->
          Enum.zip([:year, :month, :day], parsed_value)

        [us_format: parsed_value] ->
          Enum.zip([:day, :month, :year], parsed_value)
      end

    Date.new!(values[:year], values[:month], values[:day])
  end

  @spec extract_dateish(DateTime.t() | Date.t() | String.t() | nil) :: Date.t() | nil
  def extract_dateish(date_time) when is_struct(date_time, DateTime), do: date_time
  def extract_dateish(date) when is_struct(date, Date), do: date
  def extract_dateish(nil), do: nil
  def extract_dateish({:not_found, _}), do: nil

  def extract_dateish(expression) when is_binary(expression) do
    expression = Regex.replace(~r/[a-z]/u, expression, "")

    case Expression.parse_expression(expression) do
      {:ok, [{:literal, datetime}]} when is_struct(datetime, DateTime) ->
        DateTime.to_date(datetime)

      {:ok, [{:literal, date}]} when is_struct(date, Date) ->
        date

      _other ->
        nil
    end
  end

  @spec extract_datetimeish(DateTime.t() | Date.t() | String.t() | nil) :: DateTime.t() | nil
  def extract_datetimeish(nil), do: nil
  def extract_datetimeish(date_time) when is_struct(date_time, DateTime), do: date_time

  def extract_datetimeish(date) when is_struct(date, Date),
    do: DateTime.new!(date, Time.new!(0, 0, 0, 0))

  def extract_datetimeish(expression) when is_binary(expression) do
    expression = Regex.replace(~r/[a-z]/u, expression, "")

    case Expression.parse_expression(expression) do
      {:ok, [{:literal, datetime}]} when is_struct(datetime, DateTime) ->
        datetime

      {:ok, [{:literal, date}]} when is_struct(date, Date) ->
        DateTime.new!(date, ~T[00:00:00])

      _other ->
        nil
    end
  end

  @spec extract_timeish(DateTime.t() | Time.t() | String.t()) :: Time.t() | nil
  def extract_timeish(datetime) when is_struct(datetime, DateTime),
    do: DateTime.to_time(datetime)

  def extract_timeish(time) when is_struct(time, Time),
    do: time

  def extract_timeish(expression) when is_binary(expression) do
    expression = Regex.replace(~r/[a-z\s]/u, expression, "")

    case Expression.parse_expression(expression) do
      {:ok, [{:literal, datetime}]} when is_struct(datetime, DateTime) ->
        DateTime.to_time(datetime)

      {:ok, [{:literal, time}]} when is_struct(time, Time) ->
        time

      {:ok, result} ->
        result

      _other ->
        nil
    end
  end
end
