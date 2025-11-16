# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Main TOON decoder implementation.
"""

"""
    parse_primitive(token::AbstractString) -> JsonValue

Parse a primitive token into a value.
"""
function parse_primitive(token::AbstractString)::JsonValue
    token = String(strip(token))

    # Empty token -> empty string
    if isempty(token)
        return ""
    end

    # Quoted string
    if startswith(token, DOUBLE_QUOTE)
        if !endswith(token, DOUBLE_QUOTE) || length(token) < 2
            error("Unterminated string: missing closing quote")
        end
        return unescape_string(token[2:end-1])
    end

    # Boolean and null literals
    if is_boolean_or_null_literal(token)
        if token == TRUE_LITERAL
            return true
        elseif token == FALSE_LITERAL
            return false
        else  # NULL_LITERAL
            return nothing
        end
    end

    # Numeric literals
    if is_numeric_literal(token)
        # Check for forbidden leading zeros
        if has_leading_zeros(token)
            return String(token)  # Treat as string
        end

        # Try to parse as number
        try
            if !occursin('.', token) && !occursin('e', lowercase(token))
                return parse(Int, token)
            else
                return parse(Float64, token)
            end
        catch
            # Fall through to string
        end
    end

    # Default: treat as string
    return String(token)
end

"""
    decode_value_from_lines(cursor::LineCursor, options::DecodeOptions) -> JsonValue

Decode a value from the line cursor.
"""
function decode_value_from_lines(cursor::LineCursor, options::DecodeOptions)::JsonValue
    if !has_more_lines(cursor)
        return Dict{String, Any}()  # Empty object
    end

    # Check for root form
    first_line = peek_line(cursor)
    if first_line === nothing
        return Dict{String, Any}()
    end

    # Try to parse as root array header
    header = try
        parse_array_header(first_line.content)
    catch
        nothing
    end

    if header !== nothing && header.key === nothing
        # Root array
        return decode_array(cursor, options, header)
    end

    # Check if single primitive
    if length(cursor.lines) == 1 && first_line.depth == 0
        content = first_line.content

        # Check if it's a key-value line
        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            # Single primitive
            return parse_primitive(content)
        end
    end

    # Otherwise, decode as object
    return decode_object(cursor, -1, options)
end

"""
    expand_dotted_key(result::JsonObject, key::String, value::JsonValue, options::DecodeOptions)

Expand a dotted key into nested objects if expandPaths is enabled.
For example, "a.b.c" with value "x" becomes {"a": {"b": {"c": "x"}}}
"""
function expand_dotted_key(result::JsonObject, key::String, value::JsonValue, options::DecodeOptions)
    # Check if we should expand this key
    should_expand = options.expandPaths == "safe" &&
                    occursin('.', key) &&
                    all(is_safe_identifier, split(key, '.'))

    if !should_expand
        # No expansion needed - just set the key
        result[key] = value
        return
    end

    # Split the key into segments
    segments = split(key, '.')

    # Navigate/create nested structure
    current = result
    for (i, segment) in enumerate(segments[1:end-1])
        segment_str = String(segment)
        if !haskey(current, segment_str)
            # Create new nested object
            current[segment_str] = JsonObject()
        elseif !isa(current[segment_str], JsonObject)
            # Key already exists but is not an object - error in strict mode
            if options.strict
                error("Cannot expand path '$key': segment '$segment_str' already exists as non-object")
            end
            return
        end
        current = current[segment_str]
    end

    # Set the final value
    final_key = String(segments[end])
    current[final_key] = value
end

"""
    decode_object(cursor::LineCursor, parent_depth::Int, options::DecodeOptions) -> JsonObject

