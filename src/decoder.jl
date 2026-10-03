function parse_primitive(token::AbstractString)::JsonValue
    token = String(strip(token))

    if isempty(token)
        return ""
    end

    if startswith(token, DOUBLE_QUOTE)
        if !endswith(token, DOUBLE_QUOTE) || length(token) < 2
            error("Unterminated string: missing closing quote")
        end
        return unescape_string(chop(token; head = 1, tail = 1))
    end

    if is_boolean_or_null_literal(token)
        if token == TRUE_LITERAL
            return true
        elseif token == FALSE_LITERAL
            return false
        else
            return nothing
        end
    end

    if is_numeric_literal(token)
        if has_leading_zeros(token)
            return String(token)
        end

        try
            if !occursin('.', token) && !occursin('e', lowercase(token))
                return parse(Int, token)
            else
                return parse(Float64, token)
            end
        catch
            # Out-of-range numbers fall through to a string.
        end
    end

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
        return JsonObject()
    end

    first_line = peek_line(cursor)
    if first_line === nothing
        return JsonObject()
    end

    if first_line.depth == 0
        header = try
            parse_array_header(first_line.content)
        catch
            nothing
        end

        if header !== nothing && header.key === nothing
            return decode_array(cursor, options, header)
        end
    end

    if length(cursor.lines) == 1 && first_line.depth == 0
        content = first_line.content

        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            if options.strict
                if !startswith(content, DOUBLE_QUOTE) &&
                   occursin('[', content) &&
                   occursin(']', content)
                    try
                        test_header = parse_array_header(content)
                        if test_header !== nothing
                            error(
                                "Missing colon after array header at line $(first_line.lineNumber)",
                            )
                        end
                    catch e
                        if isa(e, ErrorException) && occursin("colon", e.msg)
                            error(
                                "Missing colon after array header at line $(first_line.lineNumber)",
                            )
                        end
                    end
                end

                # A spaced line without a colon is a missing colon, unless non-ASCII characters or several spaces mark it as text.
                if occursin(' ', content) &&
                   !startswith(content, DOUBLE_QUOTE) &&
                   !is_boolean_or_null_literal(content) &&
                   !is_numeric_literal(content)
                    has_non_ascii = any(c -> !isascii(c), content)
                    has_multiple_spaces = count(==(' '), content) >= 2

                    if !has_non_ascii && !has_multiple_spaces
                        error("Missing colon after key at line $(first_line.lineNumber)")
                    end
                end
            end

            return parse_primitive(content)
        end
    end

    # Strict mode rejects more than one bare primitive at the root.
    if options.strict && length(cursor.lines) > 1
        primitive_count = 0
        for line in cursor.lines
            if line.depth == 0
                content = line.content
                colon_pos = find_first_unquoted(content, ':')

                if colon_pos !== nothing
                    continue
                end

                if startswith(content, LIST_ITEM_MARKER)
                    continue
                end

                # A header missing its colon raises its own error.
                if occursin('[', content) && occursin(']', content)
                    continue
                end

                primitive_count += 1
            end
        end

        if primitive_count > 1
            error(
                "Multiple primitive values at root level are not allowed (found $primitive_count primitives)",
            )
        end
    end

    return decode_object(cursor, -1, options)
end

