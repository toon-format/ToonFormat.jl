# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "TOON.jl - All Tests" begin
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
end

@testset "TOON.jl - Basic Tests" begin
    @testset "Primitive Encoding" begin
        # Null
        @test TOON.encode(nothing) == "null"

        # Booleans
        @test TOON.encode(true) == "true"
        @test TOON.encode(false) == "false"

        # Numbers
        @test TOON.encode(42) == "42"
        @test TOON.encode(3.14) == "3.14"
        @test TOON.encode(-0.0) == "0"

        # Strings
        @test TOON.encode("hello") == "hello"
        @test TOON.encode("") == "\"\""
        @test TOON.encode("hello world") == "hello world"
        @test TOON.encode("true") == "\"true\""
    end

    @testset "Object Encoding" begin
        # Simple object
        obj = Dict("name" => "Alice", "age" => 30)
        result = TOON.encode(obj)
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Nested object
        nested = Dict("user" => Dict("name" => "Bob"))
        result = TOON.encode(nested)
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Array Encoding" begin
        # Primitive array
        arr = [1, 2, 3]
        @test TOON.encode(arr) == "[3]: 1,2,3"

        # Empty array
        @test TOON.encode([]) == "[0]:"

        # Array of objects (tabular)
        tabular = [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]
        result = TOON.encode(tabular)
        # Dict doesn't preserve order in Julia, so check for both possibilities
        @test occursin("[2]{id,name}:", result) || occursin("[2]{name,id}:", result)
    end

    @testset "Primitive Decoding" begin
        # Null
        @test TOON.decode("null") === nothing

        # Booleans
        @test TOON.decode("true") === true
        @test TOON.decode("false") === false

        # Numbers
        @test TOON.decode("42") == 42
        @test TOON.decode("3.14") == 3.14

        # Strings
        @test TOON.decode("hello") == "hello"
        @test TOON.decode("\"\"") == ""
        @test TOON.decode("\"true\"") == "true"
    end

    @testset "Object Decoding" begin
        # Simple object
        input = "name: Alice\nage: 30"
        result = TOON.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30

        # Empty object
        @test TOON.decode("") == Dict{String, Any}()
    end

    @testset "Array Decoding" begin
        # Primitive array
        result = TOON.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]

        # Empty array
        result = TOON.decode("[0]:")
        @test result == []
    end

    @testset "Round-trip" begin
        # Object round-trip
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = TOON.encode(original)
        decoded = TOON.decode(encoded)
        @test decoded["name"] == original["name"]
        @test decoded["age"] == original["age"]
        @test decoded["active"] == original["active"]

        # Array round-trip
        original = [1, 2, 3, 4, 5]
        encoded = TOON.encode(original)
        decoded = TOON.decode(encoded)
        @test decoded == original
    end

    @testset "String Escaping" begin
        # Test escape sequences
        @test TOON.encode("hello\nworld") == "\"hello\\nworld\""
        @test TOON.encode("quote: \"yes\"") == "\"quote: \\\"yes\\\"\""

        # Test unescape
        @test TOON.decode("\"hello\\nworld\"") == "hello\nworld"
        @test TOON.decode("\"quote: \\\"yes\\\"\"") == "quote: \"yes\""
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        arr = [1, 2, 3]
        options = TOON.EncodeOptions(delimiter=TOON.TAB)
        result = TOON.encode(arr, options=options)
        @test occursin("[3\t]:", result)

        # Pipe delimiter
        options = TOON.EncodeOptions(delimiter=TOON.PIPE)
        result = TOON.encode(arr, options=options)
        @test occursin("[3|]:", result)
    end
end
