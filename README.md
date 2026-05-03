# Jade

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/agustinrhcp/jade/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/agustinrhcp/jade/tree/master)

A small, statically-typed functional language that compiles to Ruby. Source
files are `.jd`; the compiler produces plain Ruby modules you `require` like
any other gem. You get type inference, exhaustive pattern matching, and an
honest interop story — Ruby stays Ruby; Jade stays Jade.

If you've used Elm or OCaml, the syntax will feel familiar. If you've only
used Ruby, the punchline is: the wrong programs stop compiling and the right
ones tend to look obvious.

---

## Using Jade from Ruby

```ruby
# Gemfile
gem 'jade', path: '/path/to/jade'
```

```ruby
require 'jade'

Jade.setup do |config|
  config.source_root = 'src'    # where your .jd files live
  config.build_dir   = '.jade'  # where compiled .rb files are written
end

Jade.require('my_module')

MyModule.my_function.call('hello')
```

Compiled modules are constants. Compiled functions live on the constant and
are called as `Module.fn.call(args)` — the extra `.call` is there because
every Jade function is a value first, callable second.

---

## Language Tour

### Functions

```jade
module Greetings exposing (greet)

def greet(name: String) -> String
  "Hello, " ++ name ++ "!"
end
```

Type annotations are required on function signatures and nowhere else. Inside
the body, types are inferred.

### Nullary references

Zero-parameter functions and zero-arity constructors are values at the
reference site. Keep the `()` at the definition for grep-ability; calling
with `()` at the use site is a type error.

```jade
def pi() -> Float
  3.14
end

area = pi * radius * radius     # not pi()
flag = True                     # not True()
none = Nothing                  # not Nothing()
```

Constructors with payloads are unchanged: `Just(x)`, `Ok(value)`.

### Types

**Primitives:** `Int`, `Float`, `Bool`, `String`, `Char`. `Char` literals use
single quotes: `'a'`, `'Z'`, `'\n'`.

**Union types:**

```jade
type Shape = Circle(Float) | Rectangle(Float, Float)
```

A variant payload may also be **keyed** — useful when positional arguments
become hard to read at the call site:

```jade
type Charge
  = Refund(Int)
  | Settled(paid_amount: Int, tax_amount: Int, issued_amount: Int)

charge = Settled(paid_amount: 100, tax_amount: 20, issued_amount: 80)

case charge
of Refund(n)   then n
of Settled(r)  then r.paid_amount + r.tax_amount
of Settled(paid_amount: pa, tax_amount: _, issued_amount: _) then pa
end
```

The payload of a keyed variant is an anonymous record — `r.paid_amount` and
`{ r | paid_amount: 0 }` work as you'd expect.

**Structs (named records):**

```jade
struct Person = { name: String, age: Int }

p1 = Person("Paul", 55)              # positional
p2 = Person(name: "Paul", age: 55)   # kwargs (canonical)
p3 = { p1 | age: 56 }                # update — result is still a Person
p4 = p1 |> .age=(57)                 # update sugar in pipelines
```

Anonymous records do not coerce into named structs. Passing
`{ name: "Paul", age: 55 }` where `Person` is expected is a type error — be
explicit about which one you mean.

**Anonymous records:**

```jade
def origin() -> { x: Int, y: Int }
  { x: 0, y: 0 }
end
```

**Tuples:**

```jade
def swap(pair: (Int, String)) -> (String, Int)
  (a, b) = pair
  (b, a)
end
```

**Generic types:**

```jade
type Result(a, e) = Ok(a) | Err(e)
```

**`Never`** is the impossible value — a union variant that can't be
constructed. The exhaustiveness checker knows about it, so `Result(Int, Never)`
destructures without matching `Err`:

```jade
def unwrap(r: Result(Int, Never)) -> Int
  Ok(n) = r
  n
end
```

### `if` / `else`

`if` is always an expression and always needs an `else`. There's no
truthy-but-not-true coercion; the condition has to be `Bool`.