Decode an object from the cursor.
"""
function decode_object(cursor::LineCursor, parent_depth::Int, options::DecodeOptions)::JsonObject
    result = JsonObject()

    while has_more_lines(cursor)
        line = peek_line(cursor)

        # Stop if we've moved to a shallower or equal depth (sibling or parent)
        if line.depth <= parent_depth
            break
        end

        # Skip if not at the expected child depth
        if line.depth != parent_depth + 1
            advance_line!(cursor)
            continue
        end

        # Parse key-value pair
        content = line.content

        # Find colon
        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            error("Missing colon after key (line $(line.lineNumber))")
        end

        key_str = strip(content[1:colon_pos-1])
        value_str = strip(content[colon_pos+1:end])

        # Check if the key contains an array header
        array_header = try
            parse_array_header(key_str * ":")
        catch
            nothing
        end

        if array_header !== nothing && array_header.key !== nothing
            # Key contains array syntax like "items[3]:" or "users[2]{name,age}:"
            key = array_header.key
            advance_line!(cursor)

            if !isempty(value_str)
                # Inline array data on the same line
                value = decode_inline_array_data(value_str, array_header, options)
            else
                # Array data on subsequent lines
                value = decode_multiline_array_data(cursor, array_header, options)
            end
        else
            # Regular key-value pair
            key = parse_key(key_str)
            advance_line!(cursor)

            # Determine value type
            if !isempty(value_str)
                # Primitive value on same line
                value = parse_primitive(value_str)
            else
                # Value on next line(s) - nested object
                next_line = peek_line(cursor)

                if next_line !== nothing && next_line.depth > line.depth
                    # Nested object
                    value = decode_object(cursor, line.depth, options)
                else
                    # Empty object or value
                    value = Dict{String, Any}()
                end
            end
        end

        # Use expand_dotted_key to handle path expansion
        expand_dotted_key(result, key, value, options)
    end

    return result
end

"""
    decode_inline_array_data(data_str::AbstractString, header::ArrayHeaderInfo, options::DecodeOptions) -> JsonArray

Decode inline array data (all on one line after the colon).
"""
function decode_inline_array_data(data_str::AbstractString, header::ArrayHeaderInfo, options::DecodeOptions)::JsonArray
    result = JsonArray()
    tokens = parse_delimited_values(data_str, header.delimiter)

    if header.fields !== nothing
        # Inline tabular array - values are row-major
        num_fields = length(header.fields)
        for i in 1:header.length
            row = JsonObject()
            for (j, field) in enumerate(header.fields)
                idx = (i-1) * num_fields + j
                if idx <= length(tokens)
                    row[field] = parse_primitive(strip(tokens[idx]))
                else
                    row[field] = ""  # Missing value
                end
            end
            push!(result, row)
        end
    else
        # Inline primitive array
        for token in tokens
            push!(result, parse_primitive(strip(token)))
        end
    end

    # Validate count in strict mode
    if options.strict && length(result) != header.length
        error("Array length mismatch: expected $(header.length), got $(length(result))")
    end

    return result
end

"""
    decode_multiline_array_data(cursor::LineCursor, header::ArrayHeaderInfo, options::DecodeOptions) -> JsonArray

Decode array data that appears on subsequent lines.
"""
function decode_multiline_array_data(cursor::LineCursor, header::ArrayHeaderInfo, options::DecodeOptions)::JsonArray
    if header.fields !== nothing
        # Tabular format - rows on subsequent lines
        return decode_tabular_array(cursor, options, header)
    else
        # List format - items on subsequent lines
        return decode_list_array(cursor, options, header)
    end
end

"""
    decode_array(cursor::LineCursor, options::DecodeOptions, header::ArrayHeaderInfo) -> JsonArray

Decode an array from the cursor using the parsed header.
"""
function decode_array(cursor::LineCursor, options::DecodeOptions, header::ArrayHeaderInfo)::JsonArray
    result = JsonArray()

    # Get the header line
    if has_more_lines(cursor)
        header_line = peek_line(cursor)
        header_content = header_line.content

        # Check if there are inline values after the colon
        colon_pos = find_first_unquoted(header_content, ':')
        if colon_pos !== nothing && colon_pos < length(header_content)
            after_colon = strip(header_content[colon_pos+1:end])

            if !isempty(after_colon)
                # Inline array (primitive or tabular)
                tokens = parse_delimited_values(after_colon, header.delimiter)

                if header.fields !== nothing
                    # Inline tabular array - values are row-major
                    num_fields = length(header.fields)
                    for i in 1:header.length
                        row = JsonObject()
                        for (j, field) in enumerate(header.fields)
                            idx = (i-1) * num_fields + j
                            if idx <= length(tokens)
                                row[field] = parse_primitive(strip(tokens[idx]))
                            else
                                row[field] = ""  # Missing value
                            end
                        end
                        push!(result, row)
                    end
                else
                    # Inline primitive array
                    for token in tokens
                        push!(result, parse_primitive(strip(token)))
                    end
                end

                # Validate count in strict mode
                if options.strict && length(result) != header.length
                    error("Array length mismatch: expected $(header.length), got $(length(result))")
                end

                advance_line!(cursor)
                return result
            end
        end

        advance_line!(cursor)
    end

    # Check for tabular or list format
    if header.fields !== nothing
        # Tabular format
        return decode_tabular_array(cursor, options, header)
    else
        # List format
        return decode_list_array(cursor, options, header)
    end
end

"""
    decode_tabular_array(cursor::LineCursor, options::DecodeOptions,
                        header::ArrayHeaderInfo) -> JsonArray

