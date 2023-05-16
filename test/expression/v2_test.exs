defmodule Expression.V2Test do
  use ExUnit.Case, async: true
  alias Expression.V2

  describe "code gen" do
    test "code gen using context" do
      assert String.trim("""
             fn context ->
               Expression.V2.default_value(context.vars["foo"], context) +
                 Expression.V2.default_value(context.vars["bar"], context)
             end
             """) == V2.debug("foo + bar")
    end

    test "code gen not using context" do
      assert String.trim("""
             fn _context -> ["one", "two"] end
             """) == V2.debug(~S|["one", "two"]|)
    end

    test "default values not used for integers and builtins" do
      assert "fn _context -> 1 + 1 end" == V2.debug("1 + 1")
    end

    test "default values not used for strings and builtins" do
      assert String.trim("""
             fn _context -> "hello" == "bye" end
             """) == V2.debug("\"hello\" == \"bye\"")
    end

    test "default values used for variables and builtins" do
      assert String.trim("""
             fn context ->
               Expression.V2.default_value(context.vars["a"], context) *
                 Expression.V2.default_value(context.vars["b"], context)
             end
             """) == V2.debug("a * b")
    end
  end
end
