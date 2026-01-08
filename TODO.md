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

### Expected type

Some nodes, like if or case statements could benefit from getting an expected
type. We can assume the expected type of an if or a case is the first branch
but that'd be wrong if the is a type already expected from above. This is a
problem of having all the typechecking happening bottom up, so maybe adding
some top down expected type could help.

### Holes for currying

Person(_, _, _, _)
is the same as (\a -> \b -> \c -> \d -> Person(a, b, c, d))


### SemanticAnalysis::Exposed

Semantic analysis of exposed symbols


### Tweaks

Dry entry versions of compilation step.
Split entry into it's own file and.


### Bugs

Scope should collect types and values independently, so
type and variant constructor can both be added.


### Reference Index Phase

New pass to track usages of symbols. This is helpful for duplicate error
(now being raised by semantic analysis), unused imports and dead code detection.



### No args constructor into constants

Having to do Nothing() is alien, and probably a trap. So having
Just be a function but Nothing be a constant would make tons of sense.

# return type_from_symbol(symbol.union, registry) if symbol.args.empty?
