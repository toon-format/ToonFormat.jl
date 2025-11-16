# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Primitive encoding and formatting functions.
"""

"""
    encode_number(n::Number) -> String

Encode a number in canonical TOON format (no exponents, no trailing zeros).
"""
function encode_number(n::Number)::String
    if isa(n, Integer)
        return string(n)
    end

    # For floats, use minimal representation
    s = string(Float64(n))

    # Remove exponent notation if present
    if occursin('e', lowercase(s)) || occursin('E', s)
        # Convert to decimal form
        val = Float64(n)
        # Format with enough precision
        s = @sprintf("%.17g", val)
    end

    # Remove trailing zeros after decimal point
    if occursin('.', s)
        s = rstrip(s, '0')
        s = rstrip(s, '.')
    end

    return s
end

"""
    encode_primitive(value::JsonPrimitive, delimiter::Delimiter) -> String

Encode a primitive value as a TOON string.
"""
function encode_primitive(value::JsonPrimitive, delimiter::Delimiter)::String
    # null
    if value === nothing
        return NULL_LITERAL
    end

    # Boolean
    if isa(value, Bool)
        return value ? TRUE_LITERAL : FALSE_LITERAL
    end

    # Number
    if isa(value, Number)
        return encode_number(value)
    end

    # String
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

"""
    encode_key(key::String) -> String

Encode an object key. Quote if necessary.
"""
function encode_key(key::String)::String
    if is_valid_unquoted_key(key)
        return key
    end
    escaped = escape_string(key)
    return "$(DOUBLE_QUOTE)$(escaped)$(DOUBLE_QUOTE)"
end

"""
    format_header(key::Union{String, Nothing}, length::Int, delimiter::Delimiter,
                  fields::Union{Vector{String}, Nothing}=nothing) -> String

Format an array header.
"""
function format_header(key::Union{String, Nothing}, length::Int,
                      delimiter::Delimiter,
                      fields::Union{Vector{String}, Nothing}=nothing)::String
    result = ""

    # Add key if present
    if key !== nothing
        result *= encode_key(key)
    end

    # Add bracket segment
    result *= OPEN_BRACKET * string(length)

    # Add delimiter marker if not comma
    if delimiter == TAB
        result *= TAB
    elseif delimiter == PIPE
        result *= PIPE
    end

    result *= CLOSE_BRACKET

    # Add fields if present
    if fields !== nothing && !isempty(fields)
        result *= OPEN_BRACE
        encoded_fields = [encode_key(f) for f in fields]
        result *= join(encoded_fields, delimiter)
        result *= CLOSE_BRACE
    end

    result *= COLON

    return result
end

"""
    join_encoded_values(values::Vector{String}, delimiter::Delimiter) -> String

Join encoded primitive values with delimiter.
"""
function join_encoded_values(values::Vector{String}, delimiter::Delimiter)::String
    return join(values, delimiter)
end
