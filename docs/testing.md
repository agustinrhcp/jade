# Testing

Most Jade tests are unit tests against pure functions: pass in data, assert on the return value. The interesting part of the testing API is the bit that handles the edges — `Task`s that talk to the outside world.

## Setup

```ruby
# spec_helper.rb — strict: every Task must be stubbed
RSpec.configure { |c| c.include Jade::Tasks::RSpec }

# rails_helper.rb — loose: real bodies run unless stubbed
RSpec.configure { |c| c.include Jade::Tasks::RSpec::Loose }
```

Pick strict for unit specs (any unstubbed `Task` is a test bug) and loose for higher-level specs that should let real bodies through unless you've replaced them.

## Stubbing a Task

`next_call_to(task, ...)` queues a one-shot answer. `all_calls_to(task, ...)` sets a persistent answer. Both accept a value or a block:

```ruby
it 'sends a welcome email after sign-up' do
  all_calls_to(User::Create)      { |t, email, _pw| t.ok(User.new(email:)) }
  all_calls_to(User::SendWelcome) { |t, _user|      t.ok(nil) }

  expect(SignUp.run.call('a@b.com', 'pw').run).to be_ok

  expect(User::Create).to have_been_called.with('a@b.com', 'pw')
  expect(User::SendWelcome).to have_been_called.once
end
```

Queued answers compose with persistent ones — `next_call_to` wins until exhausted, then `all_calls_to` takes over:

```ruby
next_call_to(Random.number, 1)
next_call_to(Random.number, 2)
all_calls_to(Random.number, 0)   # call 1: 1, call 2: 2, call 3+: 0
```

`have_been_called` chains `.with(...)`, `.times(n)`, `.once`, plus `not_to`.

## Matchers

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

Pass a class constant or `'Module::Name'` string to `look_like` when the short name is ambiguous.