"""
    expand_dotted_key(result::JsonObject, key::String, value::JsonValue, options::DecodeOptions, was_quoted::Bool=false)

Expand a dotted key into nested objects if expandPaths is enabled.
For example, "a.b.c" with value "x" becomes {"a": {"b": {"c": "x"}}}
If was_quoted is true, the key will not be expanded even if it contains dots.
"""
function expand_dotted_key(
    result::JsonObject,
    key::String,
    value::JsonValue,
    options::DecodeOptions,
    was_quoted::Bool = false,
)
    should_expand =
        options.expandPaths == "safe" &&
        !was_quoted &&
        occursin('.', key) &&
        all(is_safe_identifier, split(key, '.'))

    if !should_expand
        if options.strict &&
           haskey(result, key) &&
           isa(result[key], JsonObject) &&
           !isa(value, JsonObject)
            error("Cannot set key '$key': key already exists as object")
        end
        result[key] = value
        return
    end

    segments = split(key, '.')

    current = result
    for (i, segment) in enumerate(segments[1:(end-1)])
        segment_str = String(segment)
        if !haskey(current, segment_str)
            current[segment_str] = JsonObject()
        elseif !isa(current[segment_str], JsonObject)
            if options.strict
                error(
                    "Cannot expand path '$key': segment '$segment_str' already exists as non-object",
                )
            end
            current[segment_str] = JsonObject()
        end
        current = current[segment_str]
    end

    final_key = String(segments[end])
    if haskey(current, final_key) &&
       isa(current[final_key], JsonObject) &&
       !isa(value, JsonObject)
        if options.strict
            error(
                "Cannot expand path '$key': segment '$final_key' already exists as object",
            )
        end
    end
    current[final_key] = value
end

function decode_object(
    cursor::LineCursor,
    parent_depth::Int,
    options::DecodeOptions,
)::JsonObject
    result = JsonObject()

    while has_more_lines(cursor)
        line = peek_line(cursor)

        if line.depth <= parent_depth
            break
        end

        expected_depth = parent_depth + 1

        if options.strict && line.depth != expected_depth
            advance_line!(cursor)
            continue
        end

        # Non-strict mode decodes an over-indented root line (e.g. `   value: 1` with indent 2) as if at depth 0.
        if !options.strict && parent_depth == -1 && line.depth > expected_depth
        elseif !options.strict && line.depth > expected_depth
            advance_line!(cursor)
            continue
        end

        content = line.content

        colon_pos = find_first_unquoted(content, ':')
        if colon_pos === nothing
            if options.strict
                error("Missing colon after key at line $(line.lineNumber)")
            else
                advance_line!(cursor)
                continue
            end
        end

        key_str = strip(content[1:prevind(content, colon_pos)])
        value_str = strip(content[(colon_pos+1):end])

        array_header = try
            parse_array_header(key_str * ":")
        catch
            nothing
        end

        was_quoted = startswith(strip(key_str), DOUBLE_QUOTE)

        if array_header !== nothing && array_header.key !== nothing
            key = array_header.key
            advance_line!(cursor)

            if !isempty(value_str)
                value = decode_inline_array_data(value_str, array_header, options)
            else
                value = decode_multiline_array_data(cursor, array_header, options)
            end
        else
            key = parse_key(key_str)
            advance_line!(cursor)

            if !isempty(value_str)
                value = parse_primitive(value_str)
            else
                next_line = peek_line(cursor)

                if next_line !== nothing && next_line.depth > line.depth
                    value = decode_object(cursor, line.depth, options)
                else
                    value = JsonObject()
                end
            end
        end

        expand_dotted_key(result, key, value, options, was_quoted)
    end

    return result
end

function decode_inline_array_data(
    data_str::AbstractString,
    header::ArrayHeaderInfo,
    options::DecodeOptions,
)::JsonArray
    result = JsonArray()
    tokens = parse_delimited_values(data_str, header.delimiter)

    if header.fields !== nothing
        # Inline tabular values are row-major.
        num_fields = length(header.fields)

        expected_tokens = header.length * num_fields
        if options.strict && length(tokens) != expected_tokens
            error(
                "Array length mismatch: expected $(header.length) rows ($(expected_tokens) values), got $(div(length(tokens), num_fields)) rows ($(length(tokens)) values)",
            )
        end

        num_rows = div(length(tokens), num_fields)
        for i = 1:num_rows
            row = JsonObject()
            for (j, field) in enumerate(header.fields)
                idx = (i-1) * num_fields + j
                if idx <= length(tokens)
                    row[field] = parse_primitive(strip(tokens[idx]))
                else
                    row[field] = ""
                end
            end
            push!(result, row)
        end
    else
        for token in tokens
            push!(result, parse_primitive(strip(token)))
        end

        if options.strict && length(result) != header.length
            error("Array length mismatch: expected $(header.length), got $(length(result))")
        end
    end

    return result
