"""
    encode_number(n::Number) -> String

Prints `n` with the fewest digits that decode back to it: in plain decimal from `1e-6`
up to `1e21`, in exponent form beyond that range.
"""
function encode_number(n::Number)::String
    n isa Integer && return string(n)

    x = Float64(n)
    x == 0 && return "0"

    # Julia prints the shortest round-trip digits, e.g. `0.1` or `1.2345e-7`.
    mantissa, exponent = let parts = split(repr(abs(x)), 'e')
        parts[1], length(parts) == 2 ? parse(Int, parts[2]) : 0
    end
    integer_part, fraction_part = split(mantissa, '.')
    digits = integer_part * fraction_part
    leading_zeros = findfirst(!=('0'), digits) - 1
    digits = rstrip(digits[(leading_zeros+1):end], '0')
    point = length(integer_part) + exponent - leading_zeros
    sign = x < 0 ? "-" : ""

    if abs(x) < 1e-6 || abs(x) >= 1e21
        fraction = length(digits) > 1 ? "." * digits[2:end] : ""
        return "$sign$(digits[1])$(fraction)e$(point > 0 ? "+" : "-")$(abs(point - 1))"
    end
    point <= 0 && return "$(sign)0.$("0" ^ -point)$digits"
    point >= length(digits) && return "$sign$digits$("0" ^ (point - length(digits)))"
    return "$sign$(digits[1:point]).$(digits[(point+1):end])"
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
