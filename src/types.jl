using OrderedCollections

const JsonPrimitive = Union{String,Number,Bool,Nothing}
const JsonObject = OrderedDict{String,Any}
const JsonArray = Vector{Any}
const JsonValue = Union{JsonPrimitive,JsonObject,JsonArray}

const COMMA = ","
const TAB = "\t"
const PIPE = "|"

check_indent_size(indentSize) =
    indentSize >= 1 || throw(ArgumentError("indentSize must be at least 1, got $indentSize"))

"""
    EncodeOptions(; indentSize = 2, delimiter = COMMA)

Options for [`encode`](@ref): the spaces per indentation level, and the delimiter of
inline arrays and tabular rows – `COMMA`, `TAB`, or `PIPE`.
"""
Base.@kwdef struct EncodeOptions
    indentSize::Int = 2
    delimiter::String = COMMA

    function EncodeOptions(indentSize, delimiter)
        check_indent_size(indentSize)
        delimiter in (COMMA, TAB, PIPE) ||
            throw(ArgumentError("Invalid delimiter $(repr(delimiter)); use COMMA, TAB, or PIPE"))
        return new(indentSize, delimiter)
    end
end

"""
    DecodeOptions(; indentSize = 2, strict = true)

Options for [`decode`](@ref): the spaces per indentation level, and whether to throw on
every decode error of the spec. `strict = false` applies the spec's five non-strict
recoveries instead – a declared length is advisory, duplicate keys keep the last value, tabs
and uneven spaces count as indentation, blank lines inside an array or keyed object are
skipped, and a block indented too deep reads at its own depth – and throws on every other
error.
"""
Base.@kwdef struct DecodeOptions
    indentSize::Int = 2
    strict::Bool = true

    function DecodeOptions(indentSize, strict)
        check_indent_size(indentSize)
        return new(indentSize, strict)
    end
end

# A tabular field; `children` holds the fields of a nested field group.
struct FieldNode
    name::String
    children::Union{Vector{FieldNode},Nothing}
end

struct LineWriter
    lines::Vector{String}
    indent::Int
end

LineWriter(indent::Int) = LineWriter(String[], indent)

Base.push!(writer::LineWriter, depth::Int, content::AbstractString) =
    push!(writer.lines, " "^(depth * writer.indent) * content)

Base.string(writer::LineWriter) = join(writer.lines, '\n')
