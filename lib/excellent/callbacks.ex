defmodule Excellent.Callbacks do
  def handle(function_name, arguments, context) do
    function_name =
      function_name
      |> String.downcase()
      |> String.to_atom()

    if function_exported?(__MODULE__, function_name, length(arguments) + 1) do
      apply(__MODULE__, function_name, [context] ++ arguments)
    else
      {:error, :not_implemented}
    end
  end

  @doc """
  Returns the current date time as UTC
  """
  def now(_ctx) do
    DateTime.utc_now()
  end

  @doc """
  constructs a date
  """
  def date(_ctx, year, month, day) do
    fields = [
      calendar: Calendar.ISO,
      year: year,
      month: month,
      day: day,
      hour: 0,
      minute: 0,
      second: 0,
      time_zone: "Etc/UTC",
      zone_abbr: "UTC",
      utc_offset: 0,
      std_offset: 0
    ]

    struct(DateTime, fields)
  end
end
