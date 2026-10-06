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

A `Dict` iterates in hash order, so encode a `NamedTuple` or an `OrderedDict` from OrderedCollections.jl when the field order matters. `decode` throws an `ErrorException` naming the line on invalid input, e.g. `Line 3: Expected 3 tabular rows, but got 2`. [Options](options.md) covers delimiters and strict mode.

## Specification

Targets [TOON spec v4.3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md), and the test suite runs the spec's conformance fixtures.

- **Integers decode to `Int`, or `BigInt` beyond its range, and other numbers to `Float64`** – a token beyond the `Float64` range (e.g. `1e999`) decodes as a string; on encode, integers print in full, other numbers with the shortest digits of their `Float64` value, and finite reals beyond the `Float64` range (e.g. `big"1e400"`) as a quoted string of their `BigFloat` value in exponent form ([§4](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md#4-decoding-interpretation-reference-decoder))
- **Dicts, `NamedTuple`s, and vectors or tuples of `Pair`s encode as objects** – other arrays (a matrix in column-major order), tuples, and sets encode as arrays, `NaN` and `±Inf` as `null`, strings that are not valid Unicode throw an `ArgumentError`, and anything else (`Symbol`, `Date`, `missing`) encodes as its `string` form ([§3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md#3-encoding-normalization-reference-encoder))
