# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Compliance: Determinism Tests" begin
    @testset "Primitive Determinism" begin
        # Same input should always produce same output
        @test ToonFormat.encode(42) == ToonFormat.encode(42)
        @test ToonFormat.encode("hello") == ToonFormat.encode("hello")
        @test ToonFormat.encode(true) == ToonFormat.encode(true)
        @test ToonFormat.encode(nothing) == ToonFormat.encode(nothing)

        # Multiple encodings should be identical
        for _ = 1:10
            @test ToonFormat.encode(3.14) == "3.14"
        end
    end

    @testset "Object Determinism" begin
        obj = Dict("name" => "Alice", "age" => 30)
        encoded1 = ToonFormat.encode(obj)
        encoded2 = ToonFormat.encode(obj)
        @test encoded1 == encoded2

        # Multiple encodings
        results = [ToonFormat.encode(obj) for _ = 1:5]
        @test all(r == results[1] for r in results)
    end

    @testset "Array Determinism" begin
        arr = [1, 2, 3, 4, 5]
        encoded1 = ToonFormat.encode(arr)
        encoded2 = ToonFormat.encode(arr)
        @test encoded1 == encoded2

        # Multiple encodings
        results = [ToonFormat.encode(arr) for _ = 1:5]
        @test all(r == results[1] for r in results)
    end

    @testset "Complex Structure Determinism" begin
        obj = Dict(
            "users" =>
                [Dict("id" => 1, "name" => "Alice"), Dict("id" => 2, "name" => "Bob")],
            "config" => Dict("timeout" => 30),
        )

        encoded1 = ToonFormat.encode(obj)
        encoded2 = ToonFormat.encode(obj)
        @test encoded1 == encoded2

        # Multiple encodings
        results = [ToonFormat.encode(obj) for _ = 1:5]
        @test all(r == results[1] for r in results)
    end

    @testset "Idempotence" begin
        # encode(decode(encode(x))) == encode(x)
        obj = Dict("name" => "Alice", "values" => [1, 2, 3])
        encoded1 = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded1)
        encoded2 = ToonFormat.encode(decoded)
        @test encoded1 == encoded2

        # Multiple round-trips
        current = obj
        for _ = 1:3
            encoded = ToonFormat.encode(current)
            current = ToonFormat.decode(encoded)
        end
        @test ToonFormat.encode(current) == ToonFormat.encode(obj)
    end

    @testset "Options Determinism" begin
        arr = [1, 2, 3]

        # Same options should produce same output
        opts = ToonFormat.EncodeOptions(indent = 4, delimiter = ToonFormat.TAB)
        @test ToonFormat.encode(arr, options = opts) ==
              ToonFormat.encode(arr, options = opts)

        # Different options should produce different output
        opts1 = ToonFormat.EncodeOptions(delimiter = ToonFormat.COMMA)
        opts2 = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB)
        @test ToonFormat.encode(arr, options = opts1) !=
              ToonFormat.encode(arr, options = opts2)
    end
end
