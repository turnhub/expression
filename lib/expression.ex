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

  @type expression_type ::
          String.t()
          | number
          | map
          | DateTime.t()
          | Date.t()

  alias Expression.Context
  alias Expression.Eval
  alias Expression.Parser

  @spec parse_expression(String.t()) :: {:ok, Keyword.t()} | {:error, String.t()}
  def parse_expression(expression_block) do
    case Parser.aexpr(expression_block) do
      {:ok, ast, "", _, _, _} ->
        {:ok, ast}

      {:ok, _ast, remainder, _, _, _} ->
        {:error,
         "Unable to parse block: #{inspect(expression_block)}, remainder: #{inspect(remainder)}"}

      {:error, reason, problematic, _, _, _} ->
        {:error,
         "Unable to parse block: #{inspect(expression_block)}, reason: #{reason} in #{inspect(problematic)}"}
    end
  end

  @spec parse_expression!(String.t()) :: Keyword.t()
  def parse_expression!(expression_block) do
    case Parser.aexpr(expression_block) do
      {:ok, ast, "", _, _, _} ->
        ast

      {:ok, _ast, remainder, _, _, _} ->
        raise Expression.Error,
          type: :parse,
          message:
            "Unable to parse block: #{inspect(expression_block)}, remainder: #{inspect(remainder)}",
          expression: expression_block

      {:error, reason, problematic, _, _, _} ->
        raise Expression.Error,
          type: :parse,
          message:
            "Unable to parse block: #{inspect(expression_block)}, reason: #{reason} in #{inspect(problematic)}",
          expression: expression_block
    end
  end

  @spec escape(String.t()) :: String.t()
  def escape(expression) when is_binary(expression) do
    String.replace(expression, ~r/@([a-z]+)(\(|\.)?/i, "@@\\g{1}\\g{2}")
  end

  @spec parse!(String.t() | Number.t() | Time.t() | boolean()) :: Keyword.t()
  def parse!(expression) when is_number(expression), do: to_string(expression) |> parse!()
  def parse!(expression) when is_boolean(expression), do: to_string(expression) |> parse!()

  def parse!(expression) do
    expression = if time_struct?(expression), do: Time.to_string(expression), else: expression

    case Parser.parse(expression) do
      {:ok, ast, "", _, _, _} ->
        ast

      {:ok, _ast, remainder, _, _, _} ->
        raise Expression.Error,
          type: :parse,
          message: "Unable to parse expression: #{expression}, remainder: #{inspect(remainder)}",
          expression: to_string(expression)
    end
  end

  @spec time_struct?(String.t() | Time.t()) :: boolean
  def time_struct?(value), do: is_struct(value, Time)

  def evaluate_block!(
        expression,
        context \\ %{},
        mod \\ Expression.Callbacks,
        opts \\ []
      ) do
    ast = parse_expression!(expression)
    Eval.eval!([expression: ast], Context.new(context, opts), mod)
  rescue
    e in Expression.Error ->
      reraise e, __STACKTRACE__

    e in RuntimeError ->
      reraise Expression.Error,
              [type: :eval, message: e.message, expression: expression],
              __STACKTRACE__
  end

  def evaluate_block(expression, context \\ %{}, mod \\ Expression.Callbacks, opts \\ []) do
    {:ok, evaluate_block!(expression, context, mod, opts)}
  rescue
    e in Expression.Error -> {:error, e.message}
    e in RuntimeError -> {:error, e.message}
  end

  def evaluate!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    expression
    |> parse!
    |> Eval.eval!(Context.new(context), mod)
    |> Eval.default_value()
  rescue
    e in Expression.Error ->
      reraise e, __STACKTRACE__

    e in RuntimeError ->
      reraise Expression.Error,
              [type: :eval, message: e.message, expression: expression],
              __STACKTRACE__
  end

  @spec evaluate_as_string!(
          String.t() | Number.t() | nil,
          map(),
          module()
        ) :: String.t()
  def evaluate_as_string!(expression, context \\ %{}, mod \\ Expression.Callbacks)

  def evaluate_as_string!(nil, _context, _mod), do: ""

  def evaluate_as_string!(expression, context, mod) do
    expression
    |> parse!
    |> Eval.eval!(Context.new(context), mod)
    |> Eval.default_value(handle_not_found: true)
    |> stringify()
  end

  def evaluate_as_boolean!(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    case evaluate!(expression, context, mod) do
      boolean when is_boolean(boolean) ->
        boolean

      other ->
        raise Expression.Error,
          type: :type,
          message:
            "Expression #{inspect(expression)} did not return a boolean!, got #{inspect(other)} instead",
          expression: expression
    end
  end

  @doc """
  Convert an Expression type into a string.

  This function is applied to all values when `Expression.evaluate_as_string!/3` is called.
  """
  @spec stringify([expression_type] | expression_type) :: String.t()
  def stringify(items) when is_list(items), do: Enum.map_join(items, "", &stringify/1)
  def stringify(binary) when is_binary(binary), do: binary
  def stringify(%DateTime{} = date), do: DateTime.to_iso8601(date)
  def stringify(%Date{} = date), do: Date.to_iso8601(date)
  def stringify(map) when is_map(map), do: "#{inspect(map)}"
  def stringify(other), do: to_string(other)

  def evaluate(expression, context \\ %{}, mod \\ Expression.Callbacks) do
    {:ok, evaluate!(expression, context, mod)}
  rescue
    e in Expression.Error -> {:error, e.message}
    e in RuntimeError -> {:error, e.message}
  end

  @doc """
  Generate an error map.

  Deprecated: use `Expression.Error` exception struct instead.
  This function will be removed in a future major version.
  """
  @deprecated "Use %Expression.Error{type: :function, message: message} instead"
  @spec error(message :: term) :: %{required(String.t()) => term}
  def error(message), do: error_map(message)

  @doc false
  def error_map(message),
    do: %{
      "__type__" => "expression/v1error",
      "error" => true,
      "message" => to_string(message),
      "__value__" => nil
    }

  @doc """
  Evaluate a string as an expression template, resolving any `@variable`
  references and `@(expression)` blocks within it.

  This is the explicit version of the behavior that occurs implicitly when
  a string literal appears inside an expression (e.g., `"hello @name"`
  as an argument to a function). Use this when you need template resolution
  and want to be explicit about it.

  ## Examples

      iex> Expression.evaluate_template("hello @name", %{"name" => "world"})
      "hello world"

      iex> Expression.evaluate_template("1 + 1 = @(1 + 1)", %{})
      "1 + 1 = 2"

  """
  @spec evaluate_template(String.t(), map(), module()) :: String.t()
  def evaluate_template(template, context \\ %{}, mod \\ Expression.Callbacks) do
    evaluate_as_string!(template, context, mod)
  end

  defdelegate prewalk(ast, fun), to: Macro
  defdelegate traverse(ast, acc, pre, post), to: Macro
end
