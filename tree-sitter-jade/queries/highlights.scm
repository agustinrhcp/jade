; ===========================================================================
; Jade language Tree-sitter highlights
; ===========================================================================

; ---------------------------------------------------------------------------
; Keywords
; ---------------------------------------------------------------------------

[
  "def"
  "end"
] @keyword.function

[
  "type"
  "struct"
] @keyword.type

[
  "module"
  "import"
  "exposing"
  "as"
  "uses"
  "with"
] @keyword.module

[
  "case"
  "of"
] @keyword.control

[
  "if"
  "then"
  "else"
] @keyword.control.conditional

; ---------------------------------------------------------------------------
; Function declarations
; ---------------------------------------------------------------------------

(function_declaration
  name: (identifier) @function)

(interop_function
  name: (identifier) @function)

; ---------------------------------------------------------------------------
; Parameters
; ---------------------------------------------------------------------------

(param
  name: (identifier) @variable.parameter)

(lambda_param) @variable.parameter

; ---------------------------------------------------------------------------
; Types
; ---------------------------------------------------------------------------

; Type names in declarations
(type_declaration
  name: (constant) @type.definition)

(struct_declaration
  name: (constant) @type.definition)

; Variant constructors in type declarations
(variant_declaration
  name: (constant) @constructor)

; Type applications and references
(type_application
  name: (qualified_type_name) @type)

(qualified_type_name) @type

(type_variable) @type.parameter

(record_type
  (type_variable) @type.parameter)  ; row variable

(type_field
  name: (identifier) @variable.other.member)

; ---------------------------------------------------------------------------
; Module system
; ---------------------------------------------------------------------------

(module_header
  name: (module_name) @type)

(import_declaration
  module: (module_name) @type)

(import_declaration
  alias: (constant) @type)

(interop_import_declaration
  module: (interop_module_name) @type)

; ---------------------------------------------------------------------------
; Constructors and constants
; ---------------------------------------------------------------------------

(constructor_reference) @constructor

(constructor_pattern
  constructor: (constant) @constructor)

; Booleans are upper-case constructors
(boolean) @constant.builtin.boolean

; ---------------------------------------------------------------------------
; Variables and references
; ---------------------------------------------------------------------------

(variable_reference) @variable
(binding_pattern) @variable
(variable_binding name: (identifier) @variable)

; Record field names
(record_field name: (identifier) @variable.other.member)
(record_field_pattern name: (identifier) @variable.other.member)
(record_access_sugar (identifier) @variable.other.member)
(record_update_sugar (identifier) @variable.other.member)
(record_update target: (variable_reference) @variable)

; ---------------------------------------------------------------------------
; Operators
; ---------------------------------------------------------------------------

[
  "+"  "-"  "*"  "/"
  "==" "!=" "<"  "<="  ">"  ">="
  "++"
  "|>" "<|"
  "|"
  "->"
  "="
] @operator

; ---------------------------------------------------------------------------
; Punctuation
; ---------------------------------------------------------------------------

["(" ")" "[" "]" "{" "}"] @punctuation.bracket
["," ":" "." ".." "::"] @punctuation.delimiter

; ---------------------------------------------------------------------------
; Literals
; ---------------------------------------------------------------------------

(integer) @constant.numeric
(float) @constant.numeric
(string) @string
(string_content) @string

; Wildcard in patterns
(wildcard_pattern) @variable.builtin

; ---------------------------------------------------------------------------
; Comments
; ---------------------------------------------------------------------------

(comment) @comment
