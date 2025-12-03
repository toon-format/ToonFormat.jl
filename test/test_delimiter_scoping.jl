# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Delimiter Scoping Tests (Task 5)" begin
    @testset "Document Delimiter Affects Object Value Quoting (Requirement 8.3)" begin
        # When document delimiter is comma, strings containing comma must be quoted
        data = Dict("name" => "Smith, John")
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        @test occursin("\"Smith, John\"", result)
        
        # When document delimiter is tab, strings containing tab must be quoted
        data = Dict("name" => "Smith\tJohn")
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        @test occursin("\"Smith\\tJohn\"", result)
        
        # When document delimiter is pipe, strings containing pipe must be quoted
        data = Dict("name" => "Smith|John")
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE))
        @test occursin("\"Smith|John\"", result)
        
        # String with comma doesn't need quoting when document delimiter is tab
        data = Dict("name" => "Smith, John")
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        @test occursin("name: Smith, John", result)
        @test !occursin("\"Smith, John\"", result)
        
        # String with pipe doesn't need quoting when document delimiter is comma
        data = Dict("name" => "Smith|John")
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        @test occursin("name: Smith|John", result)
        @test !occursin("\"Smith|John\"", result)
    end
    
    @testset "Active Delimiter Affects Only Array Scope (Requirements 8.1, 8.2)" begin
        # Array with tab delimiter uses tab for splitting
        result = ToonFormat.decode("[3\t]: 1\t2\t3")
        @test result == [1, 2, 3]
        
        # Array with pipe delimiter uses pipe for splitting
        result = ToonFormat.decode("[3|]: 1|2|3")
        @test result == [1, 2, 3]
        
        # Tabular array with tab delimiter uses tab for rows
        input = "users[2\t]{name\tage}:\n  Alice\t30\n  Bob\t25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
        
        # Tabular array with pipe delimiter uses pipe for rows
        input = "users[2|]{name|age}:\n  Alice|30\n  Bob|25"
        result = ToonFormat.decode(input)
        @test result["users"][1]["name"] == "Alice"
        @test result["users"][1]["age"] == 30
    end
    
    @testset "Nested Arrays Can Change Active Delimiter (Requirement 8.3)" begin
        # Parent array with comma, nested array with tab
        input = "data[2]:\n  - [2\t]: 1\t2\n  - [2\t]: 3\t4"
        result = ToonFormat.decode(input)
        @test result["data"][1] == [1, 2]
        @test result["data"][2] == [3, 4]
        
        # Parent array with tab, nested array with pipe
        input = "data[2\t]:\n  - [2|]: 1|2\n  - [2|]: 3|4"
        result = ToonFormat.decode(input)
        @test result["data"][1] == [1, 2]
        @test result["data"][2] == [3, 4]
        
        # Parent array with pipe, nested array with comma
        input = "data[2|]:\n  - [2]: 1,2\n  - [2]: 3,4"
        result = ToonFormat.decode(input)
        @test result["data"][1] == [1, 2]
        @test result["data"][2] == [3, 4]
        
        # Encoding: nested arrays with different delimiters
        data = Dict("outer" => [[1, 2], [3, 4]])
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        # Outer array uses tab delimiter
        @test occursin("outer[2\t]:", result)
        # Inner arrays also use tab delimiter (inherited from options)
        @test occursin("[2\t]:", result)
    end
    
    @testset "Object Values Inside Arrays Use Document Delimiter (Requirement 8.4)" begin
        # Array of objects with comma document delimiter
        # Object values containing comma should be quoted
        data = Dict("items" => [
            Dict("name" => "Smith, John"),
            Dict("name" => "Doe, Jane")
        ])
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        # The array uses comma delimiter, but object values should still check document delimiter
        @test occursin("\"Smith, John\"", result)
        @test occursin("\"Doe, Jane\"", result)
        
        # Array of objects with tab document delimiter
        # Object values containing tab should be quoted, but comma is OK
        data = Dict("items" => [
            Dict("name" => "Smith\tJohn"),
            Dict("desc" => "Item, description")
        ])
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        @test occursin("\"Smith\\tJohn\"", result)
        # Comma in object value doesn't need quoting when document delimiter is tab
        @test occursin("Item, description", result)
        @test !occursin("\"Item, description\"", result)
        
        # Array of objects with pipe document delimiter
        # Object values containing pipe should be quoted
        data = Dict("items" => [
            Dict("name" => "Smith|John"),
            Dict("name" => "Doe|Jane")
        ])
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE))
        @test occursin("\"Smith|John\"", result)
        @test occursin("\"Doe|Jane\"", result)
    end
    
    @testset "Delimiter Absence Always Means Comma (Requirements 4.6, 8.6)" begin
        # Array without delimiter symbol uses comma
        result = ToonFormat.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]
        
        # Nested array without delimiter symbol uses comma (not parent delimiter)
        # Parent uses tab, child has no delimiter symbol = child uses comma
        input = "data[2\t]:\n  - [2]: 1,2\n  - [2]: 3,4"
        result = ToonFormat.decode(input)
        @test result["data"][1] == [1, 2]
        @test result["data"][2] == [3, 4]
        
        # Parent uses pipe, child has no delimiter symbol = child uses comma
        input = "data[2|]:\n  - [2]: 1,2\n  - [2]: 3,4"
        result = ToonFormat.decode(input)
        @test result["data"][1] == [1, 2]
        @test result["data"][2] == [3, 4]
        
        # Multiple levels: grandparent pipe, parent comma (absent), child tab
        input = "root[1|]:\n  - [2]:\n    - [2\t]: 1\t2\n    - [2\t]: 3\t4"
        result = ToonFormat.decode(input)
        @test result["root"][1][1] == [1, 2]
        @test result["root"][1][2] == [3, 4]
    end
    
    @testset "Complex Delimiter Scoping Scenarios" begin
        # Document with multiple arrays using different delimiters
        input = """
        arr1[3]: 1,2,3
        arr2[3\t]: 4\t5\t6
        arr3[3|]: 7|8|9
        """
        result = ToonFormat.decode(input)
        @test result["arr1"] == [1, 2, 3]
        @test result["arr2"] == [4, 5, 6]
        @test result["arr3"] == [7, 8, 9]
        
        # Nested objects with arrays at different levels
        input = """
        parent:
          child1[2]: a,b
          child2[2\t]: c\td
          child3[2|]: e|f
        """
        result = ToonFormat.decode(input)
        @test result["parent"]["child1"] == ["a", "b"]
        @test result["parent"]["child2"] == ["c", "d"]
        @test result["parent"]["child3"] == ["e", "f"]
        
        # Array of arrays with mixed delimiters
        input = """
        matrix[3]:
          - [2]: 1,2
          - [2\t]: 3\t4
          - [2|]: 5|6
        """
        result = ToonFormat.decode(input)
        @test result["matrix"][1] == [1, 2]
        @test result["matrix"][2] == [3, 4]
        @test result["matrix"][3] == [5, 6]
        
        # Tabular array with values containing different delimiters
        input = "items[2]{name,desc}:\n  \"a,b\",\"c|d\"\n  \"e\tf\",\"g-h\""
        result = ToonFormat.decode(input)
        @test result["items"][1]["name"] == "a,b"
        @test result["items"][1]["desc"] == "c|d"
        @test result["items"][2]["name"] == "e\tf"
        @test result["items"][2]["desc"] == "g-h"
    end
    
    @testset "Delimiter Scoping Round-trip" begin
        # Test that delimiter scoping is preserved through encode/decode
        
        # Simple array with tab delimiter
        original = [1, 2, 3]
        encoded = ToonFormat.encode(original, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        decoded = ToonFormat.decode(encoded)
        @test decoded == original
        
        # Object with array using pipe delimiter
        original = Dict("data" => [10, 20, 30])
        encoded = ToonFormat.encode(original, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE))
        decoded = ToonFormat.decode(encoded)
        @test decoded["data"] == [10, 20, 30]
        
        # Nested arrays (all use same delimiter from options)
        original = Dict("matrix" => [[1, 2], [3, 4]])
        encoded = ToonFormat.encode(original, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        decoded = ToonFormat.decode(encoded)
        @test decoded["matrix"][1] == [1, 2]
        @test decoded["matrix"][2] == [3, 4]
        
        # Tabular array with different delimiters
        original = Dict("users" => [
            Dict("name" => "Alice", "age" => 30),
            Dict("name" => "Bob", "age" => 25)
        ])
        for delim in [ToonFormat.COMMA, ToonFormat.TAB, ToonFormat.PIPE]
            encoded = ToonFormat.encode(original, options=ToonFormat.EncodeOptions(delimiter=delim))
            decoded = ToonFormat.decode(encoded)
            @test decoded["users"][1]["name"] == "Alice"
            @test decoded["users"][1]["age"] == 30
        end
    end
    
    @testset "Delimiter Quoting Edge Cases" begin
        # String containing all three delimiters
        data = Dict("text" => "a,b\tc|d")
        
        # With comma delimiter, comma must be quoted
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        @test occursin("\"a,b\\tc|d\"", result)
        
        # With tab delimiter, tab must be quoted
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB))
        @test occursin("\"a,b\\tc|d\"", result)
        
        # With pipe delimiter, pipe must be quoted
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE))
        @test occursin("\"a,b\\tc|d\"", result)
        
        # Array values containing document delimiter
        data = ["a,b", "c,d"]
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        @test occursin("\"a,b\"", result)
        @test occursin("\"c,d\"", result)
        
        # Array values not containing document delimiter
        data = ["a|b", "c|d"]
        result = ToonFormat.encode(data, options=ToonFormat.EncodeOptions(delimiter=ToonFormat.COMMA))
        @test occursin("a|b", result)
        @test occursin("c|d", result)
        @test !occursin("\"a|b\"", result)
        @test !occursin("\"c|d\"", result)
    end
end
