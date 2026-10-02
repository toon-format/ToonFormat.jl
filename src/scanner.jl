function to_parsed_lines(input::String, indent_size::Int, strict::Bool)::ScanResult
    if isempty(input)
        return ScanResult(ParsedLine[], BlankLineInfo[])
    end

    lines = split(input, '\n')
    parsed_lines = ParsedLine[]
    blank_lines = BlankLineInfo[]

    for (line_num, raw_line) in enumerate(lines)
        if isempty(strip(raw_line))
            indent_count = count(c -> c == ' ', raw_line)
            depth =
                strict ? (indent_count ÷ indent_size) :
                floor(Int, indent_count / indent_size)
            push!(blank_lines, BlankLineInfo(line_num, indent_count, depth))
            continue
        end

        indent_count = 0
        for char in raw_line
            if char == ' '
                indent_count += 1
            else
                break
            end
        end

        if strict && occursin('\t', raw_line[1:min(indent_count+1, length(raw_line))])
            error("Tabs are not allowed in indentation (line $(line_num))")
        end

        if strict
            if indent_count % indent_size != 0
                error(
                    "Indentation must be a multiple of $(indent_size) spaces (line $(line_num))",
                )
            end
            depth = indent_count ÷ indent_size
        else
            depth = floor(Int, indent_count / indent_size)
        end

        content = strip(raw_line)

        push!(parsed_lines, ParsedLine(raw_line, depth, indent_count, content, line_num))
    end

    return ScanResult(parsed_lines, blank_lines)
end

function find_first_unquoted(s::AbstractString, char::Char)::Union{Int,Nothing}
    s = String(s)
    in_quotes = false
    i = firstindex(s)

    while i <= lastindex(s)
        c = s[i]
        if c == '"'
            in_quotes = !in_quotes
        elseif c == '\\' && in_quotes && i < lastindex(s)
            i = nextind(s, i)
        elseif !in_quotes && c == char
            return i
        end
        i = nextind(s, i)
    end

    return nothing
end

function parse_delimited_values(s::AbstractString, delimiter::Delimiter)::Vector{String}
    s = String(s)
    tokens = String[]
    current = IOBuffer()
    in_quotes = false
    i = firstindex(s)

    while i <= lastindex(s)
        char = s[i]

        if char == '"'
            in_quotes = !in_quotes
            write(current, char)
        elseif char == '\\' && in_quotes && i < lastindex(s)
            write(current, char)
            i = nextind(s, i)
            write(current, s[i])
        elseif !in_quotes && string(char) == delimiter
            push!(tokens, String(take!(current)))
            current = IOBuffer()
        else
            write(current, char)
        end

        i = nextind(s, i)
    end

    push!(tokens, String(take!(current)))

    return tokens
end

function parse_array_header(content::String)::Union{ArrayHeaderInfo,Nothing}
    bracket_start = find_first_unquoted(content, '[')
    if bracket_start === nothing
        return nothing
    end

    bracket_end = findnext(']', content, bracket_start)
    if bracket_end === nothing
        return nothing
    end

    key = bracket_start > 1 ? strip(content[1:prevind(content, bracket_start)]) : nothing
    if key !== nothing && isempty(key)
        key = nothing
    end
    if key !== nothing
        key = parse_key(key)
    end

    bracket_content = content[(bracket_start+1):prevind(content, bracket_end)]

    delimiter = COMMA
    length_str = bracket_content

    if endswith(bracket_content, TAB)
        delimiter = TAB
        length_str = chop(bracket_content)
    elseif endswith(bracket_content, PIPE)
        delimiter = PIPE
        length_str = chop(bracket_content)
    end

    arr_length = tryparse(Int, length_str)
    if arr_length === nothing || arr_length < 0
        error("Invalid array length in header")
    end

    fields = nothing
    remainder = strip(content[(bracket_end+1):end])

    if startswith(remainder, '{')
        brace_end = findfirst('}', remainder)
        if brace_end === nothing
            error("Unterminated fields segment in array header")
        end

        fields_content = remainder[2:prevind(remainder, brace_end)]
        fields = parse_delimited_values(fields_content, delimiter)

        fields = [parse_key(f) for f in fields]

        remainder = strip(remainder[(brace_end+1):end])
    end

    if !startswith(remainder, COLON)
        error("Array header must end with colon")
    end

    return ArrayHeaderInfo(key, arr_length, delimiter, fields)
end

function parse_key(token::AbstractString)::String
    token = strip(token)

    if startswith(token, DOUBLE_QUOTE)
        if !endswith(token, DOUBLE_QUOTE) || length(token) < 2
            error("Unterminated quoted key")
        end
        return unescape_string(chop(token; head = 1, tail = 1))
    end

    return token
end
