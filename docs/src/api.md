# API Reference

Complete API documentation for ToonFormat.jl.

## Main Functions

### encode

```julia
encode(value; options::EncodeOptions=EncodeOptions()) -> String
```

Encode a Julia value to TOON format string.

**Arguments:**
- `value`: Any Julia value (will be normalized to JSON model)
- `options`: Optional encoding configuration

**Returns:** TOON formatted string

**Example:**
```julia
data = Dict("name" => "Alice", "age" => 30)
toon_str = ToonFormat.encode(data)
```

### decode

```julia
decode(input::String; options::DecodeOptions=DecodeOptions()) -> JsonValue
```

Decode a TOON format string to a Julia value.

**Arguments:**
- `input`: TOON formatted string
- `options`: Optional decoding configuration

**Returns:** Parsed Julia value (Dict, Array, or primitive)

**Example:**
```julia
input = "name: Alice\nage: 30"
data = ToonFormat.decode(input)
```

## Configuration Types

### EncodeOptions

```julia
EncodeOptions(;
    indent::Int = 2,
    delimiter::Delimiter = COMMA,
    keyFolding::String = "off",
    flattenDepth::Int = typemax(Int)
)
```

Configuration for encoding behavior.

**Fields:**
- `indent::Int`: Number of spaces per indentation level (default: 2)
- `delimiter::Delimiter`: Delimiter for arrays - `COMMA`, `TAB`, or `PIPE` (default: `COMMA`)
- `keyFolding::String`: Key folding mode - `"off"` or `"safe"` (default: `"off"`)
- `flattenDepth::Int`: Maximum folding depth (default: unlimited)

**Example:**
```julia
options = ToonFormat.EncodeOptions(
    indent = 4,
    delimiter = ToonFormat.TAB,
    keyFolding = "safe",
    flattenDepth = 2
)
```

### DecodeOptions

```julia
DecodeOptions(;
    indent::Int = 2,
    strict::Bool = true,
    expandPaths::String = "off"
)
```

Configuration for decoding behavior.

**Fields:**
- `indent::Int`: Expected spaces per indentation level (default: 2)
- `strict::Bool`: Enable strict validation (default: true)
- `expandPaths::String`: Path expansion mode - `"off"` or `"safe"` (default: `"off"`)

**Example:**
```julia
options = ToonFormat.DecodeOptions(
    indent = 4,
    strict = true,
    expandPaths = "safe"
)
```

## Constants

### Delimiters

```julia
COMMA::Delimiter    # ","
TAB::Delimiter      # "\t"
PIPE::Delimiter     # "|"
```

Delimiter constants for array encoding.

**Example:**
```julia
options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
```

### Escape Sequences

```julia
BACKSLASH = "\\\\"   # \\
DOUBLE_QUOTE = "\\"" # \"
NEWLINE = "\\n"      # \n
CARRIAGE_RETURN = "\\r"  # \r
TAB_ESCAPE = "\\t"   # \t
```

Valid escape sequences in TOON strings.

## Type Aliases

### JsonValue

```julia
JsonValue = Union{JsonObject, JsonArray, JsonPrimitive}
```

Any valid JSON value type.

### JsonObject

```julia
JsonObject = Dict{String, JsonValue}
```

JSON object (dictionary with string keys).

### JsonArray

```julia
JsonArray = Vector{JsonValue}
```

JSON array (vector of values).

### JsonPrimitive

```julia
JsonPrimitive = Union{String, Number, Bool, Nothing}
```

JSON primitive types (string, number, boolean, null).

## Internal Types

These types are used internally but may be useful for advanced usage.

### LineWriter

```julia
mutable struct LineWriter
    lines::Vector{String}
end
```

Helper for building multi-line output during encoding.

**Methods:**
- `push!(writer, depth, content)`: Add a line at specified depth

### LineCursor

```julia
mutable struct LineCursor
    lines::Vector{ParsedLine}
    position::Int
    blankLines::Vector{BlankLine}
end
```

Helper for parsing multi-line input during decoding.

**Methods:**
- `peek(cursor)`: Look at current line without advancing
- `advance!(cursor)`: Move to next line
- `has_more(cursor)`: Check if more lines available

### ParsedLine

```julia
struct ParsedLine
    content::String
    depth::Int
    lineNumber::Int
end
```

Represents a parsed line with indentation information.

### ArrayHeader

```julia
struct ArrayHeader
    length::Int
    delimiter::Delimiter
    fields::Union{Vector{String}, Nothing}
end
```

Parsed array header information.

**Fields:**
- `length`: Declared array length
- `delimiter`: Active delimiter for this array
- `fields`: Field names for tabular arrays (or `nothing`)

## Utility Functions

### normalize

```julia
normalize(value) -> JsonValue
```

Normalize a Julia value to the JSON data model.

**Transformations:**
- `NaN`, `Inf`, `-Inf` → `nothing` (null)
- `-0.0` → `0.0`
- Dictionaries → `JsonObject`
- Arrays → `JsonArray`
- Other types → primitives

**Example:**
```julia
ToonFormat.normalize(NaN)  # nothing
ToonFormat.normalize(-0.0)  # 0.0
```

### is_tabular_array

```julia
is_tabular_array(arr::Vector) -> Bool
```

Check if an array can be encoded in tabular format.

**Requirements:**
- All elements are objects (dictionaries)
- All objects have the same keys
- All keys are strings

**Example:**
```julia
arr = [Dict("a" => 1, "b" => 2), Dict("a" => 3, "b" => 4)]
ToonFormat.is_tabular_array(arr)  # true
```

### needs_quoting

```julia
needs_quoting(s::String, delimiter::Delimiter) -> Bool
```

Check if a string needs to be quoted.

**Quoting required for:**
- Empty strings
- Strings with whitespace
- Reserved literals (`true`, `false`, `null`)
- Numeric-like strings
- Strings with special characters
- Strings containing the active delimiter

**Example:**
```julia
ToonFormat.needs_quoting("hello", ToonFormat.COMMA)  # false
ToonFormat.needs_quoting("hello world", ToonFormat.COMMA)  # true
ToonFormat.needs_quoting("true", ToonFormat.COMMA)  # true
```

## Error Types

ToonFormat.jl throws `ErrorException` with descriptive messages for various error conditions:

- **Array count mismatch:** `"Array length mismatch: expected X, got Y"`
- **Row width mismatch:** `"Row width mismatch at line X: expected Y fields, got Z"`
- **Missing colon:** `"Missing colon after key at line X"`
- **Invalid escape:** `"Invalid escape sequence: \X"`
- **Unterminated string:** `"Unterminated string at line X"`
- **Indentation error:** `"Indentation must be a multiple of X spaces (line Y)"`
- **Tab in indentation:** `"Tabs are not allowed in indentation (line X)"`
- **Blank line error:** `"Blank lines are not allowed inside arrays (line X)"`
- **Path conflict:** `"Cannot expand path 'X': segment 'Y' already exists as non-object"`

## Version Information

```julia
ToonFormat.version  # Package version
```

Get the current version of ToonFormat.jl.

## Next Steps

- See [Examples](examples.md) for usage examples
- Review [Compliance](compliance.md) for specification details
- Check [User Guide](guide/encoding.md) for detailed explanations
