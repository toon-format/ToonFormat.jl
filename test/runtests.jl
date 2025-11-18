# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

# Check if we should run only specific test suites
const TEST_GROUP = get(ENV, "TEST_GROUP", "all")

if TEST_GROUP == "aqua" || TEST_GROUP == "all"
    @testset "Aqua.jl Quality Assurance" begin
        include("test_aqua.jl")
    end
end

if TEST_GROUP == "all"
    @testset "TokenOrientedObjectNotation.jl - All Tests" begin
        # Include comprehensive test suites
        include("test_decoder.jl")
    include("test_encoder.jl")
    include("test_string_utils.jl")
    include("test_scanner.jl")
    include("test_security.jl")
    include("test_folding.jl")
    include("test_path_expansion.jl")
    include("test_array_headers.jl")
    include("test_delimiter_scoping.jl")
    include("test_indentation.jl")
    include("test_strict_mode.jl")
    include("test_root_forms.jl")
    include("test_object_encoding.jl")
    include("test_array_format_selection.jl")
    include("test_tabular_arrays.jl")
    include("test_objects_as_list_items.jl")
    include("test_options.jl")
    
    # Include comprehensive compliance test suites
    include("test_compliance_requirements.jl")
    include("test_compliance_roundtrip.jl")
    include("test_compliance_determinism.jl")
    include("test_compliance_edge_cases.jl")
    include("test_compliance_spec_examples.jl")
    include("test_compliance_errors.jl")
    
    # Include official TOON spec fixtures
    if isfile(joinpath(@__DIR__, "fixtures", "encode", "primitives.json"))
        include("test_spec_fixtures.jl")
    else
        @warn "TOON spec fixtures not found. Run: julia test/download_fixtures.jl"
    end
    end
    
    @testset "TokenOrientedObjectNotation.jl - Basic Tests" begin
        @testset "Primitive Encoding" begin
        # Null
        @test TokenOrientedObjectNotation.encode(nothing) == "null"

        # Booleans
        @test TokenOrientedObjectNotation.encode(true) == "true"
        @test TokenOrientedObjectNotation.encode(false) == "false"

        # Numbers
        @test TokenOrientedObjectNotation.encode(42) == "42"
        @test TokenOrientedObjectNotation.encode(3.14) == "3.14"
        @test TokenOrientedObjectNotation.encode(-0.0) == "0"

        # Strings
        @test TokenOrientedObjectNotation.encode("hello") == "hello"
        @test TokenOrientedObjectNotation.encode("") == "\"\""
        @test TokenOrientedObjectNotation.encode("hello world") == "hello world"
        @test TokenOrientedObjectNotation.encode("true") == "\"true\""
    end

    @testset "Object Encoding" begin
        # Simple object
        obj = Dict("name" => "Alice", "age" => 30)
        result = TokenOrientedObjectNotation.encode(obj)
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Nested object
        nested = Dict("user" => Dict("name" => "Bob"))
        result = TokenOrientedObjectNotation.encode(nested)
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Array Encoding" begin
        # Primitive array
        arr = [1, 2, 3]
        @test TokenOrientedObjectNotation.encode(arr) == "[3]: 1,2,3"

        # Empty array
        @test TokenOrientedObjectNotation.encode([]) == "[0]:"

        # Array of objects (tabular)
        tabular = [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]
        result = TokenOrientedObjectNotation.encode(tabular)
        # Dict doesn't preserve order in Julia, so check for both possibilities
        @test occursin("[2]{id,name}:", result) || occursin("[2]{name,id}:", result)
    end

    @testset "Primitive Decoding" begin
        # Null
        @test TokenOrientedObjectNotation.decode("null") === nothing

        # Booleans
        @test TokenOrientedObjectNotation.decode("true") === true
        @test TokenOrientedObjectNotation.decode("false") === false

        # Numbers
        @test TokenOrientedObjectNotation.decode("42") == 42
        @test TokenOrientedObjectNotation.decode("3.14") == 3.14

        # Strings
        @test TokenOrientedObjectNotation.decode("hello") == "hello"
        @test TokenOrientedObjectNotation.decode("\"\"") == ""
        @test TokenOrientedObjectNotation.decode("\"true\"") == "true"
    end

    @testset "Object Decoding" begin
        # Simple object
        input = "name: Alice\nage: 30"
        result = TokenOrientedObjectNotation.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30

        # Empty object
        @test TokenOrientedObjectNotation.decode("") == Dict{String, Any}()
    end

    @testset "Array Decoding" begin
        # Primitive array
        result = TokenOrientedObjectNotation.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]

        # Empty array
        result = TokenOrientedObjectNotation.decode("[0]:")
        @test result == []
    end

    @testset "Round-trip" begin
        # Object round-trip
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded["name"] == original["name"]
        @test decoded["age"] == original["age"]
        @test decoded["active"] == original["active"]

        # Array round-trip
        original = [1, 2, 3, 4, 5]
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded == original
    end

    @testset "String Escaping" begin
        # Test escape sequences
        @test TokenOrientedObjectNotation.encode("hello\nworld") == "\"hello\\nworld\""
        @test TokenOrientedObjectNotation.encode("quote: \"yes\"") == "\"quote: \\\"yes\\\"\""

        # Test unescape
        @test TokenOrientedObjectNotation.decode("\"hello\\nworld\"") == "hello\nworld"
        @test TokenOrientedObjectNotation.decode("\"quote: \\\"yes\\\"\"") == "quote: \"yes\""
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        arr = [1, 2, 3]
        options = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        result = TokenOrientedObjectNotation.encode(arr, options=options)
        @test occursin("[3\t]:", result)

        # Pipe delimiter
        options = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        result = TokenOrientedObjectNotation.encode(arr, options=options)
        @test occursin("[3|]:", result)
    end
    end
end
