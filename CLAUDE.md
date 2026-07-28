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

The parser and evaluator live under `lib/expression/parser.ex` and
`lib/expression/eval.ex`. Parsing uses
[NimbleParsec](https://hexdocs.pm/nimble_parsec).

(The experimental V2 parser/evaluator was removed in v3.0.0.)

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
