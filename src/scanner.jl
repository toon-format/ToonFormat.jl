struct ParsedLine
    content::SubString{String}
    depth::Int
    number::Int
end

"""
    scan_lines(input, indent_size, strict) -> (lines, blank_line_numbers)

Splits `input` into content lines with their depth. Comment lines are dropped, and
blank lines only leave their line numbers behind for the strict blank-line checks.
"""
function scan_lines(input::AbstractString, indent_size::Int, strict::Bool)
    lines = ParsedLine[]
    blank_line_numbers = Int[]

    for (number, raw) in enumerate(split(String(input), '\n'))
        if number == 1 && startswith(raw, '\ufeff')
            raw = chop(raw; head = 1, tail = 0)
        end
        # A trailing carriage return belongs to the CRLF terminator, not to the content.
        if endswith(raw, '\r')
            raw = chop(raw)
        end

        whitespace = SubString(raw, 1, something(findfirst(!in(" \t"), raw), ncodeunits(raw) + 1) - 1)
        first_tab = findfirst(==('\t'), whitespace)

        # Strict rejects tab indentation below, so only the spaces before the first tab are indentation there.
        indent = strict && first_tab !== nothing ? first_tab - 1 : ncodeunits(whitespace)
        # Non-strict input may indent with tabs, and each tab counts as one depth level.
        tab_indent = strict ? 0 : count(==('\t'), whitespace)
        depth = (indent - tab_indent) ÷ indent_size + tab_indent

        content = rstrip(==(' '), SubString(raw, indent + 1))
        # Only spaces may precede the comment marker, so a tab in the indentation rules the line out.
        first_tab === nothing && startswith(content, '#') && continue

        if isempty(content)
            push!(blank_line_numbers, number)
            continue
        end

        if strict
            first_tab === nothing ||
                error("Line $number: Tabs are not allowed in indentation in strict mode")
            indent % indent_size == 0 || error(
                "Line $number: Indentation must be an exact multiple of $indent_size, but found $indent spaces",
            )
        end

        push!(lines, ParsedLine(content, depth, number))
    end

    return lines, blank_line_numbers
end
