# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Main TOON encoder implementation.
"""

"""
    encode_value(value::JsonValue, writer::LineWriter, depth::Int, options::EncodeOptions)

Encode a JSON value to TOON format.
"""
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

"""
    would_collide_with_sibling(obj::JsonObject, key::String, folded_path::String) -> Bool

Check if folding a nested key would create a collision with a sibling literal key.
This is used in safe mode to prevent folding when it would create duplicate keys.

For example, if obj has both:
- "data" => {"meta" => {"items" => [1,2]}}
- "data.meta.items" => "literal"

Then folding "data.meta.items" would collide with the literal key "data.meta.items".
"""
function would_collide_with_sibling(obj::JsonObject, key::String, folded_path::String)::Bool
    # Check if any sibling key matches the folded path
    for sibling_key in keys(obj)
        if sibling_key != key && sibling_key == folded_path
            return true
        end
    end
    return false
end

"""
    collect_all_folded_paths(key::String, value::JsonValue, prefix::String="") -> Vector{String}

Recursively collect all possible folded paths that would be generated when encoding this value.
"""
function collect_all_folded_paths(
    key::String,
    value::JsonValue,
    prefix::String = "",
)::Vector{String}
    paths = String[]
    current_path = isempty(prefix) ? key : "$(prefix).$(key)"

    if is_json_object(value) && length(value) == 1
        # This object could be folded
        push!(paths, current_path)
        # Recurse into the child
        child_key, child_value = first(value)
        append!(paths, collect_all_folded_paths(child_key, child_value, current_path))
    else
        # This is a leaf or multi-key object
        push!(paths, current_path)
    end

    return paths
end

"""
    encode_object(obj::JsonObject, writer::LineWriter, depth::Int, options::EncodeOptions)

Encode an object to TOON format.
"""
function encode_object(
    obj::JsonObject,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    for (key, value) in obj
        encode_key_value_pair(key, value, writer, depth, options, parent_obj = obj)
    end
end

"""
    encode_key_value_pair(key::String, value::JsonValue, writer::LineWriter,
                          depth::Int, options::EncodeOptions; prefix::String="", parent_obj::Union{JsonObject,Nothing}=nothing)

Encode a key-value pair.
"""
function encode_key_value_pair(
    key::String,
    value::JsonValue,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions;
    prefix::String = "",
    parent_obj::Union{JsonObject,Nothing} = nothing,
)
    # Build the full key (with prefix if folding)
    full_key = isempty(prefix) ? key : "$(prefix).$(key)"

    # Calculate how many segments are in the full key (e.g., "a.b.c" has 3 segments)
    num_segments = count('.', full_key) + 1

    # Should we continue folding this key?
    # We fold object values if we haven't reached the flattenDepth limit yet
    can_fold =
        options.keyFolding == "safe" &&
        is_safe_identifier(key) &&
        is_valid_unquoted_key(key) &&  # Key must not require quoting
        (isempty(prefix) || all(is_safe_identifier, split(prefix, '.')))

    # We only fold if:
    # 1. can_fold is true (safe mode, valid identifiers, no collisions)
    # 2. value is a single-key object (required for folding)
    # 3. num_segments < flattenDepth (we can add one more segment)
    #    flattenDepth=2 means we can output keys with up to 2 segments (a.b)
    #    So we fold when num_segments=1 (to create a.b), but not when num_segments=2
    should_fold =
        can_fold &&
        is_json_object(value) &&
        length(value) == 1 &&
        num_segments < options.flattenDepth

    # Use the key with prefix only if we're in a folding context
    # The parent should have already checked if we can fold before adding the prefix
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
            # Check if this is a single-key object (required for folding)
            if length(value) == 1
                # Before folding, check if the child key can actually be folded
                # (In safe mode, we can't fold if the child requires quoting)
                child_key = collect(keys(value))[1]
                child_can_fold =
                    is_safe_identifier(child_key) && is_valid_unquoted_key(child_key)

                # In safe mode at root level, check for collision with sibling keys
                has_collision = false
                if options.keyFolding == "safe" &&
                   depth == 0 &&
                   parent_obj !== nothing &&
                   isempty(prefix)
                    # Collect all paths that would be generated by folding this value
                    all_paths = collect_all_folded_paths(key, value)
                    # Check if any of these paths collide with sibling keys
                    for path in all_paths
                        if would_collide_with_sibling(parent_obj, key, path)
                            has_collision = true
                            break
                        end
                    end
                end

                if !has_collision && (child_can_fold || options.keyFolding != "safe")
                    # Continue folding - encode child keys with this key as prefix
                    for (child_key, child_value) in value
                        encode_key_value_pair(
                            child_key,
                            child_value,
                            writer,
                            depth,
                            options,
                            prefix = full_key,
                            parent_obj = nothing,
                        )
                    end
                else
                    # Child can't be folded - stop folding here
                    push!(writer, depth, "$(encoded_key):")
                    nested_opts = EncodeOptions(
                        indent = options.indent,
                        delimiter = options.delimiter,
                        keyFolding = "off",
                        flattenDepth = options.flattenDepth,
                    )
                    encode_object(value, writer, depth + 1, nested_opts)
                end
            else
                # Multi-key object - stop folding
                push!(writer, depth, "$(encoded_key):")
                nested_opts = EncodeOptions(
                    indent = options.indent,
                    delimiter = options.delimiter,
                    keyFolding = "off",
                    flattenDepth = options.flattenDepth,
                )
                encode_object(value, writer, depth + 1, nested_opts)
            end
        else
            # Don't fold - encode normally
            # Output the key and then the nested object without folding
            push!(writer, depth, "$(encoded_key):")
            if !is_empty_object(value)
                # Don't pass options with folding enabled - just use normal encoding
                # to prevent re-folding in the nested object
                nested_opts = EncodeOptions(
                    indent = options.indent,
                    delimiter = options.delimiter,
                    keyFolding = "off",
                    flattenDepth = options.flattenDepth,
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
function encode_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
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

"""
    encode_tabular_array(key::Union{String, Nothing}, arr::JsonArray,
                        writer::LineWriter, depth::Int, options::EncodeOptions)

