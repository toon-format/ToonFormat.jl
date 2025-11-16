# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Main TOON encoder implementation.
"""

"""
    encode_value(value::JsonValue, writer::LineWriter, depth::Int, options::EncodeOptions)

Encode a JSON value to TOON format.
"""
function encode_value(value::JsonValue, writer::LineWriter, depth::Int, options::EncodeOptions)
    if is_json_primitive(value)
        encoded = encode_primitive(value, options.delimiter)
        push!(writer, depth, encoded)
    elseif is_json_array(value)
        encode_array(nothing, value, writer, depth, options)
    elseif is_json_object(value)
        encode_object(value, writer, depth, options)
    end
end

"""
    encode_object(obj::JsonObject, writer::LineWriter, depth::Int, options::EncodeOptions)

Encode an object to TOON format.
"""
function encode_object(obj::JsonObject, writer::LineWriter, depth::Int, options::EncodeOptions)
    for (key, value) in obj
        encode_key_value_pair(key, value, writer, depth, options)
    end
end

"""
    encode_key_value_pair(key::String, value::JsonValue, writer::LineWriter,
                          depth::Int, options::EncodeOptions; prefix::String="")

Encode a key-value pair.
"""
function encode_key_value_pair(key::String, value::JsonValue, writer::LineWriter,
                               depth::Int, options::EncodeOptions; prefix::String="")
    # Build the full key (with prefix if folding)
    full_key = isempty(prefix) ? key : "$(prefix).$(key)"

    # Calculate how many levels deep this key would be if we output it now
    # Number of segments in the full key (e.g., "a.b.c" has 3 segments)
    num_segments = count('.', full_key) + 1

    # Should we continue folding this key?
    # We fold object values if we haven't reached the flattenDepth limit yet
    can_fold = options.keyFolding == "safe" &&
               is_safe_identifier(key) &&
               (isempty(prefix) || all(is_safe_identifier, split(prefix, '.')))

    # We only fold if the value is an object AND we haven't exceeded the depth
    # flattenDepth=2 means we can have up to 2 segments in a folded key (a.b)
    should_fold = can_fold && num_segments < options.flattenDepth && is_json_object(value)

    encoded_key = encode_key(isempty(prefix) ? key : full_key)

    if is_json_primitive(value)
        encoded_value = encode_primitive(value, options.delimiter)
        push!(writer, depth, "$(encoded_key): $(encoded_value)")
    elseif is_json_array(value)
        # For arrays, use the folded key if we have a prefix (even if we can't fold further)
        # This ensures "data.users[2]:" instead of just "users[2]:"
        array_key = isempty(prefix) ? key : full_key
        encode_array(array_key, value, writer, depth, options)
    elseif is_json_object(value)
        # Check if we should fold this nested object
        if should_fold && !is_empty_object(value)
            # Continue folding - encode child keys with this key as prefix
            for (child_key, child_value) in value
                encode_key_value_pair(child_key, child_value, writer, depth, options, prefix=full_key)
            end
        else
            # Don't fold - encode normally
            # Output the key and then the nested object without folding
            push!(writer, depth, "$(encoded_key):")
            if !is_empty_object(value)
                # Don't pass options with folding enabled - just use normal encoding
                # to prevent re-folding in the nested object
                nested_opts = EncodeOptions(
                    indent=options.indent,
                    delimiter=options.delimiter,
                    keyFolding="off",
                    flattenDepth=options.flattenDepth
                )
                encode_object(value, writer, depth + 1, nested_opts)
            end
        end
    end
end

"""
    encode_array(key::Union{String, Nothing}, arr::JsonArray, writer::LineWriter,
                 depth::Int, options::EncodeOptions)

Encode an array to TOON format. Automatically selects the appropriate format:
- Inline for primitive arrays
- Tabular for uniform objects with primitive values
- Expanded list for other arrays
"""
function encode_array(key::Union{String, Nothing}, arr::JsonArray, writer::LineWriter,
                     depth::Int, options::EncodeOptions)
    arr_length = length(arr)

    # Empty array
    if arr_length == 0
        header = format_header(key, 0, options.delimiter)
        push!(writer, depth, header)
        return
    end

    # Primitive array (inline)
    if is_array_of_primitives(arr)
        encode_primitive_array(key, arr, writer, depth, options)
        return
    end

    # Tabular array (uniform objects)
    if is_tabular_array(arr)
        encode_tabular_array(key, arr, writer, depth, options)
        return
    end

    # Arrays of primitive arrays (expanded list)
    if is_array_of_arrays(arr) && all(is_array_of_primitives, arr)
        encode_array_of_arrays(key, arr, writer, depth, options)
        return
    end

    # Mixed/complex arrays (expanded list)
    encode_mixed_array(key, arr, writer, depth, options)
end

"""
    encode_primitive_array(key::Union{String, Nothing}, arr::JsonArray,
                          writer::LineWriter, depth::Int, options::EncodeOptions)

