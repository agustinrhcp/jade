; Scopes
(module_header) @local.scope
(function_declaration) @local.scope
(case_of) @local.scope
(lambda) @local.scope

; Definitions
(function_declaration
  name: (identifier) @local.definition.function)

(param
  name: (identifier) @local.definition.parameter)

(variable_binding
  name: (identifier) @local.definition.variable)

(type_declaration
  name: (constant) @local.definition.type)

(struct_declaration
  name: (constant) @local.definition.type)

; References
(identifier) @local.reference
