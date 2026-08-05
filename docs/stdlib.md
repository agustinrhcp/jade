# Standard library

## Finding a function

Ask the compiler, don't grep:

```
jade q api                 # every module, and where it came from
jade q api Dict            # one module, with signatures
jade q api List.fold       # one symbol
jade q find fold           # everything named `fold`
```

Grep is the wrong tool here, and quietly so. Stdlib modules are written two
ways — Jade source in a heredoc (`Maybe`, `Result`, `Decimal`, …) and a Ruby
DSL (`List`, `String`, `Dict`, `Decode`, …) — so half of them never spell `def`
at all, and none of them contains the string `List.map` you'd search for.
Extension modules aren't in your tree at all; they live in a gem. A grep that
comes back empty means nothing.

`jade q api` reads the registry the compiler itself resolves against, so it
can't drift from what exists. It answers what grep can't: the argument order
(`List.fold` folds with `(b, a) -> b`, `Dict.fold` with `(k, v, b) -> b`), the
interface constraints (`List.sort : Comparable a => …`), a struct's fields
(`struct Date = { year : Int, month : Month, day : Int }`), and which types
implement `Decodable` or `Encodable`.

Run inside a project and it covers three origins, each tagged in the output:

| `origin` | what |
|---|---|
| `stdlib` | the modules below |
| `project` | your own `.jd` files, under the source root |
| `extension` | modules an extension gem ships (`jade-sql`'s `Sql.Query`, …) |

Without a `jade.json` it falls back to the stdlib alone, so the query still
works from anywhere. A file that won't compile is named under `skipped` rather
than quietly missing — an absent module reads as "that function doesn't
exist", which is the failure this is here to prevent.

## What's where

Every module's source lives in [`lib/jade/stdlib/`](../lib/jade/stdlib/) — short,
readable Ruby. This is a map of the territory; `jade q api` is the atlas.

| Module | What's there |
|--------|--------------|
| `Basics` | The built-in interfaces — `Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable` — plus the `Ordering` type (`LT` / `EQ` / `GT`) and `Never`. `++` works on `String`, `List`, and `Bytes` via `Appendable`. |
| `Maybe` | Optional values without `nil`: `Just(a)` / `Nothing`, with `map`, `and_then`, `with_default`. |
| `Result` | Errors as values, no exceptions: `Ok(a)` / `Err(e)`, with `map`, `and_then`, `map_error`, `on_error`, `sequence`. |
| `List` | Immutable lists: `map`, `filter`, `fold`, `zip`, `sort`, `length`, `range`, `head`, `tail`, `take`, `drop`, … |
| `String` | Text: `length`, `reverse`, `split`, `trim`, `to_int`, `contains?`, `uncons`, `cons`, `from_char`, `map`. |
| `Char` | Character predicates and codes: `to_code`, `from_code`, `digit?`, `alpha?`, `alpha_numeric?`, `upper?`, `lower?`. |
| `Tuple` | Pair accessors: `first`, `second`, `pair`. |
| `Task` | Side-effecting actions: `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence`. See [interop.md](interop.md) for how Tasks cross the Ruby boundary. |
| `Decode` | Parse JSON / Ruby data into typed values: `string`, `int`, `float`, `bool`, `list`, `field`, `index`, `succeed`, `required`, `optional`, `nullable`, `map`, `and_then`. Auto-derived for `struct` types. See [json.md](json.md). |
| `Decode.Params` | PATCH-style decoders: only fields present in the input appear in the output, missing fields don't error. For partial-update endpoints. |
| `Encode` | Symmetric to `Decode`: `string`, `int`, `float`, `bool`, `list`, `object`. Auto-derived for `struct` types via `Encodable`. |
| `Dict` | Immutable key-value map with structural equality: `empty`, `get`, `member?`, `insert`, `update`, `remove`, `keys`, `values`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `merge`. |
| `Set` | Immutable set: `empty`, `insert`, `remove`, `member?`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `intersect`, `diff`. |
| `Bytes` | Opaque byte buffer: `empty`, `width`, `from_list` / `to_list`, `from_string` / `to_string`. Implements `Eq` and `Appendable`. |
| `Calendar` | Dates and date arithmetic: `Date`, `today`. Days, months, years; no time of day — use `Clock`. |
| `Clock` | Timestamps and monotonic timing: `Instant`, `now`. Sub-second precision; the bridge to wall-clock time. |
| `Show` | Renders a value the way Jade writes it: `show(Just(7))` is `"Just(7)"`, `show(Point(3, 4))` is `"Point { x: 3, y: 4 }"`. Instances for the primitives; derives for unions, structs, records and lists. A function shows as `<function>`, and `Never` raises — it has no values. |
| `Debug` | `log(label, value)` prints `label: value` to stderr and returns the value untouched, so it drops into a pipeline. Unconstrained, unlike `Show`. |
| `Decimal` | Exact base-10 decimals (`coefficient * 10 ^ exponent`) — money and rates without `Float` rounding. Opaque; build with `of` / `scaled` / `parse`. Arithmetic via `Numeric` (`+` `-` `*` `/`), plus `div` (scaled, half-up), `round`, `to_i`, `to_float`. JSON-encodes to a `<mantissa>e<exponent>` string. |

Stdlib operations compile inline rather than through a runtime dispatch layer,
so the generated Ruby calls the underlying operation directly.