```jade
def absolute(n: Int) -> Int
  if n < 0 then 0 - n else n end
end

def sign(n: Int) -> Int
  if n < 0 then
    -1
  else
    if n > 0 then 1 else 0 end
  end
end
```

For matching on shapes (variants, lists, tuples, records), reach for `case`.

### Pattern matching

The compiler enforces exhaustiveness. A missing case is a type error, not a
runtime surprise.

```jade
def describe(shape: Shape) -> String
  case shape
  of Circle(_)       then "a circle"
  of Rectangle(_, _) then "a rectangle"
  end
end
```

**List patterns** use `|` to separate head from tail. The tail must be a name
or `_`:

```jade
def sum(list: List(Int)) -> Int
  case list
  of []         then 0
  of [x | rest] then x + sum(rest)
  end
end
```

**Destructuring with `=`** must be exhaustive. For lists, prefer `case`.

```jade
{ name:, age: } = person     # punning shorthand
(first, second) = pair
Ok(n)           = result_known_ok
```

**Monadic bind with `<-`** unwraps any `Chainable` (`Task`, `Maybe`,
`Result`, ...). If a step fails, the rest of the chain is skipped:

```jade
def fetch_sum() -> Task(Int, String)
  one <- get_one()
  two <- get_two()
  Task.succeed(one + two)
end
```

### Lambdas, pipes, placeholders

```jade
double = (x) -> { x * 2 }
add    = (a, b) -> { a + b }

result = numbers
  |> List.filter((x) -> { x > 0 })
  |> List.map(double)
```

A `_` in argument position curries the call, left-to-right:

```jade
add5    = add(_, 5)         # Int -> Int
incr    = add(1, _)         # Int -> Int
mk_pair = Tuple.pair(_, _)  # a -> b -> Tuple2(a, b)
```

It's how you build applicative-style decoders and similar pipelines:

```jade
Decode.succeed(Person(_, _))
  |> Decode.required("name", Decode.string)
  |> Decode.required("age", Decode.int)
```

`_` is only valid as a direct call argument — not as a bare expression or
operator operand.

### `++` for strings and lists

`++` works on both via the `Appendable` interface:

```jade
full = first ++ " " ++ last
all  = list_a ++ list_b
```

### Interfaces

Interfaces are typeclasses. `Eq`, `Comparable`, `Appendable`, `Mappable`, and
`Chainable` ship with the language. You can declare your own:

```jade
interface Show(a) with
  show : a -> String
end

implements Show(Int) with
  show : (n) -> { String.from_int(n) }
end
```

Polymorphic functions pick up constraints automatically:

```jade
def are_equal(a: a, b: a) -> Bool      # inferred: a has Eq
  a == b
end

def larger(a: a, b: a) -> a            # inferred: a has Comparable
  case compare(a, b)
  of GT then a
  of _  then b
  end
end
```

**Implementing for your own type:**

```jade
struct Person = { id: Int, name: String }

implements Eq(Person) with
  (==) : (one, other) -> { one.id == other.id }
end
```

`Eq` is auto-derived for unions, records, and structs — write `implements`
only when you want non-default behaviour (here, equality by `id` alone).
`Comparable`, `Show`, and `Appendable` are not auto-derived; if you need
them, write them by hand.

### Modules and imports

```jade
module MyModule exposing (foo, bar)

import Maybe exposing (Maybe(..), map)
import List
```

`Basics`, `Maybe`, `Result`, `List`, `String`, `Char`, `Tuple`, and `Task`
are auto-imported. The rest (`Decode`, `Encode`, `Decode.Params`, `Calendar`,
`Clock`) need an explicit `import`.

### Interop with Ruby

Jade has no implicit side effects. Anything that talks to the outside world
goes through a `uses` block, and every port returns a `Task`. The type
system can't lie about effects.

```jade
uses Time with
  now: Task(Int, Never)
end

def current_time() -> Task(Int, Never)
  now()
end
```

On the Ruby side, register ports with `Jade::Port`. The block receives a
helper `t` for `t.ok(value)` / `t.err(error)`:

```ruby
module Time
  extend Jade::Port

  task :now do |t|
    t.ok(::Time.now.to_i)
  end
end
```

