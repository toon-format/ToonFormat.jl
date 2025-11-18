# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

"""
Comprehensive tests for path expansion feature (Requirement 14).
"""

using Test
using TokenOrientedObjectNotation

@testset "Path Expansion Comprehensive Tests" begin
    @testset "14.1 - Expansion only with expandPaths=safe" begin
        input = "user.name: Alice"
        
        # With expandPaths="safe", should expand
        result = TokenOrientedObjectNotation.decode(input, options=TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe"))
        @test haskey(result, "user")
        @test result["user"]["name"] == "Alice"
        
        # With expandPaths="off", should NOT expand
        result = TokenOrientedObjectNotation.decode(input, options=TokenOrientedObjectNotation.DecodeOptions(expandPaths="off"))
        @test haskey(result, "user.name")
        @test result["user.name"] == "Alice"
        @test !haskey(result, "user")
    end
    
    @testset "14.2 - Only IdentifierSegment parts are expanded" begin
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        
        # Valid identifiers - should expand
        input = "user.name: Alice"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "user")
        @test result["user"]["name"] == "Alice"
        
        # Valid with underscores and numbers
        input = "user_1.profile_2: data"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "user_1")
        @test result["user_1"]["profile_2"] == "data"
        
        # Key with dots in segment (not valid identifier) - should NOT expand
        # This would require the key to be quoted like "user..name" which is not a valid identifier
        # Actually, if a key contains ".." it would split into empty segments which are not valid identifiers
        
        # Key that starts with number (not valid identifier) - should NOT expand
        input = "\"1user.name\": Alice"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        # "1user" is not a valid identifier (starts with number), so no expansion
        @test haskey(result, "1user.name")
        @test !haskey(result, "1user")
    end
    
    @testset "14.3 - Deep merge for overlapping object paths" begin
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        
        # Multiple keys creating same parent
        input = """
        user.name: Alice
        user.age: 30
        user.email: alice@example.com
        """
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "user")
        @test result["user"]["name"] == "Alice"
        @test result["user"]["age"] == 30
        @test result["user"]["email"] == "alice@example.com"
        
        # Deep nesting with merge
        input = """
        a.b.c: 1
        a.b.d: 2
        a.e: 3
        """
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["a"]["b"]["c"] == 1
        @test result["a"]["b"]["d"] == 2
        @test result["a"]["e"] == 3
        
        # Complex merge scenario
        input = """
        config.database.host: localhost
        config.database.port: 5432
        config.cache.enabled: true
        config.cache.ttl: 3600
        """
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["config"]["database"]["host"] == "localhost"
        @test result["config"]["database"]["port"] == 5432
        @test result["config"]["cache"]["enabled"] == true
        @test result["config"]["cache"]["ttl"] == 3600
    end
    
    @testset "14.4 - Conflict detection (object vs non-object)" begin
        opts_strict = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=true)
        
        # Conflict: primitive first, then try to expand through it
        input = """
        a: 1
        a.b: 2
        """
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts_strict)
        
        # Conflict: expanded path first, then primitive
        input = """
        a.b: 1
        a: 2
        """
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts_strict)
        
        # Conflict: nested object exists, then try to set as primitive
        input = """
        a.b.c: 1
        a.b: 2
        """
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts_strict)
        
        # No conflict: both create objects
        input = """
        a.b: 1
        a.c: 2
        """
        result = TokenOrientedObjectNotation.decode(input, options=opts_strict)
        @test result["a"]["b"] == 1
        @test result["a"]["c"] == 2
    end
    
    @testset "14.5 - Strict vs non-strict conflict resolution" begin
        # Strict mode: error on conflict
        input = """
        a: 1
        a.b: 2
        """
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=true))
        
        # Non-strict mode: last-write-wins
        result = TokenOrientedObjectNotation.decode(input, options=TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=false))
        @test haskey(result, "a")
        # The second assignment (a.b: 2) should create an object, overwriting the primitive
        @test isa(result["a"], AbstractDict)
        @test result["a"]["b"] == 2
        
        # Reverse order
        input = """
        a.b: 1
        a: 2
        """
        result = TokenOrientedObjectNotation.decode(input, options=TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=false))
        @test haskey(result, "a")
        # The second assignment (a: 2) should overwrite the object
        @test result["a"] == 2
    end
    
    @testset "Round-trip compatibility with key folding" begin
        # Simple nested structure
        data = Dict("user" => Dict("profile" => Dict("name" => "Alice", "age" => 30)))
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe")
        encoded = TokenOrientedObjectNotation.encode(data, options=enc_opts)
        dec_opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == data
        
        # With arrays
        data = Dict("data" => Dict("users" => [
            Dict("id" => 1, "name" => "Alice"),
            Dict("id" => 2, "name" => "Bob")
        ]))
        encoded = TokenOrientedObjectNotation.encode(data, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == data
        
        # Deep nesting
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => "value"))))
        encoded = TokenOrientedObjectNotation.encode(data, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == data
        
        # With flattenDepth limit
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe", flattenDepth=2)
        encoded = TokenOrientedObjectNotation.encode(data, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == data
    end
    
    @testset "Edge cases" begin
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        
        # Single segment (no dots) - no expansion
        input = "user: Alice"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["user"] == "Alice"
        
        # Empty value
        input = "user.name:"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "user")
        @test haskey(result["user"], "name")
        @test result["user"]["name"] == Dict{String,Any}()
        
        # Array values
        input = "data.items[2]: 1,2"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "data")
        @test haskey(result["data"], "items")
        @test result["data"]["items"] == [1, 2]
        
        # Mixed expanded and non-expanded keys
        input = """
        user.name: Alice
        email: alice@example.com
        user.age: 30
        """
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["user"]["name"] == "Alice"
        @test result["user"]["age"] == 30
        @test result["email"] == "alice@example.com"
    end
    
    @testset "Keys requiring quoting are not expanded" begin
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        
        # Key with special characters (would require quoting)
        # Note: The key is already parsed at this point, so we test with actual dots
        # Keys with spaces, colons, etc. would be quoted and parsed as literal strings
        
        # A key like "user:name" would be quoted and not expanded
        input = "\"user:name\": Alice"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        # "user:name" contains ":" which makes it not a valid identifier, so no expansion
        @test haskey(result, "user:name")
        @test !haskey(result, "user")
    end
end
