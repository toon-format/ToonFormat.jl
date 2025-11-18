# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Compliance: TOON Spec Examples" begin
    @testset "Basic Examples from Spec" begin
        # Example: Simple object
        input = "name: Alice\nage: 30"
        result = TokenOrientedObjectNotation.decode(input)
        @test result["name"] == "Alice"
        @test result["age"] == 30
        
        # Example: Nested object
        input = "user:\n  name: Bob\n  age: 25"
        result = TokenOrientedObjectNotation.decode(input)
        @test result["user"]["name"] == "Bob"
        @test result["user"]["age"] == 25
        
        # Example: Inline array
        input = "[3]: 1,2,3"
        result = TokenOrientedObjectNotation.decode(input)
        @test result == [1, 2, 3]
        
        # Example: List array
        input = "[3]:\n  - apple\n  - banana\n  - cherry"
        result = TokenOrientedObjectNotation.decode(input)
        @test result == ["apple", "banana", "cherry"]
        
        # Example: Tabular array
        input = "[2]{name,age}:\n  Alice,30\n  Bob,25"
        result = TokenOrientedObjectNotation.decode(input)
        @test result[1]["name"] == "Alice"
        @test result[1]["age"] == 30
        @test result[2]["name"] == "Bob"
        @test result[2]["age"] == 25
    end
    
    @testset "Number Format Examples" begin
        # Canonical form: no exponent notation
        @test TokenOrientedObjectNotation.encode(1000000) == "1000000"
        @test TokenOrientedObjectNotation.encode(0.000001) == "0.000001"
        
        # No leading zeros
        @test TokenOrientedObjectNotation.encode(42) == "42"
        @test !startswith(TokenOrientedObjectNotation.encode(42), "0")
        
        # No trailing fractional zeros
        @test TokenOrientedObjectNotation.encode(1.5) == "1.5"
        @test TokenOrientedObjectNotation.encode(1.0) == "1"
        
        # Integer form when fractional part is zero
        @test TokenOrientedObjectNotation.encode(5.0) == "5"
        @test TokenOrientedObjectNotation.encode(100.0) == "100"
        
        # -0 normalized to 0
        @test TokenOrientedObjectNotation.encode(-0.0) == "0"
        
        # Decoder accepts exponent notation
        @test TokenOrientedObjectNotation.decode("value: 1e6")["value"] == 1000000
        @test TokenOrientedObjectNotation.decode("value: 1e-6")["value"] ≈ 0.000001
    end
    
    @testset "String Quoting Examples" begin
        # Empty string quoted
        @test TokenOrientedObjectNotation.encode("") == "\"\""
        
        # Leading/trailing whitespace quoted
        @test TokenOrientedObjectNotation.encode(" text") == "\" text\""
        @test TokenOrientedObjectNotation.encode("text ") == "\"text \""
        @test TokenOrientedObjectNotation.encode(" text ") == "\" text \""
        
        # Reserved literals quoted
        @test TokenOrientedObjectNotation.encode("true") == "\"true\""
        @test TokenOrientedObjectNotation.encode("false") == "\"false\""
        @test TokenOrientedObjectNotation.encode("null") == "\"null\""
        
        # Numeric-like strings quoted
        @test TokenOrientedObjectNotation.encode("123") == "\"123\""
        @test TokenOrientedObjectNotation.encode("3.14") == "\"3.14\""
        
        # Special characters quoted
        @test occursin("\"", TokenOrientedObjectNotation.encode("has:colon"))
        @test occursin("\"", TokenOrientedObjectNotation.encode("has\"quote"))
        
        # Hyphen quoted
        @test TokenOrientedObjectNotation.encode("-") == "\"-\""
        @test TokenOrientedObjectNotation.encode("-item") == "\"-item\""
    end
    
    @testset "Escape Sequence Examples" begin
        # Five valid escapes
        @test TokenOrientedObjectNotation.decode("\"back\\\\slash\"") == "back\\slash"
        @test TokenOrientedObjectNotation.decode("\"double\\\"quote\"") == "double\"quote"
        @test TokenOrientedObjectNotation.decode("\"new\\nline\"") == "new\nline"
        @test TokenOrientedObjectNotation.decode("\"carriage\\rreturn\"") == "carriage\rreturn"
        @test TokenOrientedObjectNotation.decode("\"tab\\there\"") == "tab\there"
        
        # Encoding uses escapes
        @test TokenOrientedObjectNotation.encode("line1\nline2") == "\"line1\\nline2\""
        @test TokenOrientedObjectNotation.encode("tab\there") == "\"tab\\there\""
        @test TokenOrientedObjectNotation.encode("quote\"here") == "\"quote\\\"here\""
        @test TokenOrientedObjectNotation.encode("back\\slash") == "\"back\\\\slash\""
    end
    
    @testset "Array Header Examples" begin
        # Basic header
        @test TokenOrientedObjectNotation.encode([1, 2, 3]) == "[3]: 1,2,3"
        
        # Tab delimiter
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=opts)
        @test occursin("[3\t]:", result)
        
        # Pipe delimiter
        opts = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        result = TokenOrientedObjectNotation.encode([1, 2, 3], options=opts)
        @test occursin("[3|]:", result)
        
        # Tabular with fields
        arr = [Dict("a" => 1, "b" => 2), Dict("a" => 3, "b" => 4)]
        result = TokenOrientedObjectNotation.encode(arr)
        @test occursin("{a,b}:", result) || occursin("{b,a}:", result)
    end
    
    @testset "Delimiter Scoping Examples" begin
        # Comma is default
        result = TokenOrientedObjectNotation.decode("[3]: 1,2,3")
        @test result == [1, 2, 3]
        
        # Tab delimiter
        result = TokenOrientedObjectNotation.decode("[3\t]: 1\t2\t3")
        @test result == [1, 2, 3]
        
        # Pipe delimiter
        result = TokenOrientedObjectNotation.decode("[3|]: 1|2|3")
        @test result == [1, 2, 3]
        
        # Nested arrays with different delimiters
        input = "data[2\t]:\n  - [2]: 1,2\n  - [2]: 3,4"
        result = TokenOrientedObjectNotation.decode(input)
        @test result["data"] == [[1, 2], [3, 4]]
    end
    
    @testset "Indentation Examples" begin
        # Default 2 spaces
        obj = Dict("parent" => Dict("child" => "value"))
        result = TokenOrientedObjectNotation.encode(obj)
        @test occursin("parent:\n  child: value", result)
        
        # Custom indent
        opts = TokenOrientedObjectNotation.EncodeOptions(indent=4)
        result = TokenOrientedObjectNotation.encode(obj, options=opts)
        @test occursin("parent:\n    child: value", result)
        
        # No trailing spaces
        lines = split(TokenOrientedObjectNotation.encode(obj), '\n')
        @test all(line == "" || !endswith(line, ' ') for line in lines)
        
        # No trailing newline
        @test !endswith(TokenOrientedObjectNotation.encode(obj), '\n')
    end
    
    @testset "Root Form Examples" begin
        # Root array
        input = "[3]: 1,2,3"
        result = TokenOrientedObjectNotation.decode(input)
        @test isa(result, Vector)
        @test result == [1, 2, 3]
        
        # Single primitive
        result = TokenOrientedObjectNotation.decode("hello")
        @test result == "hello"
        
        result = TokenOrientedObjectNotation.decode("42")
        @test result == 42
        
        # Object (default)
        input = "name: Alice\nage: 30"
        result = TokenOrientedObjectNotation.decode(input)
        @test isa(result, AbstractDict)
        @test result["name"] == "Alice"
        
        # Empty document
        result = TokenOrientedObjectNotation.decode("")
        @test result == Dict{String, Any}()
    end
    
    @testset "Objects as List Items Examples" begin
        # Empty object
        input = "[2]:\n  -\n  -"
        result = TokenOrientedObjectNotation.decode(input)
        @test result == [Dict{String, Any}(), Dict{String, Any}()]
        
        # Primitive first field
        input = "[2]:\n  - name: Alice\n    age: 30\n  - name: Bob\n    age: 25"
        result = TokenOrientedObjectNotation.decode(input)
        @test result[1]["name"] == "Alice"
        @test result[1]["age"] == 30
        @test result[2]["name"] == "Bob"
        @test result[2]["age"] == 25
        
        # Nested object first field
        input = "[1]:\n  - user:\n      name: Alice\n    active: true"
        result = TokenOrientedObjectNotation.decode(input)
        @test result[1]["user"]["name"] == "Alice"
        @test result[1]["active"] === true
    end
    
    @testset "Key Folding Examples" begin
        # Basic folding
        obj = Dict("a" => Dict("b" => Dict("c" => "value")))
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe")
        result = TokenOrientedObjectNotation.encode(obj, options=opts)
        @test occursin("a.b.c: value", result)
        
        # Flatten depth limit
        opts = TokenOrientedObjectNotation.EncodeOptions(keyFolding="safe", flattenDepth=2)
        result = TokenOrientedObjectNotation.encode(obj, options=opts)
        @test occursin("a.b:", result)
        @test occursin("c: value", result)
        
        # No folding by default
        result = TokenOrientedObjectNotation.encode(obj)
        @test occursin("a:", result)
        @test occursin("b:", result)
        @test occursin("c: value", result)
    end
    
    @testset "Path Expansion Examples" begin
        # Basic expansion
        input = "a.b.c: value"
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["a"]["b"]["c"] == "value"
        
        # No expansion by default
        result = TokenOrientedObjectNotation.decode(input)
        @test result["a.b.c"] == "value"
        
        # Deep merge
        input = "a.b.x: 1\na.b.y: 2"
        opts = TokenOrientedObjectNotation.DecodeOptions(expandPaths="safe")
        result = TokenOrientedObjectNotation.decode(input, options=opts)
        @test result["a"]["b"]["x"] == 1
        @test result["a"]["b"]["y"] == 2
    end
end
