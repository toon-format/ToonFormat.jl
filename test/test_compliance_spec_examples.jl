# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "Compliance: TOON Spec Examples" begin
    @testset "Basic Examples from Spec" begin
        # Example: Simple object
        input = "name: Alice\nage: 30"
        result = TOON.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30
        
        # Example: Nested object
        input = "user:\n  name: Bob\n  age: 25"
        result = TOON.decode(input)
        @test result["user"]["name"] == "Bob"
        @test result["user"]["age"] == 25
        
        # Example: Inline array
        input = "[3]: 1,2,3"
        result = TOON.decode(input)
        @test result == [1, 2, 3]
        
        # Example: List array
        input = "[3]:\n  - apple\n  - banana\n  - cherry"
        result = TOON.decode(input)
        @test result == ["apple", "banana", "cherry"]
        
        # Example: Tabular array
        input = "[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = TOON.decode(input)
        @test result[1]["name"] == "Alice"
        @test result[1]["age"] == 30
        @test result[2]["name"] == "Bob"
        @test result[2]["age"] == 25
    end
    
    @testset "Number Format Examples" begin
        # Canonical form: no exponent notation
        @test TOON.encode(1000000) == "1000000"
        @test TOON.encode(0.000001) == "0.000001"
        
        # No leading zeros
        @test TOON.encode(42) == "42"
        @test !startswith(TOON.encode(42), "0")
        
        # No trailing fractional zeros
        @test TOON.encode(1.5) == "1.5"
        @test TOON.encode(1.0) == "1"
        
        # Integer form when fractional part is zero
        @test TOON.encode(5.0) == "5"
        @test TOON.encode(100.0) == "100"
        
        # -0 normalized to 0
        @test TOON.encode(-0.0) == "0"
        
        # Decoder accepts exponent notation
        @test TOON.decode("value: 1e6")["value"] == 1000000
        @test TOON.decode("value: 1e-6")["value"] ≈ 0.000001
    end
    
    @testset "String Quoting Examples" begin
        # Empty string quoted
        @test TOON.encode("") == "\"\""
        
        # Leading/trailing whitespace quoted
        @test TOON.encode(" text") == "\" text\""
        @test TOON.encode("text ") == "\"text \""
        @test TOON.encode(" text ") == "\" text \""
        
        # Reserved literals quoted
        @test TOON.encode("true") == "\"true\""
        @test TOON.encode("false") == "\"false\""
        @test TOON.encode("null") == "\"null\""
        
        # Numeric-like strings quoted
        @test TOON.encode("123") == "\"123\""
        @test TOON.encode("3.14") == "\"3.14\""
        
        # Special characters quoted
        @test occursin("\"", TOON.encode("has:colon"))
        @test occursin("\"", TOON.encode("has\"quote"))
        
        # Hyphen quoted
        @test TOON.encode("-") == "\"-\""
        @test TOON.encode("-item") == "\"-item\""
    end
    
    @testset "Escape Sequence Examples" begin
        # Five valid escapes
        @test TOON.decode("\"back\\\\slash\"") == "back\\slash"
        @test TOON.decode("\"double\\\"quote\"") == "double\"quote"
        @test TOON.decode("\"new\\nline\"") == "new\nline"
        @test TOON.decode("\"carriage\\rreturn\"") == "carriage\rreturn"
        @test TOON.decode("\"tab\\there\"") == "tab\there"
        
        # Encoding uses escapes
        @test TOON.encode("line1\nline2") == "\"line1\\nline2\""
        @test TOON.encode("tab\there") == "\"tab\\there\""
        @test TOON.encode("quote\"here") == "\"quote\\\"here\""
        @test TOON.encode("back\\slash") == "\"back\\\\slash\""
    end
    
    @testset "Array Header Examples" begin
        # Basic header
        @test TOON.encode([1, 2, 3]) == "[3]: 1,2,3"
        
        # Tab delimiter
        opts = TOON.EncodeOptions(delimiter=TOON.TAB)
        result = TOON.encode([1, 2, 3], options=opts)
        @test occursin("[3\t]:", result)
        
        # Pipe delimiter
        opts = TOON.EncodeOptions(delimiter=TOON.PIPE)
        result = TOON.encode([1, 2, 3], options=opts)
        @test occursin("[3|]:", result)
        
        # Tabular with fields
        arr = [Dict("a" => 1, "b" => 2), Dict("a" => 3, "b" => 4)]
        result = TOON.encode(arr)
        @test occursin("{a,b}:", result) || occursin("{b,a}:", result)
    end
    
    @testset "Delimiter Scoping Examples" begin
        # Comma is default
        result = TOON.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]
        
        # Tab delimiter
        result = TOON.decode("[3\t]: 1\t2\t3")
        @test result == [1, 2, 3]
        
        # Pipe delimiter
        result = TOON.decode("[3|]: 1|2|3")
        @test result == [1, 2, 3]
        
        # Nested arrays with different delimiters
        input = "data[2\t]:\n  - [2]: 1,2\n  - [2]: 3,4"
        result = TOON.decode(input)
        @test result["data"] == [[1, 2], [3, 4]]
    end
    
    @testset "Indentation Examples" begin
        # Default 2 spaces
        obj = Dict("parent" => Dict("child" => "value"))
        result = TOON.encode(obj)
        @test occursin("parent:\n  child: value", result)
        
        # Custom indent
        opts = TOON.EncodeOptions(indent=4)
        result = TOON.encode(obj, options=opts)
        @test occursin("parent:\n    child: value", result)
        
        # No trailing spaces
        lines = split(TOON.encode(obj), '\n')
        @test all(line == "" || !endswith(line, ' ') for line in lines)
        
        # No trailing newline
        @test !endswith(TOON.encode(obj), '\n')
    end
    
    @testset "Root Form Examples" begin
        # Root array
        input = "[3]: 1,2,3"
        result = TOON.decode(input)
        @test isa(result, Vector)
        @test result == [1, 2, 3]
        
        # Single primitive
        result = TOON.decode("hello")
        @test result == "hello"
        
        result = TOON.decode("42")
        @test result == 42
        
        # Object (default)
        input = "name: Alice\nage: 30"
        result = TOON.decode(input)
        @test isa(result, AbstractDict)
        @test result["name"] == "Alice"
        
        # Empty document
        result = TOON.decode("")
        @test result == Dict{String, Any}()
    end
    
    @testset "Objects as List Items Examples" begin
        # Empty object
        input = "[2]:\n  -\n  -"
        result = TOON.decode(input)
        @test result == [Dict{String, Any}(), Dict{String, Any}()]
        
        # Primitive first field
        input = "[2]:\n  - name: Alice\n    age: 30\n  - name: Bob\n    age: 25"
        result = TOON.decode(input)
        @test result[1]["name"] == "Alice"
        @test result[1]["age"] == 30
        @test result[2]["name"] == "Bob"
        @test result[2]["age"] == 25
        
        # Nested object first field
        input = "[1]:\n  - user:\n      name: Alice\n    active: true"
        result = TOON.decode(input)
        @test result[1]["user"]["name"] == "Alice"
        @test result[1]["active"] === true
    end
    
    @testset "Key Folding Examples" begin
        # Basic folding
        obj = Dict("a" => Dict("b" => Dict("c" => "value")))
        opts = TOON.EncodeOptions(keyFolding="safe")
        result = TOON.encode(obj, options=opts)
        @test occursin("a.b.c: value", result)
        
        # Flatten depth limit
        opts = TOON.EncodeOptions(keyFolding="safe", flattenDepth=2)
        result = TOON.encode(obj, options=opts)
        @test occursin("a.b:", result)
        @test occursin("c: value", result)
        
        # No folding by default
        result = TOON.encode(obj)
        @test occursin("a:", result)
        @test occursin("b:", result)
        @test occursin("c: value", result)
    end
    
    @testset "Path Expansion Examples" begin
        # Basic expansion
        input = "a.b.c: value"
        opts = TOON.DecodeOptions(expandPaths="safe")
        result = TOON.decode(input, options=opts)
        @test result["a"]["b"]["c"] == "value"
        
        # No expansion by default
        result = TOON.decode(input)
        @test result["a.b.c"] == "value"
        
        # Deep merge
        input = "a.b.x: 1\na.b.y: 2"
        opts = TOON.DecodeOptions(expandPaths="safe")
        result = TOON.decode(input, options=opts)
        @test result["a"]["b"]["x"] == 1
        @test result["a"]["b"]["y"] == 2
    end
end
