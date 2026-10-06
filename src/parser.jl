struct FieldNode
    name::String
    children::Union{Vector{FieldNode},Nothing}
end

struct ArrayHeader
    key::Union{String,Nothing}
    length::Int
    delimiter::Char
    fields::Union{Vector{FieldNode},Nothing}
    keyed::Bool
    inline_values::Union{SubString{String},Nothing}
end

const BRACKET_LENGTH_PATTERN = r"^(?:0|[1-9][0-9]*)$"
const NUMBER_PATTERN = r"^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?$"

# Structural characters are ASCII, so the byte indices below always land on character boundaries.
byte_at(s::AbstractString, i::Int) = i <= ncodeunits(s) ? codeunit(s, i) : 0x00

slice(s::AbstractString, from::Int, to::Int) = SubString(s, from, prevind(s, to))

function find_closing_quote(s::AbstractString, start::Int)::Union{Int,Nothing}
    i = start + 1
    while i <= ncodeunits(s)
        byte = codeunit(s, i)
        if byte == UInt8('\\')
            i += 2
            continue
        end
        byte == UInt8('"') && return i
        i += 1
    end
    return nothing
end

function find_unquoted(s::AbstractString, char::Char, start::Int = 1)::Union{Int,Nothing}
    in_quotes = false
    i = start
    while i <= ncodeunits(s)
        byte = codeunit(s, i)
        if byte == UInt8('\\') && in_quotes
            i += 2
            continue
        end
        if byte == UInt8('"')
            in_quotes = !in_quotes
        elseif byte == UInt8(char) && !in_quotes
            return i
        end
        i += 1
    end
    return nothing
end

# Token trimming removes U+0020 only; any other whitespace belongs to the token.
trim_spaces(s::AbstractString) = strip(==(' '), s)

# Splits on `delimiter` outside quotes and, with `nested`, outside braces.
function split_unquoted(s::AbstractString, delimiter::Char; nested::Bool = false)
    segments = SubString{String}[]
    in_quotes = false
    brace_depth = 0
    segment_start = 1
    i = 1
    while i <= ncodeunits(s)
        byte = codeunit(s, i)
        if byte == UInt8('\\') && in_quotes
            i += 2
            continue
        end
        if byte == UInt8('"')
            in_quotes = !in_quotes
        elseif !in_quotes && nested && byte == UInt8('{')
            brace_depth += 1
        elseif !in_quotes && nested && byte == UInt8('}')
            brace_depth -= 1
        elseif !in_quotes && brace_depth == 0 && byte == UInt8(delimiter)
            push!(segments, slice(s, segment_start, i))
            segment_start = i + 1
        end
        i += 1
    end
    push!(segments, SubString(s, segment_start))
    return segments
end

parse_delimited_values(s::AbstractString, delimiter::Char) =
    isempty(s) ? SubString{String}[] : trim_spaces.(split_unquoted(s, delimiter))

function find_matching_brace(s::AbstractString, start::Int)::Union{Int,Nothing}
    in_quotes = false
    depth = 0
    i = start
    while i <= ncodeunits(s)
        byte = codeunit(s, i)
        if byte == UInt8('\\') && in_quotes
            i += 2
            continue
        end
        if byte == UInt8('"')
            in_quotes = !in_quotes
        elseif !in_quotes && byte == UInt8('{')
            depth += 1
        elseif !in_quotes && byte == UInt8('}')
            depth -= 1
            depth == 0 && return i
        end
        i += 1
    end
    return nothing
end

