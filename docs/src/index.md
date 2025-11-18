# TokenOrientedObjectNotation.jl

[![SPEC v2.0](https://img.shields.io/badge/spec-v2.0-lightgrey)](https://github.com/toon-format/spec/blob/main/SPEC.md)
[![Compliance](https://img.shields.io/badge/compliance-100%25-brightgreen)](https://github.com/s-celles/TokenOrientedObjectNotation.jl/blob/main/COMPLIANCE_VALIDATION_REPORT.md)
[![Tests](https://img.shields.io/badge/tests-1750%20passing-brightgreen)](https://github.com/s-celles/TokenOrientedObjectNotation.jl/blob/main/test/COMPLIANCE_TEST_COVERAGE.md)

Julia implementation of **Token-Oriented Object Notation (TOON)**, a compact, human-readable serialization format optimized for LLM contexts.

**✅ Fully compliant with TOON Specification v2.0** - All 1750 tests passing

## What is TOON?

TOON is a line-oriented, indentation-based text format that encodes the JSON data model with explicit structure and minimal quoting. It achieves **30-60% token reduction** compared to JSON while maintaining readability and deterministic structure.

### Key Features

- **Compact tabular data** - Efficient representation of arrays of objects
- **Minimal quoting** - Smart quoting rules reduce visual noise
- **Explicit array lengths** - Built-in validation for data integrity
- **Multiple delimiters** - Comma, tab, and pipe support
- **Strict mode** - Optional validation for production use
- **100% JSON compatible** - Encodes the complete JSON data model

### Why TOON?

When working with Large Language Models, token efficiency matters. TOON provides:

- **Reduced token costs** - 30-60% fewer tokens than JSON
- **Better readability** - Cleaner syntax for humans and LLMs
- **Validation** - Explicit lengths catch errors early
- **Flexibility** - Multiple delimiters for different use cases

## Quick Example

**JSON (156 tokens):**
```json
{
  "users": [
    { "id": 1, "name": "Alice", "email": "alice@example.com", "active": true },
    { "id": 2, "name": "Bob", "email": "bob@example.com", "active": false }
  ],
  "count": 2
}
```

**TOON (89 tokens - 43% reduction):**
```
users[2]{id,name,email,active}:
  1,Alice,alice@example.com,true
  2,Bob,bob@example.com,false
count: 2
```

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/s-celles/TokenOrientedObjectNotation.jl")
```

Or in the Julia REPL package mode:
```julia-repl
pkg> add https://github.com/s-celles/TokenOrientedObjectNotation.jl
```

## Quick Start

```julia
using TokenOrientedObjectNotation

# Encode Julia data to TOON
data = Dict("name" => "Alice", "age" => 30)
toon_str = TOON.encode(data)
println(toon_str)
# name: Alice
# age: 30

# Decode TOON to Julia data
decoded = TOON.decode(toon_str)
# Dict("name" => "Alice", "age" => 30)
```

## Next Steps

- [Getting Started](getting-started.md) - Installation and basic usage
- [User Guide](guide/encoding.md) - Detailed encoding and decoding guide
- [Examples](examples.md) - Real-world usage examples
- [API Reference](api.md) - Complete API documentation
- [Compliance](compliance.md) - Specification compliance details