Decode a tabular array.
"""
function decode_tabular_array(cursor::LineCursor, options::DecodeOptions,
                             header::ArrayHeaderInfo)::JsonArray
    result = JsonArray()
    fields = header.fields

    if fields === nothing
        error("Tabular array must have fields")
    end

    row_count = 0

    while has_more_lines(cursor)
        line = peek_line(cursor)

        # Check if we're still in the array scope
        # Rows should be at depth > header depth
        # TODO: proper depth tracking

        # For now, assume rows are indented
        if line.depth == 0
            break
        end

        content = line.content

        # Check if it's a row or a key-value line
        delimiter_pos = find_first_unquoted(content, header.delimiter[1])
        colon_pos = find_first_unquoted(content, ':')

        # Disambiguate: if delimiter comes before colon, it's a row
        is_row = false
        if delimiter_pos !== nothing && colon_pos === nothing
            is_row = true
        elseif delimiter_pos !== nothing && colon_pos !== nothing && delimiter_pos < colon_pos
            is_row = true
        end

        if !is_row
            break
        end

        # Parse row
        tokens = parse_delimited_values(content, header.delimiter)
        row = JsonObject()

        for (i, field) in enumerate(fields)
            if i <= length(tokens)
                row[field] = parse_primitive(strip(tokens[i]))
            else
                row[field] = ""  # Missing value
            end
        end

        # Validate row width in strict mode
        if options.strict && length(tokens) != length(fields)
            error("Row width mismatch: expected $(length(fields)), got $(length(tokens))")
        end

        push!(result, row)
        row_count += 1
        advance_line!(cursor)
    end

    # Validate count in strict mode
    if options.strict && row_count != header.length
        error("Array length mismatch: expected $(header.length), got $(row_count)")
    end

    return result
end

"""
    decode_list_array(cursor::LineCursor, options::DecodeOptions,
                     header::ArrayHeaderInfo) -> JsonArray

Decode an expanded list array.
"""
function decode_list_array(cursor::LineCursor, options::DecodeOptions,
                          header::ArrayHeaderInfo)::JsonArray
    result = JsonArray()
    item_count = 0

    while has_more_lines(cursor)
        line = peek_line(cursor)

        # Check if line starts with list marker
        if !startswith(line.content, LIST_ITEM_MARKER)
            break
        end

        # Parse list item
        after_marker = strip(line.content[length(LIST_ITEM_MARKER)+1:end])

        # Check what kind of item it is
        if isempty(after_marker)
            # Empty object
            push!(result, Dict{String, Any}())
        else
            # Try to parse as array header
            item_header = try
                parse_array_header(after_marker)
            catch
                nothing
            end

            if item_header !== nothing
                # Inline array item
                advance_line!(cursor)
                push!(result, decode_array(cursor, options, item_header))
            else
                # Check for key-value
                colon_pos = find_first_unquoted(after_marker, ':')

                if colon_pos !== nothing
                    # Object item
                    advance_line!(cursor)
                    # TODO: implement object as list item parsing
                    push!(result, Dict{String, Any}())
                else
                    # Primitive item
                    push!(result, parse_primitive(after_marker))
                    advance_line!(cursor)
                end
            end
        end

        item_count += 1
    end

    # Validate count in strict mode
    if options.strict && item_count != header.length
        error("Array length mismatch: expected $(header.length), got $(item_count)")
    end

    return result
end

"""
    decode(input::String; options::DecodeOptions=DecodeOptions()) -> JsonValue

Main decoding function. Converts a TOON format string to a Julia value.

# Arguments
- `input`: TOON formatted string
- `options`: Decoding options (indent, strict, etc.)

# Returns
- Parsed Julia value (Dict, Array, or primitive)

# Examples
```julia
decode("name: Alice\\nage: 30")
# Dict("name" => "Alice", "age" => 30)

decode("[2]: 1,2")
# [1, 2]
```
"""
function decode(input::String; options::DecodeOptions=DecodeOptions())::JsonValue
    scan_result = to_parsed_lines(input, options.indent, options.strict)

    if isempty(scan_result.lines)
        return Dict{String, Any}()
    end

    cursor = LineCursor(scan_result.lines, scan_result.blankLines)
    return decode_value_from_lines(cursor, options)
end
