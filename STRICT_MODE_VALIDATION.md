# Strict Mode Error Handling Validation Report

## Overview

This document summarizes the validation and improvements made to TokenOrientedObjectNotation.jl's strict mode error handling to ensure full compliance with the TOON Specification v2.0, Section 14.

## Validation Summary

All strict mode error conditions from the specification have been implemented and tested:

### ✅ 1. Array Count Mismatch Errors (Requirements 10.1, 10.2, 10.3)

**Implemented in:** `src/decoder.jl`

- **Inline arrays**: Validates that the number of values matches the declared length
- **List arrays**: Validates that the number of list items matches the declared length
- **Tabular arrays**: Validates that the number of rows matches the declared length
- **Inline tabular arrays**: Validates that the number of values equals rows × fields

**Test Coverage:**
- Inline array with too few values
- Inline array with too many values
- List array with too few items
- List array with too many items
- Tabular array with too few rows
- Tabular array with too many rows
- Inline tabular array count mismatch
- Nested array count mismatches
- Empty array validation
- All three delimiter types (comma, tab, pipe)

### ✅ 2. Row Width Mismatch Errors (Requirement 10.3)

**Implemented in:** `src/decoder.jl` - `decode_tabular_array()`

- Validates that each row in a tabular array has exactly the number of fields declared in the header
- Provides clear error messages with line numbers

**Test Coverage:**
- Row with too few values
- Row with too many values
- All delimiter types (comma, tab, pipe)

### ✅ 3. Missing Colon Errors (Requirement 10.4)

**Implemented in:** `src/decoder.jl` and `src/scanner.jl`

- Detects missing colons after keys in object key-value pairs
- Detects missing colons after array headers
- Provides line numbers in error messages

**Test Coverage:**
- Missing colon after simple key
- Missing colon after array header
- Missing colon in nested objects
- Missing colon at root level

### ✅ 4. Invalid Escape Sequence Errors (Requirement 10.5)

**Implemented in:** `src/string_utils.jl` - `unescape_string()`

- Only allows five valid escape sequences: `\\`, `\"`, `\n`, `\r`, `\t`
- Rejects all other escape sequences with clear error messages
- Detects unterminated escape sequences at end of string

**Test Coverage:**
- All five valid escape sequences
- Invalid escapes: `\x`, `\u`, `\b`, `\f`, `\v`, `\0`, `\a`
- Escape at end of string
- Multiple invalid escapes
- Escape at different positions in string

### ✅ 5. Unterminated String Errors (Requirement 10.5)

**Implemented in:** `src/decoder.jl` and `src/scanner.jl`

- Detects strings that start with `"` but don't end with `"`
- Detects quoted keys that are not properly terminated

**Test Coverage:**
- Unterminated quoted value
- Unterminated quoted key
- Unterminated escape at end

### ✅ 6. Indentation Errors (Requirements 10.6, 10.7)

**Implemented in:** `src/scanner.jl` - `to_parsed_lines()`

- Validates that indentation is an exact multiple of `indentSize`
- Rejects tabs in indentation
- Provides line numbers in error messages

**Test Coverage:**
- Indentation not multiple of 2 (default)
- Indentation not multiple of 4 (custom indent)
- Tabs at various positions
- Mixed spaces and tabs

### ✅ 7. Blank Line Errors (Requirement 10.7)

**Implemented in:** `src/decoder.jl` - `decode_tabular_array()` and `decode_list_array()`

- Detects blank lines inside array data (between header and last item/row)
- Allows blank lines outside arrays
- Provides line numbers in error messages

**Test Coverage:**
- Blank line after array header (before first item)
- Blank line in middle of list array
- Blank line in middle of tabular array
- Blank lines before and after arrays (allowed)
- Nested arrays with blank lines

### ✅ 8. Path Expansion Conflict Errors (Requirements 14.4, 14.5)

**Implemented in:** `src/decoder.jl` - `expand_dotted_key()`

