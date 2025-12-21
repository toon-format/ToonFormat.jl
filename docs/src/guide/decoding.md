# Decoding Guide

This guide covers how to decode TOON format strings into Julia data structures.

## Basic Decoding

The `decode` function parses TOON format strings:

```julia
using ToonFormat

data = ToonFormat.decode(input_string)
```

## Root Forms

TOON supports three root forms:

### Root Array

When the first line is an array header:

```julia
input = "[3]: 1,2,3"
ToonFormat.decode(input)  # [1, 2, 3]
```

### Root Primitive

When the entire input is a single primitive:

```julia
ToonFormat.decode("42")      # 42
ToonFormat.decode("true")    # true
ToonFormat.decode("hello")   # "hello"
```

### Root Object

When the input contains key-value pairs (default):

```julia
input = """
name: Alice
age: 30
"""
ToonFormat.decode(input)  # Dict("name" => "Alice", "age" => 30)
```

## Decoding Arrays

### Inline Arrays

```julia
ToonFormat.decode("[5]: 1,2,3,4,5")
# [1, 2, 3, 4, 5]

ToonFormat.decode("[3]: a,b,c")
# ["a", "b", "c"]
```

### Tabular Arrays

```julia
input = """
users[2]{id,name,role}:
  1,Alice,admin
  2,Bob,user
"""
ToonFormat.decode(input)
# Dict("users" => [
#     Dict("id" => 1, "name" => "Alice", "role" => "admin"),
#     Dict("id" => 2, "name" => "Bob", "role" => "user")
# ])
```

### List Arrays

```julia
input = """
[3]:
  - 1
  - 2
  - 3
"""
ToonFormat.decode(input)  # [1, 2, 3]
```

## Decoding Options

### Strict Mode

Strict mode (enabled by default) validates the input:

```julia
# Strict mode (default)
options = ToonFormat.DecodeOptions(strict=true)
ToonFormat.decode(input, options=options)

# Non-strict mode (lenient)
options = ToonFormat.DecodeOptions(strict=false)
ToonFormat.decode(input, options=options)
```

**Strict mode checks:**
- Array count matches declared length
- Row width matches field count
- No missing colons after keys/headers
- Valid escape sequences only
- No unterminated strings
- Proper indentation (multiples of indent size)
- No tabs in indentation
- No blank lines inside arrays

### Path Expansion

Expand dotted keys into nested objects:

```julia
input = """
api.v1.endpoint: /api/v1
api.v1.version: 1.0
"""

options = ToonFormat.DecodeOptions(expandPaths="safe")
ToonFormat.decode(input, options=options)
# Dict("api" => Dict("v1" => Dict(
#     "endpoint" => "/api/v1",
#     "version" => "1.0"
# )))
```

### Custom Indentation

```julia
input = """
user:
    name: Alice
    age: 30
"""

options = ToonFormat.DecodeOptions(indent=4)
ToonFormat.decode(input, options=options)
```

## Error Handling

ToonFormat.jl provides detailed error messages:

### Array Count Mismatch

```julia
try
    ToonFormat.decode("[3]: 1,2")  # Expected 3, got 2
catch e
    println(e)  # "Array length mismatch: expected 3, got 2"
end
```

### Row Width Mismatch

```julia
try
    input = """
    users[2]{id,name,role}:
      1,Alice
      2,Bob,user
    """
    ToonFormat.decode(input)
catch e
    println(e)  # "Row width mismatch at line 2: expected 3 fields, got 2"
end
```

### Invalid Escape Sequence

```julia
try
    ToonFormat.decode("value: \"hello\\x\"")
catch e
    println(e)  # "Invalid escape sequence: \x"
end
```

### Indentation Errors

```julia
try
    input = """
    user:
     name: Alice
    """
    ToonFormat.decode(input)
catch e
    println(e)  # "Indentation must be a multiple of 2 spaces (line 2)"
end
```

## Delimiter Detection

TOON automatically detects the delimiter from array headers:

```julia
# Comma delimiter
ToonFormat.decode("[3]: 1,2,3")

# Tab delimiter
ToonFormat.decode("[3\t]: 1\t2\t3")

# Pipe delimiter
ToonFormat.decode("[3|]: 1|2|3")
```

## String Unescaping

TOON automatically unescapes strings:

```julia
ToonFormat.decode("\"line1\\nline2\"")     # "line1\nline2"
ToonFormat.decode("\"tab\\there\"")        # "tab\there"
ToonFormat.decode("\"quote\\\"here\"")     # "quote\"here"
ToonFormat.decode("\"backslash\\\\here\"") # "backslash\here"
```

## Best Practices

1. **Use strict mode in production** - Catches errors early
2. **Handle errors gracefully** - Provide user-friendly error messages
3. **Validate input structure** - Check for expected keys and types
4. **Use path expansion carefully** - Only with trusted input
5. **Match encoding options** - Use same indent size as encoder

## Next Steps

- Learn about [Encoding](encoding.md)
- Explore [Configuration Options](options.md)
- See [Advanced Features](advanced.md)
