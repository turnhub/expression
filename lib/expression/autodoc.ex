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
  * `fake_result` can be optionally supplied when the returning result varies
     depending on factors we do not control, like for `now()` for example.
     When this is used, the ExDoc tests are faked and won't actually test
     anything so use sparingly.

  """
  defmacro __using__(_args) do
    quote do
      @expression_docs []
      Module.register_attribute(__MODULE__, :expression_doc, accumulate: true)
      @on_definition Expression.Autodoc
      @before_compile Expression.Autodoc

      import Expression.Autodoc
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

    {function_name, function_type} = format_function_name(function)

    Module.put_attribute(module, :expression_docs, [
      {function_name, function_type, format_function_args(args), doc, []}
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
        doc = expression_doc[:doc]
        expression = expression_doc[:expression]
        code_expression = expression_doc[:code_expression] || expression_doc[:expression]
        context = expression_doc[:context]

        {doctest_prompt, result} =
          if is_nil(expression_doc[:fake_result]) do
            {"iex", expression_doc[:result]}
          else
            {"..$", expression_doc[:fake_result]}
          end

        """
        ## Example #{index}:
        #{if(doc, do: "\n> #{doc}\n", else: "")}

        When used in the following Stack expression it returns a #{format_result(result)}#{format_context(context)}

        ```
        > #{Enum.join(String.split(code_expression, "\n"), "\n> ")}
        #{inspect(result)}
        ```

        When used as an expression in text, prepend it with an `@`:

        ```expression
        > "... @#{expression} ..."
        "#{stringify(result)}"
        ```

        #{generate_ex_doc(doctest_prompt, expression, context || %{}, result)}

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

    {function_name, function_type} = format_function_name(function)

    Module.put_attribute(module, :expression_docs, [
      {function_name, function_type, format_function_args(args), doc,
       format_docs(expression_docs)}
      | existing_expression_docs
    ])
  end

  def generate_ex_doc(prompt \\ "iex", expression, context, result) do
    """
        #{prompt}> import ExUnit.Assertions
        #{prompt}> result = Expression.evaluate_block!(
        ...>   #{inspect(expression)},
        ...>   #{inspect(context || %{})}
        ...> )
        #{generate_assert(prompt, result)}
        #{prompt}> Expression.evaluate_as_string!(
        ...>   #{inspect("@" <> expression)},
        ...>   #{inspect(context || %{})}
        ...> )
        #{inspect(stringify(result))}
    """
  end

  def generate_assert(prompt, result) when is_nil(result) or result == false do
    Enum.join(["#{prompt}> refute result", "#{inspect(result)}"], "\n    ")
  end

  def generate_assert(prompt, result) do
    Enum.join(
      [
        "#{prompt}> assert #{inspect(result)} = result",
        "#{inspect(result)}"
      ],
      "\n    "
    )
  end

  def type_of(map) when is_map(map), do: "Map"
  def type_of(%Time{}), do: "Time"
  def type_of(%Date{}), do: "Date"
  def type_of(%DateTime{}), do: "DateTime"
  def type_of(%Decimal{}), do: "Decimal"
  def type_of(boolean) when is_boolean(boolean), do: "Boolean"
  def type_of(nil) when is_nil(nil), do: "Null"
  def type_of(integer) when is_integer(integer), do: "Integer"
  def type_of(float) when is_float(float), do: "Float"
  def type_of(binary) when is_binary(binary), do: "String"

  def type_of(list) when is_list(list),
    do: "List with values " <> Enum.map_join(list, ", ", &type_of/1)

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

  def format_result(result), do: " value of type **#{type_of(result)}**: `#{inspect(result)}`"

  def format_context(nil), do: "."

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
      String.ends_with?(name, "_vargs") -> {String.trim_trailing(name, "_vargs"), :vargs}
      String.ends_with?(name, "_") -> {String.trim_trailing(name, "_"), :reserved}
      true -> {name, :direct}
    end
  end

  def format_function_args(args) do
    args
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&(&1 in [:ctx, :_ctx]))
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
        Enum.reverse(@expression_docs)
      end
    end
  end
end
