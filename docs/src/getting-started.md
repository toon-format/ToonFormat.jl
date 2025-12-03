# Getting Started

This guide will help you get up and running with ToonFormat.jl.

## Installation

Add ToonFormat.jl to your Julia environment:

```julia
using Pkg
Pkg.add(url="https://github.com/toon-format/toon-julia.jl")
```

Or using the package manager:
```julia-repl
pkg> add https://github.com/toon-format/toon-julia.jl
```

## Basic Usage

### Encoding

Convert Julia data structures to TOON format:

```julia
using ToonFormat

# Simple object
data = Dict("name" => "Alice", "age" => 30)
toon_str = TOON.encode(data)
println(toon_str)
# Output:
# name: Alice
# age: 30
```

### Decoding

Parse TOON format strings back to Julia data:

```julia
using ToonFormat

input = """
name: Alice
age: 30
"""

data = TOON.decode(input)
# Dict("name" => "Alice", "age" => 30)
```

## Working with Arrays

### Primitive Arrays

```julia
# Encode
numbers = [1, 2, 3, 4, 5]
toon_str = TOON.encode(numbers)
println(toon_str)
# [5]: 1,2,3,4,5

# Decode
decoded = TOON.decode("[5]: 1,2,3,4,5")
# [1, 2, 3, 4, 5]
```

### Tabular Arrays (Arrays of Objects)

TOON excels at representing tabular data:

```julia
users = [
    Dict("id" => 1, "name" => "Alice", "role" => "admin"),
    Dict("id" => 2, "name" => "Bob", "role" => "user"),
    Dict("id" => 3, "name" => "Charlie", "role" => "user")
]

toon_str = TOON.encode(Dict("users" => users))
println(toon_str)
# Output:
# users[3]{id,name,role}:
#   1,Alice,admin
#   2,Bob,user
#   3,Charlie,user
```

## Configuration Options

### Encoding Options

```julia
using ToonFormat

# Custom indentation (4 spaces instead of 2)
options = TOON.EncodeOptions(indent=4)
toon_str = TOON.encode(data, options=options)

# Use tab delimiter
options = TOON.EncodeOptions(delimiter=TOON.TAB)
toon_str = TOON.encode(data, options=options)

# Enable key folding for nested objects
options = TOON.EncodeOptions(keyFolding="safe")
toon_str = TOON.encode(data, options=options)
```

### Decoding Options

```julia
using ToonFormat

# Disable strict mode (lenient parsing)
options = TOON.DecodeOptions(strict=false)
data = TOON.decode(input, options=options)

# Enable path expansion
options = TOON.DecodeOptions(expandPaths="safe")
data = TOON.decode(input, options=options)

# Custom indentation
options = TOON.DecodeOptions(indent=4)
data = TOON.decode(input, options=options)
```

## Common Patterns

### Nested Objects

```julia
config = Dict(
    "server" => Dict(
        "host" => "localhost",
        "port" => 8080
    ),
    "database" => Dict(
        "type" => "postgresql",
        "connections" => 10
    )
)

toon_str = TOON.encode(config)
# server:
#   host: localhost
#   port: 8080
# database:
#   type: postgresql
#   connections: 10
```

### Mixed Data Types

```julia
data = Dict(
    "string" => "hello",
    "number" => 42,
    "boolean" => true,
    "null" => nothing,
    "array" => [1, 2, 3],
    "object" => Dict("nested" => "value")
)

toon_str = TOON.encode(data)
```

## Error Handling

ToonFormat.jl provides clear error messages for invalid input:

```julia
using ToonFormat

# Array count mismatch (strict mode)
try
    TOON.decode("[3]: 1,2")  # Declares 3 items but only has 2
catch e
    println(e)
    # "Array length mismatch: expected 3, got 2"
end

# Invalid escape sequence
try
    TOON.decode("value: \"hello\\x\"")  # \x is not valid
catch e
    println(e)
    # "Invalid escape sequence: \x"
end
```

## Next Steps

- Learn more about [Encoding](guide/encoding.md)
- Learn more about [Decoding](guide/decoding.md)
- Explore [Configuration Options](guide/options.md)
- See [Advanced Features](guide/advanced.md)
- Browse [Examples](examples.md)
