# v3.0.0 Release Plan

Branch: `release/3-0-0` (from `develop` at `cb7657c`)
Current version: `2.49.0`
Target version: `3.0.0`

This plan turns the deferred items in `CRITICAL_REVIEW.md` (Phase 7 plus
related cleanups) into a concrete set of breaking changes for v3, with
consumer impact for each. Engage is the only known production consumer;
its dependencies on the current behavior are noted inline.

---

## Scope

### In scope (breaking)

1. **Flip `Context.new/2` defaults**: `coerce_strings: false`, `lowercase_keys: false`. *(Section 10.2)*
2. **Remove `Expression.error/1`** (deprecated since v2.x). *(Section 10.1)*
3. **Remove the entire V2 namespace** including `Expression.V2.Compat`. *(Section 10.7)*
4. **Drop the `:skip_context_evaluation?` legacy alias** on `Context.new/2` (replaced by `coerce_strings:`).

### In scope (additive)

5. **v2-compat mode**: all evaluation entry points accept a trailing options list; `mode: :v2` expands to `lowercase_keys: true, coerce_strings: true`, restoring v2 context normalization per evaluation so consumers can run v2- and v3-semantics evaluations side by side in one VM.

### Out of scope (defer to v3.x or v4)

- Converting the `{:not_found, path}` sentinel to `Expression.Error{type: :not_found}` — deep evaluator change, large blast radius; tackle once v3 is stable.
- AST migration from keyword lists to structs — breaks every consumer that pattern-matches the AST (engage's `ElasticsearchConverter`).
- Splitting `Expression.Callbacks.Standard` — pure refactor, no v3 hook needed.
- Converting `guard_type!` raises from `RuntimeError` to `Expression.Error` — already shadowed in practice by the top-level `evaluate!` rescue/reraise; the only caller pattern-matching `RuntimeError` (engage `public_exceptions.ex:118`) is already non-functional against v2.49.

---

## Per-change consumer impact

### 1. Context default flips

**Change**

```elixir
# v2: lowercases keys, coerces strings
Context.new(%{"FirstName" => "Jane", "age" => "30"})
#=> %{"firstname" => "Jane", "age" => 30}

# v3: preserves both
Context.new(%{"FirstName" => "Jane", "age" => "30"})
#=> %{"FirstName" => "Jane", "age" => "30"}
```

The evaluator already supports case-insensitive lookup (`Eval.case_insensitive_get/2`), so `@firstname` still resolves against `"FirstName"`. String coercion is gone — callers that relied on `"2020-12-13"` becoming a `Date` must call the relevant parsing function explicitly.

**Migration**

- Callers that need v2 behavior pass options explicitly: `Context.new(ctx, lowercase_keys: true, coerce_strings: true)`.
- Add a CHANGELOG note with both flags spelled out.

**Engage impact**

- Engage's contexts already use lowercase string keys (`"contact"`, `"number"`). `lowercase_keys: false` is a no-op for engage. ✅
- String coercion is the risk: engage may rely on `"2020-12-13T..."` → `DateTime` conversion implicitly. Audit `Build.default_context/1` and any `Context.new/1` call sites in engage before merging.
- Engage test `test/turn/build/callbacks_test.exs:291` passes `[]` opts explicitly — stays correct, but its expectations may shift if the test data contains coercible strings.

### 2. Remove `Expression.error/1`

**Change**

`Expression.error/1` is deleted. `Expression.error_map/1` (currently `@doc false`) becomes the public way to produce the legacy error map shape, but new code should raise `Expression.Error` instead.

**Engage impact**

- One call site: `lib/turn/build/callbacks.ex:188` (`Expression.error("Unable to generate token")`). Engage must switch to `Expression.error_map/1` or to raising/returning `Expression.Error`. Coordinate the engage PR with the v3 bump.

### 3. Remove `Expression.V2.Compat`

**Change**

The module is deleted. `test/expression/v2/eval_compat_test.exs` is removed too.

**Engage impact**

- None. Engage's only `Compat` references are to `Turn.Elasticsearch.Index.Compat.Bulk` (unrelated). Verified.
- `flow_runner` does not reference it either (verified — no matches in `deps/`).

### 4. Drop `:skip_context_evaluation?` alias

**Change**

`Context.new(ctx, skip_context_evaluation?: true)` no longer works; use `coerce_strings: false`.

**Engage impact**

- Audit: no engage call sites use `skip_context_evaluation?`. ✅

---

## Other v3 candidates worth considering

These weren't in Phase 7 but are natural fits for a major bump. **Not committed** — flag for discussion before doing them.

| Candidate | Reason for / against |
|---|---|
| Remove `evaluate_block`'s implicit `{:ok, _}` wrapping | Already consistent today — skip. |
| Stricter `evaluate_as_boolean!` (no truthiness coercion) | Would break flows. Skip unless requested. |
| Audit `op/3` operator coercion (review §2.3, "5" > "3") | Behavior change without API change. Risky. Skip for v3. |
| `String.to_atom/1` already fixed in Phase 1 | No-op. |

---

## Implementation order

Each step is its own commit; each commit ships green tests.

1. **Bump `@version` to `3.0.0-rc.0`** in `mix.exs` plus a `CHANGELOG.md` skeleton.
2. **Remove `Expression.V2.Compat`** + its test file (low risk, isolated).
3. **Remove `Expression.error/1`**; keep `error_map/1` as `@doc true` public.
4. **Drop `:skip_context_evaluation?` alias** in `Context.new/2`.
5. **Flip `Context.new/2` defaults** to `lowercase_keys: false, coerce_strings: false`. Update doctests in `lib/expression/context.ex`. Run targeted tests on `test/expression/context_test.exs` and any test that builds contexts with mixed-case or string-coercible values.
6. **Tag `3.0.0-rc.0`** and run full engage CI against it. Address fallout (engage's `Expression.error/1` call site).
7. **Add the v2-compat mode** (`mode: :v2` options on all evaluation entry points) with a test corpus proving the v2 semantics.
8. **Bump `@version` to `3.0.0`** and finalize `CHANGELOG.md` once rc is green.

---

## CHANGELOG skeleton

```markdown
## v3.0.0

### Breaking changes

- `Context.new/2` no longer lowercases keys or coerces string values by
  default. Pass `lowercase_keys: true, coerce_strings: true` to restore
  v2 behavior. Variable lookup remains case-insensitive at evaluation time.
- The `:skip_context_evaluation?` option on `Context.new/2` has been
  removed. Use `coerce_strings: false` instead.
- `Expression.error/1` has been removed. Use `Expression.error_map/1`
  for the legacy map shape, or raise `Expression.Error` for new code.
- `Expression.V2.Compat` has been removed. The shim returned V1 results
  with V2 disabled — call `Expression` directly.
- All evaluation entry points accept a trailing options list; `mode: :v2`
  restores the v2 context normalization per evaluation.

### Migration

See V3_MIGRATION.md (or a section here).
```

---

## Open questions for the user

1. **Tag a `3.0.0-rc.0` first?** Lets engage CI run against the rc before we finalize. *(Done — rc.0 is tagged.)*
2. **Coordinate the engage PR before tagging v3.0.0?** Engage `callbacks.ex:188` needs to migrate off `Expression.error/1`. Either (a) land an engage-side fix to `error_map/1` first (compatible with v2.49 since `error_map/1` already exists), then bump engage to v3, or (b) tag v3 and let engage break until the engage PR lands. *(Resolved: (a) — engage migrated on v2.49.1 in turnhub/engage#13034.)*