end

function decode_multiline_array_data(
    cursor::LineCursor,
    header::ArrayHeaderInfo,
    options::DecodeOptions,
)::JsonArray
    if header.fields !== nothing
        return decode_tabular_array(cursor, options, header)
    else
        return decode_list_array(cursor, options, header)
    end
end

function decode_array(
    cursor::LineCursor,
    options::DecodeOptions,
    header::ArrayHeaderInfo,
)::JsonArray
    result = JsonArray()

    if has_more_lines(cursor)
        header_line = peek_line(cursor)
        header_content = header_line.content

        colon_pos = find_first_unquoted(header_content, ':')
        if colon_pos !== nothing
            after_colon = strip(header_content[(colon_pos+1):end])

            if !isempty(after_colon)
                tokens = parse_delimited_values(after_colon, header.delimiter)

                if header.fields !== nothing
                    # Inline tabular values are row-major.
                    num_fields = length(header.fields)
                    for i = 1:header.length
                        row = JsonObject()
                        for (j, field) in enumerate(header.fields)
                            idx = (i-1) * num_fields + j
                            if idx <= length(tokens)
                                row[field] = parse_primitive(strip(tokens[idx]))
                            else
                                row[field] = ""
                            end
                        end
                        push!(result, row)
                    end
                else
                    for token in tokens
                        push!(result, parse_primitive(strip(token)))
                    end
                end

                if options.strict && length(result) != header.length
                    error(
                        "Array length mismatch: expected $(header.length), got $(length(result))",
                    )
                end

                advance_line!(cursor)
                return result
            end
        end

        advance_line!(cursor)
    end

    if header.fields !== nothing
        return decode_tabular_array(cursor, options, header)
    else
        return decode_list_array(cursor, options, header)
    end
end

function decode_tabular_array(
    cursor::LineCursor,
    options::DecodeOptions,
    header::ArrayHeaderInfo,
)::JsonArray
    result = JsonArray()
    fields = header.fields

    if fields === nothing
        error("Tabular array must have fields")
    end

    row_count = 0
    start_position = cursor.position

    while has_more_lines(cursor)
        line = peek_line(cursor)

        # TODO: Stop at the header's depth instead of only at depth 0.
        if line.depth == 0
            break
        end

        content = line.content

        delimiter_pos = find_first_unquoted(content, header.delimiter[1])
        colon_pos = find_first_unquoted(content, ':')

        # A line is a row when it has no colon or a delimiter before its colon.
        is_row = false
        if colon_pos === nothing
            is_row = true
        elseif delimiter_pos !== nothing && delimiter_pos < colon_pos
            is_row = true
        end

        if !is_row
            break
        end

        tokens = parse_delimited_values(content, header.delimiter)

        if options.strict && length(tokens) != length(fields)
            error(
                "Row width mismatch at line $(line.lineNumber): expected $(length(fields)) fields, got $(length(tokens))",
            )
        end

        row = JsonObject()

        for (i, field) in enumerate(fields)
            if i <= length(tokens)
                row[field] = parse_primitive(strip(tokens[i]))
            else
                row[field] = ""
            end
        end

        push!(result, row)
        row_count += 1
        advance_line!(cursor)
    end

    if options.strict && header.length > 0
        header_line_num = if start_position > 1
            cursor.lines[start_position-1].lineNumber
        else
            0
        end

        last_row_line_num =
            if cursor.position > 1 && cursor.position - 1 <= length(cursor.lines)
                cursor.lines[cursor.position-1].lineNumber
            else
                typemax(Int)
            end

        for blank in cursor.blankLines
            if blank.lineNumber > header_line_num && blank.lineNumber <= last_row_line_num
                error(
                    "Blank lines are not allowed inside tabular arrays (line $(blank.lineNumber))",
                )
            end
        end
    end

    if options.strict && row_count != header.length
        error("Array length mismatch: expected $(header.length), got $(row_count)")
    end

    return result
