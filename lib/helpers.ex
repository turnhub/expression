defmodule Excellent.Helpers do
  import NimbleParsec

  def decimal do
    integer(min: 1)
    |> ignore(string("."))
    |> integer(min: 1)
  end

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
    |> optional(string("Z"))
  end

  def iso_datetime do
    iso_date()
    |> ignore(string("T"))
    |> concat(iso_time())
  end

  def datetime do
    choice([
      iso_datetime(),
      us_datetime()
    ])
  end

  def boolean_true do
    choice([string("t"), string("T")])
    |> choice([string("r"), string("R")])
    |> choice([string("u"), string("U")])
    |> choice([string("e"), string("E")])
    |> map({String, :downcase, []})
    |> reduce({Enum, :join, [""]})
    |> map(:cast_boolean)
  end

  def boolean_false do
    choice([string("f"), string("F")])
    |> choice([string("a"), string("A")])
    |> choice([string("l"), string("L")])
    |> choice([string("s"), string("S")])
    |> choice([string("e"), string("E")])
    |> map({String, :downcase, []})
    |> reduce({Enum, :join, [""]})
    |> map(:cast_boolean)
  end

  def boolean do
    choice([
      boolean_true(),
      boolean_false()
    ])
  end

  def cast_boolean("true"), do: true
  def cast_boolean("false"), do: false
  def cast_boolean(binary), do: binary |> String.downcase() |> cast_boolean()
end
