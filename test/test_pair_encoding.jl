# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Tests for Vector{Pair} encoding (Issue #8).

Vector of pairs should be encoded as TOON objects, equivalent to OrderedDict.
"""

using Test
using ToonFormat
using OrderedCollections

@testset "Vector{Pair} Encoding" begin
    @testset "Basic Encoding" begin
        # Single pair
        @test encode(["a"=>1]) == "a: 1"

        # Multiple pairs
        @test encode(["b"=>1, "a"=>2]) == "b: 1\na: 2"

        # Matches OrderedDict output
        pairs_data = ["b"=>1, "a"=>[1,2,3]]
        dict_data = OrderedDict("b"=>1, "a"=>[1,2,3])
        @test encode(pairs_data) == encode(dict_data)

        # String values
        @test encode(["name"=>"Alice", "city"=>"Paris"]) == "name: Alice\ncity: Paris"
    end

    @testset "Edge Cases" begin
        # Empty vector of pairs
        @test encode(Pair{String,Any}[]) == ""

        # Single pair with array value
        @test encode(["items"=>[1,2,3]]) == "items[3]: 1,2,3"

        # Nested pairs (pair value is another vector of pairs)
        nested = ["outer"=>["inner"=>42]]
        @test encode(nested) == "outer:\n  inner: 42"

        # Non-string keys (symbols) - should coerce to string
        @test encode([:a=>1, :b=>2]) == "a: 1\nb: 2"

        # Mixed value types
        mixed = ["str"=>"hello", "num"=>42, "bool"=>true, "nil"=>nothing]
        result = encode(mixed)
        @test occursin("str: hello", result)
        @test occursin("num: 42", result)
        @test occursin("bool: true", result)
        @test occursin("nil: null", result)
    end

    @testset "Duplicate Keys" begin
        # Last value wins
        @test encode(["a"=>1, "b"=>2, "a"=>999]) == "a: 999\nb: 2"
    end

    @testset "Nested Structures" begin
        # Pair with dict value
        with_dict = ["config"=>Dict("key"=>"value")]
        @test occursin("config:", encode(with_dict))

        # Pair with nested array of objects (uses tabular format)
        complex = ["items"=>[Dict("id"=>1), Dict("id"=>2)]]
        @test occursin("items[2]{id}:", encode(complex))
    end

    @testset "Round-trip Consistency" begin
        # Basic round-trip
        pairs = ["x"=>10, "y"=>20]
        decoded = decode(encode(pairs))
        @test decoded["x"] == 10
        @test decoded["y"] == 20

        # Round-trip with nested structure
        nested = ["outer"=>["inner"=>42]]
        decoded = decode(encode(nested))
        @test decoded["outer"]["inner"] == 42

        # Round-trip with array values
        with_array = ["items"=>[1, 2, 3]]
        decoded = decode(encode(with_array))
        @test decoded["items"] == [1, 2, 3]
    end
end
