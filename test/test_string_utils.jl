# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TOON

@testset "String Utilities Tests" begin
    @testset "Escape String" begin
        # Test individual escape sequences (Requirement 3.1)
        # Only these five escapes should be used: \\, \", \n, \r, \t
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
        
        # Test that other characters are NOT escaped (Requirement 3.1)
        # Characters like /, space, etc. should pass through unchanged
        @test TOON.escape_string("path/to/file") == "path/to/file"
        @test TOON.escape_string("hello world") == "hello world"
        @test TOON.escape_string("test@example.com") == "test@example.com"
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

        # Test error on backslash at end (unterminated escape)
        @test_throws ArgumentError TOON.unescape_string("test\\")
        @test_throws ArgumentError TOON.unescape_string("\\")

        # Test error on invalid escape sequences (Requirement 3.2)
        # Only \\, \", \n, \r, \t are valid
        @test_throws ArgumentError TOON.unescape_string("test\\x")
        @test_throws ArgumentError TOON.unescape_string("test\\a")
        @test_throws ArgumentError TOON.unescape_string("test\\b")
        @test_throws ArgumentError TOON.unescape_string("test\\f")
        @test_throws ArgumentError TOON.unescape_string("test\\v")
        @test_throws ArgumentError TOON.unescape_string("test\\0")
        @test_throws ArgumentError TOON.unescape_string("test\\u0041")
        @test_throws ArgumentError TOON.unescape_string("test\\/")
        @test_throws ArgumentError TOON.unescape_string("test\\s")
        @test_throws ArgumentError TOON.unescape_string("test\\1")
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
        # Empty string needs quotes (Requirement 3.3)
        @test TOON.encode("") == "\"\""

        # Reserved literals need quotes (Requirement 3.5)
        @test TOON.encode("true") == "\"true\""
        @test TOON.encode("false") == "\"false\""
        @test TOON.encode("null") == "\"null\""

        # Numeric literals need quotes (Requirement 3.6)
        @test TOON.encode("123") == "\"123\""
        @test TOON.encode("3.14") == "\"3.14\""
        @test TOON.encode("-42") == "\"-42\""
        @test TOON.encode("1e6") == "\"1e6\""
        @test TOON.encode("1.5e-3") == "\"1.5e-3\""
        @test TOON.encode("0.5") == "\"0.5\""
        
        # Numbers with leading zeros need quotes (Requirement 3.6)
        @test TOON.encode("05") == "\"05\""
        @test TOON.encode("0001") == "\"0001\""

        # Leading/trailing whitespace needs quotes (Requirement 3.4)
        @test TOON.encode(" hello") == "\" hello\""
        @test TOON.encode("hello ") == "\"hello \""
        @test TOON.encode("  hello  ") == "\"  hello  \""
        @test TOON.encode("\thello") == "\"\\thello\""
        @test TOON.encode("hello\t") == "\"hello\\t\""

        # Special characters need quotes (Requirement 3.7)
        @test TOON.encode("key:value") == "\"key:value\""
        @test TOON.encode("say \"hi\"") == "\"say \\\"hi\\\"\""
        @test TOON.encode("path\\to\\file") == "\"path\\\\to\\\\file\""
        @test TOON.encode("[array]") == "\"[array]\""
        @test TOON.encode("{object}") == "\"{object}\""
        @test TOON.encode("line1\nline2") == "\"line1\\nline2\""
        @test TOON.encode("line1\rline2") == "\"line1\\rline2\""
        @test TOON.encode("col1\tcol2") == "\"col1\\tcol2\""
        
        # Control characters need quotes (Requirement 3.7)
        @test TOON.encode("test\x00value") == "\"test\\x00value\"" || occursin("\"", TOON.encode("test\x00value"))
        @test TOON.encode("test\x1Fvalue") == "\"test\\x1Fvalue\"" || occursin("\"", TOON.encode("test\x1Fvalue"))
        @test TOON.encode("test\x7Fvalue") == "\"test\\x7Fvalue\"" || occursin("\"", TOON.encode("test\x7Fvalue"))

        # Hyphen quoting (Requirement 3.9)
        @test TOON.encode("-") == "\"-\""
        @test TOON.encode("-hello") == "\"-hello\""
        @test TOON.encode("-123") == "\"-123\""
        
        # Regular strings don't need quotes
        @test TOON.encode("hello world") == "hello world"
        @test TOON.encode("hello_world") == "hello_world"
        @test TOON.encode("HelloWorld123") == "HelloWorld123"
        @test TOON.encode("test") == "test"
    end
    
    @testset "Delimiter-Aware Quoting" begin
        # Strings containing comma need quotes when comma is delimiter (Requirement 3.8)
        data_comma = Dict("value" => "a,b,c")
        encoded_comma = TOON.encode(data_comma)
        @test occursin("\"a,b,c\"", encoded_comma)
        
        # Strings containing tab need quotes when tab is delimiter (Requirement 3.8)
        data_tab = Dict("items" => ["a\tb", "c"])
        options_tab = TOON.EncodeOptions(delimiter=TOON.TAB)
        encoded_tab = TOON.encode(data_tab, options=options_tab)
        @test occursin("\"a\\tb\"", encoded_tab)
        
        # Strings containing pipe need quotes when pipe is delimiter (Requirement 3.8)
        data_pipe = Dict("items" => ["a|b", "c"])
        options_pipe = TOON.EncodeOptions(delimiter=TOON.PIPE)
        encoded_pipe = TOON.encode(data_pipe, options=options_pipe)
        @test occursin("\"a|b\"", encoded_pipe)
        
        # String without delimiter doesn't need quotes
        data_no_delim = Dict("value" => "abc")
        encoded_no_delim = TOON.encode(data_no_delim)
        @test occursin("value: abc", encoded_no_delim)
    end
    
    @testset "needs_quoting Direct Tests" begin
        # Test needs_quoting function directly with different delimiters
        # Note: needs_quoting is not exported, so we access it via TOON module
        
        # Empty string (Requirement 3.3)
        @test TOON.needs_quoting("", TOON.COMMA) == true
        
        # Leading/trailing whitespace (Requirement 3.4)
        @test TOON.needs_quoting(" hello", TOON.COMMA) == true
        @test TOON.needs_quoting("hello ", TOON.COMMA) == true
        @test TOON.needs_quoting("  hello  ", TOON.COMMA) == true
        
        # Reserved literals (Requirement 3.5)
        @test TOON.needs_quoting("true", TOON.COMMA) == true
        @test TOON.needs_quoting("false", TOON.COMMA) == true
        @test TOON.needs_quoting("null", TOON.COMMA) == true
        
        # Numeric-like strings (Requirement 3.6)
        @test TOON.needs_quoting("123", TOON.COMMA) == true
        @test TOON.needs_quoting("3.14", TOON.COMMA) == true
        @test TOON.needs_quoting("-42", TOON.COMMA) == true
        @test TOON.needs_quoting("1e6", TOON.COMMA) == true
        @test TOON.needs_quoting("05", TOON.COMMA) == true
        
        # Special characters (Requirement 3.7)
        @test TOON.needs_quoting("key:value", TOON.COMMA) == true
        @test TOON.needs_quoting("say \"hi\"", TOON.COMMA) == true
        @test TOON.needs_quoting("path\\file", TOON.COMMA) == true
        @test TOON.needs_quoting("[array]", TOON.COMMA) == true
        @test TOON.needs_quoting("{object}", TOON.COMMA) == true
        
        # Control characters (Requirement 3.7)
        @test TOON.needs_quoting("line1\nline2", TOON.COMMA) == true
        @test TOON.needs_quoting("line1\rline2", TOON.COMMA) == true
        @test TOON.needs_quoting("col1\tcol2", TOON.COMMA) == true
        @test TOON.needs_quoting("test\x00value", TOON.COMMA) == true
        @test TOON.needs_quoting("test\x1Fvalue", TOON.COMMA) == true
        @test TOON.needs_quoting("test\x7Fvalue", TOON.COMMA) == true
        
        # Delimiter-aware quoting (Requirement 3.8)
        @test TOON.needs_quoting("a,b", TOON.COMMA) == true
        @test TOON.needs_quoting("a,b", TOON.TAB) == false  # comma not active delimiter
        @test TOON.needs_quoting("a\tb", TOON.TAB) == true
        @test TOON.needs_quoting("a\tb", TOON.COMMA) == true  # tab is control char
        @test TOON.needs_quoting("a|b", TOON.PIPE) == true
        @test TOON.needs_quoting("a|b", TOON.COMMA) == false  # pipe not special with comma
        
        # Hyphen quoting (Requirement 3.9)
        @test TOON.needs_quoting("-", TOON.COMMA) == true
        @test TOON.needs_quoting("-hello", TOON.COMMA) == true
        @test TOON.needs_quoting("-123", TOON.COMMA) == true
        
        # Strings that don't need quoting
        @test TOON.needs_quoting("hello", TOON.COMMA) == false
        @test TOON.needs_quoting("hello_world", TOON.COMMA) == false
        @test TOON.needs_quoting("HelloWorld123", TOON.COMMA) == false
        @test TOON.needs_quoting("test", TOON.COMMA) == false
    end

    @testset "Escape Sequence Compliance (Requirements 3.1, 3.2)" begin
        # Requirement 3.1: Only five escape sequences should be used
        @testset "Valid Escape Sequences" begin
            # Test all five valid escapes
            @test TOON.escape_string("\\") == "\\\\"
            @test TOON.escape_string("\"") == "\\\""
            @test TOON.escape_string("\n") == "\\n"
            @test TOON.escape_string("\r") == "\\r"
            @test TOON.escape_string("\t") == "\\t"
            
            # Test round-trip for all valid escapes
            @test TOON.unescape_string("\\\\") == "\\"
            @test TOON.unescape_string("\\\"") == "\""
            @test TOON.unescape_string("\\n") == "\n"
            @test TOON.unescape_string("\\r") == "\r"
            @test TOON.unescape_string("\\t") == "\t"
        end
        
        # Requirement 3.2: Decoder must reject invalid escape sequences
        @testset "Invalid Escape Sequences Rejected" begin
            # Common escape sequences from other formats that should be rejected
            invalid_escapes = [
                "\\a",      # alert/bell
                "\\b",      # backspace
                "\\f",      # form feed
                "\\v",      # vertical tab
                "\\0",      # null character
                "\\x41",    # hex escape
                "\\u0041",  # unicode escape
                "\\/",      # forward slash (JSON allows, TOON doesn't need)
                "\\s",      # space (not needed)
                "\\1",      # octal
                "\\e",      # escape character
                "\\z",      # arbitrary character
            ]
            
            for invalid in invalid_escapes
                @test_throws ArgumentError TOON.unescape_string(invalid)
            end
        end
        
        # Test unterminated string detection
        @testset "Unterminated String Detection" begin
            @test_throws ArgumentError TOON.unescape_string("test\\")
            @test_throws ArgumentError TOON.unescape_string("\\")
            @test_throws ArgumentError TOON.unescape_string("hello\\nworld\\")
        end
        
        # Test that escape sequences work in context
        @testset "Escape Sequences in Context" begin
            # Test escapes at different positions
            @test TOON.unescape_string("\\nhello") == "\nhello"
            @test TOON.unescape_string("hello\\n") == "hello\n"
            @test TOON.unescape_string("hel\\nlo") == "hel\nlo"
            
            # Test multiple escapes
            @test TOON.unescape_string("\\n\\r\\t") == "\n\r\t"
            @test TOON.unescape_string("a\\nb\\rc\\td") == "a\nb\rc\td"
            
            # Test escaped backslash followed by valid escape character
            @test TOON.unescape_string("\\\\n") == "\\n"  # Should be backslash + n, not newline
            @test TOON.unescape_string("\\\\\\n") == "\\\n"  # Should be backslash + newline
        end
        
        # Test full encode/decode round-trip with all escapes
        @testset "Round-Trip with Escapes" begin
            test_strings = [
                "path\\to\\file",
                "say \"hello\"",
                "line1\nline2",
                "line1\rline2",
                "col1\tcol2",
                "complex\n\r\t\\\"test\"",
            ]
            
            for str in test_strings
                escaped = TOON.escape_string(str)
                unescaped = TOON.unescape_string(escaped)
                @test unescaped == str
            end
        end
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
