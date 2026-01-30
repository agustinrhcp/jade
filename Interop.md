# Interop part II

uses Jade::Date with
  today : Int

Needs to guard for Int actually being an Int in jade side.
Same with more elaborated literals.

Jade::Interop.ok
Jade::Interop.error
Jade::Interop.always


# Interop must return a Task

because it can fail, and interacts with the outside world.
