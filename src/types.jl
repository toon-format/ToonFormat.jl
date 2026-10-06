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

# A tabular field; `children` holds the fields of a nested field group.
struct FieldNode
    name::String
    children::Union{Vector{FieldNode},Nothing}
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
