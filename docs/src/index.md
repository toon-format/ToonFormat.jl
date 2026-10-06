# ToonFormat.jl

Encodes Julia values to [TOON (Token-Oriented Object Notation)](https://github.com/toon-format/toon) and decodes TOON back. TOON is a compact, indentation-based encoding of the JSON data model for LLM input – the [Format Overview](https://toonformat.dev/guide/format-overview) covers its syntax.

## Installation

```julia
using Pkg; Pkg.add("ToonFormat")
```

## Usage

```julia
using ToonFormat

users = [(id = 1, name = "Ada", role = "admin"), (id = 2, name = "Bob", role = "user")]
toon = encode((users = users,))
# users[2]{id,name,role}:
#   1,Ada,admin
#   2,Bob,user

decode(toon)
# OrderedDict("users" => [OrderedDict("id" => 1, "name" => "Ada", "role" => "admin"), OrderedDict("id" => 2, "name" => "Bob", "role" => "user")])
```

A `Dict` iterates in hash order, so encode a `NamedTuple` or an `OrderedDict` from OrderedCollections.jl when the field order matters. `decode` throws an `ErrorException` on invalid input, e.g. `Array length mismatch: expected 3, got 2`. [Options](options.md) covers delimiters and strict mode.

## Specification

Targets [TOON spec v3.0](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md), and the test suite runs the spec's conformance fixtures.

- **Integers decode to `Int64` and other numbers to `Float64`** – tokens outside that domain (e.g. `99999999999999999999`, `1e999`) decode as strings ([§2](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md#2-data-model))
- **Dicts, `NamedTuple`s, and vectors or tuples of `Pair`s encode as objects** – other arrays, tuples, and sets encode as arrays, `NaN` and `±Inf` as `null`, and anything else (`Symbol`, `Date`, `missing`) as its `string` form ([§3](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md#3-encoding-normalization-reference-encoder))
