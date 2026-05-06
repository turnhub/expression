defmodule Expression.AST do
  @moduledoc """
  Type definitions for the Expression abstract syntax tree.

  The AST is produced by `Expression.Parser` and consumed by `Expression.Eval`.
  It is also used by consumers for transpilation (e.g., to Elasticsearch queries)
  and static analysis (e.g., function validation). This module formalizes the
  AST as a public API.

  ## Top-Level Structure

  `Expression.Parser.parse/1` returns a keyword list of `:text` and `:expression`
  entries:

      [text: "hello ", expression: [atom: "world"]]

  `Expression.parse_expression!/1` returns the inner expression AST without
  the `:text`/`:expression` wrappers.

  ## Node Types

  ### Literals
  `{:literal, value}` — a constant value (integer, float, string, boolean, Date, DateTime, Time).

      {:literal, 42}
      {:literal, "hello"}
      {:literal, true}
      {:literal, ~D[2022-01-31]}

  ### Variables
  `{:atom, name}` — a variable reference. Names are always lowercased strings.

      {:atom, "contact"}
      {:atom, "name"}

  ### Attribute Access (dot notation)
  `{:attribute, [parent, child]}` — property access via `.` notation.
  Each element is itself an AST node.

      # @contact.name
      {:attribute, [{:atom, "contact"}, {:atom, "name"}]}

      # @contact.details.age
      {:attribute, [{:attribute, [{:atom, "contact"}, {:atom, "details"}]}, {:atom, "age"}]}

  ### Key Access (bracket notation)
  `{:key, [subject, key_expr]}` — index access via `[expr]` notation.

      # @items[0]
      {:key, [{:atom, "items"}, {:literal, 0}]}

  ### Function Calls
  `{:function, [name: name, args: args]}` — a function invocation.
  Name is a lowercased string. Args is a list of AST nodes.

      # SUM(1, 2)
      {:function, [name: "sum", args: [literal: 1, literal: 2]]}

      # upper(contact.name)
      {:function, [name: "upper", args: [{:attribute, [{:atom, "contact"}, {:atom, "name"}]}]]}

  Infix `and`/`or`/`not` also produce function nodes:

      # a and b
      {:function, [name: "and", args: [atom: "a", atom: "b"]]}

      # not a
      {:function, [name: "not", args: [{:atom, "a"}]]}

  ### Operators
  `{operator, [left, right]}` — binary arithmetic and comparison operators.

      # 1 + 2
      {:+, [literal: 1, literal: 2]}

      # age > 18
      {:>, [{:atom, "age"}, {:literal, 18}]}

  Supported operators: `:+`, `:-`, `:*`, `:/`, `:^`, `:&`,
  `:>`, `:>=`, `:<`, `:<=`, `:==`, `:!=`

  ### Lists
  `{:list, [args: elements]}` — a list literal. Empty list: `{:list, []}`.

      # [1, 2, 3]
      {:list, [args: [literal: 1, literal: 2, literal: 3]]}

  ### Ranges
  `{:range, [first, last]}` or `{:range, [first, last, step]}` — a numeric range.

      # 1..10
      {:range, [1, 10]}

      # 1..10//2
      {:range, [1, 10, 2]}

  ### Lambdas
  `{:lambda, [args: body]}` — an anonymous function using `&(...)` syntax.

      # &(&1 + 1)
      {:lambda, [args: {:+, [{:capture, 1}, {:literal, 1}]}]}

  ### Captures
  `{:capture, index}` — a lambda parameter reference (`&1`, `&2`, etc.).

      {:capture, 1}
      {:capture, 2}

  ## Operator Precedence (lowest to highest)

  1. `or` (infix logical)
  2. `and` (infix logical)
  3. `not` (prefix logical)
  4. `==`, `!=`, `>`, `>=`, `<`, `<=` (comparison)
  5. `+`, `-`, `&` (addition, concatenation)
  6. `*`, `/` (multiplication)
  7. `^` (exponentiation)
  """

  @typedoc "A literal value"
  @type literal :: {:literal, number | String.t() | boolean | Date.t() | DateTime.t() | Time.t()}

  @typedoc "A variable reference (always lowercased)"
  @type variable :: {:atom, String.t()}

  @typedoc "Dot-notation property access"
  @type attribute :: {:attribute, list(ast_node)}

  @typedoc "Bracket-notation index access"
  @type key :: {:key, list(ast_node)}

  @typedoc "A function call"
  @type function_call :: {:function, list({:name, String.t()} | {:args, list(ast_node)})}

  @typedoc "Binary operator expression"
  @type binary_op ::
          {:+, list(ast_node)}
          | {:-, list(ast_node)}
          | {:*, list(ast_node)}
          | {:/, list(ast_node)}
          | {:^, list(ast_node)}
          | {:&, list(ast_node)}
          | {:>, list(ast_node)}
          | {:>=, list(ast_node)}
          | {:<, list(ast_node)}
          | {:<=, list(ast_node)}
          | {:==, list(ast_node)}
          | {:!=, list(ast_node)}

  @typedoc "A list literal"
  @type list_node :: {:list, list() | list({:args, list(ast_node)})}

  @typedoc "A numeric range"
  @type range :: {:range, list(integer)}

  @typedoc "A lambda function"
  @type lambda :: {:lambda, list({:args, ast_node})}

  @typedoc "A lambda parameter reference"
  @type capture :: {:capture, pos_integer}

  @typedoc "Any AST node"
  @type ast_node ::
          literal
          | variable
          | attribute
          | key
          | function_call
          | binary_op
          | list_node
          | range
          | lambda
          | capture

  @typedoc "A text segment in a parsed template"
  @type text :: {:text, String.t()}

  @typedoc "An expression segment in a parsed template"
  @type expression :: {:expression, list(ast_node)}

  @typedoc "A parsed template — the output of `Expression.parse!/1`"
  @type template :: list(text | expression)

  @typedoc "A parsed expression block — the output of `Expression.parse_expression!/1`"
  @type block :: list(ast_node)
end
