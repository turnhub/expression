# Run with `mix run benchmark/blocks.exs` in the console

compiled = fn {expr, context} ->
  {:ok, ast} = Expression.V2.parse_block(expr)
  [compiled_function] = Expression.V2.compile_block(ast)
  {expression, compiled_function, context}
end

Benchee.run(
  %{
    "v1" => fn {expression, _compiled_function, context} ->
      Expression.evaluate_block(expression, context)
    end,
    "v2" => fn {_expression, compiled_function, context} ->
      compiled_function.(Expression.V2.Context.new(context))
    end
  },
  inputs: %{
    "simple" =>
      compiled.(
        "YEAR(contact.birthday)",
        %{"contact" => %{"name" => "mary", "birthday" => ~U[1920-02-02T00:00:00+0000]}}
      ),
    "map" => compiled.(~S|map(0..10, &([&1, concatenate("Button ", &1)]))|, %{}),
    "if" =>
      compiled.("if(something.false, 1, contact.bar)", %{
        "something" => %{"false" => false},
        "contact" => %{}
      }),
    "arithmetic" => compiled.("3 * (5 + 2)", %{})
  }
)
