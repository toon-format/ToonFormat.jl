# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Array Format Selection" begin
    @testset "Requirement 6.1: Primitive arrays use inline format" begin
        # Integer array
        result = ToonFormat.encode([1, 2, 3])
        @test occursin("[3]:", result)
        @test occursin("1,2,3", result)
        @test !occursin("\n", result)  # Should be single line

        # Float array
        result = ToonFormat.encode([1.5, 2.5, 3.5])
        @test occursin("[3]:", result)
        @test occursin("1.5,2.5,3.5", result)

        # String array
        result = ToonFormat.encode(["a", "b", "c"])
        @test occursin("[3]:", result)
        @test occursin("a,b,c", result)

        # Boolean array
        result = ToonFormat.encode([true, false, true])
        @test occursin("[3]:", result)
        @test occursin("true,false,true", result)

        # Null array
        result = ToonFormat.encode([nothing, nothing])
        @test occursin("[2]:", result)
        @test occursin("null,null", result)

        # Mixed primitive types
        result = ToonFormat.encode([1, "hello", true, nothing, 3.14])
        @test occursin("[5]:", result)
        @test occursin("1,hello,true,null,3.14", result)

        # Single element primitive array
        result = ToonFormat.encode([42])
        @test occursin("[1]:", result)
        @test occursin("42", result)
    end

    @testset "Requirement 6.2: Uniform object arrays use tabular format" begin
        # Simple uniform objects
        data = [Dict("id" => 1, "name" => "Alice"), Dict("id" => 2, "name" => "Bob")]
        result = ToonFormat.encode(data)
        # Dict doesn't preserve order, so check for both possibilities
        @test occursin("[2]{", result) && occursin("}:", result)
        @test occursin("Alice", result) && occursin("Bob", result)
        @test occursin("1", result) && occursin("2", result)
        lines = split(result, '\n')
        @test length(lines) == 3  # Header + 2 rows

        # Uniform objects with multiple fields
        data = [Dict("a" => 1, "b" => 2, "c" => 3), Dict("a" => 4, "b" => 5, "c" => 6)]
        result = ToonFormat.encode(data)
        @test occursin("[2]{", result) && occursin("}:", result)
        @test occursin("1", result) && occursin("2", result) && occursin("3", result)
        @test occursin("4", result) && occursin("5", result) && occursin("6", result)

        # Uniform objects with string values
        data = [
            Dict("name" => "Alice", "city" => "NYC"),
            Dict("name" => "Bob", "city" => "LA"),
        ]
        result = ToonFormat.encode(data)
        @test occursin("[2]{name,city}:", result)
        @test occursin("Alice,NYC", result)
        @test occursin("Bob,LA", result)

        # Single object array (still tabular)
        data = [Dict("x" => 1, "y" => 2)]
        result = ToonFormat.encode(data)
        @test occursin("[1]{x,y}:", result)
        @test occursin("1,2", result)
    end

    @testset "Requirement 6.3: Arrays of primitive arrays use expanded list format" begin
        # Array of integer arrays
        data = [[1, 2], [3, 4], [5, 6]]
        result = ToonFormat.encode(data)
        @test occursin("[3]:", result)
        @test occursin("- [2]: 1,2", result)  # Note: space after hyphen
        @test occursin("- [2]: 3,4", result)
        @test occursin("- [2]: 5,6", result)
        lines = split(result, '\n')
        @test length(lines) == 4  # Header + 3 list items

        # Array of string arrays
        data = [["a", "b"], ["c", "d"]]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("- [2]: a,b", result)
        @test occursin("- [2]: c,d", result)

        # Array of mixed primitive arrays
        data = [[1, "hello"], [true, nothing]]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("- [2]: 1,hello", result)
        @test occursin("- [2]: true,null", result)

        # Array with empty primitive array
        data = [[1, 2], [], [3]]
        result = ToonFormat.encode(data)
        @test occursin("[3]:", result)
        @test occursin("- [2]: 1,2", result)
        @test occursin("- [0]:", result)  # Empty array (no trailing space)
        @test occursin("- [1]: 3", result)

        # Single element array of arrays
        data = [[1, 2, 3]]
        result = ToonFormat.encode(data)
        @test occursin("[1]:", result)
        @test occursin("- [3]: 1,2,3", result)
    end

    @testset "Requirement 6.4: Mixed/non-uniform arrays use expanded list format" begin
        # Mixed primitives and objects
        data = [1, Dict("x" => 2), "hello"]
        result = ToonFormat.encode(data)
        @test occursin("[3]:", result)
        @test occursin("- 1", result)  # Note: space after hyphen
        @test occursin("- x: 2", result)
        @test occursin("- hello", result)

        # Mixed primitives and arrays
        data = [1, [2, 3], 4]
        result = ToonFormat.encode(data)
        @test occursin("[3]:", result)
        @test occursin("- 1", result)
        @test occursin("- [2]: 2,3", result)
        @test occursin("- 4", result)

        # Non-uniform objects (different keys)
        data = [Dict("a" => 1), Dict("b" => 2)]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("- a: 1", result)
        @test occursin("- b: 2", result)

        # Non-uniform objects (same keys but nested values)
        data = [Dict("x" => 1), Dict("x" => Dict("y" => 2))]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("- x: 1", result)
        @test occursin("- x:", result)
        @test occursin("y: 2", result)

        # Array with all different types
        data = [42, "text", true, nothing, [1, 2], Dict("k" => "v")]
        result = ToonFormat.encode(data)
        @test occursin("[6]:", result)
        @test occursin("- 42", result)
        @test occursin("- text", result)
        @test occursin("- true", result)
        @test occursin("- null", result)
        @test occursin("- [2]: 1,2", result)
        @test occursin("- k: v", result)
    end

    @testset "Requirement 6.5: Empty arrays emit header with no values" begin
        # Empty array
        result = ToonFormat.encode([])
        @test result == "[0]:"
        @test !occursin("\n", result)

        # Empty array with key
        result = ToonFormat.encode(Dict("items" => []))
        @test occursin("items[0]:", result)

        # Empty array in nested structure
        data = Dict("data" => Dict("list" => []))
        result = ToonFormat.encode(data)
        @test occursin("list[0]:", result)
    end

    @testset "Array format selection with different delimiters" begin
        # Primitive array with tab delimiter
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)

        # Primitive array with pipe delimiter
        result = ToonFormat.encode(
            [1, 2, 3],
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)

        # Tabular array with tab delimiter
        data = [Dict("a" => 1), Dict("a" => 2)]
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB),
        )
        @test occursin("[2\t]{a}:", result)
        @test occursin("1", result)
        @test occursin("2", result)

        # Tabular array with pipe delimiter
        result = ToonFormat.encode(
            data,
            options = ToonFormat.EncodeOptions(delimiter = ToonFormat.PIPE),
        )
        @test occursin("[2|]{a}:", result)
    end

    @testset "Complex nested array scenarios" begin
        # Array of objects containing arrays (should use expanded list)
        data = [Dict("id" => 1, "tags" => ["a", "b"]), Dict("id" => 2, "tags" => ["c"])]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("- id: 1", result) || occursin("- tags[2]: a,b", result)  # First field on hyphen line
        @test occursin("tags[2]: a,b", result)
        @test occursin("- id: 2", result) || occursin("- tags[1]: c", result)
        @test occursin("tags[1]: c", result)

        # Array of arrays of objects (should use expanded list)
        data = [[Dict("x" => 1)], [Dict("x" => 2)]]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        # Inner arrays contain objects, so they use expanded list too

        # Deeply nested arrays
        data = [[[1, 2]], [[3, 4]]]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
    end

    @testset "Edge cases for array format selection" begin
        # Array with single empty object
        data = [Dict{String,Any}()]
        result = ToonFormat.encode(data)
        @test occursin("[1]:", result)
        @test occursin("-", result)  # Empty object outputs "-"
        lines = split(result, '\n')
        @test length(lines) == 2  # Header + empty object line

        # Array with mix of empty and non-empty objects
        data = [Dict{String,Any}(), Dict("x" => 1)]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("-", result)  # Empty object
        @test occursin("- x: 1", result)

        # Very long primitive array
        data = collect(1:100)
        result = ToonFormat.encode(data)
        @test occursin("[100]:", result)
        @test occursin("1,2,3", result)
        @test occursin("99,100", result)

        # Array with quoted strings that contain delimiters
        data = ["a,b", "c,d"]
        result = ToonFormat.encode(data)
        @test occursin("[2]:", result)
        @test occursin("\"a,b\"", result)
        @test occursin("\"c,d\"", result)
    end
end
