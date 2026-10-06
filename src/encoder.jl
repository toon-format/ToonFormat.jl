function encode_value(
    value::JsonValue,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    if is_json_primitive(value)
        encoded = encode_primitive(value, options.delimiter)
        push!(writer, depth, encoded)
    elseif is_json_array(value)
        encode_array(nothing, value, writer, depth, options)
    elseif is_json_object(value)
        encode_object(value, writer, depth, options)
    end
end

function encode_object(
    obj::JsonObject,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    for (key, value) in obj
        encode_key_value_pair(key, value, writer, depth, options)
    end
end

function encode_key_value_pair(
    key::String,
    value::JsonValue,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    encoded_key = encode_key(key)

    if is_json_primitive(value)
        encoded_value = encode_primitive(value, options.delimiter)
        push!(writer, depth, "$(encoded_key): $(encoded_value)")
    elseif is_json_array(value)
        encode_array(key, value, writer, depth, options)
    elseif is_json_object(value)
        push!(writer, depth, "$(encoded_key):")
        if !is_empty_object(value)
            encode_object(value, writer, depth + 1, options)
        end
    end
end

function encode_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    arr_length = length(arr)

    if arr_length == 0
        header = format_header(key, 0, options.delimiter)
        push!(writer, depth, header)
        return
    end

    if is_array_of_primitives(arr)
        encode_primitive_array(key, arr, writer, depth, options)
        return
    end

    if is_tabular_array(arr)
        encode_tabular_array(key, arr, writer, depth, options)
        return
    end

    if is_array_of_arrays(arr) && all(is_array_of_primitives, arr)
        encode_array_of_arrays(key, arr, writer, depth, options)
        return
    end

    encode_mixed_array(key, arr, writer, depth, options)
end

function encode_primitive_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    header = format_header(key, length(arr), options.delimiter)
    encoded_values = [encode_primitive(v, options.delimiter) for v in arr]
    values_str = join_encoded_values(encoded_values, options.delimiter)
    if isempty(values_str)
        push!(writer, depth, header)
    else
        push!(writer, depth, "$(header) $(values_str)")
    end
end

function encode_tabular_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    first_obj = arr[1]
    fields = collect(keys(first_obj))

    header = format_header(key, length(arr), options.delimiter, fields)
    push!(writer, depth, header)

    for obj in arr
        row_values = [encode_primitive(obj[field], options.delimiter) for field in fields]
        row_str = join_encoded_values(row_values, options.delimiter)
        push!(writer, depth + 1, row_str)
    end
end

function encode_array_of_arrays(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    header = format_header(key, length(arr), options.delimiter)
    push!(writer, depth, header)

    for inner_arr in arr
        inner_header = format_header(nothing, length(inner_arr), options.delimiter)
        encoded_values = [encode_primitive(v, options.delimiter) for v in inner_arr]
        values_str = join_encoded_values(encoded_values, options.delimiter)
        if isempty(values_str)
            push!(writer, depth + 1, "$(LIST_ITEM_MARKER)$(inner_header)")
        else
            push!(writer, depth + 1, "$(LIST_ITEM_MARKER)$(inner_header) $(values_str)")
        end
    end
end

function encode_mixed_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    header = format_header(key, length(arr), options.delimiter)
    push!(writer, depth, header)

    for item in arr
        encode_list_item(item, writer, depth + 1, options)
    end
end

function encode_list_item(
    value::JsonValue,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    if is_json_primitive(value)
        encoded = encode_primitive(value, options.delimiter)
        push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded)")
    elseif is_json_array(value)
        if is_array_of_primitives(value)
            header = format_header(nothing, length(value), options.delimiter)
            encoded_values = [encode_primitive(v, options.delimiter) for v in value]
            values_str = join_encoded_values(encoded_values, options.delimiter)
            if isempty(values_str)
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
            else
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(header) $(values_str)")
            end
        else
            header = format_header(nothing, length(value), options.delimiter)
            push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
            for item in value
                encode_list_item(item, writer, depth + 1, options)
            end
        end
    elseif is_json_object(value)
        if is_empty_object(value)
            push!(writer, depth, LIST_ITEM_MARKER[1:(end-1)])
            return
        end

        # The first field goes on the hyphen line.
        obj_keys = collect(keys(value))
        if !isempty(obj_keys)
            first_key = obj_keys[1]
            first_value = value[first_key]

            encoded_key = encode_key(first_key)

            if is_json_primitive(first_value)
                encoded_val = encode_primitive(first_value, options.delimiter)
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded_key): $(encoded_val)")
            elseif is_json_array(first_value)
                if is_array_of_primitives(first_value)
                    header =
                        format_header(first_key, length(first_value), options.delimiter)
                    encoded_values =
                        [encode_primitive(v, options.delimiter) for v in first_value]
                    values_str = join_encoded_values(encoded_values, options.delimiter)
                    if isempty(values_str)
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
                    else
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header) $(values_str)")
                    end
                else
                    if is_tabular_array(first_value)
                        first_obj = first_value[1]
                        fields = collect(keys(first_obj))
                        header = format_header(
                            first_key,
                            length(first_value),
                            options.delimiter,
                            fields,
                        )
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
                        # Rows sit at depth + 2 (spec §10: tabular rows inside list-item objects).
                        for obj in first_value
                            row_values = [
                                encode_primitive(obj[field], options.delimiter) for
                                field in fields
                            ]
                            row_str = join_encoded_values(row_values, options.delimiter)
                            push!(writer, depth + 2, row_str)
                        end
                    else
                        header =
                            format_header(first_key, length(first_value), options.delimiter)
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
                        # Items sit at depth + 2 (spec §10: list items inside list-item objects).
                        for item in first_value
                            encode_list_item(item, writer, depth + 2, options)
                        end
                    end
                end
            elseif is_json_object(first_value)
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded_key):")
                if !is_empty_object(first_value)
                    encode_object(first_value, writer, depth + 2, options)
                end
            end

            for key in obj_keys[2:end]
                encode_key_value_pair(key, value[key], writer, depth + 1, options)
            end
        end
    end
end

"""
    encode(value; options::EncodeOptions=EncodeOptions()) -> String

Main encoding function. Converts a Julia value to TOON format string.

# Arguments
- `value`: The value to encode (will be normalized to JSON model)
- `options`: Encoding options (indentSize, delimiter)

# Returns
- TOON formatted string

# Examples
```julia
encode(Dict("name" => "Alice", "age" => 30))
# name: Alice
# age: 30

encode([Dict("id" => 1), Dict("id" => 2)])
# [2]{id}:
#   1
#   2
```
"""
function encode(value; options::EncodeOptions = EncodeOptions())::String
    normalized = normalize_value(value)
    writer = LineWriter(options.indentSize)

    if is_json_primitive(normalized)
        return encode_primitive(normalized, options.delimiter)
    end

    if is_json_array(normalized)
        encode_array(nothing, normalized, writer, 0, options)
    elseif is_json_object(normalized)
        encode_object(normalized, writer, 0, options)
    end

    return string(writer)
end
