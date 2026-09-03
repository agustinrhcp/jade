# Testing

Most Jade tests are plain unit tests over pure functions: pass in data, assert
on the return value, no mocks. Those can be written in Jade and run with
`jade test`. The only thing that needs special support is a `Task` — code that
talks to the outside world — and that stays in RSpec, where the stubs are.

## `jade test`

A test module is a `*_test.jd` file under the source root exposing `tests`:

```jade
# lib/math_test.jd
module MathTest exposing (tests)

import Test exposing (Test, context, describe, it)
import Expect
import Math


def tests -> Test
  describe(
    "Math",
    [
      it("adds", -> { Expect.equal(Math.add(1, 2), 3) }),
      context("halve", [
        it("rejects odds", -> { Expect.nothing(Math.halve(7)) }),
      ]),
    ],
  )
end
```

```
jade test                 # every test module
jade test MathTest halve  # only modules matching a pattern
jade test -f doc          # name every test instead of one mark each
```

The summary separates the two costs, because they behave differently: a pure
suite runs in milliseconds and the wall clock is almost entirely the build.

```
44 tests, 1 failure (compiled in 5.80s, ran in 4ms)
```

The lambda in `it` is what makes each test its own unit: the tree is built
first and walked after, so a raise is one failure rather than the end of the
run. Order is stable — no seed, no shuffle.

There is no `let` and no `before`: a `def` is both, and it is recomputed per
call because nothing can mutate.

### Expectations

```jade
Expect.equal(actual, expected)      Expect.not_equal(actual, expected)
Expect.field(name, actual, expected)
Expect.ok(result)                   Expect.err(result)
Expect.just(maybe)                  Expect.nothing(maybe)
Expect.true(bool)                   Expect.false(bool)
```

`field` is `equal` carrying the field's name, which is what makes a combined
assertion readable — the values alone do not say which field moved:

```
    expected field `name` to be equal

      actual:   "Agustin Cornu"
      expected: "Agustin"
```

An accessor (`.name`) cannot supply that name: it compiles to a bare block, so
nothing survives to runtime. Comparing the whole struct with `equal` stays the
better default — `Show` prints both sides in full.

Both sides of a failure are rendered through `Show`, so they read as Jade:

```
x MathTest > Math > adds

    expected values to be equal

      actual:   [1, 2]
      expected: [1, 3]
```

To assert several things in one test, combine expectations. Every failure is
reported, not just the first:

```jade
it("registers", -> {
  Expect.all([
    Expect.equal(user.name, "ada"),
    Expect.equal(user.age, 40),
    Expect.true(user.active),
  ])
})
```

`Expect.and` is the same thing for a pair, and pipes:

```jade
Expect.equal(user.name, "ada")
  |> Expect.and(Expect.true(user.active))
```

### Ports are refused

`jade test` takes the dispatch seam away: any `Task` that reaches a port fails
the test, naming the port. That covers the clock and id generation as much as
the database — a suite that forgets to stub `now` isn't slow, it's flaky. Tests
that need a port belong in RSpec, below.

## RSpec setup

Include one of two RSpec helpers:

```ruby
# strict: any unstubbed Task is a test failure
RSpec.configure { |c| c.include Jade::Tasks::RSpec }

# loose: real port bodies run unless you've replaced them
RSpec.configure { |c| c.include Jade::Tasks::RSpec::Loose }
```

Use **strict** for unit specs (an unstubbed `Task` means the test reached the
outside world by accident). Use **loose** for higher-level specs that should let
real bodies through unless you've stubbed them.

## Stubbing a Task

`all_calls_to(task, …)` sets a persistent answer; `next_call_to(task, …)` queues
a one-shot. Both take a value or a block `{ |t, *args| t.ok(…) }`:

```ruby
it 'sends a welcome mail to the new address' do
  all_calls_to(Mailer.deliver) { |t, _email| t.ok(true) }

  expect(Signup::Internal.run('ada@example.com').run).to be_ok(true)
  expect(Mailer.deliver).to have_been_called.with('ada@example.com')
end
```

Queued answers win until exhausted, then the persistent one takes over:

```ruby
next_call_to(Rng.roll, 1)
next_call_to(Rng.roll, 2)
all_calls_to(Rng.roll, 0)    # call 1 → 1, call 2 → 2, call 3+ → 0
```

`have_been_called` chains `.with(...)`, `.once`, `.times(n)`, and negates with
`not_to`.

## Matchers

```ruby
expect(result).to be_ok               # is Ok
expect(result).to be_ok(42)           # Ok(42)
expect(result).to be_err("smtp down")
expect(maybe).to  be_just(5)
expect(maybe).to  be_nothing

# look_like matches a union variant by name and payload
expect(shape).to look_like(:Circle, 10.0)
expect(shape).to look_like(:Square, 1.0)
```

`be_ok` and friends compose with ordinary matchers:

```ruby
expect(result).to be_ok(have_attributes(name: 'Ada', age: 40))
expect(result).to be_ok(kind_of(Integer))
```

Pass a `'Module::Name'` string to `look_like` when the short variant name is
ambiguous.
