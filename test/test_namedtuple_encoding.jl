# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Tests for NamedTuple encoding (Issue #9).

NamedTuple should be encoded as TOON objects, equivalent to OrderedDict.
"""

using Test
using ToonFormat
using OrderedCollections

@testset "NamedTuple Encoding" begin
    @testset "Basic Encoding" begin
        # Single field
        @test encode((a=1,)) == "a: 1"

        # Multiple fields
        @test encode((b=1, a=2)) == "b: 1\na: 2"

        # Matches OrderedDict output
        tuple_data = (b=1, a=2)
        dict_data = OrderedDict("b"=>1, "a"=>2)
        @test encode(tuple_data) == encode(dict_data)

        # String values
        @test encode((name="Alice", city="Paris")) == "name: Alice\ncity: Paris"
    end

    @testset "Edge Cases" begin
        # Empty NamedTuple
        @test encode(NamedTuple()) == ""

        # Single field with array value
        @test encode((items=[1,2,3],)) == "items[3]: 1,2,3"

        # Nested NamedTuple
        nested = (outer=(inner=42,),)
        @test encode(nested) == "outer:\n  inner: 42"

        # Mixed value types
        mixed = (str="hello", num=42, flag=true, nil=nothing)
        result = encode(mixed)
        @test occursin("str: hello", result)
        @test occursin("num: 42", result)
        @test occursin("flag: true", result)
        @test occursin("nil: null", result)
    end

    @testset "Array Values" begin
        # NamedTuple with array value
        with_array = (name="Alice", scores=[90, 85, 92])
        @test encode(with_array) == "name: Alice\nscores[3]: 90,85,92"

        # NamedTuple with nested array of objects
        complex = (items=[Dict("id"=>1), Dict("id"=>2)],)
        @test occursin("items[2]{id}:", encode(complex))
    end

    @testset "Nested Structures" begin
        # NamedTuple with Dict value
        with_dict = (config=Dict("key"=>"value"),)
        @test occursin("config:", encode(with_dict))

        # Deeply nested NamedTuple
        deep = (level1=(level2=(level3=42,),),)
        result = encode(deep)
        @test occursin("level1:", result)
        @test occursin("level2:", result)
        @test occursin("level3: 42", result)
    end

    @testset "Round-trip Consistency" begin
        # Basic round-trip
        tuple_data = (x=10, y=20)
        decoded = decode(encode(tuple_data))
        @test decoded["x"] == 10
        @test decoded["y"] == 20

        # Round-trip with nested structure
        nested = (outer=(inner=42,),)
        decoded = decode(encode(nested))
        @test decoded["outer"]["inner"] == 42

        # Round-trip with array values
        with_array = (items=[1, 2, 3],)
        decoded = decode(encode(with_array))
        @test decoded["items"] == [1, 2, 3]
    end
end
