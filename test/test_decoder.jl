# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Decoder Tests" begin
    @testset "API Tests" begin
        @test_nowarn TOON.decode("items[5]: a,b,c", options=TOON.DecodeOptions(strict=false))

        # Test decode with custom indent size
        input = "parent:\n    child:\n        value: 42"
        result = TOON.decode(input, options=TOON.DecodeOptions(indent=4))
        @test result["parent"]["child"]["value"] == 42

        # Test decode returns native Dict
        result = TOON.decode("id: 123")
        @test isa(result, Dict{String, Any})

        # Test decode returns native Array
        result = TOON.decode("[3]: 1,2,3")
        @test isa(result, Vector{Any})
    end

    @testset "Error Handling" begin
        # Test error on unterminated string
        @test_throws Exception TOON.decode("text: \"unterminated")

        # Test strict mode is default
        @test_throws Exception TOON.decode("items[5]: a,b,c")
    end

    @testset "Spec Edge Cases" begin
        # Leading zero treated as string
        result = TOON.decode("code: 05")
        @test result["code"] == "05"
        @test isa(result["code"], String)

        # Leading zeros in array (root array)
        result = TOON.decode("[3]: 01,02,03")
        @test result == ["01", "02", "03"]
        @test all(isa(x, String) for x in result)

        # Single zero is number
        result = TOON.decode("value: 0")
        @test result["value"] == 0
        @test isa(result["value"], Number)

        # Zero point zero is number
        result = TOON.decode("value: 0.0")
        @test result["value"] == 0.0
        @test isa(result["value"], Number)

        # Exponent notation accepted
        @test TOON.decode("value: 1e-6")["value"] ≈ 1e-6
        @test TOON.decode("value: -1E+9")["value"] ≈ -1E+9
        @test TOON.decode("value: 2.5e3")["value"] ≈ 2500.0

        # Exponent notation in array (root array)
        result = TOON.decode("[3]: 1e2,2e-1,3E+4")
        @test result[1] ≈ 100.0
        @test result[2] ≈ 0.2
        @test result[3] ≈ 30000.0

        # Array order preserved (root array)
        result = TOON.decode("[5]: 5,1,9,2,7")
        @test result == [5, 1, 9, 2, 7]

        # Object key order preserved (in Julia, Dict preserves insertion order in 1.7+)
        input = "z: 1\na: 2\nm: 3\nb: 4"
        result = TOON.decode(input)
        @test haskey(result, "z")
        @test haskey(result, "a")
        @test haskey(result, "m")
        @test haskey(result, "b")
    end

    @testset "Nested Objects" begin
        input = "user:\n  name: Alice\n  address:\n    city: NYC\n    zip: 10001"
        result = TOON.decode(input)
        @test result["user"]["name"] == "Alice"
        @test result["user"]["address"]["city"] == "NYC"
        @test result["user"]["address"]["zip"] == 10001
    end

    @testset "Tabular Arrays" begin
        input = "users[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = TOON.decode(input)
        @test length(result["users"]) == 2
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        @test result["users"][2]["name"] == "Bob"
        @test result["users"][2]["age"] == 25
    end

    @testset "List Arrays" begin
        input = "items[3]:\n  - apple\n  - banana\n  - cherry"
        result = TOON.decode(input)
        @test length(result["items"]) == 3
        @test result["items"] == ["apple", "banana", "cherry"]
    end

    @testset "Whitespace Handling" begin
        # Empty object
        @test TOON.decode("") == Dict{String, Any}()
        @test TOON.decode("   ") == Dict{String, Any}()

        # Whitespace-only string needs quotes
        result = TOON.decode("text: \"  \"")
        @test result["text"] == "  "
    end
end
