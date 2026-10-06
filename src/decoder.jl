mutable struct LineReader
    lines::Vector{ParsedLine}
    blank_line_numbers::Vector{Int}
    position::Int
    strict::Bool
end

peek_line(reader::LineReader) =
    reader.position <= length(reader.lines) ? reader.lines[reader.position] : nothing

function read_line!(reader::LineReader)
    line = peek_line(reader)
    line === nothing || (reader.position += 1)
    return line
end

last_read_line(reader::LineReader) = reader.lines[reader.position-1]

decode_error(line::ParsedLine, message::AbstractString) = error("Line $(line.number): $message")

# Parser helpers don't know their line; this attaches it to the errors they throw.
function with_line(f, line::ParsedLine)
    try
        return f()
    catch e
        e isa ErrorException || rethrow()
        decode_error(line, e.msg)
    end
end

"""
    decode(input::AbstractString; options::DecodeOptions = DecodeOptions()) -> JsonValue

Decodes a TOON document into `OrderedDict{String,Any}` objects, `Vector{Any}` arrays,
and `String`, `Int`, `Float64`, `Bool`, or `nothing` primitives. Throws an
`ErrorException` naming the line on invalid input.

# Examples
```julia
decode("name: Ada\\nage: 30")
# OrderedDict("name" => "Ada", "age" => 30)

decode("[2]: 1,2")
# [1, 2]
```
"""
function decode(input::AbstractString; options::DecodeOptions = DecodeOptions())::JsonValue
    lines, blank_line_numbers = scan_lines(input, options.indentSize, options.strict)
    return decode_document(LineReader(lines, blank_line_numbers, 1, options.strict))
end

function decode_document(reader::LineReader)::JsonValue
    first_line = peek_line(reader)
    skipped_leading = false
    while first_line !== nothing && first_line.depth != 0
        skip_over_indented_line(reader, first_line, 0)
        skipped_leading = true
        first_line = peek_line(reader)
    end

    first_line === nothing && return JsonObject()

    if first_line.content == "[]"
        read_line!(reader)
        assert_fully_consumed(reader)
        return JsonArray()
    end

    if is_array_header_content(first_line.content)
        header = with_line(() -> parse_array_header(first_line.content, reader.strict), first_line)
        if header !== nothing
            read_line!(reader)
            value = decode_header_value(header, reader, 0, first_line)
            assert_fully_consumed(reader)
            return value
        end
    end

    read_line!(reader)
    following = peek_line(reader)
    # A skipped leading line makes the document multi-line, so no root primitive.
    if following === nothing && !skipped_leading && !is_key_value_content(first_line.content)
        return with_line(() -> parse_primitive_token(first_line.content), first_line)
    end

    if !is_key_value_content(first_line.content) && following !== nothing && following.depth == 0
        decode_error(first_line, "Top-level document must start with a key-value or array-header line")
    end

    object = JsonObject()
    decode_key_value!(object, first_line, reader, 0)
    while (line = peek_line(reader)) !== nothing
        if line.depth != 0
            skip_over_indented_line(reader, line, 0)
            continue
        end
        read_line!(reader)
        decode_key_value!(object, line, reader, 0)
    end
    return object
end

function assert_no_depth_jump(reader::LineReader, line::ParsedLine, parent_depth::Int)
    if reader.strict && line.depth > parent_depth + 1
        decode_error(
            line,
            "Indentation depth jump: expected depth $(parent_depth + 1), but found $(line.depth)",
        )
    end
end

function skip_over_indented_line(reader::LineReader, line::ParsedLine, content_depth::Int)
    if reader.strict
        decode_error(line, "Over-indented line: expected depth $content_depth, but found $(line.depth)")
    end
    assert_not_scalar_line(line)
    read_line!(reader)
end

# A bare token errors in both modes outside root primitive position, so the non-strict
# paths that drop a line must not swallow it.
function assert_not_scalar_line(line::ParsedLine)
    if !is_key_value_content(line.content)
        decode_error(line, "Unexpected bare token line outside root primitive position")
    end
end

