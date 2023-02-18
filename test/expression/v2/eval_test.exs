defmodule Expression.V2.EvalTest do
  use ExUnit.Case

  alias Expression.V2.Parser
  alias Expression.V2.Eval

  def eval(binary, binding \\ [], callback_modules \\ [Expression.V2.Callbacks]) do
    {:ok, ast, "", _, _, _} = Parser.expression(binary)

    ast
    |> Eval.to_quoted()
    |> Eval.import_modules(callback_modules)
    |> Eval.eval(binding)
  end

  describe "quoting" do
    test "vars" do
      assert "bar" == eval("foo", foo: "bar")
    end

    test "properties" do
      assert "baz" == eval("foo.bar", foo: %{bar: "baz"})
    end

    test "attributes" do
      assert "baz" == eval("foo[bar]", foo: %{bar: "baz"})
    end

    test "function calls" do
      assert 1 == eval("echo(1)")
    end

    test "arithmatic" do
      assert 5 == eval("1 * 5")
    end

    test "precedence" do
      assert 12 == eval("2 * 5 + 2")
    end

    test "groups" do
      assert 21 == eval("3 * (5 + 2)")
    end

    test "functions with vars" do
      assert 50 == eval("echo(10) * 5")
    end

    test "functions vars & properties" do
      assert 10 == eval("echo(foo.bar).baz", foo: %{bar: %{baz: 10}})
    end
  end
end