end

function decode_list_array(
    cursor::LineCursor,
    options::DecodeOptions,
    header::ArrayHeaderInfo,
)::JsonArray
    result = JsonArray()
    item_count = 0
    start_position = cursor.position

    while has_more_lines(cursor)
        line = peek_line(cursor)

        if !startswith(line.content, "-")
            break
        end

        if line.content == "-"
            after_marker = ""
        elseif startswith(line.content, LIST_ITEM_MARKER)
            after_marker = String(strip(line.content[(length(LIST_ITEM_MARKER)+1):end]))
        else
            # `-5` or `-abc` is not a list item.
            break
        end

        if isempty(after_marker)
            hyphen_line_depth = line.depth
            advance_line!(cursor)

            next_line = peek_line(cursor)
            if next_line !== nothing &&
               next_line.depth == hyphen_line_depth + 1 &&
               !startswith(next_line.content, "-")
                obj = decode_object(cursor, hyphen_line_depth, options)
                push!(result, obj)
            else
                push!(result, JsonObject())
            end
        else
            item_header = try
                parse_array_header(after_marker)
            catch
                nothing
            end

            if item_header !== nothing
                colon_pos = find_first_unquoted(after_marker, ':')

                if item_header.key !== nothing
                    # An array as the first field of an object, e.g. `- items[3]: 1,2,3`.
                    first_key = item_header.key
                    hyphen_line_depth = line.depth

                    if colon_pos !== nothing
                        after_colon = strip(after_marker[(colon_pos+1):end])
                        advance_line!(cursor)

                        next_line = peek_line(cursor)
                        has_additional_fields = (
                            next_line !== nothing &&
                            next_line.depth == hyphen_line_depth + 1 &&
                            !startswith(next_line.content, LIST_ITEM_MARKER)
                        )

                        if has_additional_fields
                            obj = JsonObject()

                            if !isempty(after_colon)
                                obj[first_key] = decode_inline_array_data(
                                    after_colon,
                                    item_header,
                                    options,
                                )
                            else
                                if item_header.length == 0
                                    obj[first_key] = []
                                else
                                    obj[first_key] = decode_multiline_array_data(
                                        cursor,
                                        item_header,
                                        options,
                                    )
                                end
                            end

                            while has_more_lines(cursor)
                                next_line = peek_line(cursor)

                                if next_line.depth != hyphen_line_depth + 1
                                    break
                                end

                                if startswith(next_line.content, LIST_ITEM_MARKER)
                                    break
                                end

                                field_colon_pos =
                                    find_first_unquoted(next_line.content, ':')
                                if field_colon_pos === nothing
                                    if options.strict
                                        error(
                                            "Missing colon after key at line $(next_line.lineNumber)",
                                        )
                                    end
                                    advance_line!(cursor)
                                    continue
                                end

                                field_key_str =
                                    strip(next_line.content[1:prevind(next_line.content, field_colon_pos)])
                                field_value_str =
                                    strip(next_line.content[(field_colon_pos+1):end])

                                field_header = try
                                    parse_array_header(field_key_str * ":")
                                catch
                                    nothing
                                end

                                if field_header !== nothing && field_header.key !== nothing
                                    field_key = field_header.key
                                    advance_line!(cursor)

                                    if !isempty(field_value_str)
                                        obj[field_key] = decode_inline_array_data(
                                            field_value_str,
                                            field_header,
                                            options,
                                        )
                                    else
                                        obj[field_key] = decode_multiline_array_data(
                                            cursor,
                                            field_header,
                                            options,
                                        )
                                    end
                                else
                                    field_key = parse_key(field_key_str)
                                    advance_line!(cursor)

                                    if !isempty(field_value_str)
                                        obj[field_key] = parse_primitive(field_value_str)
                                    else
                                        nested_line = peek_line(cursor)

                                        if nested_line !== nothing &&
                                           nested_line.depth > hyphen_line_depth + 1
                                            nested_header = try
                                                parse_array_header(nested_line.content)
                                            catch
                                                nothing
                                            end

                                            if nested_header !== nothing
                                                obj[field_key] = decode_array(
                                                    cursor,
                                                    options,
                                                    nested_header,
                                                )
                                            else
                                                obj[field_key] = decode_object(
                                                    cursor,
                                                    hyphen_line_depth + 1,
                                                    options,
                                                )
                                            end
                                        else
                                            obj[field_key] = JsonObject()
                                        end
                                    end
                                end
                            end

                            push!(result, obj)
                        else
                            # Fields after a multiline array only show up once its rows are consumed.
                            obj = JsonObject()
                            if !isempty(after_colon)
                                obj[first_key] = decode_inline_array_data(
                                    after_colon,
                                    item_header,
                                    options,
                                )
                            else
                                if item_header.length == 0
                                    obj[first_key] = []
                                elseif item_header.fields !== nothing
                                    obj[first_key] = decode_multiline_array_data(
                                        cursor,
                                        item_header,
                                        options,
                                    )
                                else
                                    obj[first_key] = decode_multiline_array_data(
                                        cursor,
                                        item_header,
                                        options,
                                    )
                                end

                                while has_more_lines(cursor)
                                    next_line = peek_line(cursor)

                                    if next_line.depth != hyphen_line_depth + 1
                                        break
                                    end

                                    if startswith(next_line.content, LIST_ITEM_MARKER)
                                        break
                                    end

                                    field_colon_pos =
                                        find_first_unquoted(next_line.content, ':')
                                    if field_colon_pos === nothing
                                        if options.strict
                                            error(
                                                "Missing colon after key at line $(next_line.lineNumber)",
                                            )
                                        end
                                        advance_line!(cursor)
                                        continue
                                    end

                                    field_key_str =
                                        strip(next_line.content[1:prevind(next_line.content, field_colon_pos)])
                                    field_value_str =
                                        strip(next_line.content[(field_colon_pos+1):end])
                                    field_key = parse_key(field_key_str)
                                    advance_line!(cursor)

                                    if !isempty(field_value_str)
                                        obj[field_key] = parse_primitive(field_value_str)
                                    else
                                        nested_line = peek_line(cursor)
                                        if nested_line !== nothing &&
                                           nested_line.depth > hyphen_line_depth + 1
                                            obj[field_key] = decode_object(
                                                cursor,
                                                hyphen_line_depth + 1,
                                                options,
                                            )
                                        else
                                            obj[field_key] = JsonObject()
                                        end
                                    end
                                end
                            end
                            push!(result, obj)
                        end
                    else
                        # Unreachable – a valid array header always ends with a colon.
                        advance_line!(cursor)
                        push!(result, [])
                    end
                else
                    # A bare array item, e.g. `- [2]: 1,2`.
                    if colon_pos !== nothing
                        after_colon = strip(after_marker[(colon_pos+1):end])
                        if !isempty(after_colon)
                            advance_line!(cursor)
                            array_value =
                                decode_inline_array_data(after_colon, item_header, options)
                            push!(result, array_value)
                        else
                            advance_line!(cursor)
                            if item_header.length == 0
                                push!(result, [])
                            else
                                array_value = decode_multiline_array_data(
                                    cursor,
                                    item_header,
                                    options,
                                )
                                push!(result, array_value)
                            end
                        end
                    else
                        # Unreachable – a valid array header always ends with a colon.
                        advance_line!(cursor)
                        push!(result, [])
                    end
                end
            else
                colon_pos = find_first_unquoted(after_marker, ':')

                if colon_pos !== nothing
                    key_str = strip(after_marker[1:prevind(after_marker, colon_pos)])
                    value_str = strip(after_marker[(colon_pos+1):end])

                    first_key = parse_key(key_str)
                    hyphen_line_depth = line.depth

                    advance_line!(cursor)

                    obj = JsonObject()

                    if !isempty(value_str)
                        obj[first_key] = parse_primitive(value_str)
                    else
                        next_line = peek_line(cursor)

                        if next_line !== nothing && next_line.depth == hyphen_line_depth + 2
                            # The first field's nested object sits two levels below the hyphen.
                            obj[first_key] =
                                decode_object(cursor, hyphen_line_depth + 1, options)
                        else
                            obj[first_key] = JsonObject()
                        end
                    end

                    while has_more_lines(cursor)
                        next_line = peek_line(cursor)

                        if next_line.depth != hyphen_line_depth + 1
                            break
                        end

                        if startswith(next_line.content, LIST_ITEM_MARKER)
                            break
                        end

                        field_colon_pos = find_first_unquoted(next_line.content, ':')
                        if field_colon_pos === nothing
                            if options.strict
                                error(
                                    "Missing colon after key at line $(next_line.lineNumber)",
                                )
                            end
                            advance_line!(cursor)
                            continue
                        end

                        field_key_str = strip(next_line.content[1:prevind(next_line.content, field_colon_pos)])
                        field_value_str = strip(next_line.content[(field_colon_pos+1):end])

                        field_header = try
                            parse_array_header(field_key_str * ":")
                        catch
                            nothing
                        end

                        if field_header !== nothing && field_header.key !== nothing
                            field_key = field_header.key
                            advance_line!(cursor)

                            if !isempty(field_value_str)
                                obj[field_key] = decode_inline_array_data(
                                    field_value_str,
                                    field_header,
                                    options,
                                )
                            else
                                obj[field_key] = decode_multiline_array_data(
                                    cursor,
                                    field_header,
                                    options,
                                )
                            end
                        else
                            field_key = parse_key(field_key_str)
                            advance_line!(cursor)

                            if !isempty(field_value_str)
                                obj[field_key] = parse_primitive(field_value_str)
                            else
                                nested_line = peek_line(cursor)

                                if nested_line !== nothing &&
                                   nested_line.depth > hyphen_line_depth + 1
                                    nested_header = try
                                        parse_array_header(nested_line.content)
                                    catch
                                        nothing
                                    end

                                    if nested_header !== nothing
                                        obj[field_key] =
                                            decode_array(cursor, options, nested_header)
                                    else
                                        obj[field_key] = decode_object(
                                            cursor,
                                            hyphen_line_depth + 1,
                                            options,
                                        )
                                    end
                                else
                                    obj[field_key] = JsonObject()
                                end
                            end
                        end
                    end

                    push!(result, obj)
                else
                    push!(result, parse_primitive(after_marker))
                    advance_line!(cursor)
                end
            end
        end

        item_count += 1
    end

    if options.strict && header.length > 0
        header_line_num = if start_position > 1
            cursor.lines[start_position-1].lineNumber
        else
            0
        end

        last_item_line_num =
            if cursor.position > 1 && cursor.position - 1 <= length(cursor.lines)
                cursor.lines[cursor.position-1].lineNumber
            else
                typemax(Int)
            end

        for blank in cursor.blankLines
            if blank.lineNumber > header_line_num && blank.lineNumber <= last_item_line_num
                error(
                    "Blank lines are not allowed inside list arrays (line $(blank.lineNumber))",
                )
            end
        end
    end

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
function decode(input::String; options::DecodeOptions = DecodeOptions())::JsonValue
    scan_result = to_parsed_lines(input, options.indent, options.strict)

    if isempty(scan_result.lines)
        return JsonObject()
    end

    cursor = LineCursor(scan_result.lines, scan_result.blankLines)
    return decode_value_from_lines(cursor, options)
end