Encode an array of uniform objects in tabular format.
"""
function encode_tabular_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
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
function encode_array_of_arrays(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
    # Write parent header
    header = format_header(key, length(arr), options.delimiter)
    push!(writer, depth, header)

    # Write each inner array as a list item
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

"""
    encode_mixed_array(key::Union{String, Nothing}, arr::JsonArray,
                      writer::LineWriter, depth::Int, options::EncodeOptions)

Encode a mixed array in expanded list format.
"""
function encode_mixed_array(
    key::Union{String,Nothing},
    arr::JsonArray,
    writer::LineWriter,
    depth::Int,
    options::EncodeOptions,
)
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
        # Inline primitive array on the hyphen line
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
            # Complex array needs its own header with list marker
            header = format_header(nothing, length(value), options.delimiter)
            push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
            # Encode array contents at depth + 1
            for item in value
                encode_list_item(item, writer, depth + 1, options)
            end
        end
    elseif is_json_object(value)
        # Empty object
        if is_empty_object(value)
            push!(writer, depth, LIST_ITEM_MARKER[1:(end-1)])  # Just "-"
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
                # If it's an inline array (primitives), put it on the hyphen line
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
                    # Complex array - determine format (tabular vs list)
                    if is_tabular_array(first_value)
                        # Use tabular format for uniform objects
                        # Get field names from first object
                        first_obj = first_value[1]
                        fields = collect(keys(first_obj))
                        header = format_header(
                            first_key,
                            length(first_value),
                            options.delimiter,
                            fields,
                        )
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
                        # Write rows at depth + 2 (per spec §10: tabular rows inside list-item objects)
                        for obj in first_value
                            row_values = [
                                encode_primitive(obj[field], options.delimiter) for
                                field in fields
                            ]
                            row_str = join_encoded_values(row_values, options.delimiter)
                            push!(writer, depth + 2, row_str)
                        end
                    else
                        # Use list format for non-uniform objects or arrays of arrays
                        header =
                            format_header(first_key, length(first_value), options.delimiter)
                        push!(writer, depth, "$(LIST_ITEM_MARKER)$(header)")
                        # Encode array contents at depth + 2 (per spec §10: list items inside list-item objects)
                        for item in first_value
                            encode_list_item(item, writer, depth + 2, options)
                        end
                    end
                end
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
function encode(value; options::EncodeOptions = EncodeOptions())::String
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
