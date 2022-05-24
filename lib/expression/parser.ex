defmodule Expression.Parser do
  import NimbleParsec
  import Expression.BooleanHelpers
  import Expression.DateHelpers
  import Expression.LiteralHelpers
  import Expression.OperatorHelpers

  # literal = 1, 2.1, "three", 'four', true, false, ISO dates
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

  # atom = atom
  atom =
    ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> map({String, :downcase, []})
    |> reduce({Enum, :join, []})

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

  defparsec(
    :aexpr_factor,
    choice([
      parsec(:literal),
      parsec(:function),
      parsec(:variable),
      ignore(string("(")) |> parsec(:aexpr) |> ignore(string(")"))
    ])
    |> ignore_surrounding_whitespace.()
  )

  attribute =
    empty()
    |> ascii_char([?.])
    |> replace(:attribute)
    |> label(".")

  defparsec(
    :aexpr_exponent_or_attribute,
    parsec(:aexpr_factor)
    |> repeat(
      choice([exponent(), attribute])
      |> parsec(:aexpr_factor)
    )
    |> reduce(:fold_infixl)
  )

  defparsec(
    :aexpr_term,
    parsec(:aexpr_exponent_or_attribute)
    |> repeat(choice([times(), divide()]) |> parsec(:aexpr_exponent_or_attribute))
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

  # defparsec(
  #   :attribute,
  #   parsec(:aexpr)
  #   |> repeat(string(".") |> replace(:attribute) |> label("."))
  #   |> concat(atom)
  #   |> reduce(:fold_infixl)
  # )

  def fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  # function  = "(" arguments ")"
  defparsec(
    :function,
    atom
    |> unwrap_and_tag(:name)
    |> ignore(string("("))
    |> optional(parsec(:arguments) |> tag(:args))
    |> ignore(string(")"))
    |> tag(:function)
  )

  # variable = atom
  defparsec(
    :variable,
    atom
    |> unwrap_and_tag(:atom)
  )

  expression_block =
    ignore(string("@"))
    |> lookahead_not(string("@"))
    |> ignore(string("("))
    |> parsec(:aexpr)
    |> ignore(string(")"))
    |> tag(:expression)

  expression =
    ignore(string("@"))
    |> lookahead_not(string("@"))
    |> repeat(
      choice([
        attribute,
        parsec(:function),
        parsec(:variable)
      ])
    )
    |> reduce(:fold_infixl)
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
