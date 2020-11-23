defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`.
  """
  import NimbleParsec
  import Excellent.{BooleanHelpers, DateHelpers}

  opening_block = string("@(")
  closing_block = string(")")

  function_open = string("(")
  function_close = string(")")

  identifier = ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 1)

  plus = tag(string("+"), :plus)
  minus = tag(string("-"), :minus)
  multiply = tag(string("*"), :multiply)
  divide = tag(string("/"), :divide)
  exponent = tag(string("^"), :exponent)

  operators =
    choice([
      plus,
      minus,
      multiply,
      divide,
      exponent
    ])

  eq = tag(string("="), :eq)
  neq = tag(string("<>"), :neq)
  gt = tag(string(">"), :gt)
  gte = tag(string(">="), :gte)
  lt = tag(string("<"), :lt)
  lte = tag(string("<="), :lte)

  logical =
    choice([
      neq,
      eq,
      gte,
      gt,
      lte,
      lt
    ])

  int =
    optional(minus)
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})

  decimal =
    optional(minus)
    |> concat(integer(min: 1))
    |> concat(string("."))
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({Decimal, :new, []})

  single_quoted_string =
    ignore(string(~s(')))
    |> repeat(
      lookahead_not(ascii_char([?']))
      |> choice([string(~s(\')), utf8_char([])])
    )
    |> ignore(string(~s(')))
    |> reduce({List, :to_string, []})

  double_quoted_string =
    ignore(string(~s(")))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([string(~s(\")), utf8_char([])])
    )
    |> ignore(string(~s(")))
    |> reduce({List, :to_string, []})

  dot_access =
    ignore(string("."))
    |> concat(identifier)

  field =
    identifier
    |> repeat(dot_access)
    |> tag(:field)

  value =
    choice([
      datetime(),
      decimal,
      int,
      boolean(),
      operators,
      logical,
      single_quoted_string,
      double_quoted_string
    ])
    |> unwrap_and_tag(:value)

  space =
    string(" ")
    |> times(min: 0)

  opening_substitution = string("@")

  text =
    lookahead_not(choice([opening_block, opening_substitution]))
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})
    |> tag(:text)

  argument =
    choice([
      value,
      field
    ])

  arguments = choice([parsec(:function), value, field])
  # |> repeat(
  #   ignore(space)
  #   |> ignore(string(","))
  #   |> ignore(space)
  #   |> concat(choice([parsec(:function), value, argument]))
  # )

  substitution =
    ignore(opening_substitution)
    |> concat(
      choice([
        parsec(:function),
        # argument
        tag(identifier, :field)
      ])
    )
    |> tag(:substitution)

  block =
    ignore(opening_block)
    |> ignore(space)
    |> lookahead_not(closing_block)
    |> concat(arguments)
    |> ignore(space)
    |> ignore(closing_block)
    |> tag(:block)

  defcombinatorp(
    :function,
    identifier
    |> concat(ignore(function_open))
    |> optional(tag(arguments, :arguments))
    |> concat(ignore(function_close))
    |> tag(:function)
  )

  defcombinatorp(:expression, repeat(choice([block, substitution, text])))
  defparsec(:parse, parsec(:expression) |> eos())
end
