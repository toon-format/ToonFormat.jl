# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Encoder Tests" begin
    @testset "API Tests" begin
        # Test encode with options
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB))
        @test occursin("[3\t]:", result)

        # Test encode returns native String
        result = TokenOrientedObjectNotation.encode(Dict("id" => 123))
        @test isa(result, String)

        # Test encode handles nothing gracefully
        @test TokenOrientedObjectNotation.encode(nothing) == "null"
    end

    @testset "Number Precision" begin
        # No scientific notation in output for regular numbers
        result = TokenOrientedObjectNotation.encode(Dict("big" => 1000000))
        @test occursin("1000000", result)
        @test !occursin("1e", result)

        # Small decimals may use scientific notation in Julia
        result = TokenOrientedObjectNotation.encode(Dict("small" => 0.000001))
        @test occursin("small:", result)  # Just check it encodes

        # Negative zero normalized
        result = TokenOrientedObjectNotation.encode(Dict("value" => -0.0))
        @test occursin("value: 0", result)
        @test !occursin("-0", result)

        # Negative zero in array
        result = TokenOrientedObjectNotation.encode([-0.0, 0.0, 1.0])
        @test !occursin("-0", result) || !occursin("-0.0", result)
    end

    @testset "Number Formatting Compliance" begin
        # Requirement 2.1: No exponent notation for large numbers
        @test TokenOrientedObjectNotation.encode(1000000) == "1000000"
        @test TokenOrientedObjectNotation.encode(1e6) == "1000000"
        @test !occursin("e", TokenOrientedObjectNotation.encode(1000000))
        @test !occursin("E", TokenOrientedObjectNotation.encode(1000000))
        
        # Requirement 2.1: No exponent notation for small decimals
        @test TokenOrientedObjectNotation.encode(0.000001) == "0.000001"
        @test TokenOrientedObjectNotation.encode(1e-6) == "0.000001"
        @test !occursin("e", TokenOrientedObjectNotation.encode(0.000001))
        @test !occursin("E", TokenOrientedObjectNotation.encode(0.000001))
        
        # Requirement 2.2: No leading zeros except "0"
        @test TokenOrientedObjectNotation.encode(0) == "0"
        @test TokenOrientedObjectNotation.encode(0.0) == "0"
        @test !startswith(TokenOrientedObjectNotation.encode(123), "0")
        @test !startswith(TokenOrientedObjectNotation.encode(0.5), "00")
        
        # Requirement 2.3: No trailing fractional zeros
        @test TokenOrientedObjectNotation.encode(1.5) == "1.5"
        @test TokenOrientedObjectNotation.encode(1.5000) == "1.5"
        @test !occursin("1.5000", TokenOrientedObjectNotation.encode(1.5))
        @test !occursin("1.50", TokenOrientedObjectNotation.encode(1.5))
        
        # Requirement 2.4: Integer form when fractional part is zero
        @test TokenOrientedObjectNotation.encode(1.0) == "1"
        @test TokenOrientedObjectNotation.encode(42.0) == "42"
        @test TokenOrientedObjectNotation.encode(100.0) == "100"
        @test !occursin(".", TokenOrientedObjectNotation.encode(1.0))
        @test !occursin(".", TokenOrientedObjectNotation.encode(42.0))
        
        # Requirement 1.5: Normalize -0 to 0
        @test TokenOrientedObjectNotation.encode(-0.0) == "0"
        @test !occursin("-", TokenOrientedObjectNotation.encode(-0.0))
        
        # Edge cases: Very large numbers
        @test TokenOrientedObjectNotation.encode(999999999999) == "999999999999"
        @test !occursin("e", TokenOrientedObjectNotation.encode(999999999999))
        
        # Edge cases: Very small decimals
        @test TokenOrientedObjectNotation.encode(0.00000001) == "0.00000001"
        @test !occursin("e", TokenOrientedObjectNotation.encode(0.00000001))
        
        # Edge cases: Numbers with many decimal places (check no exponent)
        result = TokenOrientedObjectNotation.encode(3.14159265359)
        @test !occursin("e", result)
        @test !occursin("E", result)
        @test startswith(result, "3.14159")
        
        # Edge cases: Trailing zeros should be removed
        result = TokenOrientedObjectNotation.encode(2.5000000)
        @test result == "2.5"
        @test !occursin("2.50", result)
        
        # Edge cases: Mixed array with -0
        result = TokenOrientedObjectNotation.encode([-0.0, 1.0, 2.5])
        @test occursin("0,1,2.5", result) || occursin("0, 1, 2.5", result)
        @test !occursin("-0", result)
        
        # Edge cases: Negative numbers should keep sign
        @test TokenOrientedObjectNotation.encode(-42) == "-42"
        result = TokenOrientedObjectNotation.encode(-3.14)
        @test startswith(result, "-3.14")
        @test !occursin("e", result)
        @test !occursin("E", result)
        
        # Edge cases: Integer boundaries
        @test TokenOrientedObjectNotation.encode(0) == "0"
        @test TokenOrientedObjectNotation.encode(1) == "1"
        @test TokenOrientedObjectNotation.encode(-1) == "-1"
    end

    @testset "String Quoting" begin
        # Reserved literals must be quoted
        @test TokenOrientedObjectNotation.encode("true") == "\"true\""
        @test TokenOrientedObjectNotation.encode("false") == "\"false\""
        @test TokenOrientedObjectNotation.encode("null") == "\"null\""

        # Numeric strings must be quoted
        @test TokenOrientedObjectNotation.encode("123") == "\"123\""
        @test TokenOrientedObjectNotation.encode("3.14") == "\"3.14\""
        @test TokenOrientedObjectNotation.encode("1e5") == "\"1e5\""

        # Leading zero strings must be quoted
        @test TokenOrientedObjectNotation.encode("0123") == "\"0123\""
        @test TokenOrientedObjectNotation.encode("0755") == "\"0755\""

        # Empty string must be quoted
        @test TokenOrientedObjectNotation.encode("") == "\"\""

        # Strings with special characters
        @test TokenOrientedObjectNotation.encode("hello world") == "hello world"  # Space is OK
        @test TokenOrientedObjectNotation.encode("  leading") == "\"  leading\""  # Leading space needs quotes
        @test TokenOrientedObjectNotation.encode("trailing  ") == "\"trailing  \""  # Trailing space needs quotes
    end

    @testset "Escape Sequences" begin
        # Newline
        @test TokenOrientedObjectNotation.encode("hello\nworld") == "\"hello\\nworld\""

        # Tab
        @test TokenOrientedObjectNotation.encode("col1\tcol2") == "\"col1\\tcol2\""

        # Carriage return
        @test TokenOrientedObjectNotation.encode("line1\rline2") == "\"line1\\rline2\""

        # Backslash
        @test TokenOrientedObjectNotation.encode("path\\to\\file") == "\"path\\\\to\\\\file\""

        # Double quote
        @test TokenOrientedObjectNotation.encode("say \"hello\"") == "\"say \\\"hello\\\"\""

        # Multiple escape sequences
        @test TokenOrientedObjectNotation.encode("test\n\r\t\\\"value\"") == "\"test\\n\\r\\t\\\\\\\"value\\\"\""
    end

    @testset "Array Encoding" begin
        # Simple array
        @test TokenOrientedObjectNotation.encode([1, 2, 3]) == "[3]: 1,2,3"

        # Empty array
        @test TokenOrientedObjectNotation.encode([]) == "[0]:"

        # Array with strings
        result = TokenOrientedObjectNotation.encode(["a", "b", "c"])
        @test occursin("[3]:", result)
        @test occursin("a,b,c", result)

        # Array with quoted values
        result = TokenOrientedObjectNotation.encode(["true", "123"])
        @test occursin("\"true\"", result)
        @test occursin("\"123\"", result)
    end

    @testset "Object Encoding" begin
        # Simple object
        result = TokenOrientedObjectNotation.encode(Dict("name" => "Alice", "age" => 30))
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Empty object
        result = TokenOrientedObjectNotation.encode(Dict{String, Any}())
        @test result == ""

        # Nested object
        result = TokenOrientedObjectNotation.encode(Dict("user" => Dict("name" => "Bob")))
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB))
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)

        # Pipe delimiter
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE))
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)

        # Comma delimiter (default)
        result = TokenOrientedObjectNotation.encode([1, 2, 3])
        @test occursin("[3]:", result)
        @test occursin("1,2,3", result)
    end

    @testset "Indent Options" begin
        # Custom indent
        result = TokenOrientedObjectNotation.encode(Dict("a" => Dict("b" => 1)), options=TokenOrientedObjectNotation.EncodeOptions(indent=4))
        @test occursin("a:", result)
        @test occursin("    b: 1", result)

        # Default indent (2 spaces)
        result = TokenOrientedObjectNotation.encode(Dict("a" => Dict("b" => 1)))
        @test occursin("a:", result)
        @test occursin("  b: 1", result)
    end

    @testset "Round-trip Encoding" begin
        # Simple values
        for val in [nothing, true, false, 42, 3.14, "hello"]
            encoded = TokenOrientedObjectNotation.encode(val)
            decoded = TokenOrientedObjectNotation.decode(encoded)
            @test decoded == val || (isnan(val) && isnan(decoded))
        end

        # Arrays
        original = [1, 2, 3, 4, 5]
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded == original

        # Objects
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        for key in keys(original)
            @test decoded[key] == original[key]
        end
    end
end
