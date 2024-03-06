defmodule ExpressionCallbacksTest do
  use ExUnit.Case, async: true
  doctest Expression.V1.Callbacks, import: true
  doctest Expression.V1.Callbacks.Standard, import: true
end