# Strict decoding never silently discards input, so a line after the root form is an error.
function assert_fully_consumed(reader::LineReader)
    line = peek_line(reader)
    line === nothing && return
    reader.strict && decode_error(line, "Unexpected content after the document root")
    while (line = read_line!(reader)) !== nothing
        assert_not_scalar_line(line)
    end
end

function assert_expected_count(
    reader::LineReader,
    actual::Int,
    expected::Int,
    what::String,
    line::ParsedLine,
)
    if reader.strict && actual != expected
        decode_error(line, "Expected $expected $what, but got $actual")
    end
end

function assert_no_blank_lines(reader::LineReader, from::Int, to::Int, what::String)
    for number in reader.blank_line_numbers
        if from < number < to
            error("Line $number: Blank lines inside $what are not allowed in strict mode")
        end
    end
end

function decode_key_value!(
    object::JsonObject,
    line::ParsedLine,
    reader::LineReader,
    base_depth::Int,
)
    header = with_line(() -> parse_array_header(line.content, reader.strict), line)
    if header !== nothing && header.key !== nothing
        object[header.key] = decode_header_value(header, reader, base_depth, line)
        return
    end
    if header !== nothing && reader.strict
        decode_error(line, "Keyless array header is only valid at the document root or as a list item")
    end

    key, value_start = with_line(() -> parse_key_token(line.content), line)
    rest = trim_spaces(SubString(line.content, value_start))

    object[key] = if !isempty(rest)
        rest == "[]" ? JsonArray() : with_line(() -> parse_primitive_token(rest), line)
    else
        next_line = peek_line(reader)
        if next_line !== nothing && next_line.depth > base_depth
            assert_no_depth_jump(reader, next_line, base_depth)
            decode_object_fields(reader, base_depth + 1)
        else
            JsonObject()
        end
    end
end

function decode_object_fields(reader::LineReader, base_depth::Int)::JsonObject
    object = JsonObject()
    # A non-strict first line deeper than expected sets the depth of the whole scope.
    field_depth = nothing
    while (line = peek_line(reader)) !== nothing && line.depth >= base_depth
        field_depth = something(field_depth, line.depth)
        if line.depth == field_depth
            read_line!(reader)
            decode_key_value!(object, line, reader, field_depth)
        else
            skip_over_indented_line(reader, line, field_depth)
        end
    end
    return object
end

function scope_content_depth(reader::LineReader, base_depth::Int)::Int
    first_line = peek_line(reader)
    (first_line === nothing || first_line.depth <= base_depth + 1) && return base_depth + 1
    assert_no_depth_jump(reader, first_line, base_depth)
    return first_line.depth
end

function decode_header_value(
    header::ArrayHeader,
    reader::LineReader,
    base_depth::Int,
    header_line::ParsedLine,
)::JsonValue
    if header.inline_values !== nothing
        values = with_line(header_line) do
            parse_primitive_token.(parse_delimited_values(header.inline_values, header.delimiter))
        end
        assert_expected_count(reader, length(values), header.length, "inline-form values", header_line)
        return JsonArray(values)
    end

    header.fields !== nothing && return decode_tabular_array(header, reader, base_depth, header_line)
    return decode_list_array(header, reader, base_depth, header_line)
end

# A row line has no unquoted colon, or its first unquoted delimiter precedes the colon.
function is_data_row(content::AbstractString, delimiter::Char)::Bool
    colon = find_unquoted(content, ':')
    colon === nothing && return true
    delimiter_index = find_unquoted(content, delimiter)
    return delimiter_index !== nothing && delimiter_index < colon
end

