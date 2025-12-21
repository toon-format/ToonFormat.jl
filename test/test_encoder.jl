# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Encoder Tests" begin
    @testset "API Tests" begin
        # Test encode with options
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[3\t]:", result)

        # Test encode returns native String
        result = ToonFormat.encode(Dict("id" => 123))
        @test isa(result, String)

        # Test encode handles nothing gracefully
        @test ToonFormat.encode(nothing) == "null"
    end

    @testset "Number Precision" begin
        # No scientific notation in output for regular numbers
        result = ToonFormat.encode(Dict("big" => 1000000))
        @test occursin("1000000", result)
        @test !occursin("1e", result)

        # Small decimals may use scientific notation in Julia
        result = ToonFormat.encode(Dict("small" => 0.000001))
        @test occursin("small:", result)  # Just check it encodes

        # Negative zero normalized
        result = ToonFormat.encode(Dict("value" => -0.0))
        @test occursin("value: 0", result)
        @test !occursin("-0", result)

        # Negative zero in array
        result = ToonFormat.encode([-0.0, 0.0, 1.0])
        @test !occursin("-0", result) || !occursin("-0.0", result)
    end

    @testset "Number Formatting Compliance" begin
        # Requirement 2.1: No exponent notation for large numbers
        @test ToonFormat.encode(1000000) == "1000000"
        @test ToonFormat.encode(1e6) == "1000000"
        @test !occursin("e", ToonFormat.encode(1000000))
        @test !occursin("E", ToonFormat.encode(1000000))

        # Requirement 2.1: No exponent notation for small decimals
        @test ToonFormat.encode(0.000001) == "0.000001"
        @test ToonFormat.encode(1e-6) == "0.000001"
        @test !occursin("e", ToonFormat.encode(0.000001))
        @test !occursin("E", ToonFormat.encode(0.000001))

        # Requirement 2.2: No leading zeros except "0"
        @test ToonFormat.encode(0) == "0"
        @test ToonFormat.encode(0.0) == "0"
        @test !startswith(ToonFormat.encode(123), "0")
        @test !startswith(ToonFormat.encode(0.5), "00")

        # Requirement 2.3: No trailing fractional zeros
        @test ToonFormat.encode(1.5) == "1.5"
        @test ToonFormat.encode(1.5000) == "1.5"
        @test !occursin("1.5000", ToonFormat.encode(1.5))
        @test !occursin("1.50", ToonFormat.encode(1.5))

        # Requirement 2.4: Integer form when fractional part is zero
        @test ToonFormat.encode(1.0) == "1"
        @test ToonFormat.encode(42.0) == "42"
        @test ToonFormat.encode(100.0) == "100"
        @test !occursin(".", ToonFormat.encode(1.0))
        @test !occursin(".", ToonFormat.encode(42.0))

        # Requirement 1.5: Normalize -0 to 0
        @test ToonFormat.encode(-0.0) == "0"
        @test !occursin("-", ToonFormat.encode(-0.0))

        # Edge cases: Very large numbers
        @test ToonFormat.encode(999999999999) == "999999999999"
        @test !occursin("e", ToonFormat.encode(999999999999))

        # Edge cases: Very small decimals
        @test ToonFormat.encode(0.00000001) == "0.00000001"
        @test !occursin("e", ToonFormat.encode(0.00000001))

        # Edge cases: Numbers with many decimal places (check no exponent)
        result = ToonFormat.encode(3.14159265359)
        @test !occursin("e", result)
        @test !occursin("E", result)
        @test startswith(result, "3.14159")

        # Edge cases: Trailing zeros should be removed
        result = ToonFormat.encode(2.5000000)
        @test result == "2.5"
        @test !occursin("2.50", result)

        # Edge cases: Mixed array with -0
        result = ToonFormat.encode([-0.0, 1.0, 2.5])
        @test occursin("0,1,2.5", result) || occursin("0, 1, 2.5", result)
        @test !occursin("-0", result)

        # Edge cases: Negative numbers should keep sign
        @test ToonFormat.encode(-42) == "-42"
        result = ToonFormat.encode(-3.14)
        @test startswith(result, "-3.14")
        @test !occursin("e", result)
        @test !occursin("E", result)

        # Edge cases: Integer boundaries
        @test ToonFormat.encode(0) == "0"
        @test ToonFormat.encode(1) == "1"
        @test ToonFormat.encode(-1) == "-1"
    end

    @testset "String Quoting" begin
        # Reserved literals must be quoted
        @test ToonFormat.encode("true") == "\"true\""
        @test ToonFormat.encode("false") == "\"false\""
        @test ToonFormat.encode("null") == "\"null\""

        # Numeric strings must be quoted
        @test ToonFormat.encode("123") == "\"123\""
        @test ToonFormat.encode("3.14") == "\"3.14\""
        @test ToonFormat.encode("1e5") == "\"1e5\""

        # Leading zero strings must be quoted
        @test ToonFormat.encode("0123") == "\"0123\""
        @test ToonFormat.encode("0755") == "\"0755\""

        # Empty string must be quoted
        @test ToonFormat.encode("") == "\"\""

        # Strings with special characters
        @test ToonFormat.encode("hello world") == "hello world"  # Space is OK
        @test ToonFormat.encode("  leading") == "\"  leading\""  # Leading space needs quotes
        @test ToonFormat.encode("trailing  ") == "\"trailing  \""  # Trailing space needs quotes
    end

    @testset "Escape Sequences" begin
        # Newline
        @test ToonFormat.encode("hello\nworld") == "\"hello\\nworld\""

        # Tab
        @test ToonFormat.encode("col1\tcol2") == "\"col1\\tcol2\""

        # Carriage return
        @test ToonFormat.encode("line1\rline2") == "\"line1\\rline2\""

        # Backslash
        @test ToonFormat.encode("path\\to\\file") == "\"path\\\\to\\\\file\""

        # Double quote
        @test ToonFormat.encode("say \"hello\"") == "\"say \\\"hello\\\"\""

        # Multiple escape sequences
        @test ToonFormat.encode("test\n\r\t\\\"value\"") ==
              "\"test\\n\\r\\t\\\\\\\"value\\\"\""
    end

    @testset "Array Encoding" begin
        # Simple array
        @test ToonFormat.encode([1, 2, 3]) == "[3]: 1,2,3"

        # Empty array
        @test ToonFormat.encode([]) == "[0]:"

        # Array with strings
        result = ToonFormat.encode(["a", "b", "c"])
        @test occursin("[3]:", result)
        @test occursin("a,b,c", result)

        # Array with quoted values
        result = ToonFormat.encode(["true", "123"])
        @test occursin("\"true\"", result)
        @test occursin("\"123\"", result)
    end

    @testset "Object Encoding" begin
        # Simple object
        result = ToonFormat.encode(Dict("name" => "Alice", "age" => 30))
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)

        # Empty object
        result = ToonFormat.encode(Dict{String,Any}())
        @test result == ""

        # Nested object
        result = ToonFormat.encode(Dict("user" => Dict("name" => "Bob")))
        @test occursin("user:", result)
        @test occursin("name: Bob", result)
    end

    @testset "Delimiter Options" begin
        # Tab delimiter
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)

        # Pipe delimiter
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)

        # Comma delimiter (default)
        result = ToonFormat.encode([1, 2, 3])
        @test occursin("[3]:", result)
        @test occursin("1,2,3", result)
    end

    @testset "Indent Options" begin
        # Custom indent
        result = ToonFormat.encode(
            Dict("a" => Dict("b" => 1)),
            options = ToonFormat.EncodeOptions(indent = 4),
        )
        @test occursin("a:", result)
        @test occursin("    b: 1", result)

        # Default indent (2 spaces)
        result = ToonFormat.encode(Dict("a" => Dict("b" => 1)))
        @test occursin("a:", result)
        @test occursin("  b: 1", result)
    end

    @testset "Round-trip Encoding" begin
        # Simple values
        for val in [nothing, true, false, 42, 3.14, "hello"]
            encoded = ToonFormat.encode(val)
            decoded = ToonFormat.decode(encoded)
            @test decoded == val || (isnan(val) && isnan(decoded))
        end

        # Arrays
        original = [1, 2, 3, 4, 5]
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded == original

        # Objects
        original = Dict("name" => "Alice", "age" => 30, "active" => true)
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        for key in keys(original)
            @test decoded[key] == original[key]
        end
    end
end
