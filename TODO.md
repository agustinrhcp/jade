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


### Sql.Uuid: short (Base64) display form

UUID's 36-char canonical form is too noisy for URLs / admin UIs / logs.
Add `Sql.Uuid.to_b64(u) -> String` and `from_b64(s) -> Maybe(Uuid)` that
round-trip the 16 raw bytes through url-safe Base64 (no padding) — 22
chars instead of 36, same v7 time-ordering preserved.

Implementing this in pure Jade is ~150 LOC because Jade has no bit ops
and no String-Bytes interop. Wait for the `bytes-decodable` branch to
land (adds `Bytes`, `Bytes.Encode`, `Bytes.Decode` stdlib modules with
Base64 codecs). Then `Sql.Uuid.to_b64` collapses to:

```jade
def to_b64(u: Uuid) -> String
  Uuid(s) = u
  s |> String.replace("-", "") |> Bytes.from_hex |> Bytes.to_base64
```

Prereqs:
- `bytes-decodable` merged to master.
- Add `Bytes.from_hex(String) -> Maybe(Bytes)` and `Bytes.to_hex(Bytes) -> String`.
- Add `Bytes.to_url_safe_base64(Bytes) -> String` and `from_url_safe_base64(String) -> Maybe(Bytes)` (the existing Encodable uses standard base64 with `+/`; url-safe needs `-_`).


### jade-sql: round-trip test for schema generator output

The schema generator (`jade:schema` rake task) emits a `schema.jd` file
from `db/structure.sql`. There are unit tests asserting the generated
*string* contains the expected substrings, but nothing asserts the
output actually compiles. A compiler/formatter change can silently
break the generator for real users.

When jade-sql moves to its own gem, add an integration spec:
generate from a multi-table fixture SQL, feed through `test_compiler`,
assert it compiles, and that a simple `from(persons) |> to_sql` works.


