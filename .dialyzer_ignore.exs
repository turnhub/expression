[
  # doing this because while Number.Percentage.number_to_percentage/1
  # does accept a Decimal as an input number, the spec signature
  # doesn't and so dialyzer breaks on it.
  {"lib/expression/callbacks.ex", :no_return, 809},
  {"lib/expression/callbacks.ex", :call, 820},
]
