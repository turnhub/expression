defmodule Expression.Context do
  @moduledoc """

  A helper module for creating a context that can be
  used with Expression.Eval.

  ## Plain map context

  `new/2` returns a plain map with lowercased string keys and
  auto-coerced values. This is the legacy format and remains the
  default for backwards compatibility.

    iex> Expression.Context.new(%{foo: "bar"})
    %{"foo" => "bar"}
    iex> Expression.Context.new(%{FOO: "bar"})
    %{"foo" => "bar"}
    iex> Expression.Context.new(%{foo: %{bar: "baz"}})
    %{"foo" => %{"bar" => "baz"}}
    iex> Expression.Context.new(%{Foo: %{Bar: "baz"}})
    %{"foo" => %{"bar" => "baz"}}
    iex> Expression.Context.new(%{foo: %{bar: 1}})
    %{"foo" => %{"bar" => 1}}
    iex> Expression.Context.new(%{date: "2020-12-13T23:34:45"})
    %{"date" => ~U[2020-12-13 23:34:45.0Z]}
    iex> Expression.Context.new(%{boolean: "true"})
    %{"boolean" => true}
    iex> Expression.Context.new(%{float: 1.234})
    %{"float" => 1.234}
    iex> now = DateTime.utc_now()
    iex> ctx = Expression.Context.new(%{float: "1.234", nested: %{date: now}})
    iex> ctx["float"]
    1.234
    iex> now == ctx["nested"]["date"]
    true
    iex> Expression.Context.new(%{mixed: ["2020-12-13T23:34:45", 1, "true", "binary"]})
    %{"mixed" => [~U[2020-12-13 23:34:45.0Z], 1, true, "binary"]}

  ## Structured context with private state

  `build/2` returns an `%Expression.Context{}` struct that separates
  user-visible variables from callback-private state.

  Variable resolution (`@foo`) only reads from `vars`.
  Callbacks receive the full struct and can access `private` for
  trusted data (database records, tokens, internal IDs) that
  expression authors must not be able to read.

    iex> ctx = Expression.Context.build(%{name: "Jane"}, private: %{number: %{uuid: "abc"}})
    iex> ctx.vars["name"]
    "Jane"
    iex> ctx.private
    %{number: %{uuid: "abc"}}

  """

  defstruct vars: %{}, private: %{}

  @type t :: %__MODULE__{
          vars: map(),
          private: map()
        }

  @spec new(map, Keyword.t() | nil) :: map
  def new(ctx, opts \\ [])

  def new(%__MODULE__{} = ctx, _opts), do: ctx

  def new(ctx, opts) when is_map(ctx) do
    ctx
    # Ensure all keys are lower case strings
    |> Enum.map(&downcase_string_key/1)
    |> Enum.map(&iterate(&1, opts))
    |> Enum.into(%{})
  end

  @doc """
  Build a structured context with separate variable and private state compartments.

  Variable resolution (`@foo`) only reads from `vars`. Callbacks receive the
  full struct and can access `private` for trusted data that expression authors
  must not be able to read.

  ## Options

    * `:private` - a map of callback-only data (default: `%{}`)

  Any other options are passed through to `new/2` for variable normalization.

  ## Examples

      iex> ctx = Expression.Context.build(%{name: "Jane"}, private: %{token: "secret"})
      iex> ctx.vars["name"]
      "Jane"
      iex> ctx.private.token
      "secret"

  """
  @spec build(map, Keyword.t()) :: t
  def build(vars, opts \\ []) when is_map(vars) do
    {private, context_opts} = Keyword.pop(opts, :private, %{})

    %__MODULE__{
      vars: new(vars, context_opts),
      private: private
    }
  end

  defp downcase_string_key({key, value}), do: {String.downcase(to_string(key)), value}

  defp iterate({key, value}, opts) when is_map(value) or is_list(value) do
    {key, evaluate!(value, opts)}
  end

  # Implictly convert the string "0" as a number
  defp iterate({key, "0"}, _opts), do: {key, 0}

  defp iterate({key, value}, opts) when is_binary(value) do
    cond do
      # Prevent implicitly converting numbers starting with a zero
      # Only allows strings fully made of digits or decimals
      String.starts_with?(value, "0") and String.match?(value, ~r/^\d+(\.\d+)?$/) -> {key, value}
      Keyword.get(opts, :skip_context_evaluation?, false) -> {key, value}
      true -> {key, evaluate!(value, opts)}
    end
  end

  defp iterate({key, value}, _), do: {key, value}

  defp evaluate!(ctx, opts) when is_map(ctx) and not is_struct(ctx) do
    new(ctx, opts)
  end

  defp evaluate!(ctx, opts) when is_list(ctx) do
    Enum.map(ctx, &evaluate!(&1, opts))
  end

  defp evaluate!(binary, _) when is_binary(binary) do
    case Expression.Parser.literal(binary) do
      {:ok, [{:literal, literal}], "", _, _, _} -> literal
      # when we're not parsing the full literal
      {:ok, [{:literal, _literal}], _, _, _, _} -> binary
      # when we're getting something entirely unexpected
      {:error, _reason, _, _, _, _} -> binary
    end
  rescue
    ArgumentError -> binary
  end

  defp evaluate!(value, _), do: value
end
