# Stability

Jade is `0.x`. This says what that means in practice, so an upgrade is a
decision rather than a surprise.

## The promise

**A minor version may break your code. A patch version may not.**

`0.9.0` to `0.10.0` can change the language, the stdlib or the generated
output. `0.9.0` to `0.9.1` fixes something without asking you to edit
anything.

There is no long-term support branch and no backport policy. If a break lands
in `0.10.0` and you cannot take it yet, stay on `0.9.x`; nothing is removed
from a version already published.

## What counts as a break

Anything that makes code that compiled stop compiling, or makes it behave
differently:

- syntax that no longer parses, or parses as something else
- a stdlib function whose name, arity, argument order or return type changes
- a new member on an interface, which every existing implementation of it now
  fails to satisfy
- a check that starts rejecting a program it used to accept
- generated Ruby whose public shape changes, when a Ruby caller was using it

The third is the one to watch: it breaks code that never named the thing that
changed.

Not breaks: a new function, a new module, a better error message, faster or
tidier generated Ruby that keeps the same public shape.

## How we notice

`jade api` prints every name a program can depend on, with its shape, as JSON.
Interface members are listed on their own, because adding one breaks every
implementation without changing a single signature.

```
jade api --out jade-api.json    # commit the result
jade api --check                # exits 1 when the surface moved
```

Jade's own surface is snapshotted that way in `spec/fixtures/public_api.json`.
Two things then hold, both in CI:

- a spec fails when the snapshot and the compiler disagree, so the surface
  cannot move without someone updating the file
- a pull request that updates the file without touching `CHANGELOG.md` fails,
  so it cannot move without someone saying what changed

Neither stops a break. They stop a *silent* one.

The same command works in a project or in an extension gem: `--origin
extension` narrows it to the modules that gem ships, which is the surface its
users depend on. An extension that runs `jade api --check` in CI gets the same
guarantee this repo gives.

That catches names and shapes. It does not catch a function that keeps its
signature and changes its answer; the compilation suite and the ejected
examples are what stand behind that.

## How a break is announced

Every one appears in [CHANGELOG.md](../CHANGELOG.md) under the release that
carries it, in a `### Changed` or `### Removed` entry that says what to write
instead. If the entry does not tell you how to fix your code, that is a bug in
the entry.

Where the compiler can see the old form, it says so at the point of use rather
than leaving you to read a changelog:

```
`SqlMapper` is now `Sql.Assignable`
```

## Deprecation, when it is possible

A name that can be kept working while the new one settles gets one minor
version of both, with the old one reported as a warning, and is removed in the
next. That works for a rename or a moved function.

It does not work for a change in behaviour or a new interface member, where the
old and new forms cannot coexist. Those land in one version, with the changelog
entry and the compiler error carrying the instructions.

## Before 1.0

The version that matters to you is the one you are on. Pin it:

```ruby
gem 'jade-lang', '~> 0.10.0'
```

Compiled output is checked into your build directory, so a version you have
already compiled with keeps working whether or not you upgrade. That, and
[`jade eject`](../README.md#if-it-doesnt-work-out), are what make the pin cheap: the cost of
staying behind is the features you skip, not a stuck project.
