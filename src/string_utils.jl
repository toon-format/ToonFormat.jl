function escape_string(s::String)::String
    result = IOBuffer()
    for char in s
        if haskey(CHARS_TO_ESCAPE, char)
            write(result, CHARS_TO_ESCAPE[char])
        else
            write(result, char)
        end
    end
    return String(take!(result))
end

"""
    unescape_string(s::AbstractString) -> String

Unescape a TOON string. Throws an error if invalid escape sequences are found.
"""
function unescape_string(s::AbstractString)::String
    s_str = String(s)
    result = IOBuffer()
    i = firstindex(s_str)
    while i <= lastindex(s_str)
        c = s_str[i]
        if c == '\\'
            if i == lastindex(s_str)
                throw(ArgumentError("Unterminated escape sequence at end of string"))
            end

            next_i = nextind(s_str, i)
            next_char = s_str[next_i]
            if haskey(ESCAPE_CHARS, next_char)
                write(result, ESCAPE_CHARS[next_char])
                i = nextind(s_str, next_i)
            elseif next_char == 'u'
                write(result, unescape_unicode(s_str, i))
                i += 6
            else
                throw(ArgumentError("Invalid escape sequence: \\$(next_char)"))
            end
        else
            write(result, c)
            i = nextind(s_str, i)
        end
    end
    return String(take!(result))
end

function unescape_unicode(s::String, i::Int)::Char
    hex = codeunits(s)[(i+2):min(i + 5, end)]
    if length(hex) != 4 || !all(b -> isxdigit(Char(b)), hex)
        throw(ArgumentError("Invalid escape sequence: \\u must be followed by 4 hex digits"))
    end
    code = parse(UInt16, String(hex); base = 16)
    if 0xd800 <= code <= 0xdfff
        throw(ArgumentError("Invalid escape sequence: \\u$(String(hex)) is a lone surrogate"))
    end
    return Char(code)
end

function is_numeric_literal(s::AbstractString)::Bool
    return !isnothing(match(NUMERIC_PATTERN, String(s)))
end

function has_leading_zeros(s::AbstractString)::Bool
    return !isnothing(match(LEADING_ZERO_PATTERN, String(s)))
end

function is_boolean_or_null_literal(s::AbstractString)::Bool
    return s == TRUE_LITERAL || s == FALSE_LITERAL || s == NULL_LITERAL
end

function needs_quoting(s::String, delimiter::Delimiter)::Bool
    if isempty(s)
        return true
    end

    if s != strip(s)
        return true
    end

    if is_boolean_or_null_literal(s)
        return true
    end

    if is_numeric_literal(s) || has_leading_zeros(s)
        return true
    end

    if occursin(COLON, s) || occursin(DOUBLE_QUOTE, s) || occursin(BACKSLASH, s)
        return true
    end

    if occursin(OPEN_BRACKET, s) ||
       occursin(CLOSE_BRACKET, s) ||
       occursin(OPEN_BRACE, s) ||
       occursin(CLOSE_BRACE, s)
        return true
    end

    for char in s
        if Int(char) < 32 || Int(char) == 127
            return true
        end
    end

    if occursin(delimiter, s)
        return true
    end

    if s == "-" || startswith(s, "-")
        return true
    end

    return false
end

function is_valid_unquoted_key(s::String)::Bool
    return !isnothing(match(UNQUOTED_KEY_PATTERN, s))
end

function find_first_unquoted(s::String, target::Char)::Union{Int,Nothing}
    in_quotes = false
    skip_next = false

    for (idx, char) in pairs(s)
        if skip_next
            skip_next = false
            continue
        end

        if char == '\\'
            skip_next = true
            continue
        elseif char == '"'
            in_quotes = !in_quotes
        elseif char == target && !in_quotes
            return idx
        end
    end

    return nothing
end
