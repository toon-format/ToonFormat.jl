# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "String Utilities Tests" begin
    @testset "Escape String" begin
        # Test individual escape sequences
        @test TOON.escape_string("path\\to\\file") == "path\\\\to\\\\file"
        @test TOON.escape_string("say \"hello\"") == "say \\\"hello\\\""
        @test TOON.escape_string("line1\nline2") == "line1\\nline2"
        @test TOON.escape_string("line1\rline2") == "line1\\rline2"
        @test TOON.escape_string("col1\tcol2") == "col1\\tcol2"

        # Test multiple escape sequences
        @test TOON.escape_string("test\n\r\t\\\"value\"") == "test\\n\\r\\t\\\\\\\"value\\\""

        # Test empty string
        @test TOON.escape_string("") == ""

        # Test string with no special characters
        @test TOON.escape_string("hello world") == "hello world"
    end

    @testset "Unescape String" begin
        # Test individual unescape sequences
        @test TOON.unescape_string("hello\\nworld") == "hello\nworld"
        @test TOON.unescape_string("col1\\tcol2") == "col1\tcol2"
        @test TOON.unescape_string("line1\\rline2") == "line1\rline2"
        @test TOON.unescape_string("path\\\\to\\\\file") == "path\\to\\file"
        @test TOON.unescape_string("say \\\"hello\\\"") == "say \"hello\""

        # Test multiple sequences
        @test TOON.unescape_string("test\\n\\r\\t\\\\\\\"value\\\"") == "test\n\r\t\\\"value\""

        # Test empty string
        @test TOON.unescape_string("") == ""

        # Test string with no escapes
        @test TOON.unescape_string("hello world") == "hello world"

        # Test error on backslash at end
        @test_throws Exception TOON.unescape_string("test\\")

        # Test error on invalid escape sequence
        @test_throws Exception TOON.unescape_string("test\\x")
    end

    @testset "Find First Unquoted" begin
        # Test simple case
        @test TOON.find_first_unquoted("key: value", ':') == 4

        # Test with quoted colon
        @test TOON.find_first_unquoted("\"key:1\": value", ':') == 8

        # Test character not found
        @test TOON.find_first_unquoted("abcdef", ':') === nothing

        # Test character only in quotes
        @test TOON.find_first_unquoted("\"a:b\"", ':') === nothing

        # Test empty string
        @test TOON.find_first_unquoted("", ':') === nothing

        # Test with escaped quote before target
        @test TOON.find_first_unquoted("\"a\\\"b\":value", ':') == 7

        # Test with escaped backslash before quote
        @test TOON.find_first_unquoted("\"test\\\\\":value", ':') == 9
    end

    @testset "String Quoting Rules" begin
        # Test needs_quoting function (if exposed)
        # Empty string needs quotes
        @test TOON.encode("") == "\"\""

        # Reserved literals need quotes
        @test TOON.encode("true") == "\"true\""
        @test TOON.encode("false") == "\"false\""
        @test TOON.encode("null") == "\"null\""

        # Numeric literals need quotes
        @test TOON.encode("123") == "\"123\""
        @test TOON.encode("3.14") == "\"3.14\""
        @test TOON.encode("-42") == "\"-42\""

        # Leading/trailing whitespace needs quotes
        @test TOON.encode(" hello") == "\" hello\""
        @test TOON.encode("hello ") == "\"hello \""

        # Regular strings don't need quotes
        @test TOON.encode("hello world") == "hello world"
        @test TOON.encode("hello_world") == "hello_world"
    end

    @testset "Unicode Support" begin
        # Test encoding Unicode strings
        @test TOON.encode("café") == "café"
        @test TOON.encode("你好") == "你好"
        @test TOON.encode("emoji🎉") == "emoji🎉"  # Removed colon to avoid quoting

        # Test round-trip with Unicode
        original = Dict("message" => "Hello 世界 🌍")
        encoded = TOON.encode(original)
        decoded = TOON.decode(encoded)
        @test decoded["message"] == "Hello 世界 🌍"
    end
end
