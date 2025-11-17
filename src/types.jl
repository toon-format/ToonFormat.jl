# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Type definitions for TOON format.
"""

using OrderedCollections

# JSON-compatible types
const JsonPrimitive = Union{String, Number, Bool, Nothing}
const JsonObject = OrderedDict{String, Any}
const JsonArray = Vector{Any}
const JsonValue = Union{JsonPrimitive, JsonObject, JsonArray}

# Delimiter types
const DelimiterKey = String  # "comma", "tab", or "pipe"
const Delimiter = String     # actual delimiter character

# Encode options
Base.@kwdef struct EncodeOptions
    indent::Int = 2
    delimiter::Delimiter = DEFAULT_DELIMITER
    keyFolding::String = "off"  # "off" or "safe"
    flattenDepth::Int = typemax(Int)
end

# Decode options
Base.@kwdef struct DecodeOptions
    indent::Int = 2
    strict::Bool = true
    expandPaths::String = "off"  # "off" or "safe"
end

# Array header information
struct ArrayHeaderInfo
    key::Union{String, Nothing}
    length::Int
    delimiter::Delimiter
    fields::Union{Vector{String}, Nothing}
end

# Parsed line information
struct ParsedLine
    raw::String
    depth::Int
    indent::Int
    content::String
    lineNumber::Int
end

# Blank line information
struct BlankLineInfo
    lineNumber::Int
    indent::Int
    depth::Int
end

# Scan result
struct ScanResult
    lines::Vector{ParsedLine}
    blankLines::Vector{BlankLineInfo}
end

# Line writer for encoding
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

# Line cursor for decoding
mutable struct LineCursor
    lines::Vector{ParsedLine}
    blankLines::Vector{BlankLineInfo}
    position::Int

    LineCursor(lines::Vector{ParsedLine}, blankLines::Vector{BlankLineInfo}) = new(lines, blankLines, 1)
end

# Helper functions for LineCursor (not extending Base)
peek_line(cursor::LineCursor)::Union{ParsedLine, Nothing} =
    cursor.position <= length(cursor.lines) ? cursor.lines[cursor.position] : nothing

advance_line!(cursor::LineCursor) = (cursor.position += 1)

has_more_lines(cursor::LineCursor)::Bool = cursor.position <= length(cursor.lines)
