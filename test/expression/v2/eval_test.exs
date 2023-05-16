defmodule Expression.V2.EvalTest do
  use ExUnit.Case, async: true
  doctest Expression.V2

  alias Expression.V2
  alias Expression.V2.Compile
  alias Expression.V2.Context
  alias Expression.V2.Parser

  def eval(binary, vars \\ %{}, opts \\ []) do
    {:ok, ast, "", _, _, _} = Parser.expression(binary)
    context = Context.new(vars)
    debug = opts[:debug] || false

    if debug do
      IO.puts("ast: #{inspect(ast)}")

      ast
      |> V2.debug()
      |> IO.puts()
    end

    case Compile.compile(ast) do
      result when is_function(result) -> result.(context)
      result -> result
    end
  end

  describe "map as context" do
    test "eval_block accepts a map" do
      assert V2.eval_block("contact.name", %{"contact" => %{"name" => "Mary"}}) == "Mary"
    end

    test "eval accepts a map" do
      assert V2.eval("hello @contact.name", %{"contact" => %{"name" => "Mary"}}) == [
               "hello ",
               "Mary"
             ]
    end
  end

  describe "eval_as_string" do
    test "with missing vars" do
      assert "hello @one.two.three" == Expression.V2.eval_as_string("hello @one.two.three")
    end
  end

  describe "eval" do
    test "with missing vars" do
      assert nil == Expression.V2.eval_block("one.two.three")
    end

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

    test "attribute and property combination" do
      assert "hi" ==
               eval(
                 "after_hours.rows[random_row].label.bar",
                 %{
                   "after_hours" => %{"rows" => [%{"label" => %{"bar" => "hi"}}]},
                   "random_row" => 0
                 }
               )
    end

    test "indices on lists" do
      assert "qux" == eval("foo[2]", %{"foo" => [1, 2, "qux"]})
    end

    test "function calls" do
      assert "Hi" == eval("proper(\"hi\")")
    end

    test "arithmetic" do
      assert 5 == eval("1 * 5")
    end

    test "arithmetic against default values" do
      assert 50 ==
               eval(
                 "5 * foo",
                 %{
                   "foo" => %{
                     "__value__" => 10,
                     "other_attributes" => "ignored"
                   }
                 }
               )
    end

    test "precedence" do
      assert 12 == eval("2 * 5 + 2")
    end

    test "groups" do
      assert 21 == eval("3 * (5 + 2)")
    end

    test "functions with vars" do
      assert 50 == eval("day(date(2023, 2, 10)) * 5")
    end

    test "functions with default values" do
      assert 50 = eval("day(foo) * 5", %{"foo" => %{"__value__" => Date.new!(2023, 2, 10)}})
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
      ctx = %{"foo" => [1, 2, 3]}
      assert [1, 2, 3] == eval("map(foo, &(&1))", ctx)

      assert [[1, "Button"], [2, "Button"], [3, "Button"]] =
               eval("map(foo, &([&1, \"Button\"]))", ctx)

      assert [[1, "Button 1"], [2, "Button 2"], [3, "Button 3"]] =
               eval(~S|map(foo, &([&1, concatenate("Button ", &1)]))|, ctx)
    end

    test "lambda & map with single quoted strings" do
      assert [
               ["one", "Button One"],
               ["two", "Button Two"],
               ["three", "Button Three"],
               ["four", "Button Four"],
               ["five", "Button Five"]
             ] ==
               eval(
                 ~S|map(options, &([&1, concatenate('Button ', proper(&1))]))|,
                 %{
                   "options" => ["one", "two", "three", "four", "five"]
                 }
               )
    end
  end
end
