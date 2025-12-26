# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Tests for Tuple of Pairs encoding (Issue #10).

Tuples containing only Pair elements should be encoded as TOON objects.
Regular tuples (mixed content) should still encode as arrays.
"""

using Test
using ToonFormat
using OrderedCollections

@testset "Tuple of Pairs Encoding" begin
    @testset "Basic Encoding" begin
        # Single pair tuple
        @test encode((:a=>1,)) == "a: 1"

        # Multiple pairs
        @test encode((:b=>1, :a=>2)) == "b: 1\na: 2"

        # Matches OrderedDict output
        tuple_pairs = (:b=>1, :a=>2)
        dict_data = OrderedDict("b"=>1, "a"=>2)
        @test encode(tuple_pairs) == encode(dict_data)

        # String keys in tuple of pairs
        @test encode(("name"=>"Alice", "city"=>"Paris")) == "name: Alice\ncity: Paris"
    end

    @testset "Edge Cases" begin
        # Single pair with array value
        @test encode((:items=>[1,2,3],)) == "items[3]: 1,2,3"

        # Nested tuple of pairs
        nested = (:outer=>(:inner=>42,),)
        @test encode(nested) == "outer:\n  inner: 42"

        # Symbol keys converted to strings
        @test encode((:a=>1, :b=>2)) == "a: 1\nb: 2"

        # Mixed value types
        mixed = (:str=>"hello", :num=>42, :flag=>true, :nil=>nothing)
        result = encode(mixed)
        @test occursin("str: hello", result)
        @test occursin("num: 42", result)
        @test occursin("flag: true", result)
        @test occursin("nil: null", result)
    end

    @testset "Duplicate Keys" begin
        # Last value wins
        dupes = (:a=>1, :b=>2, :a=>3)
        @test encode(dupes) == "a: 3\nb: 2"
    end

    @testset "Mixed Tuples (Not All Pairs)" begin
        # Mixed tuple - NOT all pairs, encodes as array
        mixed = (1, :a=>2, "hello")
        result = encode(mixed)
        @test startswith(result, "[3]:")

        # Regular tuple without pairs - should encode as array
        regular = (1, 2, 3)
        @test encode(regular) == "[3]: 1,2,3"

        # Tuple with some non-pair elements - array
        some_pairs = (1, :a=>2)
        @test startswith(encode(some_pairs), "[2]:")
    end

    @testset "Array Values" begin
        # Tuple of pairs with array value
        with_array = (:name=>"Alice", :scores=>[90, 85])
        @test encode(with_array) == "name: Alice\nscores[2]: 90,85"
    end

    @testset "Nested Structures" begin
        # Tuple of pairs with Dict value
        with_dict = (:config=>Dict("key"=>"value"),)
        @test occursin("config:", encode(with_dict))

        # Deeply nested tuple of pairs
        deep = (:level1=>(:level2=>(:level3=>42,),),)
        result = encode(deep)
        @test occursin("level1:", result)
        @test occursin("level2:", result)
        @test occursin("level3: 42", result)
    end

    @testset "Round-trip Consistency" begin
        # Basic round-trip
        tuple_pairs = (:x=>10, :y=>20)
        decoded = decode(encode(tuple_pairs))
        @test decoded["x"] == 10
        @test decoded["y"] == 20

        # Round-trip with nested structure
        nested = (:outer=>(:inner=>42,),)
        decoded = decode(encode(nested))
        @test decoded["outer"]["inner"] == 42

        # Round-trip with array values
        with_array = (:items=>[1, 2, 3],)
        decoded = decode(encode(with_array))
        @test decoded["items"] == [1, 2, 3]
    end
end
