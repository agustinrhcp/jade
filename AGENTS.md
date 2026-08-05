# Writing Jade

Idiom and gotchas. This file is deliberately not a function list — that's
what `jade q api` is for, and a copy here would rot.

## Ask the compiler, not the source

| Question | Command |
|---|---|
| Does this function exist? What does it take? | `jade q api List` / `jade q api List.fold` |
| Which module has a `fold`? | `jade q find fold` |
| How is a lambda / `implements` block written? | `jade q syntax lambda` |
| Did what I just wrote compile? | `jade check path/to/file.jd` |

**Grepping the stdlib does not work, and fails quietly.** Stdlib modules are
written two ways — Jade in a heredoc (`Maybe`, `Result`, `Decimal`) and a Ruby
DSL (`List`, `String`, `Dict`, `Decode`) — so half of them never spell `def`,
and none contains the string `List.map` you would search for. Extension
modules (`Sql.*`) live in a gem that isn't in the tree at all. A grep that
comes back empty tells you nothing.

Inside a project, `jade q api` covers the stdlib, your own modules, and any
extension gem's, each tagged with an `origin`.

## Reach for the combinator

A `case` that just unwraps and rewraps is the long way round.

| Instead of | Write |
|---|---|
| `case m in Just(x) then f(x) in Nothing then Nothing end` | `Maybe.map(m, f)` |
| `case m in Just(x) then x in Nothing then d end` | `Maybe.with_default(m, d)` |
| `case m in Just(x) then f(x) in Nothing then Nothing end` where `f` returns `Maybe` | `Maybe.and_then(m, f)` |
| `case r in Ok(x) then Ok(f(x)) in Err(e) then Err(e) end` | `Result.map(r, f)` |
| `case r in Ok(x) then x in Err(_) then d end` | `Result.with_default(r, d)` |
| a hand-written `==` | nothing — `Eq` derives |
| a hand-written decoder for a struct | nothing — `Decode.from_json` derives it |

These read best piped:

```jade
def label(m: Maybe(User)) -> String
  m
    |> Maybe.map((u) -> { u.name })
    |> Maybe.with_default("anonymous")
end
```

`case` earns its place when you're actually distinguishing variants — the
`Result` arm that reports a different error, the union with five constructors.
Write one `in` branch per variant rather than an `else` fallback; `else` is for
matching literals, where exhaustiveness isn't available.

**`map` changes the element type.** `Maybe.map : (Maybe(a), (a) -> b) ->
Maybe(b)`. If you were told otherwise, that was hover, which reports a
collapsed `(a) -> a` for the stdlib functions backing an interface — a known
bug, see `~/vault/claude/jade/bugs/hover-collapses-stdlib-type-vars.md`.
`jade q api` reads the declaration and is right.

## Imports

Auto-imported, no `import` needed: **`Basics`, `Maybe`, `Tuple`, `List`,
`Char`, `String`, `Result`, `Task`, `Bytes`**.

Everything else needs an explicit `import`: **`Dict`, `Set`, `Decode`,
`Decode.Params`, `Encode`, `Calendar`, `Clock`, `Decimal`, `Show`, `Debug`**.
`Show.show(x)` without `import Show` is "I cannot find a `Show.show`
variable" — the function exists, the import doesn't.

`import Dict` gets you the module. To name its *type* unqualified you have to
ask for it:

```jade
import Dict exposing (Dict)      -- then: def go -> Dict(String, Int)
import Dict                      -- then: def go -> Dict.Dict(String, Int)
```

**Zero-argument entries are values, not calls.** `Dict.empty`, `Decode.bool`,
`Encode.null` — no parentheses. `Dict.empty()` is a compile error.

## Interfaces

The built-ins live in `Basics`: `Eq`, `Comparable`, `Appendable`, `Mappable`,
`Chainable`, `Numeric`. Plus `Show` (in `Show`), `Decodable` (in `Decode`),
`Encodable` (in `Encode`).

Declare and implement:

```jade
interface Sized(a) with
  size : a -> Int
end


implements Sized(Basket) with
  size: (b) -> { List.length(b.items) }
end
```

The right-hand side is an inline lambda or a function reference
(`size: basket_size`).

Two things to keep straight:

- **The interface parameter is the constructor, not the applied type.**
  `Mappable f` has `map : f(a), (a -> b) -> f(b)` — `f` is `Maybe`, not
  `Maybe(a)`. Getting this wrong is why the impl target reads
  `Mappable(Maybe(a))`.
- **`jade q api` tells you what already has an instance.** `jade q api
  Decode.Decodable` lists every implementing type under `implemented_by`;
  a struct's entry lists what it `implements`. Check before writing one.

### What derives, what doesn't

Verified against the compiler:

| | Structs / unions |
|---|---|
| `Eq` (`==`) | derives |
| `Show` | derives |
| `Encodable` / `Decodable` | derives |
| `Comparable` (`<`, `List.sort`) | **does not derive** |

`List.sort` on a list of structs is `No implementation of Basics.Comparable
for Point`. Write the instance, or sort by a projection with
`List.sort_by`.

## Encoding and decoding

`Encode.encode(value)` derives the encoder from the value's type;
`Decode.from_json(json)` derives the decoder from the **return type**. A
struct round-trips with neither written by hand:

```jade
def parse(json: String) -> Result(User, DecodeError)
  Decode.from_json(json)
end
```

Derivation reaches through structural types, so anything built from encodable
parts is encodable: `List(a)`/`Set(a)` → array, `Maybe(a)` → the value or
`null`, tuples → positional array, `Dict(k, v)` → array of `[k, v]` pairs (a
JSON object only admits string keys), a struct → object keyed by field name, a
union whose variants take no arguments → the variant name in snake_case.

Outside that list — a union carrying arguments, say — write
`implements Encodable(T)` / `Decodable(T)` yourself; nothing but you knows the
shape it should take.

Reach for the explicit combinators (`Decode.field`, `Decode.required`,
`Decode.index`) when the JSON doesn't match the struct one-to-one. Use
`Decode.Params` for PATCH-style input, where a missing field means "don't
touch" rather than an error.

Full treatment: [docs/json.md](docs/json.md).

## Where else to look

- [docs/syntax.md](docs/syntax.md) — the language, form by form.
- [examples/](examples/) — nine files, compiled and asserted by
  `spec/examples_spec.rb`, so they're verified idiom rather than samples that
  drifted. `interfaces.jd` and `pattern_matching.jd` earn their keep.
- [docs/interop.md](docs/interop.md) — the Ruby boundary, ports, `uses`.
- [docs/stdlib.md](docs/stdlib.md) — what each module is for.
