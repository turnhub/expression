defmodule Expression.V2.EvalTest do
  use ExUnit.Case, async: true

  alias Expression.V2.Parser
  alias Expression.V2.Eval

  def eval(binary_or_ast, binding \\ [], callback_module \\ Expression.V2.Callbacks)

  def eval(binary, binding, callback_module) do
    {:ok, ast, "", _, _, _} = Parser.expression(binary)
    eval(ast, binding, callback_module)
  end

  def eval(ast, binding, callback_module) do
    ast
    |> Eval.to_quoted(callback_module)
    |> Eval.eval(binding)
  end

  describe "eval" do
    test "vars" do
      assert "bar" == eval("foo", foo: "bar")
    end

    test "properties" do
      assert "baz" == eval("foo.bar", foo: %{"bar" => "baz"})
    end

    test "attributes" do
      assert "baz" == eval("foo[\"bar\"]", foo: %{"bar" => "baz"})
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
      assert 10 == eval("echo(foo.bar).baz", foo: %{"bar" => %{"baz" => 10}})
    end

    test "ints & floats" do
      assert true == eval("1.0 <= 1")
      assert true == eval("1.0 == 1")
      assert true == eval("1.0 = 1")
      assert false == eval("1.0 > 1")
      assert true == eval("1.1 > 1")
    end

    test "if" do
      assert 1 == eval("if(true, 1, contact)")
    end

    test "complex values" do
      assert %{"__value__" => true, "match" => "Fox"} ==
               eval(~S|has_any_word("The Quick Brown Fox", "red fox")|)

      assert "Fox" ==
               eval(~S|has_any_word("The Quick Brown Fox", "red fox").match|)
    end

    test "lambda & map" do
      assert [1, 2, 3] == eval("map(foo, &(&1))", foo: [1, 2, 3])

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] =
               eval("map(foo, &([&1, \"Button\"]))", foo: [1, 2, 3])

      assert [~D[2022-05-01], ~D[2022-05-02], ~D[2022-05-03]] =
               eval("map(1..3, &date(2022, 5, &1))")
    end
  end
end
