defmodule Expression.Autodoc do
  @moduledoc """

  Extract `@expression_doc` attributes from modules defining callbacks
  and automatically write doctests for those.

  Also inserts an `expression_docs()` function which returns a list of
  all functions and their defined expression docs.

  The format is:

  ```elixir
  @expression_doc doc: "Construct a date from year, month, and day integers",
                  expression: "@date(year, month, day)",
                  context: %{"year" => 2022, "month" => 1, "day" => 31},
                  result: "2022-01-31T00:00:00Z"
  ```

  Where:

  * `doc` is the explanatory text added to the doctest.
  * `expression` is the expression we want to test
  * `context` is the context the expression is tested against
  * `result` is the result we're expecting to get and are asserting against

  """
  defmacro __using__(_args) do
    quote do
      @expression_docs []
      Module.register_attribute(__MODULE__, :expression_doc, accumulate: true)
      @on_definition Expression.Autodoc
      @before_compile Expression.Autodoc

      import Expression.Autodoc
      require Expression.Autodoc
    end
  end

  def __on_definition__(env, :def, name, args, _guards, _body),
    do: annotate_method(env.module, name, args)

  def __on_definition__(_env, _kind, _name, _args, _guards, _body), do: nil

  def annotate_method(module, function, args) do
    if expression_doc = Module.delete_attribute(module, :expression_doc) do
      update_annotations(module, function, args, expression_doc)
    end
  end

  def update_annotations(module, function, args, []) do
    existing_expression_docs = Module.get_attribute(module, :expression_docs)

    {_line_number, doc} = get_existing_docstring(module)

    Module.put_attribute(module, :expression_docs, [
      {format_function_name(function), format_function_args(args), doc, []}
      | existing_expression_docs
    ])
  end

  def update_annotations(module, function, args, expression_docs) do
    existing_expression_docs = Module.get_attribute(module, :expression_docs)

    {line_number, doc} = get_existing_docstring(module)

    expression_doc_tests =
      expression_docs
      |> Enum.reverse()
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {expression_doc, index} ->
        """
        ## Example #{index}:

          > #{expression_doc[:doc]}

        When used as a Stack expression it returns a #{format_result(expression_doc[:result])}#{format_context(expression_doc[:context])}.

        ```
        #{expression_doc[:expression]}
        ```

        When used as an expression in text, prepend it with an `@`:

        ```expression
        > "... @#{expression_doc[:expression]} ..."
        "#{stringify(expression_doc[:result])}"
        ```

            iex> Expression.evaluate_block!(
            ...>   #{inspect(expression_doc[:expression])},
            ...>   #{inspect(expression_doc[:context] || %{})}
            ...> )
            #{inspect(expression_doc[:result])}

            iex> Expression.evaluate_as_string!(
            ...>   #{inspect("@" <> expression_doc[:expression])},
            ...>   #{inspect(expression_doc[:context] || %{})}
            ...> )
            #{inspect(stringify(expression_doc[:result]))}

        ---

        """
      end)

    updated_docs =
      case doc do
        nil -> expression_doc_tests
        doc -> "#{doc}\n\n#{expression_doc_tests}"
      end

    Module.put_attribute(
      module,
      :doc,
      {line_number, updated_docs}
    )

    Module.put_attribute(module, :expression_docs, [
      {format_function_name(function), format_function_args(args), doc,
       format_docs(expression_docs)}
      | existing_expression_docs
    ])
  end

  def type_of(%Date{}), do: "Date"
  def type_of(%DateTime{}), do: "DateTime"
  def type_of(binary) when is_binary(binary), do: "String"

  def stringify(%{"__value__" => value}), do: Expression.stringify(value)
  def stringify(value), do: Expression.stringify(value)

  def get_existing_docstring(module) do
    case Module.get_attribute(module, :doc) do
      {line_number, doc} -> {line_number, doc}
      nil -> {0, nil}
    end
  end

  def format_result(%{"__value__" => value} = result) when is_map(result) do
    other_fields =
      result
      |> Map.drop(["__value__"])
      |> Enum.map(fn {key, value} ->
        "* *#{key}* of type **#{type_of(value)}**"
      end)

    """
    complex **#{type_of(value)}** type of default value:
    ```elixir
    #{inspect(value)}
    ```
    with the following fields:\n\n#{Enum.join(other_fields, "\n")}
    """
  end

  def format_result(result), do: "**#{type_of(result)}** type: `#{inspect(result)}`"

  def format_context(nil), do: ""

  def format_context(context) do
    """
    when used with the following context:

    ```elixir
    #{inspect(context)}
    ```
    """
  end

  def format_function_name(name) do
    name = to_string(name)

    cond do
      String.ends_with?(name, "_vargs") -> String.trim_trailing("_vargs")
      String.ends_with?(name, "_") -> String.trim_trailing("_")
      true -> name
    end
  end

  def format_function_args(args) do
    args
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&(&1 == :ctx))
    |> Enum.map(&to_string/1)
  end

  def format_docs(docs) do
    Enum.map(docs, &Enum.into(&1, %{}))
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      Return a list of all functions annotated with @expression_docs
      """
      def expression_docs do
        @expression_docs
      end
    end
  end
end
