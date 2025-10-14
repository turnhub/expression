defmodule ExpressionCallbacksTest do
  use ExUnit.Case, async: true
  doctest Expression.Callbacks, import: true
  doctest Expression.Callbacks.Standard, import: true
end
