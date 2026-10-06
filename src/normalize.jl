function normalize_value(v)::JsonValue
    if v === nothing
        return nothing
    end

    if isa(v, Bool)
        return v
    end

    if isa(v, Number)
        return normalize_number(v)
    end

    if isa(v, AbstractString)
        return String(v)
    end

    # Checked before `AbstractArray`, which would encode the pairs as strings.
    if isa(v, AbstractVector) && eltype(v) <: Pair
        result = JsonObject()
        for (k, val) in v
            key_str = string(k)
            result[key_str] = normalize_value(val)
        end
        return result
    end

    if isa(v, NamedTuple)
        result = JsonObject()
        for (k, val) in pairs(v)
            key_str = string(k)
            result[key_str] = normalize_value(val)
        end
        return result
    end

    # Checked before the general `Tuple` branch – only a non-empty tuple of `Pair`s is an object.
    if isa(v, Tuple) && !isempty(v) && all(x -> isa(x, Pair), v)
        result = JsonObject()
        for (k, val) in v
            key_str = string(k)
            result[key_str] = normalize_value(val)
        end
        return result
    end

    if isa(v, AbstractArray)
        return JsonArray([normalize_value(item) for item in v])
    end

    if isa(v, AbstractDict)
        result = JsonObject()
        for (k, val) in v
            key_str = string(k)
            result[key_str] = normalize_value(val)
        end
        return result
    end

    if isa(v, Tuple)
        return JsonArray([normalize_value(item) for item in v])
    end

    if isa(v, AbstractSet)
        return JsonArray([normalize_value(item) for item in v])
    end

    return string(v)
end

function normalize_number(n::Number)::Union{Number,Nothing}
    if isa(n, AbstractFloat)
        if isnan(n) || isinf(n)
            return nothing
        end
        if n == 0.0 && signbit(n)
            return 0.0
        end
    end
    return n
end

function is_json_primitive(v)::Bool
    return v === nothing || isa(v, Bool) || isa(v, Number) || isa(v, AbstractString)
end

function is_json_object(v)::Bool
    return isa(v, AbstractDict)
end

function is_json_array(v)::Bool
    return isa(v, AbstractArray)
end

function is_empty_object(v)::Bool
    return isa(v, AbstractDict) && isempty(v)
end

function is_array_of_primitives(arr::AbstractArray)::Bool
    return all(is_json_primitive, arr)
end

function is_array_of_objects(arr::AbstractArray)::Bool
    return all(is_json_object, arr)
end

function is_array_of_arrays(arr::AbstractArray)::Bool
    return all(is_json_array, arr)
end
