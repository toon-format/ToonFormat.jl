# Design Document

## Overview

This design document outlines the approach to ensure TOON.jl achieves full compliance with the TOON Specification v2.0. The current implementation (v0.1.0) already has substantial functionality implemented, including core encoding/decoding, key folding, and path expansion. This design focuses on identifying gaps, validating compliance, and implementing any missing features or fixes needed to meet all normative requirements.

Based on analysis of the current codebase and the official specification, the implementation is largely complete but requires:
1. Validation against the official test suite
2. Verification of edge cases and strict-mode error handling
3. Potential fixes for any discovered non-compliance issues
4. Documentation updates to reflect full compliance

## Architecture

### Component Structure

The TOON.jl package follows a modular architecture:

```
TOON.jl/
├── src/
│   ├── TOON.jl           # Main module, exports public API
│   ├── types.jl          # Type definitions (JsonValue, Options, etc.)
│   ├── constants.jl      # Constants (delimiters, escape sequences, patterns)
│   ├── normalize.jl      # Value normalization to JSON model
│   ├── string_utils.jl   # String escaping, quoting, validation
│   ├── primitives.jl     # Primitive value encoding
│   ├── encoder.jl        # Main encoding logic
│   ├── scanner.jl        # Line scanning and parsing
│   └── decoder.jl        # Main decoding logic
└── test/
    └── runtests.jl       # Test suite
```

### Data Flow

**Encoding Flow:**
```
Input Value → normalize_value() → encode() → encode_value() → Output String
                                      ↓
                                  encode_object()
                                  encode_array()
                                  encode_primitive()
```

**Decoding Flow:**
```
Input String → to_parsed_lines() → decode() → decode_value_from_lines() → Output Value
                                       ↓
                                   decode_object()
                                   decode_array()
                                   parse_primitive()
```

## Components and Interfaces

### 1. Number Formatting Component

**Current State:** Implemented in `primitives.jl` with `format_number()` function.

**Compliance Requirements:**
- Canonical decimal form (no exponent notation)
- No leading zeros except "0"
- No trailing fractional zeros
- Integer form when fractional part is zero
- Normalize -0 to 0

**Design Decisions:**
- Use Julia's `@sprintf` for precise decimal formatting
- Implement custom logic to strip trailing zeros
- Handle edge cases: very large numbers, very small numbers, -0

**Verification Needed:**
- Test with numbers requiring many decimal places (e.g., 0.000001 not 1e-6)
- Test with large integers (e.g., 1000000 not 1e6)
- Test -0 normalization
- Test fractional zero stripping (1.0 → 1, 1.5000 → 1.5)

### 2. String Quoting Component

**Current State:** Implemented in `string_utils.jl` with `needs_quoting()` function.

**Compliance Requirements:**
- Quote empty strings
- Quote strings with leading/trailing whitespace
- Quote reserved literals (true, false, null)
- Quote numeric-like strings
- Quote strings with special characters (colon, quotes, backslash, brackets, braces)
- Quote strings with control characters
- Quote strings containing the active delimiter
- Quote strings equal to "-" or starting with "-"

**Design Decisions:**
- Centralize all quoting logic in `needs_quoting()`
- Accept delimiter parameter for context-aware quoting
- Use regex patterns for numeric detection

**Verification Needed:**
- Test all quoting conditions from §7.2
- Test delimiter-aware quoting (document vs active delimiter)
- Test hyphen quoting edge cases

### 3. Array Header Component

**Current State:** Implemented in `primitives.jl` with `format_header()` and in `scanner.jl` with `parse_array_header()`.

**Compliance Requirements:**
- Format: [N] or key[N]: or key[N]{fields}:
- Delimiter symbols: absent (comma), HTAB (tab), "|" (pipe)
- Field names separated by active delimiter
- Colon required after header

**Design Decisions:**
- Encode delimiter symbol in bracket segment
- Use same delimiter in fields segment
- Validate header syntax on decode

**Verification Needed:**
- Test all delimiter variations
- Test field list parsing
- Test missing colon error
- Test delimiter mismatch between bracket and fields

### 4. Delimiter Scoping Component

