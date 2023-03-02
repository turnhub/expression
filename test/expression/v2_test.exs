defmodule Expression.V2Test do
  use ExUnit.Case, async: true
  alias Expression.V2

  describe "code gen" do
    test "code gen using context" do
      assert String.trim("""
             fn context ->
               apply(context.callback_module, :callback, [
                 context,
                 "+",
                 [context.vars["foo"], context.vars["bar"]]
               ])
             end
             """) == V2.debug("foo + bar")
    end

    test "code gen not using context" do
      assert String.trim("""
             fn _context -> ["one", "two"] end
             """) == V2.debug(~S|["one", "two"]|)
    end
  end
end
