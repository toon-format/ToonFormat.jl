# Advanced Features

This guide covers advanced features and use cases for ToonFormat.jl.

## Key Folding and Path Expansion

Key folding and path expansion are complementary features for working with deeply nested objects.

### Key Folding (Encoding)

Flatten nested objects into dotted keys:

```julia
data = Dict(
    "database" => Dict(
        "host" => "localhost",
        "port" => 5432,
        "credentials" => Dict(
            "username" => "admin",
            "password" => "secret"
        )
    )
)

# Without folding
ToonFormat.encode(data)
# database:
#   host: localhost
#   port: 5432
#   credentials:
#     username: admin
#     password: secret

# With folding
options = ToonFormat.EncodeOptions(keyFolding="safe")
ToonFormat.encode(data, options=options)
# database.host: localhost
# database.port: 5432
# database.credentials.username: admin
# database.credentials.password: secret
```

### Path Expansion (Decoding)

Expand dotted keys back into nested objects:

```julia
input = """
database.host: localhost
database.port: 5432
database.credentials.username: admin
database.credentials.password: secret
"""

options = ToonFormat.DecodeOptions(expandPaths="safe")
data = ToonFormat.decode(input, options=options)
# Dict("database" => Dict(
#     "host" => "localhost",
#     "port" => 5432,
#     "credentials" => Dict(
#         "username" => "admin",
#         "password" => "secret"
#     )
# ))
```

### Round-trip Compatibility

Key folding and path expansion are designed to work together:

```julia
original = Dict("a" => Dict("b" => Dict("c" => 42)))

# Encode with folding
encode_opts = ToonFormat.EncodeOptions(keyFolding="safe")
encoded = ToonFormat.encode(original, options=encode_opts)
# a.b.c: 42

# Decode with expansion
decode_opts = ToonFormat.DecodeOptions(expandPaths="safe")
decoded = ToonFormat.decode(encoded, options=decode_opts)
# Dict("a" => Dict("b" => Dict("c" => 42)))

# original == decoded ✓
```

### Conflict Detection

Path expansion detects conflicts when keys overlap:

```julia
# Conflict: 'a' is both a primitive and an object
input = """
a: 1
a.b: 2
"""

# Strict mode: error
options = ToonFormat.DecodeOptions(expandPaths="safe", strict=true)
try
    ToonFormat.decode(input, options=options)
catch e
    println(e)  # "Cannot expand path 'a.b': segment 'a' already exists as non-object"
end

# Non-strict mode: last-write-wins
options = ToonFormat.DecodeOptions(expandPaths="safe", strict=false)
data = ToonFormat.decode(input, options=options)
# Dict("a" => Dict("b" => 2))  # 'a: 1' is overwritten
```

### Depth Limiting

Control how deep folding goes:

```julia
data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => 42))))

# Fold only 2 levels
options = ToonFormat.EncodeOptions(keyFolding="safe", flattenDepth=2)
ToonFormat.encode(data, options=options)
# a.b:
#   c:
#     d: 42
```

## Delimiter Selection

Choose the right delimiter for your use case.

### Comma (Default)

Best for general purpose use:

```julia
users = [Dict("name" => "Alice", "age" => 30)]
ToonFormat.encode(Dict("users" => users))
# users[1]{name,age}:
#   Alice,30
```

**Pros:**
- Most compact
- Familiar to JSON users
- Works well with most data

**Cons:**
- Requires quoting if values contain commas

### Tab

Best for TSV-like data:

```julia
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
users = [Dict("name" => "Alice", "age" => 30)]
ToonFormat.encode(Dict("users" => users), options=options)
# users[1	]{name	age}:
#   Alice	30
```

**Pros:**
- Easy to parse programmatically
- Natural for spreadsheet data
- Rarely needs quoting

**Cons:**
- Less readable in some contexts
- Invisible character

### Pipe

Best for visual separation:

```julia
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE)
users = [Dict("name" => "Alice", "age" => 30)]
ToonFormat.encode(Dict("users" => users), options=options)
# users[1|]{name|age}:
#   Alice|30
```

**Pros:**
- Very readable
- Clear visual separation
- Database/SQL-like

**Cons:**
- Requires quoting if values contain pipes
- Slightly less compact

## Working with Large Data

### Streaming Considerations

For very large datasets, consider:

1. **Chunking:** Process data in smaller batches
2. **Tabular format:** Use tabular arrays for uniform data
3. **Delimiter choice:** Tabs are fastest to parse

```julia
# Process in chunks
function encode_large_dataset(records, chunk_size=1000)
    chunks = []
    for i in 1:chunk_size:length(records)
        chunk = records[i:min(i+chunk_size-1, length(records))]
        push!(chunks, ToonFormat.encode(Dict("data" => chunk)))
    end
    return chunks
end
```

### Memory Efficiency

ToonFormat.jl is designed for correctness over performance, but you can optimize:

```julia
# Use tabular format for uniform data (most compact)
users = [Dict("id" => i, "name" => "User$i") for i in 1:10000]
toon_str = ToonFormat.encode(Dict("users" => users))

# Use appropriate delimiter (tabs are fastest)
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
toon_str = ToonFormat.encode(Dict("users" => users), options=options)
```

## Custom Indentation

Match your team's style preferences:

```julia
# 2 spaces (default, most compact)
options = ToonFormat.EncodeOptions(indent=2)

# 4 spaces (common in many languages)
options = ToonFormat.EncodeOptions(indent=4)

# 8 spaces (very readable)
options = ToonFormat.EncodeOptions(indent=8)
```

## Error Recovery

Handle errors gracefully in production:

```julia
function safe_decode(input::String)
    try
        # Try strict mode first
        return ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    catch e
        @warn "Strict decoding failed, trying lenient mode" exception=e
        try
            # Fall back to lenient mode
            return ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=false))
        catch e2
            @error "Decoding failed completely" exception=e2
            return nothing
        end
    end
end
```

## Integration with Other Formats

### From JSON

```julia
using JSON

# JSON to TOON
json_str = """{"name": "Alice", "age": 30}"""
data = JSON.parse(json_str)
toon_str = ToonFormat.encode(data)

# TOON to JSON
toon_str = "name: Alice\nage: 30"
data = ToonFormat.decode(toon_str)
json_str = JSON.json(data)
```

### From CSV/TSV

```julia
using CSV, DataFrames

# CSV to TOON
df = CSV.read("data.csv", DataFrame)
records = [Dict(pairs(row)) for row in eachrow(df)]
toon_str = ToonFormat.encode(Dict("data" => records))

# Use tab delimiter for TSV-like output
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
toon_str = ToonFormat.encode(Dict("data" => records), options=options)
```

## Performance Tips

1. **Use tabular format** - Most compact for uniform data
2. **Choose appropriate delimiter** - Tabs are fastest to parse
3. **Limit nesting depth** - Flatter structures are faster
4. **Batch operations** - Process multiple records together
5. **Reuse options** - Create options once, reuse many times

```julia
# Good: reuse options
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
for data in datasets
    toon_str = ToonFormat.encode(data, options=options)
    # process...
end

# Bad: create options every time
for data in datasets
    toon_str = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
    # process...
end
```

## Next Steps

- See [Examples](../examples.md) for real-world use cases
- Check [API Reference](../api.md) for complete function documentation
- Review [Compliance](../compliance.md) for specification details
