# TODOs

### Parser:MultipleErrors

Collect all errors in one_of parser.
Potentially combine them by context, today we return the last one.

string | int | bool
shows "expected bool"
it should return something like "expected string, int or bool"

for that we also need to contextualize parsers, as string is not
a type, but " > chunk > "


### ForwardDeclaration:HandleErrors

Looking up undeclared symbols can return nil. That needs to fail
and return a helpful error.


### AST Nodes

Current VarReference should probably be renamed to identifier.
And have a new VarReference for the a in Maybe(a) and Just(a).

### Holes for currying

Person(_, _, _, _)
is the same as (\a -> \b -> \c -> \d -> Person(a, b, c, d))