**Current State:** Partially implemented. Encoder uses `options.delimiter` as document delimiter. Decoder tracks active delimiter from headers.

**Compliance Requirements:**
- Document delimiter: affects quoting for object values throughout document
- Active delimiter: declared by array header, affects splitting for that array's scope
- Nested headers can change active delimiter
- Absence of delimiter symbol always means comma

**Design Decisions:**
- Encoder: Pass document delimiter to `encode_primitive()` for quoting
- Encoder: Pass active delimiter to array encoding functions
- Decoder: Track active delimiter per array scope
- Decoder: Use active delimiter only for splitting inline arrays and tabular rows

**Verification Needed:**
- Test nested arrays with different delimiters
- Test object values inside arrays (should use document delimiter for quoting)
- Test delimiter inheritance (absence means comma, not parent delimiter)

### 5. Indentation and Whitespace Component

**Current State:** Implemented in `types.jl` (LineWriter) and `scanner.jl` (to_parsed_lines).

**Compliance Requirements:**
- Consistent spaces per level (default 2, configurable)
- No tabs for indentation
- Exactly one space after colons
- No trailing spaces
- No trailing newline
- Strict mode: indentation must be exact multiple of indentSize

**Design Decisions:**
- LineWriter manages indentation automatically
- Scanner computes depth from leading spaces
- Strict mode validates indentation multiples

**Verification Needed:**
- Test indentation validation in strict mode
- Test tab rejection in strict mode
- Test trailing space/newline handling
- Test space after colon consistency

### 6. Strict Mode Validation Component

**Current State:** Partially implemented. Some validations present, others may be missing.

**Compliance Requirements (§14):**
- Array count mismatches (inline, list, tabular)
- Row width mismatches (tabular)
- Missing colon after key
- Invalid escape sequences
- Unterminated strings
- Indentation errors (not multiple of indentSize, tabs)
- Blank lines inside arrays/tabular rows
- Path expansion conflicts (when expandPaths enabled)

**Design Decisions:**
- Check strict flag before throwing errors
- Provide clear error messages with line numbers
- Validate counts after parsing complete structures

**Verification Needed:**
- Test all error conditions from §14
- Test error messages are clear and actionable
- Test non-strict mode behavior (lenient parsing)

### 7. Root Form Detection Component

**Current State:** Implemented in `decoder.jl` in `decode_value_from_lines()`.

**Compliance Requirements (§5):**
- Root array: first non-empty depth-0 line is valid array header with colon
- Single primitive: exactly one non-empty line, not array header, not key-value
- Object: default case
- Empty document: no non-empty lines → empty object

**Design Decisions:**
- Peek at first line to determine form
- Try parsing as array header
- Check for colon to distinguish key-value from primitive
- Handle empty input gracefully

**Verification Needed:**
- Test root array detection
- Test single primitive detection (various types)
- Test object detection (default)
- Test empty document → empty object
- Test invalid multi-primitive input (strict mode error)

### 8. Key Folding Component

**Current State:** Implemented in `encoder.jl` in `encode_key_value_pair()`.

**Compliance Requirements (§13.4):**
- Mode: "off" (default) or "safe"
- flattenDepth: max segments to fold (default Infinity when safe mode)
- Foldable chain: single-key objects until non-single-key or leaf
- Safe mode: all segments must be IdentifierSegments (no dots, valid identifiers)
- No quoting required for any segment
- No collision with existing sibling keys

**Design Decisions:**
- Recursive folding with prefix accumulation
- Check `is_safe_identifier()` for each segment
- Respect flattenDepth limit
- Stop folding when reaching non-object or multi-key object

**Verification Needed:**
- Test basic folding (a.b.c)
- Test flattenDepth limits
- Test safe mode validation (reject segments with dots or requiring quotes)
- Test collision avoidance
- Test folding with arrays (data.items[2]:)
- Test partial folding (depth limit stops mid-chain)

### 9. Path Expansion Component

**Current State:** Implemented in `decoder.jl` in `expand_dotted_key()`.

