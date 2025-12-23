# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Constants used throughout the TOON format implementation.
"""

# Delimiters
const COMMA = ","
const TAB = "\t"
const PIPE = "|"
const DEFAULT_DELIMITER = COMMA

const DELIMITERS = Dict("comma" => COMMA, "tab" => TAB, "pipe" => PIPE)

# Special characters
const COLON = ":"
const DOUBLE_QUOTE = "\""
const BACKSLASH = "\\"
const NEWLINE = "\n"
const CARRIAGE_RETURN = "\r"
const HTAB = "\t"
const DOT = "."

# Array and object markers
const OPEN_BRACKET = "["
const CLOSE_BRACKET = "]"
const OPEN_BRACE = "{"
const CLOSE_BRACE = "}"
const LIST_ITEM_MARKER = "- "

# Literals
const TRUE_LITERAL = "true"
const FALSE_LITERAL = "false"
const NULL_LITERAL = "null"

# Escape sequences
const ESCAPE_CHARS = Dict('\\' => '\\', '"' => '"', 'n' => '\n', 'r' => '\r', 't' => '\t')

const CHARS_TO_ESCAPE =
    Dict('\\' => "\\\\", '"' => "\\\"", '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")

# Validation patterns
const UNQUOTED_KEY_PATTERN = r"^[A-Za-z_][A-Za-z0-9_.]*$"
const IDENTIFIER_SEGMENT_PATTERN = r"^[A-Za-z_][A-Za-z0-9_]*$"
const NUMERIC_PATTERN = r"^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?$"
const LEADING_ZERO_PATTERN = r"^-?0\d+$"
