defmodule Expression.V2.Eval do
  def eval(quoted, binding) do
    {term, _binding, _env} =
      {:__block__, [], quoted}
      |> Code.eval_quoted_with_env(binding, Code.env_for_eval([]))

    term
  end

  def import_modules(quoted, modules) when is_list(modules),
    do: Enum.reduce(modules, quoted, &import_module(&2, &1))

  def import_module(quoted, module) when is_atom(module) do
    callbacks =
      module
      |> Module.split()
      |> Enum.map(&String.to_atom/1)

    [{:import, [], [{:__aliases__, [], callbacks}]} | quoted]
  end

  def to_quoted(ast) when is_list(ast) do
    Enum.reduce(ast, [], fn element, acc ->
      [quoted(element) | acc]
    end)
  end

  def quoted(string) when is_binary(string) do
    {String.to_atom(string), [], nil}
  end

  def quoted(number) when is_number(number), do: number

  def quoted([:__property__, [a, b]]) when is_binary(b),
    do: {{:., [], [quoted(a), String.to_atom(b)]}, [], []}

  def quoted([:__attribute__, [a, b]]),
    do: {{:., [], [quoted(a), String.to_atom(b)]}, [], []}

  def quoted([function, arguments]) when is_binary(function) do
    {String.to_atom(function), [], Enum.map(arguments, &quoted/1)}
  end
end
