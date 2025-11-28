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

ForwardDeclaration: looking up undeclared symbols can return nil. That needs to fail
and return a helpful error.

FixityFixer: can fail if invalid operators are chained

### AST Nodes

ConstructorReference and VariableReference are a bit annoying.
String is a constructor reference if we are trying to build a string,
but it could also be a module name. So having the parser determine that
is a mistake. We don't know what they actually are until we start semantic
analysis. We should record what the user wrote, not what it means at parse
time.

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
