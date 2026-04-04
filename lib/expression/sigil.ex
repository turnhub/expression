defmodule Expression.Sigil do
  @moduledoc """
  Provides the `~EXPR` sigil for compile-time expression validation
  and optional pre-parsing.

  ## Usage

      import Expression.Sigil

      # Validate syntax at compile time, return string at runtime
      expr = ~EXPR"SUM(contact.age, 10)"

      # Pre-parse to AST at compile time — zero runtime parse cost
      ast = ~EXPR"SUM(contact.age, 10)"c

      # Compile error on invalid syntax
      bad = ~EXPR"SUM(contact.age,"
      #=> ** (CompileError) invalid expression: ...

  The default mode validates that the expression is syntactically correct
  during compilation but returns the original string for runtime parsing.
  This catches typos and syntax errors at build time.

  The `c` modifier pre-compiles the expression to its AST representation,
  eliminating runtime parsing entirely. Use this for expressions embedded
  in Elixir source that are evaluated repeatedly.
  """

  @doc """
  Sigil for compile-time expression validation.

  Without modifiers, validates syntax and returns the string.
  With the `c` modifier, returns the pre-parsed AST.
  """
  defmacro sigil_EXPR(code, modifiers)

  defmacro sigil_EXPR({:<<>>, _, [literal]}, []) when is_binary(literal) do
    case Expression.parse_expression(literal) do
      {:ok, _ast} ->
        literal

      {:error, reason} ->
        raise CompileError,
          file: __CALLER__.file,
          line: __CALLER__.line,
          description: "invalid expression: #{reason}"
    end
  end

  defmacro sigil_EXPR({:<<>>, _, [literal]}, [?c]) when is_binary(literal) do
    case Expression.parse_expression(literal) do
      {:ok, ast} ->
        Macro.escape(ast)

      {:error, reason} ->
        raise CompileError,
          file: __CALLER__.file,
          line: __CALLER__.line,
          description: "invalid expression: #{reason}"
    end
  end

  defmacro sigil_EXPR(_code, _modifiers) do
    raise CompileError,
      description: "~EXPR only accepts string literals without interpolation"
  end
end
