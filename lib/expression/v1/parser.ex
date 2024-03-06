defmodule Expression.V1.Parser do
  @moduledoc """
  Expression.Parser is responsible for accepting a string
  containing an expression and returning the abstract syntax
  tree (AST) representing the expression.

  The AST generated by this module can be evaluated by
  Expression.Eval

  # Example

    iex(1)> Expression.V1.Parser.parse("hello @world")
    {:ok, [text: "hello ", expression: [atom: "world"]], "", %{}, {1, 0}, 12}

  """
  import NimbleParsec
  import Expression.V1.BooleanHelpers
  import Expression.V1.DateHelpers
  import Expression.V1.LiteralHelpers
  import Expression.V1.OperatorHelpers

  # literal = 1, 2.1, "three", 'four', true, false, ISO dates
  defparsec(
    :literal,
    choice([
      datetime(),
      date(),
      time(),
      float(),
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

  range =
    int()
    |> ignore(string(".."))
    |> concat(int())
    |> optional(
      ignore(string("//"))
      |> concat(int())
    )
    |> tag(:range)

  whitespace = choice([string(" "), string("\n"), string("\r")])

  ignore_surrounding_whitespace = fn p ->
    ignore(repeat(whitespace))
    |> concat(p)
    |> ignore(repeat(whitespace))
  end

  # argument separator = ", "
  argument_separator =
    string(",")
    |> ignore_surrounding_whitespace.()

  lambda_capture =
    ignore(string("&"))
    |> concat(int())
    |> unwrap_and_tag(:capture)

  # arguments = expression "," expression
  defparsec(
    :arguments,
    parsec(:aexpr)
    |> optional(ignore(argument_separator) |> parsec(:arguments))
  )

  primitives =
    choice([
      lambda_capture,
      range,
      parsec(:lambda),
      parsec(:function),
      parsec(:literal),
      parsec(:variable),
      parsec(:list)
    ])

  defparsec(
    :aexpr_factor,
    choice([
      primitives,
      ignore(string("(")) |> parsec(:aexpr) |> ignore(string(")"))
    ])
    |> ignore_surrounding_whitespace.()
  )

  defparsec(
    :key,
    ignore(ascii_char([91]))
    |> replace(:key)
    |> parsec(:aexpr)
    |> ignore(ascii_char([93]))
    |> label("[..]")
  )

  defparsec(
    :attribute,
    ascii_char([?.])
    |> replace(:attribute)
    |> label(".")
  )

  attribute_or_key =
    repeat(
      choice([
        parsec(:attribute) |> parsec(:aexpr_factor),
        parsec(:key)
      ])
    )

  # The difference between this one and the one above
  # is that this one does not allow for spaces or arithmatic
  # which makes it suitable for use in `@foo` type expressions
  # because otherwise `info@support.com for` (note the space)
  # is parsed as being part of the expression.
  #
  # That would be wrong since spaces are only allowed in
  # expressions starting with brackets like `@( ... )`
  attribute_or_key_with_primitives_only =
    repeat(
      choice([
        parsec(:attribute) |> concat(primitives),
        parsec(:key)
      ])
    )

  defparsec(
    :aexpr_exponent,
    parsec(:aexpr_factor)
    |> optional(attribute_or_key)
    |> repeat(
      exponent()
      |> parsec(:aexpr_factor)
      |> optional(attribute_or_key)
    )
    |> reduce(:fold_infixl)
  )

  defparsec(
    :aexpr_term,
    parsec(:aexpr_exponent)
    |> repeat(
      choice([times(), divide()])
      |> ignore_surrounding_whitespace.()
      |> parsec(:aexpr_exponent)
    )
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
      |> ignore_surrounding_whitespace.()
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

  defparsec(
    :list,
    ignore(string("["))
    |> optional(parsec(:arguments) |> tag(:args))
    |> ignore(string("]"))
    |> tag(:list)
  )

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

  defparsec(
    :lambda,
    ignore(string("&"))
    |> optional(parsec(:arguments) |> tag(:args))
    |> tag(:lambda)
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
        parsec(:list),
        parsec(:function),
        parsec(:variable)
      ])
      |> optional(attribute_or_key_with_primitives_only)
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
