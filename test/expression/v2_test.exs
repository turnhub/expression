defmodule Expression.V2Test do
  use ExUnit.Case, async: true
  alias Expression.V2

  describe "code gen" do
    test "code gen variables" do
      assert String.trim("""
             fn context ->
               Expression.V2.Callbacks.callback(context, "+", [
                 Map.get(context.vars, "foo"),
                 Map.get(context.vars, "bar")
               ])
             end
             """) == V2.debug("foo + bar")
    end
  end
end
