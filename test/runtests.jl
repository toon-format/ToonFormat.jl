# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

# Check if we should run only specific test suites
const TEST_GROUP = get(ENV, "TEST_GROUP", "all")

if TEST_GROUP == "aqua" || TEST_GROUP == "all"
    @testset "Aqua.jl Quality Assurance" begin
        include("test_aqua.jl")
    end
end

if TEST_GROUP == "all"
    @testset "ToonFormat.jl - All Tests" begin
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
    
    # Include official TOON spec fixtures (via submodule)
    # The test file handles missing submodule gracefully with clear instructions
    include("test_spec_fixtures.jl")
    end
    
    @testset "ToonFormat.jl - Basic Tests" begin
        @testset "Primitive Encoding" begin
        # Null
        @test ToonFormat.encode(nothing) == "null"

        # Booleans
        @test ToonFormat.encode(true) == "true"
        @test ToonFormat.encode(false) == "false"

        # Numbers
        @test ToonFormat.encode(42) == "42"
        @test ToonFormat.encode(3.14) == "3.14"
        @test ToonFormat.encode(-0.0) == "0"

        # Strings
        @test ToonFormat.encode("hello") == "hello"
        @test ToonFormat.encode("") == "\"\""
        @test ToonFormat.encode("hello world") == "hello world"
        @test ToonFormat.encode("true") == "\"true\""
    end

    @testset "Object Encoding" begin
        # Simple object
        obj = Dict("name" => "Alice", "age" => 30)
        result = ToonFormat.encode(obj)
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Nested object
        nested = Dict("user" => Dict("name" => "Bob"))
        result = ToonFormat.encode(nested)
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Array Encoding" begin
        # Primitive array
        arr = [1, 2, 3]
        @test ToonFormat.encode(arr) == "[3]: 1,2,3"

        # Empty array
        @test ToonFormat.encode([]) == "[0]:"

        # Array of objects (tabular)
        tabular = [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]
        result = ToonFormat.encode(tabular)
        # Dict doesn't preserve order in Julia, so check for both possibilities
        @test occursin("[2]{id,name}:", result) || occursin("[2]{name,id}:", result)
    end

    @testset "Primitive Decoding" begin
        # Null
        @test ToonFormat.decode("null") === nothing

        # Booleans
        @test ToonFormat.decode("true") === true
        @test ToonFormat.decode("false") === false

        # Numbers
        @test ToonFormat.decode("42") == 42
        @test ToonFormat.decode("3.14") == 3.14

        # Strings
        @test ToonFormat.decode("hello") == "hello"
        @test ToonFormat.decode("\"\"") == ""
        @test ToonFormat.decode("\"true\"") == "true"
    end

    @testset "Object Decoding" begin
        # Simple object
        input = "name: Alice\nage: 30"
        result = ToonFormat.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30

        # Empty object
        @test ToonFormat.decode("") == Dict{String, Any}()
    end

    @testset "Array Decoding" begin
        # Primitive array
        result = ToonFormat.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]

        # Empty array
        result = ToonFormat.decode("[0]:")
        @test result == []
    end

    @testset "Round-trip" begin
        # Object round-trip
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded["name"] == original["name"]
        @test decoded["age"] == original["age"]
        @test decoded["active"] == original["active"]

        # Array round-trip
        original = [1, 2, 3, 4, 5]
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded == original
    end

    @testset "String Escaping" begin
        # Test escape sequences
        @test ToonFormat.encode("hello\nworld") == "\"hello\\nworld\""
        @test ToonFormat.encode("quote: \"yes\"") == "\"quote: \\\"yes\\\"\""

        # Test unescape
        @test ToonFormat.decode("\"hello\\nworld\"") == "hello\nworld"
        @test ToonFormat.decode("\"quote: \\\"yes\\\"\"") == "quote: \"yes\""
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        arr = [1, 2, 3]
        options = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
        result = ToonFormat.encode(arr, options=options)
        @test occursin("[3\t]:", result)

        # Pipe delimiter
        options = ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE)
        result = ToonFormat.encode(arr, options=options)
        @test occursin("[3|]:", result)
    end
    end
end
