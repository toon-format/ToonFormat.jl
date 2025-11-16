# TOON.jl

[![SPEC v2.0](https://img.shields.io/badge/spec-v2.0-lightgrey)](https://github.com/toon-format/spec/blob/main/SPEC.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](./LICENSE)

Julia implementation of **Token-Oriented Object Notation (TOON)**, a compact, human-readable serialization format optimized for LLM contexts.

## What is TOON?

TOON is a line-oriented, indentation-based text format that encodes the JSON data model with explicit structure and minimal quoting. It achieves 30-60% token reduction compared to JSON while maintaining readability and deterministic structure.

**Key Features:**
- Compact representation of tabular data
- Minimal quoting requirements
- Explicit array lengths for validation
- Support for multiple delimiter types (comma, tab, pipe)
- Strict mode for validation
- 100% compatible with JSON data model

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/s-celles/TOON.jl")
```

Or in the Julia REPL package mode:
```julia-repl
pkg> add https://github.com/s-celles/TOON.jl
```

## Quick Start

### Encoding

```julia
using TOON

# Simple object
data = Dict("name" => "Alice", "age" => 30)
toon_str = TOON.encode(data)
println(toon_str)
# name: Alice
# age: 30

# Array of objects (tabular format)
users = [
    Dict("id" => 1, "name" => "Alice", "role" => "admin"),
    Dict("id" => 2, "name" => "Bob", "role" => "user")
]
toon_str = TOON.encode(Dict("users" => users))
println(toon_str)
# users[2]{id,name,role}:
#   1,Alice,admin
#   2,Bob,user
```

### Decoding

```julia
using TOON

# Decode a simple object
input = "name: Alice\nage: 30"
data = TOON.decode(input)
# Dict("name" => "Alice", "age" => 30)

# Decode an array
input = "[3]: 1,2,3"
data = TOON.decode(input)
# [1, 2, 3]
```

### Options

```julia
using TOON

# Encoding with custom options
options = TOON.EncodeOptions(
    indent = 4,                    # Use 4 spaces per indentation level
    delimiter = TOON.TAB,          # Use tab as delimiter
    keyFolding = "safe",           # Enable key folding
    flattenDepth = 2               # Limit folding depth
)

data = Dict("user" => Dict("name" => "Alice"))
toon_str = TOON.encode(data, options=options)

# Decoding with custom options
options = TOON.DecodeOptions(
    indent = 4,                    # Expect 4 spaces per level
    strict = true,                 # Enable strict validation
    expandPaths = "safe"           # Enable path expansion
)

data = TOON.decode(toon_str, options=options)
```

## Examples

### JSON vs TOON Comparison

**JSON:**
```json
{
  "users": [
    { "id": 1, "name": "Alice", "role": "admin" },
    { "id": 2, "name": "Bob", "role": "user" }
  ],
  "count": 2
}
```

**TOON:**
```
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
count: 2
```

Token savings: ~45% reduction

### Complex Nested Structures

```julia
using TOON

data = Dict(
    "server" => Dict(
        "host" => "localhost",
        "port" => 8080,
        "tags" => ["web", "api"]
    ),
    "database" => Dict(
        "type" => "postgresql",
        "connections" => 10
    )
)

println(TOON.encode(data))
# server:
#   host: localhost
#   port: 8080
#   tags[2]: web,api
# database:
#   type: postgresql
#   connections: 10
```

## API Reference

### Main Functions

#### `encode(value; options::EncodeOptions=EncodeOptions()) -> String`

Encode a Julia value to TOON format string.

**Arguments:**
- `value`: Any Julia value (will be normalized to JSON model)
- `options`: Optional encoding configuration

**Returns:** TOON formatted string

#### `decode(input::String; options::DecodeOptions=DecodeOptions()) -> JsonValue`

Decode a TOON format string to a Julia value.

**Arguments:**
- `input`: TOON formatted string
- `options`: Optional decoding configuration

**Returns:** Parsed Julia value (Dict, Array, or primitive)

### Types

#### `EncodeOptions`

Configuration for encoding:
- `indent::Int = 2`: Number of spaces per indentation level
- `delimiter::Delimiter = ","`: Delimiter for arrays (`,`, `\t`, or `|`)
- `keyFolding::String = "off"`: Key folding mode (`"off"` or `"safe"`)
- `flattenDepth::Int = typemax(Int)`: Maximum folding depth

#### `DecodeOptions`

Configuration for decoding:
- `indent::Int = 2`: Expected spaces per indentation level
- `strict::Bool = true`: Enable strict validation
- `expandPaths::String = "off"`: Path expansion mode (`"off"` or `"safe"`)

## Specification Compliance

This implementation follows the official [TOON Specification v2.0](https://github.com/toon-format/spec/blob/main/SPEC.md).

**Supported features:**
- ✅ All primitive types (string, number, boolean, null)
- ✅ Objects with nested structures
- ✅ Primitive arrays (inline format)
- ✅ Tabular arrays (uniform objects)
- ✅ Mixed/complex arrays (expanded list format)
- ✅ Multiple delimiters (comma, tab, pipe)
- ✅ Strict mode validation
- ✅ String escaping and quoting rules
- ✅ Key folding and path expansion (v2.0)

## Testing

Run the test suite:

```julia
using Pkg
Pkg.test("TOON")
```

## Contributing

Contributions are welcome! Please see the [main TOON repository](https://github.com/toon-format/toon) for contribution guidelines.

## License

[MIT](./LICENSE) License © 2025 TOON Format Organization

## Related Projects

- [Official TOON Specification](https://github.com/toon-format/spec)
- [TypeScript/JavaScript Implementation](https://github.com/toon-format/toon)
- [Python Implementation](https://github.com/toon-format/toon-python)

## Links

- **Specification:** [SPEC.md](https://github.com/toon-format/spec/blob/main/SPEC.md)
- **Test Fixtures:** [Spec test suite](https://github.com/toon-format/spec/tree/main/tests/fixtures)
- **Benchmarks:** [Token efficiency results](https://github.com/toon-format/toon/tree/main/benchmarks)
