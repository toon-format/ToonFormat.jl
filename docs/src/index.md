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

The [README](https://github.com/toon-format/ToonFormat.jl#specification) names the targeted spec version and how Julia values map to the JSON data model.
