defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`.
  """
  import NimbleParsec
  import Excellent.{BooleanHelpers, DateHelpers, OperatorHelpers}

  opening_block = string("(")
  closing_block = string(")")

  function_open = string("(")
  function_close = string(")")

  # identifiers must start with a letter
  identifier =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> reduce({Enum, :join, []})

  int =
    optional(string("-"))
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})

  decimal =
    optional(string("-"))
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
    |> tag(:string)

  double_quoted_string =
    ignore(string(~s(")))
    |> repeat(
      lookahead_not(ascii_char([?"]))
      |> choice([string(~s(\")), utf8_char([])])
    )
    |> ignore(string(~s(")))
    |> reduce({List, :to_string, []})
    |> tag(:string)

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
    lookahead_not(opening_substitution)
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

  grouping =
    ignore(ascii_char([?(]))
    |> concat(parsec(:expression))
    |> ignore(ascii_char([?)]))

  block_argument =
    choice([
      parsec(:function),
      operator(),
      grouping,
      value,
      field
    ])

  block_arguments =
    block_argument
    |> repeat(
      ignore(space)
      |> concat(block_argument)
    )

  block =
    ignore(opening_block)
    |> ignore(space)
    |> lookahead_not(closing_block)
    |> concat(block_arguments)
    |> ignore(space)
    |> ignore(closing_block)
    |> tag(:block)

  substitution =
    ignore(opening_substitution)
    |> concat(
      choice([
        block,
        parsec(:function),
        field
      ])
    )
    |> tag(:substitution)

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

  defcombinatorp(
    :expression,
    empty()
    |> choice([
      parsec(:function),
      operator(),
      value,
      field
    ])
  )

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

  def evaluate(expression, context) do
    {:ok, ast, "", _, _, _} = parse(expression)

    {:ok,
     evaluate_ast(ast, context)
     |> Enum.reverse()
     |> Enum.map(&to_string/1)
     |> Enum.join("")}
  end

  def evaluate_ast(ast, context) do
    Enum.reduce(ast, [], fn {type, args}, acc ->
      [partial_ast(type, args, context) |> unwrap() | acc]
    end)
  end

  def unwrap([value]), do: value

  def partial_ast(:substitution, substitution, context),
    do: evaluate_ast(substitution, context)

  def partial_ast(:text, text, _context), do: text
  def partial_ast(:value, value, _context), do: value
  def partial_ast(:field, args, context), do: get_in(context, args) || ""

  def partial_ast(:block, args, context),
    do: evaluate_block(args, context)

  def evaluate_block([a, {:operator, [op]}, b], context) do
    case op do
      "+" ->
        (evaluate_ast([a], context) |> unwrap()) +
          (evaluate_ast([b], context) |> unwrap())
    end
  end

  def evaluate_block(args, context), do: evaluate_ast(args, context)
end
