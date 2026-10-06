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
    value === nothing && return "null"
    value isa Bool && return string(value)
    value isa Number && return encode_number(value)
    return needs_quoting(value, delimiter) ? quote_string(value) : String(value)
end

encode_key(key::String) = is_valid_unquoted_key(key) ? key : quote_string(key)

function format_header(
    key::Union{String,Nothing},
    len::Int,
    delimiter::Delimiter,
    fields::Union{Vector{FieldNode},Nothing} = nothing;
    keyed::Bool = false,
)::String
    header = key === nothing ? "" : encode_key(key)
    header *= "[$len$(keyed ? ":" : "")$(delimiter == COMMA ? "" : delimiter)]"
    fields === nothing || (header *= "{$(format_fields(fields, delimiter))}")
    return header * ":"
end

format_fields(fields::Vector{FieldNode}, delimiter::Delimiter) = join(
    (
        encode_key(field.name) *
        (field.children === nothing ? "" : "{$(format_fields(field.children, delimiter))}") for
        field in fields
    ),
    delimiter,
)
