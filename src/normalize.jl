# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Value normalization for TOON encoding.
"""

"""
    normalize_value(v) -> JsonValue

Normalize a value to the JSON data model.
"""
function normalize_value(v)::JsonValue
    # Nothing maps to nothing (JSON null)
    if v === nothing
        return nothing
    end

    # Booleans
    if isa(v, Bool)
        return v
    end

    # Numbers
    if isa(v, Number)
        return normalize_number(v)
    end

    # Strings
    if isa(v, AbstractString)
        return String(v)
    end

    # Arrays and vectors
    if isa(v, AbstractArray)
        return JsonArray([normalize_value(item) for item in v])
    end

    # Dictionaries
    if isa(v, AbstractDict)
        result = JsonObject()
        for (k, val) in v
            key_str = string(k)
            result[key_str] = normalize_value(val)
        end
        return result
    end

    # Tuples
    if isa(v, Tuple)
        return JsonArray([normalize_value(item) for item in v])
    end

    # Sets
    if isa(v, AbstractSet)
        return JsonArray([normalize_value(item) for item in v])
    end

    # Default: try to convert to string
    return string(v)
end

"""
    normalize_number(n::Number) -> Union{Number, Nothing}

Normalize a number according to TOON specification.
NaN and Infinity map to null.
-0.0 is normalized to 0.0.
"""
function normalize_number(n::Number)::Union{Number, Nothing}
    if isa(n, AbstractFloat)
        if isnan(n) || isinf(n)
            return nothing
        end
        # Normalize -0 to 0 (check sign bit to distinguish -0.0 from 0.0)
        if n == 0.0 && signbit(n)
            return 0.0
        end
    end
    return n
end

"""
    is_json_primitive(v) -> Bool

Check if a value is a JSON primitive.
"""
function is_json_primitive(v)::Bool
    return v === nothing || isa(v, Bool) || isa(v, Number) || isa(v, AbstractString)
end

"""
    is_json_object(v) -> Bool

Check if a value is a JSON object.
"""
function is_json_object(v)::Bool
    return isa(v, AbstractDict)
end

"""
    is_json_array(v) -> Bool

Check if a value is a JSON array.
"""
function is_json_array(v)::Bool
    return isa(v, AbstractArray)
end

"""
    is_empty_object(v) -> Bool

Check if a value is an empty object.
"""
function is_empty_object(v)::Bool
    return isa(v, AbstractDict) && isempty(v)
end

"""
    is_array_of_primitives(arr::AbstractArray) -> Bool

Check if an array contains only primitives.
"""
function is_array_of_primitives(arr::AbstractArray)::Bool
    return all(is_json_primitive, arr)
end

"""
    is_array_of_objects(arr::AbstractArray) -> Bool

Check if an array contains only objects.
"""
function is_array_of_objects(arr::AbstractArray)::Bool
    return all(is_json_object, arr)
end

"""
    is_array_of_arrays(arr::AbstractArray) -> Bool

Check if an array contains only arrays.
"""
function is_array_of_arrays(arr::AbstractArray)::Bool
    return all(is_json_array, arr)
end

"""
    is_tabular_array(arr::AbstractArray) -> Bool

Check if an array qualifies for tabular format:
- All elements are objects
- All objects have the same keys
- All values are primitives
"""
function is_tabular_array(arr::AbstractArray)::Bool
    if isempty(arr) || !is_array_of_objects(arr)
        return false
    end

    # Get keys from first object
    first_obj = arr[1]
    if !isa(first_obj, AbstractDict)
        return false
    end

    first_keys = Set(keys(first_obj))

    # Check all objects have same keys and all values are primitives
    for obj in arr
        if !isa(obj, AbstractDict)
            return false
        end

        # Check same keys
        if Set(keys(obj)) != first_keys
            return false
        end

        # Check all values are primitives
        if !all(is_json_primitive, values(obj))
            return false
        end
    end

    return true
end
