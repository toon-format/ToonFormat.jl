# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
String utilities for escaping and unescaping TOON strings.
"""

"""
    escape_string(s::String) -> String

Escape special characters in a string according to TOON specification.
Only escapes: \\, \", \\n, \\r, \\t
"""
function escape_string(s::String)::String
    result = IOBuffer()
    for char in s
        if haskey(CHARS_TO_ESCAPE, char)
            write(result, CHARS_TO_ESCAPE[char])
        else
            write(result, char)
        end
    end
    return String(take!(result))
end

"""
    unescape_string(s::AbstractString) -> String

Unescape a TOON string. Throws an error if invalid escape sequences are found.
"""
function unescape_string(s::AbstractString)::String
    s_str = String(s)
    result = IOBuffer()
    i = 1
    while i <= length(s_str)
        if s_str[i] == '\\'
            if i == length(s_str)
                throw(ArgumentError("Unterminated escape sequence at end of string"))
            end

            next_char = s_str[i+1]
            if haskey(ESCAPE_CHARS, next_char)
                write(result, ESCAPE_CHARS[next_char])
                i += 2
            else
                throw(ArgumentError("Invalid escape sequence: \\$(next_char)"))
            end
        else
            write(result, s_str[i])
            i += 1
        end
    end
    return String(take!(result))
end

"""
    is_numeric_literal(s::AbstractString) -> Bool

Check if a string matches the numeric pattern.
"""
function is_numeric_literal(s::AbstractString)::Bool
    return !isnothing(match(NUMERIC_PATTERN, String(s)))
end

"""
    has_leading_zeros(s::AbstractString) -> Bool

Check if a string has forbidden leading zeros (e.g., "05", "0001").
"""
function has_leading_zeros(s::AbstractString)::Bool
    return !isnothing(match(LEADING_ZERO_PATTERN, String(s)))
end

"""
    is_boolean_or_null_literal(s::AbstractString) -> Bool

Check if a string is a boolean or null literal.
"""
function is_boolean_or_null_literal(s::AbstractString)::Bool
    return s == TRUE_LITERAL || s == FALSE_LITERAL || s == NULL_LITERAL
end

"""
    needs_quoting(s::String, delimiter::Delimiter) -> Bool

Determine if a string needs quoting based on TOON rules.
"""
function needs_quoting(s::String, delimiter::Delimiter)::Bool
    # Empty string must be quoted
    if isempty(s)
        return true
    end

    # Leading or trailing whitespace
    if s != strip(s)
        return true
    end

    # Reserved literals
    if is_boolean_or_null_literal(s)
        return true
    end

    # Numeric-like strings
    if is_numeric_literal(s) || has_leading_zeros(s)
        return true
    end

    # Contains special characters
    if occursin(COLON, s) || occursin(DOUBLE_QUOTE, s) || occursin(BACKSLASH, s)
        return true
    end

    # Contains brackets or braces
    if occursin(OPEN_BRACKET, s) ||
       occursin(CLOSE_BRACKET, s) ||
       occursin(OPEN_BRACE, s) ||
       occursin(CLOSE_BRACE, s)
        return true
    end

    # Contains control characters (any character with code < 32 or == 127)
    for char in s
        if Int(char) < 32 || Int(char) == 127
            return true
        end
    end

    # Contains the active delimiter
    if occursin(delimiter, s)
        return true
    end

    # Starts with hyphen or equals hyphen
    if s == "-" || startswith(s, "-")
        return true
    end

    return false
end

"""
    is_valid_unquoted_key(s::String) -> Bool

Check if a string is a valid unquoted key.
"""
function is_valid_unquoted_key(s::String)::Bool
    return !isnothing(match(UNQUOTED_KEY_PATTERN, s))
end

"""
    is_identifier_segment(s::String) -> Bool

Check if a string is a valid identifier segment (for key folding/expansion).
"""
function is_identifier_segment(s::String)::Bool
    return !isnothing(match(IDENTIFIER_SEGMENT_PATTERN, s))
end

"""
    is_safe_identifier(s::AbstractString) -> Bool

Check if a string is safe for key folding (no dots, valid identifier).
Safe identifiers match the pattern: ^[A-Za-z_][A-Za-z0-9_]*\$
"""
function is_safe_identifier(s::AbstractString)::Bool
    # Must not contain dots
    if occursin('.', s)
        return false
    end
    # Must be a valid identifier segment
    return is_identifier_segment(String(s))
end

"""
    find_first_unquoted(s::String, target::Char) -> Union{Int, Nothing}

Find the first occurrence of a character outside of quoted strings.
Returns the index (1-based) or nothing if not found.
"""
function find_first_unquoted(s::String, target::Char)::Union{Int,Nothing}
    in_quotes = false
    skip_next = false

    for (idx, char) in pairs(s)
        if skip_next
            skip_next = false
            continue
        end

        if char == '\\'
            # Skip next character
            skip_next = true
            continue
        elseif char == '"'
            in_quotes = !in_quotes
        elseif char == target && !in_quotes
            return idx
        end
    end

    return nothing
end
