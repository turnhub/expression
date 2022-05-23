defmodule Expression.Parser do
  import NimbleParsec
  import Expression.LiteralHelpers
  import Expression.OperatorHelpers

  # literal = 1, 2.1, "three", 'four', true, false, ISO dates
  literal =
    choice([
      # datetime(),
      decimal(),
      int(),
      # boolean(),
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

  # variable = atom

  # expression = variable | literal | function_call
  expression =
    choice([
      literal,
      parsec(:function_call),
      parsec(:variable)
    ])

  # argument separator = ", "
  argument_separator =
    string(",")
    |> repeat(ignore(string(" ")))

  # arguments = expression "," expression
  arguments =
    repeat(
      choice([
        expression,
        ignore(argument_separator)
      ])
    )
    |> tag(:args)

  # function  = "(" arguments ")"
  defparsec(
    :function_call,
    atom
    |> tag(:name)
    |> ignore(string("("))
    |> optional(arguments)
    |> ignore(string(")"))
    |> tag(:function_call)
  )

  # attribute = expression "." atom
  # access = expression "[" expression  "]"

  attribute =
    expression
    |> tag(:subject)
    |> concat(ignore(string(".")))
    |> concat(atom)
    |> tag(:attribute)

  defparsec(:variable, atom)

  substitution =
    ignore(string("@"))
    |> concat(
      choice([
        parsec(:function_call),
        parsec(:variable)
      ])
    )
    |> optional(
      ignore(string("."))
      |> concat(parsec(:variable))
      |> tag(:attribute)
    )
    |> tag(:substitution)

  text =
    empty()
    |> lookahead_not(string("@"))
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})
    |> unwrap_and_tag(:text)

  defparsec(:parse, repeat(choice([text, substitution])))
end
