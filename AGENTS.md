# AGENTS.md

Quick reference for AI agents writing or reviewing Jade. README.md is the
narrative tour; this file is the dense, scannable reference of what's
actually implemented. Same content, different shape — pick whichever your
task needs.

If you maintain a project that uses Jade as a dependency, you can `@`-import
this file from your own AGENTS.md so the agent has the language reference
without re-reading README each turn.

## What Jade is

A small, statically-typed functional language that compiles to Ruby.
Hindley–Milner inference, exhaustive pattern matching, no implicit side
effects (every I/O goes through `Task` via `uses` blocks). `.jd` source
compiles to `.rb`; Ruby calls compiled modules as `MyModule.fn.call(args)`.

## Syntax cheat sheet

```jade
module Foo exposing (greet, area, sum)
import List
import Maybe exposing (Maybe(..), map)

# comments are # — NOT -- (parse error)

def greet(name: String) -> String
  "hi " ++ name
end

# union types — variants can have positional or keyed payloads
type Shape  = Circle(Float) | Rectangle(Float, Float)
type Charge = Refund(Int) | Settled(paid: Int, tax: Int)

# structs — kwargs construction is canonical
struct Point = { x: Int, y: Int }
p1 = Point(x: 1, y: 2)
p2 = { p1 | y: 5 }            # update
p3 = p1 |> .y=(5)             # update sugar

# pattern match — exhaustive; missing case is a type error
def area(s: Shape) -> Float
  case s
  of Circle(r)        then 3.14 * r * r
  of Rectangle(w, h)  then w * h
  end
end

# list patterns — `|` separates tail; tail must be a name or `_`
def sum(xs: List(Int)) -> Int
  case xs
  of []         then 0
  of [x | rest] then x + sum(rest)
  end
end

# destructuring with `=` (must be exhaustive)
(a, b)          = pair
{ name:, age: } = person          # punning shorthand
Ok(n)           = result_ok       # Result(_, Never) is exhaustive in Ok

# if/else — always an expression, always needs else
def absolute(n: Int) -> Int
  if n < 0 then 0 - n else n end
end

# lambdas, pipes, placeholders
def example(xs: List(Int)) -> List(Int)
  double = (x) -> { x * 2 }
  incr   = add(1, _)              # `_` curries left-to-right
  xs |> List.map(double) |> List.filter(incr)
end

# monadic bind `<-` works with any Chainable (Task, Maybe, Result, ...)
def fetch_sum() -> Task(Int, e)
  one <- get_one()
  two <- get_two()
  Task.succeed(one + two)
end

# user-defined interface + implementation
interface Show(a) with
  show : a -> String
end

implements Show(Point) with
  show : (p) -> { "(" ++ String.from_int(p.x) ++ ", " ++ String.from_int(p.y) ++ ")" }
end
```

## Stdlib at a glance

| Module | Contents |
|--------|----------|
| `Basics` | `Int`, `Float`, `Bool`, `Never`, `Ordering` (`GT`/`EQ`/`LT`); interfaces `Eq`, `Comparable`, `Numeric`, `Appendable`, `Mappable`, `Chainable`; ops `(==)`, `(!=)`, `(<)`, `(>)`, `(<=)`, `(>=)`, `(&&)`, `(\|\|)`, `(+)`, `(-)`, `(*)`, `(/)`, `(++)`; `not`, `identity` — **all auto-imported** |
| `Maybe` | `Just(a)` / `Nothing`, `with_default`, `map`, `and_then` — type & constructors auto-imported |
| `Result` | `Ok(a)` / `Err(e)`, `map`, `and_then`, `with_default`, `to_maybe`, `from_maybe`, `map_error`, `on_error`, `sequence` — type & constructors auto-imported |
| `List` | `singleton`, `repeat`, `range`, `is_empty`, `head`, `tail`, `length`, `map`, `and_then`, `indexed_map`, `fold`, `filter`, `sort`, `sort_by` |
| `String` | `is_empty`, `length`, `reverse`, `uncons`, `cons`, `from_char`, `map`, `repeat`, `to_int`, `from_int`, `split`, `concat`, `join` |
| `Char` | `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower` |
| `Tuple` | `pair`, `first`, `second` — only `Tuple2`–`Tuple4` exist at runtime |
| `Task` | `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence`, `run`, `from_result` |
| `Decode` | NOT auto-imported. Types: `Decoder(a)`, `Value`, `DecodeError` (`MissingField`/`WrongType`/`AtField`/`AtIndex`/`Multiple`/`Custom`); interface `Decodable`. Primitives (nullary, reference bare): `string`, `int`, `float`, `bool`. Structural: `field`, `optional_field`, `index`, `list`, `nullable`, `map`. Pipeline: `succeed`, `and_map`, `required`, `optional`, `and_then`, `sequence`, `one_of`, `fail`, `from_result`. Entry: `decode(d, value)`, `decode_string(d, json)`. Constrained on `Decodable a`: `from_value`, `from_json`. |
| `Encode` | NOT auto-imported. Type: `Value`; interface `Encodable`. Primitives: `string`, `int`, `float`, `bool`, `null`. Structural: `nullable(enc, m)`, `list(enc, xs)`, `field(key, enc, val)`, `object(pairs: List(Tuple2(String, Value)))`. Entry: `encode_to_string(value)`. Constrained on `Encodable a`: `encode(x)`. |
| `Decode.Params` | NOT auto-imported. Sieve API for endpoint params — accept-then-collect builds a `Decoder(List(a))`. `Params(..)`, `empty`, `accept(p, key, decoder)`, `default(p, key, value)`, `string`/`int`/`float`/`bool` `(p, key, ctor)`, `nested(p, key, ctor, sub)`, `collect`. Defaults are post-step keyed by name. |
| `Calendar` | NOT auto-imported. `Date` struct + `Month(..)`, `Weekday(..)`, `Unit(..)` (`Days`/`Weeks`/`Months`/`Years`). `today: Task(Date, Never)`, `from_calendar_date`, `year`/`month`/`day`/`weekday`, `month_to_int`/`from_int`, `weekday_to_int`/`from_int`, `to_iso_string`, `from_iso_string`, `add(d, unit, n)`, `diff(a, b, unit)`. `Date` and `Month` derive `Eq` + `Comparable`. |
| `Clock` | NOT auto-imported. `Instant`, `Duration` opaque newtypes. `now: Task(Instant, Never)`, `epoch`, `millis`/`seconds`/`minutes`/`hours`/`days` (build), `in_millis`/`in_seconds`/... (read), `parts`, `add(i, d)`, `diff(a, b)`, `on_date(i): Calendar.Date`, `at_time(i)`, `to_iso`, `from_iso`. Both types derive `Eq`, `Comparable`, `Decodable`, `Encodable`. |

