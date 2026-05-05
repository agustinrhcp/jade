# Jade

A statically typed, functional language that compiles to Ruby. It focuses on simple, predictable code, with type inference, exhaustive pattern matching, and straightforward interop with Ruby.

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

# The module is now available as a Ruby constant
MyModule.my_function.call('hello')
```

---

## Language Tour

### Functions

```jade
module Greetings exposing (greet)

def greet(name: String) -> String
  "Hello, " ++ name ++ "!"
end
```

### Nullary references as values

Zero-parameter functions and zero-arity constructors are values at the reference site. The `()` stays at the definition site for grep-ability, but call parens at the use site are a type error.

```jade
def pi() -> Float
  3.14
end

area = pi * radius * radius     -- not pi()
flag = True                     -- not True()
none = Nothing                  -- not Nothing()
```

Constructors with payloads are unchanged: `Just(x)`, `Ok(value)`.

### Types

Jade infers types throughout — annotations are only required on function signatures.

**Primitives:** `Int`, `Float`, `Bool`, `String`, `Char`

`Char` literals use single quotes: `'a'`, `'Z'`, `'\n'`.

**Union types:**
```jade
type Shape = Circle(Float) | Rectangle(Float, Float)
```

A variant payload may also be keyed — useful when positional args become hard to read:

```jade
type Charge
  = Refund(Int)
  | Settled(paid_amount: Int, tax_amount: Int, issued_amount: Int)

Settled(paid_amount: 100, tax_amount: 20, issued_amount: 80)

case charge
of Refund(n) then n
of Settled(r) then r.paid_amount + r.tax_amount
of Settled(paid_amount: pa, tax_amount: _, issued_amount: _) then pa
end
```

The payload is an anonymous record, so `r.paid_amount` and `{ r | paid_amount: 0 }` work as usual.

**Structs (named records):**
```jade
struct Person = { name: String, age: Int }
```

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

**`Never`** is a bottom type representing an impossible value. It marks a union variant that can never be constructed — the exhaustiveness checker understands this, so you can destructure without matching the impossible case:

```jade
-- Ok is the only possible case, so destructuring works
def unwrap(r: Result(Int, Never)) -> Int
  Ok(n) = r
  n
end
```

### Pattern Matching

The compiler enforces exhaustiveness — missing a case is a type error.

```jade
def describe(shape: Shape) -> String
  case shape
  of Circle(_)      then "a circle"
  of Rectangle(_, _) then "a rectangle"
  end
end
```

**List patterns:**
```jade
def sum(list: List(Int)) -> Int
  case list
  of [] then 0
  of [x | xs] then x + sum(xs)
  end
end
```

The rest of a list pattern (after `|`) must be a name (`xs`) or wildcard (`_`).

**Destructuring with `=`:**
```jade
{ name:, age: } = person
(first, second) = pair
```

(For lists, use `case` — the exhaustiveness checker will flag a partial `=` binding.)

**Monadic bind with `<-`** works with any `Chainable` type (`Task`, `Maybe`, `Result`, etc.):
```jade
def fetch_sum() -> Task(Int, String)
  one <- get_one()
  two <- get_two()
  Task.succeed(one + two)
end
```
Each `<-` line unwraps the value from the container. If any step fails or is `Nothing`, the rest of the chain is skipped.

### Lambdas

```jade
double = (x) -> { x * 2 }
add    = (a, b) -> { a + b }
```

### Pipe Operators

```jade
result = numbers
  |> List.filter((x) -> { x > 0 })
  |> List.map((x) -> { x * 2 })
```

### Placeholders (currying)

A `_` in a function-call argument position curries the call. Each `_` becomes a
nested unary lambda parameter, in left-to-right order. Non-`_` arguments are
captured by the lambda:

```jade
add5  = add(_, 5)         -- Int -> Int
incr  = add(1, _)         -- Int -> Int
mkPair = Pair(_, _)       -- a -> b -> Pair(a, b)
```

Useful for applicative-style pipelines:

```jade
Decode.succeed(Person(_, _, _))
  |> Decode.required("name", Decode.string)
  |> Decode.required("age", Decode.int)
