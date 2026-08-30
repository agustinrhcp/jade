# Testing

Most Jade tests are plain unit tests over pure functions: pass in data, assert
on the return value, no mocks. The only thing that needs special support is a
`Task` — code that talks to the outside world. That's what this page covers.

## Setup

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

  expect(Signup.run('ada@example.com')).to be_ok(true)
  expect(Mailer.deliver).to have_been_called.with('ada@example.com')
end
```

Call the module's public function, the same one the rest of your Ruby calls.
**Never `Signup::Internal`** — that is the compiler's own facade, holding
values that never went through a decoder. A test that reaches for it is
testing something no caller can reach.

Queued answers win until exhausted, then the persistent one takes over:

```ruby
next_call_to(Rng.roll, 1)
next_call_to(Rng.roll, 2)
all_calls_to(Rng.roll, 0)    # call 1 → 1, call 2 → 2, call 3+ → 0
```

`have_been_called` chains `.with(...)`, `.once`, `.times(n)`, and negates with
`not_to`.

## What comes back

A public function hands you wire data, so most assertions are the ordinary
ones. What you get depends on the return type:

| Returns | You assert on |
|---|---|
| `Int`, `Float`, `Bool`, `String` | the value itself |
| `Maybe(a)` | the value, or `nil` |
| `List(a)`, `Set(a)` | an array |
| `Dict(k, v)` | an array of `[k, v]` pairs |
| a struct | a hash keyed by field name, **strings not symbols** |
| a union with no variant arguments | the variant name, snake_case |
| `Task(a, e)` | `["ok", a]` or `["err", e]` — use `be_ok` / `be_err` |

```ruby
expect(Users.fetch(1)).to eq({ 'name' => 'Ada', 'age' => 40 })
expect(Users.nickname(1)).to be_nil
expect(Shapes.kind(circle)).to eq('circle')
```

The bang form unwraps a `Task` and raises the err arm, which reads better when
failure is not what the example is about:

```ruby
expect(Signup.run!('ada@example.com')).to be(true)
```

## Matchers

```ruby
expect(outcome).to be_ok                  # ["ok", _]
expect(outcome).to be_ok(42)              # ["ok", 42]
expect(outcome).to be_err("smtp down")    # ["err", "smtp down"]
```

`be_ok` and friends compose with ordinary matchers:

```ruby
expect(outcome).to be_ok(include('name' => 'Ada'))
expect(outcome).to be_ok(kind_of(Integer))
```

`be_ok` and `be_err` are the whole matcher surface. There is nothing for a
`Maybe` or a union variant because nothing crossing the boundary has that
shape — a `Maybe` arrives as the value or `nil`, a variant-only union as its
name. Assert on those with `eq`, `be_nil`, and the matchers RSpec already
gives you.
