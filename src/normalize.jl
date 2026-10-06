function normalize_value(v)::JsonValue
    v === nothing && return nothing
    v isa Bool && return v
    v isa Number && return normalize_number(v)
    v isa AbstractString && return String(v)

    # Checked before `AbstractArray`, which would encode the pairs as strings.
    v isa AbstractVector && eltype(v) <: Pair && return normalize_pairs(v)
    v isa NamedTuple && return normalize_pairs(pairs(v))
    # Only a non-empty tuple of `Pair`s is an object; other tuples are arrays.
    v isa Tuple && !isempty(v) && all(x -> x isa Pair, v) && return normalize_pairs(v)
    v isa AbstractDict && return normalize_pairs(v)

    if v isa AbstractArray || v isa Tuple || v isa AbstractSet
        return JsonArray([normalize_value(item) for item in v])
    end
    return string(v)
end

normalize_pairs(pairs) = JsonObject(string(key) => normalize_value(value) for (key, value) in pairs)

function normalize_number(n::Number)::Union{Number,Nothing}
    n isa AbstractFloat || return n
    isfinite(n) || return nothing
    return n == 0 ? zero(n) : n
end

is_json_primitive(v) = v === nothing || v isa Bool || v isa Number || v isa AbstractString
is_json_object(v) = v isa AbstractDict
is_json_array(v) = v isa AbstractArray

is_array_of_primitives(array::AbstractArray) = all(is_json_primitive, array)
is_array_of_objects(array::AbstractArray) = all(is_json_object, array)
