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

  Functions are expressed as:

  ```
  {"function name", [arg1, arg2]}
  ```

  Until we have a fixed scope of allowed functions, or if we can dynamically look up whether an
  `atom` is a function or a variable reference, we will need to rely on tuples to represent functions
  as otherwise the system has no means to distinguish the following AST as being a function call
  or a list as a variable:

  ```
  ["echo", [1, 2, 3]]
  ```

  Without being able to say _ahead_ of time whether or not `echo/1` is a known function, the
  system cannot reliable determine whether the result of this AST should be `["echo", [1, 2, 3]]`
  or the result of `echo(1, 2, 3)`.

  Variable references are single values.

  ```
  "contact"
  ```

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

  int =
    optional(string("-"))
    |> concat(ascii_string([?0..?9], min: 1))
    |> reduce({Enum, :join, [""]})
    |> map({String, :to_integer, []})

  # These are just regular floats, previous iteration used the
  # Decimal library but that just made some simple arithmetic
  # and comparisons more complicated than needed to be.
  float =
    optional(string("-"))
    |> integer(min: 1)
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
    |> reduce(:to_double_quoted_string)
  )

  # Helper to convert a 'hello' parsed by parsec(:single_quoted_string) into
  # a "hello"
  def to_double_quoted_string(charlist) when is_list(charlist),
    do: inspect(to_string(charlist))

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
    |> reduce(:as_function_tuple)

  lambda_capture =
    string("&")
    |> concat(integer(min: 1))
    |> reduce({Enum, :join, []})

  lambda =
    string("&")
    |> optional(ignore(string(" ")))
    |> choice([
      # either we get a block as a function
      function_arguments,
      # or we refer to a function directly
      wrap(parsec(:term_operator))
    ])
    |> reduce(:as_function_tuple)

  @doc false
  def as_function_tuple([binary]) when is_binary(binary), do: {binary, []}

  def as_function_tuple([binary, args]) when is_binary(binary) and is_list(args),
    do: {binary, args}

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

  # A block is a expression that can be parsed and is surrounded
  # by opening & closing brackets
  block =
    ignore(string("("))
    |> parsec(:term_operator)
    |> ignore(string(")"))

  # A term is the lowest level types in an Expression
  term =
    times(
      choice([
        label(datetime(), "a datetime"),
        label(date(), "a date"),
        label(time(), "a time"),
        label(range, "a range"),
        label(float, "a float"),
        label(int, "an integer"),
        label(string_with_quotes, "a quoted string"),
        label(lambda_capture, "a capture"),
        label(lambda, "an anonymous function"),
        label(function, "a function"),
        label(boolean, "a boolean"),
        label(atom, "an atom")
      ]),
      min: 1
    )

  # Properties are only allowed to be atoms
  # So if we have a foo.bar, `bar` is property the atom
  # If we allow more complicated types here it causes confusion
  # because in `foo.false`, `false` would be parsed as a boolean type
  property =
    times(
      replace(string("."), "__property__")
      |> concat(atom),
      min: 1
    )

  # We allow parsec operators here to allow expressions
  # to be evaluated and their result to be used as a key
  # to lookup an attribute value
  attribute =
    times(
      replace(string("["), "__attribute__")
      |> concat(parsec(:term_operator))
      |> ignore(string("]")),
      min: 1
    )

  property_or_attribute = repeat(choice([property, attribute]))

  # A compound term is either a term or a term made up of terms
  # using a list or a block which may or may not have a property
  # or an attribute
  #
  # As an example `foo.bar` calls the property `bar` on term `foo`.
  compound_term_with_property_or_attribute =
    choice([
      label(list, "a list"),
      label(block, "a group"),
      term
    ])
    |> optional(property_or_attribute)

  # The following operators determine the order of operations, as per
  # https://en.wikipedia.org/wiki/Order_of_operations

  # Normally this would also have root but we don't have a shorthand for that
  # and so rather than a list of options, this is just the exponent operator.
  # This has higher precedence.
  exponentiation_operator = string("^")

  # Multiplication & division is second
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
      string("<>"),
      string(">="),
      string(">"),
      string("!="),
      string("<="),
      string("<"),
      string("=="),
      replace(string("="), "==")
    ])

  # Below are the precedence parsers, each gives the higher precedence
  # a change to parse its things _before_ it itself attempts to do so.
  # This is how the precedence is guaranteed.

  # First operator precedence parser
  defparsecp(
    :exponentiation,
    compound_term_with_property_or_attribute
    |> label("an expression")
    |> repeat(
      exponentiation_operator
      |> label("an operator")
      |> ignore_surrounding_whitespace.()
      |> concat(compound_term_with_property_or_attribute)
    )
    |> reduce(:fold_infixl)
  )

  # Second operator precedence parser
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

  # Third operator precedence parser
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
    |> concat(wrap(reduce(compound_term_with_property_or_attribute, :fold_infixl)))

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
      [r, op], l -> {op, [l, r]}
    end)
  end

  @doc """
  Parse a block and return the AST
    
  ## Example
      
      iex> Expression.V2.Parser.expression("contact.age + 1")
      {:ok,  [{"+", [{"__property__", ["contact", "age"]}, 1]}], "", %{}, {1, 0}, 15}

  """
  defparsec(:expression, parsec(:term_operator))

  @doc """
  Parse an expression and return the AST

  ## Example
      
      iex> Expression.V2.Parser.parse("hello @world the time is @now()")
      {:ok, ["hello ", ["world"], " the time is ", [{"now", []}]], "", %{}, {1, 0}, 31}

  """
  defparsec(
    :parse,
    repeat(choice([text, escaped_at, expression_block, expression_shorthand, single_at]))
  )
end
