defmodule Expression.V2.Callbacks do
  @built_ins ["*", "+", "-", ">", ">=", "<", "<=", "/", "^", "=="]

  def callback(_context, built_in, args) when built_in in @built_ins,
    do: apply(Kernel, String.to_existing_atom(built_in), args)

  def callback(_context, "echo", [a]), do: echo(a)

  def echo(a), do: a
end