```

`_` is only valid as a direct argument inside a call — not as a bare expression
or operator operand.

### String and List Concatenation

`++` works on both `String` and `List` via the `Appendable` interface:

```jade
full = first ++ " " ++ last
all  = list_a ++ list_b
```

### Interfaces

Interfaces are like typeclasses. `Eq`, `Comparable`, and `Appendable` are built-in.

```jade
-- Works for any type with an Eq instance
def are_equal(a: a, b: a) -> Bool
  a == b
end

-- Works for any type with a Comparable instance
def larger(a: a, b: a) -> a
  case compare(a, b)
  of GT then a
  of _  then b
  end
end
```

**Custom interfaces:**
```jade
implements Show(Person) with
  show: (p) -> { p.name ++ " (age " ++ String.from_int(p.age) ++ ")" }
end
```

### Modules and Imports

```jade
module MyModule exposing (foo, bar)

import Maybe exposing (Maybe(..), map)
import List
```

### Interop with Ruby

Jade has no side effects — all interaction with the outside world goes through `uses` blocks. Every port must return a `Task`, making side effects explicit in the type system.

```jade
uses Time with
  now: Task(Int, Never)
end

def current_time() -> Task(Int, Never)
  now()
end
```

On the Ruby side, implement ports using `Jade::Task.ok` or `Jade::Task.error`:

```ruby
module Time
  extend self

  def now
    Jade::Task.ok { ::Time.now.to_i }
  end
end
```

Tasks are lazy — no Ruby code runs until `.run` is called on the returned value:

```ruby
Jade.require(‘my_module’)

task = MyModule.current_time.call   # nothing runs yet
result = task.run                   # => Result::Ok[1234567890]
```

Jade guards values at the interop boundary — if Ruby returns the wrong type, you get a `Guard::Error` rather than silent corruption. For `Task`, the inner value is guarded lazily when `.run` is called.

---

## Standard Library

| Module | Contents |
|--------|----------|
| `Maybe` | `Just(a)` / `Nothing`, `map`, `and_then`, `with_default` |
| `Result` | `Ok(a)` / `Err(e)`, `map`, `and_then`, `map_error`, `on_error`, `sequence` |
| `List` | `map`, `filter`, `fold`, `zip`, `sort`, `length`, `range`, and more |
| `String` | `length`, `reverse`, `split`, `trim`, `to_int`, `contains`, `uncons`, `cons`, `from_char`, `map`, and more |
| `Char` | `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower` |
| `Tuple` | `first`, `second`, `map_first`, `map_second` |
| `Task` | `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence` |
| `Basics` | `Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable`, `Ordering` |

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

### Compiler
- **Incremental compilation** — currently recompiles everything on every run
- **Better error messages** — parsing errors are structured and include source location, but coverage is still limited; more error sites need to be wired up
- **Multi-error collection** — parser returns the first error; should collect all errors in one pass
- **Module name validation** — enforce that a module's declared name matches its file path

### Language Features
- **Ranges** — `1..10`, `1...10`

### Type System
- **Unresolved constraint error messages** — constraint propagation works but error messages need improvement
- **Row polymorphism** — partial record types in function signatures

### Tooling
- **Language Server (LSP)** — go-to-definition, hover types, inline errors
- **Diagnostics** — structured error output for editor integration
- **`jade fmt`** — formatter CLI entrypoint (formatter exists internally)

### Interop and Runtime
- **Decoding Ruby / JSON values** — a decoder layer for safely converting untyped Ruby or JSON data into typed Jade values

### Infrastructure
- **Reference index pass** — track symbol usages for unused import detection and dead code warnings
- **Gem / extension registration** — allow third-party gems to register Jade modules and stdlib extensions
