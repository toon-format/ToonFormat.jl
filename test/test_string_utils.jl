# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "String Utilities Tests" begin
    @testset "Escape String" begin
        # Test individual escape sequences (Requirement 3.1)
        # Only these five escapes should be used: \\, \", \n, \r, \t
        @test ToonFormat.escape_string("path\\to\\file") == "path\\\\to\\\\file"
        @test ToonFormat.escape_string("say \"hello\"") == "say \\\"hello\\\""
        @test ToonFormat.escape_string("line1\nline2") == "line1\\nline2"
        @test ToonFormat.escape_string("line1\rline2") == "line1\\rline2"
        @test ToonFormat.escape_string("col1\tcol2") == "col1\\tcol2"

        # Test multiple escape sequences
        @test ToonFormat.escape_string("test\n\r\t\\\"value\"") == "test\\n\\r\\t\\\\\\\"value\\\""

        # Test empty string
        @test ToonFormat.escape_string("") == ""

        # Test string with no special characters
        @test ToonFormat.escape_string("hello world") == "hello world"
        
        # Test that other characters are NOT escaped (Requirement 3.1)
        # Characters like /, space, etc. should pass through unchanged
        @test ToonFormat.escape_string("path/to/file") == "path/to/file"
        @test ToonFormat.escape_string("hello world") == "hello world"
        @test ToonFormat.escape_string("test@example.com") == "test@example.com"
    end

    @testset "Unescape String" begin
        # Test individual unescape sequences
        @test ToonFormat.unescape_string("hello\\nworld") == "hello\nworld"
        @test ToonFormat.unescape_string("col1\\tcol2") == "col1\tcol2"
        @test ToonFormat.unescape_string("line1\\rline2") == "line1\rline2"
        @test ToonFormat.unescape_string("path\\\\to\\\\file") == "path\\to\\file"
        @test ToonFormat.unescape_string("say \\\"hello\\\"") == "say \"hello\""

        # Test multiple sequences
        @test ToonFormat.unescape_string("test\\n\\r\\t\\\\\\\"value\\\"") == "test\n\r\t\\\"value\""

        # Test empty string
        @test ToonFormat.unescape_string("") == ""

        # Test string with no escapes
        @test ToonFormat.unescape_string("hello world") == "hello world"

        # Test error on backslash at end (unterminated escape)
        @test_throws ArgumentError ToonFormat.unescape_string("test\\")
        @test_throws ArgumentError ToonFormat.unescape_string("\\")

        # Test error on invalid escape sequences (Requirement 3.2)
        # Only \\, \", \n, \r, \t are valid
        @test_throws ArgumentError ToonFormat.unescape_string("test\\x")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\a")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\b")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\f")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\v")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\0")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\u0041")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\/")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\s")
        @test_throws ArgumentError ToonFormat.unescape_string("test\\1")
    end

    @testset "Find First Unquoted" begin
        # Test simple case
        @test ToonFormat.find_first_unquoted("key: value", ':') == 4

        # Test with quoted colon
        @test ToonFormat.find_first_unquoted("\"key:1\": value", ':') == 8

        # Test character not found
        @test ToonFormat.find_first_unquoted("abcdef", ':') === nothing

        # Test character only in quotes
        @test ToonFormat.find_first_unquoted("\"a:b\"", ':') === nothing

        # Test empty string
        @test ToonFormat.find_first_unquoted("", ':') === nothing

        # Test with escaped quote before target
        @test ToonFormat.find_first_unquoted("\"a\\\"b\":value", ':') == 7

        # Test with escaped backslash before quote
        @test ToonFormat.find_first_unquoted("\"test\\\\\":value", ':') == 9
    end

    @testset "String Quoting Rules" begin
        # Test needs_quoting function (if exposed)
        # Empty string needs quotes (Requirement 3.3)
        @test ToonFormat.encode("") == "\"\""

        # Reserved literals need quotes (Requirement 3.5)
        @test ToonFormat.encode("true") == "\"true\""
        @test ToonFormat.encode("false") == "\"false\""
        @test ToonFormat.encode("null") == "\"null\""

        # Numeric literals need quotes (Requirement 3.6)
        @test ToonFormat.encode("123") == "\"123\""
        @test ToonFormat.encode("3.14") == "\"3.14\""
        @test ToonFormat.encode("-42") == "\"-42\""
        @test ToonFormat.encode("1e6") == "\"1e6\""
        @test ToonFormat.encode("1.5e-3") == "\"1.5e-3\""
        @test ToonFormat.encode("0.5") == "\"0.5\""
        
        # Numbers with leading zeros need quotes (Requirement 3.6)
        @test ToonFormat.encode("05") == "\"05\""
        @test ToonFormat.encode("0001") == "\"0001\""

        # Leading/trailing whitespace needs quotes (Requirement 3.4)
        @test ToonFormat.encode(" hello") == "\" hello\""
        @test ToonFormat.encode("hello ") == "\"hello \""
        @test ToonFormat.encode("  hello  ") == "\"  hello  \""
        @test ToonFormat.encode("\thello") == "\"\\thello\""
        @test ToonFormat.encode("hello\t") == "\"hello\\t\""

        # Special characters need quotes (Requirement 3.7)
        @test ToonFormat.encode("key:value") == "\"key:value\""
        @test ToonFormat.encode("say \"hi\"") == "\"say \\\"hi\\\"\""
        @test ToonFormat.encode("path\\to\\file") == "\"path\\\\to\\\\file\""
        @test ToonFormat.encode("[array]") == "\"[array]\""
        @test ToonFormat.encode("{object}") == "\"{object}\""
        @test ToonFormat.encode("line1\nline2") == "\"line1\\nline2\""
        @test ToonFormat.encode("line1\rline2") == "\"line1\\rline2\""
        @test ToonFormat.encode("col1\tcol2") == "\"col1\\tcol2\""
        
        # Control characters need quotes (Requirement 3.7)
        @test ToonFormat.encode("test\x00value") == "\"test\\x00value\"" || occursin("\"", ToonFormat.encode("test\x00value"))
        @test ToonFormat.encode("test\x1Fvalue") == "\"test\\x1Fvalue\"" || occursin("\"", ToonFormat.encode("test\x1Fvalue"))
        @test ToonFormat.encode("test\x7Fvalue") == "\"test\\x7Fvalue\"" || occursin("\"", ToonFormat.encode("test\x7Fvalue"))

        # Hyphen quoting (Requirement 3.9)
        @test ToonFormat.encode("-") == "\"-\""
        @test ToonFormat.encode("-hello") == "\"-hello\""
        @test ToonFormat.encode("-123") == "\"-123\""
        
        # Regular strings don't need quotes
        @test ToonFormat.encode("hello world") == "hello world"
        @test ToonFormat.encode("hello_world") == "hello_world"
        @test ToonFormat.encode("HelloWorld123") == "HelloWorld123"
        @test ToonFormat.encode("test") == "test"
    end
    
    @testset "Delimiter-Aware Quoting" begin
        # Strings containing comma need quotes when comma is delimiter (Requirement 3.8)
        data_comma = Dict("value" => "a,b,c")
        encoded_comma = ToonFormat.encode(data_comma)
        @test occursin("\"a,b,c\"", encoded_comma)
        
        # Strings containing tab need quotes when tab is delimiter (Requirement 3.8)
        data_tab = Dict("items" => ["a\tb", "c"])
        options_tab = ToonFormat.EncodeOptions(delimiter=ToonFormat.TAB)
        encoded_tab = ToonFormat.encode(data_tab, options=options_tab)
        @test occursin("\"a\\tb\"", encoded_tab)
        
        # Strings containing pipe need quotes when pipe is delimiter (Requirement 3.8)
        data_pipe = Dict("items" => ["a|b", "c"])
        options_pipe = ToonFormat.EncodeOptions(delimiter=ToonFormat.PIPE)
        encoded_pipe = ToonFormat.encode(data_pipe, options=options_pipe)
        @test occursin("\"a|b\"", encoded_pipe)
        
        # String without delimiter doesn't need quotes
        data_no_delim = Dict("value" => "abc")
        encoded_no_delim = ToonFormat.encode(data_no_delim)
        @test occursin("value: abc", encoded_no_delim)
    end
    
    @testset "needs_quoting Direct Tests" begin
        # Test needs_quoting function directly with different delimiters
        # Note: needs_quoting is not exported, so we access it via TOON module
        
        # Empty string (Requirement 3.3)
        @test ToonFormat.needs_quoting("", ToonFormat.COMMA) == true
        
        # Leading/trailing whitespace (Requirement 3.4)
        @test ToonFormat.needs_quoting(" hello", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("hello ", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("  hello  ", ToonFormat.COMMA) == true
        
        # Reserved literals (Requirement 3.5)
        @test ToonFormat.needs_quoting("true", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("false", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("null", ToonFormat.COMMA) == true
        
        # Numeric-like strings (Requirement 3.6)
        @test ToonFormat.needs_quoting("123", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("3.14", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("-42", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("1e6", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("05", ToonFormat.COMMA) == true
        
        # Special characters (Requirement 3.7)
        @test ToonFormat.needs_quoting("key:value", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("say \"hi\"", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("path\\file", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("[array]", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("{object}", ToonFormat.COMMA) == true
        
        # Control characters (Requirement 3.7)
        @test ToonFormat.needs_quoting("line1\nline2", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("line1\rline2", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("col1\tcol2", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("test\x00value", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("test\x1Fvalue", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("test\x7Fvalue", ToonFormat.COMMA) == true
        
        # Delimiter-aware quoting (Requirement 3.8)
        @test ToonFormat.needs_quoting("a,b", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("a,b", ToonFormat.TAB) == false  # comma not active delimiter
        @test ToonFormat.needs_quoting("a\tb", ToonFormat.TAB) == true
        @test ToonFormat.needs_quoting("a\tb", ToonFormat.COMMA) == true  # tab is control char
        @test ToonFormat.needs_quoting("a|b", ToonFormat.PIPE) == true
        @test ToonFormat.needs_quoting("a|b", ToonFormat.COMMA) == false  # pipe not special with comma
        
        # Hyphen quoting (Requirement 3.9)
        @test ToonFormat.needs_quoting("-", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("-hello", ToonFormat.COMMA) == true
        @test ToonFormat.needs_quoting("-123", ToonFormat.COMMA) == true
        
        # Strings that don't need quoting
        @test ToonFormat.needs_quoting("hello", ToonFormat.COMMA) == false
        @test ToonFormat.needs_quoting("hello_world", ToonFormat.COMMA) == false
        @test ToonFormat.needs_quoting("HelloWorld123", ToonFormat.COMMA) == false
        @test ToonFormat.needs_quoting("test", ToonFormat.COMMA) == false
    end

    @testset "Escape Sequence Compliance (Requirements 3.1, 3.2)" begin
        # Requirement 3.1: Only five escape sequences should be used
        @testset "Valid Escape Sequences" begin
            # Test all five valid escapes
            @test ToonFormat.escape_string("\\") == "\\\\"
            @test ToonFormat.escape_string("\"") == "\\\""
            @test ToonFormat.escape_string("\n") == "\\n"
            @test ToonFormat.escape_string("\r") == "\\r"
            @test ToonFormat.escape_string("\t") == "\\t"
            
            # Test round-trip for all valid escapes
            @test ToonFormat.unescape_string("\\\\") == "\\"
            @test ToonFormat.unescape_string("\\\"") == "\""
            @test ToonFormat.unescape_string("\\n") == "\n"
            @test ToonFormat.unescape_string("\\r") == "\r"
            @test ToonFormat.unescape_string("\\t") == "\t"
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
                @test_throws ArgumentError ToonFormat.unescape_string(invalid)
            end
        end
        
        # Test unterminated string detection
        @testset "Unterminated String Detection" begin
            @test_throws ArgumentError ToonFormat.unescape_string("test\\")
            @test_throws ArgumentError ToonFormat.unescape_string("\\")
            @test_throws ArgumentError ToonFormat.unescape_string("hello\\nworld\\")
        end
        
        # Test that escape sequences work in context
        @testset "Escape Sequences in Context" begin
            # Test escapes at different positions
            @test ToonFormat.unescape_string("\\nhello") == "\nhello"
            @test ToonFormat.unescape_string("hello\\n") == "hello\n"
            @test ToonFormat.unescape_string("hel\\nlo") == "hel\nlo"
            
            # Test multiple escapes
            @test ToonFormat.unescape_string("\\n\\r\\t") == "\n\r\t"
            @test ToonFormat.unescape_string("a\\nb\\rc\\td") == "a\nb\rc\td"
            
            # Test escaped backslash followed by valid escape character
            @test ToonFormat.unescape_string("\\\\n") == "\\n"  # Should be backslash + n, not newline
            @test ToonFormat.unescape_string("\\\\\\n") == "\\\n"  # Should be backslash + newline
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
                escaped = ToonFormat.escape_string(str)
                unescaped = ToonFormat.unescape_string(escaped)
                @test unescaped == str
            end
        end
    end

    @testset "Unicode Support" begin
        # Test encoding Unicode strings
        @test ToonFormat.encode("café") == "café"
        @test ToonFormat.encode("你好") == "你好"
        @test ToonFormat.encode("emoji🎉") == "emoji🎉"  # Removed colon to avoid quoting

        # Test round-trip with Unicode
        original = Dict("message" => "Hello 世界 🌍")
        encoded = ToonFormat.encode(original)
        decoded = ToonFormat.decode(encoded)
        @test decoded["message"] == "Hello 世界 🌍"
    end
end