"""
    parse_array_header(content, strict) -> Union{ArrayHeader,Nothing}

Returns `nothing` for a line that is no array header. A line that is one but breaks the
header grammar throws in strict mode and returns `nothing` otherwise, so non-strict
decoding reads it as a key-value line.
"""
function parse_array_header(content::AbstractString, strict::Bool)::Union{ArrayHeader,Nothing}
    invalid(reason) = strict ? error(reason) : nothing

    leading = ncodeunits(content) - ncodeunits(lstrip(content))
    if byte_at(content, leading + 1) == UInt8('"')
        closing_quote = find_closing_quote(content, leading + 1)
        if closing_quote === nothing || byte_at(content, closing_quote + 1) != UInt8('[')
            return nothing
        end
        bracket_start = closing_quote + 1
    else
        bracket_start = find_unquoted(content, '[')
        bracket_start === nothing && return nothing
    end

    # A header needs a colon, and its key can't contain one. Past this check, a grammar
    # failure makes the line an invalid header instead of a key-value line.
    first_colon = find_unquoted(content, ':')
    (first_colon === nothing || first_colon < bracket_start) && return nothing

    bracket_end = find_unquoted(content, ']', bracket_start)
    bracket_end === nothing && return invalid("Unterminated bracket segment")

    fields_end = bracket_end + 1
    brace_start = find_unquoted(content, '{', bracket_end)
    colon_after_bracket = find_unquoted(content, ':', bracket_end)
    has_field_list =
        brace_start !== nothing && colon_after_bracket !== nothing && brace_start < colon_after_bracket
    if has_field_list && brace_start > bracket_end + 1
        gap = strip(slice(content, bracket_end + 1, brace_start))
        return invalid(
            isempty(gap) ? "Unexpected whitespace between bracket segment and field list" :
            "Unexpected content \"$gap\" between bracket segment and field list",
        )
    end
    brace_end = has_field_list ? find_matching_brace(content, brace_start) : nothing
    brace_end === nothing || (fields_end = brace_end + 1)

    colon = find_unquoted(content, ':', max(bracket_end, fields_end))
    colon === nothing && return invalid("Missing colon after array header")
    if colon > max(bracket_end + 1, fields_end)
        gap = strip(slice(content, max(bracket_end + 1, fields_end), colon))
        return invalid(
            isempty(gap) ? "Unexpected whitespace between bracket segment and colon" :
            "Unexpected content \"$gap\" between bracket segment and colon",
        )
    end

    key = nothing
    if bracket_start > 1
        raw_key = slice(content, 1, bracket_start)
        # Trimming here would silently turn `foo [2]:` into a header with key `foo`.
        raw_key == rstrip(raw_key) ||
            return invalid("Unexpected whitespace between key and bracket segment")
        key = startswith(raw_key, '"') ? parse_string_literal(raw_key) : String(raw_key)
    end

    bracket = parse_bracket_segment(slice(content, bracket_start + 1, bracket_end))
    bracket === nothing && return invalid(
        "Invalid array length in \"$(slice(content, bracket_start, bracket_end + 1))\" (expected a non-negative integer with no leading zeros)",
    )
    declared_length, delimiter, keyed = bracket

    fields = nothing
    if brace_end !== nothing
        fields_content = slice(content, brace_start + 1, brace_end)
        for other in (',', '\t', '|')
            if other != delimiter && find_unquoted(fields_content, other) !== nothing
                return invalid(
                    "Header delimiter mismatch: the bracket declares $(repr(delimiter)) but the field list contains an unquoted $(repr(other))",
                )
            end
        end
        fields = try
            parse_field_entries(fields_content, delimiter)
        catch e
            e isa ErrorException || rethrow()
            return invalid(e.msg)
        end
    end

    duplicate = fields === nothing ? nothing : find_duplicate_field_name(fields)
    duplicate_reason = "Duplicate field name \"$duplicate\" in field list"
    keyed && fields === nothing && return invalid("Keyed header requires a field list")

    inline_values = trim_spaces(SubString(content, colon + 1))
    # A fields-bearing header carries no inline content; decoding it as an inline array would drop the fields.
    if fields !== nothing && !isempty(inline_values)
        return invalid(
            duplicate === nothing ? "Unexpected content after fields-bearing header colon" :
            duplicate_reason,
        )
    end
    # Non-strict mode resolves duplicate field names by last-write-wins.
    strict && duplicate !== nothing && error(duplicate_reason)

    return ArrayHeader(
        key,
        declared_length,
        delimiter,
        fields,
        keyed,
        isempty(inline_values) ? nothing : inline_values,
    )
end

