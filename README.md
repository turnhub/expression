# Expression

An Elixir library implementing the [FLOIP Expressions](https://floip.gitbook.io/flow-specification/expressions) language.

```elixir
iex(1)> Expression.evaluate!("Hello @name", %{
...(1)>   "name" => "World"
...(1)> })
["Hello ", "World"]

iex(2)> Expression.evaluate("Hello @contact.name", %{
...(2)>   "contact" => %{
...(2)>     "name" => "peter"
...(2)>   }
...(2)> })
{:ok, ["Hello ", "peter"]}

iex(6)> Expression.evaluate("Hello @contact.name, you were born in @(YEAR(contact.birthday))", %{
...(6)>   "contact" => %{
...(6)>     "name" => "mary",
...(6)>     "birthday" => "1920-02-02T00:00:00"
...(6)>   }
...(6)> })
{:ok, ["Hello ", "mary", ", you were born in ", 1920]}

iex(7)> Expression.evaluate("Hello @PROPER(contact.name)", %{
...(7)>   "contact" => %{
...(7)>     "name" => "peter rabbit"
...(7)>   }
...(7)> })
{:ok, ["Hello ", "Peter Rabbit"]}

ex(8)> Expression.evaluate("Your next appointment is @(EDATE(contact.appointment, 1))", %{
...(8)>   "contact" => %{
...(8)>     "appointment" => DateTime.utc_now()
...(8)>   }
...(8)> })
{:ok, ["Your next appointment is ", ~U[2022-06-25 08:39:51.730780Z]]}

iex(9)> Expression.evaluate("Your next appointment is @(DATEVALUE(EDATE(contact.appointment, 1), \"%Y-%m-%d\"))", %{
...(9)>   "contact" => %{
...(9)>     "appointment" => "2020-12-13T23:35:55"
...(9)>   }
...(9)> })
{:ok, ["Your next appointment is ", "2021-01-13"]}


iex(10)> Expression.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'Client')", %{
...(10)>   "contact" => %{
...(10)>     "gender" => "O"
...(10)>   }
...(10)> })
{:ok, ["Dear ", "Client"]}
```

The values of each chunk (either text or expression) is in the list returned by evaluate.
The return values of Expressions are typed. The types are documented below under _Types_.

If you're looking for a shorthand to convert these to a single string output use `Expression.as_string!/3`.

```elixir
iex(11)> Expression.as_string!("Your next appointment is @(DATEVALUE(EDATE(contact.appointment, 1), \"%Y-%m-%d\"))", %{
...(11)>   "contact" => %{
...(11)>     "appointment" => "2020-12-13T23:35:55"
...(11)>   }
...(11)> })
"Your next appointment is 2021-01-13"
```

See `Engaged.Callbacks` for all the functions implemented.

Often, when one has an email address in an expression, one would want to leave it as is.
Expressions accommodates this by having expressions that evaluate to nil left as is.

```elixir
iex(3)> Expression.as_string!("info@support.com")
"info@support.com"
```

A thing to note though is that if `@support.com` does resolve to something with the given context,
it will still be applied:

```elixir
iex(6)> Expression.as_string!("info@support.com", %{
...(6)>   "support" => %{
...(6)>     "com" => "example placeholder value"
...(6)>   }
...(6)> })
"infoexample placeholder value"
```

To properly escape the `@`, prefix it with another `@` as the example below:

```elixir
iex(4)> Expression.as_string!("info@@support.com")
"info@support.com"
```

# Types

Expression knows the following types:

```elixir
iex> # Decimals
iex> Expression.evaluate("@(1.23)")
{:ok, [#Decimal<1.23>]}
iex> # Integers
iex> Expression.evaluate("@(1)")
{:ok, [1]}
iex> # DateTime in ISO and a sloppy US formats
iex> Expression.evaluate("@(2020-12-13T23:35:55)")
{:ok, [~U[2020-12-13 23:35:55.0Z]]}
iex> Expression.evaluate("@(13-12-2020 23:35:55)")
{:ok, [~U[2020-12-13 23:35:55Z]]}
iex> # case insensitive booleans
iex> Expression.evaluate("@(true)")
{:ok, [true]}
iex> Expression.evaluate("@(TrUe)")
{:ok, [true]}
iex> Expression.evaluate("@(false)")
{:ok, [false]}
iex> Expression.evaluate("@(FaLsE)")
{:ok, [false]}
```

# Future extensions

- It may be worth implementing a binary only expression parser, something
  that is guaranteed to only return a `true` or `false`. That could be useful
  when building decision trees with dynamic conditionals depending on context.

## Installation

> This is not available in Hex.pm or Hexdocs.pm yet

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `expression` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:expression, "~> 1.1.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/expression](https://hexdocs.pm/expression).
