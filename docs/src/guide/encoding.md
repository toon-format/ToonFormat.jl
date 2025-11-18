# Encoding Guide

This guide covers how to encode Julia data structures into TOON format.

## Basic Encoding

The `encode` function converts Julia values to TOON format strings:

```julia
using TokenOrientedObjectNotation

result = TOON.encode(value)
```

## Primitive Types

### Numbers

Numbers are encoded in canonical decimal form:

```julia
TOON.encode(42)           # "42"
TOON.encode(3.14)         # "3.14"
TOON.encode(-0.5)         # "-0.5"
TOON.encode(1000000)      # "1000000"
```

**Rules:**
- No exponential notation
- No leading zeros (except "0")
- No trailing zeros in fractional part
- Integer form when fractional part is zero
- `-0` is normalized to `0`

### Strings

Strings are quoted only when necessary:

```julia
TOON.encode("hello")      # "hello"
TOON.encode("hello world") # "\"hello world\""  (contains space)
TOON.encode("")           # "\"\""  (empty string)
TOON.encode("true")       # "\"true\""  (reserved literal)
TOON.encode("123")        # "\"123\""  (numeric-like)
```

**Quoting rules:**
- Empty strings must be quoted
- Strings with whitespace must be quoted
- Reserved literals (`true`, `false`, `null`) must be quoted
- Numeric-like strings must be quoted
- Strings with special characters must be quoted

### Booleans and Null

```julia
TOON.encode(true)         # "true"
TOON.encode(false)        # "false"
TOON.encode(nothing)      # "null"
```

## Objects

Objects are encoded as key-value pairs with proper indentation:

```julia
data = Dict(
    "name" => "Alice",
    "age" => 30,
    "active" => true
)

TOON.encode(data)
# name: Alice
# age: 30
# active: true
```

### Nested Objects

```julia
data = Dict(
    "user" => Dict(
        "name" => "Alice",
        "email" => "alice@example.com"
    ),
    "settings" => Dict(
        "theme" => "dark",
        "notifications" => true
    )
)

TOON.encode(data)
# user:
#   name: Alice
#   email: alice@example.com
# settings:
#   theme: dark
#   notifications: true
```

## Arrays

TOON supports three array formats depending on the content.

### Inline Arrays (Primitives)

Arrays of primitives are encoded inline:

```julia
TOON.encode([1, 2, 3, 4, 5])
# [5]: 1,2,3,4,5

TOON.encode(["a", "b", "c"])
# [3]: a,b,c

TOON.encode([true, false, true])
# [3]: true,false,true
```

### Tabular Arrays (Uniform Objects)

Arrays of objects with the same keys use tabular format:

```julia
users = [
    Dict("id" => 1, "name" => "Alice", "role" => "admin"),
    Dict("id" => 2, "name" => "Bob", "role" => "user")
]

TOON.encode(Dict("users" => users))
# users[2]{id,name,role}:
#   1,Alice,admin
#   2,Bob,user
```

**Benefits:**
- Extremely compact for tabular data
- Clear column structure
- Easy to read and edit

### List Arrays (Mixed Content)

Arrays with mixed types or non-uniform objects use list format:

```julia
mixed = [
    Dict("type" => "user", "name" => "Alice"),
    Dict("type" => "admin", "name" => "Bob", "level" => 5),
    42,
    "string value"
]

TOON.encode(mixed)
# [4]:
#   - type: user
#     name: Alice
#   - type: admin
#     name: Bob
#     level: 5
#   - 42
#   - string value
```

### Arrays of Arrays

Nested arrays are encoded as list items:

```julia
matrix = [[1, 2], [3, 4], [5, 6]]

TOON.encode(matrix)
# [3]:
#   - [2]: 1,2
#   - [2]: 3,4
#   - [2]: 5,6
```

## Encoding Options

### Custom Indentation

```julia
options = TOON.EncodeOptions(indent=4)
TOON.encode(data, options=options)
```

### Delimiter Selection

Choose between comma, tab, or pipe delimiters:

```julia
# Comma (default)
options = TOON.EncodeOptions(delimiter=TOON.COMMA)

# Tab
options = TOON.EncodeOptions(delimiter=TOON.TAB)

# Pipe
options = TOON.EncodeOptions(delimiter=TOON.PIPE)

users = [Dict("name" => "Alice", "age" => 30)]
TOON.encode(Dict("users" => users), options=options)
# With pipe: users[1|]{name|age}:
#              Alice|30
```

### Key Folding

Flatten nested objects into dotted keys:

```julia
data = Dict(
    "api" => Dict(
        "v1" => Dict(
            "endpoint" => "/api/v1"
        )
    )
)

# Without key folding (default)
TOON.encode(data)
# api:
#   v1:
#     endpoint: /api/v1

# With key folding
options = TOON.EncodeOptions(keyFolding="safe")
TOON.encode(data, options=options)
# api.v1.endpoint: /api/v1
```

**Flatten depth limit:**

```julia
options = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
TOON.encode(data, options=options)
# api.v1:
#   endpoint: /api/v1
```

## Special Cases

### Empty Values

```julia
TOON.encode(Dict())       # "{}"
TOON.encode([])           # "[]"
TOON.encode("")           # "\"\""
```

### Special Numbers

```julia
TOON.encode(NaN)          # "null"  (normalized)
TOON.encode(Inf)          # "null"  (normalized)
TOON.encode(-Inf)         # "null"  (normalized)
TOON.encode(-0.0)         # "0"     (normalized)
```

### Escape Sequences

Five escape sequences are supported:

```julia
TOON.encode("line1\nline2")        # "\"line1\\nline2\""
TOON.encode("tab\there")           # "\"tab\\there\""
TOON.encode("quote\"here")         # "\"quote\\\"here\""
TOON.encode("backslash\\here")     # "\"backslash\\\\here\""
TOON.encode("return\rhere")        # "\"return\\rhere\""
```

## Best Practices

1. **Use tabular format for uniform data** - It's the most compact
2. **Choose appropriate delimiters** - Tabs for TSV-like data, pipes for visual separation
3. **Enable key folding for deep nesting** - Reduces indentation levels
4. **Limit flatten depth** - Prevents over-flattening of complex structures
5. **Normalize data before encoding** - Ensure consistent structure for tabular arrays

## Next Steps

- Learn about [Decoding](decoding.md)
- Explore [Configuration Options](options.md)
- See [Advanced Features](advanced.md)
