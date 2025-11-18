"""
Test TokenOrientedObjectNotation.jl against official TOON specification test fixtures
https://github.com/toon-format/spec/tree/main/tests
"""

using Test
using TokenOrientedObjectNotation
using JSON3

const FIXTURES_DIR = joinpath(@__DIR__, "fixtures")

# Helper to load fixture file
function load_fixture(category::String, filename::String)
    path = joinpath(FIXTURES_DIR, category, filename)
    if !isfile(path)
        error("Fixture file not found: $path\nRun: julia test/download_fixtures.jl")
    end
    return JSON3.read(read(path, String))
end

# Helper to convert JSON3 objects to native Julia types for comparison
function normalize_json(val)
    if val isa JSON3.Object
        return TokenOrientedObjectNotation.JsonObject(string(k) => normalize_json(v) for (k, v) in pairs(val))
    elseif val isa JSON3.Array || val isa Vector
        return [normalize_json(v) for v in val]
    else
        return val
    end
end

# Helper to parse options
function parse_encode_options(opts)
    if isnothing(opts)
        return EncodeOptions()
    end
    
    kwargs = Dict{Symbol, Any}()
    haskey(opts, :delimiter) && (kwargs[:delimiter] = opts.delimiter)
    haskey(opts, :indent) && (kwargs[:indent] = opts.indent)
    haskey(opts, :keyFolding) && (kwargs[:keyFolding] = opts.keyFolding)
    haskey(opts, :flattenDepth) && (kwargs[:flattenDepth] = opts.flattenDepth)
    
    return EncodeOptions(; kwargs...)
end

function parse_decode_options(opts)
    if isnothing(opts)
        return DecodeOptions()
    end
    
    kwargs = Dict{Symbol, Any}()
    haskey(opts, :indent) && (kwargs[:indent] = opts.indent)
    haskey(opts, :strict) && (kwargs[:strict] = opts.strict)
    haskey(opts, :expandPaths) && (kwargs[:expandPaths] = opts.expandPaths)
    
    return DecodeOptions(; kwargs...)
end

@testset "TOON Spec Fixtures" begin
    
    @testset "Encode Fixtures" begin
        encode_files = [
            "primitives.json",
            "objects.json",
            "arrays-primitive.json",
            "arrays-tabular.json",
            "arrays-nested.json",
            "arrays-objects.json",
            "delimiters.json",
            "whitespace.json",
            "key-folding.json"
        ]
        
        for filename in encode_files
            fixture = load_fixture("encode", filename)
            
            @testset "$(fixture.description)" begin
                for test in fixture.tests
                    @testset "$(test.name)" begin
                        input = normalize_json(test.input)
                        expected = test.expected
                        options = parse_encode_options(get(test, :options, nothing))
                        
                        if get(test, :shouldError, false)
                            @test_throws Exception TokenOrientedObjectNotation.encode(input; options=options)
                        else
                            result = TokenOrientedObjectNotation.encode(input; options=options)
                            @test result == expected
                        end
                    end
                end
            end
        end
    end
    
    @testset "Decode Fixtures" begin
        decode_files = [
            "primitives.json",
            "numbers.json",
            "objects.json",
            "arrays-primitive.json",
            "arrays-tabular.json",
            "arrays-nested.json",
            "delimiters.json",
            "whitespace.json",
            "root-form.json",
            "validation-errors.json",
            "indentation-errors.json",
            "blank-lines.json",
            "path-expansion.json"
        ]
        
        for filename in decode_files
            fixture = load_fixture("decode", filename)
            
            @testset "$(fixture.description)" begin
                for test in fixture.tests
                    @testset "$(test.name)" begin
                        input = test.input
                        expected = normalize_json(test.expected)
                        options = parse_decode_options(get(test, :options, nothing))
                        
                        if get(test, :shouldError, false)
                            @test_throws Exception TokenOrientedObjectNotation.decode(input; options=options)
                        else
                            result = TokenOrientedObjectNotation.decode(input; options=options)
                            @test result == expected
                        end
                    end
                end
            end
        end
    end
end
