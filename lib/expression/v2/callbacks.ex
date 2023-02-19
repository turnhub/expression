defmodule Expression.V2.Callbacks do
  @built_ins ["*", "+", "-", ">", ">=", "<", "<=", "/", "^", "=="]

  def callback(_context, built_in, args) when built_in in @built_ins,
    do: apply(Kernel, String.to_existing_atom(built_in), args)

  def callback(_context, "map", [enumerable, mapper]), do: Enum.map(enumerable, mapper)
  def callback(_context, "date", [year, month, day]), do: Date.new!(year, month, day)
  def callback(_context, "echo", [a]), do: a

  def callback(_context, "has_any_word", [haystack, words]) do
    haystack_words = String.split(haystack)
    haystacks_lowercase = Enum.map(haystack_words, &String.downcase/1)
    words_lowercase = String.split(words) |> Enum.map(&String.downcase/1)

    matched_indices =
      haystacks_lowercase
      |> Enum.with_index()
      |> Enum.filter(fn {haystack_word, _index} ->
        Enum.member?(words_lowercase, haystack_word)
      end)
      |> Enum.map(fn {_haystack_word, index} -> index end)

    matched_haystack_words = Enum.map(matched_indices, &Enum.at(haystack_words, &1))

    match? = Enum.any?(matched_haystack_words)

    %{
      "__value__" => match?,
      "match" => if(match?, do: Enum.join(matched_haystack_words, " "), else: nil)
    }
  end
end
