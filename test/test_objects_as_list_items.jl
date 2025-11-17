# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Objects as List Items (Requirements 12.1-12.5)" begin
    # Note: Uniform objects with primitive values use tabular format (Requirement 6.2)
    # Objects as list items only appear in mixed or non-uniform arrays
    
    @testset "Requirement 12.1: Empty object emits single '-'" begin
        # Mixed array with empty objects
        arr = [1, Dict{String, Any}(), 2, Dict{String, Any}()]
        result = TOON.encode(arr)
        
        lines = split(result, '\n')
        @test lines[1] == "[4]:"
        @test any(l -> strip(l) == "-", lines)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test length(decoded) == 4
        @test decoded[1] == 1
        @test isa(decoded[2], AbstractDict)
        @test isempty(decoded[2])
        @test decoded[3] == 2
        @test isa(decoded[4], AbstractDict)
        @test isempty(decoded[4])
    end
    
    @testset "Requirement 12.2: Primitive first field uses '- key: value'" begin
        # Mixed array with object - first field is primitive
        arr = [42, Dict("name" => "Alice")]
        result = TOON.encode(arr)
        
        @test occursin("- 42", result)
        @test occursin("- name: Alice", result)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test length(decoded) == 2
        @test decoded[1] == 42
        @test decoded[2]["name"] == "Alice"
        
        # Multiple fields - first is primitive
        arr = [1, Dict("id" => 1, "name" => "Alice", "age" => 30)]
        result = TOON.encode(arr)
        
        lines = split(result, '\n')
        # First field on hyphen line
        @test any(l -> occursin("- id: 1", l) || occursin("- name: Alice", l) || occursin("- age: 30", l), lines)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test decoded[1] == 1
        @test decoded[2]["id"] == 1
        @test decoded[2]["name"] == "Alice"
        @test decoded[2]["age"] == 30
    end
    
    @testset "Requirement 12.3: Nested object first field uses '- key:' with fields at depth +2" begin
        # Mixed array with object that has nested object as first field
        arr = [1, Dict("user" => Dict("name" => "Alice", "age" => 30))]
        result = TOON.encode(arr)
        
        lines = split(result, '\n')
        @test lines[1] == "[2]:"
        @test any(l -> occursin("- 1", l), lines)
        @test any(l -> occursin("- user:", l), lines)
        # Nested fields at depth +2 (4 spaces)
        @test any(l -> startswith(l, "    ") && occursin("name: Alice", l), lines)
        @test any(l -> startswith(l, "    ") && occursin("age: 30", l), lines)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test decoded[1] == 1
        @test decoded[2]["user"]["name"] == "Alice"
        @test decoded[2]["user"]["age"] == 30
    end
    
    @testset "Requirement 12.4: Remaining fields appear at depth +1" begin
        # Object with multiple fields in mixed array
        arr = [1, Dict("a" => 1, "b" => 2, "c" => 3)]
        result = TOON.encode(arr)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test decoded[1] == 1
        @test decoded[2]["a"] == 1
        @test decoded[2]["b"] == 2
        @test decoded[2]["c"] == 3
        
        # Object with nested objects in remaining fields
        arr = [true, Dict("id" => 1, "user" => Dict("name" => "Alice"), "meta" => Dict("created" => "2025-01-01"))]
        result = TOON.encode(arr)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test decoded[1] == true
        @test decoded[2]["id"] == 1
        @test decoded[2]["user"]["name"] == "Alice"
        @test decoded[2]["meta"]["created"] == "2025-01-01"
    end
    
    @testset "Requirement 12.5: Array first field is supported" begin
        # Object with array as first field in mixed array
        arr = [1, Dict("items" => [1, 2, 3], "count" => 3)]
        result = TOON.encode(arr)
        
        lines = split(result, '\n')
        # Array on first field - hyphen alone, then array at depth +1
        @test any(l -> strip(l) == "-", lines)
        @test any(l -> occursin("items[3]: 1,2,3", l), lines)
        # Remaining fields at depth +1
        @test any(l -> occursin("count: 3", l), lines)
        
        # Decode and verify
        decoded = TOON.decode(result)
        @test decoded[1] == 1
        @test decoded[2]["items"] == [1, 2, 3]
        @test decoded[2]["count"] == 3
    end
    
    @testset "Complex objects as list items" begin
        # Deeply nested structure in mixed array
        arr = [
            "header",
            Dict(
                "id" => 1,
                "user" => Dict(
                    "name" => "Alice",
                    "address" => Dict(
                        "city" => "NYC",
                        "zip" => 10001
                    )
                ),
                "tags" => ["admin", "active"]
            ),
            Dict(
                "id" => 2,
                "user" => Dict(
                    "name" => "Bob",
                    "address" => Dict(
                        "city" => "LA",
                        "zip" => 90001
                    )
                ),
                "tags" => ["user"]
            )
        ]
        
        encoded = TOON.encode(arr)
        decoded = TOON.decode(encoded)
        
        # Verify structure
        @test length(decoded) == 3
        @test decoded[1] == "header"
        @test decoded[2]["id"] == 1
        @test decoded[2]["user"]["name"] == "Alice"
        @test decoded[2]["user"]["address"]["city"] == "NYC"
        @test decoded[2]["user"]["address"]["zip"] == 10001
        @test decoded[2]["tags"] == ["admin", "active"]
        @test decoded[3]["id"] == 2
        @test decoded[3]["user"]["name"] == "Bob"
        @test decoded[3]["user"]["address"]["city"] == "LA"
        @test decoded[3]["user"]["address"]["zip"] == 90001
        @test decoded[3]["tags"] == ["user"]
    end
    
    @testset "Mixed array with objects as list items" begin
        # Mixed array with primitives, arrays, and objects
        arr = [
            42,
            "hello",
            [1, 2, 3],
            Dict("name" => "Alice", "age" => 30),
            Dict{String, Any}(),
            true
        ]
        
        encoded = TOON.encode(arr)
        decoded = TOON.decode(encoded)
        
        @test length(decoded) == 6
        @test decoded[1] == 42
        @test decoded[2] == "hello"
        @test decoded[3] == [1, 2, 3]
        @test decoded[4]["name"] == "Alice"
        @test decoded[4]["age"] == 30
        @test isempty(decoded[5])
        @test decoded[6] == true
    end
    
    @testset "Round-trip with various object configurations" begin
        # Mixed arrays with objects
        arr = [1, Dict("x" => 1), 2, Dict("y" => 2), 3, Dict("z" => 3)]
        @test TOON.decode(TOON.encode(arr)) == arr
        
        # Objects with nested objects
        arr = [
            "a",
            Dict("outer" => Dict("inner" => 1)),
            "b",
            Dict("outer" => Dict("inner" => 2))
        ]
        @test TOON.decode(TOON.encode(arr)) == arr
        
        # Objects with arrays
        arr = [
            0,
            Dict("items" => [1, 2], "count" => 2),
            Dict("items" => [3, 4, 5], "count" => 3)
        ]
        @test TOON.decode(TOON.encode(arr)) == arr
        
        # Empty objects in mixed array
        arr = [1, Dict{String, Any}(), 2, Dict{String, Any}(), 3, Dict{String, Any}()]
        @test TOON.decode(TOON.encode(arr)) == arr
    end
end
