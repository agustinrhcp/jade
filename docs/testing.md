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
