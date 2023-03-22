defmodule Expression.V2.ContextVars do
  @moduledoc """
  A module for keeping track of context variables.
  This mostly just behaves like a regular Map with the exception
  that when a variable doesn't exist in the context, it returns
  a `%ContextVars{}` map that keeps track of the path that
  was requested.

  This is to allow us to keep displaying `Hello info@support.com`
  when `support.com` doesn't exist in the context.

  The `to_string()` behaviour is defined in the `String.Chars` protocol
  implementation below this module.
  """
  @behaviour Access
  defstruct path: [], vars: %{}, missing?: false

  def get_and_update(ctx_vars, key, function) do
    {_, new_vars} = Map.get_and_update(ctx_vars.vars, key, function)
    {ctx_vars, %{ctx_vars | vars: new_vars}}
  end

  def fetch(ctx_vars, key) do
    updated_path = [key | ctx_vars.path]
    {:ok, Map.get(ctx_vars.vars, key, %__MODULE__{path: updated_path, vars: %{}, missing?: true})}
  end

  def pop(ctx_vars, key) do
    {popped, updated_vars} = Map.pop(ctx_vars.vars, key)
    {popped, %{ctx_vars | vars: updated_vars}}
  end

  def new(vars) do
    %__MODULE__{vars: vars}
  end
end

defimpl Jason.Encoder, for: Expression.V2.ContextVars do
  def encode(%{missing?: true}, opts), do: Jason.Encode.value(nil, opts)
  def encode(%{vars: vars}, opts), do: Jason.Encode.map(vars, opts)
end

# defimpl String.Chars, for: Expression.V2.ContextVars do
#   def to_string(%{missing?: true, path: path}),
#     do:
#       "@" <>
#         (path
#          |> Enum.reverse()
#          |> Enum.join("."))
# end
