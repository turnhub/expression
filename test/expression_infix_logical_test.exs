defmodule ExpressionInfixLogicalTest do
  use ExUnit.Case, async: true

  describe "infix and" do
    test "basic and" do
      assert {:ok, true} = Expression.evaluate("@(true and true)")
      assert {:ok, false} = Expression.evaluate("@(true and false)")
      assert {:ok, false} = Expression.evaluate("@(false and true)")
    end

    test "and with variables" do
      ctx = %{"a" => true, "b" => false}
      assert {:ok, false} = Expression.evaluate("@(a and b)", ctx)
    end

    test "and with comparison expressions" do
      ctx = %{"age" => 25, "name" => "Jane"}
      assert {:ok, true} = Expression.evaluate("@(age > 18 and name == \"Jane\")", ctx)
      assert {:ok, false} = Expression.evaluate("@(age > 30 and name == \"Jane\")", ctx)
    end

    test "produces same result as function call and(a, b)" do
      ctx = %{"a" => true, "b" => true}
      assert Expression.evaluate("@(a and b)", ctx) == Expression.evaluate("@(and(a, b))", ctx)
    end
  end

  describe "infix or" do
    test "basic or" do
      assert {:ok, true} = Expression.evaluate("@(true or false)")
      assert {:ok, true} = Expression.evaluate("@(false or true)")
      assert {:ok, false} = Expression.evaluate("@(false or false)")
    end

    test "or with variables" do
      ctx = %{"a" => false, "b" => true}
      assert {:ok, true} = Expression.evaluate("@(a or b)", ctx)
    end

    test "or with comparison expressions" do
      ctx = %{"age" => 15}
      assert {:ok, true} = Expression.evaluate("@(age > 18 or age < 16)", ctx)
      assert {:ok, false} = Expression.evaluate("@(age > 18 or age < 10)", ctx)
    end

    test "produces same result as function call or(a, b)" do
      ctx = %{"a" => false, "b" => true}
      assert Expression.evaluate("@(a or b)", ctx) == Expression.evaluate("@(or(a, b))", ctx)
    end
  end

  describe "infix not" do
    test "basic not" do
      assert {:ok, true} = Expression.evaluate("@(not false)")
      assert {:ok, false} = Expression.evaluate("@(not true)")
    end

    test "not with comparison" do
      ctx = %{"age" => 15}
      assert {:ok, true} = Expression.evaluate("@(not age > 18)", ctx)
    end

    test "produces same result as function call not(a)" do
      assert Expression.evaluate("@(not true)") == Expression.evaluate("@(not(true))")
    end
  end

  describe "precedence" do
    test "and binds tighter than or" do
      # true or (false and false) => true
      assert {:ok, true} = Expression.evaluate("@(true or false and false)")
      # (true or false) and false => false -- wrong if or binds tighter
      # but correct precedence: true or (false and false) => true
    end

    test "not binds tighter than and" do
      # (not false) and true => true
      assert {:ok, true} = Expression.evaluate("@(not false and true)")
    end

    test "comparison binds tighter than and/or" do
      ctx = %{"a" => 5, "b" => 10}
      assert {:ok, true} = Expression.evaluate("@(a > 3 and b < 20)", ctx)
    end

    test "complex expression with all operators" do
      ctx = %{"age" => 25, "active" => true, "blocked" => false}

      assert {:ok, true} =
               Expression.evaluate("@(age >= 18 and active or not blocked)", ctx)
    end
  end

  describe "does not match partial words" do
    test "and does not match inside android" do
      ctx = %{"android" => "phone"}
      assert {:ok, "phone"} = Expression.evaluate("@android", ctx)
    end

    test "or does not match inside order" do
      ctx = %{"order" => "abc"}
      assert {:ok, "abc"} = Expression.evaluate("@order", ctx)
    end

    test "not does not match inside nothing" do
      ctx = %{"nothing" => "empty"}
      assert {:ok, "empty"} = Expression.evaluate("@nothing", ctx)
    end
  end

  describe "backwards compatibility" do
    test "function call and(a, b) still works" do
      assert {:ok, true} = Expression.evaluate("@(and(true, true))")
    end

    test "function call or(a, b) still works" do
      assert {:ok, true} = Expression.evaluate("@(or(false, true))")
    end

    test "function call not(a) still works" do
      assert {:ok, true} = Expression.evaluate("@(not(false))")
    end
  end
end
