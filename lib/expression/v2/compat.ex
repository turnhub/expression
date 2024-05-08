defmodule Expression.V2.Compat do
  @moduledoc """
  Compatibility module to make the transition from V1 to V2 a bit easier, hopefully.

  It does a few things:

  * It swaps out V2 callbacks for V1 callbacks when evaluating expressions with V1.
  * It does some patching of the context to match V1's assumptions:
      * case insensitive context keys
      * casting of integers
      * casting of datetimes
  * It compares the output of V1 to V2, if those aren't equal it will log an error and return the V1 response.
  * If there is no error it will return the value from V2.

  > **NOTE**: This module does *twice* the work because it runs V1 and V2 sequentially
    and then compares the result before returning a value.
  """
  @behaviour Expression.Behaviour
  require Logger
  alias Expression.V2

  def evaluate_as_string!(
        expression,
        context,
        callback_module \\ V2.Callbacks.Standard
      )

  def evaluate_as_string!(expression, context, callback_module) do
    v1_resp = Expression.evaluate_as_string!(expression, context, v1_module(callback_module))

    v2_resp =
      V2.eval_as_string(
        expression,
        V2.Context.new(patch_v1_context(context), callback_module)
      )

    return_or_log(expression, context, v1_resp, v2_resp)
  end

  def v1_module(Turn.Build.Callbacks), do: Turn.Build.CallbacksV1
  def v1_module(V2.Callbacks.Standard), do: Expression.V1.Callbacks.Standard

  def patch_v1_key(key),
    do:
      key
      |> to_string()
      |> String.downcase()

  def patch_v1_context(datetime) when is_struct(datetime, DateTime), do: datetime

  def patch_v1_context(date) when is_struct(date, Date), do: date

  def patch_v1_context(struct) when is_struct(struct) do
    Map.from_struct(struct)
    |> patch_v1_context()
  end

  def patch_v1_context(list) when is_list(list), do: Enum.map(list, &patch_v1_context/1)

  def patch_v1_context(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> {patch_v1_key(key), patch_v1_context(value)} end)
    |> Enum.into(%{})
  end

  def patch_v1_context(binary) when is_binary(binary) do
    with :nope <- attempt_integer(binary),
         :nope <- attempt_float(binary),
         :nope <- attempt_datetime(binary),
         :nope <- attempt_boolean(binary) do
      binary
    end
  end

  def patch_v1_context(other), do: other

  def attempt_boolean(binary) do
    potential_boolean =
      binary
      |> String.trim()
      |> String.downcase()

    case potential_boolean do
      "true" -> true
      "false" -> false
      _other -> :nope
    end
  end

  # Leading plus is still parsed as an integer, which we don't want
  def attempt_integer("+" <> _), do: :nope
  # Leading zero likely means a string code, not an integer
  def attempt_integer("0" <> binary) when byte_size(binary) > 0, do: :nope

  def attempt_integer(binary) do
    String.to_integer(binary)
  rescue
    ArgumentError -> :nope
  end

  # Leading plus is still parsed as an integer, which we don't want
  def attempt_float("+" <> _), do: :nope

  def attempt_float(binary) do
    String.to_float(binary)
  rescue
    ArgumentError -> :nope
  end

  def attempt_datetime(binary) do
    case DateTime.from_iso8601(binary) do
      {:ok, datetime, _} -> datetime
      _other -> :nope
    end
  end

  def evaluate!(expression, context \\ %{}, callback_module \\ V2.Callbacks.Standard)

  def evaluate!(expression, context, callback_module) do
    v1_resp = Expression.evaluate!(expression, context, v1_module(callback_module))

    v2_resp =
      V2.eval(
        expression,
        V2.Context.new(patch_v1_context(context), callback_module)
      )
      |> hd

    return_or_log(expression, context, v1_resp, v2_resp)
  end

  def evaluate_block!(
        expression,
        context \\ %{},
        callback_module \\ V2.Callbacks.Standard
      )

  def evaluate_block!(expression, context, callback_module) do
    v1_resp = Expression.evaluate_block(expression, context, v1_module(callback_module))

    v2_resp =
      case V2.eval_block(
             expression,
             V2.Context.new(patch_v1_context(context), callback_module)
           ) do
        {:error, error, reason} -> {:error, error <> " " <> reason}
        value -> {:ok, value}
      end

    cond do
      # Hack for handling random returns from `rand_between()` callback function
      # these will throw an error because they're designed to be different every time
      String.contains?(expression, "rand_between") ->
        return_or_log(expression, context, v2_resp, v2_resp)

      # Hack for handling `@if` expressions, in V2 these aren't evaluated.
      # See the note for this in `eval_compat_test.exs`.
      String.contains?(String.downcase(expression), ["@if", "@left"]) ->
        return_or_log(expression, context, v2_resp, v2_resp)

      true ->
        return_or_log(expression, context, v1_resp, v2_resp)
    end
  end

  def return_or_log(
        _expression,
        _context,
        {:not_found, _v1_path} = _v1_resp,
        nil = _v2_resp
      ) do
    nil
  end

  def return_or_log(expression, context, {:ok, val1}, {:ok, val2}) do
    return_or_log(expression, context, val1, val2)
  end

  def return_or_log(expression, _context, {:error, error1}, {:error, error2}) do
    Logger.error("#{inspect(expression)} -> error1: #{inspect(error1)}")
    Logger.error("#{inspect(expression)} -> error2: #{inspect(error2)}")
    error2
  end

  def return_or_log(expression, context, "2023" <> _ = v1_resp, "2023" <> _ = v2_resp)
      when byte_size(v1_resp) == 10 do
    {:ok, v1_resp} = Date.from_iso8601(v1_resp)
    {:ok, v2_resp} = Date.from_iso8601(v2_resp)
    return_or_log(expression, context, v1_resp, v2_resp)
  end

  def return_or_log(expression, context, "2023" <> _ = v1_resp, "2023" <> _ = v2_resp) do
    {:ok, v1_resp, _} = DateTime.from_iso8601(v1_resp)
    {:ok, v2_resp, _} = DateTime.from_iso8601(v2_resp)
    return_or_log(expression, context, v1_resp, v2_resp)
  end

  def return_or_log(expression, context, v1_resp, v2_resp) do
    cond do
      is_binary(v1_resp) and is_binary(v2_resp) ->
        return_or_log_binaries(expression, context, v1_resp, v2_resp)

      is_struct(v1_resp, DateTime) and is_struct(v2_resp, DateTime) ->
        if DateTime.diff(v1_resp, v2_resp) <= :timer.seconds(1) do
          v2_resp
        else
          log_error(expression, context, v1_resp, v2_resp)
        end

      normalize_value(v1_resp) == normalize_value(v2_resp) ->
        v2_resp

      true ->
        log_error(expression, context, v1_resp, v2_resp)
    end
  end

  # To minimize random errors due to the V1 & V2 expressions being evaluated at different
  # times we're truncating DateTime structs to the second to give the CPU some grace
  # In the `return_or_log` we confirm that it's still within a second though and return
  # the original (non truncated) value
  def normalize_value(%DateTime{} = datetime), do: DateTime.truncate(datetime, :second)
  def normalize_value(list) when is_list(list), do: Enum.map(list, &normalize_value/1)

  def normalize_value(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.map(fn {key, value} -> {key, normalize_value(value)} end)
    |> Enum.into(%{})
  end

  def normalize_value(other), do: other

  def return_or_log_binaries(expression, context, v1_resp, v2_resp) do
    if String.jaro_distance(v1_resp, v2_resp) > 0.9 do
      v2_resp
    else
      log_error(expression, context, v1_resp, v2_resp)
    end
  end

  def log_error(expression, context, v1_resp, v2_resp) do
    Logger.error("""

    ** Compatibility Error **

    Expression: #{inspect(expression)}
    Context: #{inspect(Map.drop(context, ["flow"]), pretty: true)}

    V1: #{inspect(v1_resp)}
    V2: #{inspect(v2_resp)}
    """)

    v1_resp
  end
end
