defmodule ExpressionDefexprTest do
  use ExUnit.Case, async: true

  # A callback module using only defexpr — no manual def callbacks
  defmodule DefexprCallbacks do
    use Expression.Callbacks

    defexpr shout(text) do
      String.upcase(to_string(text))
    end

    defexpr add(a, b) do
      a + b
    end

    # With context access
    defexpr greet(name), ctx do
      prefix =
        case ctx do
          %Expression.Context{private: %{prefix: p}} -> p
          _ -> "Hello"
        end

      "#{prefix}, #{name}!"
    end

    # Reserved word: user writes `not_`, macro registers as expression name `not`
    defexpr not_(value) do
      !value
    end

    # Variadic function
    @variadic true
    defexpr concat(args), ctx do
      alias Expression.Callbacks.EvalHelpers
      Enum.map_join(args, "", &EvalHelpers.eval!(&1, ctx))
    end
  end

  # A callback module that mixes defexpr and regular def
  defmodule MixedCallbacks do
    use Expression.Callbacks

    # defexpr style
    defexpr double(n) do
      n * 2
    end

    # traditional def style — still works
    def triple(ctx, n) do
      eval!(n, ctx) * 3
    end
  end

  # A callback module with stdlib: false
  defmodule NoStdlibCallbacks do
    use Expression.Callbacks, stdlib: false

    defexpr echo(text) do
      "echo: #{text}"
    end
  end

  # Callback modules for composition
  defmodule MathCallbacks do
    use Expression.Callbacks, stdlib: false

    defexpr square(n) do
      n * n
    end
  end

  defmodule StringCallbacks do
    use Expression.Callbacks, stdlib: false

    defexpr reverse(text) do
      text |> to_string() |> String.reverse()
    end
  end

  defmodule ComposedCallbacks do
    use Expression.Callbacks, also: [MathCallbacks, StringCallbacks]

    defexpr custom_hello(name) do
      "hello #{name}"
    end
  end

  describe "defexpr/2 (no context)" do
    test "simple single-arg function" do
      assert {:ok, "FOO"} = Expression.evaluate("@shout(\"foo\")", %{}, DefexprCallbacks)
    end

    test "multi-arg function" do
      assert {:ok, 7} = Expression.evaluate("@(add(3, 4))", %{}, DefexprCallbacks)
    end

    test "with variable substitution" do
      assert {:ok, "HELLO"} =
               Expression.evaluate("@shout(name)", %{"name" => "hello"}, DefexprCallbacks)
    end
  end

  describe "defexpr/3 (with context)" do
    test "accesses private state from structured context" do
      ctx = Expression.Context.build(%{"name" => "Jane"}, private: %{prefix: "Hi"})
      assert "Hi, Jane!" == Expression.evaluate_as_string!("@greet(name)", ctx, DefexprCallbacks)
    end

    test "falls back gracefully with plain map context" do
      assert {:ok, "Hello, Jane!"} =
               Expression.evaluate("@greet(\"Jane\")", %{}, DefexprCallbacks)
    end
  end

  describe "reserved words" do
    test "not function works through defexpr" do
      assert {:ok, true} =
               Expression.evaluate("@(not(false))", %{}, DefexprCallbacks)
    end

    test "not negates truthy value" do
      assert {:ok, false} =
               Expression.evaluate("@(not(true))", %{}, DefexprCallbacks)
    end
  end

  describe "@variadic" do
    test "variadic function receives argument list" do
      assert {:ok, "abc"} =
               Expression.evaluate(~s|@concat("a", "b", "c")|, %{}, DefexprCallbacks)
    end
  end

  describe "mixed defexpr and def" do
    test "defexpr function works" do
      assert {:ok, 10} = Expression.evaluate("@(double(5))", %{}, MixedCallbacks)
    end

    test "traditional def function works alongside defexpr" do
      assert {:ok, 15} = Expression.evaluate("@(triple(5))", %{}, MixedCallbacks)
    end

    test "stdlib fallback still works" do
      assert {:ok, "FOO"} = Expression.evaluate("@upper(\"foo\")", %{}, MixedCallbacks)
    end
  end

  describe "stdlib: false" do
    test "custom function works" do
      assert {:ok, "echo: hi"} =
               Expression.evaluate("@echo(\"hi\")", %{}, NoStdlibCallbacks)
    end

    test "stdlib functions are not available" do
      assert {:ok, result} = Expression.evaluate("@upper(\"foo\")", %{}, NoStdlibCallbacks)
      assert result =~ "ERROR"
    end
  end

  describe "also: composition" do
    test "own functions work" do
      assert {:ok, "hello world"} =
               Expression.evaluate("@custom_hello(\"world\")", %{}, ComposedCallbacks)
    end

    test "also modules are available" do
      assert {:ok, 25} = Expression.evaluate("@(square(5))", %{}, ComposedCallbacks)
    end

    test "multiple also modules compose" do
      assert {:ok, "oof"} = Expression.evaluate("@reverse(\"foo\")", %{}, ComposedCallbacks)
    end

    test "stdlib still available as final fallback" do
      assert {:ok, "FOO"} = Expression.evaluate("@upper(\"foo\")", %{}, ComposedCallbacks)
    end
  end

  describe "__expression_functions__/0" do
    test "registered functions are listed" do
      funcs = DefexprCallbacks.__expression_functions__()
      names = Enum.map(funcs, &elem(&1, 0))

      assert :shout in names
      assert :add in names
      assert :greet in names
      assert :not in names
      assert :concat in names
    end

    test "context usage is tracked" do
      funcs = DefexprCallbacks.__expression_functions__()

      shout = Enum.find(funcs, &(elem(&1, 0) == :shout))
      assert {_, false, false} = shout

      greet = Enum.find(funcs, &(elem(&1, 0) == :greet))
      assert {_, true, false} = greet
    end

    test "variadic is tracked" do
      funcs = DefexprCallbacks.__expression_functions__()
      concat = Enum.find(funcs, &(elem(&1, 0) == :concat))
      assert {_, true, true} = concat
    end
  end

  describe "backwards compatibility" do
    test "existing custom callbacks test still passes with custom def" do
      # The CustomCallback from expression_custom_callbacks_test.exs uses def, not defexpr
      # This test ensures the __using__ changes don't break existing modules
      assert {:ok, "FOO"} = Expression.evaluate("@upper(\"foo\")", %{}, MixedCallbacks)
    end
  end
end
