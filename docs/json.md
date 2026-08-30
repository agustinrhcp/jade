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

Every one of these returns a `Result`, which has no `Encodable` — so they are
for Jade to consume, not Ruby. Written in Jade, the outcomes are:

```jade
age('{"age":40}')                 -- Ok(40)
tags('["a","b"]')                 -- Ok(["a", "b"])
coords('null')                    -- Ok(Nothing)
coords('7')                       -- Ok(Just(7))
user('{"name":"Ada","age":40}')   -- Ok(User(name: "Ada", age: 40))
user('{"name":"Ada"}')            -- Err(MissingField("age"))
```

To hand one of these to Ruby, return a `Task` instead — its arms encode, and
the caller gets `["ok", …]` or `["err", …]`. Reaching into `Module::Internal`
to call the `Result` form is not an option: that facade holds values that
never went through an encoder.

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
EncodeJson.user({"name" => "Ada", "age" => 40})
# => '{"name":"Ada","age":40}'
```

A struct argument crosses as the object it encodes to, keyed by strings.

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

Derivation reaches through the structural types to their elements, so anything
built out of encodable parts is itself encodable:

| Type | Wire form |
|------|-----------|
| `List(a)`, `Set(a)` | array — a set drops duplicates on the way back |
| `Maybe(a)` | the value, or `null` |
| `(a, b)` … `(a, b, c, d)` | array, positional |
| `Dict(k, v)` | array of `[key, value]` pairs — a JSON object only admits string keys |
| a `struct` | object, keyed by field name |
| a union whose variants take no arguments | string, the variant name in snake_case |

A type outside that list needs its own `implements Encodable(T)` /
`Decodable(T)` — a union carrying arguments, say, where nothing but you knows
which shape it should take.