Tasks don't run until `.run`:

```ruby
Jade.require('my_module')

task   = MyModule.current_time.call   # nothing runs yet
result = task.run                     # => Jade::Result::Ok[1234567890]
```

The block must return `t.ok(value)` or `t.err(error)` — never another `Task`.
Composition (`map`, `and_then`, `sequence`) lives in Jade. Jade also guards
values at the boundary, so a Ruby-side type mismatch surfaces as a
`Guard::Error` instead of corrupting downstream code.

---

## Testing

Stub ports, assert on outcomes, never run a real HTTP call from a unit test.

### Setup

```ruby
# spec_helper.rb — strict: every Task must be stubbed
RSpec.configure { |c| c.include Jade::Tasks::RSpec }

# rails_helper.rb — loose: real bodies run unless stubbed
RSpec.configure { |c| c.include Jade::Tasks::RSpec::Loose }
```

### Stubbing

`next_call_to(task, ...)` queues a one-shot answer. `all_calls_to(task, ...)`
sets a persistent answer. Both accept a value or a block:

```ruby
it 'sends a welcome email after sign-up' do
  all_calls_to(User::Create)      { |t, email, _pw| t.ok(User.new(email:)) }
  all_calls_to(User::SendWelcome) { |t, _user|      t.ok(nil) }

  expect(SignUp.run.call('a@b.com', 'pw').run).to be_ok

  expect(User::Create).to have_been_called.with('a@b.com', 'pw')
  expect(User::SendWelcome).to have_been_called.once
end

# Sequential answers across calls
next_call_to(Random.number, 1)
next_call_to(Random.number, 2)
all_calls_to(Random.number, 0)        # call 1: 1, call 2: 2, call 3+: 0
```

`have_been_called` chains: `.with(...)`, `.times(n)`, `.once`, plus `not_to`.

### Matchers

```ruby
expect(result).to be_ok                  # is Ok
expect(result).to be_ok(42)              # Ok(42)
expect(result).to be_err(:not_found)
expect(maybe).to  be_just(5)
expect(maybe).to  be_nothing
expect(shape).to  be_circle              # any union variant gets a predicate

expect(result).to be_ok(have_attributes(year: 2026, month: 5))
expect(result).to be_ok(kind_of(Integer))

expect(value).to look_like(:Circle, 5.0)
expect(value).to look_like(Shapes::Circle, 5.0)
expect(value).to look_like(:Point, x: 1, y: 2)
expect(value).to look_like(:Pair, [:Circle, 5.0], 42)   # Pair(Circle(5.0), 42)
```

Pass a class constant or `'Module::Name'` string to `look_like` when the
short name is ambiguous.

---

## Working with JSON

`Decode` and `Encode` are mirror modules: one converts JSON or untyped Ruby
data into typed Jade values, the other goes the other way. Both surface
failures explicitly — no exceptions thrown across the boundary.

Both modules need explicit imports:

```jade
import Decode exposing (Decoder, DecodeError)
import Encode exposing (Encodable)
```

### Decoding

A pipeline-style decoder for a struct:

```jade
struct Person = { name: String, age: Int }

def person_decoder() -> Decoder(Person)
  Decode.succeed(Person(_, _))
    |> Decode.required("name", Decode.string)
    |> Decode.required("age", Decode.int)
end

def parse(json: String) -> Result(Person, DecodeError)
  Decode.decode_string(person_decoder, json)
end
```

The primitives — `string`, `int`, `float`, `bool` — are nullary. Reference
them bare; calling with `()` is a type error.

