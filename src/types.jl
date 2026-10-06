using OrderedCollections

const JsonPrimitive = Union{String,Number,Bool,Nothing}
const JsonObject = OrderedDict{String,Any}
const JsonArray = Vector{Any}
const JsonValue = Union{JsonPrimitive,JsonObject,JsonArray}

const COMMA = ","
const TAB = "\t"
const PIPE = "|"

"""
    EncodeOptions(; indentSize = 2, delimiter = COMMA)

Options for [`encode`](@ref): the spaces per indentation level, and the delimiter of
inline arrays and tabular rows – `COMMA`, `TAB`, or `PIPE`.
"""
Base.@kwdef struct EncodeOptions
    indentSize::Int = 2
    delimiter::String = COMMA
end

"""
    DecodeOptions(; indentSize = 2, strict = true)

Options for [`decode`](@ref): the spaces per indentation level, and whether to throw on
every strict-mode error of the spec instead of applying its non-strict leniencies.
"""
Base.@kwdef struct DecodeOptions
    indentSize::Int = 2
    strict::Bool = true
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
