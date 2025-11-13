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
