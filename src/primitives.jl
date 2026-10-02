"""
    encode_number(n::Number) -> String

Encode a number in canonical TOON format (no exponents, no trailing zeros).
"""
function encode_number(n::Number)::String
    if isa(n, Integer)
        return string(n)
    end

    val = Float64(n)

    if isinteger(val)
        if val >= typemin(Int64) && val <= typemax(Int64)
            return string(Int64(val))
        else
            return @sprintf("%.0f", val)
        end
    end

    # `%.16g` keeps full precision without excess digits.
    s = @sprintf("%.16g", val)

    if occursin('e', lowercase(s)) || occursin('E', s)
        if abs(val) < 1.0
            # `%.17f` keeps every digit – the trailing zeros are stripped below.
            s = @sprintf("%.17f", val)
        else
            s = @sprintf("%.0f", val)
        end
    end

    if occursin('.', s)
        s = rstrip(s, '0')
        s = rstrip(s, '.')
    end

    return s
end

function encode_primitive(value::JsonPrimitive, delimiter::Delimiter)::String
    if value === nothing
        return NULL_LITERAL
    end

    if isa(value, Bool)
        return value ? TRUE_LITERAL : FALSE_LITERAL
    end

    if isa(value, Number)
        return encode_number(value)
    end

    if isa(value, AbstractString)
        str = String(value)
        if needs_quoting(str, delimiter)
            escaped = escape_string(str)
            return "$(DOUBLE_QUOTE)$(escaped)$(DOUBLE_QUOTE)"
        end
        return str
    end

    error("Unsupported primitive type: $(typeof(value))")
end

function encode_key(key::String)::String
    if is_valid_unquoted_key(key)
        return key
    end
    escaped = escape_string(key)
    return "$(DOUBLE_QUOTE)$(escaped)$(DOUBLE_QUOTE)"
end

function format_header(
    key::Union{String,Nothing},
    length::Int,
    delimiter::Delimiter,
    fields::Union{Vector{String},Nothing} = nothing,
)::String
    result = ""

    if key !== nothing
        result *= encode_key(key)
    end

    result *= OPEN_BRACKET * string(length)

    if delimiter == TAB
        result *= TAB
    elseif delimiter == PIPE
        result *= PIPE
    end

    result *= CLOSE_BRACKET

    if fields !== nothing && !isempty(fields)
        result *= OPEN_BRACE
        encoded_fields = [encode_key(f) for f in fields]
        result *= join(encoded_fields, delimiter)
        result *= CLOSE_BRACE
    end

    result *= COLON

    return result
end

function join_encoded_values(values::Vector{String}, delimiter::Delimiter)::String
    return join(values, delimiter)
end
