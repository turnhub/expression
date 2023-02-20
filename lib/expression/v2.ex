defmodule Expression.V2 do
  @moduledoc """
  A second attempt at the parser, hopefully a little easier to read & maintain.

  `parse/1` parsed an Expression into AST.
  `eval/3` evaluates the given AST using the context and the callback module.

  For details on how this is done please read `Expression.V2.Parser` and
  `Expression.V2.Eval`.

  This parser & evaluator supports the following:

  * [strings](https://hexdocs.pm/elixir/typespecs.html#basic-types) either double or single quoted.
  * [integers](https://hexdocs.pm/elixir/typespecs.html#basic-types) such as `1`, `2`, `40`, `55`
  * [floats](https://hexdocs.pm/elixir/typespecs.html#basic-types) such as `3.141592653589793`
  * [booleans](https://hexdocs.pm/elixir/typespecs.html#basic-types) which can be written in any mixed case such as `tRue` or `TRUE`, `False` etc
  * `Range.t` such as `1..10`, also with steps `1..10//2`
  * `Date.t` such as `2022-01-01` which is parsed into `~D[2022-01-01]`
  * `Time.t` such as `10:30` which is parsed into `~T[10:30:00]`
  * ISO formatted `DateTime.t` such as `2022-05-24T00:00:00` which is parsed into `~U[2022-05-24 00:00:00.0Z]`
  * US formatted `DateTime.t` such as `01-02-2020 23:23:23` which is parsed into `~U[2020-02-01T23:23:23Z]`
  * Lists of any of the above, such as `[1, 2, 3]` or `[1, 1.234, "john"]`
  * Reading properties off of nested objects such as maps with a full stop, such as `contact.name` returning `"Doe"` from `%{"contact" => %{"name" => "Doe"}}`
  * Reading attributes off of maps, such as `contact[the_key]` which returns `"Doe"` from `%{"contact" => %{"name" => "Doe"}, "the_key" => "name"}`
  * Anonymous functions with `&` and `&1` as capture operators, `&(&1 + 1)` is an anonymous function that increments the input by 1.

  """
  alias Expression.V2.Eval
  alias Expression.V2.Parser

  @spec parse(String.t()) ::
          {:ok, [term]}
          | {:error, reason :: String.t(), bad_parts :: String.t()}
  def parse(expression) do
    case Parser.parse(expression) do
      {:ok, ast, "", _, _, _} ->
        {:ok, ast}

      {:ok, _ast, remaining, _, _, _} ->
        {:error, "Unable to parse remainder", remaining}
    end
  end

  @spec eval(String.t() | [term], context :: map, callback_module :: atom) :: [term]
  def eval(expression, context, callback_module) when is_binary(expression) do
    with {:ok, parts} <- parse(expression) do
      Enum.map(parts, fn
        part when is_list(part) -> eval([part], context, callback_module)
        other -> other
      end)
    end
  end

  def eval(ast, context, callback_module) when is_list(ast) do
    Eval.eval(ast, Enum.into(context, []), callback_module)
  end
end
