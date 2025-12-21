# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Root Form Detection Tests (Task 8)" begin
    @testset "Root Array Detection (Requirement 11.1)" begin
        # Basic root array with comma delimiter
        result = ToonFormat.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]
        @test isa(result, Vector{Any})

        # Root array with tab delimiter
        result = ToonFormat.decode("[2\t]: a\tb")
        @test result == ["a", "b"]

        # Root array with pipe delimiter
        result = ToonFormat.decode("[2|]: x|y")
        @test result == ["x", "y"]

        # Root array with tabular format
        result = ToonFormat.decode("[2]{name,age}:\n  Alice,30\n  Bob,25")
        @test length(result) == 2
        @test result[1]["name"] == "Alice"
        @test result[1]["age"] == 30

        # Root array with list format
        result = ToonFormat.decode("[3]:\n  - apple\n  - banana\n  - cherry")
        @test result == ["apple", "banana", "cherry"]

        # Empty root array
        result = ToonFormat.decode("[0]:")
        @test result == []
        @test isa(result, Vector{Any})
    end

    @testset "Single Primitive Detection (Requirement 11.2)" begin
        # Single string primitive
        result = ToonFormat.decode("hello")
        @test result == "hello"
        @test isa(result, String)

        # Single number primitive
        result = ToonFormat.decode("42")
        @test result == 42
        @test isa(result, Number)

        # Single float primitive
        result = ToonFormat.decode("3.14")
        @test result == 3.14
        @test isa(result, Number)

        # Single boolean primitive - true
        result = ToonFormat.decode("true")
        @test result == true
        @test isa(result, Bool)

        # Single boolean primitive - false
        result = ToonFormat.decode("false")
        @test result == false
        @test isa(result, Bool)

        # Single null primitive
        result = ToonFormat.decode("null")
        @test result === nothing

        # Single quoted string
        result = ToonFormat.decode("\"hello world\"")
        @test result == "hello world"

        # Single empty string (quoted)
        result = ToonFormat.decode("\"\"")
        @test result == ""

        # Single string with special characters
        result = ToonFormat.decode("\"test:value\"")
        @test result == "test:value"
    end

    @testset "Object Detection (Requirement 11.3)" begin
        # Simple object with one key-value pair
        result = ToonFormat.decode("name: Alice")
        @test result == Dict("name" => "Alice")
        @test isa(result, AbstractDict)

        # Object with multiple key-value pairs
        result = ToonFormat.decode("name: Alice\nage: 30")
        @test result["name"] == "Alice"
        @test result["age"] == 30

        # Object with nested object
        result = ToonFormat.decode("user:\n  name: Alice\n  age: 30")
        @test result["user"]["name"] == "Alice"
        @test result["user"]["age"] == 30

        # Object with array
        result = ToonFormat.decode("items[2]: a,b")
        @test result["items"] == ["a", "b"]
    end

    @testset "Empty Document (Requirement 11.4)" begin
        # Completely empty string
        result = ToonFormat.decode("")
        @test result == Dict{String,Any}()
        @test isa(result, AbstractDict)

        # Only whitespace
        result = ToonFormat.decode("   ")
        @test result == Dict{String,Any}()

        # Only newlines
        result = ToonFormat.decode("\n\n\n")
        @test result == Dict{String,Any}()

        # Mixed whitespace
        result = ToonFormat.decode("  \n  \n  ")
        @test result == Dict{String,Any}()
    end

    @testset "Invalid Multi-Primitive in Strict Mode" begin
        # Multiple primitives should error in strict mode
        @test_throws Exception ToonFormat.decode("hello\nworld")
        @test_throws Exception ToonFormat.decode("42\n3.14")
        @test_throws Exception ToonFormat.decode("true\nfalse")

        # Multiple primitives with blank lines should also error
        @test_throws Exception ToonFormat.decode("hello\n\nworld")

        # Non-strict mode should handle gracefully (treat as object or use first value)
        # This behavior is implementation-defined, but should not crash
        @test_nowarn ToonFormat.decode(
            "hello\nworld",
            options = ToonFormat.DecodeOptions(strict = false),
        )
    end

    @testset "Edge Cases and Ambiguous Inputs" begin
        # String that looks like array header but missing colon
        @test_throws Exception ToonFormat.decode("[3]")

        # String that looks like key but missing colon in strict mode
        @test_throws Exception ToonFormat.decode("name Alice")

        # Non-strict mode should be more lenient
        result = ToonFormat.decode(
            "name Alice",
            options = ToonFormat.DecodeOptions(strict = false),
        )
        # Should treat as single primitive
        @test isa(result, String)

        # Single line with colon is object, not primitive
        result = ToonFormat.decode("key: value")
        @test isa(result, AbstractDict)
        @test result["key"] == "value"

        # Array header at depth 0 with colon is root array
        result = ToonFormat.decode("[1]: x")
        @test isa(result, Vector{Any})
        @test result == ["x"]

        # Multiple root arrays should be treated as object with array keys
        result = ToonFormat.decode(
            "[3]: 1,2,3\n[2]: a,b",
            options = ToonFormat.DecodeOptions(strict = false),
        )
        # This is actually valid - it's an object with no keys, just arrays at root level
        # In strict mode, this would need proper depth handling
    end
end
