defmodule Excellent do
  @moduledoc """
  Documentation for `Excellent`, a library to parse and evaluate
  [Floip](https://floip.gitbook.io/flow-specification/expressions) compatible expressions

  Excellent is an expression language which consists of the functions provided
  by Excel with a few additions.

  Function and variable names are not case-sensitive so UPPER is equivalent to upper:

  ```
  contact.name -> Marshawn Lynch
  FIRST_WORD(contact.name) -> Marshawn
  first_word(CONTACT.NAME) -> Marshawn
  ```

  For templating, RapidPro uses the @ character to denote either a single variable substitution
  or the beginning of an Excellent block. `@` was chosen as it is known how to type by a broad
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
  alias Excellent.{Ast, Eval}

  def parse_expression(expression) do
    case Ast.aexpr(expression) do
      {:ok, ast, "", _, _, _} ->
        {:ok, ast}

      {:ok, _ast, remainder, _, _, _} ->
        {:error, "Unable to parse: #{inspect(remainder)}"}
    end
  end

  def parse(text) do
    case Ast.parse(text) do
      {:ok, ast, "", _, _, _} ->
        {:ok, ast}

      {:ok, _ast, remainder, _, _, _} ->
        {:error, "Unable to parse: #{inspect(remainder)}"}
    end
  end

  def evaluate(text, context \\ %{}, mod \\ Excellent.Callbacks)

  def evaluate(text, context, mod) do
    with {:ok, ast} <- parse(text),
         {:ok, result} <- Eval.evaluate(ast, context, mod) do
      {:ok, result}
    end
  end
end
