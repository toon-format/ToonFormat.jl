# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Object Encoding and Decoding (Requirements 5.1-5.5)" begin
    @testset "Requirement 5.1: Primitive fields with exactly one space after colon" begin
        # Simple primitive fields
        result = ToonFormat.encode(Dict("name" => "Alice", "age" => 30))
        @test occursin("name: Alice", result)
        @test occursin("age: 30", result)
        @test !occursin("name:  Alice", result)  # No double space
        @test !occursin("name:Alice", result)    # No missing space
        
        # Various primitive types
        obj = Dict(
            "str" => "hello",
            "num" => 42,
            "float" => 3.14,
            "bool" => true,
            "null" => nothing
        )
        result = ToonFormat.encode(obj)
        @test occursin("str: hello", result)
        @test occursin("num: 42", result)
        @test occursin("float: 3.14", result)
        @test occursin("bool: true", result)
        @test occursin("null: null", result)
        
        # Verify exactly one space (no extra spaces)
        lines = split(result, '\n')
        for line in lines
            if occursin(':', line)
                # Find the colon position
                colon_idx = findfirst(':', line)
                if colon_idx !== nothing && colon_idx < length(line)
                    # Check that there's exactly one space after colon
                    after_colon = line[colon_idx+1:end]
                    @test startswith(after_colon, ' ')
                    @test !startswith(after_colon, "  ")  # Not two spaces
                end
            end
        end
    end
    
    @testset "Requirement 5.2: Nested/empty objects use 'key:' on its own line" begin
        # Nested object
        obj = Dict("user" => Dict("name" => "Bob"))
        result = ToonFormat.encode(obj)
        lines = split(result, '\n')
        
        # Find the "user:" line
        user_line = findfirst(l -> occursin("user:", l), lines)
        @test user_line !== nothing
        @test strip(lines[user_line]) == "user:"
        
        # Empty object
        obj = Dict("empty" => Dict{String, Any}())
        result = ToonFormat.encode(obj)
        @test occursin("empty:", result)
        
        # Multiple nested levels
        obj = Dict("a" => Dict("b" => Dict("c" => 1)))
        result = ToonFormat.encode(obj)
        @test occursin("a:", result)
        @test occursin("b:", result)
        @test occursin("c: 1", result)
    end
    
    @testset "Requirement 5.3: Nested fields appear at depth +1" begin
        # Single level nesting
        obj = Dict("parent" => Dict("child" => "value"))
        result = ToonFormat.encode(obj)
        lines = split(result, '\n')
        
        # parent: should be at depth 0 (no indent)
        parent_line = findfirst(l -> occursin("parent:", l), lines)
        @test parent_line !== nothing
        @test !startswith(lines[parent_line], ' ')
        
        # child: value should be at depth 1 (2 spaces by default)
        child_line = findfirst(l -> occursin("child: value", l), lines)
        @test child_line !== nothing
        @test startswith(lines[child_line], "  ")
        @test !startswith(lines[child_line], "    ")  # Not 4 spaces
        
        # Multiple levels
        obj = Dict("a" => Dict("b" => Dict("c" => Dict("d" => 1))))
        result = ToonFormat.encode(obj)
        lines = split(result, '\n')
        
        # Check indentation increases by 2 spaces per level
        a_line = findfirst(l -> occursin("a:", l), lines)
        b_line = findfirst(l -> occursin("b:", l), lines)
        c_line = findfirst(l -> occursin("c:", l), lines)
        d_line = findfirst(l -> occursin("d: 1", l), lines)
        
        @test !startswith(lines[a_line], ' ')        # 0 spaces
        @test startswith(lines[b_line], "  ")        # 2 spaces
        @test startswith(lines[c_line], "    ")      # 4 spaces
        @test startswith(lines[d_line], "      ")    # 6 spaces
        
        # Custom indent
        result = ToonFormat.encode(obj, options=ToonFormat.EncodeOptions(indent=4))
        lines = split(result, '\n')
        
        a_line = findfirst(l -> occursin("a:", l), lines)
        b_line = findfirst(l -> occursin("b:", l), lines)
        c_line = findfirst(l -> occursin("c:", l), lines)
        d_line = findfirst(l -> occursin("d: 1", l), lines)
        
        @test !startswith(lines[a_line], ' ')        # 0 spaces
        @test startswith(lines[b_line], "    ")      # 4 spaces
        @test startswith(lines[c_line], "        ")  # 8 spaces
        @test startswith(lines[d_line], "            ")  # 12 spaces
    end
    
    @testset "Requirement 5.4: Decoder requires colon after each key" begin
        # Valid key-value pairs
        @test_nowarn ToonFormat.decode("name: Alice")
        @test_nowarn ToonFormat.decode("age: 30")
        @test_nowarn ToonFormat.decode("nested:\n  value: 1")
        
        # Missing colon in strict mode should error
        @test_throws Exception ToonFormat.decode("name Alice", options=ToonFormat.DecodeOptions(strict=true))
        @test_throws Exception ToonFormat.decode("age 30", options=ToonFormat.DecodeOptions(strict=true))
        
        # Missing colon in nested object
        @test_throws Exception ToonFormat.decode("parent:\n  child value", options=ToonFormat.DecodeOptions(strict=true))
        
        # Non-strict mode treats single line without colon as primitive
        result = ToonFormat.decode("name Alice", options=ToonFormat.DecodeOptions(strict=false))
        @test result == "name Alice"  # Single primitive value
        
        # Multiple keys, one missing colon
        input = "valid: 1\ninvalid no colon\nother: 2"
        @test_throws Exception ToonFormat.decode(input, options=ToonFormat.DecodeOptions(strict=true))
    end
    
    @testset "Requirement 5.5: Decoder opens nested object at depth +1 for 'key:' lines" begin
        # Simple nested object
        input = "user:\n  name: Alice\n  age: 30"
        result = ToonFormat.decode(input)
        @test haskey(result, "user")
        @test isa(result["user"], AbstractDict)
        @test result["user"]["name"] == "Alice"
        @test result["user"]["age"] == 30
        
        # Empty nested object (key: with nothing after)
        input = "empty:"
        result = ToonFormat.decode(input)
        @test haskey(result, "empty")
        @test isa(result["empty"], AbstractDict)
        @test isempty(result["empty"])
        
        # Multiple nested levels
        input = "a:\n  b:\n    c:\n      d: value"
        result = ToonFormat.decode(input)
        @test result["a"]["b"]["c"]["d"] == "value"
        
        # Mixed primitive and nested
        input = "name: Alice\naddress:\n  city: NYC\n  zip: 10001\nage: 30"
        result = ToonFormat.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30
        @test result["address"]["city"] == "NYC"
        @test result["address"]["zip"] == 10001
        
        # Nested object at correct depth
        input = "parent:\n  child1: value1\n  child2:\n    grandchild: value2"
        result = ToonFormat.decode(input)
        @test result["parent"]["child1"] == "value1"
        @test result["parent"]["child2"]["grandchild"] == "value2"
    end
    
    @testset "Empty object encoding and decoding" begin
        # Empty root object
        obj = Dict{String, Any}()
        result = ToonFormat.encode(obj)
        @test result == ""
        
        decoded = ToonFormat.decode(result)
        @test isa(decoded, AbstractDict)
        @test isempty(decoded)
        
        # Nested empty objects
        obj = Dict("a" => Dict{String, Any}(), "b" => Dict{String, Any}())
        result = ToonFormat.encode(obj)
        @test occursin("a:", result)
        @test occursin("b:", result)
        
        decoded = ToonFormat.decode(result)
        @test haskey(decoded, "a")
        @test haskey(decoded, "b")
        @test isempty(decoded["a"])
        @test isempty(decoded["b"])
    end
    
    @testset "Complex nested object round-trip" begin
        # Complex nested structure
        obj = Dict(
            "user" => Dict(
                "name" => "Alice",
                "age" => 30,
                "address" => Dict(
                    "street" => "123 Main St",
                    "city" => "NYC",
                    "zip" => 10001
                ),
                "active" => true
            ),
            "metadata" => Dict(
                "created" => "2025-01-01",
                "updated" => "2025-01-15"
            )
        )
        
        encoded = ToonFormat.encode(obj)
        decoded = ToonFormat.decode(encoded)
        
        # Verify structure
        @test decoded["user"]["name"] == "Alice"
        @test decoded["user"]["age"] == 30
        @test decoded["user"]["address"]["street"] == "123 Main St"
        @test decoded["user"]["address"]["city"] == "NYC"
        @test decoded["user"]["address"]["zip"] == 10001
        @test decoded["user"]["active"] == true
        @test decoded["metadata"]["created"] == "2025-01-01"
        @test decoded["metadata"]["updated"] == "2025-01-15"
    end
end