| Combinator | Type | Notes |
|---|---|---|
| `field(key, d)` | `String, Decoder(a) -> Decoder(a)` | Required key. Missing key → `MissingField`. |
| `optional_field(key, d)` | `String, Decoder(a) -> Decoder(Maybe(a))` | Absent key → `Nothing`. `null` is still a type error. |
| `index(i, d)` | `Int, Decoder(a) -> Decoder(a)` | Element at array index. |
| `list(d)` | `Decoder(a) -> Decoder(List(a))` | Decodes every element; collects all element errors. |
| `nullable(d)` | `Decoder(a) -> Decoder(Maybe(a))` | `null` → `Nothing`; otherwise wraps in `Just`. |
| `map(fn, d)` | `(a -> b), Decoder(a) -> Decoder(b)` | Transforms a successful decode. |
| `succeed(v)` | `a -> Decoder(a)` | Always yields `v`. Seed for the pipeline. |
| `and_map(wrapped, d)` | `Decoder(a -> b), Decoder(a) -> Decoder(b)` | Applicative apply. |
| `required(wrapped, key, d)` | pipeline step | Like `field` + `and_map`. |
| `optional(wrapped, key, d, default)` | pipeline step | Substitutes `default` when key is absent or `null`. |
| `and_then(d, fn)` | `Decoder(a), (a -> Decoder(b)) -> Decoder(b)` | Monadic bind — pick the next decoder by inspecting the previous result. |
| `sequence(ds)` | `List(Decoder(a)) -> Decoder(List(a))` | Runs each decoder against the same value. |
| `one_of(ds)` | `List(Decoder(a)) -> Decoder(a)` | First success wins; on total failure, errors collect. |
| `fail(msg)` | `String -> Decoder(a)` | Always fails — useful inside `and_then`. |
| `from_result(r)` | `Result(a, String) -> Decoder(a)` | Lift a `Result` into a decoder. |

**Entry points:**

| Function | Type |
|---|---|
| `decode(d, value)` | `Decoder(a), Value -> Result(a, DecodeError)` |
| `decode_string(d, json)` | `Decoder(a), String -> Result(a, DecodeError)` |

`Value` is a JSON-shaped value. From Ruby, build one with
`Jade::Decode::Value[...]`. From Jade, you receive one through a port whose
return type mentions `Value`.

`DecodeError` carries the failure plus where it happened:

```jade
type DecodeError =
    MissingField(String)
  | WrongType(String, String)        # expected, got
  | AtField(String, DecodeError)
  | AtIndex(Int, DecodeError)
  | Multiple(List(DecodeError))
  | Custom(String)
```

`list`, `sequence`, and `one_of` accumulate every branch's error into
`Multiple`. `field` and `index` wrap inner errors in `AtField` / `AtIndex`.
A single failure is reported as-is, never wrapped in `Multiple`.

### `Decodable` and `Encodable` derivation

If you don't want to write a decoder by hand, ask the compiler to derive one:

```jade
struct Person = { name: String, age: Int }

def parse(json: String) -> Result(Person, DecodeError)
  Decode.from_json(json)
end

def stringify(p: Person) -> String
  Encode.encode_to_string(Encode.encode(p))
end
```

Auto-derivation covers `Int`, `Float`, `Bool`, `String`, `Maybe(a)`,
`List(a)`, and any `struct` whose fields are all themselves `Decodable` /
`Encodable`. Unions are not derived — write a decoder by hand using
`one_of` + `map`, and an encoder by writing the cases out:

```jade
type Id = StringId(String) | IntId(Int)

def id_decoder() -> Decoder(Id)
  Decode.one_of([
    Decode.map(StringId, Decode.string),
    Decode.map(IntId, Decode.int),
  ])
end
```

The struct deriver always uses `field` (not `optional_field`), so a
`Maybe(a)` field decodes via `nullable`: `null` is `Nothing`, but an absent
key fails. If you want absent-key tolerance, write the explicit pipeline
with `optional_field`.

### Encoding

`Encode` is symmetric with `Decode`:

| Function | Type |
|---|---|
| `string` / `int` / `float` / `bool` / `null` | `a -> Value` |
| `nullable(encoder, m)` | `(a -> Value), Maybe(a) -> Value` |
| `list(encoder, items)` | `(a -> Value), List(a) -> Value` |
| `field(key, encoder, value)` | `String, (a -> Value), a -> Tuple2(String, Value)` |
| `object(pairs)` | `List(Tuple2(String, Value)) -> Value` |
| `encode_to_string(value)` | `Value -> String` |
| `encode(x)` | `a -> Value` (constrained on `Encodable a`) |

