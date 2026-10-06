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
            return quote_string(normalized)
        end
        return encode_primitive(normalized, options.delimiter)
    end

    writer = LineWriter(options.indentSize)
    if is_json_array(normalized)
        encode_array!(writer, nothing, normalized, 0, options)
    else
        fields = keyed_tabular_fields(normalized)
        if fields === nothing
            encode_object!(writer, normalized, 0, options)
        else
            encode_keyed_object!(writer, nothing, normalized, fields, 0, options)
        end
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
        fields = keyed_tabular_fields(value)
        if fields === nothing
            push!(writer, depth, "$(encode_key(key)):")
            encode_object!(writer, value, depth + 1, options)
        else
            encode_keyed_object!(writer, key, value, fields, depth, options)
        end
    end
end

function encode_keyed_object!(
    writer::LineWriter,
    key::Union{String,Nothing},
    object::AbstractDict,
    fields::Vector{FieldNode},
    depth::Int,
    options::EncodeOptions,
)
    push!(writer, depth, format_header(key, length(object), options.delimiter, fields; keyed = true))
    for (entry_key, entry) in object
        push!(writer, depth + 1, "$(encode_key(entry_key)): $(encode_row(entry, fields, options.delimiter))")
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
        push!(writer, depth, "- " * encode_primitive(value, options.delimiter))
    elseif is_json_array(value) && is_array_of_primitives(value)
        push!(writer, depth, "- " * inline_array_line(nothing, value, options.delimiter))
    elseif is_json_array(value)
        push!(writer, depth, "- " * format_header(nothing, length(value), options.delimiter))
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
            " "^(depth * writer.indent) * "- " * lstrip(writer.lines[first_line])
    end
end

function encode_row(row::AbstractDict, fields::Vector{FieldNode}, delimiter::Delimiter)
    return join((encode_primitive(value, delimiter) for value in row_leaves(row, fields)), delimiter)
end

# Leaf cells in the depth-first order of the field list.
function row_leaves(row::AbstractDict, fields::Vector{FieldNode}, leaves = Any[])
    for field in fields
        if field.children === nothing
            push!(leaves, row[field.name])
        else
            row_leaves(row[field.name], field.children, leaves)
        end
    end
    return leaves
end

is_non_empty_object(value) = is_json_object(value) && !isempty(value)

"""
    tabular_fields(rows) -> Union{Vector{FieldNode},Nothing}

Returns the field list of objects that share one key set, with a nested field group for
every column of non-empty objects that are tabular themselves, or `nothing` when another
column holds anything but primitives.
"""
function tabular_fields(rows::AbstractVector)::Union{Vector{FieldNode},Nothing}
    first_keys = collect(keys(first(rows)))
    isempty(first_keys) && return nothing
    for row in rows
        (length(row) == length(first_keys) && all(haskey(row, key) for key in first_keys)) ||
            return nothing
    end

    fields = FieldNode[]
    for key in first_keys
        column = [row[key] for row in rows]
        if all(is_json_primitive, column)
            push!(fields, FieldNode(key, nothing))
        elseif all(is_non_empty_object, column)
            children = tabular_fields(column)
            children === nothing && return nothing
            push!(fields, FieldNode(key, children))
        else
            return nothing
        end
    end
    return fields
end

function keyed_tabular_fields(object::AbstractDict)::Union{Vector{FieldNode},Nothing}
    entries = collect(values(object))
    (length(entries) >= 2 && all(is_non_empty_object, entries)) || return nothing
    return tabular_fields(entries)
end
