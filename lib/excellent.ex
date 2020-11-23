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

  identifier =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> reduce({Enum, :join, []})

  plus = string("+")
  minus = string("-")
  multiply = string("*")
  divide = string("/")
  exponent = string("^")

  eq = string("=")
  neq = string("<>")
  gt = string(">")
  gte = string(">=")
  lt = string("<")
  lte = string("<=")

  operator =
    choice([
      plus,
      minus,
      multiply,
      divide,
      exponent,
      neq,
      eq,
      gte,
      gt,
      lte,
      lt
    ])
    |> tag(:operator)

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

  function_argument =
    choice([
      parsec(:function),
      field,
      value
    ])

  function_arguments =
    function_argument
    |> repeat(
      ignore(space)
      |> ignore(string(","))
      |> ignore(space)
      |> concat(function_argument)
    )

  block_argument =
    choice([
      parsec(:function),
      operator,
      value,
      field
    ])

  block_arguments =
    block_argument
    |> repeat(
      ignore(space)
      |> concat(block_argument)
    )

  substitution =
    ignore(opening_substitution)
    |> concat(
      choice([
        parsec(:function),
        field
      ])
    )
    |> tag(:substitution)

  block =
    ignore(opening_block)
    |> ignore(space)
    |> lookahead_not(closing_block)
    |> concat(block_arguments)
    |> ignore(space)
    |> ignore(closing_block)
    |> tag(:block)

  defcombinatorp(
    :function,
    identifier
    |> concat(ignore(function_open))
    |> optional(tag(function_arguments, :arguments))
    |> concat(ignore(function_close))
    |> tag(:function)
  )

  defparsec(:parse_function, parsec(:function))
  defparsec(:parse_substitution, substitution)
  defparsec(:parse_block, block)
  # defcombinatorp(:expression, repeat(choice([block, substitution, text])))
  defparsec(
    :parse,
    repeat(
      choice([
        block,
        substitution,
        text
      ])
    )
  )
end
