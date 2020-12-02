# Excellent

An Elixir library implementing the [FLOIP Expressions](https://floip.gitbook.io/flow-specification/expressions) language.

```elixir
iex> Excellent.evaluate("Hello @name", %{
  "name" => "World"
})
"Hello World"

iex> Excellent.evaluate("Hello @contact.name", %{
  "contact" => %{
    "name" => "peter"
  }
})
"Hello peter"

iex> Excellent.evaluate("Hello @contact.name, you were born in @(YEAR(contact.birthday))", %{
  "contact" => %{
    "name" => "mary",
    "birthday" => "1920-02-02T00:00:00"
  }
})
{:ok, "Hello mary, you were born in 1920"}

iex> Excellent.evaluate("Hello @PROPER(contact.name)", %{
  "contact" => %{
    "name" => "peter rabbit"
  }
})
"Hello Peter Rabbit"

iex> Excellent.evaluate("Your next appointment is @(EDATE(contact.appointment, 1))", %{
  "contact" => %{
    "appointment" => DateTime.utc_now()
  }
})
{:ok, "Your next appointment is 2021-01-02 12:38:14.426663Z"}

iex> Excellent.evaluate("Your next appointment is @(EDATE(contact.appointment, 1))", %{
  "contact" => %{
    "appointment" => "2020-12-13T23:35:55"
  }
})
{:ok, "Your next appointment is 2021-01-13 23:35:55.0Z"}

iex> Excellent.evaluate("Dear @IF(contact.gender = 'M', 'Sir', 'Client')", %{
  "contact" => %{
    "gender" => "O"
  }
})
{:ok, "Dear Client"}
```

See `Engaged.Callbacks` for all the functions implemented.

# Types

Excellent knows the following types:

```elixir
iex> # Decimals
iex> Excellent.evaluate("@(1.23)")
{:ok, #Decimal<1.23>}
iex> # Integers
iex> Excellent.evaluate("@(1)")
{:ok, 1}
iex> # DateTime in ISO and a sloppy US formats
iex> Excellent.evaluate("@(2020-12-13T23:35:55)")
{:ok, ~U[2020-12-13 23:35:55.0Z]}
iex> Excellent.evaluate("@(13-12-2020 23:35:55)")
{:ok, ~U[2020-12-13 23:35:55Z]}
iex> # case insensitive booleans
iex> Excellent.evaluate("@(true)")
{:ok, true}
iex> Excellent.evaluate("@(TrUe)")
{:ok, true}
iex> Excellent.evaluate("@(false)")
{:ok, false}
iex> Excellent.evaluate("@(FaLsE)")
{:ok, false}
```

## Installation

> This is not available in Hex.pm or Hexdocs.pm yet

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `excellent` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:excellent, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/excellent](https://hexdocs.pm/excellent).