## Gotchas (don't hallucinate these)

- **Zero-arity references are bare; `()` at the use site is a type error.** `Nothing`, `True`, `False`, `GT`, `EQ`, `LT`, any `def f() -> T`, and the nullary `Decode.string` / `Decode.int` / `Decode.float` / `Decode.bool` / `Encode.null` are referenced without parens. The `()` stays at the definition site (`def pi() -> Float`). Constructors with payloads still take args: `Just(x)`, `Ok(x)`, `Err(x)`.
- **Interop ports MUST return `Task(a, e)`.** A non-`Task` return is a `NonTaskPort` semantic error. `uses ... with ... end` blocks need an `end`; ports are comma-separated.
- **List patterns: `|` separates tail, not `,*`.** `[x | xs]`, not `[x, *xs]`. Tail must be `name` or `_`.
- **Don't reach for these — they don't exist:** `List.zip`, `List.find`, `List.any`, `List.all`, `List.take`, `List.drop`, `List.reverse`, `List.flatten`, `String.trim`, `String.contains`, `String.to_upper`, `String.to_lower`, `Tuple.map_first`, `Tuple.map_second`, `Tuple5+`. `Comparable` / `Show` derivation is also not implemented.
- **`Eq` is auto-derived** for unions, records, structs. `Comparable`, `Show`, `Appendable` are not — write them by hand.
- **No top-level `let`.** Top-level declarations are: `def`, `type`, `struct`, `import`, `uses`, `implements`, `interface`. `x = 1` at module scope won't parse.
- **Tuples are `(a, b)` syntax.** Both at type level (`(Int, String)`) and value level (`(1, "x")`). Internally they're `Tuple2`/`Tuple3`/`Tuple4` — but you almost never write that.
- **Anonymous records don't coerce into named structs.** Passing `{ name: "Paul", age: 55 }` where `Person` is expected is a type error. Use `Person(name: "Paul", age: 55)` or positional.
- **`Decode`, `Encode`, `Decode.Params`, `Calendar`, `Clock` need explicit `import`.** Unlike `List`/`Maybe`/`Result`, they are not auto-imported.
- **`Decodable`/`Encodable` derivation covers structs, `List(a)`, `Maybe(a)`, and primitives only.** Unions are not derived — write a `one_of` decoder by hand and an explicit encoder. The struct deriver uses `field` (not `optional_field`) for every key, so a `Maybe(a)` field decodes via `nullable`: `null` is `Nothing`, but an absent key fails.
- **`Decode.optional` differs from `Decode.optional_field`.** `optional_field(key, d)` returns `Decoder(Maybe(a))` and only handles absent keys (a `null` value is an error). `optional(wrapped, key, d, default)` is a pipeline step that substitutes `default: a` when the key is absent or `null`.
- **`Decode.Params` defaults are keyed by name, applied post-collection.** A sieve built once can be reused across endpoints with different default policies.
- **Ruby ports must return `t.ok` / `t.err` — never another `Task`.** Composition lives in Jade. Block return value goes through `Outcome`; nested Tasks are rejected.
- **`uses` qualifies the Ruby module fully.** `uses Jade::Calendar::Runtime with ...`, not `uses Calendar with ...`.

## Common commands

```bash
bundle exec rspec                       # full suite
bundle exec rspec spec/compilation      # end-to-end only
bin/jade-fmt path/to/file.jd            # format a Jade source file
```

## See also

- `README.md` — narrative tour with worked examples
- `examples/*.jd` — canonical idiomatic style