A custom encoder is written either via the `Encodable` interface (so
`Encode.encode(x)` finds it) or directly:

```jade
type Status = Active | Archived

def status_encoder(s: Status) -> Value
  case s
  of Active   then Encode.string("active")
  of Archived then Encode.string("archived")
  end
end

implements Encodable(Status) with
  encoder : status_encoder
end
```

### Combining with ports

Most real apps decode something they got from a Ruby port:

```jade
uses BodyParser with
  get_body: Task(Value, Never)
end

def handle() -> Task(Person, DecodeError)
  body <- get_body()
  Task.from_result(Decode.from_value(body))
end
```

---

## Endpoint params with `Decode.Params`

`Decode.Params` is a sieve API for endpoint inputs. Each accepted field
becomes one variant of a `Field` type, and `collect` produces a
`Decoder(List(Field))` you can run against a JSON body. PATCH-style endpoints
get a list of only-what-was-sent; CREATE-style endpoints fill in the rest
with defaults.

```jade
import Decode exposing (DecodeError)
import Decode.Params exposing (Params)

type Field = Name(String) | Age(Int)

def patient_params() -> Params(Field)
  Decode.Params.empty
    |> Decode.Params.string("name", Name)
    |> Decode.Params.int("age", Age)
end

def parse(json: String) -> Result(List(Field), DecodeError)
  Decode.decode_string(Decode.Params.collect(patient_params), json)
end
```

| Function | Behaviour |
|---|---|
| `empty` | A sieve with no accepted fields and no defaults. |
| `accept(p, key, decoder)` | Add an arbitrary `Decoder(a)` for `key`. |
| `default(p, key, value)` | Provide a fallback used when `key` is absent. |
| `string` / `int` / `float` / `bool` | Shorthand: `accept` with a primitive decoder + variant constructor. |
| `nested(p, key, ctor, sub)` | Decode `key` as an inner sieve and wrap with `ctor`. |
| `collect(p)` | Compile the sieve into a `Decoder(List(a))`. |

Defaults are a separate post-step keyed by name, so the same sieve can be
reused with different default policies:

```jade
def create_params() -> Params(Field)
  patient_params
    |> Decode.Params.default("name", Name("anon"))
    |> Decode.Params.default("age",  Age(0))
end
```

---

## Time: `Calendar` and `Clock`

Two modules for two different jobs:

- **`Calendar`** is for civil dates — year, month, day. Date arithmetic and
  ISO `YYYY-MM-DD` formatting.
- **`Clock`** is for instants and durations — a millisecond-precise point in
  time, plus operations on durations.

They interoperate: `Clock.on_date(instant)` returns a `Calendar.Date`.

### Calendar

```jade
import Calendar exposing (Date, Month(..), Unit(..))

def next_week(d: Date) -> Date
  Calendar.add(d, Days, 7)
end

def report(d: Date) -> String
  Calendar.to_iso_string(d)
end

def today_iso() -> Task(String, Never)
  d <- Calendar.today
  Task.succeed(Calendar.to_iso_string(d))
end
```

| Function | Type |
|---|---|
| `today` | `Task(Date, Never)` |
| `from_calendar_date(y, m, d)` | `Int, Month, Int -> Date` |
| `year` / `month` / `day` / `weekday` | `Date -> ...` |
| `month_to_int` / `month_from_int` | `Month <-> Int` (1–12) |
| `weekday_to_int` / `weekday_from_int` | `Weekday <-> Int` (1=Mon … 7=Sun) |
| `to_iso_string` | `Date -> String` (`"YYYY-MM-DD"`) |
| `from_iso_string` | `String -> Result(Date, String)` |
| `add(d, unit, n)` | `Date, Unit, Int -> Date` (`Days`/`Weeks`/`Months`/`Years`) |
| `diff(a, b, unit)` | `Date, Date, Unit -> Int` |

`Date` and `Month` derive `Eq` and `Comparable`, so `<`, `==`, and `compare`
work directly.

### Clock

