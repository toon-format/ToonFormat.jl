# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Scanner for parsing TOON text into structured lines.
"""

"""
    to_parsed_lines(input::String, indent_size::Int, strict::Bool) -> ScanResult

Parse TOON input string into structured lines.
"""
function to_parsed_lines(input::String, indent_size::Int, strict::Bool)::ScanResult
    if isempty(input)
        return ScanResult(ParsedLine[], BlankLineInfo[])
    end

    lines = split(input, '\n')
    parsed_lines = ParsedLine[]
    blank_lines = BlankLineInfo[]

    for (line_num, raw_line) in enumerate(lines)
        # Check if line is blank
        if isempty(strip(raw_line))
            indent_count = count(c -> c == ' ', raw_line)
            depth = strict ? (indent_count ÷ indent_size) : floor(Int, indent_count / indent_size)
            push!(blank_lines, BlankLineInfo(line_num, indent_count, depth))
            continue
        end

        # Count leading spaces
        indent_count = 0
        for char in raw_line
            if char == ' '
                indent_count += 1
            else
                break
            end
        end

        # Check for tabs in indentation (strict mode)
        if strict && occursin('\t', raw_line[1:min(indent_count+1, length(raw_line))])
            error("Tabs are not allowed in indentation (line $(line_num))")
        end

        # Calculate depth
        if strict
            if indent_count % indent_size != 0
                error("Indentation must be a multiple of $(indent_size) spaces (line $(line_num))")
            end
            depth = indent_count ÷ indent_size
        else
            depth = floor(Int, indent_count / indent_size)
        end

        # Get content (trimmed)
        content = strip(raw_line)

        push!(parsed_lines, ParsedLine(raw_line, depth, indent_count, content, line_num))
    end

    return ScanResult(parsed_lines, blank_lines)
end

"""
    find_first_unquoted(s::AbstractString, char::Char) -> Union{Int, Nothing}

Find the first unquoted occurrence of a character.
"""
function find_first_unquoted(s::AbstractString, char::Char)::Union{Int, Nothing}
    s = String(s)  # Convert to String if it's a SubString
    in_quotes = false
    i = 1

    while i <= length(s)
        if s[i] == '"'
            in_quotes = !in_quotes
        elseif s[i] == '\\' && i < length(s) && in_quotes
            # Skip escaped character
            i += 1
        elseif !in_quotes && s[i] == char
            return i
        end
        i += 1
    end

    return nothing
end

"""
    parse_delimited_values(s::AbstractString, delimiter::Delimiter) -> Vector{String}

Parse a delimited string into tokens, respecting quotes.
"""
function parse_delimited_values(s::AbstractString, delimiter::Delimiter)::Vector{String}
    s = String(s)  # Convert to String if it's a SubString
    tokens = String[]
    current = IOBuffer()
    in_quotes = false
    i = 1

    while i <= length(s)
        char = s[i]

        if char == '"'
            in_quotes = !in_quotes
            write(current, char)
        elseif char == '\\' && i < length(s) && in_quotes
            # Include escape sequence as-is
            write(current, char)
            i += 1
            if i <= length(s)
                write(current, s[i])
            end
        elseif !in_quotes && string(char) == delimiter
            # Split on delimiter
            push!(tokens, String(take!(current)))
            current = IOBuffer()
        else
            write(current, char)
        end

        i += 1
    end

    # Add final token
    push!(tokens, String(take!(current)))

    return tokens
end

"""
    parse_array_header(content::String) -> Union{ArrayHeaderInfo, Nothing}

Parse an array header from a content string.
Returns nothing if not a valid array header.
"""
function parse_array_header(content::String)::Union{ArrayHeaderInfo, Nothing}
    # Find opening bracket
    bracket_start = findfirst('[', content)
    if bracket_start === nothing
        return nothing
    end

    # Find closing bracket
    bracket_end = findnext(']', content, bracket_start)
    if bracket_end === nothing
        return nothing
    end

    # Extract key (everything before opening bracket)
    key = bracket_start > 1 ? strip(content[1:bracket_start-1]) : nothing
    if key !== nothing && isempty(key)
        key = nothing
    end

    # Extract bracket content
    bracket_content = content[bracket_start+1:bracket_end-1]

    # Determine delimiter and length
    delimiter = COMMA
    length_str = bracket_content

    if endswith(bracket_content, TAB)
        delimiter = TAB
        length_str = bracket_content[1:end-1]
    elseif endswith(bracket_content, PIPE)
        delimiter = PIPE
        length_str = bracket_content[1:end-1]
    end

    # Parse length
    arr_length = tryparse(Int, length_str)
    if arr_length === nothing || arr_length < 0
        error("Invalid array length in header")
    end

    # Look for fields segment
    fields = nothing
    remainder = strip(content[bracket_end+1:end])

    if startswith(remainder, '{')
        brace_end = findfirst('}', remainder)
        if brace_end === nothing
            error("Unterminated fields segment in array header")
        end

        fields_content = remainder[2:brace_end-1]
        fields = parse_delimited_values(fields_content, delimiter)

        # Unescape quoted field names
        fields = [parse_key(f) for f in fields]

        remainder = strip(remainder[brace_end+1:end])
    end

    # Check for colon
    if !startswith(remainder, COLON)
        # If we got this far, it looks like an array header but is missing the colon
        # This is a syntax error, not just "not an array header"
        error("Array header must end with colon (line contains bracket syntax but no colon)")
    end

    return ArrayHeaderInfo(key, arr_length, delimiter, fields)
end

"""
    parse_key(token::AbstractString) -> String

Parse a key (quoted or unquoted) and return the unescaped string.
"""
function parse_key(token::AbstractString)::String
    token = strip(token)

    if startswith(token, DOUBLE_QUOTE)
        if !endswith(token, DOUBLE_QUOTE) || length(token) < 2
            error("Unterminated quoted key")
        end
        return unescape_string(token[2:end-1])
    end

    return token
end
