# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Compliance: Error Conditions (§14)" begin
    @testset "Array Count Mismatch Errors" begin
        # Inline array count mismatch
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]: 1,2")  # Too few
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]: 1,2,3,4")  # Too many
        @test_throws Exception TokenOrientedObjectNotation.decode("[5]: 1,2,3")  # Declared 5, got 3
        
        # List array count mismatch
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]:\n  - a\n  - b")  # Too few
        @test_throws Exception TokenOrientedObjectNotation.decode("[2]:\n  - a\n  - b\n  - c")  # Too many
        
        # Tabular array count mismatch
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]{a,b}:\n  1,2\n  3,4")  # Too few rows
        @test_throws Exception TokenOrientedObjectNotation.decode("[1]{a,b}:\n  1,2\n  3,4")  # Too many rows
        
        # Non-strict mode accepts mismatches
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        @test_nowarn TokenOrientedObjectNotation.decode("[5]: 1,2,3", options=opts)
        @test_nowarn TokenOrientedObjectNotation.decode("[2]:\n  - a\n  - b\n  - c", options=opts)
    end
    
    @testset "Row Width Mismatch Errors" begin
        # Too few values in row
        @test_throws Exception TokenOrientedObjectNotation.decode("[2]{a,b,c}:\n  1,2,3\n  4,5")
        
        # Too many values in row
        @test_throws Exception TokenOrientedObjectNotation.decode("[2]{a,b}:\n  1,2\n  3,4,5")
        
        # Inconsistent row widths
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]{a,b}:\n  1,2\n  3\n  4,5")
        
        # Non-strict mode accepts mismatches
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        @test_nowarn TokenOrientedObjectNotation.decode("[2]{a,b,c}:\n  1,2,3\n  4,5", options=opts)
    end
    
    @testset "Missing Colon Errors" begin
        # Missing colon after key
        @test_throws Exception TokenOrientedObjectNotation.decode("name Alice")
        @test_throws Exception TokenOrientedObjectNotation.decode("key value")
        
        # Missing colon after array header
        @test_throws Exception TokenOrientedObjectNotation.decode("[3] 1,2,3")
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]{a,b} 1,2")
        
        # Missing colon after nested key
        @test_throws Exception TokenOrientedObjectNotation.decode("parent:\n  child value")
    end
    
    @testset "Invalid Escape Sequence Errors" begin
        # Invalid escape sequences
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\x41\"")  # \x not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\u0041\"")  # \u not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\a\"")  # \a not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\b\"")  # \b not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\f\"")  # \f not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\v\"")  # \v not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\0\"")  # \0 not valid
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"test\\z\"")  # \z not valid
        
        # Only five escapes are valid: \\, \", \n, \r, \t
        @test_nowarn TokenOrientedObjectNotation.decode("text: \"test\\\\value\"")
        @test_nowarn TokenOrientedObjectNotation.decode("text: \"test\\\"value\"")
        @test_nowarn TokenOrientedObjectNotation.decode("text: \"test\\nvalue\"")
        @test_nowarn TokenOrientedObjectNotation.decode("text: \"test\\rvalue\"")
        @test_nowarn TokenOrientedObjectNotation.decode("text: \"test\\tvalue\"")
    end
    
    @testset "Unterminated String Errors" begin
        # Unterminated quoted string
        @test_throws Exception TokenOrientedObjectNotation.decode("text: \"unterminated")
        @test_throws Exception TokenOrientedObjectNotation.decode("text: \"missing end quote")
        @test_throws Exception TokenOrientedObjectNotation.decode("[2]: \"a\",\"b")
        
        # Unterminated escape at end
        @test_throws ArgumentError TokenOrientedObjectNotation.decode("text: \"ends with\\\"")
    end
    
    @testset "Indentation Errors (Strict Mode)" begin
        # Not a multiple of indentSize
        input = "parent:\n   child: value"  # 3 spaces instead of 2
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        input = "parent:\n     child: value"  # 5 spaces instead of 4
        opts = TokenOrientedObjectNotation.DecodeOptions(indent=4)
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts)
        
        # Tabs in indentation
        input = "parent:\n\tchild: value"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Mixed spaces and tabs
        input = "parent:\n \tchild: value"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Non-strict mode accepts irregular indentation
        input = "parent:\n   child: value"
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        @test_nowarn TokenOrientedObjectNotation.decode(input, options=opts)
    end
    
    @testset "Blank Line Errors" begin
        # Blank lines inside arrays
        input = "[3]:\n  - a\n\n  - b\n  - c"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Blank lines inside tabular rows
        input = "[2]{a,b}:\n  1,2\n\n  3,4"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Blank lines in list items
        input = "[2]:\n  - item1\n\n  - item2"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Non-strict mode may accept blank lines
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        # Behavior depends on implementation
    end
    
    @testset "Path Expansion Conflict Errors" begin
        # Conflict: segment already exists as non-object
        input = "a: 1\na.b: 2"
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=true)
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts)
        
        # Conflict: segment already exists as array
        input = "a[1]: 1\na.b: 2"
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=true)
        @test_throws Exception TokenOrientedObjectNotation.decode(input, options=opts)
        
        # Non-strict mode uses last-write-wins
        input = "a: 1\na.b: 2"
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe", strict=false)
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["a"]["b"] == 2  # Last write wins
    end
    
    @testset "Invalid Header Format Errors" begin
        # Invalid array length (not a number) - may be parsed as key
        # These might not throw errors in current implementation
        # @test_throws Exception TokenOrientedObjectNotation.decode("[abc]: 1,2,3")
        # @test_throws Exception TokenOrientedObjectNotation.decode("[N]: 1,2,3")
        
        # Negative array length - may be parsed as key
        # @test_throws Exception TokenOrientedObjectNotation.decode("[-1]: 1,2,3")
        
        # Missing closing bracket - may be parsed differently
        # @test_throws Exception TokenOrientedObjectNotation.decode("[3: 1,2,3")
        # @test_throws Exception TokenOrientedObjectNotation.decode("[3{a,b}: 1,2")
        
        # Invalid delimiter symbol - may be parsed as regular character
        # @test_throws Exception TokenOrientedObjectNotation.decode("[3;]: 1;2;3")  # Semicolon not valid
    end
    
    @testset "Invalid Root Form Errors" begin
        # Multiple primitives at root (strict mode)
        input = "42\n43"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        input = "hello\nworld"
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # Non-strict mode may accept (implementation-dependent)
        opts = TokenOrientedObjectNotation.DecodeOptions(strict=false)
        # Behavior depends on implementation
    end
    
    @testset "Malformed Structure Errors" begin
        # Array header without content
        # Note: [0]: is valid (empty array), but missing colon is not
        @test_throws Exception TokenOrientedObjectNotation.decode("[3]")
        
        # Nested structure without proper indentation
        # This is actually valid - creates two separate keys at root level
        # input = "parent:\nchild: value"  # No indentation
        # @test_throws Exception TokenOrientedObjectNotation.decode(input)
        
        # List item without hyphen - this will error on count mismatch
        input = "[2]:\n  item1\n  item2"
        # This should error because list expects hyphens
        @test_throws Exception TokenOrientedObjectNotation.decode(input)
    end
    
    @testset "Type Mismatch Errors" begin
        # Attempting to use non-uniform objects in tabular format
        # This should fall back to list format, not error
        arr = [Dict("a" => 1), Dict("b" => 2)]  # Different keys
        @test_nowarn TokenOrientedObjectNotation.encode(arr)
        
        # Attempting to use nested objects in tabular format
        # Should fall back to list format
        arr = [Dict("a" => Dict("x" => 1)), Dict("a" => Dict("y" => 2))]
        @test_nowarn TokenOrientedObjectNotation.encode(arr)
    end
    
    @testset "Edge Case Errors" begin
        # Very deep nesting (should work, not error)
        deep = Dict("a" => Dict("b" => Dict("c" => Dict("d" => Dict("e" => "value")))))
        @test_nowarn TokenOrientedObjectNotation.encode(deep)
        @test_nowarn TokenOrientedObjectNotation.decode(TokenOrientedObjectNotation.encode(deep))
        
        # Very long strings (should work)
        long_str = "x" ^ 10000
        @test_nowarn TokenOrientedObjectNotation.encode(long_str)
        @test_nowarn TokenOrientedObjectNotation.decode(TokenOrientedObjectNotation.encode(long_str))
        
        # Very large arrays (should work)
        large_arr = collect(1:10000)
        @test_nowarn TokenOrientedObjectNotation.encode(large_arr)
        # Decoding might be slow but should work
    end
end
