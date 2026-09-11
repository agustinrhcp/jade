# Running a pilot

A four to six week trial that answers one question with evidence: does moving
this module into Jade catch things your review does not, at a cost you are
willing to keep paying. It is written so somebody who has never used Jade can
run it, and so the answer can be no.

Agree the kill criterion before the first line is written. A trial that cannot
fail is a decision that was already made.

## 1. Pick the module

Good candidates have all four:

- **Logic-heavy.** Branching on states, rules, money, dates. If the code is
  mostly calling other services, there is nothing for a type system to hold.
- **Incident-prone.** Look at the last six months of bugs. You want a module
  where the recurring shape is "we forgot a case" or "that field was nil".
- **Coarse at the boundary.** It should be callable as one function per unit
  of work: `Pricing.quote_all(rows)`, not `Pricing.quote(row)` in a loop. A
  crossing costs about 0.8 microseconds per struct, which is nothing once per
  request and everything once per row.
- **A settled specification.** Porting a module whose rules are changing
  weekly measures your ability to hit a moving target, not the language.

Avoid, for a first pilot: anything in a hot loop, anything whose main job is
IO orchestration, and anything where the Ruby is already the simplest possible
expression of the problem.

## 2. Set it up so leaving is tested from day one

```
jade.json          { "source_roots": ["lib"], "extensions": [] }
```

Three CI steps, on the first commit, not the last:

```yaml
- run: bundle exec jade check          # the module compiles
- run: bundle exec jade eject          # it becomes plain Ruby under ejected/
- run: EJECTED=1 bundle exec rspec     # the suite, against those files
```

The third one is the point, and it needs one thing from you: wherever the app
loads its Jade modules, load the ejected files instead when `EJECTED` is set.
In a Rails app that is the initializer holding the `Jade.require` calls.

```ruby
if ENV['EJECTED']
  Dir[Rails.root.join('ejected/**/*.rb')].sort.each { require it }
else
  Jade.require('pricing')
end
```

Nothing under `ejected/` requires the gem, so if that run is green the decision
to keep Jade is reversible for as long as the pilot lasts, and you find out on
the day it stops being true rather than at the end.

## 3. Port with the Ruby tests as the contract

Keep the existing test file. Do not rewrite it, do not port it, do not improve
it. It is the only thing standing between "the port is correct" and "the port
is what I now believe the code should do".

The port is done when the original suite passes against the Jade
implementation through its Ruby boundary. Everything the tests did not cover is
a finding, not a task: write it down.

## 4. Record what the compiler catches

One line per catch, in a file in the repo, with a date:

```
2026-09-04  Compiler  Refund arm missing in `settle`, added in the PR that
                      introduced Refund three weeks ago. Review passed it.
2026-09-08  Compiler  `cancelled_at` read on an Order that has no such state.
2026-09-11  Nothing   Two days, no catches, all mechanical porting.
```

Days with no catches are data. A pilot log that only records the hits is an
advertisement, and everyone reading it knows.

For each catch, answer two questions: would review have caught it, and would
production have. A compiler error for something the tests already covered is
worth little. A compiler error for a case nobody had thought about is the
entire argument.

## 5. Measure three numbers

- **Catches per week**, from the log above, split by whether review would have
  found them.
- **Crossings per request.** Count the calls into the module from one request.
  One or two is the shape you want; one per row means the port has the wrong
  shape, and no amount of tuning inside Jade will recover it.
- **Wall clock on the endpoint that uses the module**, before and after. Not
  microbenchmarks. The number that matters is whether anyone notices.

## 6. The kill criterion

Write it down in week zero and hold to it. A workable default:

> We stop if, after four weeks: fewer than three catches that review would
> have missed, or the ejected build is not green, or p95 on the affected
> endpoint has moved more than 10%.

If you stop, you run `jade eject`, delete the `.jd` files, and keep the Ruby.
That is what the third CI step has been proving all along.

## What to tell people at the start

Point them at [guarantees.md](guarantees.md), which is a list of things the
compiler enforces with the code that proves each one, and be equally plain
about the costs:

- **A value crossing from Ruby costs about 0.8 microseconds per struct.** Cross
  once per unit of work and it is invisible. Cross per row and it dominates.
- **Interface-heavy inner loops run around 2x the equivalent Ruby.** Straight
  arithmetic and list work compile to the obvious Ruby and run at its speed.
- **The stdlib is small.** It covers strings, lists, dicts, sets, dates, times,
  decimals, JSON and SQL. Anything else crosses back to Ruby, which is fine,
  and which is what the boundary rules above are about.
- **The editor story is a language server**, not an IDE with twenty years
  behind it.

A team that hears the costs first and the guarantees second tends to believe
both. The reverse does not work twice.
