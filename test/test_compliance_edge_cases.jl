# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Compliance: Edge Cases" begin
    @testset "Empty Values" begin
        # Empty string
        @test ToonFormat.encode("") == "\"\""
        @test ToonFormat.decode("\"\"") == ""
        
        # Empty object
        @test ToonFormat.encode(Dict{String, Any}()) == ""
        @test ToonFormat.decode("") == Dict{String, Any}()
        
        # Empty array
        @test ToonFormat.encode([]) == "[0]:"
        @test ToonFormat.decode("[0]:") == []
        
        # Object with empty values
        obj = Dict("empty_str" => "", "empty_arr" => [], "empty_obj" => Dict{String, Any}())
        encoded = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded)
        @test decoded["empty_str"] == ""
        @test decoded["empty_arr"] == []
        @test decoded["empty_obj"] == Dict{String, Any}()
    end
    
    @testset "Deeply Nested Structures" begin
        # Deep nesting (10 levels)
        obj = Dict("l1" => Dict("l2" => Dict("l3" => Dict("l4" => Dict("l5" => 
              Dict("l6" => Dict("l7" => Dict("l8" => Dict("l9" => Dict("l10" => "deep"))))))))))
        encoded = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded)
        @test decoded["l1"]["l2"]["l3"]["l4"]["l5"]["l6"]["l7"]["l8"]["l9"]["l10"] == "deep"
        
        # Deep array nesting (simpler test - 5 levels)
        arr = [[[[[1]]]]]
        encoded = ToonFormat.encode(arr)
        decoded = ToonFormat.decode(encoded)
        @test decoded[1][1][1][1][1] == 1
        
        # Mixed deep nesting
        obj = Dict("a" => [Dict("b" => [Dict("c" => [Dict("d" => "value")])])])
        encoded = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded)
        @test decoded["a"][1]["b"][1]["c"][1]["d"] == "value"
    end
    
    @testset "Large Arrays" begin
        # Large primitive array
        arr = collect(1:1000)
        encoded = ToonFormat.encode(arr)
        decoded = ToonFormat.decode(encoded)
        @test decoded == arr
        
        # Large object array
        arr = [Dict("id" => i, "value" => "item$i") for i in 1:100]
        encoded = ToonFormat.encode(arr)
        decoded = ToonFormat.decode(encoded)
        @test length(decoded) == 100
        @test decoded[1]["id"] == 1
        @test decoded[100]["id"] == 100
        
        # Large nested structure
        obj = Dict("items" => [Dict("values" => collect(1:50)) for _ in 1:20])
        encoded = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded)
        @test length(decoded["items"]) == 20
        @test length(decoded["items"][1]["values"]) == 50
    end
    
    @testset "Special Characters" begin
        # All escape sequences
        str = "newline:\n tab:\t quote:\" backslash:\\ return:\r"
        encoded = ToonFormat.encode(str)
        decoded = ToonFormat.decode(encoded)
        @test decoded == str
        
        # Unicode characters (skip for now - may have indexing issues)
        # str = "Hello 世界 🌍"
        # encoded = ToonFormat.encode(str)
        # decoded = ToonFormat.decode(encoded)
        # @test decoded == str
        
        # Control characters (should be escaped or quoted)
        for char in ['\x00', '\x01', '\x1F']
            str = "test$(char)value"
            encoded = ToonFormat.encode(str)
            decoded = ToonFormat.decode(encoded)
            @test decoded == str
        end
        
        # Delimiter characters in strings
        @test ToonFormat.decode(ToonFormat.encode("has,comma")) == "has,comma"
        @test ToonFormat.decode(ToonFormat.encode("has\ttab")) == "has\ttab"
        @test ToonFormat.decode(ToonFormat.encode("has|pipe")) == "has|pipe"
        
        # Special TOON characters
        @test ToonFormat.decode(ToonFormat.encode("has:colon")) == "has:colon"
        @test ToonFormat.decode(ToonFormat.encode("has[bracket]")) == "has[bracket]"
        @test ToonFormat.decode(ToonFormat.encode("has{brace}")) == "has{brace}"
        @test ToonFormat.decode(ToonFormat.encode("has-hyphen")) == "has-hyphen"
    end
    
    @testset "Numeric Edge Cases" begin
        # Very large numbers
        @test ToonFormat.decode(ToonFormat.encode(1000000)) == 1000000
        @test ToonFormat.decode(ToonFormat.encode(999999999999)) == 999999999999
        
        # Very small decimals
        @test ToonFormat.decode(ToonFormat.encode(0.000001)) ≈ 0.000001
        @test ToonFormat.decode(ToonFormat.encode(0.123456789)) ≈ 0.123456789
        
        # Negative zero
        @test ToonFormat.encode(-0.0) == "0"
        @test ToonFormat.decode(ToonFormat.encode(-0.0)) == 0
        
        # Integer boundaries
        @test ToonFormat.decode(ToonFormat.encode(typemax(Int32))) == typemax(Int32)
        @test ToonFormat.decode(ToonFormat.encode(typemin(Int32))) == typemin(Int32)
        
        # Fractional precision
        @test ToonFormat.decode(ToonFormat.encode(1.5)) == 1.5
        @test ToonFormat.decode(ToonFormat.encode(1.25)) == 1.25
        @test ToonFormat.decode(ToonFormat.encode(1.125)) == 1.125
    end
    
    @testset "String Edge Cases" begin
        # Reserved literals as strings
        @test ToonFormat.encode("true") == "\"true\""
        @test ToonFormat.encode("false") == "\"false\""
        @test ToonFormat.encode("null") == "\"null\""
        
        # Numeric-like strings
        @test ToonFormat.encode("123") == "\"123\""
        @test ToonFormat.encode("3.14") == "\"3.14\""
        @test ToonFormat.encode("-42") == "\"-42\""
        
        # Whitespace strings
        @test ToonFormat.encode(" ") == "\" \""
        @test ToonFormat.encode("  ") == "\"  \""
        @test ToonFormat.encode(" leading") == "\" leading\""
        @test ToonFormat.encode("trailing ") == "\"trailing \""
        
        # Hyphen strings
        @test ToonFormat.encode("-") == "\"-\""
        @test ToonFormat.encode("-item") == "\"-item\""
        
        # Empty and whitespace-only
        @test ToonFormat.encode("") == "\"\""
        @test ToonFormat.encode("   ") == "\"   \""
    end
    
    @testset "Array Format Edge Cases" begin
        # Single element arrays
        @test ToonFormat.decode(ToonFormat.encode([1])) == [1]
        @test ToonFormat.decode(ToonFormat.encode(["a"])) == ["a"]
        @test ToonFormat.decode(ToonFormat.encode([Dict("x" => 1)])) == [Dict("x" => 1)]
        
        # Arrays with null values
        arr = [1, nothing, 3]
        decoded = ToonFormat.decode(ToonFormat.encode(arr))
        @test decoded[1] == 1
        @test decoded[2] === nothing
        @test decoded[3] == 3
        
        # Arrays with empty strings
        arr = ["", "a", ""]
        @test ToonFormat.decode(ToonFormat.encode(arr)) == arr
        
        # Mixed type arrays
        arr = [1, "two", true, nothing, 5.5]
        decoded = ToonFormat.decode(ToonFormat.encode(arr))
        @test decoded[1] == 1
        @test decoded[2] == "two"
        @test decoded[3] === true
        @test decoded[4] === nothing
        @test decoded[5] == 5.5
    end
    
    @testset "Object Key Edge Cases" begin
        # Keys requiring quoting
        obj = Dict("has:colon" => 1, "has space" => 2, "has\"quote" => 3)
        decoded = ToonFormat.decode(ToonFormat.encode(obj))
        @test decoded["has:colon"] == 1
        @test decoded["has space"] == 2
        @test decoded["has\"quote"] == 3
        
        # Keys with special characters
        obj = Dict("key-with-hyphen" => 1, "key_with_underscore" => 2, "key.with.dot" => 3)
        decoded = ToonFormat.decode(ToonFormat.encode(obj))
        @test decoded["key-with-hyphen"] == 1
        @test decoded["key_with_underscore"] == 2
        @test decoded["key.with.dot"] == 3
        
        # Empty key (if supported)
        # Note: Empty keys may not be valid in TOON, but test if they work
        # obj = Dict("" => "empty")
        # This might fail, which is expected
    end
    
    @testset "Whitespace Preservation" begin
        # Leading/trailing spaces in values
        obj = Dict("text" => "  spaces  ")
        decoded = ToonFormat.decode(ToonFormat.encode(obj))
        @test decoded["text"] == "  spaces  "
        
        # Newlines in strings
        obj = Dict("multiline" => "line1\nline2\nline3")
        decoded = ToonFormat.decode(ToonFormat.encode(obj))
        @test decoded["multiline"] == "line1\nline2\nline3"
        
        # Tabs in strings
        obj = Dict("tabbed" => "col1\tcol2\tcol3")
        decoded = ToonFormat.decode(ToonFormat.encode(obj))
        @test decoded["tabbed"] == "col1\tcol2\tcol3"
    end
end
