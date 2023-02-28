defmodule Expression.V2 do
  @moduledoc """
  A second attempt at the parser, hopefully a little easier to read & maintain.

  `parse/1` parsed an Expression into AST.
  `eval/3` evaluates the given AST using the context supplied.

  For details on how this is done please read `Expression.V2.Parser` and
  `Expression.V2.Compile`.

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

  The result of a call to `eval/3` is a list of typed evaluated items. It is up to the integrating library to determine how
  best to convert these into a final end user representation.

  # Examples

      iex> alias Expression.V2
      iex> V2.eval("the date is @date(2022, 2, 20)")
      ["the date is ", ~D[2022-02-20]]
      iex> V2.eval("the answer is @true")
      ["the answer is ", true]
      iex> V2.eval("22 divided by 7 is @(22 / 7)")
      ["22 divided by 7 is ", 3.142857142857143]
      iex> V2.eval(
      ...>   "Hello @proper(contact.name)! Looking forward to meet you @date(2023, 2, 20)", 
      ...>   V2.Context.new(%{"contact" => %{"name" => "mary"}})
      ...> )
      ["Hello ", "Mary", "! Looking forward to meet you ", ~D[2023-02-20]]
      iex> V2.eval("@map(1..3, &date(2023, 1, &1))")
      [[~D[2023-01-01], ~D[2023-01-02], ~D[2023-01-03]]]
      iex> V2.eval(
      ...>   "Here is the multiplication table of @number: @(map(1..10, &(&1 * number)))",
      ...>   V2.Context.new(%{"number" => 5})
      ...> )
      [
        "Here is the multiplication table of ",
        5,
        ": ",
        [5, 10, 15, 20, 25, 30, 35, 40, 45, 50]
      ]

  """

  alias Expression.V2.Compile
  alias Expression.V2.Context
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

  def parse_block(expression_block) do
    case Parser.expression(expression_block) do
      {:ok, ast, "", _, _, _} -> {:ok, ast}
      {:error, _ast, remaining, _, _, _} -> {:error, "Unable to parse remainder", remaining}
    end
  end

  @spec eval_block(String.t(), context :: Context.t()) :: term
  def eval_block(expression_block, context \\ Context.new()) do
    {:ok, ast} = parse_block(expression_block)
    function = Compile.compile(ast)
    function.(context)
  end

  @spec eval(String.t() | [term], context :: Context.t()) :: [term]
  def eval(expression_or_ast, context \\ Context.new())

  def eval(expression, context) when is_binary(expression) do
    ast = compile(expression)
    eval(ast, context)
  end

  def eval(ast, context) when is_list(ast) do
    Enum.map(ast, &eval(&1, context))
  end

  def eval(function, context) when is_function(function), do: function.(context)

  def eval(atom, context) when is_binary(atom),
    do: Map.get(context.vars, atom, atom)

  def eval(item, _context), do: item

  def eval_as_string(expression, context \\ Context.new()) do
    eval(expression, context)
    |> Enum.map(&default_value(&1, context))
    |> Enum.map(&stringify/1)
    |> Enum.join("")
  end

  @doc """
  Return the default value for a potentially complex value.

  Complex values can be Maps that have a `__value__` key, if that's
  returned then we can to use the `__value__` value when eval'ing against
  operators or functions.
  """
  def default_value(val, context \\ nil)
  def default_value(%{"__value__" => default_value}, _context), do: default_value
  def default_value(value, _context), do: value

  @spec stringify(term) :: String.t()
  def stringify(items) when is_list(items), do: Enum.map_join(items, "", &stringify/1)
  def stringify(binary) when is_binary(binary), do: binary
  def stringify(%DateTime{} = date), do: DateTime.to_iso8601(date)
  def stringify(%Date{} = date), do: Date.to_iso8601(date)
  def stringify(map) when is_map(map), do: "#{inspect(map)}"
  def stringify(other), do: to_string(other)

  @spec eval_part((Context.t() -> term) | term, Context.t()) :: term
  def eval_part(function, context) when is_function(function),
    do: function.(context)

  def eval_part(atom, context) when is_binary(atom),
    do: Map.get(context.vars, atom, atom)

  def eval_part(list, context) when is_list(list), do: Enum.map(list, &eval_part(&1, context))
  def eval_part(literal, _context), do: literal

  @spec compile(expression :: String.t()) :: [term]
  def compile(expression) when is_binary(expression) do
    with {:ok, parts} <- parse(expression),
         parts <- Enum.map([parts], &compile_block/1) do
      hd(parts)
    end
  end

  def compile_block({function_name, arguments})
      when is_binary(function_name) and is_list(arguments) do
    [{function_name, arguments}]
    |> Compile.compile()
    |> compile_block()
  end

  def compile_block(list) when is_list(list),
    do: Enum.map(list, &compile_block(&1))

  def compile_block(final), do: final

  @doc """
  Return the code generated for the Abstract Syntax tree or 
  Expression string provided.
  """
  @spec debug(String.t() | [term]) :: String.t()
  def debug(expression) when is_binary(expression) do
    with {:ok, ast, "", _, _, _} <- Parser.expression(expression) do
      debug(ast)
    end
  end

  def debug(ast) do
    ast
    |> Compile.to_quoted()
    |> Compile.wrap_in_context()
    |> Macro.to_string()
  end
end
