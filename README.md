# TOON for Julia

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://toon-format.github.io/ToonFormat.jl/stable/)
[![SPEC v4.3](https://img.shields.io/badge/spec-v4.3-lightgrey)](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

Encodes Julia values to [TOON (Token-Oriented Object Notation)](https://github.com/toon-format/toon) and decodes TOON back. TOON is a compact, indentation-based encoding of the JSON data model for LLM input.

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

`decode` returns `OrderedDict{String,Any}` objects and `Vector{Any}` arrays, and throws an `ErrorException` naming the line on invalid input. Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode` through the `options` keyword, e.g. `encode(data; options = EncodeOptions(delimiter = TAB))`:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `indentSize` | `2` | Spaces per indentation level (encode and decode) |
| `delimiter` | `COMMA` | Delimiter for inline arrays and tabular rows: `COMMA`, `TAB`, or `PIPE` (encode) |
| `strict` | `true` | Throws on the spec's strict-mode errors instead of applying its non-strict leniencies (decode) |

## Specification

Targets [TOON spec v4.3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md), and the test suite runs the spec's conformance fixtures.

- **Integers decode to `Int`, or `BigInt` beyond its range, and other numbers to `Float64`** – a token beyond the `Float64` range (e.g. `1e999`) decodes as a string; on encode, integers print in full and other numbers with the shortest digits of their `Float64` value ([§4](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md#4-decoding-interpretation-reference-decoder))
- **Dicts, `NamedTuple`s, and vectors or tuples of `Pair`s encode as objects** – other arrays (a matrix in column-major order), tuples, and sets encode as arrays, `NaN` and `±Inf` as `null`, strings that are not valid Unicode throw an `ArgumentError`, and anything else (`Symbol`, `Date`, `missing`) encodes as its `string` form ([§3](https://github.com/toon-format/spec/blob/v4.3.0/SPEC.md#3-encoding-normalization-reference-encoder))

## Resources

- **Specification:** [SPEC.md](https://github.com/toon-format/spec/blob/main/SPEC.md) – Normative rules and conformance checklists
- **Format Overview:** [toonformat.dev](https://toonformat.dev/guide/format-overview) – Every form with examples
- **Other Implementations:** [toonformat.dev](https://toonformat.dev/ecosystem/implementations) – TOON in other languages
- **API Reference:** [toon-format.github.io/ToonFormat.jl](https://toon-format.github.io/ToonFormat.jl/stable/) – Options and the `encode` and `decode` docstrings

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the development setup and pull request guidelines.

## License

[MIT](./LICENSE) License © 2025-PRESENT [Sébastien Celles](https://github.com/s-celles)