**Compliance Requirements (§13.4):**
- Mode: "off" (default) or "safe"
- Safe mode: only expand keys where all segments are IdentifierSegments
- Deep merge: recursively merge overlapping object paths
- Conflict resolution: strict mode errors, non-strict mode uses last-write-wins
- Application order: after base parsing, before returning final value

**Design Decisions:**
- Split dotted keys on "."
- Navigate/create nested structure
- Check `is_safe_identifier()` for all segments
- Merge objects recursively
- Error on conflicts in strict mode

**Verification Needed:**
- Test basic expansion (a.b.c → nested objects)
- Test deep merge (multiple dotted keys creating same parent)
- Test safe mode validation (reject non-identifier segments)
- Test conflict detection (object vs primitive)
- Test conflict resolution (strict error, non-strict LWW)
- Test round-trip with key folding

### 10. Objects as List Items Component

**Current State:** Implemented in `encoder.jl` in `encode_list_item()` and partially in `decoder.jl`.

**Compliance Requirements (§10):**
- Empty object: single "-"
- First field on hyphen line: "- key: value" or "- key:"
- Nested object first field: fields at depth +2
- Remaining fields: at depth +1
- Arrays on first field: supported

**Design Decisions:**
- Encode first field on hyphen line
- Adjust depth for nested object first field (+2 vs +1)
- Encode remaining fields at +1

**Verification Needed:**
- Test empty object list items
- Test primitive first field
- Test nested object first field (depth +2)
- Test array first field
- Test remaining fields (depth +1)
- Test complex nested structures

## Data Models

### Core Types

```julia
# JSON value types
JsonPrimitive = Union{String, Number, Bool, Nothing}
JsonObject = Dict{String, Any}
JsonArray = Vector{Any}
JsonValue = Union{JsonPrimitive, JsonObject, JsonArray}

# Encoding options
struct EncodeOptions
    indent::Int                    # Spaces per level (default 2)
    delimiter::Delimiter           # Document delimiter (default comma)
    keyFolding::String            # "off" or "safe" (default "off")
    flattenDepth::Int             # Max folding depth (default Infinity)
end

# Decoding options
struct DecodeOptions
    indent::Int                    # Expected spaces per level (default 2)
    strict::Bool                   # Enable strict validation (default true)
    expandPaths::String           # "off" or "safe" (default "off")
end

# Array header information
struct ArrayHeaderInfo
    key::Union{String, Nothing}    # Key prefix (nothing for root arrays)
    length::Int                    # Declared array length
    delimiter::Delimiter           # Active delimiter for this array
    fields::Union{Vector{String}, Nothing}  # Field names for tabular arrays
end

# Parsed line information
struct ParsedLine
    content::String                # Line content (without indentation)
    depth::Int                     # Indentation depth
    lineNumber::Int               # Original line number
end
```

### Delimiter Types

```julia
Delimiter = String  # One of: "," (comma), "\t" (tab), "|" (pipe)

const COMMA = ","
const TAB = "\t"
const PIPE = "|"
```

## Error Handling

### Strict Mode Errors

All strict mode errors should:
1. Include descriptive error message
2. Include line number when applicable
3. Reference the specific requirement violated
4. Be thrown as Julia exceptions

**Error Categories:**
- **Count Mismatches:** "Array length mismatch: expected N, got M"
- **Width Mismatches:** "Row width mismatch: expected N fields, got M"
- **Syntax Errors:** "Missing colon after key", "Invalid escape sequence: \\x"
- **Indentation Errors:** "Indentation must be exact multiple of N spaces"
- **Structural Errors:** "Blank lines not allowed inside arrays"
- **Expansion Conflicts:** "Cannot expand path 'a.b': segment 'a' already exists as non-object"

### Non-Strict Mode Behavior

