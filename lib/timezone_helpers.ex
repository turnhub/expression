defmodule Expression.TimezoneHelpers do
  @moduledoc """
  A helper module which reads a text file we've originally downloaded from
  Google's [libphonenumber](https://github.com/google/libphonenumber) and
  automatically generates helper functions for converting a phone number
  or a country dialing prefix to one or more timezones.

  The functions are dynamically generated at compile time.

  # Example

      ```elixir
      defmodule MyModule do
        use Expression.TimezoneHelpers
      end
      ```

      iex> MyModule.timezone_for_prefix("31")
      ["Europe/Amsterdam"]
      iex> MyModule.timezone_for_e164("+31612345678")
      ["Europe/Amsterdam"]

  """

  @map_file Path.join(Application.app_dir(:expression), "priv/phone_prefix_timezone_map.txt")
  @map_data File.read!(@map_file)
  @map_entries @map_data
               |> String.split("\n")
               |> Enum.map(&String.trim/1)
               |> Enum.reject(&(String.starts_with?(&1, "#") || String.equivalent?(&1, "")))
               |> Enum.map(fn line ->
                 [prefix, timezones] = String.split(line, "|")
                 {prefix, String.split(timezones, "&")}
               end)
               # Sort them by length of the prefix in descending order
               # This ensures that we leave `+1` as a last resort when dealing with an
               # phone number beginning with `+120831` for example
               |> Enum.sort_by(fn {prefix, _timezones} -> String.length(prefix) end, :desc)

  defmacro __before_compile__(_opts) do
    for {prefix, timezones} <- @map_entries do
      quote do
        def timezones_for_prefix(unquote(prefix)), do: unquote(timezones)
        def timezones_for_e164("+" <> unquote(prefix) <> <<rest::binary>>), do: unquote(timezones)
      end
    end
  end

  defmacro __using__(_opts) do
    quote do
      @before_compile Expression.TimezoneHelpers
    end
  end

  def all, do: @map_entries
end
