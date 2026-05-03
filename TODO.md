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


### No args constructor into constants

Having to do Nothing() is alien, and probably a trap. So having
Just be a function but Nothing be a constant would make tons of sense.

```ruby
return type_from_symbol(symbol.union, registry) if symbol.args.empty?
```


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


### No arg functions into constants

Similar to above, but

def pepe() -> Int

should be callable as pepe (without parens)
or should it not? I think it should.


### Interop part II - Tasks

Interop must return a Task
