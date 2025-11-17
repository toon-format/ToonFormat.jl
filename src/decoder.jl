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

Root form detection (§5):
- Root array: first depth-0 line is valid array header with colon
- Single primitive: exactly one non-empty line, not array header, not key-value
- Object: default case
- Empty document: no non-empty lines → empty object
"""
function decode_value_from_lines(cursor::LineCursor, options::DecodeOptions)::JsonValue
    if !has_more_lines(cursor)
        return JsonObject()  # Empty object
    end

    # Check for root form
    first_line = peek_line(cursor)
    if first_line === nothing
        return JsonObject()
    end

    # Root array detection: first depth-0 line is valid array header with colon
    if first_line.depth == 0
        header = try
            parse_array_header(first_line.content)
        catch
            nothing
        end

        if header !== nothing && header.key === nothing
            # Valid root array header found
            return decode_array(cursor, options, header)
        end
    end

    # Single primitive detection: exactly one non-empty line, not array header, not key-value
    if length(cursor.lines) == 1 && first_line.depth == 0
        content = first_line.content

        # Check if it's a key-value line (has unquoted colon)
        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            # No colon found - check for common errors in strict mode
            if options.strict
                # Check if it looks like an array header without colon
                # Only check if it's not a quoted string
                if !startswith(content, DOUBLE_QUOTE) && occursin('[', content) && occursin(']', content)
                    # Try to parse as array header to see if it's valid
                    try
                        test_header = parse_array_header(content)
                        if test_header !== nothing
                            error("Missing colon after array header at line $(first_line.lineNumber)")
                        end
                    catch e
                        # If the error is about missing colon, re-throw it
                        if isa(e, ErrorException) && occursin("colon", e.msg)
                            error("Missing colon after array header at line $(first_line.lineNumber)")
                        end
                        # Otherwise, not a valid array header, ignore
                    end
                end
                
                # Check if it looks like a key without colon (has spaces but not quoted)
                if occursin(' ', content) && 
                   !startswith(content, DOUBLE_QUOTE) && 
                   !is_boolean_or_null_literal(content) &&
                   !is_numeric_literal(content)
                    error("Missing colon after key at line $(first_line.lineNumber)")
                end
            end
            
            # Single primitive value
            return parse_primitive(content)
        end
    end

    # Multi-primitive validation: in strict mode, error if multiple depth-0 lines without colons
    # that are not list items or array headers
    if options.strict && length(cursor.lines) > 1
        # Count depth-0 lines that are actual primitives (not list items, not key-value, not array headers)
        primitive_count = 0
        for line in cursor.lines
            if line.depth == 0
                content = line.content
                colon_pos = find_first_unquoted(content, ':')
                
                # Skip if it has a colon (key-value or array header)
                if colon_pos !== nothing
                    continue
                end
                
                # Skip if it's a list item marker
                if startswith(content, LIST_ITEM_MARKER)
                    continue
                end
                
                # Skip if it looks like an array header (even without colon - will error elsewhere)
                if occursin('[', content) && occursin(']', content)
                    continue
                end
                
                # This is a primitive
                primitive_count += 1
            end
        end
        
        if primitive_count > 1
            error("Multiple primitive values at root level are not allowed (found $primitive_count primitives)")
        end
    end

    # Default: decode as object
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
        # But first check if we're overwriting an object in strict mode
        if options.strict && haskey(result, key) && isa(result[key], JsonObject) && !isa(value, JsonObject)
            error("Cannot set key '$key': key already exists as object")
        end
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
            # In non-strict mode, overwrite with new object
            current[segment_str] = JsonObject()
        end
        current = current[segment_str]
    end

    # Set the final value
    final_key = String(segments[end])
    # Check if final key already exists as an object and we're trying to set a primitive
    if haskey(current, final_key) && isa(current[final_key], JsonObject) && !isa(value, JsonObject)
        if options.strict
            error("Cannot expand path '$key': segment '$final_key' already exists as object")
        end
    end
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

        # Check if at expected child depth
        expected_depth = parent_depth + 1
        
        # In strict mode, require exact depth match
        if options.strict && line.depth != expected_depth
            advance_line!(cursor)
            continue
        end
        
        # In non-strict mode, if we're at root and see unexpected depth, process it anyway
        # This handles cases like "   value: 1" with indent=2 (depth=1 instead of 0)
        if !options.strict && parent_depth == -1 && line.depth > expected_depth
            # Process it as if it were at the expected depth
            # Continue processing
        elseif !options.strict && line.depth > expected_depth
            # Skip lines that are too deep
            advance_line!(cursor)
            continue
        end

        # Parse key-value pair
        content = line.content

        # Find colon
        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            if options.strict
                error("Missing colon after key at line $(line.lineNumber)")
            else
                # In non-strict mode, skip the line
                advance_line!(cursor)
                continue
            end
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
                    value = JsonObject()
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
        
        # Validate that we have the right number of tokens for the declared rows
        expected_tokens = header.length * num_fields
        if options.strict && length(tokens) != expected_tokens
            error("Array length mismatch: expected $(header.length) rows ($(expected_tokens) values), got $(div(length(tokens), num_fields)) rows ($(length(tokens)) values)")
        end
        
        # Build rows from tokens
        num_rows = div(length(tokens), num_fields)
        for i in 1:num_rows
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
        
        # Validate count in strict mode
        if options.strict && length(result) != header.length
            error("Array length mismatch: expected $(header.length), got $(length(result))")
        end
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
    start_position = cursor.position

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
        # Also treat lines without colons as rows (they might have missing fields)
        is_row = false
        if colon_pos === nothing
            # No colon, so it's a row (even if no delimiter)
            is_row = true
        elseif delimiter_pos !== nothing && delimiter_pos < colon_pos
            # Delimiter comes before colon, so it's a row
            is_row = true
        end

        if !is_row
            break
        end

        # Parse row
        tokens = parse_delimited_values(content, header.delimiter)
        
        # Validate row width in strict mode
        if options.strict && length(tokens) != length(fields)
            error("Row width mismatch at line $(line.lineNumber): expected $(length(fields)) fields, got $(length(tokens))")
        end
        
        row = JsonObject()

        for (i, field) in enumerate(fields)
            if i <= length(tokens)
                row[field] = parse_primitive(strip(tokens[i]))
            else
                row[field] = ""  # Missing value
            end
        end

        push!(result, row)
        row_count += 1
        advance_line!(cursor)
    end

    # Check for blank lines inside the array in strict mode
    if options.strict && header.length > 0
        # Get the line number of the header (one before start_position)
        header_line_num = if start_position > 1
            cursor.lines[start_position - 1].lineNumber
        else
            0
        end
        
        # Get the line number of the last row we processed
        last_row_line_num = if cursor.position > 1 && cursor.position - 1 <= length(cursor.lines)
            cursor.lines[cursor.position - 1].lineNumber
        else
            typemax(Int)
        end
        
        for blank in cursor.blankLines
            # Blank line is inside the array if it's after the header and before/at the last row
            if blank.lineNumber > header_line_num && blank.lineNumber <= last_row_line_num
                error("Blank lines are not allowed inside tabular arrays (line $(blank.lineNumber))")
            end
        end
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
    start_position = cursor.position

    while has_more_lines(cursor)
        line = peek_line(cursor)

        # Check if line starts with list marker (either "- " or just "-")
        if !startswith(line.content, "-")
            break
        end

        # Parse list item
        # Handle both "- " (with content) and "-" (empty object)
        if line.content == "-"
            # Empty object - just "-"
            after_marker = ""
        elseif startswith(line.content, LIST_ITEM_MARKER)
            # Normal list item with "- "
            after_marker = String(strip(line.content[length(LIST_ITEM_MARKER)+1:end]))
        else
            # Not a list item (e.g., "-5" or "-abc")
            break
        end

        # Check what kind of item it is
        if isempty(after_marker)
            # Could be empty object or object with fields at depth +1
            hyphen_line_depth = line.depth
            advance_line!(cursor)
            
            # Check if there are fields at depth +1
            next_line = peek_line(cursor)
            if next_line !== nothing && next_line.depth == hyphen_line_depth + 1 && !startswith(next_line.content, "-")
                # Object with fields at depth +1
                obj = decode_object(cursor, hyphen_line_depth, options)
                push!(result, obj)
            else
                # Empty object
                push!(result, JsonObject())
            end
        else
            # Try to parse as array header
            item_header = try
                parse_array_header(after_marker)
            catch
                nothing
            end

            if item_header !== nothing
                # Array item - the header was parsed from after_marker
                # Now we need to check if there's inline data
                # Find where the header ends (after the colon)
                colon_pos = find_first_unquoted(after_marker, ':')
                if colon_pos !== nothing
                    after_colon = strip(after_marker[colon_pos+1:end])
                    if !isempty(after_colon)
                        # Inline array data
                        advance_line!(cursor)
                        array_value = decode_inline_array_data(after_colon, item_header, options)
                        push!(result, array_value)
                    else
                        # Multiline array (data on subsequent lines)
                        advance_line!(cursor)
                        array_value = decode_multiline_array_data(cursor, item_header, options)
                        push!(result, array_value)
                    end
                else
                    # No colon found - shouldn't happen for valid array header
                    advance_line!(cursor)
                    push!(result, [])
                end
            else
                # Check for key-value
                colon_pos = find_first_unquoted(after_marker, ':')

                if colon_pos !== nothing
                    # Object item with first field on hyphen line
                    key_str = strip(after_marker[1:colon_pos-1])
                    value_str = strip(after_marker[colon_pos+1:end])
                    
                    first_key = parse_key(key_str)
                    hyphen_line_depth = line.depth
                    
                    advance_line!(cursor)
                    
                    obj = JsonObject()
                    
                    # Parse the first field value
                    if !isempty(value_str)
                        # Primitive value on hyphen line
                        obj[first_key] = parse_primitive(value_str)
                    else
                        # Nested object or array - check next line
                        next_line = peek_line(cursor)
                        
                        if next_line !== nothing && next_line.depth == hyphen_line_depth + 2
                            # Nested object at depth +2
                            obj[first_key] = decode_object(cursor, hyphen_line_depth + 1, options)
                        else
                            # Empty value
                            obj[first_key] = JsonObject()
                        end
                    end
                    
                    # Parse remaining fields at depth +1
                    while has_more_lines(cursor)
                        next_line = peek_line(cursor)
                        
                        # Remaining fields should be at depth +1 relative to hyphen
                        if next_line.depth != hyphen_line_depth + 1
                            break
                        end
                        
                        # Check if it's a list item marker (next item in array)
                        if startswith(next_line.content, LIST_ITEM_MARKER)
                            break
                        end
                        
                        # Parse key-value pair
                        field_colon_pos = find_first_unquoted(next_line.content, ':')
                        if field_colon_pos === nothing
                            if options.strict
                                error("Missing colon after key at line $(next_line.lineNumber)")
                            end
                            advance_line!(cursor)
                            continue
                        end
                        
                        field_key_str = strip(next_line.content[1:field_colon_pos-1])
                        field_value_str = strip(next_line.content[field_colon_pos+1:end])
                        
                        # Check if the key contains an array header
                        field_header = try
                            parse_array_header(field_key_str * ":")
                        catch
                            nothing
                        end
                        
                        if field_header !== nothing && field_header.key !== nothing
                            # Key contains array syntax like "tags[2]:"
                            field_key = field_header.key
                            advance_line!(cursor)
                            
                            if !isempty(field_value_str)
                                # Inline array data
                                obj[field_key] = decode_inline_array_data(field_value_str, field_header, options)
                            else
                                # Multiline array data
                                obj[field_key] = decode_multiline_array_data(cursor, field_header, options)
                            end
                        else
                            # Regular key-value pair
                            field_key = parse_key(field_key_str)
                            advance_line!(cursor)
                            
                            if !isempty(field_value_str)
                                # Primitive value
                                obj[field_key] = parse_primitive(field_value_str)
                            else
                                # Nested object or array
                                nested_line = peek_line(cursor)
                                
                                if nested_line !== nothing && nested_line.depth > hyphen_line_depth + 1
                                    # Check if it's an array header
                                    nested_header = try
                                        parse_array_header(nested_line.content)
                                    catch
                                        nothing
                                    end
                                    
                                    if nested_header !== nothing
                                        # Array value
                                        obj[field_key] = decode_array(cursor, options, nested_header)
                                    else
                                        # Nested object
                                        obj[field_key] = decode_object(cursor, hyphen_line_depth + 1, options)
                                    end
                                else
                                    # Empty value
                                    obj[field_key] = JsonObject()
                                end
                            end
                        end
                    end
                    
                    push!(result, obj)
                else
                    # Primitive item
                    push!(result, parse_primitive(after_marker))
                    advance_line!(cursor)
                end
            end
        end

        item_count += 1
    end

    # Check for blank lines inside the array in strict mode
    if options.strict && header.length > 0
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
            # We use <= for the upper bound to catch blank lines between items
            if blank.lineNumber > header_line_num && blank.lineNumber <= last_item_line_num
                error("Blank lines are not allowed inside list arrays (line $(blank.lineNumber))")
            end
        end
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
        return JsonObject()
    end

    cursor = LineCursor(scan_result.lines, scan_result.blankLines)
    return decode_value_from_lines(cursor, options)
end
