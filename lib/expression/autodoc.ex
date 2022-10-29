defmodule Expression.Autodoc do
  @moduledoc """

  Extract `@expression_doc` attributes from modules defining callbacks
  and automatically write doctests for those.

  Also inserts an `expression_docs()` function which returns a list of
  all functions and their defined expression docs.

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

  def __on_definition__(env, _kind, name, args, _guards, _body) do
    annotate_method(env.module, name, args)
  end

  def annotate_method(module, function, args) do
    if expression_doc = Module.delete_attribute(module, :expression_doc) do
      update_annotations(module, function, args, expression_doc)
    end
  end

  def update_annotations(_module, _function, _args, []), do: nil

  def update_annotations(module, function, args, expression_docs) do
    existing_expression_docs = Module.get_attribute(module, :expression_docs)

    for expression_doc <- expression_docs do
      {line_number, doc} =
        case Module.get_attribute(module, :doc) do
          {line_number, doc} -> {line_number, doc}
          nil -> {0, ""}
        end

      Module.put_attribute(
        module,
        :doc,
        {line_number,
         """
         #{doc}

         ## Example expression:

         #{expression_doc[:doc]}

         ```expression
         #{expression_doc[:expression]}
         ```

         ## Example code:

             iex> Expression.evaluate_as_string!(
             ...>   #{inspect(expression_doc[:expression])},
             ...>   #{inspect(expression_doc[:context])}
             ...> )
             #{inspect(expression_doc[:result])}

         """}
      )
    end

    Module.put_attribute(module, :expression_docs, [
      {format_function_name(function), format_function_args(args), format_docs(expression_docs)}
      | existing_expression_docs
    ])
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