```jade
import Clock exposing (Instant, Duration)

def in_ten_minutes() -> Task(Instant, Never)
  i <- Clock.now
  Task.succeed(Clock.add(i, Clock.minutes(10)))
end

def stamp(i: Instant) -> String
  Clock.to_iso(i)              # "2026-05-08T14:30:00Z"
end
```

| Function | Type |
|---|---|
| `now` | `Task(Instant, Never)` |
| `epoch` | `Instant` |
| `millis` / `seconds` / `minutes` / `hours` / `days` | `Int -> Duration` |
| `in_millis` / `in_seconds` / ... | `Duration -> Int` |
| `parts` | `Duration -> { days, hours, minutes, seconds, millis }` |
| `add(i, d)` | `Instant, Duration -> Instant` |
| `diff(a, b)` | `Instant, Instant -> Duration` |
| `on_date(i)` | `Instant -> Calendar.Date` |
| `at_time(i)` | `Instant -> { hour, minute, second, millisecond }` |
| `to_iso(i)` | `Instant -> String` (ISO 8601 with `Z`) |
| `from_iso(s)` | `String -> Result(Instant, String)` |

`Instant` and `Duration` derive `Eq`, `Comparable`, `Decodable`, and
`Encodable`. `Encode.encode(instant)` gives you an ISO string; `Decodable`
parses one back.

---

## Standard Library

| Module | Contents |
|--------|----------|
| `Maybe` | `Just(a)` / `Nothing`, `map`, `and_then`, `with_default` |
| `Result` | `Ok(a)` / `Err(e)`, `map`, `and_then`, `map_error`, `on_error`, `sequence`, `with_default`, `to_maybe`, `from_maybe` |
| `List` | `map`, `filter`, `fold`, `and_then`, `indexed_map`, `sort`, `sort_by`, `length`, `head`, `tail`, `range`, `repeat`, `singleton`, `is_empty` |
| `String` | `length`, `reverse`, `split`, `concat`, `join`, `repeat`, `to_int`, `from_int`, `uncons`, `cons`, `from_char`, `map`, `is_empty` |
| `Char` | `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower` |
| `Tuple` | `pair`, `first`, `second` |
| `Task` | `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence`, `from_result` |
| `Decode` | full pipeline + `Decodable` derivation (see Working with JSON) |
| `Encode` | full pipeline + `Encodable` derivation (see Working with JSON) |
| `Decode.Params` | sieve API for endpoint params (see Endpoint params) |
| `Calendar` | civil dates (see Time) |
| `Clock` | instants, durations, ISO timestamps (see Time) |
| `Basics` | `Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable`, `Numeric`, `Ordering` |

---

## Examples

See the [`examples/`](examples/) directory:

| File | Covers |
|------|--------|
| [`basics_examples.jd`](examples/basics_examples.jd) | Arithmetic, strings, conditionals |
| [`pattern_matching.jd`](examples/pattern_matching.jd) | Lists, literal patterns, recursion |
| [`maybe_examples.jd`](examples/maybe_examples.jd) | Safe nullability and chaining |
| [`records.jd`](examples/records.jd) | Structs, record update, destructuring |
| [`custom_types.jd`](examples/custom_types.jd) | Union types and exhaustive matching |
| [`interfaces.jd`](examples/interfaces.jd) | Generic functions with inferred constraints |
| [`interop.jd`](examples/interop.jd) | Calling Ruby from Jade safely |

---

## Roadmap

**Compiler**
- Incremental compilation
- Better error messages — coverage is uneven
- Multi-error collection — parser bails on the first error
- Module name validation — declared name must match file path

**Language**
- Ranges (`1..10`, `1...10`)

**Type system**
- Better unresolved-constraint error messages
- Row polymorphism for partial record types in signatures

**Tooling**
- LSP — go-to-definition, hover types, inline errors
- Structured diagnostics for editor integration
- `jade fmt` CLI (the formatter exists internally)

**Interop & runtime**
- `Decodable` / `Encodable` derivation for unions

**Infrastructure**
- Reference index pass — unused-import detection, dead-code warnings
- Gem extension registration — let third-party gems register Jade modules
