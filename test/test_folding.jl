# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Key Folding and Path Expansion Tests" begin
    @testset "Key Folding - Basic" begin
        # Multi-key object should NOT be folded
        data = Dict("user" => Dict("name" => "Alice", "age" => 30))
        opts = TOON.EncodeOptions(keyFolding="safe")
        result = TOON.encode(data, options=opts)
        @test occursin("user:", result)
        @test occursin("  name: Alice", result)
        @test occursin("  age: 30", result)
        @test !occursin("user.name", result)
        @test !occursin("user.age", result)

        # Single-key chain should be folded
        data = Dict("a" => Dict("b" => Dict("c" => "value")))
        result = TOON.encode(data, options=opts)
        @test occursin("a.b.c: value", result)
    end

    @testset "Key Folding - flattenDepth" begin
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => "value"))))

        # flattenDepth=2 should fold only "a.b"
        opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
        result = TOON.encode(data, options=opts)
        @test occursin("a.b:", result)
        @test occursin("  c:", result)
        @test occursin("    d: value", result)

        # flattenDepth=3 should fold "a.b.c"
        opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=3)
        result = TOON.encode(data, options=opts)
        @test occursin("a.b.c:", result)
        @test occursin("  d: value", result)

        # flattenDepth=10 should fold everything
        opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=10)
        result = TOON.encode(data, options=opts)
        @test result == "a.b.c.d: value"
    end

    @testset "Key Folding - Arrays" begin
        # Nested object with array
        data = Dict("data" => Dict("users" => [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]))
        opts = TOON.EncodeOptions(keyFolding="safe")
        result = TOON.encode(data, options=opts)
        @test occursin("data.users[2]", result)

        # Deeply nested with array
        data = Dict("app" => Dict("config" => Dict("items" => [1, 2, 3])))
        result = TOON.encode(data, options=opts)
        @test occursin("app.config.items[3]: 1,2,3", result)
    end

    @testset "Key Folding - Safe Mode" begin
        # Keys with dots are NOT safe identifiers, so they don't participate in folding
        # The key "user.id" will be output as-is and its child "value" nested normally
        data = Dict("user.id" => Dict("value" => 123))
        opts = TOON.EncodeOptions(keyFolding="safe")
        result = TOON.encode(data, options=opts)
        @test occursin("user.id:", result)  # Key as-is (may or may not be quoted)
        @test occursin("  value: 123", result)  # Nested normally
        @test !occursin("user.id.value", result)  # Should not be folded

        # Non-identifier keys should not be folded
        data = Dict("user-name" => Dict("first" => "Alice"))
        result = TOON.encode(data, options=opts)
        @test !occursin("user-name.first", result)
    end

    @testset "Key Folding - Quoting Prevention" begin
        # Keys that require quoting should not be folded
        opts = TOON.EncodeOptions(keyFolding="safe")
        
        # Key with space
        data = Dict("user name" => Dict("value" => 123))
        result = TOON.encode(data, options=opts)
        @test occursin("\"user name\":", result)
        @test occursin("  value: 123", result)
        @test !occursin("user name.value", result)
        
        # Key with special characters
        data = Dict("user:id" => Dict("value" => 123))
        result = TOON.encode(data, options=opts)
        @test occursin("\"user:id\":", result)
        @test occursin("  value: 123", result)
        
        # Numeric-like key
        data = Dict("123" => Dict("value" => "test"))
        result = TOON.encode(data, options=opts)
        @test occursin("\"123\":", result)
        @test occursin("  value: test", result)
    end

    @testset "Key Folding - Collision Detection" begin
        opts = TOON.EncodeOptions(keyFolding="safe")
        
        # No collision: "a" has a sibling "c", but folding "a.b" is still safe
        # because there's no literal key "a.b" at the top level
        data = Dict("a" => Dict("b" => 1), "c" => 2)
        result = TOON.encode(data, options=opts)
        @test occursin("a.b: 1", result)
        @test occursin("c: 2", result)
        
        # No collision: only "a" exists, so folding is safe
        data = Dict("a" => Dict("b" => Dict("c" => 1)))
        result = TOON.encode(data, options=opts)
        @test occursin("a.b.c: 1", result)
        
        # Collision with literal dotted key: if we have "a.b" as a literal key
        # and "a" as another key, we can't fold "a.c" because it would be ambiguous
        # However, this is actually OK in TOON - "a.b" is a literal key (possibly quoted)
        # and "a.c" is a folded key. They don't collide.
        data = Dict("a.b" => 1, "a" => Dict("c" => 2))
        result = TOON.encode(data, options=opts)
        # "a.b" is a literal key (may be quoted because it contains a dot)
        # "a" can still be folded to "a.c"
        @test occursin("a.b: 1", result) || occursin("\"a.b\": 1", result)
        # "a" is a single-key object, so it should be folded
        @test occursin("a.c: 2", result)
    end

    @testset "Key Folding - Single-Key Object Requirement" begin
        opts = TOON.EncodeOptions(keyFolding="safe")
        
        # Multi-key object should stop folding
        data = Dict("a" => Dict("b" => 1, "c" => 2))
        result = TOON.encode(data, options=opts)
        @test occursin("a:", result)
        @test occursin("  b: 1", result)
        @test occursin("  c: 2", result)
        @test !occursin("a.b:", result)
        @test !occursin("a.c:", result)
        
        # Single-key chain ending in multi-key object
        data = Dict("a" => Dict("b" => Dict("c" => 1, "d" => 2)))
        result = TOON.encode(data, options=opts)
        @test occursin("a.b:", result)
        @test occursin("  c: 1", result)
        @test occursin("  d: 2", result)
        @test !occursin("a.b.c:", result)
    end

    @testset "Key Folding - Partial Folding" begin
        opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
        
        # Should fold "a.b" but stop there
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => 1))))
        result = TOON.encode(data, options=opts)
        @test occursin("a.b:", result)
        @test occursin("  c:", result)
        @test occursin("    d: 1", result)
        @test !occursin("a.b.c", result)
        
        # Verify the nested object after partial fold doesn't re-fold
        lines = split(result, '\n')
        @test any(line -> occursin("a.b:", line), lines)
        @test any(line -> occursin("  c:", line), lines)
        @test any(line -> occursin("    d: 1", line), lines)
    end

    @testset "Key Folding - Off Mode" begin
        data = Dict("user" => Dict("name" => "Alice"))
        opts = TOON.EncodeOptions(keyFolding="off")
        result = TOON.encode(data, options=opts)
        @test occursin("user:", result)
        @test occursin("  name: Alice", result)
        @test !occursin("user.name", result)
    end

    @testset "Path Expansion - Basic" begin
        # Simple dotted key
        input = "user.name: Alice"
        opts = TOON.DecodeOptions(expandPaths="safe")
        result = TOON.decode(input, options=opts)
        @test haskey(result, "user")
        @test haskey(result["user"], "name")
        @test result["user"]["name"] == "Alice"

        # Multiple dotted keys
        input = "user.profile.name: Alice\nuser.profile.age: 30"
        result = TOON.decode(input, options=opts)
        @test result["user"]["profile"]["name"] == "Alice"
        @test result["user"]["profile"]["age"] == 30
    end

    @testset "Path Expansion - Arrays" begin
        input = "data.users[2]{id,name}:\n  1,Alice\n  2,Bob"
        opts = TOON.DecodeOptions(expandPaths="safe")
        result = TOON.decode(input, options=opts)
        @test haskey(result, "data")
        @test haskey(result["data"], "users")
        @test length(result["data"]["users"]) == 2
        @test result["data"]["users"][1]["name"] == "Alice"
    end

    @testset "Path Expansion - Safe Mode" begin
        # Quoted keys still get expanded if they are safe identifiers
        # To prevent expansion, use expandPaths="off"
        input = "\"user.id\": 123"
        opts = TOON.DecodeOptions(expandPaths="safe")
        result = TOON.decode(input, options=opts)
        # "user.id" is parsed to the string "user.id" which contains valid identifier segments
        # so it WILL be expanded in safe mode
        @test haskey(result, "user")
        @test haskey(result["user"], "id")
        @test result["user"]["id"] == 123

        # Mix of dotted and non-dotted
        input = "user.name: Alice\nemail: alice@example.com"
        result = TOON.decode(input, options=opts)
        @test haskey(result, "user")
        @test haskey(result, "email")
        @test result["user"]["name"] == "Alice"
        @test result["email"] == "alice@example.com"
    end

    @testset "Path Expansion - Off Mode" begin
        input = "user.name: Alice"
        opts = TOON.DecodeOptions(expandPaths="off")
        result = TOON.decode(input, options=opts)
        @test haskey(result, "user.name")  # Literal key
        @test result["user.name"] == "Alice"
        @test !haskey(result, "user")
    end

    @testset "Round-Trip - Folding and Expansion" begin
        # Simple case
        data = Dict("user" => Dict("profile" => Dict("name" => "Alice", "age" => 30)))
        enc_opts = TOON.EncodeOptions(keyFolding="safe")
        encoded = TOON.encode(data, options=enc_opts)
        dec_opts = TOON.DecodeOptions(expandPaths="safe")
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data

        # With arrays
        data = Dict("data" => Dict("users" => [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]))
        encoded = TOON.encode(data, options=enc_opts)
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data

        # Deep nesting
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => "value"))))
        encoded = TOON.encode(data, options=enc_opts)
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data
    end

    @testset "Round-Trip - With flattenDepth" begin
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => "value"))))

        # flattenDepth=2
        enc_opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
        encoded = TOON.encode(data, options=enc_opts)
        dec_opts = TOON.DecodeOptions(expandPaths="safe")
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data

        # flattenDepth=3
        enc_opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=3)
        encoded = TOON.encode(data, options=enc_opts)
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data
    end

    @testset "Edge Cases" begin
        # Empty nested objects
        data = Dict("user" => Dict{String,Any}())
        enc_opts = TOON.EncodeOptions(keyFolding="safe")
        encoded = TOON.encode(data, options=enc_opts)
        dec_opts = TOON.DecodeOptions(expandPaths="safe")
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data

        # Single character keys
        data = Dict("a" => Dict("b" => "c"))
        encoded = TOON.encode(data, options=enc_opts)
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data

        # Underscore in keys
        data = Dict("user_id" => Dict("profile_name" => "Alice"))
        encoded = TOON.encode(data, options=enc_opts)
        @test occursin("user_id.profile_name", encoded)
        decoded = TOON.decode(encoded, options=dec_opts)
        @test decoded == data
    end
end
