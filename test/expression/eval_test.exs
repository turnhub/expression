defmodule Expression.EvalTest do
  use ExUnit.Case, async: true
  alias Expression.Eval
  alias Expression.Parser

  test "substitution" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo")
    assert "bar" == Eval.to_string!(ast, %{"foo" => "bar"})
  end

  test "attributes on substitutions" do
    {:ok, ast, "", _, _, _} = Parser.parse("@foo.bar")
    assert "baz" == Eval.to_string!(ast, %{"foo" => %{"bar" => "baz"}})
  end

  test "functions" do
    {:ok, ast, "", _, _, _} = Parser.parse(~s[@has_any_word("The Quick Brown Fox", "red fox")])

    assert [true] == Eval.eval!(ast, %{})
  end

  test "attributes on functions" do
    {:ok, ast, "", _, _, _} =
      Parser.parse(~s[@has_any_word("The Quick Brown Fox", "red fox").match])

    assert "Fox" == Eval.to_string!(ast, %{})
  end

  describe "lists" do
    test "with literal indices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1]")

      assert [1] == Eval.eval!(ast, %{"foo" => [0, 1, 2]})
    end

    test "with function" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[day(now())]")
      today = DateTime.utc_now().day
      assert [today] == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end

    test "with range slices" do
      {:ok, ast, "", _, _, _} = Parser.parse("@foo[1..3]")
      assert [[1, 2, 3]] == Eval.eval!(ast, %{"foo" => Enum.to_list(0..31)})
    end
  end

  test "arithmatic" do
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 1)")
    assert [2] == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(1 + 2 * 3)")
    assert [7] == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) * 3)")
    assert [9] == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@((1 + 2) / 3)")
    assert [1.0] == Eval.eval!(ast, %{})
    {:ok, ast, "", _, _, _} = Parser.parse("@(6 / 2 + 1)")
    assert [4.0] == Eval.eval!(ast, %{})
  end

  test "text" do
    {:ok, ast, "", _, _, _} = Parser.parse("hello @contact.name")
    assert "hello Bob" == Eval.to_string!(ast, %{"contact" => %{"name" => "Bob"}})
  end
end
