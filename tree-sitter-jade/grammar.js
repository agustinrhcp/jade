// Tree-sitter grammar for the Jade programming language.
// Jade is a statically-typed functional language that compiles to Ruby.

module.exports = grammar({
  name: 'jade',

  // The token used for keyword disambiguation.
  // Ensures keywords like `def` are not confused with identifiers like `default`.
  word: $ => $.identifier,

  // Whitespace and comments are allowed anywhere.
  extras: $ => [/\s+/, $.comment],

  // Conflicts that tree-sitter resolves via GLR.
  conflicts: $ => [
    // `identifier` starts both a variable_binding and a variable_reference (expression).
    [$.variable_binding, $.variable_reference],
    // `(expr` starts both a tuple and a grouping.
    [$.tuple, $.grouping],
    // A type_atom/expression starts both a type_function and a standalone type.
    [$._type_atom, $.type_function],
    [$._type_expression, $.type_function],
    // record_literal vs record_update both start with `{ identifier`.
    [$.record_literal, $.record_update],
    // constructor_pattern with no args looks like a bare constant reference.
    [$.constructor_pattern, $.constructor_reference],
    // tuple_pattern vs grouping-like patterns both start with `(`.
    [$.tuple_pattern, $.pattern],
    // Lambda params vs grouped type expressions.
    [$.lambda_param, $.type_variable],
    // Lambda params vs variable_reference (both are identifiers inside parens).
    [$.lambda_param, $.variable_reference],
    // _primary vs member_access / function_call (left-recursive postfix chain).
    [$._primary, $.member_access],
    [$._primary, $.function_call],
  ],

  rules: {
    // =========================================================================
    // Top-level
    // =========================================================================

    source_file: $ => choice(
      seq($.module_header, repeat($._top_level_item)),
      repeat($._top_level_item),
    ),

    module_header: $ => seq(
      'module',
      field('name', $.module_name),
      'exposing',
      $.exposing_clause,
    ),

    module_name: $ => prec.left(seq(
      $.constant,
      repeat(seq('.', $.constant)),
    )),

    exposing_clause: $ => seq(
      '(',
      choice('..', sep1($.expose_item, ',')),
      ')',
    ),

    expose_item: $ => choice(
      seq($.constant, '(', '..', ')'),  // Type(..) — export type + constructors
      $.constant,                        // Type — export type only
      $.identifier,                      // value — export value
    ),

    _top_level_item: $ => choice(
      $.function_declaration,
      $.type_declaration,
      $.struct_declaration,
      $.import_declaration,
      $.interop_import_declaration,
      $._statement,
    ),

    // =========================================================================
    // Declarations
    // =========================================================================

    function_declaration: $ => seq(
      'def',
      field('name', $.identifier),
      '(',
      optional(sep1($.param, ',')),
      ')',
      '->',
      field('return_type', $._type_expression),
      field('body', $._body),
      'end',
    ),

    param: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $._type_expression),
    ),

    type_declaration: $ => seq(
      'type',
      field('name', $.constant),
      optional($.type_params),
      '=',
      sep1($.variant_declaration, '|'),
    ),

    variant_declaration: $ => prec.right(seq(
      field('name', $.constant),
      optional(seq('(', sep1($._type_expression, ','), ')')),
    )),

    struct_declaration: $ => seq(
      'struct',
      field('name', $.constant),
      optional($.type_params),
      '=',
      $.record_type,
    ),

    import_declaration: $ => seq(
      'import',
      field('module', $.module_name),
      optional(seq('as', field('alias', $.constant))),
      optional(choice(
        seq('exposing', '(', '..', ')'),
        seq('exposing', '(', sep1($.expose_item, ','), ')'),
      )),
    ),

    interop_import_declaration: $ => seq(
      'uses',
      field('module', $.interop_module_name),
      'with',
      sep1($.interop_function, ','),
    ),

    interop_module_name: $ => seq(
      $.constant,
      repeat(seq('::', $.constant)),
    ),

    interop_function: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $._type_expression),
    ),

    // =========================================================================
    // Types
    // =========================================================================

    _type_expression: $ => choice(
      $.type_function,
      $._type_atom,
      $.record_type,
    ),

    // Function type: `a -> b` or `a -> b -> c` (right-associative, curried form)
    type_function: $ => prec.right(1, seq(
      $._type_atom,
      '->',
      $._type_expression,
    )),

    _type_atom: $ => choice(
      $.type_application,
      $.qualified_type_name,
      $.type_variable,
      $.type_tuple,
      seq('(', $.type_function, ')'),
    ),

    // `Maybe(a)`, `Result(a, e)`, `List(Int)`
    type_application: $ => prec(1, seq(
      field('name', $.qualified_type_name),
      '(',
      sep1($._type_expression, ','),
      ')',
    )),

    // `Module.Type` or just `Type`
    qualified_type_name: $ => prec.left(seq(
      $.constant,
      repeat(seq('.', $.constant)),
    )),

    type_variable: $ => $.identifier,

    // `{ r | field: Type, ... }` or `{ field: Type, ... }`
    record_type: $ => seq(
      '{',
      optional(seq($.type_variable, '|')),  // row variable
      sep1($.type_field, ','),
      '}',
    ),

    type_field: $ => seq(
      field('name', $.identifier),
      ':',
      field('type', $._type_expression),
    ),

    // `(a, b)` — tuple type
    type_tuple: $ => seq(
      '(',
      $._type_atom,
      ',',
      sep1($._type_atom, ','),
      ')',
    ),

    // `(a, b)` after `type Name`
    type_params: $ => seq(
      '(',
      sep1($.identifier, ','),
      ')',
    ),

    // =========================================================================
    // Statements & Expressions
    // =========================================================================

    _statement: $ => choice(
      $.variable_binding,
      $._expression,
    ),

    variable_binding: $ => seq(
      field('name', $.identifier),
      '=',
      field('value', $._expression),
    ),

    _expression: $ => choice(
      $.case_of,
      $.if_then_else,
      $.lambda,
      $.binary_expression,
      $._primary,
    ),

    _body: $ => repeat1($._expression),

    if_then_else: $ => seq(
      'if',
      field('condition', $._expression),
      'then',
      field('then_body', $._body),
      'else',
      field('else_body', $._body),
      'end',
    ),

    case_of: $ => seq(
      'case',
      field('subject', $._expression),
      repeat1($.case_of_branch),
      'end',
    ),

    case_of_branch: $ => seq(
      'of',
      field('pattern', $.pattern),
      'then',
      field('body', $._body),
    ),

    lambda: $ => seq(
      '(',
      optional(sep1($.lambda_param, ',')),
      ')',
      '->',
      '{',
      field('body', $._body),
      '}',
    ),

    lambda_param: $ => $.identifier,

    // Binary infix expressions with operator precedence.
    binary_expression: $ => {
      const table = [
        [1, prec.left,  choice('|>', '<|')],
        [2, prec.left,  choice('==', '!=', '<', '<=', '>', '>=')],
        [3, prec.left,  '++'],
        [4, prec.left,  choice('+', '-')],
        [5, prec.left,  choice('*', '/')],
      ];
      return choice(...table.map(([precedence, fn, op]) =>
        fn(precedence, seq(
          field('left', $._primary),
          field('operator', op),
          field('right', choice($.binary_expression, $._primary)),
        ))
      ));
    },

    // primary = atom followed by zero or more postfix applications (left-recursive)
    _primary: $ => choice(
      $.function_call,
      $.member_access,
      $._atom,
    ),

    // Function call: `foo(a, b)` or `foo()` — postfix chains left-recursively
    function_call: $ => prec.left(10, seq(
      field('function', $._primary),
      '(',
      field('arguments', optional(sep1($._expression, ','))),
      ')',
    )),

    // Member access: `foo.bar` or `Mod.Ctor` — postfix chains left-recursively
    member_access: $ => prec.left(10, seq(
      field('object', $._primary),
      '.',
      field('member', choice($.identifier, $.constant)),
    )),

    _atom: $ => choice(
      $.variable_reference,
      $.constructor_reference,
      $.tuple,
      $.grouping,
      $.record_literal,
      $.record_update,
      $.record_access_sugar,
      $.record_update_sugar,
      $.list,
      $.integer,
      $.float,
      $.boolean,
      $.string,
    ),

    // =========================================================================
    // Records
    // =========================================================================

    record_literal: $ => seq(
      '{',
      sep1($.record_field, ','),
      '}',
    ),

    record_field: $ => seq(
      field('name', $.identifier),
      ':',
      field('value', $._expression),
    ),

    // `{ person | name: "Alice" }` — record update
    record_update: $ => seq(
      '{',
      field('target', $.variable_reference),
      '|',
      sep1($.record_field, ','),
      '}',
    ),

    // `.field` — partial field access function
    record_access_sugar: $ => seq('.', $.identifier),

    // `.field =` — partial field update function
    record_update_sugar: $ => seq('.', $.identifier, '='),

    // =========================================================================
    // Grouping & Tuples
    // =========================================================================

    // `(expr, expr, ...)` — tuple literal (2+ elements)
    tuple: $ => seq(
      '(',
      $._expression,
      ',',
      sep1($._expression, ','),
      ')',
    ),

    // `(expr)` — grouping / parenthesized expression
    grouping: $ => seq(
      '(',
      $._expression,
      ')',
    ),

    // List literal `[a, b, c]`
    list: $ => seq(
      '[',
      optional(sep1($._expression, ',')),
      ']',
    ),

    // =========================================================================
    // Patterns
    // =========================================================================

    pattern: $ => choice(
      $.wildcard_pattern,
      $.literal_pattern,
      $.tuple_pattern,
      $.record_pattern,
      $.constructor_pattern,
      $.binding_pattern,
    ),

    wildcard_pattern: $ => '_',

    binding_pattern: $ => $.identifier,

    literal_pattern: $ => choice(
      $.integer,
      $.float,
      $.boolean,
      $.string,
    ),

    constructor_pattern: $ => seq(
      field('constructor', $.constant),
      optional(seq('(', optional(sep1($.pattern, ',')), ')')),
    ),

    tuple_pattern: $ => seq(
      '(',
      $.pattern,
      ',',
      sep1($.pattern, ','),
      ')',
    ),

    record_pattern: $ => seq(
      '{',
      sep1($.record_field_pattern, ','),
      '}',
    ),

    // `name: pattern` or shorthand `name:` (binds to same name)
    record_field_pattern: $ => seq(
      field('name', $.identifier),
      ':',
      optional(field('pattern', $.pattern)),
    ),

    // =========================================================================
    // References
    // =========================================================================

    variable_reference: $ => $.identifier,
    constructor_reference: $ => $.constant,

    // =========================================================================
    // Literals
    // =========================================================================

    integer: $ => /\d+/,

    // float must be checked before integer (longer match wins in tree-sitter)
    float: $ => /\d+\.\d+/,

    boolean: $ => token(choice('True', 'False')),

    string: $ => seq(
      '"',
      optional($.string_content),
      '"',
    ),

    // String content: any characters except quote and newline
    string_content: $ => /[^"\n]*/,

    // =========================================================================
    // Primitives
    // =========================================================================

    // Identifiers start with a lowercase letter (not underscore, to avoid
    // conflict with the `_` wildcard token).
    identifier: $ => /[a-z][a-z0-9_]*/,

    // Type names, constructors, module names start with uppercase.
    constant: $ => /[A-Z][A-Za-z0-9_]*/,

    // Line comment
    comment: $ => /#[^\n]*/,
  },
});

// =========================================================================
// Helpers
// =========================================================================

// One or more occurrences of `rule` separated by `separator`.
function sep1(rule, separator) {
  return seq(rule, repeat(seq(separator, rule)));
}
