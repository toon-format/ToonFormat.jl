"""
Encodes Julia values to TOON (Token-Oriented Object Notation) and decodes TOON back.
"""
module ToonFormat

include("types.jl")
include("string_utils.jl")
include("normalize.jl")
include("primitives.jl")
include("scanner.jl")
include("parser.jl")
include("encoder.jl")
include("decoder.jl")

export encode, decode, EncodeOptions, DecodeOptions, COMMA, TAB, PIPE

end # module
