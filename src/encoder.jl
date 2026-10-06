"""
    encode(value; options::EncodeOptions = EncodeOptions()) -> String

Encodes `value` as a TOON document after normalizing it to the JSON data model.

# Examples
```julia
encode((name = "Ada", age = 30))
# name: Ada
# age: 30

encode([(id = 1,), (id = 2,)])
# [2]{id}:
#   1
#   2
```
"""
function encode(value; options::EncodeOptions = EncodeOptions())::String
    normalized = normalize_value(value)

    if is_json_primitive(normalized)
        # Unquoted, a leading U+FEFF would read as the byte-order mark that decoders strip.
        if normalized isa String && startswith(normalized, '\ufeff')
            return "$(DOUBLE_QUOTE)$(escape_string(normalized))$(DOUBLE_QUOTE)"
        end
        return encode_primitive(normalized, options.delimiter)
    end

    writer = LineWriter(options.indentSize)
    if is_json_array(normalized)
        encode_array!(writer, nothing, normalized, 0, options)
    else
        encode_object!(writer, normalized, 0, options)
    end
    return string(writer)
end

function encode_object!(writer::LineWriter, object::AbstractDict, depth::Int, options::EncodeOptions)
    for (key, value) in object
        encode_key_value!(writer, key, value, depth, options)
    end
end

function encode_key_value!(writer::LineWriter, key::String, value, depth::Int, options::EncodeOptions)
    if is_json_primitive(value)
        push!(writer, depth, "$(encode_key(key)): $(encode_primitive(value, options.delimiter))")
    elseif is_json_array(value)
        encode_array!(writer, key, value, depth, options)
    else
        push!(writer, depth, "$(encode_key(key)):")
        encode_object!(writer, value, depth + 1, options)
    end
end

function encode_array!(
    writer::LineWriter,
    key::Union{String,Nothing},
    array::AbstractVector,
    depth::Int,
    options::EncodeOptions,
)
    if isempty(array)
        push!(writer, depth, key === nothing ? "[]" : "$(encode_key(key)): []")
        return
    end

    if is_array_of_primitives(array)
        push!(writer, depth, inline_array_line(key, array, options.delimiter))
        return
    end

    fields = is_array_of_objects(array) ? tabular_fields(array) : nothing
    push!(writer, depth, format_header(key, length(array), options.delimiter, fields))
    for item in array
        if fields !== nothing
            push!(writer, depth + 1, encode_row(item, fields, options.delimiter))
        else
            encode_list_item!(writer, item, depth + 1, options)
        end
    end
end

function inline_array_line(key::Union{String,Nothing}, values::AbstractVector, delimiter::Delimiter)
    header = format_header(key, length(values), delimiter)
    isempty(values) && return header
    return "$header $(join((encode_primitive(value, delimiter) for value in values), delimiter))"
end

function encode_list_item!(writer::LineWriter, value, depth::Int, options::EncodeOptions)
    if is_json_primitive(value)
        push!(writer, depth, LIST_ITEM_MARKER * encode_primitive(value, options.delimiter))
    elseif is_json_array(value) && is_array_of_primitives(value)
        push!(writer, depth, LIST_ITEM_MARKER * inline_array_line(nothing, value, options.delimiter))
    elseif is_json_array(value)
        push!(writer, depth, LIST_ITEM_MARKER * format_header(nothing, length(value), options.delimiter))
        for item in value
            encode_list_item!(writer, item, depth + 1, options)
        end
    elseif isempty(value)
        push!(writer, depth, "-")
    else
        # The object's fields sit one level deeper, except the first, which moves onto the hyphen line.
        first_line = length(writer.lines) + 1
        encode_object!(writer, value, depth + 1, options)
        writer.lines[first_line] =
            " "^(depth * writer.indent) * LIST_ITEM_MARKER * lstrip(writer.lines[first_line])
    end
end

encode_row(row::AbstractDict, fields::Vector{String}, delimiter::Delimiter) =
    join((encode_primitive(row[field], delimiter) for field in fields), delimiter)

"""
    tabular_fields(rows) -> Union{Vector{String},Nothing}

Returns the keys that objects share when every value is a primitive, or `nothing`.
"""
function tabular_fields(rows::AbstractVector)::Union{Vector{String},Nothing}
    first_keys = collect(keys(first(rows)))
    isempty(first_keys) && return nothing
    for row in rows
        (
            length(row) == length(first_keys) &&
            all(haskey(row, key) for key in first_keys) &&
            all(is_json_primitive, values(row))
        ) || return nothing
    end
    return first_keys
end
