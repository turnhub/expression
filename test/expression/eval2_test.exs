defmodule Expression.Eval2Test do
  use ExUnit.Case, async: true
  alias Expression.Eval2, as: Eval
  alias Expression.Parser

  test "substitution" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo")
    assert "bar" == Eval.eval!(ast, %{"foo" => "bar"})
  end

  test "attributes" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo.bar")
    assert "baz" == Eval.eval!(ast, %{"foo" => %{"bar" => "bar"}})
  end
end
