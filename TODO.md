# TODOs

### Parser:MultipleErrors

Collect all errors in one_of parser.
Potentially combine them by context, today we return the last one.

string | int | bool
shows "expected bool"
it should return something like "expected string, int or bool"

for that we also need to contextualize parsers, as string is not
a type, but " > chunk > "


### Frontend:HandleErrors

FixityFixer: can fail if invalid operators are chained


### AST Nodes

ConstructorReference and VariableReference are a bit annoying.
String is a constructor reference if we are trying to build a string,
but it could also be a module name. So having the parser determine that
is a mistake. We don't know what they actually are until we start semantic
analysis. We should record what the user wrote, not what it means at parse
time.


### SemanticAnalysis::Exposed

Semantic analysis of exposed symbols


### Tweaks

Dry entry versions of compilation step.


### Reference Index Phase

New pass to track usages of symbols. This is helpful for duplicate error
(now being raised by semantic analysis), unused imports and dead code detection.


### Missing Type Name Should fail

```jade
  module Pepe exposing(paul, pauls_birthday)

  def paul() -> { name : String, age : Int }
    { name: "Paul", age: 55 }
  end

  def pauls_birthday() -> Person
    paul_before_today = paul()
    { paul_before_today | age: paul_before_today.age + 1 }
  end
```

### REVISE Store types in env

At the moment we are just storing values, that makes type_from_symbol need
to calculate on every use, and some cases with free vars we should be
instantiating and we are not. We should store types as schemes in the env instead
and mimic the current lookup (to be lookup_value) when dealing with types too.

### Test Int(a)

This should fail, Int has no vars


### Interop part II - Tasks

Interop must return a Task


### Codegen: dispatch_value non-exhaustive on Application constraints

`function_call.rb:dispatch_value` only matches `Type::Constraint` with
`type: Type::Var(id:)` and `Symbol::Implementation`. When a polymorphic
fn body calls `encode(values: List(a))` and the type-checker has
already partially resolved `a` to a concrete type (so the constraint
becomes `Encodable(List(Concrete))`), the case-in falls through and
crashes with `NoMatchingPatternError`.

Repro (smallest):

```jade
def f(xs: List(a)) -> Value
  encode(xs)
end
```

Worked around in `jade-sql/sql.jd` by hand-composing
`Encode.list((x) -> { encode(x) }, values)` — bypasses the lifted
`Encodable(List(a))` derivation. Affects any caller that wants
`encode(parameterised_type)` in a polymorphic fn body.

The deriver in `frontend/type_checking/constraints/deriving/encodable.rb`
already produces the right IR (`derive_list`, `derive_nullable`,
`derive_struct`). The gap is in `dispatch_value` not knowing how to
emit the dictionary for a constraint whose type is a concrete
`Type::Application` — needs a third arm that walks the application
and pulls the inner dict from `dict_env`.


### jade-sql: round-trip test for schema generator output

The schema generator (`jade:schema` rake task) emits a `schema.jd` file
from `db/structure.sql`. There are unit tests asserting the generated
*string* contains the expected substrings, but nothing asserts the
output actually compiles. A compiler/formatter change can silently
break the generator for real users.

When jade-sql moves to its own gem, add an integration spec:
generate from a multi-table fixture SQL, feed through `test_compiler`,
assert it compiles, and that a simple `from(persons) |> to_sql` works.


