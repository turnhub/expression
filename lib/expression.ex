defmodule Expression do
  @moduledoc """
  Documentation for `Expression`, a library to parse and evaluate
  [Floip](https://floip.gitbook.io/flow-specification/expressions) compatible expressions

  Expression is an expression language which consists of the functions provided
  by Excel with a few additions.

  Function and variable names are not case-sensitive so UPPER is equivalent to upper:

  ```
  contact.name -> Marshawn Lynch
  FIRST_WORD(contact.name) -> Marshawn
  first_word(CONTACT.NAME) -> Marshawn
  ```

  For templating, RapidPro uses the @ character to denote either a single variable substitution
  or the beginning of an Expression block. `@` was chosen as it is known how to type by a broad
  number of users regardless of keyboard. It does have the disadvantage of being used in
  email addresses and Twitter handles, but these are rarely ambiguous and escaping can be
  done easily via doubling of the character (`@@`).

  Functions are called by using the block syntax:
  ```
  10 plus 4 is @(SUM(10, 4))
  ```

  Within a block, `@` is not required to refer to variable in the context:
  ```
  Hello @(contact.name)
  ```

  A template can contain more than one substitution or block:
  ```
  Hello @contact.name, you were born in @(YEAR(contact.birthday))
  ```

  """
  alias Expression.Context
  alias Expression.Eval
  alias Expression.Parser

  def parse_expression!(expression_block) do
    case Parser.aexpr(expression_block) do
      {:ok, ast, "", _, _, _} ->
        ast

      {:ok, _ast, remainder, _, _, _} ->
        raise "Unable to parse: #{inspect(remainder)}"

      {:error, reason, problematic, _, _, _} ->
        raise "#{reason} in #{inspect(problematic)}"
    end
  end

  def parse!(expression) do
    case Parser.parse(expression) do
      {:ok, ast, "", _, _, _} ->
        ast

      {:ok, _ast, remainder, _, _, _} ->
        raise "Unable to parse: #{inspect(remainder)}"
    end
  end

  def evaluate_block!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    ast = parse_expression!(expression)
    Eval.eval!([expression: ast], Context.new(context), mod)
  end

  def evaluate_block(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    {:ok, evaluate_block!(expression, context, mod)}
  rescue
    e in RuntimeError -> {:error, e.message}
  end

  def evaluate!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    expression
    |> parse!
    |> Eval.eval!(Context.new(context), mod)
    |> default_value()
  end

  def evaluate_as_string!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    expression
    |> parse!
    |> Eval.eval!(Context.new(context), mod)
    |> default_value(handle_not_found: true)
    |> stringify()
  end

  def evaluate_as_boolean!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    case evaluate!(expression, context, mod) do
      boolean when is_boolean(boolean) ->
        boolean

      other ->
        raise "Expression #{inspect(expression)} did not return a boolean!, got #{inspect(other)} instead"
    end
  end

  defp stringify(items) when is_list(items), do: Enum.map_join(items, "", &to_string/1)
  defp stringify(binary) when is_binary(binary), do: binary
  defp stringify(%DateTime{} = date), do: DateTime.to_iso8601(date)
  defp stringify(%Date{} = date), do: Date.to_iso8601(date)
  defp stringify(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
  defp stringify(other), do: to_string(other)

  defp default_value(val, opts \\ [])
  defp default_value(%{"__value__" => default_value}, _opts), do: default_value

  defp default_value({:not_found, attributes}, opts) do
    if(opts[:handle_not_found], do: "@#{Enum.join(attributes, ".")}", else: nil)
  end

  defp default_value(items, opts) when is_list(items),
    do: Enum.map(items, &default_value(&1, opts))

  defp default_value(value, _opts), do: value

  def evaluate(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    {:ok, evaluate!(expression, context, mod)}
  rescue
    e in RuntimeError -> {:error, e.message}
  end
end
