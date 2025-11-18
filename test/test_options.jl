# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Options Tests" begin
    @testset "EncodeOptions Defaults (Requirements 15.1, 15.2, 15.3, 15.4)" begin
        # Test default values
        opts = TokenOrientedObjectNotation.EncodeOptions()
        @test opts.indent == 2
        @test opts.delimiter == TokenOrientedObjectNotation.COMMA
        @test opts.keyFolding == "off"
        @test opts.flattenDepth == typemax(Int)
        
        # Test that encode works with default options
        data = Dict("a" => 1, "b" => 2)
        result = TokenOrientedObjectNotation.encode(data)
        @test occursin("a: 1", result) || occursin("a: 2", result)
    end
    
    @testset "DecodeOptions Defaults (Requirements 15.5, 15.6, 15.7)" begin
        # Test default values
        opts = TokenOrientedObjectNotation.DecodeOptions()
        @test opts.indent == 2
        @test opts.strict == true
        @test opts.expandPaths == "off"
        
        # Test that decode works with default options
        input = "a: 1\nb: 2"
        result = TokenOrientedObjectNotation.decode(input)
        @test result["a"] == 1
        @test result["b"] == 2
    end
    
    @testset "EncodeOptions Custom Values" begin
        # Test custom indent
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=4)
        @test opts.indent == 4
        @test opts.delimiter == TokenOrientedObjectNotation.COMMA  # Other defaults preserved
        
        data = Dict("parent" => Dict("child" => 1))
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        lines = split(result, '\n')
        @test lines[1] == "parent:"
        @test lines[2] == "    child: 1"  # 4 spaces
        
        # Test custom delimiter
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        @test opts.delimiter == TokenOrientedObjectNotation.TAB
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=opts)
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)
        
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        @test opts.delimiter == TokenOrientedObjectNotation.PIPE
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=opts)
        @test occursin("[3|]:", result)
        @test occursin("1|2|3", result)
        
        # Test keyFolding
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe")
        @test opts.keyFolding == "safe"
        data = Dict("a" => Dict("b" => Dict("c" => 1)))
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("a.b.c: 1", result)
        
        # Test flattenDepth
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe", flattenDepth=2)
        @test opts.flattenDepth == 2
        data = Dict("a" => Dict("b" => Dict("c" => Dict("d" => 1))))
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("a.b:", result)
        @test !occursin("a.b.c.d:", result)
    end
    
    @testset "DecodeOptions Custom Values" begin
        # Test custom indent
        opts = TokenOrientedObjectNotation.DecodeOptions(indent=4)
        @test opts.indent == 4
        input = "parent:\n    child: 1"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["parent"]["child"] == 1
        
        # Test strict mode
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        @test opts.strict == false
        # Count mismatch should be allowed in non-strict mode
        result = TokenOrientedObjectNotation.decode("[5]: 1,2,3", options=opts)
        @test length(result) == 3
        
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=true)
        @test opts.strict == true
        # Count mismatch should error in strict mode
        @test_throws Exception TokenOrientedObjectNotation.decode("[5]: 1,2,3", options=opts)
        
        # Test expandPaths
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        @test opts.expandPaths == "safe"
        input = "a.b.c: 1"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["a"]["b"]["c"] == 1
    end
    
    @testset "Option Combinations" begin
        # Encode with multiple custom options
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(indent=4, delimiter=TokenOrientedObjectNotation.TAB, keyFolding="safe", flattenDepth=3)
        data = Dict(
            "config" => Dict(
                "server" => Dict(
                    "host" => "localhost",
                    "port" => 8080
                )
            ),
            "items" => [1, 2, 3]
        )
        result = TokenOrientedObjectNotation.encode(data, options=enc_opts)
        
        # Verify indent (4 spaces)
        @test occursin("    ", result)
        # Verify delimiter (tab in array)
        @test occursin("[3\t]:", result)
        @test occursin("1\t2\t3", result)
        # Verify key folding (stops at multi-key object)
        @test occursin("config.server:", result)
        
        # Decode with multiple custom options
        dec_opts = TokenOrientedObjectNotation.DecodeOptions(indent=4, strict=false, expandPaths="safe")
        input = """
        a.b: 1
        c.d: 2
        items[5]: 1,2,3
        """
        result = TokenOrientedObjectNotation.decode(input, options=dec_opts)
        @test result["a"]["b"] == 1
        @test result["c"]["d"] == 2
        @test length(result["items"]) == 3  # Non-strict allows count mismatch
    end
    
    @testset "Round-Trip with Options" begin
        # Test that encode/decode with matching options preserves data
        original = Dict(
            "name" => "Alice",
            "age" => 30,
            "scores" => [95, 87, 92],
            "address" => Dict(
                "city" => "NYC",
                "zip" => "10001"
            )
        )
        
        # Default options
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded == original
        
        # Custom indent
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(indent=4)
        dec_opts = TokenOrientedObjectNotation.DecodeOptions(indent=4)
        encoded = TokenOrientedObjectNotation.encode(original, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == original
        
        # Tab delimiter
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        encoded = TokenOrientedObjectNotation.encode(original, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded == original
        
        # Pipe delimiter
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        encoded = TokenOrientedObjectNotation.encode(original, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded == original
        
        # Key folding and path expansion
        enc_opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe")
        dec_opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        encoded = TokenOrientedObjectNotation.encode(original, options=enc_opts)
        decoded = TokenOrientedObjectNotation.decode(encoded, options=dec_opts)
        @test decoded == original
    end
    
    @testset "flattenDepth Behavior with keyFolding" begin
        # When keyFolding is "off", flattenDepth should be ignored
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="off", flattenDepth=1)
        data = Dict("a" => Dict("b" => Dict("c" => 1)))
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test !occursin("a.b", result)  # No folding should occur
        
        # When keyFolding is "safe", flattenDepth should limit folding
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe", flattenDepth=1)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("a:", result)
        @test !occursin("a.b.c:", result)  # Should not fold beyond depth 1
        
        # Default flattenDepth (Infinity) should fold all levels
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe")
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("a.b.c: 1", result)
        
        # flattenDepth=0 should disable folding even with keyFolding="safe"
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe", flattenDepth=0)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test !occursin("a.b", result)
    end
    
    @testset "Strict Mode Behavior" begin
        # Strict mode (default) should enforce validation
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=true)
        
        # Count mismatch
        @test_throws Exception TokenOrientedObjectNotation.decode("[5]: 1,2,3", options=opts)
        
        # Invalid indentation
        @test_throws Exception TokenOrientedObjectNotation.decode("a:\n   b: 1", options=opts)
        
        # Tabs in indentation
        @test_throws Exception TokenOrientedObjectNotation.decode("\ta: 1", options=opts)
        
        # Non-strict mode should be lenient
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        
        # Count mismatch allowed
        result = TokenOrientedObjectNotation.decode("[5]: 1,2,3", options=opts)
        @test length(result) == 3
        
        # Invalid indentation allowed
        result = TokenOrientedObjectNotation.decode("a:\n   b: 1", options=opts)
        @test haskey(result, "a")
        
        # Tabs allowed (treated as single space)
        result = TokenOrientedObjectNotation.decode("\ta: 1", options=opts)
        @test haskey(result, "a")
    end
    
    @testset "expandPaths Modes" begin
        # expandPaths="off" (default) should not expand
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="off")
        input = "a.b.c: 1"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "a.b.c")
        @test result["a.b.c"] == 1
        
        # expandPaths="safe" should expand identifier segments
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "a")
        @test haskey(result["a"], "b")
        @test haskey(result["a"]["b"], "c")
        @test result["a"]["b"]["c"] == 1
        
        # Non-identifier segments should not be expanded even in safe mode
        input = "a.b-c: 1"
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test haskey(result, "a.b-c")  # Not expanded due to hyphen
    end
    
    @testset "Delimiter Option Values" begin
        # Test all valid delimiter values
        data = [1, 2, 3, 4, 5]
        
        # Comma (default)
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.COMMA)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("[5]:", result)
        @test occursin("1,2,3,4,5", result)
        
        # Tab
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("[5\t]:", result)
        @test occursin("1\t2\t3\t4\t5", result)
        
        # Pipe
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        @test occursin("[5|]:", result)
        @test occursin("1|2|3|4|5", result)
    end
    
    @testset "Indent Option Range" begin
        data = Dict("a" => Dict("b" => 1))
        
        # Small indent
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=1)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        lines = split(result, '\n')
        @test lines[2] == " b: 1"
        
        # Default indent
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=2)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        lines = split(result, '\n')
        @test lines[2] == "  b: 1"
        
        # Large indent
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=8)
        result = TokenOrientedObjectNotation.encode(data, options=opts)
        lines = split(result, '\n')
        @test lines[2] == "        b: 1"
        
        # Decode with matching indent
        dec_opts = TokenOrientedObjectNotation.DecodeOptions(indent=8)
        decoded = TokenOrientedObjectNotation.decode(result, options=dec_opts)
        @test decoded == data
    end
end
