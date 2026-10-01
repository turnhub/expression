defmodule ExpressionContextTest do
  use ExUnit.Case, async: true
  doctest Expression.Context

  test "context with underscores" do
    assert %{
             "trouble" => "_she_calls_me_princes___🤔",
             "integer" => 1,
             "string_integer" => 1
           } ==
             Expression.Context.new(
               %{
                 "string_integer" => "1",
                 "integer" => 1,
                 "trouble" => "_she_calls_me_princes___🤔"
               },
               coerce_strings: true
             )
  end

  describe "Expression.Context.build/2" do
    test "builds structured context with vars and private" do
      ctx = Expression.Context.build(%{name: "Jane"}, private: %{token: "secret"})
      assert %Expression.Context{} = ctx
      assert ctx.vars["name"] == "Jane"
      assert ctx.private == %{token: "secret"}
    end

    test "defaults private to empty map" do
      ctx = Expression.Context.build(%{name: "Jane"})
      assert ctx.private == %{}
    end

    test "normalizes vars through Context.new" do
      ctx =
        Expression.Context.build(
          %{Name: "Jane", date: "2020-12-13T23:34:45"},
          lowercase_keys: true,
          coerce_strings: true
        )

      assert ctx.vars["name"] == "Jane"
      assert %DateTime{} = ctx.vars["date"]
    end

    test "expressions resolve from vars, not private" do
      ctx = Expression.Context.build(%{name: "Jane"}, private: %{secret: "hidden"})

      assert "Jane" == Expression.evaluate_as_string!("@name", ctx)
      assert "@secret" == Expression.evaluate_as_string!("@secret", ctx)
    end

    test "private state is not accessible via @variable syntax" do
      ctx =
        Expression.Context.build(
          %{visible: "yes"},
          private: %{number: %{uuid: "abc-123"}}
        )

      assert "yes" == Expression.evaluate_as_string!("@visible", ctx)
      assert "@number" == Expression.evaluate_as_string!("@number", ctx)
    end

    test "callbacks receive the full context struct" do
      ctx = Expression.Context.build(%{name: "Jane"}, private: %{token: "secret"})
      # Evaluating a function passes the struct to the callback module
      # The standard callbacks work with both maps and structs
      assert Expression.evaluate_as_string!("@(upper(name))", ctx) == "JANE"
    end

    test "Context.new passes through an existing struct unchanged" do
      ctx = Expression.Context.build(%{name: "Jane"}, private: %{token: "secret"})
      assert ^ctx = Expression.Context.new(ctx)
    end

    test "lambdas work with structured context" do
      ctx =
        Expression.Context.build(%{items: [1, 2, 3]}, private: %{secret: "hidden"})

      assert Expression.evaluate!("@(map(items, &(&1 + 1)))", ctx) == [2, 3, 4]
    end
  end
end
