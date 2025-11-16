# TOON Specification Test Fixtures Status

**Last Updated:** 2024-11-16

## Overview

This document tracks the compliance status of TOON.jl against the official TOON specification test fixtures from https://github.com/toon-format/spec/tree/main/tests.

## Current Status

**Test Results:** 298 passing, 37 failing, 5 errored (out of 340 total tests)

**Compliance Rate:** 87.6% passing

## Test Categories

### ✅ Fully Passing Categories

1. **Primitive value encoding** - 39/39 tests passing
   - String encoding with proper quoting
   - Number encoding (integers, decimals, scientific notation)
   - Boolean and null encoding
   - Unicode and emoji support

2. **Primitive value decoding** - 23/25 tests passing
   - String parsing with escape sequences
   - Number parsing
   - Boolean and null parsing
   - Ambiguity quoting

3. **Number decoding edge cases** - 18/18 tests passing
   - Trailing zeros, exponent forms, negative zero

4. **Object decoding** - 28/28 tests passing
   - Simple and nested objects
   - Key parsing and quoted values

5. **Whitespace tolerance** - 6/6 tests passing
   - Spaces around delimiters and values

6. **Root form detection** - 1/1 test passing
   - Empty document, single primitive, multiple primitives

7. **Validation errors** - 10/10 tests passing
   - Length mismatches, invalid escapes, syntax errors

8. **Strict mode indentation** - 15/15 tests passing
   - Non-multiple indentation, tab characters, custom indent sizes

9. **Blank line handling** - 13/13 tests passing
   - Strict mode errors on blank lines inside arrays

### ⚠️ Partially Passing Categories

#### Object Encoding (24/26 tests passing)
**Failing Tests:**
- `preserves key order in objects` - Dict iteration order not preserved
- `encodes repeating decimal with full precision` - Precision loss (15 vs 16 digits)

#### Primitive Array Encoding (8/10 tests passing)
**Failing Tests:**
- `encodes empty inner arrays` - Empty array encoding issue

#### Tabular Array Encoding (2/5 tests passing)
**Failing Tests:**
- `encodes arrays of similar objects in tabular format` - Field order mismatch
- `quotes strings containing delimiters in tabular rows` - Quoting issue
- `quotes ambiguous strings in tabular rows` - Quoting issue

#### Nested and Mixed Array Encoding (10/12 tests passing)
**Failing Tests:**
- `encodes root-level array of non-uniform objects in list format` - Format selection issue
- `encodes root-level arrays of arrays` - Nested array encoding
- `encodes complex nested structure` - Complex structure handling

#### Arrays of Objects Encoding (4/14 tests passing)
**Failing Tests:**
- Multiple list format tests failing
- Field order preservation issues
- Nested array handling in objects

#### Delimiter Options (22/22 tests passing)
✅ All delimiter tests passing

#### Whitespace and Formatting (2/3 tests passing)
**Failing Tests:**
- None currently

#### Key Folding (13/13 tests passing)
✅ All key folding tests passing

#### Primitive Array Decoding (10/13 tests passing)
**Failing Tests:**
- `parses quoted key with inline array` - Quoted key not unquoted
- `parses quoted key containing brackets with inline array` - Parse error
- `parses quoted key with empty array` - Quoted key not unquoted

#### Tabular Array Decoding (5/6 tests passing)
**Failing Tests:**
- `parses quoted key with tabular array format` - Quoted key not unquoted

#### Nested and Mixed Array Decoding (16/20 tests passing)
**Failing Tests:**
- `parses nested tabular arrays as first field on hyphen line` - Structure mismatch
- `parses arrays of arrays within objects` - Structure mismatch
- `parses empty inner arrays` - Array length validation error
- `parses quoted key with list array format` - Quoted key not unquoted

#### Delimiter Decoding (27/29 tests passing)
**Failing Tests:**
- `nested arrays inside list items default to comma delimiter` - Structure mismatch
- `nested arrays inside list items default to comma with pipe parent` - Structure mismatch

