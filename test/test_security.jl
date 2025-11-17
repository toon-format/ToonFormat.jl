# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Security Tests" begin
    @testset "Resource Exhaustion" begin
        # Deeply nested objects
        nested = Dict("level" => "0")
        for i in 1:100
            nested = Dict("level" => string(i), "child" => nested)
        end
        encoded = TOON.encode(nested)
        @test occursin("level: \"0\"", encoded)  # String values are quoted
        decoded = TOON.decode(encoded)
        @test isa(decoded, AbstractDict)

        # Very long string
        long_str = "x" ^ 100000
        obj = Dict("data" => long_str)
        encoded = TOON.encode(obj)
        decoded = TOON.decode(encoded)
        @test length(decoded["data"]) == 100000

        # Large array
        large_array = collect(1:10000)
        encoded = TOON.encode(large_array)
        @test occursin("[10000]:", encoded)
        decoded = TOON.decode(encoded)
        @test length(decoded) == 10000

        # Many object keys
        many_keys = Dict("key_$i" => i for i in 1:1000)
        encoded = TOON.encode(many_keys)
        decoded = TOON.decode(encoded)
        @test length(decoded) == 1000
    end

    @testset "Malicious Input" begin
        # Unterminated string
        @test_throws Exception TOON.decode("name: \"unterminated")

        # Invalid escape sequence
        @test_throws Exception TOON.decode("text: \"bad\\xescape\"")

        # Tab in indentation (strict mode)
        @test_throws Exception TOON.decode("  \tindented: value")

        # Invalid indentation (strict mode)
        @test_throws Exception TOON.decode("   value: 1", options=TOON.DecodeOptions(indent=2, strict=true))

        # Count mismatch (strict mode)
        @test_throws Exception TOON.decode("items[5]: 1,2,3")
    end

    @testset "Injection Prevention" begin
        # Delimiter in value should be quoted
        obj = Dict("items" => ["a,b", "c"])
        encoded = TOON.encode(obj)
        @test occursin("\"a,b\"", encoded)
        decoded = TOON.decode(encoded)
        @test length(decoded["items"]) == 2
        @test decoded["items"][1] == "a,b"

        # Colon in value should be quoted
        obj = Dict("text" => "fake: value")
        encoded = TOON.encode(obj)
        @test occursin("\"fake: value\"", encoded)
        decoded = TOON.decode(encoded)
        @test length(keys(decoded)) == 1
        @test decoded["text"] == "fake: value"

        # Brackets in value should be quoted
        obj = Dict("text" => "[10]: fake,array")
        encoded = TOON.encode(obj)
        @test occursin("\"[10]: fake,array\"", encoded)
        decoded = TOON.decode(encoded)
        @test decoded["text"] == "[10]: fake,array"
    end

    @testset "Quoting Security" begin
        # Reserved literals must be quoted
        values = ["true", "false", "null"]
        obj = Dict("values" => values)
        encoded = TOON.encode(obj)
        @test occursin("\"true\"", encoded)
        @test occursin("\"false\"", encoded)
        @test occursin("\"null\"", encoded)
        decoded = TOON.decode(encoded)
        @test all(isa(v, String) for v in decoded["values"])

        # Numeric strings must be quoted
        codes = ["123", "3.14", "1e5", "-42"]
        obj = Dict("codes" => codes)
        encoded = TOON.encode(obj)
        for code in codes
            @test occursin("\"$code\"", encoded)
        end
        decoded = TOON.decode(encoded)
        @test all(isa(v, String) for v in decoded["codes"])

        # Octal-like strings must be quoted
        codes = ["0123", "0755"]
        obj = Dict("codes" => codes)
        encoded = TOON.encode(obj)
        @test occursin("\"0123\"", encoded)
        @test occursin("\"0755\"", encoded)
        decoded = TOON.decode(encoded)
        @test all(isa(v, String) for v in decoded["codes"])

        # Empty string must be quoted
        obj = Dict("empty" => "")
        encoded = TOON.encode(obj)
        @test occursin("empty: \"\"", encoded)
        decoded = TOON.decode(encoded)
        @test decoded["empty"] == ""

        # Whitespace strings must be quoted
        obj = Dict("space" => "  ", "tab" => "\t")
        encoded = TOON.encode(obj)
        # Both should be quoted and escaped
        decoded = TOON.decode(encoded)
        @test decoded["space"] == "  "
        @test decoded["tab"] == "\t"

        # Control characters must be escaped
        obj = Dict("newline" => "a\nb", "tab" => "a\tb", "cr" => "a\rb")
        encoded = TOON.encode(obj)
        @test occursin("\\n", encoded)
        @test occursin("\\t", encoded)
        @test occursin("\\r", encoded)
        decoded = TOON.decode(encoded)
        @test decoded["newline"] == "a\nb"
        @test decoded["tab"] == "a\tb"
        @test decoded["cr"] == "a\rb"
    end

    @testset "Edge Cases" begin
        # Empty array
        @test TOON.encode([]) == "[0]:"

        # Empty object
        @test TOON.encode(Dict{String, Any}()) == ""

        # Null values
        obj = Dict("value" => nothing)
        encoded = TOON.encode(obj)
        decoded = TOON.decode(encoded)
        @test decoded["value"] === nothing

        # Mixed types in array
        mixed = [1, "two", true, nothing, 3.14]
        encoded = TOON.encode(mixed)
        decoded = TOON.decode(encoded)
        @test length(decoded) == 5
        @test decoded[1] == 1
        @test decoded[2] == "two"
        @test decoded[3] === true
        @test decoded[4] === nothing
        @test decoded[5] ≈ 3.14
    end

    @testset "Strict Mode Validation" begin
        # Array count mismatch (array property)
        @test_throws Exception TOON.decode("items[5]: 1,2,3", options=TOON.DecodeOptions(strict=true))

        # Lenient mode allows mismatch
        result = TOON.decode("items[5]: 1,2,3", options=TOON.DecodeOptions(strict=false))
        @test length(result["items"]) == 3

        # Invalid indentation in strict mode
        @test_throws Exception TOON.decode("   value: 1", options=TOON.DecodeOptions(indent=2, strict=true))

        # Lenient mode allows invalid indentation
        result = TOON.decode("a: 0\n   b: 1", options=TOON.DecodeOptions(indent=2, strict=false))
        @test haskey(result, "a")
    end
end
