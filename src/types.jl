using OrderedCollections

const JsonPrimitive = Union{String,Number,Bool,Nothing}
const JsonObject = OrderedDict{String,Any}
const JsonArray = Vector{Any}
const JsonValue = Union{JsonPrimitive,JsonObject,JsonArray}

const DelimiterKey = String  # "comma", "tab", or "pipe"
const Delimiter = String     # actual delimiter character

Base.@kwdef struct EncodeOptions
    indentSize::Int = 2
    delimiter::Delimiter = DEFAULT_DELIMITER
end

Base.@kwdef struct DecodeOptions
    indentSize::Int = 2
    strict::Bool = true
end

struct ArrayHeaderInfo
    key::Union{String,Nothing}
    length::Int
    delimiter::Delimiter
    fields::Union{Vector{String},Nothing}
end

struct ParsedLine
    raw::String
    depth::Int
    indent::Int
    content::String
    lineNumber::Int
end

struct BlankLineInfo
    lineNumber::Int
    indent::Int
    depth::Int
end

struct ScanResult
    lines::Vector{ParsedLine}
    blankLines::Vector{BlankLineInfo}
end

mutable struct LineWriter
    lines::Vector{String}
    indent::Int

    LineWriter(indent::Int) = new(String[], indent)
end

function Base.push!(writer::LineWriter, depth::Int, content::String)
    indentation = " " ^ (depth * writer.indent)
    push!(writer.lines, indentation * content)
end

function Base.string(writer::LineWriter)::String
    return join(writer.lines, "\n")
end

mutable struct LineCursor
    lines::Vector{ParsedLine}
    blankLines::Vector{BlankLineInfo}
    position::Int

    LineCursor(lines::Vector{ParsedLine}, blankLines::Vector{BlankLineInfo}) =
        new(lines, blankLines, 1)
end

peek_line(cursor::LineCursor)::Union{ParsedLine,Nothing} =
    cursor.position <= length(cursor.lines) ? cursor.lines[cursor.position] : nothing

advance_line!(cursor::LineCursor) = (cursor.position += 1)

has_more_lines(cursor::LineCursor)::Bool = cursor.position <= length(cursor.lines)
