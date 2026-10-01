defmodule Expression.Test.CrashSafe do
  @moduledoc """
  Single source of truth for the expression functions empirically confirmed
  crash-safe — i.e. they never raise, returning a value or an error map — across
  the full type matrix (`Expression.Test.TypeTestMatrix.all_test_values/0`).

  Two suites consume this list so the classification cannot silently drift:

    * `ExpressionFuzzTest` fuzzes each entry with random inputs (the no-crash
      invariant under exploration).
    * `CrashSafeClassificationTest` runs each entry against the full type matrix
      deterministically (the no-crash invariant pinned, every CI run).

  Each entry is `{label, expression}` where `value` is the argument under test,
  bound to the `value` key in the context. Multi-argument functions exercise the
  first argument and hold the rest fixed.

  Functions NOT listed here currently raise on at least some inputs; those
  crashes are pinned per-function in the `*_functions_type_test.exs` files.
  Moving a function in here is only valid once it has been hardened to return an
  error map instead of raising.
  """

  @groups [
    {"string",
     [
       {"upper", "upper(value)"},
       {"lower", "lower(value)"},
       {"proper", "proper(value)"},
       {"trim", "trim(value)"}
     ]},
    {"logical",
     [
       {"not", "not(value)"},
       {"if", "if(value, 1, 2)"},
       {"and", "and(value, true)"},
       {"or", "or(value, false)"},
       {"isnumber", "isnumber(value)"},
       {"isbool", "isbool(value)"},
       {"isstring", "isstring(value)"},
       {"is_error", "is_error(value)"},
       {"is_nil_or_empty", "is_nil_or_empty(value)"}
     ]},
    {"number",
     [
       {"max", "max(value, 1)"},
       {"min", "min(value, 1)"}
     ]},
    {"enum",
     [
       {"uniq", "uniq(value)"},
       {"with_index", "with_index(value)"},
       {"has_all_members", "has_all_members(value, [1])"},
       {"has_any_member", "has_any_member(value, [1])"}
     ]},
    {"other",
     [
       {"json", "json(value)"}
     ]}
  ]

  @doc "Crash-safe functions grouped by category: `[{category, [{label, expr}]}]`."
  def groups, do: @groups

  @doc "All crash-safe `{label, expression}` entries, flattened across categories."
  def all, do: Enum.flat_map(@groups, fn {_category, entries} -> entries end)

  @doc "The `{label, expression}` entries for a single category."
  def group(category) do
    {^category, entries} = List.keyfind(@groups, category, 0)
    entries
  end
end
