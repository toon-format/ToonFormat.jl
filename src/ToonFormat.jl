# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
ToonFormat - Token-Oriented Object Notation (TOON)

A compact, human-readable serialization format optimized for LLM contexts.
Achieves 30-60% token reduction vs JSON while maintaining readability and structure.

This package provides encoding and decoding functionality with 100% compatibility
with the official TOON specification (v2.0).

# Examples

```julia
using ToonFormat

# Encoding
data = Dict("name" => "Alice", "age" => 30)
toon_str = ToonFormat.encode(data)
println(toon_str)
# name: Alice
# age: 30

# Decoding
decoded = ToonFormat.decode(toon_str)
# Dict("name" => "Alice", "age" => 30)

# With options
options = ToonFormat.EncodeOptions(indent=4, delimiter=ToonFormat.TAB)
toon_str = ToonFormat.encode(data, options=options)
```

# Main Functions
- `encode(value; options)`: Encode a Julia value to TOON format
- `decode(input; options)`: Decode a TOON string to a Julia value

# Types
- `EncodeOptions`: Configuration for encoding (indent, delimiter, keyFolding, flattenDepth)
- `DecodeOptions`: Configuration for decoding (indent, strict, expandPaths)
"""
module ToonFormat

using Printf

# Include all source files
include("constants.jl")
include("types.jl")
include("string_utils.jl")
include("normalize.jl")
include("primitives.jl")
include("scanner.jl")
include("encoder.jl")
include("decoder.jl")

# Export main functions
export encode, decode

# Export types
export EncodeOptions, DecodeOptions

# Export commonly used constants
export COMMA, TAB, PIPE

# Export utility functions for testing
export escape_string,
    unescape_string, find_first_unquoted, is_safe_identifier, needs_quoting
export to_parsed_lines, parse_array_header, parse_delimited_values, parse_key

end # module
