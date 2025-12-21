# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Decoder Tests" begin
    @testset "API Tests" begin
        @test_nowarn ToonFormat.decode(
            "items[5]: a,b,c",
            options = ToonFormat.DecodeOptions(strict = false),
        )

        # Test decode with custom indent size
        input = "parent:\n    child:\n        value: 42"
        result = ToonFormat.decode(input, options = ToonFormat.DecodeOptions(indent = 4))
        @test result["parent"]["child"]["value"] == 42

        # Test decode returns native Dict (OrderedDict to preserve key order)
        result = ToonFormat.decode("id: 123")
        @test isa(result, AbstractDict)

        # Test decode returns native Array
        result = ToonFormat.decode("[3]: 1,2,3")
        @test isa(result, Vector{Any})
    end

    @testset "Error Handling" begin
        # Test error on unterminated string
        @test_throws Exception ToonFormat.decode("text: \"unterminated")

        # Test strict mode is default
        @test_throws Exception ToonFormat.decode("items[5]: a,b,c")

        # Test invalid escape sequences are rejected (Requirement 3.2)
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\x41\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\u0041\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\a\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\b\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\f\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\v\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\0\"")

        # Test unterminated escape sequence
        @test_throws ArgumentError ToonFormat.decode("text: \"test\\\"")
    end

    @testset "Spec Edge Cases" begin
        # Leading zero treated as string
        result = ToonFormat.decode("code: 05")
        @test result["code"] == "05"
        @test isa(result["code"], String)

        # Leading zeros in array (root array)
        result = ToonFormat.decode("[3]: 01,02,03")
        @test result == ["01", "02", "03"]
        @test all(isa(x, String) for x in result)

        # Single zero is number
        result = ToonFormat.decode("value: 0")
        @test result["value"] == 0
        @test isa(result["value"], Number)

        # Zero point zero is number
        result = ToonFormat.decode("value: 0.0")
        @test result["value"] == 0.0
        @test isa(result["value"], Number)

        # Exponent notation accepted
        @test ToonFormat.decode("value: 1e-6")["value"] ≈ 1e-6
        @test ToonFormat.decode("value: -1E+9")["value"] ≈ -1E+9
        @test ToonFormat.decode("value: 2.5e3")["value"] ≈ 2500.0

        # Exponent notation in array (root array)
        result = ToonFormat.decode("[3]: 1e2,2e-1,3E+4")
        @test result[1] ≈ 100.0
        @test result[2] ≈ 0.2
        @test result[3] ≈ 30000.0

        # Array order preserved (root array)
        result = ToonFormat.decode("[5]: 5,1,9,2,7")
        @test result == [5, 1, 9, 2, 7]

        # Object key order preserved (in Julia, Dict preserves insertion order in 1.7+)
        input = "z: 1\na: 2\nm: 3\nb: 4"
        result = ToonFormat.decode(input)
        @test haskey(result, "z")
        @test haskey(result, "a")
        @test haskey(result, "m")
        @test haskey(result, "b")
    end

    @testset "Nested Objects" begin
        input = "user:\n  name: Alice\n  address:\n    city: NYC\n    zip: 10001"
        result = ToonFormat.decode(input)
        @test result["user"]["name"] == "Alice"
        @test result["user"]["address"]["city"] == "NYC"
        @test result["user"]["address"]["zip"] == 10001
    end

    @testset "Tabular Arrays" begin
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = ToonFormat.decode(input)
        @test length(result["users"]) == 2
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        @test result["users"][2]["name"] == "Bob"
        @test result["users"][2]["age"] == 25
    end

    @testset "List Arrays" begin
        input = "items[3]:\n  - apple\n  - banana\n  - cherry"
        result = ToonFormat.decode(input)
        @test length(result["items"]) == 3
        @test result["items"] == ["apple", "banana", "cherry"]
    end

    @testset "Whitespace Handling" begin
        # Empty object
        @test ToonFormat.decode("") == Dict{String,Any}()
        @test ToonFormat.decode("   ") == Dict{String,Any}()

        # Whitespace-only string needs quotes
        result = ToonFormat.decode("text: \"  \"")
        @test result["text"] == "  "
    end

    @testset "Escape Sequence Handling (Requirements 3.1, 3.2)" begin
        # Test all five valid escape sequences in decoded strings
        @test ToonFormat.decode("text: \"hello\\nworld\"")["text"] == "hello\nworld"
        @test ToonFormat.decode("text: \"col1\\tcol2\"")["text"] == "col1\tcol2"
        @test ToonFormat.decode("text: \"line1\\rline2\"")["text"] == "line1\rline2"
        @test ToonFormat.decode("text: \"path\\\\to\\\\file\"")["text"] == "path\\to\\file"
        @test ToonFormat.decode("text: \"say \\\"hello\\\"\"")["text"] == "say \"hello\""

        # Test multiple escape sequences
        @test ToonFormat.decode("text: \"test\\n\\r\\t\\\\\\\"value\\\"\"")["text"] ==
              "test\n\r\t\\\"value\""

        # Test escape sequences in arrays
        result = ToonFormat.decode("[3]: \"a\\nb\",\"c\\td\",\"e\\\\f\"")
        @test result[1] == "a\nb"
        @test result[2] == "c\td"
        @test result[3] == "e\\f"

        # Test escape sequences in nested objects
        input = "user:\n  name: \"Alice\\nSmith\"\n  path: \"C:\\\\Users\\\\Alice\""
        result = ToonFormat.decode(input)
        @test result["user"]["name"] == "Alice\nSmith"
        @test result["user"]["path"] == "C:\\Users\\Alice"

        # Test escape sequences in tabular arrays
        input = "items[2]{name,desc}:\n  \"Item\\n1\",\"First\\titem\"\n  \"Item\\n2\",\"Second\\titem\""
        result = ToonFormat.decode(input)
        @test result["items"][1]["name"] == "Item\n1"
        @test result["items"][1]["desc"] == "First\titem"
        @test result["items"][2]["name"] == "Item\n2"
        @test result["items"][2]["desc"] == "Second\titem"
    end
end
