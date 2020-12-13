defmodule Expression.Ast do
  @moduledoc """
  Parse a string and turn it into an AST which
  can be evaluated by Expression.Eval
  """
  import NimbleParsec
  import Expression.{BooleanHelpers, DateHelpers, LiteralHelpers, OperatorHelpers}

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
  # <block_arg>     = block | function | name | literal
  # <block>         = "(", block_arg, [{operator, block_arg}], ")"

  # <function_arg>  = function | name | literal
  # <function>      = name, "(", [function_arg, {", ", function_arg}] , ")"

  escaped_at = string("@@") |> tag(:escaped_at)
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

  defparsec(
    :literal,
    choice([
      datetime(),
      decimal(),
      int(),
      boolean(),
      single_quoted_string(),
      double_quoted_string()
    ])
    |> unwrap_and_tag(:literal)
  )

  ignore_surrounding_whitespace = fn p ->
    ignore(optional(space))
    |> concat(p)
    |> ignore(optional(space))
  end

  defcombinatorp(
    :aexpr_factor,
    choice([
      ignore(opening_bracket) |> parsec(:aexpr) |> ignore(closing_bracket),
      parsec(:literal),
      parsec(:function),
      parsec(:variable)
    ])
    |> ignore_surrounding_whitespace.()
  )

  defparsecp(
    :aexpr_exponent,
    parsec(:aexpr_factor)
    |> repeat(exponent() |> parsec(:aexpr_factor))
    |> reduce(:fold_infixl)
  )

  defparsecp(
    :aexpr_term,
    parsec(:aexpr_exponent)
    |> repeat(choice([times(), divide()]) |> parsec(:aexpr_exponent))
    |> reduce(:fold_infixl)
  )

  defparsec(
    :aexpr,
    parsec(:aexpr_term)
    |> repeat(
      choice([
        plus(),
        minus(),
        concatenate(),
        gte(),
        lte(),
        neq(),
        gt(),
        lt(),
        eq()
      ])
      |> parsec(:aexpr_term)
    )
    |> reduce(:fold_infixl)
  )

  defcombinator(
    :block,
    ignore(opening_bracket)
    |> ignore(space)
    |> lookahead_not(closing_bracket)
    |> concat(parsec(:aexpr))
    |> ignore(space)
    |> ignore(closing_bracket)
    |> tag(:block)
  )

  function_argument =
    choice([
      parsec(:aexpr),
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
    |> tag(:arguments)
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
        escaped_at,
        parsec(:substitution),
        parsec(:text)
      ])
    )
  )

  def fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end
end
