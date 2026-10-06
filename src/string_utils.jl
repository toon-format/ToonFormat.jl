function escape_string(s::String)::String
    result = IOBuffer()
    for char in s
        if haskey(CHARS_TO_ESCAPE, char)
            write(result, CHARS_TO_ESCAPE[char])
        elseif char < ' '
            write(result, "\\u", string(UInt16(char); base = 16, pad = 4))
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
                error("Invalid escape sequence: backslash at end of string")
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
                error("Invalid escape sequence: \\$(next_char)")
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
        error("Invalid escape sequence: \\u must be followed by 4 hex digits")
    end
    code = parse(UInt16, String(hex); base = 16)
    if 0xd800 <= code <= 0xdfff
        error("Invalid escape sequence: \\u$(String(hex)) is a lone surrogate")
    end
    return Char(code)
end

function is_boolean_or_null_literal(s::AbstractString)::Bool
    return s == TRUE_LITERAL || s == FALSE_LITERAL || s == NULL_LITERAL
end

function needs_quoting(s::String, delimiter::Delimiter)::Bool
    if isempty(s)
        return true
    end

    # Only space and tab force quoting; `strip` would also count other Unicode whitespace.
    if first(s) in " \t" || last(s) in " \t"
        return true
    end

    if is_boolean_or_null_literal(s)
        return true
    end

    if occursin(NUMERIC_LIKE_PATTERN, s)
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
        if char < ' '
            return true
        end
    end

    if occursin(delimiter, s)
        return true
    end

    if startswith(s, "-") || startswith(s, "#")
        return true
    end

    return false
end

function is_valid_unquoted_key(s::String)::Bool
    return !isnothing(match(UNQUOTED_KEY_PATTERN, s))
end
