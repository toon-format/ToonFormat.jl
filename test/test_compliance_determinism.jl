# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Compliance: Determinism Tests" begin
    @testset "Primitive Determinism" begin
        # Same input should always produce same output
        @test TokenOrientedObjectNotation.encode(42) == TokenOrientedObjectNotation.encode(42)
        @test TokenOrientedObjectNotation.encode("hello") == TokenOrientedObjectNotation.encode("hello")
        @test TokenOrientedObjectNotation.encode(true) == TokenOrientedObjectNotation.encode(true)
        @test TokenOrientedObjectNotation.encode(nothing) == TokenOrientedObjectNotation.encode(nothing)
        
        # Multiple encodings should be identical
        for _ in 1:10
            @test TokenOrientedObjectNotation.encode(3.14) == "3.14"
        end
    end
    
    @testset "Object Determinism" begin
        obj = Dict("name" => "Alice", "age" => 30)
        encoded1 = TokenOrientedObjectNotation.encode(obj)
        encoded2 = TokenOrientedObjectNotation.encode(obj)
        @test encoded1 == encoded2
        
        # Multiple encodings
        results = [TokenOrientedObjectNotation.encode(obj) for _ in 1:5]
        @test all(r == results[1] for r in results)
    end
    
    @testset "Array Determinism" begin
        arr = [1, 2, 3, 4, 5]
        encoded1 = TokenOrientedObjectNotation.encode(arr)
        encoded2 = TokenOrientedObjectNotation.encode(arr)
        @test encoded1 == encoded2
        
        # Multiple encodings
        results = [TokenOrientedObjectNotation.encode(arr) for _ in 1:5]
        @test all(r == results[1] for r in results)
    end
    
    @testset "Complex Structure Determinism" begin
        obj = Dict(
            "users" => [
                Dict("id" => 1, "name" => "Alice"),
                Dict("id" => 2, "name" => "Bob")
            ],
            "config" => Dict("timeout" => 30)
        )
        
        encoded1 = TokenOrientedObjectNotation.encode(obj)
        encoded2 = TokenOrientedObjectNotation.encode(obj)
        @test encoded1 == encoded2
        
        # Multiple encodings
        results = [TokenOrientedObjectNotation.encode(obj) for _ in 1:5]
        @test all(r == results[1] for r in results)
    end
    
    @testset "Idempotence" begin
        # encode(decode(encode(x))) == encode(x)
        obj = Dict("name" => "Alice", "values" => [1, 2, 3])
        encoded1 = TokenOrientedObjectNotation.encode(obj)
        decoded = TokenOrientedObjectNotation.decode(encoded1)
        encoded2 = TokenOrientedObjectNotation.encode(decoded)
        @test encoded1 == encoded2
        
        # Multiple round-trips
        current = obj
        for _ in 1:3
            encoded = TokenOrientedObjectNotation.encode(current)
            current = TokenOrientedObjectNotation.decode(encoded)
        end
        @test TokenOrientedObjectNotation.encode(current) == TokenOrientedObjectNotation.encode(obj)
    end
    
    @testset "Options Determinism" begin
        arr = [1, 2, 3]
        
        # Same options should produce same output
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=4, delimiter=TokenOrientedObjectNotation.TAB)
        @test TokenOrientedObjectNotation.encode(arr, options=opts) == TokenOrientedObjectNotation.encode(arr, options=opts)
        
        # Different options should produce different output
        opts1 = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.COMMA)
        opts2 = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        @test TokenOrientedObjectNotation.encode(arr, options=opts1) != TokenOrientedObjectNotation.encode(arr, options=opts2)
    end
end
