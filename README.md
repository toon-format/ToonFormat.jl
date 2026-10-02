# TOON for Julia

[![Docs](https://img.shields.io/badge/docs-stable-blue.svg)](https://toon-format.github.io/ToonFormat.jl/stable/)
[![SPEC v3.0](https://img.shields.io/badge/spec-v3.0-lightgrey)](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md)
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

Pass `EncodeOptions` to `encode` and `DecodeOptions` to `decode` through the `options` keyword, e.g. `encode(data; options = EncodeOptions(delimiter = TAB))`:

| Option | Default | Description |
| ------ | ------- | ----------- |
| `indent` | `2` | Spaces per indentation level (encode and decode) |
| `delimiter` | `COMMA` | Array delimiter: `COMMA`, `TAB`, or `PIPE` (encode) |
| `keyFolding` | `"off"` | `"safe"` folds chains of single-key objects into dotted keys (encode) |
| `flattenDepth` | `typemax(Int)` | Maximum segments in a folded key (encode) |
| `strict` | `true` | Raise the strict-mode errors of spec §14 (decode) |
| `expandPaths` | `"off"` | `"safe"` expands dotted keys into nested objects (decode) |

## Specification

Targets [TOON spec v3.0](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md), and the test suite runs the spec's conformance fixtures.

- **Integers decode to `Int64` and other numbers to `Float64`** – tokens outside that domain (e.g. `99999999999999999999`, `1e999`) decode as strings ([§2](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md#2-data-model))
- **Dicts, `NamedTuple`s, and vectors or tuples of `Pair`s encode as objects** – other arrays, tuples, and sets encode as arrays, `NaN` and `±Inf` as `null`, and anything else (`Symbol`, `Date`, `missing`) as its `string` form ([§3](https://github.com/toon-format/spec/blob/v3.0.1/SPEC.md#3-encoding-normalization-reference-encoder))

## Resources

- **Specification:** [SPEC.md](https://github.com/toon-format/spec/blob/main/SPEC.md) – Normative rules and conformance checklists
- **Format Overview:** [toonformat.dev](https://toonformat.dev/guide/format-overview) – Every form with examples
- **Other Implementations:** [toonformat.dev](https://toonformat.dev/ecosystem/implementations) – TOON in other languages
- **API Reference:** [toon-format.github.io/ToonFormat.jl](https://toon-format.github.io/ToonFormat.jl/stable/) – Options and the `encode` and `decode` docstrings

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the development setup and pull request guidelines.

## License

[MIT](./LICENSE) License © 2025-PRESENT [Sébastien Celles](https://github.com/s-celles)
