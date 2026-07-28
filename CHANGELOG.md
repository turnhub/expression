# Changelog

## v3.0.0-rc.0

This is the first release candidate for v3.0.0. It contains the breaking
changes intended for the major version. Cut to allow downstream CI runs
to surface migration work before the final v3.0.0 tag.

### Breaking changes

- **`Context.new/2` no longer normalizes by default.** Both `lowercase_keys`
  and `coerce_strings` now default to `false`. Original key casing is
  preserved (variable lookup remains case-insensitive at evaluation time
  via `Eval.case_insensitive_get/2`), and string values pass through
  untouched. Callers that need v2 behavior must opt in explicitly:
  `Context.new(ctx, lowercase_keys: true, coerce_strings: true)`.
- **`:skip_context_evaluation?` option has been removed.** Use
  `coerce_strings: false` instead.
- **`Expression.error/1` has been removed.** Use `Expression.error_map/1`
  to produce the legacy error map shape, or raise `Expression.Error` for
  new code.
- **The entire V2 parser/evaluator has been removed.** All modules under
  `lib/expression/v2/` (`Expression.V2`, `Expression.V2.Parser`,
  `Expression.V2.Compile`, `Expression.V2.Context`, `Expression.V2.Eval`,
  `Expression.V2.Callbacks`, `Expression.V2.Callbacks.Standard`,
  `Expression.V2.Autodoc`) and `Expression.V2.Compat` are gone. Consumers
  using V2 for static analysis (`Expression.V2.parse_block/1`,
  `Expression.V2.Compile.to_quoted/1`) will need to migrate to V1's
  AST surface or build their own analysis layer.

### Added

- **v2-compat mode on all evaluation entry points.** `evaluate!/4`,
  `evaluate/4`, `evaluate_block!/4`, `evaluate_block/4`,
  `evaluate_as_string!/4`, `evaluate_as_boolean!/4` and
  `evaluate_template!/4` accept a trailing options list. `mode: :v2`
  expands to `lowercase_keys: true, coerce_strings: true`, restoring the
  v2 context normalization per evaluation; explicitly passed flags win
  over the expansion. This lets a consumer run v2- and v3-semantics
  evaluations side by side in the same VM.

### Migration

See `V3_PLAN.md` for the detailed plan and engage-specific impact notes.
