# Requirements Document

## Introduction

This specification defines the requirements for ensuring TOON.jl is fully compliant with the official TOON Specification v2.0 (https://github.com/toon-format/spec/blob/main/SPEC.md). TOON (Token-Oriented Object Notation) is a line-oriented, indentation-based text format that encodes the JSON data model with explicit structure and minimal quoting. The implementation must conform to all normative requirements in the specification to ensure interoperability with other TOON implementations.

## Glossary

- **TOON**: Token-Oriented Object Notation, a compact serialization format
- **Encoder**: Component that converts Julia values to TOON format strings
- **Decoder**: Component that parses TOON format strings into Julia values
- **JsonValue**: A value conforming to the JSON data model (primitive, object, or array)
- **Primitive**: A string, number, boolean, or null value
- **Tabular Array**: An array of uniform objects with primitive values only
- **Active Delimiter**: The delimiter declared by the nearest array header (comma, tab, or pipe)
- **Document Delimiter**: The encoder-selected delimiter for quoting decisions outside array scope
- **Strict Mode**: Decoder mode that enforces counts, indentation, and delimiter consistency
- **Key Folding**: Optional encoder feature to collapse single-key object chains into dotted notation
- **Path Expansion**: Optional decoder feature to expand dotted keys into nested objects
- **IdentifierSegment**: A key segment matching ^[A-Za-z_][A-Za-z0-9_]*$ (no dots, valid identifier)

## Requirements

### Requirement 1: Data Model Compliance

**User Story:** As a TOON library user, I want the encoder and decoder to correctly handle all JSON data types, so that I can reliably serialize and deserialize my data structures.

#### Acceptance Criteria

1. WHEN encoding or decoding values, THE Encoder SHALL preserve the JSON data model including primitives (string, number, boolean, null), objects, and arrays
2. WHEN encoding arrays, THE Encoder SHALL preserve array element order
3. WHEN encoding objects, THE Encoder SHALL preserve object key order as encountered
4. WHEN encoding numbers, THE Encoder SHALL emit canonical decimal form without exponent notation, leading zeros, or trailing fractional zeros
5. WHEN encoding the number -0, THE Encoder SHALL normalize it to 0

### Requirement 2: Number Formatting and Precision

**User Story:** As a TOON library user, I want numbers to be formatted canonically and preserve precision, so that numeric data round-trips correctly.

#### Acceptance Criteria

1. WHEN encoding numbers, THE Encoder SHALL emit decimal form without exponent notation (e.g., 1000000 not 1e6)
2. WHEN encoding numbers, THE Encoder SHALL emit no leading zeros except for the single digit "0"
3. WHEN encoding numbers, THE Encoder SHALL emit no trailing zeros in the fractional part (e.g., 1.5 not 1.5000)
4. WHEN encoding numbers with zero fractional part, THE Encoder SHALL emit as integer (e.g., 1 not 1.0)
5. WHEN decoding numeric tokens, THE Decoder SHALL accept both decimal and exponent forms (e.g., 42, -3.14, 1e-6)
6. WHEN decoding tokens with forbidden leading zeros, THE Decoder SHALL treat them as strings not numbers

### Requirement 3: String Escaping and Quoting

**User Story:** As a TOON library user, I want strings to be properly escaped and quoted, so that special characters are handled correctly and the output is unambiguous.

#### Acceptance Criteria

1. WHEN encoding quoted strings, THE Encoder SHALL escape only backslash, double-quote, newline, carriage return, and tab characters
2. WHEN decoding quoted strings, THE Decoder SHALL reject any escape sequence other than \\, \", \n, \r, \t
3. WHEN encoding empty strings, THE Encoder SHALL quote them
4. WHEN encoding strings with leading or trailing whitespace, THE Encoder SHALL quote them
5. WHEN encoding strings equal to "true", "false", or "null", THE Encoder SHALL quote them
6. WHEN encoding numeric-like strings, THE Encoder SHALL quote them
7. WHEN encoding strings containing colon, double-quote, backslash, brackets, braces, or control characters, THE Encoder SHALL quote them
8. WHEN encoding strings containing the active delimiter, THE Encoder SHALL quote them
9. WHEN encoding strings equal to "-" or starting with "-", THE Encoder SHALL quote them

### Requirement 4: Array Header Syntax

**User Story:** As a TOON library user, I want array headers to be correctly formatted and parsed, so that array structure and metadata are properly represented.

#### Acceptance Criteria

1. WHEN encoding arrays, THE Encoder SHALL emit headers in the form [N] or key[N]: where N is the array length
2. WHEN encoding arrays with tab delimiter, THE Encoder SHALL include HTAB inside brackets (e.g., [N<TAB>])
3. WHEN encoding arrays with pipe delimiter, THE Encoder SHALL include "|" inside brackets (e.g., [N|])
4. WHEN encoding tabular arrays, THE Encoder SHALL emit field list in braces using the active delimiter (e.g., {f1,f2})
5. WHEN decoding array headers, THE Decoder SHALL parse the length N as a non-negative integer
6. WHEN decoding array headers without delimiter symbol, THE Decoder SHALL use comma as the active delimiter
7. WHEN decoding array headers, THE Decoder SHALL require a colon after the bracket and optional fields segment

### Requirement 5: Object Encoding and Decoding

**User Story:** As a TOON library user, I want objects to be correctly encoded and decoded with proper indentation, so that nested structures are clearly represented.

#### Acceptance Criteria

1. WHEN encoding object primitive fields, THE Encoder SHALL emit "key: value" with exactly one space after the colon
2. WHEN encoding nested or empty objects, THE Encoder SHALL emit "key:" on its own line
3. WHEN encoding nested objects, THE Encoder SHALL emit nested fields at depth +1
4. WHEN decoding object lines, THE Decoder SHALL require a colon after each key
5. WHEN decoding "key:" with nothing after the colon, THE Decoder SHALL open a nested object at depth +1

### Requirement 6: Array Format Selection

**User Story:** As a TOON library user, I want the encoder to automatically select the most compact array format, so that output is optimized for token efficiency.

#### Acceptance Criteria

1. WHEN encoding arrays of primitives, THE Encoder SHALL use inline format (e.g., [3]: 1,2,3)
2. WHEN encoding arrays of uniform objects with primitive values, THE Encoder SHALL use tabular format
3. WHEN encoding arrays of primitive arrays, THE Encoder SHALL use expanded list format with inner array headers
4. WHEN encoding mixed or non-uniform arrays, THE Encoder SHALL use expanded list format
5. WHEN encoding empty arrays, THE Encoder SHALL emit header with no values (e.g., [0]:)

### Requirement 7: Tabular Array Format

**User Story:** As a TOON library user, I want tabular arrays to be compactly represented, so that uniform data structures are token-efficient.

#### Acceptance Criteria

1. WHEN encoding tabular arrays, THE Encoder SHALL emit field names from the first object's key order
2. WHEN encoding tabular arrays, THE Encoder SHALL emit one row per object at depth +1
3. WHEN encoding tabular rows, THE Encoder SHALL join values with the active delimiter
4. WHEN decoding tabular arrays, THE Decoder SHALL split rows using only the active delimiter
5. WHILE strict mode is enabled, THE Decoder SHALL error if row value count does not equal field count
6. WHILE strict mode is enabled, THE Decoder SHALL error if row count does not equal declared length N

### Requirement 8: Delimiter Scoping and Quoting

**User Story:** As a TOON library user, I want delimiters to be correctly scoped and strings to be quoted appropriately, so that values are not incorrectly split.

#### Acceptance Criteria

1. WHEN encoding inline arrays, THE Encoder SHALL use the active delimiter declared by the array header
2. WHEN encoding tabular rows, THE Encoder SHALL use the active delimiter declared by the array header
3. WHEN encoding object values outside array scope, THE Encoder SHALL use document delimiter for quoting decisions
4. WHEN decoding inline arrays, THE Decoder SHALL split only on the active delimiter
5. WHEN decoding tabular rows, THE Decoder SHALL split only on the active delimiter
6. WHEN splitting delimited values, THE Decoder SHALL preserve empty tokens and decode them as empty strings

### Requirement 9: Indentation and Whitespace

**User Story:** As a TOON library user, I want consistent indentation and whitespace handling, so that documents are readable and parseable.

#### Acceptance Criteria

1. WHEN encoding documents, THE Encoder SHALL use a consistent number of spaces per level (default 2)
2. WHEN encoding documents, THE Encoder SHALL NOT use tabs for indentation
3. WHEN encoding key-value lines, THE Encoder SHALL emit exactly one space after the colon
4. WHEN encoding array headers with inline values, THE Encoder SHALL emit exactly one space after the colon
5. WHEN encoding documents, THE Encoder SHALL emit no trailing spaces at the end of any line
6. WHEN encoding documents, THE Encoder SHALL emit no trailing newline at the end of the document
7. WHILE strict mode is enabled, THE Decoder SHALL error if leading spaces are not an exact multiple of indentSize
8. WHILE strict mode is enabled, THE Decoder SHALL error if tabs are used for indentation

### Requirement 10: Strict Mode Validation

**User Story:** As a TOON library user, I want strict mode to catch malformed input, so that data integrity is ensured.

#### Acceptance Criteria

1. WHILE strict mode is enabled, THE Decoder SHALL error if inline array value count does not equal declared N
2. WHILE strict mode is enabled, THE Decoder SHALL error if list array item count does not equal declared N
3. WHILE strict mode is enabled, THE Decoder SHALL error if tabular array row count does not equal declared N
4. WHILE strict mode is enabled, THE Decoder SHALL error if a key is not followed by a colon
5. WHILE strict mode is enabled, THE Decoder SHALL error if invalid escape sequences are found
6. WHILE strict mode is enabled, THE Decoder SHALL error if indentation is not an exact multiple of indentSize
7. WHILE strict mode is enabled, THE Decoder SHALL error if blank lines appear inside arrays or tabular rows

### Requirement 11: Root Form Detection

**User Story:** As a TOON library user, I want the decoder to correctly identify the root value type, so that single primitives, arrays, and objects are properly decoded.

#### Acceptance Criteria

1. WHEN decoding a document with a valid root array header at depth 0, THE Decoder SHALL decode a root array
2. WHEN decoding a document with exactly one non-empty line that is neither an array header nor a key-value line, THE Decoder SHALL decode a single primitive
3. WHEN decoding a document that does not match root array or single primitive patterns, THE Decoder SHALL decode an object
4. WHEN decoding an empty document, THE Decoder SHALL return an empty object

### Requirement 12: Objects as List Items

**User Story:** As a TOON library user, I want objects in list arrays to be correctly formatted, so that complex nested structures are properly represented.

#### Acceptance Criteria

1. WHEN encoding empty objects as list items, THE Encoder SHALL emit a single "-" at the list-item indentation level
2. WHEN encoding objects as list items with primitive first field, THE Encoder SHALL emit "- key: value" on the hyphen line
3. WHEN encoding objects as list items with nested object first field, THE Encoder SHALL emit "- key:" and nested fields at depth +2
4. WHEN encoding objects as list items, THE Encoder SHALL emit remaining fields at depth +1 under the hyphen line
5. WHEN decoding objects as list items with nested first field, THE Decoder SHALL parse nested fields at depth +2 relative to the hyphen line

### Requirement 13: Key Folding (Optional Feature)

**User Story:** As a TOON library user, I want the option to enable key folding, so that deeply nested single-key objects can be compactly represented.

#### Acceptance Criteria

1. WHERE key folding is enabled in safe mode, THE Encoder SHALL collapse chains of single-key objects into dotted notation
2. WHERE key folding is enabled, THE Encoder SHALL only fold segments that are IdentifierSegments (no dots, valid identifiers)
3. WHERE key folding is enabled with flattenDepth set, THE Encoder SHALL fold at most flattenDepth segments
4. WHERE key folding is enabled, THE Encoder SHALL NOT fold if any segment would require quoting
5. WHERE key folding is enabled, THE Encoder SHALL NOT fold if the resulting key collides with an existing sibling key

### Requirement 14: Path Expansion (Optional Feature)

**User Story:** As a TOON library user, I want the option to enable path expansion, so that dotted keys can be expanded into nested objects for round-trip compatibility with key folding.

#### Acceptance Criteria

1. WHERE path expansion is enabled in safe mode, THE Decoder SHALL expand dotted keys into nested objects
2. WHERE path expansion is enabled, THE Decoder SHALL only expand keys where all segments are IdentifierSegments
3. WHERE path expansion is enabled, THE Decoder SHALL deep-merge overlapping object paths recursively
4. WHERE path expansion is enabled with strict mode, THE Decoder SHALL error on expansion conflicts (object vs non-object)
5. WHERE path expansion is enabled without strict mode, THE Decoder SHALL apply last-write-wins conflict resolution

### Requirement 15: Conformance and Options

**User Story:** As a TOON library user, I want configurable encoding and decoding options, so that I can customize behavior for my use case.

#### Acceptance Criteria

1. WHEN encoding, THE Encoder SHALL support indent option (default 2 spaces)
2. WHEN encoding, THE Encoder SHALL support delimiter option (default comma; alternatives: tab, pipe)
3. WHEN encoding, THE Encoder SHALL support keyFolding option (default "off"; alternative: "safe")
4. WHEN encoding, THE Encoder SHALL support flattenDepth option (default Infinity when keyFolding is "safe")
5. WHEN decoding, THE Decoder SHALL support indent option (default 2 spaces)
6. WHEN decoding, THE Decoder SHALL support strict option (default true)
7. WHEN decoding, THE Decoder SHALL support expandPaths option (default "off"; alternative: "safe")