Encode a primitive array in inline format.
"""
function encode_primitive_array(key::Union{String, Nothing}, arr::JsonArray,
                               writer::LineWriter, depth::Int, options::EncodeOptions)
    header = format_header(key, length(arr), options.delimiter)
    encoded_values = [encode_primitive(v, options.delimiter) for v in arr]
    values_str = join_encoded_values(encoded_values, options.delimiter)
    push!(writer, depth, "$(header) $(values_str)")
end

"""
    encode_tabular_array(key::Union{String, Nothing}, arr::JsonArray,
                        writer::LineWriter, depth::Int, options::EncodeOptions)

Encode an array of uniform objects in tabular format.
"""
function encode_tabular_array(key::Union{String, Nothing}, arr::JsonArray,
                             writer::LineWriter, depth::Int, options::EncodeOptions)
    # Get field names from first object
    first_obj = arr[1]
    fields = collect(keys(first_obj))

    # Write header
    header = format_header(key, length(arr), options.delimiter, fields)
    push!(writer, depth, header)

    # Write rows
    for obj in arr
        row_values = [encode_primitive(obj[field], options.delimiter) for field in fields]
        row_str = join_encoded_values(row_values, options.delimiter)
        push!(writer, depth + 1, row_str)
    end
end

"""
    encode_array_of_arrays(key::Union{String, Nothing}, arr::JsonArray,
                          writer::LineWriter, depth::Int, options::EncodeOptions)

Encode an array of primitive arrays in expanded list format.
"""
function encode_array_of_arrays(key::Union{String, Nothing}, arr::JsonArray,
                               writer::LineWriter, depth::Int, options::EncodeOptions)
    # Write parent header
    header = format_header(key, length(arr), options.delimiter)
    push!(writer, depth, header)

    # Write each inner array as a list item
    for inner_arr in arr
        inner_header = format_header(nothing, length(inner_arr), options.delimiter)
        encoded_values = [encode_primitive(v, options.delimiter) for v in inner_arr]
        values_str = join_encoded_values(encoded_values, options.delimiter)
        push!(writer, depth + 1, "$(LIST_ITEM_MARKER)$(inner_header) $(values_str)")
    end
end

"""
    encode_mixed_array(key::Union{String, Nothing}, arr::JsonArray,
                      writer::LineWriter, depth::Int, options::EncodeOptions)

Encode a mixed array in expanded list format.
"""
function encode_mixed_array(key::Union{String, Nothing}, arr::JsonArray,
                           writer::LineWriter, depth::Int, options::EncodeOptions)
    # Write parent header
    header = format_header(key, length(arr), options.delimiter)
    push!(writer, depth, header)

    # Write each item
    for item in arr
        encode_list_item(item, writer, depth + 1, options)
    end
end

"""
    encode_list_item(value::JsonValue, writer::LineWriter, depth::Int,
                    options::EncodeOptions)

Encode a single list item.
"""
function encode_list_item(value::JsonValue, writer::LineWriter, depth::Int,
                         options::EncodeOptions)
    if is_json_primitive(value)
        encoded = encode_primitive(value, options.delimiter)
        push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded)")
    elseif is_json_array(value)
        # Inline primitive array on the hyphen line
        if is_array_of_primitives(value)
            header = format_header(nothing, length(value), options.delimiter)
            encoded_values = [encode_primitive(v, options.delimiter) for v in value]
            values_str = join_encoded_values(encoded_values, options.delimiter)
            push!(writer, depth, "$(LIST_ITEM_MARKER)$(header) $(values_str)")
        else
            # Complex array needs its own header
            encode_array(nothing, value, writer, depth, options)
        end
    elseif is_json_object(value)
        # Empty object
        if is_empty_object(value)
            push!(writer, depth, LIST_ITEM_MARKER[1:end-1])  # Just "-"
            return
        end

        # Object with fields - first field on hyphen line
        obj_keys = collect(keys(value))
        if !isempty(obj_keys)
            first_key = obj_keys[1]
            first_value = value[first_key]

            encoded_key = encode_key(first_key)

            if is_json_primitive(first_value)
                encoded_val = encode_primitive(first_value, options.delimiter)
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded_key): $(encoded_val)")
            elseif is_json_array(first_value)
                # Array on first field
                push!(writer, depth, LIST_ITEM_MARKER[1:end-1])
                encode_key_value_pair(first_key, first_value, writer, depth + 1, options)
            elseif is_json_object(first_value)
                # Nested object
                push!(writer, depth, "$(LIST_ITEM_MARKER)$(encoded_key):")
                if !is_empty_object(first_value)
                    encode_object(first_value, writer, depth + 2, options)
                end
            end

            # Remaining fields at depth + 1
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
- `options`: Encoding options (indent, delimiter, etc.)

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
function encode(value; options::EncodeOptions=EncodeOptions())::String
    normalized = normalize_value(value)
    writer = LineWriter(options.indent)

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
