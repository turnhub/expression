defmodule Expression.V2.Callbacks do
  @moduledoc """
  Use this module to implement one's own callbacks.
  The standard callbacks available are implemented in `Expression.V2.Callbacks.Standard`.

  ```elixir
  defmodule MyCallbacks do
    use Expression.V2.Callbacks

    @doc \"\"\"
    Roll a dice and randomly return a number between 1 and 6.
    \"\"\"
    def dice_roll(ctx) do
      Enum.random(1..6)
    end

  end
  ```
  """

  @built_ins ["*", "+", "-", "<>", ">", ">=", "<", "<=", "/", "^", "=="]

  alias Expression.V2.Callbacks.Standard

  @reserved_words ~w[and if or not]

  @doc """
  Convert a string function name into an atom meant to handle
  that function

  Reserved words such as `and`, `if`, and `or` are automatically suffixed
  with an `_` underscore.
  """
  def atom_function_name(function_name) when function_name in @reserved_words,
    do: atom_function_name("#{function_name}_")

  def atom_function_name(function_name) do
    String.to_atom(function_name)
  end

  @doc """
  Callback a function while evaluating the context against an expression.

  Callback functions in this module are either:

  1. The function name as is
  2. The function name with an underscore suffix if the function name is a reserved word
  3. The function name suffixed with `_vargs` if the takes a variable set of arguments
  """
  @spec callback(
          module :: module,
          context :: map,
          function_name :: binary,
          arguments :: [any]
        ) :: any
  def callback(module \\ Standard, context, function_name, arguments) do
    case implements(module, function_name, arguments) do
      {:exact, module, function_name} ->
        apply(
          module,
          function_name,
          [context] ++ Enum.map(arguments, &Expression.V2.default_value(&1, context))
        )

      {:vargs, module, function_name} ->
        apply(module, function_name, [
          context,
          Enum.map(arguments, &Expression.V2.default_value(&1, context))
        ])

      {:error, reason} ->
        reason
    end
  end

  @spec implements(module, function_name :: String.t(), arguments :: [any]) ::
          {:exact, module, function_name :: atom}
          | {:vargs, module, function_name :: atom}
          | {:error, reason :: String.t()}
  def implements(module \\ Standard, function_name, arguments) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    Code.ensure_loaded!(Standard)

    cond do
      # Check if the exact function signature has been implemented
      function_name in @built_ins ->
        {:exact, module, atom_function_name(function_name)}

      function_exported?(module, exact_function_name, length(arguments) + 1) ->
        {:exact, module, exact_function_name}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(module, vargs_function_name, 2) ->
        {:vargs, module, vargs_function_name}

      # Check if the exact function signature has been implemented
      function_exported?(Standard, exact_function_name, length(arguments) + 1) ->
        {:exact, Standard, exact_function_name}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(Standard, vargs_function_name, 2) ->
        {:vargs, Standard, vargs_function_name}

      # Otherwise fail
      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  defmacro __using__(_opts) do
    quote do
      def callback(module \\ __MODULE__, context, function_name, args)

      def callback(module, context, built_in, args)
          when built_in in unquote(@built_ins),
          do:
            apply(
              Kernel,
              String.to_existing_atom(built_in),
              Enum.map(args, &Expression.V2.default_value(&1, context))
            )

      defdelegate callback(module, context, function_name, arguments),
        to: Expression.V2.Callbacks
    end
  end
end
