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


### `case Decode.from_json(...) of Ok(b) ...` loses the Decodable dispatch

```jade
def f(json: String) -> Maybe(Bytes)
  case Decode.from_json(json)   # codegen emits impl_arg = [{}]
  of Ok(b)  then Just(b)
  of Err(_) then Nothing
  end
end
```

When the result of a constrained call is destructured by a `case`/`Ok(b)`
pattern, the binding-from-pattern type doesn't propagate back to the call's
constraint resolution — the dictionary slot ends up empty (`[{}]`), and the
runtime crashes with `undefined method 'desc' for nil`. Workaround: declare
the function's return type as `Result(Bytes, DecodeError)` so the constraint
resolves at the signature level (`def f(s) -> Result(Bytes, DecodeError); Decode.from_json(s); end`).

Fix probably lives in inference/pattern.rb where pattern bindings flow back
into the parent expression's expected type.


### Dict: boundary unbox for `Dict(k, v)`

`Dict` ops carry `Eq k` (concrete and Jade-internal polymorphic uses work).
The boundary wrapper for a user-written polymorphic fn with a `Dict(k, v)` arg
falls through `unbox_nominal` (Dict is a no-variant union with no destructurable
shape from the type alone) and emits the `NotCallableFromRuby` raise. To make
those wrappers callable from Ruby too, `unbox` would need a hook for opaque
stdlib types backed by a native Ruby class — for Dict, "extract a sample key
via `dict.hash.keys.first`, dispatch on its class, fall back to `{}` when
empty." Same shape as `unbox_list`'s `[head, *] then ...; [] then {}` pattern.
