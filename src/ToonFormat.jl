"""
Encodes Julia values to TOON (Token-Oriented Object Notation) and decodes TOON back.
"""
module ToonFormat

using Printf

# Include all source files
include("constants.jl")
include("types.jl")
include("string_utils.jl")
include("normalize.jl")
include("primitives.jl")
include("scanner.jl")
include("encoder.jl")
include("decoder.jl")

# Export main functions
export encode, decode

# Export types
export EncodeOptions, DecodeOptions

# Export commonly used constants
export COMMA, TAB, PIPE

end # module
