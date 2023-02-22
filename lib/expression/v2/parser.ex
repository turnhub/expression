defmodule Expression.V2.Parser do
  @moduledoc """
  A NimbleParsec parser for FLOIP expressions.

  FLOIP Expressions consist of plain text and of blocks. Plain text is returned untouched
  but blocks are evaluated.

  Blocks are prefixed with an `@` sign. Blocks can either have expressions between brackets or 
  be used in a shorthand form when wanting to use a single function or variable substitution.

  As an example, the following are identical:

  * `@(now())` and `@now()`
  * `@contact.name` and `@(contact.name)`

  However, a full expression needs to be within brackets:

  `Tomorrow's is @(today().day + 1)`

  This parses it into an Abstract Syntax Tree (AST) which follows a style much like a Lisp would. 
  It parses expressions in [Infix notation](https://en.wikipedia.org/wiki/Infix_notation) such as 
  `1 + 1` and parses it into lists where the operator is the first element and the second element
  is the list of arguments for the operator.

  ```
  ["+", [1, 1]]
  ```

  Similarly, functions are expressed as:

  ```
  ["function name", [arg1, arg2]]
  ```

  Variable references are single value lists.

  ["contact"]

  This module provides two functions for parsing. `parse/2` which will parse a full FLOIP expression
  including text and blocks, and `expression/2` which will parse expression blocks.

  Internally `parse/2` refers to the same parsers as `expression/2` for things that are expressions.
  """
  import NimbleParsec
  import Expression.DateHelpers

  # Booleans can be spelled in any mixed case
  boolean_true =
    choice([string("t"), string("T")])
    |> choice([string("r"), string("R")])
    |> choice([string("u"), string("U")])
    |> choice([string("e"), string("E")])
    |> replace(true)

  boolean_false =
    choice([string("f"), string("F")])
    |> choice([string("a"), string("A")])
    |> choice([string("l"), string("L")])
    |> choice([string("s"), string("S")])
    |> choice([string("e"), string("E")])
    |> replace(false)

  boolean =
    choice([
      boolean_true,
      boolean_false
    ])

  # These are just regular floats, previous iteration used the
  # Decimal library but that just made some simple arithmatic
  # and comparisons more complicated than needed to be.
  float =
    integer(min: 1)
    |> string(".")
    # Using ascii string here instead of integer/2 to prevent us chopping
    # off leading zeros after the period.
    |> concat(ascii_string([?0..?9], min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_float, []})

  # This is yanked wholesale from the NimbleParsec docs
  # https://hexdocs.pm/nimble_parsec/NimbleParsec.html#repeat_while/4
  defparsecp(
    :double_quoted_string,
    ascii_char([?"])
    |> repeat_while(
      choice([
        ~S(\") |> string() |> replace(?"),
        utf8_char([])
      ]),
      {:not_double_quote, []}
    )
    |> ascii_char([?"])
    |> reduce({List, :to_string, []})
  )

  @doc false
  defp not_double_quote(<<?", _::binary>>, context, _, _), do: {:halt, context}
  defp not_double_quote(_, context, _, _), do: {:cont, context}

  defparsecp(
    :single_quoted_string,
    ignore(ascii_char([?']))
    |> repeat_while(
      choice([
        string(~S(\')) |> replace(?'),
        utf8_char([])
      ]),
      {:not_single_quote, []}
    )
    |> ignore(ascii_char([?']))
    |> reduce({List, :to_string, []})
  )

  @doc false
  def not_single_quote(<<?', _::binary>>, context, _, _), do: {:halt, context}
  def not_single_quote(_, context, _, _), do: {:cont, context}

  # We support single & double quoted strings.
  string_with_quotes =
    choice([
      parsec(:single_quoted_string),
      parsec(:double_quoted_string)
    ])

  # Atoms are names, these can be variable names or function names etc.
  atom =
    ascii_string([?a..?z, ?A..?Z, ?0..?9], min: 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> map({String, :downcase, []})
    |> reduce({Enum, :join, []})

  whitespace =
    choice([
      string(" "),
      string("\n"),
      string("\r")
    ])

  # Helper function to wrap parsers in, resulting in them ignoring
  # surrounding whitespace.
  #
  # This has to be an anonymous function otherwise the compiler cannot
  # find it during compilation steps.
  ignore_surrounding_whitespace = fn p ->
    ignore(repeat(whitespace))
    |> concat(p)
    |> ignore(repeat(whitespace))
  end

  list =
    ignore(string("["))
    |> wrap(
      repeat(
        parsec(:term_operator)
        |> optional(ignore(ignore_surrounding_whitespace.(string(","))))
      )
    )
    |> ignore(string("]"))

  function_arguments =
    ignore(string("("))
    |> wrap(
      repeat(
        parsec(:term_operator)
        |> optional(ignore(ignore_surrounding_whitespace.(string(","))))
      )
    )
    |> ignore(string(")"))

  function =
    atom
    |> concat(function_arguments)
    |> reduce(:ensure_list)

  lambda_capture =
    string("&")
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, []})

  lambda =
    string("&")
    |> choice([
      # either we get a block as a function
      function_arguments,
      # or we refer to a function directly
      wrap(parsec(:term_operator))
    ])
    |> reduce(:ensure_list)

  @doc false
  def ensure_list([binary]) when is_binary(binary), do: [binary, []]
  def ensure_list([binary, args]) when is_binary(binary) and is_list(args), do: [binary, args]

  range =
    integer(min: 1)
    |> ignore(string(".."))
    |> concat(integer(min: 1))
    |> optional(
      ignore(string("//"))
      |> concat(integer(min: 1))
    )
    |> reduce(:ensure_range)

  @doc false
  def ensure_range([first, last, step]), do: Range.new(first, last, step)
  def ensure_range([first, last]), do: Range.new(first, last)

  property =
    choice([function, atom])
    |> times(
      replace(string("."), :__property__)
      |> concat(choice([function, atom])),
      min: 1
    )

  attribute =
    choice([function, property, atom])
    |> times(
      replace(string("["), :__attribute__)
      |> concat(parsec(:term_operator))
      |> ignore(string("]")),
      min: 1
    )

  # The following operators determine the order of operations, as per
  # https://en.wikipedia.org/wiki/Order_of_operations

  # Normally this would also have root but we don't have a shorthand for that
  # and so rather than a list of options, this is just the exponent operator.
  # This has higher precendence.
  exponentiation_operator = string("^")

  # Multiplation & division is second
  multiplication_division_operator =
    choice([
      string("*"),
      string("/")
    ])

  # Addition & subtraction are last
  addition_subtraction_operator =
    choice([
      string("+"),
      string("-"),
      string(">="),
      string(">"),
      string("!="),
      string("<="),
      string("<"),
      string("=="),
      replace(string("="), "==")
    ])

  # A block is a expression that can be parsed and is surrounded
  # by opening & closing brackets
  block =
    ignore(string("("))
    |> parsec(:term_operator)
    |> ignore(string(")"))

  term =
    times(
      choice([
        label(datetime(), "a datetime"),
        label(date(), "a date"),
        label(time(), "a time"),
        label(range, "a range"),
        label(list, "a list"),
        label(float, "a float"),
        label(integer(min: 1), "an integer"),
        label(string_with_quotes, "a quoted string"),
        label(boolean, "a boolean"),
        label(attribute, "an attribute"),
        label(property, "a property"),
        label(lambda_capture, "a capture"),
        label(lambda, "an anonymous function"),
        label(function, "a function"),
        label(block, "a group"),
        label(atom, "an atom")
      ]),
      min: 1
    )

  # Below are the precendence parsers, each gives the higher precendence
  # a change to parse its things _before_ it itself attempts to do so.
  # This is how the precendence is guaranteed.

  # First operator precendence parser
  defparsecp(
    :exponentiation,
    term
    |> label("an expression")
    |> repeat(
      exponentiation_operator
      |> label("an operator")
      |> ignore_surrounding_whitespace.()
      |> concat(term)
    )
    |> reduce(:fold_infixl)
  )

  # Second operator precendence parser
  defparsecp(
    :multiplication_division,
    parsec(:exponentiation)
    |> repeat(
      multiplication_division_operator
      |> ignore_surrounding_whitespace.()
      |> concat(parsec(:exponentiation))
    )
    |> reduce(:fold_infixl)
  )

  # Third operator precendence parser
  defparsecp(
    :term_operator,
    parsec(:multiplication_division)
    |> repeat(
      addition_subtraction_operator
      |> ignore_surrounding_whitespace.()
      |> concat(parsec(:multiplication_division))
    )
    |> reduce(:fold_infixl)
  )

  # Parses a block such as `@(1 + 1)`
  expression_block =
    ignore(string("@"))
    |> concat(wrap(block))

  # Parsed a short hand such as `@now()`
  expression_shorthand =
    ignore(string("@"))
    |> concat(wrap(parsec(:term_operator)))

  single_at = string("@")

  # @@ should be treated as an @
  escaped_at =
    ignore(string("@"))
    |> string("@")

  # Parses any old text as long as it doesn't have
  # any @ expression markers
  text =
    empty()
    |> lookahead_not(string("@"))
    |> utf8_string([], 1)
    |> times(min: 1)
    |> reduce({Enum, :join, []})

  @doc false
  def fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> [op, [l, r]]
    end)
  end

  @doc """
  Parse a block and return the AST
    
  ## Example
      
      iex> Expression.V2.Parser.expression("contact.age + 1")
      {:ok, [["+", [[:__property__, ["contact", "age"]], 1]]], "", %{}, {1, 0}, 15}

  """
  defparsec(:expression, parsec(:term_operator))

  @doc """
  Parse an expression and return the AST

  ## Example
      
      iex> Expression.V2.Parser.parse("hello @world the time is @now()")
      {:ok, ["hello ", ["world"], " the time is ", [["now", []]]], "", %{}, {1, 0}, 31}

  """
  defparsec(
    :parse,
    repeat(choice([text, escaped_at, expression_block, expression_shorthand, single_at]))
  )
end