defmodule Expression.Callbacks do
  @moduledoc """
  The function callbacks for the standard function set available
  in FLOIP expressions.

  This should be relatively swappable with another implementation.
  The only requirement is the `handle/3` function.

  FLOIP functions are case insensitive. All functions in this callback
  module are implemented as lowercase names.

  Some functions accept a variable amount of arguments. Elixir doesn't
  support variable arguments in functions.

  If a function accepts a variable number of arguments the convention
  is to call the `<function_name>_vargs/2` callback where the context
  is given as the first argument and the argument list as a second
  argument.

  Reserved names such as `and`, `if`, and `or` are suffixed with an
  underscore.
  """

  alias Expression.Callbacks.Standard

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
  Handle a function call while evaluating the AST.

  Handlers in this module are either:

  1. The function name as is
  2. The function name with an underscore suffix if the function name is a reserved word
  3. The function name suffixed with `_vargs` if the takes a variable set of arguments
  """
  @spec handle(module :: module, function_name :: binary, arguments :: [any], context :: map) ::
          {:ok, any} | {:error, :not_implemented}
  def handle(module \\ Standard, function_name, arguments, context) do
    case implements(module, function_name, arguments) do
      {:exact, module, function_name, _arity} ->
        {:ok, apply(module, function_name, [context] ++ arguments)}

      {:vargs, module, function_name, _arity} ->
        {:ok, apply(module, function_name, [context, arguments])}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def implements(module \\ Standard, function_name, arguments) do
    exact_function_name = atom_function_name(function_name)
    vargs_function_name = atom_function_name("#{function_name}_vargs")

    Code.ensure_loaded!(Standard)

    cond do
      # Check if the exact function signature has been implemented
      function_exported?(module, exact_function_name, length(arguments) + 1) ->
        {:exact, module, exact_function_name, length(arguments) + 1}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(module, vargs_function_name, 2) ->
        {:vargs, module, vargs_function_name, 2}

      # Check if the exact function signature has been implemented
      function_exported?(Standard, exact_function_name, length(arguments) + 1) ->
        {:exact, Standard, exact_function_name, length(arguments) + 1}

      # Check if it's been implemented to accept a variable amount of arguments
      function_exported?(Standard, vargs_function_name, 2) ->
        {:vargs, Standard, vargs_function_name, 2}

      # Otherwise fail
      true ->
        {:error, "#{function_name} is not implemented."}
    end
  end

  defmacro __using__(_opts) do
    quote do
      import Expression.Callbacks.EvalHelpers

      defdelegate handle(module \\ __MODULE__, function_name, arguments, context),
        to: Expression.Callbacks
    end
  end
end
