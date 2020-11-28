defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`.
  """
  import NimbleParsec
  import Excellent.{BooleanHelpers, DateHelpers, LiteralHelpers, OperatorHelpers}

  # Taking inspiration from https://github.com/slapers/ex_sel/
  # and trying to wrap my head around the grammer using EBNF as per
  # https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form

  # <alpha>         = "a".."z" | "A".."Z"
  # <digit>         = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
  # <integer>       = ["-"], digit, {digit}
  # <decimal>       = ["-"], integer, ".", integer
  # <alphanum>      = alpha | digit
  # <true>          = "t" | "T", "r" | "R", "u" | "U", "e" | "E"
  # <false>         = "f" | "F", "a" | "A", "l" | "L", "s" | "S", "e" | "E"
  # <boolean>       = true | false
  # <name>          = alpha, {alphanum | digit | "_" | "-" }
  # <variable>      = name, {[".", name]}

  # <substitution>  = "@", expression
  # <expression>    = block | function | variable
  # <string>        = ["'], [utf8], ["']
  # <arithmatic>    = "+" | "-" | "*" | "/" | "^" | "&"
  # <comparison>    = "=" | "<>" | ">" | ">=" | "<" | "<="
  # <operator>      = arithmatic | comparison
  # <literal>       = string | integer | decimal | boolean

  # <block_arg>     = function | name | literal
  # <block>         = "(", block_arg, [{operator, block_arg}], ")"

  # <function_arg>  = function | name | literal
  # <function>      = name, "(", [function_arg, {", ", function_arg}] , ")"

  opening_substitution = string("@")
  opening_bracket = string("(")
  closing_bracket = string(")")
  dot = string(".")
  space = string(" ") |> times(min: 0)

  name =
    ascii_string([?a..?z, ?A..?Z], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> reduce({Enum, :join, []})

  defcombinator(
    :variable,
    name
    |> repeat(ignore(dot) |> concat(name))
    |> tag(:variable)
  )

  defcombinator(
    :literal,
    choice([
      datetime(),
      decimal(),
      int(),
      boolean(),
      single_quoted_string(),
      double_quoted_string()
    ])
    |> tag(:literal)
  )

  block_argument =
    choice([
      parsec(:function),
      parsec(:literal),
      parsec(:variable)
    ])

  defcombinator(
    :block_arguments,
    block_argument
    |> repeat(
      ignore(space)
      |> concat(operator())
      |> ignore(space)
      |> concat(block_argument)
    )
  )

  defcombinator(
    :block,
    ignore(opening_bracket)
    |> ignore(space)
    |> lookahead_not(closing_bracket)
    |> concat(parsec(:block_arguments))
    |> ignore(space)
    |> ignore(closing_bracket)
    |> tag(:block)
  )

  function_argument =
    choice([
      parsec(:function),
      parsec(:variable),
      parsec(:literal)
    ])

  defcombinator(
    :function_arguments,
    function_argument
    |> repeat(
      ignore(space)
      |> ignore(string(","))
      |> ignore(space)
      |> concat(function_argument)
    )
  )

  defcombinator(
    :function,
    name
    |> ignore(opening_bracket)
    |> optional(
      ignore(space)
      |> lookahead_not(closing_bracket)
      |> concat(parsec(:function_arguments))
    )
    |> ignore(closing_bracket)
    |> tag(:function)
  )

  defcombinator(
    :expression,
    choice([
      parsec(:block),
      parsec(:function),
      parsec(:variable)
    ])
  )

  defcombinator(
    :text,
    empty()
    |> lookahead_not(opening_substitution)
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})
    |> tag(:text)
  )

  defcombinator(
    :substitution,
    ignore(opening_substitution)
    |> parsec(:expression)
    |> tag(:substitution)
  )

  defparsec(
    :parse,
    repeat(
      choice([
        parsec(:substitution),
        parsec(:text)
      ])
    )
  )

  def evaluate(expression, context \\ %{})

  def evaluate(expression, context) do
    case parse(expression) do
      {:ok, ast, "", _, _, _} ->
        {:ok,
         evaluate_ast(ast, context)
         |> Enum.reverse()
         |> Enum.map(&to_string/1)
         |> Enum.join("")}

      {:ok, _ast, remainder, _, _, _} ->
        {:error, "Unable to parse: #{inspect(remainder)}"}
    end
  end

  def evaluate_ast(ast, context) do
    Enum.reduce(ast, [], fn {type, args}, acc ->
      [partial_ast(type, args, context) |> unwrap() | acc]
    end)
  end

  def unwrap([value]), do: value
  # some literals are already unwrapped
  def unwrap(value), do: value

  def partial_ast(:substitution, substitution, context),
    do: evaluate_ast(substitution, context)

  def partial_ast(:text, text, _context), do: text
  def partial_ast(:literal, literal, _context), do: literal
  def partial_ast(:variable, args, context), do: get_in(context, args) || ""

  def partial_ast(:block, args, context),
    do: evaluate_block(args, context)

  def evaluate_block([a, {:operator, [op]}, b], context) do
    case op do
      "+" ->
        (evaluate_ast([a], context) |> unwrap()) +
          (evaluate_ast([b], context) |> unwrap())

      "*" ->
        (evaluate_ast([a], context) |> unwrap()) *
          (evaluate_ast([b], context) |> unwrap())
    end
  end

  def evaluate_block(args, context), do: evaluate_ast(args, context)
end
