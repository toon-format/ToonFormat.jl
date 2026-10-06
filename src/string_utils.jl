const ESCAPES = Dict('\\' => "\\\\", '"' => "\\\"", '\n' => "\\n", '\r' => "\\r", '\t' => "\\t")
const UNESCAPES = Dict('\\' => '\\', '"' => '"', 'n' => '\n', 'r' => '\r', 't' => '\t')

const UNQUOTED_KEY_PATTERN = r"^[A-Za-z_][A-Za-z0-9_.]*$"
const NUMERIC_LIKE_PATTERN = r"^[+-]?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"

function escape_string(s::AbstractString)::String
    out = IOBuffer()
    for char in s
        if haskey(ESCAPES, char)
            write(out, ESCAPES[char])
        elseif char < ' '
            write(out, "\\u", string(UInt16(char); base = 16, pad = 4))
        else
            write(out, char)
        end
    end
    return String(take!(out))
end

quote_string(s::AbstractString) = "\"$(escape_string(s))\""

function unescape_string(s::AbstractString)::String
    out = IOBuffer()
    i = 1
    while i <= ncodeunits(s)
        char = s[i]
        if char != '\\'
            write(out, char)
            i = nextind(s, i)
            continue
        end

        i == ncodeunits(s) && error("Invalid escape sequence: backslash at end of string")
        escaped = s[i+1]
        if haskey(UNESCAPES, escaped)
            write(out, UNESCAPES[escaped])
            i += 2
        elseif escaped == 'u'
            write(out, unescape_unicode(s, i))
            i += 6
        else
            error("Invalid escape sequence: \\$escaped")
        end
    end
    return String(take!(out))
end

function unescape_unicode(s::AbstractString, i::Int)::Char
    hex = codeunits(s)[(i+2):min(i + 5, end)]
    if length(hex) != 4 || !all(byte -> isxdigit(Char(byte)), hex)
        error("Invalid escape sequence: \\u must be followed by 4 hex digits")
    end
    code = parse(UInt16, String(hex); base = 16)
    0xd800 <= code <= 0xdfff &&
        error("Invalid escape sequence: \\u$(String(hex)) is a lone surrogate")
    return Char(code)
end

function needs_quoting(s::AbstractString, delimiter::String)::Bool
    isempty(s) && return true
    # Only space and tab force quoting; `strip` would also count other Unicode whitespace.
    (first(s) in " \t" || last(s) in " \t") && return true
    s in ("true", "false", "null") && return true
    occursin(NUMERIC_LIKE_PATTERN, s) && return true
    any(char -> char in ":\"\\[]{}" || char < ' ', s) && return true
    occursin(delimiter, s) && return true
    return startswith(s, '-') || startswith(s, '#')
end

is_valid_unquoted_key(s::AbstractString) = occursin(UNQUOTED_KEY_PATTERN, s)