function parse_bracket_segment(segment::AbstractString)
    delimiter = ','
    if endswith(segment, '\t') || endswith(segment, '|')
        delimiter = last(segment)
        segment = chop(segment)
    end

    # Only a colon between the length and the optional delimiter symbol marks a keyed header.
    keyed = endswith(segment, ':')
    keyed && (segment = chop(segment))

    occursin(BRACKET_LENGTH_PATTERN, segment) || return nothing
    # A length beyond the integer range still forms a header; no count can match it.
    return something(tryparse(Int, segment), typemax(Int)), delimiter, keyed
end

function parse_field_entries(content::AbstractString, delimiter::Char)::Vector{FieldNode}
    return map(split_unquoted(content, delimiter; nested = true)) do entry
        entry = trim_spaces(entry)
        isempty(entry) && error("Empty field name in field list")

        group_start = find_unquoted(entry, '{')
        group_start === nothing && return FieldNode(parse_string_literal(entry), nothing)

        name = slice(entry, 1, group_start)
        isempty(name) && error("Missing field name before nested field group")
        name == rstrip(name) || error("Unexpected whitespace before nested field group")

        group_end = find_matching_brace(entry, group_start)
        group_end === nothing && error("Unmatched brace in field list")
        group_end == ncodeunits(entry) || error("Unexpected content after nested field group")

        children = parse_field_entries(slice(entry, group_start + 1, group_end), delimiter)
        return FieldNode(parse_string_literal(name), children)
    end
end

function find_duplicate_field_name(fields::Vector{FieldNode})::Union{String,Nothing}
    seen = Set{String}()
    for field in fields
        field.name in seen && return field.name
        push!(seen, field.name)
        if field.children !== nothing
            duplicate = find_duplicate_field_name(field.children)
            duplicate === nothing || return duplicate
        end
    end
    return nothing
end

count_leaf_fields(fields::Vector{FieldNode}) =
    sum(field -> field.children === nothing ? 1 : count_leaf_fields(field.children), fields; init = 0)

function parse_primitive_token(token::AbstractString)::JsonPrimitive
    token = trim_spaces(token)
    isempty(token) && return ""
    startswith(token, '"') && return parse_string_literal(token)
    token == TRUE_LITERAL && return true
    token == FALSE_LITERAL && return false
    token == NULL_LITERAL && return nothing
    occursin(NUMBER_PATTERN, token) && return parse_number(token)
    return String(token)
end

# Numbers outside the `Int64` and finite `Float64` domain decode as strings, losslessly.
function parse_number(token::AbstractString)::Union{Int,Float64,String}
    if !any(in(".eE"), token)
        number = tryparse(Int, token)
        return number === nothing ? String(token) : number
    end
    number = tryparse(Float64, token)
    (number === nothing || !isfinite(number)) && return String(token)
    return number == 0 ? 0.0 : number
end

function parse_string_literal(token::AbstractString)::String
    token = trim_spaces(token)
    startswith(token, '"') || return String(token)

    closing_quote = find_closing_quote(token, 1)
    closing_quote === nothing && error("Unterminated string: missing closing quote")
    closing_quote == ncodeunits(token) || error("Unexpected characters after closing quote")
    return unescape_string(slice(token, 2, closing_quote))
end

"""
    parse_key_token(content) -> (key, value_start)

Reads the key before the first unquoted colon and returns it with the byte index right
after that colon.
"""
function parse_key_token(content::AbstractString)
    if startswith(content, '"')
        closing_quote = find_closing_quote(content, 1)
        closing_quote === nothing && error("Unterminated quoted key")
        colon = closing_quote + 1
        while byte_at(content, colon) == UInt8(' ')
            colon += 1
        end
        byte_at(content, colon) == UInt8(':') || error("Missing colon after key")
        return unescape_string(slice(content, 2, closing_quote)), colon + 1
    end

    # A raw scan would cut `a "b:c" d: 1` at the quoted colon and split the key in two.
    colon = find_unquoted(content, ':')
    colon === nothing && error("Missing colon after key")
    return String(trim_spaces(slice(content, 1, colon))), colon + 1
end

is_key_value_content(content::AbstractString) = find_unquoted(content, ':') !== nothing

is_array_header_content(content::AbstractString) =
    startswith(lstrip(content), '[') && is_key_value_content(content)
