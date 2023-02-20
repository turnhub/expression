
expression = "Hello @contact.name, you were born in @(YEAR(contact.birthday))"
contact = %{"name" => "mary", "birthday" => ~U[1920-02-02T00:00:00+0000]}

Benchee.run(
  %{
    "v1" => fn -> Expression.evaluate(expression, %{"contact" => contact}) end,
    # "v1.parsing" => fn -> Expression.parse!(expression) end,
    "v2" =>  fn -> Expression.V2.eval(expression, %{contact: contact}, Expression.V2.Callbacks) end,
    # "v2.parsing" => fn -> Expression.V2.parse(expression) end
  })