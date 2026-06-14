# Decoding and encoding

`Decode` turns untyped JSON / Ruby data into typed Jade values; `Encode` turns
typed values back into JSON. Both are explicit pipelines, and both auto-derive
for `struct` types so the common case needs no hand-written decoder or encoder.

## Decoding

A decoder is a value; `Decode.decode_string(decoder, json)` runs one and returns
a `Result(a, DecodeError)`. The combinators compose:

```jade
module DecodeJson exposing (
  age,
  coords,
  tags,
  user,
)

import Decode exposing (DecodeError)


struct User = {
  name: String,
  age: Int
}


def age(json: String) -> Result(Int, DecodeError)
  Decode.decode_string(Decode.field("age", Decode.int), json)
end


def tags(json: String) -> Result(List(String), DecodeError)
  Decode.decode_string(Decode.list(Decode.string), json)
end


def coords(json: String) -> Result(Maybe(Int), DecodeError)
  Decode.decode_string(Decode.nullable(Decode.int), json)
end


def user(json: String) -> Result(User, DecodeError)
  decoder = Decode.succeed(User(_, _))
    |> Decode.required("name", Decode.string)
    |> Decode.required("age", Decode.int)

  Decode.decode_string(decoder, json)
end
```

```ruby
DecodeJson::Internal.age('{"age":40}')             # => Ok(40)
DecodeJson::Internal.tags('["a","b"]')             # => Ok(["a", "b"])
DecodeJson::Internal.coords('null')                # => Ok(Nothing)
DecodeJson::Internal.coords('7')                   # => Ok(Just(7))
DecodeJson::Internal.user('{"name":"Ada","age":40}')
# => Ok(User(name: "Ada", age: 40))
DecodeJson::Internal.user('{"name":"Ada"}')
# => Err(MissingField("age"))
```

The struct decoder is `Decode.succeed(User(_, _))` piped through one
`Decode.required` per field — the `_` placeholders are the constructor's holes,
filled left to right as each field decodes.

## Encoding

`Encode.encode_to_string(value)` serializes; the combinators mirror `Decode`:

```jade
module EncodeJson exposing (n, point, user, xs)

import Encode


struct User = {
  name: String,
  age: Int
}


def n -> String
  Encode.encode_to_string(Encode.int(42))
end


def xs -> String
  Encode.encode_to_string(Encode.list(Encode.int, [1, 2, 3]))
end


def point -> String
  pairs = [
    Encode.field("x", Encode.int, 1),
    Encode.field("y", Encode.int, 2),
  ]

  Encode.encode_to_string(Encode.object(pairs))
end


def user(u: User) -> String
  Encode.encode_to_string(Encode.encode(u))
end
```

```ruby
EncodeJson.n                  # => "42"
EncodeJson.xs                 # => "[1,2,3]"
EncodeJson.point              # => '{"x":1,"y":2}'
EncodeJson::Internal.user(user)
# => '{"name":"Ada","age":40}'
```

## Auto-derivation

`Encode.encode(value)` derives the encoder from the value's type, and
`Decode.from_json(json)` derives the decoder from the **return type** — so a
struct round-trips without writing either by hand:

```jade
module Api exposing (parse, render)

import Encode
import Decode exposing (DecodeError)


struct User = {
  name: String,
  age: Int
}


def parse(json: String) -> Result(User, DecodeError)
  Decode.from_json(json)
end


def render(user: User) -> String
  Encode.encode_to_string(Encode.encode(user))
end
```

Reach for the explicit combinators above when the JSON shape doesn't match the
struct one-to-one — renamed keys, nested lookups, optional fields.