When strict mode is disabled:
- Count mismatches: accept actual count
- Width mismatches: pad with empty strings or truncate
- Indentation: compute depth as floor(spaces / indentSize)
- Blank lines: ignore (don't count as items/rows)
- Expansion conflicts: last-write-wins

## Testing Strategy

### Test Categories

1. **Unit Tests**
   - String escaping/unescaping
   - Quoting rules
   - Number formatting
   - Key validation
   - Header parsing
   - Delimiter splitting

2. **Integration Tests**
   - Encode/decode round-trips
   - Complex nested structures
   - All array formats
   - Key folding and path expansion
   - Delimiter variations

3. **Compliance Tests**
   - Official TOON spec test suite (if available)
   - All examples from specification
   - All error conditions from §14
   - Edge cases from specification

4. **Property-Based Tests**
   - Round-trip property: decode(encode(x)) == x
   - Determinism: encode(x) always produces same output
   - Idempotence: encode(decode(encode(x))) == encode(x)

### Test Coverage Goals

- 100% coverage of normative requirements
- All examples from specification
- All error conditions
- Edge cases: empty values, deeply nested, large arrays, special characters

### Validation Approach

1. **Manual Review:** Compare implementation against specification sections
2. **Example Validation:** Run all specification examples through encoder/decoder
3. **Error Testing:** Trigger all strict-mode errors and verify messages
4. **Round-Trip Testing:** Ensure encode/decode preserves values
5. **Cross-Implementation Testing:** Compare output with reference TypeScript implementation (if feasible)

## Implementation Priorities

### Phase 1: Validation and Gap Analysis
1. Review current implementation against all 15 requirements
2. Identify any missing functionality
3. Create comprehensive test cases for each requirement
4. Document any deviations or ambiguities

### Phase 2: Core Compliance Fixes
1. Fix number formatting edge cases
2. Verify string quoting completeness
3. Validate delimiter scoping behavior
4. Ensure indentation/whitespace compliance
5. Complete strict mode error handling

### Phase 3: Advanced Features
1. Verify key folding implementation
2. Verify path expansion implementation
3. Test round-trip compatibility
4. Handle conflict resolution

### Phase 4: Testing and Documentation
1. Run full test suite
2. Add missing test cases
3. Update documentation
4. Create compliance report

## Design Decisions and Rationales

### Decision 1: Use Dict for Objects (Not OrderedDict)

**Rationale:** Julia's Dict preserves insertion order as of Julia 1.0+, meeting the specification requirement to preserve key order. Using OrderedDict would add an unnecessary dependency.

**Trade-off:** Dict order preservation is an implementation detail, but it's stable and documented.

### Decision 2: Normalize Values Before Encoding

**Rationale:** Separating normalization from encoding keeps the encoder focused on TOON syntax. Normalization handles host-type conversion (NaN → null, -0 → 0, etc.).

**Trade-off:** Two-pass approach, but cleaner separation of concerns.

### Decision 3: Line-Based Parsing

**Rationale:** TOON is line-oriented, so parsing line-by-line with depth tracking is natural and efficient.

**Trade-off:** Requires careful depth management, but aligns with specification structure.

### Decision 4: Strict Mode Default to True

**Rationale:** Specification recommends strict validation for data integrity. Users can opt-out for lenient parsing.

**Trade-off:** May be less forgiving for malformed input, but catches errors early.

### Decision 5: Key Folding and Path Expansion Default to Off

**Rationale:** These are optional features that change the structure. Defaulting to off ensures backward compatibility and predictable behavior.

**Trade-off:** Users must explicitly enable for compact notation, but safer default.

### Decision 6: Separate Encoder and Decoder Options

**Rationale:** Encoding and decoding have different configuration needs. Separate option types make the API clearer.

**Trade-off:** Two types to maintain, but better type safety and clarity.

## Open Questions and Considerations

1. **Performance Optimization:** Current implementation prioritizes correctness. Future work could optimize for large arrays or deeply nested structures.

2. **Error Message Quality:** Should error messages include suggestions for fixes? (e.g., "Did you mean to quote this string?")

3. **Streaming Support:** Specification doesn't require streaming, but could be useful for very large documents. Out of scope for initial compliance.

4. **Schema Validation:** Specification mentions future schema support. Not required for v2.0 compliance.

5. **Comment Support:** Specification explicitly excludes comments. No action needed.

6. **Unicode Normalization:** Specification doesn't require Unicode normalization. Accept UTF-8 as-is.

7. **Numeric Precision:** Julia's Float64 has ~15-17 decimal digits of precision. Document this limitation and behavior for out-of-range numbers.
