# Run with `mix run benchmark.exs` in the console

Benchee.run(
  %{
    "v1" => fn {expression, context} -> Expression.evaluate(expression, context) end,
    "v2" => fn {expression, context} ->
      Expression.V2.eval(expression, context, Expression.V2.Callbacks)
    end
  },
  inputs: %{
    "simple" => {
      "Hello @contact.name, you were born in @(YEAR(contact.birthday))",
      %{"contact" => %{"name" => "mary", "birthday" => ~U[1920-02-02T00:00:00+0000]}}
    },
    "map" => {~S|map(0..10, &([&1, concatenate("Button ", &1)]))|, %{}},
    "if" =>
      {"if(something.false, 1, contact.bar)",
       %{"something" => %{"false" => false}, "contact" => %{}}},
    "arithmetic" => {"3 * (5 + 2)", %{}}
  }
)
