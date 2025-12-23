# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Tabular Array Handling" begin
    @testset "Requirement 7.1: Field names from first object's key order" begin
        # Basic tabular array
        data = [Dict("name" => "Alice", "age" => 30), Dict("name" => "Bob", "age" => 25)]
        result = ToonFormat.encode(data)

        # Should have header with fields
        @test occursin("[2]{name,age}:", result) || occursin("[2]{age,name}:", result)

        # Field order should match first object's key order
        # Julia Dict preserves insertion order, so we can check
        first_obj = data[1]
        first_keys = collect(keys(first_obj))
        if first_keys == ["name", "age"]
            @test occursin("[2]{name,age}:", result)
        else
            @test occursin("[2]{age,name}:", result)
        end

        # Decode and verify field order is preserved
        decoded = ToonFormat.decode(result)
        @test decoded[1]["name"] == "Alice"
        @test decoded[1]["age"] == 30
        @test decoded[2]["name"] == "Bob"
        @test decoded[2]["age"] == 25
    end

    @testset "Requirement 7.2: One row per object at depth +1" begin
        # Encode tabular array with key
        data = Dict(
            "users" =>
                [Dict("id" => 1, "name" => "Alice"), Dict("id" => 2, "name" => "Bob")],
        )
        result = ToonFormat.encode(data)

        lines = split(result, '\n')
        @test length(lines) == 3  # Header + 2 rows

        # Check indentation (rows should be at depth +1)
        @test startswith(lines[1], "users[2]")  # Header at depth 0
        @test startswith(lines[2], "  ")  # Row 1 at depth 1 (2 spaces)
        @test startswith(lines[3], "  ")  # Row 2 at depth 1 (2 spaces)

        # Decode and verify
        decoded = ToonFormat.decode(result)
        @test length(decoded["users"]) == 2
    end

    @testset "Requirement 7.3: Rows use active delimiter" begin
        # Comma delimiter (default)
        data = [Dict("a" => 1, "b" => 2), Dict("a" => 3, "b" => 4)]
        result = ToonFormat.encode(data)
        @test occursin("1,2", result) || occursin("2,1", result)

        # Tab delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[2\t]{", result)
        @test occursin("\t", result)  # Rows should use tab

        # Pipe delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[2|]{", result)
        @test occursin("|", result)  # Rows should use pipe
    end

    @testset "Requirement 7.4: Decoder splits rows using only active delimiter" begin
        # Comma delimiter
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        @test result["users"][2]["name"] == "Bob"
        @test result["users"][2]["age"] == 25

        # Tab delimiter
        input = "users[2\t]{name\tage}:\n  Alice\t30\n  Bob\t25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30

        # Pipe delimiter
        input = "users[2|]{name|age}:\n  Alice|30\n  Bob|25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30

        # Values containing other delimiters should not be split
        input = "items[2]{name,desc}:\n  \"a,b\",\"c|d\"\n  \"e\tf\",\"g-h\""
        result = ToonFormat.decode(input)
        @test result["items"][1]["name"] == "a,b"
        @test result["items"][1]["desc"] == "c|d"
        @test result["items"][2]["name"] == "e\tf"
        @test result["items"][2]["desc"] == "g-h"
    end

    @testset "Requirement 7.5: Strict mode errors on row width mismatch" begin
        # Too many values in row
        input = "users[2]{name,age}:\n  Alice,30,extra\n  Bob,25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Too few values in row
        input = "users[2]{name,age}:\n  Alice\n  Bob,25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Tab delimiter with width mismatch
        input = "users[2\t]{name\tage}:\n  Alice\t30\textra\n  Bob\t25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Pipe delimiter with width mismatch
        input = "users[2|]{name|age}:\n  Alice|30|extra\n  Bob|25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Non-strict mode should handle gracefully
        input = "users[2]{name,age}:\n  Alice,30,extra\n  Bob"
        result =
            ToonFormat.decode(input, options = ToonFormat.DecodeOptions(strict = false))
        @test haskey(result["users"][1], "name")
        @test haskey(result["users"][2], "name")
    end

    @testset "Requirement 7.6: Strict mode errors on row count mismatch" begin
        # Too few rows
        input = "users[3]{name,age}:\n  Alice,30\n  Bob,25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Too many rows
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25\n  Charlie,35"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Exact count should work
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = ToonFormat.decode(input, options = ToonFormat.DecodeOptions(strict = true))
        @test length(result["users"]) == 2

        # Non-strict mode should accept actual count
        input = "users[3]{name,age}:\n  Alice,30\n  Bob,25"
        result =
            ToonFormat.decode(input, options = ToonFormat.DecodeOptions(strict = false))
        @test length(result["users"]) == 2  # Actual count, not declared
    end

    @testset "Tabular arrays with all delimiters" begin
        # Test encoding and decoding with each delimiter
        data = Dict(
            "users" => [
                Dict("name" => "Alice", "age" => 30, "city" => "NYC"),
                Dict("name" => "Bob", "age" => 25, "city" => "LA"),
                Dict("name" => "Charlie", "age" => 35, "city" => "SF"),
            ],
        )

        # Comma delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.COMMA),
        )
        @test occursin("[3]{", result)
        @test occursin(",", result)
        decoded = ToonFormat.decode(result)
        @test decoded["users"][1]["name"] == "Alice"
        @test decoded["users"][2]["age"] == 25
        @test decoded["users"][3]["city"] == "SF"

        # Tab delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[3\t]{", result)
        @test occursin("\t", result)
        decoded = ToonFormat.decode(result)
        @test decoded["users"][1]["name"] == "Alice"
        @test decoded["users"][2]["age"] == 25
        @test decoded["users"][3]["city"] == "SF"

        # Pipe delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[3|]{", result)
        @test occursin("|", result)
        decoded = ToonFormat.decode(result)
        @test decoded["users"][1]["name"] == "Alice"
        @test decoded["users"][2]["age"] == 25
        @test decoded["users"][3]["city"] == "SF"
    end

    @testset "Edge cases for tabular arrays" begin
        # Empty tabular array
        input = "users[0]{name,age}:"
        result = ToonFormat.decode(input)
        @test length(result["users"]) == 0

        # Single row tabular array
        data = [Dict("x" => 1, "y" => 2)]
        result = ToonFormat.encode(data)
        @test occursin("[1]{", result)
        decoded = ToonFormat.decode(result)
        @test decoded[1]["x"] == 1

        # Tabular array with many fields
        data = [
            Dict("a" => 1, "b" => 2, "c" => 3, "d" => 4, "e" => 5),
            Dict("a" => 6, "b" => 7, "c" => 8, "d" => 9, "e" => 10),
        ]
        result = ToonFormat.encode(data)
        @test occursin("[2]{", result)
        decoded = ToonFormat.decode(result)
        @test decoded[1]["a"] == 1
        @test decoded[2]["e"] == 10

        # Tabular array with quoted field names
        data = [
            Dict("first name" => "Alice", "last name" => "Smith"),
            Dict("first name" => "Bob", "last name" => "Jones"),
        ]
        result = ToonFormat.encode(data)
        @test occursin("{", result) && occursin("}", result)
        decoded = ToonFormat.decode(result)
        @test decoded[1]["first name"] == "Alice"
        @test decoded[2]["last name"] == "Jones"

        # Tabular array with empty string values
        input = "data[2]{a,b,c}:\n  1,,3\n  ,2,"
        result = ToonFormat.decode(input)
        @test result["data"][1]["a"] == 1
        @test result["data"][1]["b"] == ""
        @test result["data"][1]["c"] == 3
        @test result["data"][2]["a"] == ""
        @test result["data"][2]["b"] == 2
        @test result["data"][2]["c"] == ""

        # Tabular array with null values
        data = [Dict("a" => 1, "b" => nothing), Dict("a" => nothing, "b" => 2)]
        result = ToonFormat.encode(data)
        @test occursin("null", result)
        decoded = ToonFormat.decode(result)
        @test decoded[1]["a"] == 1
        @test decoded[1]["b"] === nothing
        @test decoded[2]["a"] === nothing
        @test decoded[2]["b"] == 2
    end

    @testset "Round-trip encoding and decoding" begin
        # Basic round-trip
        original = [
            Dict("id" => 1, "name" => "Alice", "active" => true),
            Dict("id" => 2, "name" => "Bob", "active" => false),
        ]
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded[1]["id"] == 1
        @test decoded[1]["name"] == "Alice"
        @test decoded[1]["active"] == true
        @test decoded[2]["id"] == 2
        @test decoded[2]["name"] == "Bob"
        @test decoded[2]["active"] == false

        # Round-trip with different delimiters
        for delim in [ToonFormat.COMMA, ToonFormat.TAB, ToonFormat.PIPE]
            encoded = ToonFormat.encode(
                original,
                options = ToonFormat.EncodeOptions(delimiter = delim),
            )
            decoded = ToonFormat.decode(encoded)
            @test decoded[1]["id"] == 1
            @test decoded[2]["name"] == "Bob"
        end
    end

    @testset "Inline tabular arrays" begin
        # Inline tabular array (all on one line)
        input = "users[2]{name,age}: Alice,30,Bob,25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        @test result["users"][2]["name"] == "Bob"
        @test result["users"][2]["age"] == 25

        # Inline with tab delimiter
        input = "users[2\t]{name\tage}: Alice\t30\tBob\t25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][2]["age"] == 25

        # Inline with pipe delimiter
        input = "users[2|]{name|age}: Alice|30|Bob|25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][2]["age"] == 25

        # Inline count mismatch in strict mode
        input = "users[3]{name,age}: Alice,30,Bob,25"
        @test_throws Exception ToonFormat.decode(
            input,
            options = ToonFormat.DecodeOptions(strict = true),
        )
    end
end
