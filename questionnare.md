### What frustrates you in Ruby?
### What do you wish Ruby made easier?
### What makes you NOT want to leave Ruby?

## Imports and Export

### Ruby

```ruby
require 'module'

class Something
  attr_accessor :...

  private

  ...
end
```

### Elm

```elm
module Exp exposing(...)

import Imp as I exposing (...)
```

### Rust

```rust
use module::{..., ..., ...};

mod something{
  pub fn ...
  }
}
```

## Function Definition

### Ruby

```ruby
def something(x)
  x + 1
end

something = ->(x) { x + 1 } || lambda { |x| x + 1}
```


### Elm


```elm
something : Int
something =
  x + 1


let
    something = \x -> x + 1
in
```


### Rust

```rust
fn something(x: i32) -> i32 {
  x + 1
}

let something = |x| x + 1;
```


## Interfaces

### Ruby

```ruby
module Speakable
  def speak
    raise NotImplementedError
  end
end
```

### Rust

```rust
trait Speak {
  fn speak(&self) -> String;
}

impl Speak for Dog {
  fn speak(&self) -> String {
    "woof".to_string()
  }
}

<T: Speak>(animal: T)
```


```haskell
class Speak a where
  speak :: a -> String

instance Speak Dog where
  speak Dog = "woof"

Speak a => a
```

### Would you miss duck typing?


## Side Effects

### Ruby

```ruby
File.read("test.txt")
Net::HTTP.get(...)
```


### Elm


```elm
type Msg
    = GotData (Result Http.Error Data)

update msg model =
    case msg of
        ...
```

### Rust

```rust
async fn fetch() -> Result<Data, Error> {
  ...
}
```


### Haskell

```haskell
main :: IO ()
main = putStrLn "Hello"
```

### Should IO be explicit in the type system?
### Should pure and impure code be separated?
### Would you tolerate more ceremony for stronger guarantees?
