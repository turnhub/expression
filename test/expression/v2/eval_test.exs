defmodule Expression.V2.EvalTest do
  use ExUnit.Case, async: true
  doctest Expression.V2

  alias Expression.V2
  alias Expression.V2.Context
  alias Expression.V2.Eval
  alias Expression.V2.Parser

  def eval(binary, vars \\ %{}, callback_module \\ Expression.V2.Callbacks) do
    {:ok, ast, "", _, _, _} = Parser.expression(binary)
    context = Context.new(vars)

    case Eval.compile(ast, callback_module) do
      result when is_function(result) -> result.(context)
      result -> result
    end
  end

  describe "eval" do
    test "vars" do
      assert "bar" == eval("foo", %{"foo" => "bar"})
    end

    test "properties" do
      assert "baz" == eval("foo.bar", %{"foo" => %{"bar" => "baz"}})
    end

    test "attributes as vars" do
      assert "qux" == eval("foo[bar]", %{"foo" => %{"baz" => "qux"}, "bar" => "baz"})
    end

    test "attributes as literals" do
      assert "qux" == eval("foo[\"baz\"]", %{"foo" => %{"baz" => "qux"}})
    end

    test "indices on lists" do
      assert "qux" == eval("foo[2]", %{"foo" => [1, 2, "qux"]})
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
      assert 10 == eval("echo(foo.bar).baz", %{"foo" => %{"bar" => %{"baz" => 10}}})
    end

    test "ints & floats" do
      assert true == eval("1.0 <= 1")
      assert true == eval("1.0 == 1")
      assert true == eval("1.0 = 1")
      assert false == eval("1.0 > 1")
      assert true == eval("1.1 > 1")
    end

    test "if" do
      assert 1 == eval("if(something.true, 1, 0)", %{"something" => %{"true" => true}})

      assert nil ==
               eval(
                 "if(something.false, 1, contact.bar)",
                 %{"something" => %{"false" => false}, "contact" => %{}}
               )
    end

    test "complex values" do
      assert %{"__value__" => true, "match" => "Fox"} ==
               eval(~S|has_any_word("The Quick Brown Fox", "red fox")|)

      assert "Fox" ==
               eval(~S|has_any_word("The Quick Brown Fox", "red fox").match|)
    end

    test "lambda & map" do
      assert [1, 2, 3] == eval("map(foo, &(&1))", %{"foo" => [1, 2, 3]})

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] =
               eval("map(foo, &([&1, \"Button\"]))", %{"foo" => [1, 2, 3]})

      assert [~D[2022-05-01], ~D[2022-05-02], ~D[2022-05-03]] =
               eval("map(1..3, &date(2022, 5, &1))")
    end
  end
end
