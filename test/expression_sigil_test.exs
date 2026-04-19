defmodule ExpressionSigilTest do
  use ExUnit.Case, async: true
  import Expression.Sigil

  describe "~EXPR (validation only)" do
    test "valid expression returns string" do
      assert "SUM(1, 2)" = ~EXPR"SUM(1, 2)"
    end

    test "valid expression with variables" do
      assert "contact.name" = ~EXPR"contact.name"
    end

    test "valid complex expression" do
      assert "age > 18 and name == \"Jane\"" = ~EXPR|age > 18 and name == "Jane"|
    end
  end

  describe "~EXPR with c modifier (pre-parsed)" do
    test "returns pre-parsed AST" do
      assert [{:function, [name: "sum", args: [literal: 1, literal: 2]]}] = ~EXPR"SUM(1, 2)"c
    end

    test "pre-parsed AST can be used directly with Eval" do
      ast = ~EXPR"1 + 2"c
      result = Expression.Eval.eval!([expression: ast], %{})
      assert result == 3
    end

    test "pre-parsed AST with variables" do
      assert [{:function, _}] = ~EXPR"upper(name)"c
    end
  end

  describe "compile-time error detection" do
    test "invalid expression raises CompileError" do
      assert_raise CompileError, fn ->
        Code.compile_string("""
        import Expression.Sigil
        ~EXPR"SUM(1,"
        """)
      end
    end
  end
end