function decode_tabular_array(
    header::ArrayHeader,
    reader::LineReader,
    base_depth::Int,
    header_line::ParsedLine,
)::JsonArray
    row_depth = scope_content_depth(reader, base_depth)
    rows = JsonArray()
    first_row_line = nothing
    last_row_line = header_line

    # Only strict stops at N; non-strict reads on, so the declared length never truncates.
    while !reader.strict || length(rows) < header.length
        line = peek_line(reader)
        (line === nothing || line.depth <= base_depth) && break
        if line.depth != row_depth
            skip_over_indented_line(reader, line, row_depth)
            continue
        end
        is_data_row(line.content, header.delimiter) || break

        read_line!(reader)
        first_row_line = something(first_row_line, line)
        last_row_line = line

        cells = with_line(line) do
            parse_primitive_token.(parse_delimited_values(line.content, header.delimiter))
        end
        assert_expected_count(reader, length(cells), length(header.fields), "tabular row values", line)
        push!(rows, object_from_fields(header.fields, cells))
    end

    assert_expected_count(reader, length(rows), header.length, "tabular rows", last_row_line)
    if reader.strict
        if first_row_line !== nothing
            assert_no_blank_lines(reader, first_row_line.number, last_row_line.number, "tabular array")
        end
        next_line = peek_line(reader)
        if next_line !== nothing &&
           next_line.depth == row_depth &&
           !startswith(next_line.content, "- ") &&
           is_data_row(next_line.content, header.delimiter)
            decode_error(next_line, "Expected $(header.length) tabular rows, but found more")
        end
    end
    return rows
end

is_list_item(content::AbstractString) = content == "-" || startswith(content, "- ")

function decode_list_array(
    header::ArrayHeader,
    reader::LineReader,
    base_depth::Int,
    header_line::ParsedLine,
)::JsonArray
    item_depth = scope_content_depth(reader, base_depth)
    items = JsonArray()
    first_item_line = nothing
    last_item_line = header_line

    # Only strict stops at N; non-strict reads on, so the declared length never truncates.
    while !reader.strict || length(items) < header.length
        line = peek_line(reader)
        (line === nothing || line.depth <= base_depth) && break
        if line.depth != item_depth
            skip_over_indented_line(reader, line, item_depth)
            continue
        end
        is_list_item(line.content) || break

        first_item_line = something(first_item_line, line)
        push!(items, decode_list_item(reader, item_depth))
        # The header span reaches the last line of the item's content, not just its hyphen line.
        last_item_line = last_read_line(reader)
    end

    assert_expected_count(reader, length(items), header.length, "list-form items", last_item_line)
    if reader.strict
        if first_item_line !== nothing
            assert_no_blank_lines(reader, first_item_line.number, last_item_line.number, "list-form array")
        end
        next_line = peek_line(reader)
        if next_line !== nothing && next_line.depth == item_depth && startswith(next_line.content, "- ")
            decode_error(next_line, "Expected $(header.length) list-form items, but found more")
        end
    end
    return items
end

function decode_list_item(reader::LineReader, base_depth::Int)::JsonValue
    line = read_line!(reader)
    line.content == "-" && return JsonObject()

    content = SubString(line.content, 3)
    trim_spaces(content) == "[]" && return JsonArray()

    item_line = ParsedLine(content, line.depth, line.number)
    header = with_line(() -> parse_array_header(content, reader.strict), item_line)
    if header !== nothing && header.key === nothing
        # There is no keyless fields-bearing list-item form.
        if header.fields === nothing
            return decode_header_value(header, reader, base_depth, item_line)
        elseif reader.strict
            decode_error(item_line, "Keyless header with a field list is only valid at the document root")
        end
    end

    is_key_value_content(content) ||
        return with_line(() -> parse_primitive_token(content), item_line)

    # The first field sits on the hyphen line; the others follow one level deeper.
    object = JsonObject()
    field_depth = base_depth + 1
    decode_key_value!(object, item_line, reader, field_depth)
    while (line = peek_line(reader)) !== nothing && line.depth >= field_depth
        if line.depth == field_depth
            # A hyphen marks a list item only at item depth, so a `- ` line here is a further field.
            read_line!(reader)
            decode_key_value!(object, line, reader, field_depth)
        else
            skip_over_indented_line(reader, line, field_depth)
        end
    end
    return object
end

# A non-strict width mismatch leaves trailing fields absent.
object_from_fields(fields::Vector{String}, cells::Vector) = JsonObject(zip(fields, cells))
