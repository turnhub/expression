defmodule Expression.Parser do
  import NimbleParsec
  import Expression.BooleanHelpers
  import Expression.DateHelpers
  import Expression.LiteralHelpers
  import Expression.OperatorHelpers

  # literal = 1, 2.1, "three", 'four', true, false, ISO dates
  literal =
    choice([
      datetime(),
      decimal(),
      int(),
      boolean(),
      single_quoted_string(),
      double_quoted_string()
    ])
    |> unwrap_and_tag(:literal)

  # atom = atom
  atom =
    ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> map({String, :downcase, []})
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:atom)

  ignore_surrounding_whitespace = fn p ->
    ignore(optional(string(" ")))
    |> concat(p)
    |> ignore(optional(string(" ")))
  end

  # argument separator = ", "
  argument_separator =
    string(",")
    |> ignore_surrounding_whitespace.()

  # arguments = expression "," expression
  defparsec(
    :arguments,
    parsec(:aexpr)
    |> optional(ignore(argument_separator) |> parsec(:arguments))
  )

  # repeat(
  #   # choice([
  #   # expression,
  #   parsec(:aexpr),
  #   ignore(argument_separator)
  #   # ])
  # )
  # |> tag(:args)

  defcombinatorp(
    :aexpr_factor,
    choice([
      literal,
      parsec(:function),
      parsec(:variable),
      ignore(string("(")) |> parsec(:aexpr) |> ignore(string(")"))
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

  def fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  # attribute = expression "." atom
  # access = expression "[" expression  "]"

  defparsec(
    :attribute,
    ignore(string("."))
    |> concat(atom)
    |> optional(parsec(:attribute))
    |> tag(:attribute)
  )

  # function  = "(" arguments ")"
  defparsec(
    :function,
    atom
    |> tag(:name)
    |> ignore(string("("))
    |> optional(parsec(:arguments) |> tag(:args))
    |> ignore(string(")"))
    |> optional(parsec(:attribute))
    |> tag(:function)
  )

  # variable = atom
  defparsec(
    :variable,
    atom
    |> optional(parsec(:attribute))
    |> tag(:variable)
  )

  expression_block =
    ignore(string("@"))
    |> lookahead_not(string("@"))
    |> ignore(string("("))
    |> concat(parsec(:aexpr))
    |> ignore(string(")"))
    |> tag(:expression_block)

  expression =
    ignore(string("@"))
    |> lookahead_not(string("@"))
    |> concat(
      choice([
        parsec(:function),
        parsec(:variable)
      ])
    )
    |> tag(:expression)

  escaped_at =
    ignore(string("@"))
    |> string("@")
    |> unwrap_and_tag(:text)

  text =
    empty()
    |> lookahead_not(string("@"))
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:text)

  defparsec(:parse, repeat(choice([expression_block, expression, escaped_at, text])))
end
