# Copyright (c) 2025 TOON Format Organization
# SPDX-License-Identifier: MIT

using Test
using ToonFormat

@testset "Indentation and Whitespace" begin
    @testset "Requirement 9.1: Consistent spaces per level" begin
        # Default 2 spaces
        obj = Dict("a" => Dict("b" => Dict("c" => 1)))
        result = ToonFormat.encode(obj)
        lines = split(result, '\n')
        @test lines[1] == "a:"
        @test lines[2] == "  b:"
        @test lines[3] == "    c: 1"

        # Custom indent (4 spaces)
        options = ToonFormat.EncodeOptions(indent = 4)
        result = ToonFormat.encode(obj, options = options)
        lines = split(result, '\n')
        @test lines[1] == "a:"
        @test lines[2] == "    b:"
        @test lines[3] == "        c: 1"

        # Single level
        simple = Dict("x" => 1, "y" => 2)
        result = ToonFormat.encode(simple)
        for line in split(result, '\n')
            @test !startswith(line, " ")  # No indentation at depth 0
        end
    end

    @testset "Requirement 9.2: No tabs for indentation" begin
        # Encoder should never produce tabs for indentation
        obj = Dict("a" => Dict("b" => 1))
        result = ToonFormat.encode(obj)
        @test !occursin('\t', result) || occursin("[", result)  # Tabs only in array headers

        # Verify no tabs in indentation specifically
        lines = split(result, '\n')
        for line in lines
            if !isempty(line) && !startswith(strip(line), "[")
                # Check leading whitespace doesn't contain tabs
                leading = match(r"^(\s*)", line)
                if leading !== nothing
                    @test !occursin('\t', leading.captures[1])
                end
            end
        end
    end

    @testset "Requirement 9.3: Exactly one space after colons in key-value lines" begin
        # Simple key-value
        obj = Dict("name" => "Alice", "age" => 30)
        result = ToonFormat.encode(obj)
        @test occursin("name: Alice", result) || occursin("age: 30", result)
        @test !occursin(":  ", result)  # No double spaces
        @test !occursin(":", result) || occursin(": ", result)  # Space after colon

        # Nested object key-value
        nested = Dict("user" => Dict("id" => 1, "name" => "Bob"))
        result = ToonFormat.encode(nested)
        @test occursin("id: 1", result) || occursin("name: Bob", result)

        # List item with key-value (mixed array to force list format)
        arr = [Dict("x" => 1), Dict("x" => 2, "y" => 3)]  # Non-uniform
        result = ToonFormat.encode(arr)
        # Should have "- x: 1" format for list items
        @test occursin("- x: ", result)
    end

    @testset "Requirement 9.4: Exactly one space after array headers with inline values" begin
        # Primitive array
        arr = [1, 2, 3]
        result = ToonFormat.encode(arr)
        @test result == "[3]: 1,2,3"
        @test !occursin("]:  ", result)  # No double space

        # Array with different delimiter
        options = ToonFormat.EncodeOptions(delimiter = ToonFormat.TAB)
        result = ToonFormat.encode(arr, options = options)
        @test occursin("[3\t]: ", result)

        # Array of arrays (inline inner arrays)
        arr_of_arr = [[1, 2], [3, 4]]
        result = ToonFormat.encode(arr_of_arr)
        @test occursin("- [2]: ", result)
    end

    @testset "Requirement 9.5: No trailing spaces at end of lines" begin
        # Simple object
        obj = Dict("name" => "Alice", "age" => 30)
        result = ToonFormat.encode(obj)
        lines = split(result, '\n')
        for line in lines
            @test !endswith(line, " ")
            @test !endswith(line, "\t")
        end

        # Nested structure
        nested = Dict("user" => Dict("profile" => Dict("name" => "Bob")))
        result = ToonFormat.encode(nested)
        lines = split(result, '\n')
        for line in lines
            @test !endswith(line, " ")
        end

        # Array with tabular format
        tabular = [Dict("id" => 1, "name" => "Alice"), Dict("id" => 2, "name" => "Bob")]
        result = ToonFormat.encode(tabular)
        lines = split(result, '\n')
        for line in lines
            @test !endswith(line, " ")
        end

        # Empty object line (key:)
        obj_with_empty = Dict("empty" => Dict())
        result = ToonFormat.encode(obj_with_empty)
        lines = split(result, '\n')
        for line in lines
            @test !endswith(line, " ")
        end
    end

    @testset "Requirement 9.6: No trailing newline at end of document" begin
        # Simple value
        @test !endswith(ToonFormat.encode(42), '\n')
        @test !endswith(ToonFormat.encode("hello"), '\n')

        # Object
        obj = Dict("a" => 1, "b" => 2)
        result = ToonFormat.encode(obj)
        @test !endswith(result, '\n')

        # Array
        arr = [1, 2, 3]
        result = ToonFormat.encode(arr)
        @test !endswith(result, '\n')

        # Complex nested structure
        complex = Dict(
            "users" =>
                [Dict("id" => 1, "name" => "Alice"), Dict("id" => 2, "name" => "Bob")],
            "settings" => Dict("theme" => "dark"),
        )
        result = ToonFormat.encode(complex)
        @test !endswith(result, '\n')

        # Empty structures
        @test !endswith(ToonFormat.encode(Dict()), '\n')
        @test !endswith(ToonFormat.encode([]), '\n')
    end

    @testset "Requirement 9.7: Strict mode validates indentation as exact multiple" begin
        # Valid indentation (multiples of 2)
        valid_input = "a:\n  b: 1"
        @test_nowarn ToonFormat.decode(
            valid_input,
            options = ToonFormat.DecodeOptions(indent = 2, strict = true),
        )

        # Valid indentation (multiples of 4)
        valid_input = "a:\n    b: 1"
        @test_nowarn ToonFormat.decode(
            valid_input,
            options = ToonFormat.DecodeOptions(indent = 4, strict = true),
        )

        # Invalid indentation (3 spaces with indent=2)
        invalid_input = "a:\n   b: 1"
        @test_throws Exception ToonFormat.decode(
            invalid_input,
            options = ToonFormat.DecodeOptions(indent = 2, strict = true),
        )

        # Invalid indentation (5 spaces with indent=2)
        invalid_input = "a:\n     b: 1"
        @test_throws Exception ToonFormat.decode(
            invalid_input,
            options = ToonFormat.DecodeOptions(indent = 2, strict = true),
        )

        # Invalid indentation (2 spaces with indent=4)
        invalid_input = "a:\n  b: 1"
        @test_throws Exception ToonFormat.decode(
            invalid_input,
            options = ToonFormat.DecodeOptions(indent = 4, strict = true),
        )

        # Non-strict mode allows non-multiples
        lenient_input = "a:\n   b: 1"
        result = ToonFormat.decode(
            lenient_input,
            options = ToonFormat.DecodeOptions(indent = 2, strict = false),
        )
        @test haskey(result, "a")

        # Deep nesting with valid indentation
        deep_valid = "a:\n  b:\n    c:\n      d: 1"
        @test_nowarn ToonFormat.decode(
            deep_valid,
            options = ToonFormat.DecodeOptions(indent = 2, strict = true),
        )

        # Deep nesting with invalid indentation at one level
        deep_invalid = "a:\n  b:\n   c:\n      d: 1"
        @test_throws Exception ToonFormat.decode(
            deep_invalid,
            options = ToonFormat.DecodeOptions(indent = 2, strict = true),
        )
    end

    @testset "Requirement 9.8: Strict mode rejects tabs in indentation" begin
        # Tab in indentation
        tab_input = "\tvalue: 1"
        @test_throws Exception ToonFormat.decode(
            tab_input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Tab mixed with spaces
        mixed_input = "  \tvalue: 1"
        @test_throws Exception ToonFormat.decode(
            mixed_input,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Tab at deeper level
        nested_tab = "a:\n\tb: 1"
        @test_throws Exception ToonFormat.decode(
            nested_tab,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Tab in array header delimiter is OK (not indentation)
        # When tab delimiter is used, values should be tab-separated
        array_with_tab = "[3\t]: 1\t2\t3"
        @test_nowarn ToonFormat.decode(
            array_with_tab,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Tab in string value is OK (not indentation)
        string_with_tab = "text: \"hello\tworld\""
        @test_nowarn ToonFormat.decode(
            string_with_tab,
            options = ToonFormat.DecodeOptions(strict = true),
        )

        # Non-strict mode is more lenient - tabs are allowed but treated as single space
        # This is implementation-dependent behavior
        result = ToonFormat.decode(
            "\tvalue: 1",
            options = ToonFormat.DecodeOptions(strict = false),
        )
        @test haskey(result, "value")
    end

    @testset "Edge Cases: Indentation and Whitespace" begin
        # Zero-depth items (no indentation)
        root_obj = Dict("a" => 1, "b" => 2)
        result = ToonFormat.encode(root_obj)
        lines = split(result, '\n')
        for line in lines
            @test !startswith(line, " ")
        end

        # Empty lines in input (should be handled gracefully)
        input_with_blanks = "a: 1\n\nb: 2"
        result = ToonFormat.decode(
            input_with_blanks,
            options = ToonFormat.DecodeOptions(strict = false),
        )
        @test haskey(result, "a")
        @test haskey(result, "b")

        # Very deep nesting
        deep = Dict("a" => Dict("b" => Dict("c" => Dict("d" => Dict("e" => 1)))))
        result = ToonFormat.encode(deep)
        lines = split(result, '\n')
        @test lines[1] == "a:"
        @test lines[2] == "  b:"
        @test lines[3] == "    c:"
        @test lines[4] == "      d:"
        @test lines[5] == "        e: 1"

        # Array with nested objects (proper indentation)
        arr_with_obj = [Dict("x" => Dict("y" => 1))]
        result = ToonFormat.encode(arr_with_obj)
        @test occursin("[1]:", result)
        # Check indentation is consistent
        lines = split(result, '\n')
        for (i, line) in enumerate(lines)
            if i > 1  # Skip header
                # Count leading spaces
                spaces = length(match(r"^( *)", line).captures[1])
                @test spaces % 2 == 0  # Should be multiple of default indent
            end
        end
    end
end
