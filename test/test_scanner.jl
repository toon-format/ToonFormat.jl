# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "Scanner Tests" begin
    @testset "ToParsedLines" begin
        # Empty source
        result = TokenOrientedObjectNotation.to_parsed_lines("", 2, true)
        @test isempty(result.lines)
        @test isempty(result.blankLines)

        # Whitespace only source
        result = TokenOrientedObjectNotation.to_parsed_lines("   \n  \n", 2, true)
        @test isempty(result.lines)

        # Blank line tracking
        result = TokenOrientedObjectNotation.to_parsed_lines("line1\n\nline3", 2, true)
        @test length(result.lines) == 2
        @test length(result.blankLines) == 1
        @test result.blankLines[1].lineNumber == 2

        # Strict mode: tabs in indentation
        @test_throws Exception TokenOrientedObjectNotation.to_parsed_lines("\tindented", 2, true)

        # Strict mode: invalid indent multiple
        @test_throws Exception TokenOrientedObjectNotation.to_parsed_lines("   value", 2, true)

        # Lenient mode: accepts tabs
        result = TokenOrientedObjectNotation.to_parsed_lines("\tindented", 2, false)
        @test length(result.lines) == 1

        # Lenient mode: accepts invalid multiples
        result = TokenOrientedObjectNotation.to_parsed_lines("a\n   b", 2, false)
        @test length(result.lines) == 2

        # Depth calculation
        result = TokenOrientedObjectNotation.to_parsed_lines("a\n  b\n    c\n      d", 2, true)
        @test result.lines[1].depth == 0
        @test result.lines[2].depth == 1
        @test result.lines[3].depth == 2
        @test result.lines[4].depth == 3

        # Line numbers are one-based
        result = TokenOrientedObjectNotation.to_parsed_lines("a\nb\nc", 2, true)
        @test result.lines[1].lineNumber == 1
        @test result.lines[2].lineNumber == 2
        @test result.lines[3].lineNumber == 3
    end

    @testset "Parse Array Header" begin
        # Simple array header
        header = TokenOrientedObjectNotation.parse_array_header("[3]:")
        @test header !== nothing
        @test header.key === nothing
        @test header.length == 3
        @test header.delimiter == ","

        # Array header with key
        header = TokenOrientedObjectNotation.parse_array_header("items[5]:")
        @test header !== nothing
        @test header.key == "items"
        @test header.length == 5

        # Tabular array header
        header = TokenOrientedObjectNotation.parse_array_header("[2]{name,age}:")
        @test header !== nothing
        @test header.length == 2
        @test header.fields == ["name", "age"]

        # Tab delimiter
        header = TokenOrientedObjectNotation.parse_array_header("[3\t]:")
        @test header !== nothing
        @test header.delimiter == "\t"

        # Pipe delimiter
        header = TokenOrientedObjectNotation.parse_array_header("[3|]:")
        @test header !== nothing
        @test header.delimiter == "|"

        # Not an array header
        @test TokenOrientedObjectNotation.parse_array_header("name: value") === nothing

        # Invalid array header (no colon)
        @test_throws Exception TokenOrientedObjectNotation.parse_array_header("[3]")

        # Invalid array length
        @test_throws Exception TokenOrientedObjectNotation.parse_array_header("[-1]:")
        @test_throws Exception TokenOrientedObjectNotation.parse_array_header("[abc]:")
    end

    @testset "Parse Delimited Values" begin
        # Comma separated
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a,b,c", ",")
        @test tokens == ["a", "b", "c"]

        # Tab delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a\tb\tc", "\t")
        @test tokens == ["a", "b", "c"]

        # Pipe delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a|b|c", "|")
        @test tokens == ["a", "b", "c"]

        # Empty values
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a,,c", ",")
        @test tokens == ["a", "", "c"]

        # Trailing delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a,b,", ",")
        @test tokens == ["a", "b", ""]

        # Leading delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values(",a,b", ",")
        @test tokens == ["", "a", "b"]

        # Only delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values(",", ",")
        @test tokens == ["", ""]

        # No delimiter
        tokens = TokenOrientedObjectNotation.parse_delimited_values("abc", ",")
        @test tokens == ["abc"]

        # Empty string
        tokens = TokenOrientedObjectNotation.parse_delimited_values("", ",")
        @test tokens == [""]

        # Quoted sections with delimiter inside
        tokens = TokenOrientedObjectNotation.parse_delimited_values("a,\"b,c\",d", ",")
        @test tokens == ["a", "\"b,c\"", "d"]

        # Multiple quoted sections
        tokens = TokenOrientedObjectNotation.parse_delimited_values("\"a,b\",\"c,d\",\"e,f\"", ",")
        @test tokens == ["\"a,b\"", "\"c,d\"", "\"e,f\""]

        # Preserves whitespace
        tokens = TokenOrientedObjectNotation.parse_delimited_values(" a , b , c ", ",")
        @test tokens == [" a ", " b ", " c "]

        # Escaped quote in quotes
        tokens = TokenOrientedObjectNotation.parse_delimited_values("\"a\\\"b\",c", ",")
        @test tokens == ["\"a\\\"b\"", "c"]
    end

    @testset "Parse Key" begin
        # Unquoted key
        @test TokenOrientedObjectNotation.parse_key("name") == "name"

        # Quoted key
        @test TokenOrientedObjectNotation.parse_key("\"name with space\"") == "name with space"

        # Quoted key with escape
        @test TokenOrientedObjectNotation.parse_key("\"name\\\"quoted\"") == "name\"quoted"

        # Key with whitespace (trimmed)
        @test TokenOrientedObjectNotation.parse_key("  name  ") == "name"

        # Empty key (quoted)
        @test TokenOrientedObjectNotation.parse_key("\"\"") == ""

        # Unterminated quoted key
        @test_throws Exception TokenOrientedObjectNotation.parse_key("\"unterminated")
    end

    @testset "Find First Unquoted" begin
        # Simple case
        @test TokenOrientedObjectNotation.find_first_unquoted("key: value", ':') == 4

        # Character in quotes
        @test TokenOrientedObjectNotation.find_first_unquoted("\"a:b\":c", ':') == 6

        # Not found
        @test TokenOrientedObjectNotation.find_first_unquoted("abc", ':') === nothing

        # Multiple occurrences
        @test TokenOrientedObjectNotation.find_first_unquoted("a:b:c", ':') == 2

        # With escaped quote
        @test TokenOrientedObjectNotation.find_first_unquoted("\"a\\\"b\":c", ':') == 7

        # Empty string
        @test TokenOrientedObjectNotation.find_first_unquoted("", ':') === nothing
    end
end
