# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Expression is an Elixir library implementing the [FLOIP Expressions](https://floip.gitbook.io/flow-specification/expressions) language - an Excel-like expression parser and evaluator used for templating with variable substitution.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/expression_test.exs

# Run a specific test by line number
mix test test/expression_test.exs:42

# Watch tests during development
mix test.watch

# Format code
mix format

# Check formatting (CI uses this)
mix format --check-formatted

# Lint with Credo
mix credo --strict

# Type checking with Dialyzer (generate PLT first time)
mix dialyzer --plt
mix dialyzer --format dialyxir
```

## Architecture

### Two Parser Implementations
The library maintains both V1 and V2 parsers for compatibility:
- **V1** (`lib/expression/parser.ex`, `lib/expression/eval.ex`) - Original implementation
- **V2** (`lib/expression/v2/`) - An EXPERIMENTAL and SOON TO BE THROWN AWAY parser with `compile.ex`, `eval.ex`, `context.ex`. MAKE NO CHANGES TO V2

Both use [NimbleParsec](https://hexdocs.pm/nimble_parsec) for parsing.

### Core Modules
- `Expression` (`lib/expression.ex`) - Main API: `evaluate!/3`, `evaluate_as_string!/3`, `parse!/1`
- `Expression.Parser` - Converts expression strings to AST
- `Expression.Eval` - Evaluates AST with given context
- `Expression.Context` - Builds context for variable substitution
- `Expression.Callbacks` - Behavior for function handlers (pluggable)
- `Expression.Callbacks.Standard` - Standard FLOIP function implementations (300+ functions)

### Expression Syntax
- Variables: `@name` or `@contact.name` (dot notation for nested access)
- Functions: `@(FUNCTION(args))` or `@FUNCTION(contact.name)`
- Escape `@` with `@@`
- Email addresses like `info@support.com` are preserved if `@support` doesn't resolve

### Type System
Expressions preserve types through evaluation (integers, floats, booleans, DateTime, Date, Time, lists). Use `evaluate_as_string!/3` when string output is needed.

## Testing

CI tests against Elixir 1.15/OTP 26, 1.18/OTP 27, and 1.19/OTP 28. Format checking runs only on 1.19/OTP 28.

Beyond `@expression_doc` doctests and `expression_test.exs`, the suite includes
systematic **type-matrix** tests per function category
(`test/*_functions_type_test.exs`) and **property-based fuzz** tests
(`test/expression_fuzz_test.exs`, tagged `:fuzz`, excluded from `mix test` —
run with `mix test --only fuzz`). These document current V1 behavior (pinning
crashes, not endorsing them). See `TESTING.md` for the full approach.
