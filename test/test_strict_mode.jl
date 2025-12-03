# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Strict Mode Error Handling" begin
    @testset "Array Count Mismatch Errors" begin
        # Inline array count mismatch - declared more than actual
        @test_throws Exception ToonFormat.decode("[5]: 1,2,3", options=ToonFormat.DecodeOptions(strict=true))
        
        # Inline array count mismatch - declared less than actual
        @test_throws Exception ToonFormat.decode("[2]: 1,2,3,4", options=ToonFormat.DecodeOptions(strict=true))
        
        # List array count mismatch - too few items
        input = """
        [3]:
        - 1
        - 2
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # List array count mismatch - too many items
        input = """
        [2]:
        - 1
        - 2
        - 3
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Tabular array count mismatch - too few rows
        input = """
        users[3]{name,age}:
          Alice,30
          Bob,25
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Tabular array count mismatch - too many rows
        input = """
        users[2]{name,age}:
          Alice,30
          Bob,25
          Charlie,35
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Inline tabular array count mismatch
        @test_throws Exception ToonFormat.decode("users[3]{name,age}: Alice,30,Bob,25", options=ToonFormat.DecodeOptions(strict=true))
        
        # Non-strict mode allows mismatches
        result = ToonFormat.decode("[5]: 1,2,3", options=ToonFormat.DecodeOptions(strict=false))
        @test length(result) == 3
        
        # Non-strict mode with too many items
        result = ToonFormat.decode("[2]: 1,2,3,4", options=ToonFormat.DecodeOptions(strict=false))
        @test length(result) == 4
    end
    
    @testset "Row Width Mismatch Errors" begin
        # Too few values in row
        input = """
        users[2]{name,age,city}:
          Alice,30
          Bob,25,NYC
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Too many values in row
        input = """
        users[2]{name,age}:
          Alice,30,extra
          Bob,25
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Non-strict mode allows width mismatches
        input = """
        users[2]{name,age}:
          Alice,30,extra
          Bob
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=false))
        @test length(result["users"]) == 2
    end
    
    @testset "Missing Colon Errors" begin
        # Missing colon after key
        @test_throws Exception ToonFormat.decode("name Alice", options=ToonFormat.DecodeOptions(strict=true))
        
        # Missing colon after array header
        @test_throws Exception ToonFormat.decode("[3] 1,2,3", options=ToonFormat.DecodeOptions(strict=true))
        
        # Missing colon in nested object
        input = """
        user
          name: Alice
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Invalid Escape Sequence Errors" begin
        # Invalid escape sequences
        @test_throws ArgumentError ToonFormat.decode("text: \"bad\\xescape\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"bad\\uescape\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"bad\\0escape\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"bad\\aescape\"")
        
        # Valid escape sequences should work
        result = ToonFormat.decode("text: \"good\\nescape\"")
        @test result["text"] == "good\nescape"
        
        result = ToonFormat.decode("text: \"good\\\\escape\"")
        @test result["text"] == "good\\escape"
        
        result = ToonFormat.decode("text: \"good\\\"escape\"")
        @test result["text"] == "good\"escape"
        
        result = ToonFormat.decode("text: \"good\\rescape\"")
        @test result["text"] == "good\rescape"
        
        result = ToonFormat.decode("text: \"good\\tescape\"")
        @test result["text"] == "good\tescape"
    end
    
    @testset "Unterminated String Errors" begin
        # Unterminated quoted string
        @test_throws Exception ToonFormat.decode("name: \"unterminated")
        
        # Unterminated quoted key
        @test_throws Exception ToonFormat.decode("\"unterminated: value")
        
        # Unterminated escape at end
        @test_throws ArgumentError ToonFormat.decode("text: \"ends with\\\"")
    end
    
    @testset "Indentation Errors" begin
        # Not a multiple of indentSize
        @test_throws Exception ToonFormat.decode("   value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=true))
        
        # Tabs in indentation
        @test_throws Exception ToonFormat.decode("\tvalue: 1", options=ToonFormat.DecodeOptions(strict=true))
        @test_throws Exception ToonFormat.decode("  \tvalue: 1", options=ToonFormat.DecodeOptions(strict=true))
        
        # Non-strict mode allows invalid indentation
        result = ToonFormat.decode("   value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=false))
        @test haskey(result, "value")
    end
    
    @testset "Blank Line Errors" begin
        # Blank line inside inline array (not applicable - inline is single line)
        
        # Blank line inside list array - after header
        input = """
        [3]:

        - 1
        - 2
        - 3
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank line inside list array - in middle
        input = """
        [3]:
        - 1

        - 2
        - 3
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank line inside list array - before last item
        input = """
        [3]:
        - 1
        - 2

        - 3
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank line inside tabular array - after header
        input = """
        users[3]{name,age}:

          Alice,30
          Bob,25
          Charlie,35
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank line inside tabular array - in middle
        input = """
        users[3]{name,age}:
          Alice,30

          Bob,25
          Charlie,35
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank line inside tabular array - before last row
        input = """
        users[3]{name,age}:
          Alice,30
          Bob,25

          Charlie,35
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Blank lines outside arrays are OK
        input = """
        name: Alice

        age: 30
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        @test result["name"] == "Alice"
        @test result["age"] == 30
        
        # Blank line before array is OK
        input = """
        name: Alice

        items[2]:
        - 1
        - 2
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        @test result["name"] == "Alice"
        @test length(result["items"]) == 2
        
        # Blank line after array is OK
        input = """
        items[2]:
        - 1
        - 2

        name: Alice
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        @test result["name"] == "Alice"
        @test length(result["items"]) == 2
    end
    
    @testset "Path Expansion Conflict Errors" begin
        # Conflict: segment already exists as non-object
        input = """
        a: 1
        a.b: 2
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(expandPaths="safe", strict=true))
        
        # Non-strict mode uses last-write-wins
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(expandPaths="safe", strict=false))
        @test haskey(result, "a")
        
        # No conflict when both are objects
        input = """
        a.b: 1
        a.c: 2
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(expandPaths="safe", strict=true))
        @test result["a"]["b"] == 1
        @test result["a"]["c"] == 2
        
        # Conflict with nested object
        input = """
        a.b.c: 1
        a.b: 2
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(expandPaths="safe", strict=true))
    end
    
    @testset "Error Messages Include Line Numbers" begin
        # Missing colon error should include line number
        input = """
        name: Alice
        age 30
        city: NYC
        """
        try
            ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
            @test false  # Should have thrown
        catch e
            msg = string(e)
            @test occursin("line", lowercase(msg)) || occursin("2", msg)
        end
        
        # Indentation error should include line number
        input = """
        name: Alice
           age: 30
        """
        try
            ToonFormat.decode(input, options=ToonFormat.DecodeOptions(indent=2, strict=true))
            @test false  # Should have thrown
        catch e
            msg = string(e)
            @test occursin("line", lowercase(msg)) || occursin("2", msg)
        end
        
        # Tab error should include line number
        input = """
        name: Alice
        \tage: 30
        """
        try
            ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
            @test false  # Should have thrown
        catch e
            msg = string(e)
            @test occursin("line", lowercase(msg)) || occursin("2", msg)
        end
    end
    
    @testset "Multiple Primitives at Root" begin
        # Multiple primitives at root should error in strict mode
        input = """
        42
        hello
        """
        # This should be treated as an object with keys, not multiple primitives
        # Actually, this is invalid TOON - only one primitive allowed at root
        # The decoder will try to parse as object and fail on missing colons
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Nested Array Count Mismatches" begin
        # Nested array with count mismatch
        input = """
        data[2]:
        - [3]: 1,2
        - [2]: 3,4
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Nested tabular array with count mismatch
        input = """
        groups[2]:
        - name: A
          users[3]{id}:
            1
            2
        - name: B
          users[2]{id}:
            3
            4
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Empty Array Validation" begin
        # Empty array with correct count
        result = ToonFormat.decode("[0]:", options=ToonFormat.DecodeOptions(strict=true))
        @test length(result) == 0
        
        # Empty array with incorrect count
        @test_throws Exception ToonFormat.decode("[1]:", options=ToonFormat.DecodeOptions(strict=true))
        
        # Empty tabular array
        result = ToonFormat.decode("users[0]{name,age}:", options=ToonFormat.DecodeOptions(strict=true))
        @test length(result["users"]) == 0
    end
    
    @testset "Delimiter-Specific Errors" begin
        # Tab delimiter with count mismatch
        input = "[\t5\t]: 1\t2\t3"
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Pipe delimiter with count mismatch
        input = "[5|]: 1|2|3"
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Tabular with tab delimiter and row width mismatch
        input = "users[2\t]{name\tage}:\n  Alice\t30\textra\n  Bob\t25"
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Tabular with pipe delimiter and row width mismatch
        input = "users[2|]{name|age}:\n  Alice|30|extra\n  Bob|25"
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Complex Indentation Errors" begin
        # Indentation not multiple of 2 (default)
        @test_throws Exception ToonFormat.decode(" value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=true))
        @test_throws Exception ToonFormat.decode("   value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=true))
        @test_throws Exception ToonFormat.decode("     value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=true))
        
        # Indentation not multiple of 4
        @test_throws Exception ToonFormat.decode("  value: 1", options=ToonFormat.DecodeOptions(indent=4, strict=true))
        @test_throws Exception ToonFormat.decode("   value: 1", options=ToonFormat.DecodeOptions(indent=4, strict=true))
        
        # Tab at different positions
        @test_throws Exception ToonFormat.decode("\tvalue: 1", options=ToonFormat.DecodeOptions(strict=true))
        @test_throws Exception ToonFormat.decode(" \tvalue: 1", options=ToonFormat.DecodeOptions(strict=true))
        @test_throws Exception ToonFormat.decode("  \tvalue: 1", options=ToonFormat.DecodeOptions(strict=true))
        
        # Mixed spaces and tabs
        @test_throws Exception ToonFormat.decode(" \t value: 1", options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Escape Sequence Edge Cases" begin
        # All valid escape sequences
        result = ToonFormat.decode("text: \"\\\\\\\"\\n\\r\\t\"")
        @test result["text"] == "\\\"\n\r\t"
        
        # Invalid escape at different positions
        @test_throws ArgumentError ToonFormat.decode("text: \"\\x\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"start\\xend\"")
        @test_throws ArgumentError ToonFormat.decode("text: \"\\xend\"")
        
        # Various invalid escapes
        @test_throws ArgumentError ToonFormat.decode("text: \"\\u0041\"")  # Unicode escape
        @test_throws ArgumentError ToonFormat.decode("text: \"\\b\"")      # Backspace
        @test_throws ArgumentError ToonFormat.decode("text: \"\\f\"")      # Form feed
        @test_throws ArgumentError ToonFormat.decode("text: \"\\v\"")      # Vertical tab
        @test_throws ArgumentError ToonFormat.decode("text: \"\\0\"")      # Null
        @test_throws ArgumentError ToonFormat.decode("text: \"\\a\"")      # Alert
        
        # Escape at end of string
        @test_throws ArgumentError ToonFormat.decode("text: \"ends\\\"")
        
        # Multiple invalid escapes
        @test_throws ArgumentError ToonFormat.decode("text: \"\\x\\y\\z\"")
    end
    
    @testset "Missing Colon Edge Cases" begin
        # Missing colon in nested structure
        input = """
        user:
          name Alice
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
        
        # Missing colon in array item
        input = """
        items[2]:
        - key value
        - another: value
        """
        # This should parse "key value" as a primitive string
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=false))
        @test result["items"][1] == "key value"
        
        # Missing colon after nested key
        input = """
        outer:
          inner
            value: 1
        """
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Strict Mode Can Be Disabled" begin
        # All the above errors should be lenient when strict=false
        
        # Count mismatch
        result = ToonFormat.decode("[5]: 1,2,3", options=ToonFormat.DecodeOptions(strict=false))
        @test length(result) == 3
        
        # Invalid indentation
        result = ToonFormat.decode("   value: 1", options=ToonFormat.DecodeOptions(indent=2, strict=false))
        @test haskey(result, "value")
        
        # Path expansion conflict
        input = """
        a: 1
        a.b: 2
        """
        result = ToonFormat.decode(input, options=ToonFormat.DecodeOptions(expandPaths="safe", strict=false))
        @test haskey(result, "a")
    end
end
