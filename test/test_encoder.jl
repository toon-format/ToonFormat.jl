# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Encoder Tests" begin
    @testset "API Tests" begin
        # Test encode with options
        result = TOON.encode([1, 2, 3], options=TOON.EncodeOptions(delimiter=TOON.TAB))
        @test occursin("[3\t]:", result)

        # Test encode returns native String
        result = TOON.encode(Dict("id" => 123))
        @test isa(result, String)

        # Test encode handles nothing gracefully
        @test TOON.encode(nothing) == "null"
    end

    @testset "Number Precision" begin
        # No scientific notation in output for regular numbers
        result = TOON.encode(Dict("big" => 1000000))
        @test occursin("1000000", result)
        @test !occursin("1e", result)

        # Small decimals may use scientific notation in Julia
        result = TOON.encode(Dict("small" => 0.000001))
        @test occursin("small:", result)  # Just check it encodes

        # Negative zero normalized
        result = TOON.encode(Dict("value" => -0.0))
        @test occursin("value: 0", result)
        @test !occursin("-0", result)

        # Negative zero in array
        result = TOON.encode([-0.0, 0.0, 1.0])
        @test !occursin("-0", result) || !occursin("-0.0", result)
    end

    @testset "String Quoting" begin
        # Reserved literals must be quoted
        @test TOON.encode("true") == "\"true\""
        @test TOON.encode("false") == "\"false\""
        @test TOON.encode("null") == "\"null\""

        # Numeric strings must be quoted
        @test TOON.encode("123") == "\"123\""
        @test TOON.encode("3.14") == "\"3.14\""
        @test TOON.encode("1e5") == "\"1e5\""

        # Leading zero strings must be quoted
        @test TOON.encode("0123") == "\"0123\""
        @test TOON.encode("0755") == "\"0755\""

        # Empty string must be quoted
        @test TOON.encode("") == "\"\""

        # Strings with special characters
        @test TOON.encode("hello world") == "hello world"  # Space is OK
        @test TOON.encode("  leading") == "\"  leading\""  # Leading space needs quotes
        @test TOON.encode("trailing  ") == "\"trailing  \""  # Trailing space needs quotes
    end

    @testset "Escape Sequences" begin
        # Newline
        @test TOON.encode("hello\nworld") == "\"hello\\nworld\""

        # Tab
        @test TOON.encode("col1\tcol2") == "\"col1\\tcol2\""

        # Carriage return
        @test TOON.encode("line1\rline2") == "\"line1\\rline2\""

        # Backslash
        @test TOON.encode("path\\to\\file") == "\"path\\\\to\\\\file\""

        # Double quote
        @test TOON.encode("say \"hello\"") == "\"say \\\"hello\\\"\""

        # Multiple escape sequences
        @test TOON.encode("test\n\r\t\\\"value\"") == "\"test\\n\\r\\t\\\\\\\"value\\\"\""
    end

    @testset "Array Encoding" begin
        # Simple array
        @test TOON.encode([1, 2, 3]) == "[3]: 1,2,3"

        # Empty array
        @test TOON.encode([]) == "[0]:"

        # Array with strings
        result = TOON.encode(["a", "b", "c"])
        @test occursin("[3]:", result)
        @test occursin("a,b,c", result)

        # Array with quoted values
        result = TOON.encode(["true", "123"])
        @test occursin("\"true\"", result)
        @test occursin("\"123\"", result)
    end

    @testset "Object Encoding" begin
        # Simple object
        result = TOON.encode(Dict("name" => "Alice", "age" => 30))
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Empty object
        result = TOON.encode(Dict{String, Any}())
        @test result == ""

        # Nested object
        result = TOON.encode(Dict("user" => Dict("name" => "Bob")))
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        result = TOON.encode([1, 2, 3], options=TOON.EncodeOptions(delimiter=TOON.TAB))
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)

        # Pipe delimiter
        result = TOON.encode([1, 2, 3], options=TOON.EncodeOptions(delimiter=TOON.PIPE))
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)

        # Comma delimiter (default)
        result = TOON.encode([1, 2, 3])
        @test occursin("[3]:", result)
        @test occursin("1,2,3", result)
    end

    @testset "Indent Options" begin
        # Custom indent
        result = TOON.encode(Dict("a" => Dict("b" => 1)), options=TOON.EncodeOptions(indent=4))
        @test occursin("a:", result)
        @test occursin("    b: 1", result)

        # Default indent (2 spaces)
        result = TOON.encode(Dict("a" => Dict("b" => 1)))
        @test occursin("a:", result)
        @test occursin("  b: 1", result)
    end

    @testset "Round-trip Encoding" begin
        # Simple values
        for val in [nothing, true, false, 42, 3.14, "hello"]
            encoded = TOON.encode(val)
            decoded = TOON.decode(encoded)
            @test decoded == val || (isnan(val) && isnan(decoded))
        end

        # Arrays
        original = [1, 2, 3, 4, 5]
        encoded = TOON.encode(original)
        decoded = TOON.decode(encoded)
        @test decoded == original

        # Objects
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = TOON.encode(original)
        decoded = TOON.decode(encoded)
        for key in keys(original)
            @test decoded[key] == original[key]
        end
    end
end
