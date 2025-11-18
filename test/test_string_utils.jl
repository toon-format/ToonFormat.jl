# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using TokenOrientedObjectNotation

@testset "String Utilities Tests" begin
    @testset "Escape String" begin
        # Test individual escape sequences (Requirement 3.1)
        # Only these five escapes should be used: \\, \", \n, \r, \t
        @test TokenOrientedObjectNotation.escape_string("path\\to\\file") == "path\\\\to\\\\file"
        @test TokenOrientedObjectNotation.escape_string("say \"hello\"") == "say \\\"hello\\\""
        @test TokenOrientedObjectNotation.escape_string("line1\nline2") == "line1\\nline2"
        @test TokenOrientedObjectNotation.escape_string("line1\rline2") == "line1\\rline2"
        @test TokenOrientedObjectNotation.escape_string("col1\tcol2") == "col1\\tcol2"

        # Test multiple escape sequences
        @test TokenOrientedObjectNotation.escape_string("test\n\r\t\\\"value\"") == "test\\n\\r\\t\\\\\\\"value\\\""

        # Test empty string
        @test TokenOrientedObjectNotation.escape_string("") == ""

        # Test string with no special characters
        @test TokenOrientedObjectNotation.escape_string("hello world") == "hello world"
        
        # Test that other characters are NOT escaped (Requirement 3.1)
        # Characters like /, space, etc. should pass through unchanged
        @test TokenOrientedObjectNotation.escape_string("path/to/file") == "path/to/file"
        @test TokenOrientedObjectNotation.escape_string("hello world") == "hello world"
        @test TokenOrientedObjectNotation.escape_string("test@example.com") == "test@example.com"
    end

    @testset "Unescape String" begin
        # Test individual unescape sequences
        @test TokenOrientedObjectNotation.unescape_string("hello\\nworld") == "hello\nworld"
        @test TokenOrientedObjectNotation.unescape_string("col1\\tcol2") == "col1\tcol2"
        @test TokenOrientedObjectNotation.unescape_string("line1\\rline2") == "line1\rline2"
        @test TokenOrientedObjectNotation.unescape_string("path\\\\to\\\\file") == "path\\to\\file"
        @test TokenOrientedObjectNotation.unescape_string("say \\\"hello\\\"") == "say \"hello\""

        # Test multiple sequences
        @test TokenOrientedObjectNotation.unescape_string("test\\n\\r\\t\\\\\\\"value\\\"") == "test\n\r\t\\\"value\""

        # Test empty string
        @test TokenOrientedObjectNotation.unescape_string("") == ""

        # Test string with no escapes
        @test TokenOrientedObjectNotation.unescape_string("hello world") == "hello world"

        # Test error on backslash at end (unterminated escape)
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("\\")

        # Test error on invalid escape sequences (Requirement 3.2)
        # Only \\, \", \n, \r, \t are valid
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\x")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\a")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\b")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\f")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\v")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\0")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\u0041")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\/")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\s")
        @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\1")
    end

    @testset "Find First Unquoted" begin
        # Test simple case
        @test TokenOrientedObjectNotation.find_first_unquoted("key: value", ':') == 4

        # Test with quoted colon
        @test TokenOrientedObjectNotation.find_first_unquoted("\"key:1\": value", ':') == 8

        # Test character not found
        @test TokenOrientedObjectNotation.find_first_unquoted("abcdef", ':') === nothing

        # Test character only in quotes
        @test TokenOrientedObjectNotation.find_first_unquoted("\"a:b\"", ':') === nothing

        # Test empty string
        @test TokenOrientedObjectNotation.find_first_unquoted("", ':') === nothing

        # Test with escaped quote before target
        @test TokenOrientedObjectNotation.find_first_unquoted("\"a\\\"b\":value", ':') == 7

        # Test with escaped backslash before quote
        @test TokenOrientedObjectNotation.find_first_unquoted("\"test\\\\\":value", ':') == 9
    end

    @testset "String Quoting Rules" begin
        # Test needs_quoting function (if exposed)
        # Empty string needs quotes (Requirement 3.3)
        @test TokenOrientedObjectNotation.encode("") == "\"\""

        # Reserved literals need quotes (Requirement 3.5)
        @test TokenOrientedObjectNotation.encode("true") == "\"true\""
        @test TokenOrientedObjectNotation.encode("false") == "\"false\""
        @test TokenOrientedObjectNotation.encode("null") == "\"null\""

        # Numeric literals need quotes (Requirement 3.6)
        @test TokenOrientedObjectNotation.encode("123") == "\"123\""
        @test TokenOrientedObjectNotation.encode("3.14") == "\"3.14\""
        @test TokenOrientedObjectNotation.encode("-42") == "\"-42\""
        @test TokenOrientedObjectNotation.encode("1e6") == "\"1e6\""
        @test TokenOrientedObjectNotation.encode("1.5e-3") == "\"1.5e-3\""
        @test TokenOrientedObjectNotation.encode("0.5") == "\"0.5\""
        
        # Numbers with leading zeros need quotes (Requirement 3.6)
        @test TokenOrientedObjectNotation.encode("05") == "\"05\""
        @test TokenOrientedObjectNotation.encode("0001") == "\"0001\""

        # Leading/trailing whitespace needs quotes (Requirement 3.4)
        @test TokenOrientedObjectNotation.encode(" hello") == "\" hello\""
        @test TokenOrientedObjectNotation.encode("hello ") == "\"hello \""
        @test TokenOrientedObjectNotation.encode("  hello  ") == "\"  hello  \""
        @test TokenOrientedObjectNotation.encode("\thello") == "\"\\thello\""
        @test TokenOrientedObjectNotation.encode("hello\t") == "\"hello\\t\""

        # Special characters need quotes (Requirement 3.7)
        @test TokenOrientedObjectNotation.encode("key:value") == "\"key:value\""
        @test TokenOrientedObjectNotation.encode("say \"hi\"") == "\"say \\\"hi\\\"\""
        @test TokenOrientedObjectNotation.encode("path\\to\\file") == "\"path\\\\to\\\\file\""
        @test TokenOrientedObjectNotation.encode("[array]") == "\"[array]\""
        @test TokenOrientedObjectNotation.encode("{object}") == "\"{object}\""
        @test TokenOrientedObjectNotation.encode("line1\nline2") == "\"line1\\nline2\""
        @test TokenOrientedObjectNotation.encode("line1\rline2") == "\"line1\\rline2\""
        @test TokenOrientedObjectNotation.encode("col1\tcol2") == "\"col1\\tcol2\""
        
        # Control characters need quotes (Requirement 3.7)
        @test TokenOrientedObjectNotation.encode("test\x00value") == "\"test\\x00value\"" || occursin("\"", TokenOrientedObjectNotation.encode("test\x00value"))
        @test TokenOrientedObjectNotation.encode("test\x1Fvalue") == "\"test\\x1Fvalue\"" || occursin("\"", TokenOrientedObjectNotation.encode("test\x1Fvalue"))
        @test TokenOrientedObjectNotation.encode("test\x7Fvalue") == "\"test\\x7Fvalue\"" || occursin("\"", TokenOrientedObjectNotation.encode("test\x7Fvalue"))

        # Hyphen quoting (Requirement 3.9)
        @test TokenOrientedObjectNotation.encode("-") == "\"-\""
        @test TokenOrientedObjectNotation.encode("-hello") == "\"-hello\""
        @test TokenOrientedObjectNotation.encode("-123") == "\"-123\""
        
        # Regular strings don't need quotes
        @test TokenOrientedObjectNotation.encode("hello world") == "hello world"
        @test TokenOrientedObjectNotation.encode("hello_world") == "hello_world"
        @test TokenOrientedObjectNotation.encode("HelloWorld123") == "HelloWorld123"
        @test TokenOrientedObjectNotation.encode("test") == "test"
    end
    
    @testset "Delimiter-Aware Quoting" begin
        # Strings containing comma need quotes when comma is delimiter (Requirement 3.8)
        data_comma = Dict("value" => "a,b,c")
        encoded_comma = TokenOrientedObjectNotation.encode(data_comma)
        @test occursin("\"a,b,c\"", encoded_comma)
        
        # Strings containing tab need quotes when tab is delimiter (Requirement 3.8)
        data_tab = Dict("items" => ["a\tb", "c"])
        options_tab = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.TAB)
        encoded_tab = TokenOrientedObjectNotation.encode(data_tab, options=options_tab)
        @test occursin("\"a\\tb\"", encoded_tab)
        
        # Strings containing pipe need quotes when pipe is delimiter (Requirement 3.8)
        data_pipe = Dict("items" => ["a|b", "c"])
        options_pipe = TokenOrientedObjectNotation.EncodeOptions(delimiter=TokenOrientedObjectNotation.PIPE)
        encoded_pipe = TokenOrientedObjectNotation.encode(data_pipe, options=options_pipe)
        @test occursin("\"a|b\"", encoded_pipe)
        
        # String without delimiter doesn't need quotes
        data_no_delim = Dict("value" => "abc")
        encoded_no_delim = TokenOrientedObjectNotation.encode(data_no_delim)
        @test occursin("value: abc", encoded_no_delim)
    end
    
    @testset "needs_quoting Direct Tests" begin
        # Test needs_quoting function directly with different delimiters
        # Note: needs_quoting is not exported, so we access it via TOON module
        
        # Empty string (Requirement 3.3)
        @test TokenOrientedObjectNotation.needs_quoting("", TokenOrientedObjectNotation.COMMA) == true
        
        # Leading/trailing whitespace (Requirement 3.4)
        @test TokenOrientedObjectNotation.needs_quoting(" hello", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("hello ", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("  hello  ", TokenOrientedObjectNotation.COMMA) == true
        
        # Reserved literals (Requirement 3.5)
        @test TokenOrientedObjectNotation.needs_quoting("true", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("false", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("null", TokenOrientedObjectNotation.COMMA) == true
        
        # Numeric-like strings (Requirement 3.6)
        @test TokenOrientedObjectNotation.needs_quoting("123", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("3.14", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("-42", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("1e6", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("05", TokenOrientedObjectNotation.COMMA) == true
        
        # Special characters (Requirement 3.7)
        @test TokenOrientedObjectNotation.needs_quoting("key:value", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("say \"hi\"", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("path\\file", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("[array]", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("{object}", TokenOrientedObjectNotation.COMMA) == true
        
        # Control characters (Requirement 3.7)
        @test TokenOrientedObjectNotation.needs_quoting("line1\nline2", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("line1\rline2", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("col1\tcol2", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("test\x00value", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("test\x1Fvalue", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("test\x7Fvalue", TokenOrientedObjectNotation.COMMA) == true
        
        # Delimiter-aware quoting (Requirement 3.8)
        @test TokenOrientedObjectNotation.needs_quoting("a,b", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("a,b", TokenOrientedObjectNotation.TAB) == false  # comma not active delimiter
        @test TokenOrientedObjectNotation.needs_quoting("a\tb", TokenOrientedObjectNotation.TAB) == true
        @test TokenOrientedObjectNotation.needs_quoting("a\tb", TokenOrientedObjectNotation.COMMA) == true  # tab is control char
        @test TokenOrientedObjectNotation.needs_quoting("a|b", TokenOrientedObjectNotation.PIPE) == true
        @test TokenOrientedObjectNotation.needs_quoting("a|b", TokenOrientedObjectNotation.COMMA) == false  # pipe not special with comma
        
        # Hyphen quoting (Requirement 3.9)
        @test TokenOrientedObjectNotation.needs_quoting("-", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("-hello", TokenOrientedObjectNotation.COMMA) == true
        @test TokenOrientedObjectNotation.needs_quoting("-123", TokenOrientedObjectNotation.COMMA) == true
        
        # Strings that don't need quoting
        @test TokenOrientedObjectNotation.needs_quoting("hello", TokenOrientedObjectNotation.COMMA) == false
        @test TokenOrientedObjectNotation.needs_quoting("hello_world", TokenOrientedObjectNotation.COMMA) == false
        @test TokenOrientedObjectNotation.needs_quoting("HelloWorld123", TokenOrientedObjectNotation.COMMA) == false
        @test TokenOrientedObjectNotation.needs_quoting("test", TokenOrientedObjectNotation.COMMA) == false
    end

    @testset "Escape Sequence Compliance (Requirements 3.1, 3.2)" begin
        # Requirement 3.1: Only five escape sequences should be used
        @testset "Valid Escape Sequences" begin
            # Test all five valid escapes
            @test TokenOrientedObjectNotation.escape_string("\\") == "\\\\"
            @test TokenOrientedObjectNotation.escape_string("\"") == "\\\""
            @test TokenOrientedObjectNotation.escape_string("\n") == "\\n"
            @test TokenOrientedObjectNotation.escape_string("\r") == "\\r"
            @test TokenOrientedObjectNotation.escape_string("\t") == "\\t"
            
            # Test round-trip for all valid escapes
            @test TokenOrientedObjectNotation.unescape_string("\\\\") == "\\"
            @test TokenOrientedObjectNotation.unescape_string("\\\"") == "\""
            @test TokenOrientedObjectNotation.unescape_string("\\n") == "\n"
            @test TokenOrientedObjectNotation.unescape_string("\\r") == "\r"
            @test TokenOrientedObjectNotation.unescape_string("\\t") == "\t"
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
                @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string(invalid)
            end
        end
        
        # Test unterminated string detection
        @testset "Unterminated String Detection" begin
            @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("test\\")
            @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("\\")
            @test_throws ArgumentError TokenOrientedObjectNotation.unescape_string("hello\\nworld\\")
        end
        
        # Test that escape sequences work in context
        @testset "Escape Sequences in Context" begin
            # Test escapes at different positions
            @test TokenOrientedObjectNotation.unescape_string("\\nhello") == "\nhello"
            @test TokenOrientedObjectNotation.unescape_string("hello\\n") == "hello\n"
            @test TokenOrientedObjectNotation.unescape_string("hel\\nlo") == "hel\nlo"
            
            # Test multiple escapes
            @test TokenOrientedObjectNotation.unescape_string("\\n\\r\\t") == "\n\r\t"
            @test TokenOrientedObjectNotation.unescape_string("a\\nb\\rc\\td") == "a\nb\rc\td"
            
            # Test escaped backslash followed by valid escape character
            @test TokenOrientedObjectNotation.unescape_string("\\\\n") == "\\n"  # Should be backslash + n, not newline
            @test TokenOrientedObjectNotation.unescape_string("\\\\\\n") == "\\\n"  # Should be backslash + newline
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
                escaped = TokenOrientedObjectNotation.escape_string(str)
                unescaped = TokenOrientedObjectNotation.unescape_string(escaped)
                @test unescaped == str
            end
        end
    end

    @testset "Unicode Support" begin
        # Test encoding Unicode strings
        @test TokenOrientedObjectNotation.encode("café") == "café"
        @test TokenOrientedObjectNotation.encode("你好") == "你好"
        @test TokenOrientedObjectNotation.encode("emoji🎉") == "emoji🎉"  # Removed colon to avoid quoting

        # Test round-trip with Unicode
        original = Dict("message" => "Hello 世界 🌍")
        encoded = TokenOrientedObjectNotation.encode(original)
        decoded = TokenOrientedObjectNotation.decode(encoded)
        @test decoded["message"] == "Hello 世界 🌍"
    end
end
