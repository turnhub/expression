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

  ## v2-compat mode

  All evaluation entry points accept a trailing options list. Passing
  `mode: :v2` restores the v2 evaluation semantics that changed in v3
  (context key lowercasing and string value coercion):

  ```
  Expression.evaluate_as_string!("@date", %{"date" => "2020-12-13T23:34:45"}, mod, mode: :v2)
  ```

  See `t:evaluation_opts/0` for the individual flags.
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

  @typedoc """
  Options accepted by the evaluation entry points.

  `mode: :v2` expands to the v2-compat flags:
  `lowercase_keys: true, coerce_strings: true`. Explicitly passed flags win
  over the expansion. `mode: :v3` (or omitting `:mode`) keeps the v3
  defaults.

    * `:lowercase_keys` / `:coerce_strings` - see `Expression.Context.new/2`.

  Note: v2's operator semantics need no compat flags — the parser collapses
  `=` and `==` into the same operator in both v2 and v3, so the documented
  v2 "date-only `=`" behavior was unreachable dead code and evaluation
  semantics beyond context normalization are unchanged.
  """
  @type evaluation_opts :: [
          mode: :v2 | :v3,
          lowercase_keys: boolean(),
          coerce_strings: boolean()
        ]

  @v2_mode_opts [lowercase_keys: true, coerce_strings: true]

  @spec normalize_opts(evaluation_opts()) :: Keyword.t()
  defp normalize_opts(opts) do
    case Keyword.pop(opts, :mode) do
      {:v2, rest} -> Keyword.merge(@v2_mode_opts, rest)
      {_v3_or_nil, rest} -> rest
    end
  end

  def evaluate_block!(
        expression,
        context \\ %{},
        mod \\ Expression.Callbacks,
        opts \\ []
      ) do
    opts = normalize_opts(opts)
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
    e in Expression.Error -> {:error, e}
  end

  def evaluate!(expression, context \\ %{}, mod \\ Expression.Callbacks, opts \\ []) do
    opts = normalize_opts(opts)

    expression
    |> parse!
    |> Eval.eval!(Context.new(context, opts), mod)
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
          module(),
          evaluation_opts()
        ) :: String.t()
  def evaluate_as_string!(expression, context \\ %{}, mod \\ Expression.Callbacks, opts \\ [])

  def evaluate_as_string!(nil, _context, _mod, _opts), do: ""

  def evaluate_as_string!(expression, context, mod, opts) do
    opts = normalize_opts(opts)

    expression
    |> parse!
    |> Eval.eval!(Context.new(context, opts), mod)
    |> Eval.default_value(handle_not_found: true)
    |> stringify()
  end

  def evaluate_as_boolean!(expression, context \\ %{}, mod \\ Expression.Callbacks, opts \\ []) do
    case evaluate!(expression, context, mod, opts) do
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

  def evaluate(expression, context \\ %{}, mod \\ Expression.Callbacks, opts \\ []) do
    {:ok, evaluate!(expression, context, mod, opts)}
  rescue
    e in Expression.Error -> {:error, e}
  end

  @doc """
  Build the legacy error map shape used by callbacks to signal recoverable
  errors that should flow through evaluation as a value.

  New code should raise `Expression.Error` instead. This helper exists for
  callbacks that need to return an error sentinel without halting evaluation.
  """
  @spec error_map(message :: term) :: %{required(String.t()) => term}
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

  Raises `Expression.Error` on parse or evaluation failures.

  ## Examples

      iex> Expression.evaluate_template!("hello @name", %{"name" => "world"})
      "hello world"

      iex> Expression.evaluate_template!("1 + 1 = @(1 + 1)", %{})
      "1 + 1 = 2"

  """
  @spec evaluate_template!(String.t(), map(), module(), evaluation_opts()) :: String.t()
  def evaluate_template!(template, context \\ %{}, mod \\ Expression.Callbacks, opts \\ []) do
    evaluate_as_string!(template, context, mod, opts)
  end

  defdelegate prewalk(ast, fun), to: Macro
  defdelegate traverse(ast, acc, pre, post), to: Macro
end
