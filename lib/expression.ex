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

  @behaviour Expression.Behaviour

  defdelegate evaluate!(expression, context, callback), to: Expression.V1
  defdelegate evaluate_as_string!(expression, context, callback), to: Expression.V1
  defdelegate evaluate_block!(expression, context, callback), to: Expression.V1
end
