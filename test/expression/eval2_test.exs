defmodule Expression.Eval2Test do
  use ExUnit.Case, async: true
  alias Expression.Eval2, as: Eval
  alias Expression.Parser

  test "substitution" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo")
    assert "bar" == Eval.eval!(ast, %{"foo" => "bar"})
  end

  test "attributes on substitutions" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo.bar")
    assert "baz" == Eval.eval!(ast, %{"foo" => %{"bar" => "baz"}})
  end

  test "functions" do
    {:ok, ast, "", _, _, _} = Parser.parse("@has_any_word(\"The Quick Brown Fox\", \"red fox\")")

    assert true == Eval.eval!(ast, %{})
  end

  test "attributes on functions" do
    {:ok, ast, "", _, _, _} =
      Parser.parse("@has_any_word(\"The Quick Brown Fox\", \"red fox\").match")

    assert "Fox" == Eval.eval!(ast, %{})
  end

  test "arithmatic" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 1)")
    assert 2 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    assert 7 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) * 3)")
    assert 9 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) / 3)")
    assert 1.0 == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(6 / 2 + 1)")
    assert 4.0 == Eval.eval!(ast, %{})
  end

  test "text" do
    {:ok, ast, "", _, _, _} = Parser.parse("hello @contact.name")
    assert "hello Bob" == Eval.eval!(ast, %{"contact" => %{"name" => "Bob"}})
  end
end
