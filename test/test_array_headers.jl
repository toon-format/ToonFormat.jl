# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Array Header Syntax Tests (Task 4)" begin
    @testset "Header Format - Encoding (Requirement 4.1)" begin
        # Root array with comma delimiter (default)
        result = ToonFormat.encode([1, 2, 3])
        @test occursin("[3]:", result)
        @test startswith(result, "[3]:")

        # Named array with comma delimiter
        result = ToonFormat.encode(Dict("items" => [1, 2, 3]))
        @test occursin("items[3]:", result)

        # Empty array
        result = ToonFormat.encode([])
        @test occursin("[0]:", result)

        # Named empty array
        result = ToonFormat.encode(Dict("items" => []))
        @test occursin("items[0]:", result)
    end

    @testset "Delimiter Symbol Encoding (Requirements 4.2, 4.3)" begin
        # Comma delimiter (absent symbol)
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.COMMA),
        )
        @test occursin("[3]:", result)
        @test !occursin("[3\t]:", result)
        @test !occursin("[3|]:", result)

        # Tab delimiter (HTAB symbol)
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)

        # Pipe delimiter ("|" symbol)
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)

        # Named array with tab delimiter
        result = ToonFormat.encode(
            Dict("data" => [10, 20, 30]),
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("data[3\t]:", result)
        @test occursin("10\t20\t30", result)

        # Named array with pipe delimiter
        result = ToonFormat.encode(
            Dict("data" => [10, 20, 30]),
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("data[3|]:", result)
        @test occursin("10|20|30", result)
    end

    @testset "Field List Encoding (Requirement 4.4)" begin
        # Tabular array with comma delimiter
        data = Dict(
            "users" => [
                Dict("name" => "Alice", "age" => 30),
                Dict("name" => "Bob", "age" => 25),
            ],
        )
        result = ToonFormat.encode(data)
        @test occursin("users[2]{name,age}:", result)
        @test occursin("Alice,30", result)
        @test occursin("Bob,25", result)

        # Tabular array with tab delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("users[2\t]{name\tage}:", result)
        @test occursin("Alice\t30", result)
        @test occursin("Bob\t25", result)

        # Tabular array with pipe delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("users[2|]{name|age}:", result)
        @test occursin("Alice|30", result)
        @test occursin("Bob|25", result)

        # Tabular array with quoted field names
        data = Dict(
            "items" => [
                Dict("item name" => "Widget", "price" => 10),
                Dict("item name" => "Gadget", "price" => 20),
            ],
        )
        result = ToonFormat.encode(data)
        # Dict doesn't guarantee key order, so check for both possibilities
        @test occursin("items[2]{\"item name\",price}:", result) ||
              occursin("items[2]{price,\"item name\"}:", result)
    end

    @testset "Colon Requirement (Requirement 4.7)" begin
        # All array headers must end with colon
        result = ToonFormat.encode([1, 2, 3])
        @test occursin("[3]:", result)

        result = ToonFormat.encode(Dict("items" => [1, 2, 3]))
        @test occursin("items[3]:", result)

        # Tabular arrays
        data = Dict("users" => [Dict("name" => "Alice")])
        result = ToonFormat.encode(data)
        @test occursin("users[1]{name}:", result)

        # Empty arrays
        result = ToonFormat.encode([])
        @test occursin("[0]:", result)
    end

    @testset "Header Parsing - Decoding (Requirement 4.5)" begin
        # Parse root array with comma delimiter
        result = ToonFormat.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]

        # Parse named array with comma delimiter
        result = ToonFormat.decode("items[3]: 1,2,3")
        @test result["items"] == [1, 2, 3]

        # Parse array with tab delimiter
        result = ToonFormat.decode("[3\t]: 1\t2\t3")
        @test result == [1, 2, 3]

        # Parse array with pipe delimiter
        result = ToonFormat.decode("[3|]: 1|2|3")
        @test result == [1, 2, 3]

        # Parse named array with tab delimiter
        result = ToonFormat.decode("data[3\t]: 10\t20\t30")
        @test result["data"] == [10, 20, 30]

        # Parse named array with pipe delimiter
        result = ToonFormat.decode("data[3|]: 10|20|30")
        @test result["data"] == [10, 20, 30]

        # Parse empty array
        result = ToonFormat.decode("[0]:")
        @test result == []

        # Parse named empty array
        result = ToonFormat.decode("items[0]:")
        @test result["items"] == []
    end

    @testset "Field List Parsing (Requirement 4.4)" begin
        # Parse tabular array with comma delimiter
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = ToonFormat.decode(input)
        @test length(result["users"]) == 2
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        @test result["users"][2]["name"] == "Bob"
        @test result["users"][2]["age"] == 25

        # Parse tabular array with tab delimiter
        input = "users[2\t]{name\tage}:\n  Alice\t30\n  Bob\t25"
        result = ToonFormat.decode(input)
        @test length(result["users"]) == 2
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30

        # Parse tabular array with pipe delimiter
        input = "users[2|]{name|age}:\n  Alice|30\n  Bob|25"
        result = ToonFormat.decode(input)
        @test length(result["users"]) == 2
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30

        # Parse tabular array with quoted field names
        input = "items[2]{\"item name\",price}:\n  Widget,10\n  Gadget,20"
        result = ToonFormat.decode(input)
        @test result["items"][1]["item name"] == "Widget"
        @test result["items"][1]["price"] == 10
    end

    @testset "Delimiter Absence Means Comma (Requirement 4.6)" begin
        # No delimiter symbol = comma
        result = ToonFormat.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]

        # Tabular array without delimiter symbol uses comma
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30

        # Multiple arrays in same document, each with explicit delimiter
        input = "arr1[2]: 1,2\narr2[2]: 3,4"
        result = ToonFormat.decode(input)
        @test result["arr1"] == [1, 2]
        @test result["arr2"] == [3, 4]
    end

    @testset "Colon Requirement Validation (Requirement 4.7)" begin
        # All valid array headers must have colons
        # These should parse successfully
        @test ToonFormat.decode("[0]:") == []
        @test ToonFormat.decode("items[0]:") == Dict("items" => [])
        @test ToonFormat.decode("users[2]{name,age}:\n  Alice,30\n  Bob,25")["users"][1]["name"] ==
              "Alice"

        # Array headers with inline data
        @test ToonFormat.decode("[3]: 1,2,3") == [1, 2, 3]
        @test ToonFormat.decode("items[2]: a,b")["items"] == ["a", "b"]
    end

    @testset "Complex Header Scenarios" begin
        # Array with special characters in values
        result = ToonFormat.decode("[3]: \"a,b\",\"c|d\",\"e\tf\"")
        @test result[1] == "a,b"
        @test result[2] == "c|d"
        @test result[3] == "e\tf"

        # Tabular array with empty values
        input = "data[2]{a,b,c}:\n  1,,3\n  ,2,"
        result = ToonFormat.decode(input)
        @test result["data"][1]["a"] == 1
        @test result["data"][1]["b"] == ""
        @test result["data"][1]["c"] == 3
        @test result["data"][2]["a"] == ""
        @test result["data"][2]["b"] == 2
        @test result["data"][2]["c"] == ""

        # Multiple arrays with different delimiters in same document
        input = "arr1[2]: 1,2\narr2[2\t]: 3\t4\narr3[2|]: 5|6"
        result = ToonFormat.decode(input)
        @test result["arr1"] == [1, 2]
        @test result["arr2"] == [3, 4]
        @test result["arr3"] == [5, 6]
    end

    @testset "Round-trip with Different Delimiters" begin
        # Comma delimiter
        original = [1, 2, 3, 4, 5]
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded == original

        # Tab delimiter
        encoded = ToonFormat.encode(
            original,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        decoded = ToonFormat.decode(encoded)
        @test decoded == original

        # Pipe delimiter
        encoded = ToonFormat.encode(
            original,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        decoded = ToonFormat.decode(encoded)
        @test decoded == original

        # Tabular arrays with different delimiters
        original = Dict(
            "users" => [
                Dict("name" => "Alice", "age" => 30),
                Dict("name" => "Bob", "age" => 25),
            ],
        )

        for delim in [ToonFormat.COMMA, ToonFormat.TAB, ToonFormat.PIPE]
            encoded = ToonFormat.encode(
                original,
                options = ToonFormat.EncodeOptions(delimiter = delim),
            )
            decoded = ToonFormat.decode(encoded)
            @test decoded["users"][1]["name"] == "Alice"
            @test decoded["users"][1]["age"] == 30
            @test decoded["users"][2]["name"] == "Bob"
            @test decoded["users"][2]["age"] == 25
        end
    end
end