#### Path Expansion (11/12 tests passing)
**Failing Tests:**
- `preserves quoted dotted key as literal when expandPaths=safe` - Quoted key being expanded

### ❌ Errored Tests

1. **Encoding Errors:**
   - `encodes large number` - InexactError: Int64(1.0e20) - Number too large for Int64

2. **Decoding Errors:**
   - `parses Chinese characters` - StringIndexError with multi-byte Unicode
   - `parses string with emoji and spaces` - StringIndexError with emoji

## Known Issues

### Critical Issues

1. **Unicode String Indexing** (2 errors)
   - **Issue:** `find_first_unquoted()` in `src/string_utils.jl` uses byte indexing instead of character indexing
   - **Impact:** Crashes on multi-byte Unicode characters (Chinese, emoji)
   - **Location:** `src/string_utils.jl:183`
   - **Fix Required:** Use `nextind()` for proper Unicode iteration

2. **Large Number Handling** (1 error)
   - **Issue:** `encode_number()` tries to convert large floats to Int64
   - **Impact:** Crashes on numbers >= 1e20
   - **Location:** `src/primitives.jl:23`
   - **Fix Required:** Check if float is within Int64 range before conversion

3. **Quoted Key Handling** (5 failures)
   - **Issue:** Quoted keys are not being unquoted after parsing
   - **Impact:** Keys like `"my-key"` remain as `"my-key"` instead of `my-key`
   - **Location:** Key parsing in decoder
   - **Fix Required:** Strip quotes from parsed keys

### Major Issues

4. **Dictionary Key Order** (1 failure)
   - **Issue:** Julia's `Dict` doesn't preserve insertion order
   - **Impact:** Encoded output has different key order than expected
   - **Solution:** Use `OrderedDict` from OrderedCollections.jl

5. **Floating Point Precision** (1 failure)
   - **Issue:** Julia's default float formatting loses precision
   - **Impact:** `0.3333333333333333` becomes `0.333333333333333`
   - **Solution:** Use custom formatting with full precision

6. **Array Format Selection** (10+ failures)
   - **Issue:** Logic for choosing tabular vs list format needs refinement
   - **Impact:** Arrays encoded in wrong format
   - **Areas:** Field order, nested arrays, mixed types

7. **List Item Structure** (4 failures)
   - **Issue:** Nested arrays and objects in list items not structured correctly
   - **Impact:** Missing fields or incorrect nesting
   - **Location:** `encode_list_item()` and related functions

### Minor Issues

8. **Empty Array Handling** (2 failures)
   - **Issue:** Empty nested arrays not encoded/decoded correctly
   - **Impact:** Structure mismatch in nested scenarios

9. **Delimiter Scoping** (2 failures)
   - **Issue:** Nested arrays not defaulting to comma delimiter correctly
   - **Impact:** Wrong delimiter used in nested contexts

10. **Path Expansion with Quotes** (1 failure)
    - **Issue:** Quoted dotted keys being expanded when they shouldn't be
    - **Impact:** `"c.d"` becomes `c: {d: ...}` instead of literal key

## Priority Fixes

### P0 - Critical (Crashes)
1. Fix Unicode string indexing in `find_first_unquoted()`
2. Fix large number handling in `encode_number()`

### P1 - High (Core Functionality)
3. Fix quoted key unquoting in decoder
4. Implement key order preservation (OrderedDict)
5. Fix floating point precision in number encoding

### P2 - Medium (Format Compliance)
6. Refine array format selection logic
7. Fix list item structure encoding
8. Fix empty array handling

### P3 - Low (Edge Cases)
9. Fix delimiter scoping in nested arrays
10. Fix path expansion with quoted keys

## Testing

To run the fixture tests:
```bash
julia --project=. test/test_spec_fixtures.jl
```

To download/update fixtures:
```bash
julia --project=. test/download_fixtures.jl
```

## References

- TOON Specification: https://github.com/toon-format/spec
- Test Fixtures: https://github.com/toon-format/spec/tree/main/tests
- TOON.jl Implementation: https://github.com/your-org/TOON.jl