- Detects conflicts when expanding dotted keys (e.g., `a: 1` followed by `a.b: 2`)
- Errors in strict mode when a segment already exists as a non-object
- Uses last-write-wins in non-strict mode

**Test Coverage:**
- Conflict with primitive value
- Conflict with nested object
- No conflict when both are objects
- Non-strict mode behavior

## Improvements Made

### 1. Enhanced Inline Tabular Array Validation

**Issue:** Inline tabular arrays were not validating that the total number of values matched `rows × fields`.

**Fix:** Added validation in `decode_inline_array_data()` to check that the number of tokens equals the expected count for tabular arrays.

```julia
# Validate that we have the right number of tokens for the declared rows
expected_tokens = header.length * num_fields
if options.strict && length(tokens) != expected_tokens
    error("Array length mismatch: expected $(header.length) rows ($(expected_tokens) values), got $(div(length(tokens), num_fields)) rows ($(length(tokens)) values)")
end
```

### 2. Improved Blank Line Detection

**Issue:** Blank line detection was not correctly identifying blank lines that appear after the array header or between array items.

**Fix:** Improved the logic in both `decode_tabular_array()` and `decode_list_array()` to:
- Track the header line number
- Track the last item/row line number
- Check if blank lines fall within the array's line range

```julia
# Get the line number of the header (one before start_position)
header_line_num = if start_position > 1
    cursor.lines[start_position - 1].lineNumber
else
    0
end

# Get the line number of the last item we processed
last_item_line_num = if cursor.position > 1 && cursor.position - 1 <= length(cursor.lines)
    cursor.lines[cursor.position - 1].lineNumber
else
    typemax(Int)
end

for blank in cursor.blankLines
    # Blank line is inside the array if it's after the header and before/at the last item
    if blank.lineNumber > header_line_num && blank.lineNumber <= last_item_line_num
        error("Blank lines are not allowed inside list arrays (line $(blank.lineNumber))")
    end
end
```

## Test Suite Enhancements

Added comprehensive test coverage for all strict mode error conditions:

- **88 test cases** covering all error scenarios
- Tests for all three delimiter types (comma, tab, pipe)
- Tests for nested structures
- Tests for edge cases (empty arrays, multiple errors, etc.)
- Tests verify that non-strict mode allows lenient parsing
- Tests verify that error messages include line numbers

## Compliance Status

✅ **FULLY COMPLIANT** with TOON Specification v2.0, Section 14

All normative requirements for strict mode error handling have been implemented and validated:

- Requirement 10.1: Array count mismatch errors (inline)
- Requirement 10.2: Array count mismatch errors (list)
- Requirement 10.3: Array count mismatch errors (tabular) and row width mismatch
- Requirement 10.4: Missing colon errors
- Requirement 10.5: Invalid escape sequence and unterminated string errors
- Requirement 10.6: Indentation errors (not multiple of indentSize)
- Requirement 10.7: Indentation errors (tabs) and blank line errors

## Test Results

All tests pass successfully:

```
Test Summary:              | Pass  Total
Strict Mode Error Handling |   88     88
```

Full test suite: **782 tests pass**

## Error Message Quality

All error messages include:
- Clear description of the error
- Line numbers where applicable
- Expected vs actual values for count/width mismatches
- Specific escape sequences that are invalid

Example error messages:
- `"Array length mismatch: expected 5, got 3"`
- `"Row width mismatch at line 3: expected 3 fields, got 2"`
- `"Missing colon after key at line 2"`
- `"Invalid escape sequence: \x"`
- `"Indentation must be a multiple of 2 spaces (line 1)"`
- `"Tabs are not allowed in indentation (line 2)"`
- `"Blank lines are not allowed inside tabular arrays (line 3)"`
- `"Cannot expand path 'a.b': segment 'a' already exists as non-object"`

## Conclusion

The TokenOrientedObjectNotation.jl decoder now has comprehensive strict mode error handling that fully complies with the TOON Specification v2.0. All error conditions are properly detected, reported with clear messages including line numbers, and thoroughly tested.
