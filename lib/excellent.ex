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
  # <block_arg>     = block | function | name | literal
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
    :aexpr_term,
    parsec(:aexpr_factor)
    |> repeat(choice([times(), divide()]) |> parsec(:aexpr_factor))
    |> reduce(:fold_infixl)
  )

  defparsec(
    :aexpr,
    parsec(:aexpr_term)
    |> repeat(choice([plus(), minus(), concatenate()]) |> parsec(:aexpr_term))
    |> reduce(:fold_infixl)
  )

  # block_argument =
  #   choice([
  #     parsec(:block),
  #     parsec(:function),
  #     parsec(:literal),
  #     # parsec(:variable),
  #     parsec(:aexpr),
  #   ])

  # defcombinator(
  #   :block_arguments,
  #   block_argument
  #   |> repeat(
  #     ignore(space)
  #     |> concat(block_argument)
  #   )
  # )

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
        resp =
          ast
          |> Enum.reduce([], fn
            {:substitution, ast}, acc ->
              [eval!(fold_infixl(ast), context) | acc]

            {:text, text}, acc ->
              [text | acc]
          end)

        case resp do
          [value] ->
            {:ok, value}

          values ->
            {:ok,
             values
             |> Enum.map(&to_string/1)
             |> Enum.reverse()
             |> Enum.join()}
        end

      {:ok, _ast, remainder, _, _, _} ->
        {:error, "Unable to parse: #{inspect(remainder)}"}
    end
  end

  def fold_infixl(acc) do
    acc
    |> Enum.reverse()
    |> Enum.chunk_every(2)
    |> List.foldr([], fn
      [l], [] -> l
      [r, op], l -> {op, [l, r]}
    end)
  end

  def eval!(ast, ctx \\ %{})
  def eval!(ast, _ctx) when is_number(ast), do: ast
  def eval!(ast, _ctx) when is_binary(ast), do: ast
  def eval!(ast, _ctx) when is_boolean(ast), do: ast
  def eval!({:variable, k}, ctx), do: get_var!(ctx, k)
  def eval!({:literal, value}, _ctx), do: value
  def eval!({:substitution, ast}, ctx), do: eval!(fold_infixl(ast), ctx)
  def eval!({:block, ast}, ctx), do: eval!(fold_infixl(ast), ctx)
  def eval!({:+, [a, b]}, ctx), do: eval!(a, ctx, :num) + eval!(b, ctx, :num)
  def eval!({:-, [a, b]}, ctx), do: eval!(a, ctx, :num) - eval!(b, ctx, :num)
  def eval!({:*, [a, b]}, ctx), do: eval!(a, ctx, :num) * eval!(b, ctx, :num)
  def eval!({:/, [a, b]}, ctx), do: eval!(a, ctx, :num) / eval!(b, ctx, :num)
  def eval!({:!, [a]}, ctx), do: not eval!(a, ctx, :bool)
  def eval!({:&&, [a, b]}, ctx), do: eval!(a, ctx, :bool) && eval!(b, ctx, :bool)
  def eval!({:||, [a, b]}, ctx), do: eval!(a, ctx, :bool) || eval!(b, ctx, :bool)
  def eval!({:>, [a, b]}, ctx), do: eval!(a, ctx, :num) > eval!(b, ctx, :num)
  def eval!({:>=, [a, b]}, ctx), do: eval!(a, ctx, :num) >= eval!(b, ctx, :num)
  def eval!({:<, [a, b]}, ctx), do: eval!(a, ctx, :num) < eval!(b, ctx, :num)
  def eval!({:<=, [a, b]}, ctx), do: eval!(a, ctx, :num) <= eval!(b, ctx, :num)
  def eval!({:==, [a, b]}, ctx), do: eval!(a, ctx) == eval!(b, ctx)
  def eval!({:!=, [a, b]}, ctx), do: eval!(a, ctx) != eval!(b, ctx)
  def eval!({:^, [a, b]}, ctx), do: :math.pow(eval!(a, ctx), eval!(b, ctx))

  defp eval!(ast, ctx, type), do: ast |> eval!(ctx) |> guard_type!(type)

  defp get_var!(ctx, k), do: get_in(ctx, k) |> guard_nil!(k)
  defp guard_nil!(nil, k), do: raise("variable #{k} undefined or null")
  defp guard_nil!(v, _), do: v

  defp guard_type!(v, :bool) when is_boolean(v), do: v
  defp guard_type!(v, :bool), do: raise("expression is not a boolean: `#{inspect(v)}`")
  defp guard_type!(v, :num) when is_number(v), do: v
  defp guard_type!(v, :num), do: raise("expression is not a number: `#{inspect(v)}`")

  # def evaluate_block([a, {:operator, [op]}, b], context) do
  #   IO.puts("hitting logic")

  #   case op do
  #     "+" ->
  #       (evaluate_ast([a], context) |> unwrap()) +
  #         (evaluate_ast([b], context) |> unwrap())

  #     "*" ->
  #       (evaluate_ast([a], context) |> unwrap()) *
  #         (evaluate_ast([b], context) |> unwrap())
  #   end
  # end

  # def evaluate_block(args, context) do
  #   IO.puts("catch all hit")
  #   IO.inspect(args, label: "args")
  #   evaluate_ast(args, context)
  # end
end
