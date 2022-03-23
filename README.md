# Expression

An Elixir library implementing the [FLOIP Expressions](https://floip.gitbook.io/flow-specification/expressions) language.

```elixir
iex> Expression.evaluate("Hello @name", %{
  "name" => "World"
})
"Hello World"

iex> Expression.evaluate("Hello @contact.name", %{
  "contact" => %{
    "name" => "peter"
  }
})
"Hello peter"

iex> Expression.evaluate("Hello @contact.name, you were born in @(YEAR(contact.birthday))", %{
  "contact" => %{
    "name" => "mary",
    "birthday" => "1920-02-02T00:00:00"
  }
})
{:ok, "Hello mary, you were born in 1920"}

iex> Expression.evaluate("Hello @PROPER(contact.name)", %{
  "contact" => %{
    "name" => "peter rabbit"
  }
})
"Hello Peter Rabbit"

iex> Expression.evaluate("Your next appointment is @(EDATE(contact.appointment, 1))", %{
  "contact" => %{
    "appointment" => DateTime.utc_now()
  }
})
{:ok, "Your next appointment is 2021-01-02 12:38:14.426663Z"}

iex> Expression.evaluate("Your next appointment is @(DATEVALUE(EDATE(contact.appointment, 1), \"%Y-%m-%d\"))", %{
  "contact" => %{
    "appointment" => "2020-12-13T23:35:55"
  }
})
{:ok, "Your next appointment is 2021-01-13"}

iex> Expression.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'Client')", %{
  "contact" => %{
    "gender" => "O"
  }
})
{:ok, "Dear Client"}
```

See `Engaged.Callbacks` for all the functions implemented.

# Types

Expression knows the following types:

```elixir
iex> # Decimals
iex> Expression.evaluate("@(1.23)")
{:ok, #Decimal<1.23>}
iex> # Integers
iex> Expression.evaluate("@(1)")
{:ok, 1}
iex> # DateTime in ISO and a sloppy US formats
iex> Expression.evaluate("@(2020-12-13T23:35:55)")
{:ok, ~U[2020-12-13 23:35:55.0Z]}
iex> Expression.evaluate("@(13-12-2020 23:35:55)")
{:ok, ~U[2020-12-13 23:35:55Z]}
iex> # case insensitive booleans
iex> Expression.evaluate("@(true)")
{:ok, true}
iex> Expression.evaluate("@(TrUe)")
{:ok, true}
iex> Expression.evaluate("@(false)")
{:ok, false}
iex> Expression.evaluate("@(FaLsE)")
{:ok, false}
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
    {:expression, "~> 0.7.2"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/expression](https://hexdocs.pm/expression).
