# TOON.jl

[![CI](https://github.com/s-celles/TOON.jl/workflows/CI/badge.svg)](https://github.com/s-celles/TOON.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/s-celles/TOON.jl/workflows/Documentation/badge.svg)](https://github.com/s-celles/TOON.jl/actions/workflows/Documentation.yml)
[![codecov](https://codecov.io/gh/s-celles/TOON.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/s-celles/TOON.jl)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)
[![SPEC v2.0](https://img.shields.io/badge/spec-v2.0-lightgrey)](https://github.com/toon-format/spec/blob/main/SPEC.md)
[![Compliance](https://img.shields.io/badge/compliance-100%25-brightgreen)](./COMPLIANCE_VALIDATION_REPORT.md)
[![Tests](https://img.shields.io/badge/tests-1750%20passing-brightgreen)](./test/COMPLIANCE_TEST_COVERAGE.md)
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

### Key Folding (Compact Nested Objects)

```julia
using TOON

# Deep nesting with key folding
data = Dict("api" => Dict("v1" => Dict("users" => Dict("endpoint" => "/api/v1/users"))))

# Without key folding (default)
println(TOON.encode(data))
# api:
#   v1:
#     users:
#       endpoint: /api/v1/users

# With key folding
options = TOON.EncodeOptions(keyFolding="safe")
println(TOON.encode(data, options=options))
# api.v1.users.endpoint: /api/v1/users
```

### Path Expansion (Round-trip with Key Folding)

```julia
using TOON

# Decode with path expansion
input = "api.v1.users.endpoint: /api/v1/users"
options = TOON.DecodeOptions(expandPaths="safe")
data = TOON.decode(input, options=options)
# Dict("api" => Dict("v1" => Dict("users" => Dict("endpoint" => "/api/v1/users"))))

# Round-trip: folding + expansion
encode_opts = TOON.EncodeOptions(keyFolding="safe")
decode_opts = TOON.DecodeOptions(expandPaths="safe")
original = Dict("a" => Dict("b" => Dict("c" => 42)))
encoded = TOON.encode(original, options=encode_opts)  # "a.b.c: 42"
decoded = TOON.decode(encoded, options=decode_opts)   # Reconstructs original structure
```

### Different Delimiters

```julia
using TOON

users = [
    Dict("name" => "Alice", "role" => "admin"),
    Dict("name" => "Bob", "role" => "user")
]

# Comma delimiter (default)
println(TOON.encode(Dict("users" => users)))
# users[2]{name,role}:
#   Alice,admin
#   Bob,user

# Tab delimiter
options = TOON.EncodeOptions(delimiter=TOON.TAB)
println(TOON.encode(Dict("users" => users), options=options))
# users[2	]{name	role}:
#   Alice	admin
#   Bob	user

# Pipe delimiter
options = TOON.EncodeOptions(delimiter=TOON.PIPE)
println(TOON.encode(Dict("users" => users), options=options))
# users[2|]{name|role}:
#   Alice|admin
#   Bob|user
```

### Strict Mode Validation

```julia
using TOON

# Strict mode catches errors (default)
input = "[3]: 1,2"  # Declares 3 items but only has 2
try
    TOON.decode(input)  # strict=true by default
catch e
    println(e)  # "Array length mismatch: expected 3, got 2"
end

# Non-strict mode is lenient
options = TOON.DecodeOptions(strict=false)
result = TOON.decode(input, options=options)  # [1, 2] - accepts actual count
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

**✅ FULLY COMPLIANT with TOON Specification v2.0**

This implementation has been validated against all normative requirements in the official [TOON Specification v2.0](https://github.com/toon-format/spec/blob/main/SPEC.md) with **1750 passing tests**.

### Core Features
- ✅ All primitive types (string, number, boolean, null)
- ✅ Canonical number formatting (no exponents, no trailing zeros)
- ✅ Objects with nested structures
- ✅ Primitive arrays (inline format)
- ✅ Tabular arrays (uniform objects with all delimiters)
- ✅ Mixed/complex arrays (expanded list format)
- ✅ Objects as list items with proper depth handling
- ✅ Root form detection (array, primitive, object)

### String Handling
- ✅ Five valid escape sequences (\\, \", \n, \r, \t)
- ✅ Complete quoting rules (empty, whitespace, reserved literals, numeric-like, special chars)
- ✅ Delimiter-aware quoting (document vs active delimiter)

### Delimiters and Formatting
- ✅ Multiple delimiters (comma, tab, pipe)
- ✅ Proper delimiter scoping (document vs active)
- ✅ Array header syntax with delimiter symbols
- ✅ Consistent indentation and whitespace rules

### Validation and Options
- ✅ Strict mode validation (all §14 error conditions)
- ✅ Array count and row width validation
- ✅ Indentation validation (multiples, no tabs)
- ✅ Configurable encoding/decoding options

### Advanced Features (v2.0)
- ✅ Key folding (safe mode with depth limits)
- ✅ Path expansion (safe mode with conflict detection)
- ✅ Round-trip compatibility between folding and expansion

### Known Limitations
- Number precision limited to Float64 (~15-17 decimal digits)
- Very deeply nested structures (100+ levels) may impact performance
- Julia Dict preserves insertion order (implementation detail, not guaranteed by language spec)

## Testing

Run the comprehensive test suite (1750 tests):

```julia
using Pkg
Pkg.test("TOON")
```

### Test Coverage

The test suite includes:
- **Requirements Testing:** All 15 normative requirements (900+ tests)
- **Round-trip Testing:** Encode/decode preservation (69 tests)
- **Determinism Testing:** Consistent output validation (24 tests)
- **Edge Cases:** Empty values, deep nesting, large arrays (75 tests)
- **Spec Examples:** All examples from the specification (79 tests)
- **Error Conditions:** All §14 error scenarios (57 tests)
- **Integration Tests:** Real-world usage patterns (546 tests)

See [COMPLIANCE_VALIDATION_REPORT.md](./COMPLIANCE_VALIDATION_REPORT.md) for detailed validation results.

## Performance

TOON achieves significant token reduction compared to JSON:

- **Tabular data:** 40-60% reduction
- **Nested objects:** 20-40% reduction
- **Mixed structures:** 30-50% reduction

Example token counts (using GPT-4 tokenizer):
```julia
# JSON: 156 tokens
# TOON: 89 tokens (43% reduction)
users = [
    Dict("id" => 1, "name" => "Alice", "email" => "alice@example.com", "active" => true),
    Dict("id" => 2, "name" => "Bob", "email" => "bob@example.com", "active" => false)
]
```

## Documentation

Comprehensive documentation is available in the `docs/` folder:

- **Getting Started** - Installation and basic usage
- **User Guide** - Detailed encoding and decoding guide
- **Examples** - Real-world usage examples
- **API Reference** - Complete API documentation
- **Compliance** - Specification compliance details

### Building Documentation

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

Then open `docs/build/index.html` in your browser.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](docs/src/contributing.md) for guidelines.

### Development

```julia
# Clone the repository
git clone https://github.com/s-celles/TOON.jl.git
cd TOON.jl

# Run tests
julia --project=. -e 'using Pkg; Pkg.test()'

# Run specific test file
julia --project=. test/test_encoder.jl
```

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

