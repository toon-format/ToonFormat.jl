"""
Test ToonFormat.jl against official TOON specification test fixtures
https://github.com/toon-format/spec/tree/main/tests

Uses Git submodule at test/spec/ for fixtures. To initialize:
    git submodule update --init --recursive
"""

using Test
using ToonFormat
using JSON3
using JSONSchema

# =============================================================================
# T006: Submodule availability check
# =============================================================================

const SPEC_DIR = joinpath(@__DIR__, "spec", "tests")
const FIXTURES_DIR = joinpath(SPEC_DIR, "fixtures")
const SCHEMA_PATH = joinpath(SPEC_DIR, "fixtures.schema.json")

"""
Check if the spec submodule is initialized and available.
Returns true if fixtures are accessible, false otherwise with a warning.
"""
function check_submodule_available()
    if !isdir(FIXTURES_DIR)
        @warn """
        TOON spec submodule not initialized.

        To initialize the submodule, run:
            git submodule update --init --recursive

        Or clone with submodules:
            git clone --recurse-submodules <repo-url>

        Skipping official fixture tests.
        """
        return false
    end

    encode_dir = joinpath(FIXTURES_DIR, "encode")
    decode_dir = joinpath(FIXTURES_DIR, "decode")

    if !isdir(encode_dir) || !isdir(decode_dir)
        @warn "Spec submodule incomplete: missing encode/ or decode/ directories"
        return false
    end

    return true
end

# =============================================================================
# T004: Schema validation helper
# =============================================================================

# Cached schema object (loaded once)
const _FIXTURE_SCHEMA = Ref{Union{Nothing, JSONSchema.Schema}}(nothing)

"""
Load and cache the fixtures schema. Returns the schema object or nothing if unavailable.
"""
function get_fixture_schema()
    if _FIXTURE_SCHEMA[] === nothing
        if isfile(SCHEMA_PATH)
            try
                schema_json = JSON3.read(read(SCHEMA_PATH, String))
                _FIXTURE_SCHEMA[] = JSONSchema.Schema(schema_json)
            catch e
                @warn "Failed to load fixtures schema: $e"
                return nothing
            end
        else
            @warn "Fixtures schema not found at: $SCHEMA_PATH"
            return nothing
        end
    end
    return _FIXTURE_SCHEMA[]
end

"""
Validate a fixture file against the schema.
Returns (is_valid::Bool, error_message::Union{String, Nothing})
"""
function validate_fixture(fixture_data)
    schema = get_fixture_schema()
    if schema === nothing
        # No schema available - assume valid (graceful degradation)
        return (true, nothing)
    end

    try
        result = JSONSchema.validate(schema, fixture_data)
        if result === nothing
            return (true, nothing)
        else
            return (false, string(result))
        end
    catch e
        return (false, "Schema validation error: $e")
    end
end

# =============================================================================
# T005: Fixture discovery function
# =============================================================================

"""
Discover all fixture JSON files in a category directory.
Returns a sorted list of absolute file paths.
"""
function discover_fixtures(category::String)
    category_dir = joinpath(FIXTURES_DIR, category)
    if !isdir(category_dir)
        return String[]
    end

    files = readdir(category_dir; join=true)
    json_files = filter(f -> endswith(f, ".json"), files)
    return sort(json_files)
end

"""
Load a fixture file and return parsed JSON.
"""
function load_fixture_file(filepath::String)
    return JSON3.read(read(filepath, String))
end

# =============================================================================
# Helper functions (existing, preserved)
# =============================================================================

"""
Convert JSON3 objects to native Julia types for comparison.
"""
function normalize_json(val)
    if val isa JSON3.Object
        return ToonFormat.JsonObject(string(k) => normalize_json(v) for (k, v) in pairs(val))
    elseif val isa JSON3.Array || val isa Vector
        return [normalize_json(v) for v in val]
    else
        return val
    end
end

"""
Parse encode options from fixture test case.
"""
function parse_encode_options(opts)
    if isnothing(opts)
        return EncodeOptions()
    end

    kwargs = Dict{Symbol, Any}()
    haskey(opts, :delimiter) && (kwargs[:delimiter] = opts.delimiter)
    haskey(opts, :indent) && (kwargs[:indent] = opts.indent)
    haskey(opts, :keyFolding) && (kwargs[:keyFolding] = opts.keyFolding)
    haskey(opts, :flattenDepth) && (kwargs[:flattenDepth] = opts.flattenDepth)

    return EncodeOptions(; kwargs...)
end

"""
Parse decode options from fixture test case.
"""
function parse_decode_options(opts)
    if isnothing(opts)
        return DecodeOptions()
    end

    kwargs = Dict{Symbol, Any}()
    haskey(opts, :indent) && (kwargs[:indent] = opts.indent)
    haskey(opts, :strict) && (kwargs[:strict] = opts.strict)
    haskey(opts, :expandPaths) && (kwargs[:expandPaths] = opts.expandPaths)

    return DecodeOptions(; kwargs...)
end

# =============================================================================
# T013-T016: Compliance tracking (User Story 2)
# =============================================================================

"""
Mutable struct to track compliance metrics during test execution.
"""
mutable struct ComplianceReport
    total::Int
    passed::Int
    failed::Int
    skipped::Int
    skipped_fixtures::Vector{String}

    ComplianceReport() = new(0, 0, 0, 0, String[])
end

"""
Calculate compliance percentage.
"""
function compliance_percentage(report::ComplianceReport)
    if report.total == 0
        return 0.0
    end
    return round(report.passed / report.total * 100; digits=1)
end

"""
Print compliance summary to test output.
"""
function print_compliance_summary(report::ComplianceReport)
    pct = compliance_percentage(report)

    println()
    println("=" ^ 70)
    println("Official Fixtures: $(report.passed)/$(report.total) passing, " *
            "$(report.failed) failing, $(report.skipped) skipped ($pct%)")
    println("=" ^ 70)

    if !isempty(report.skipped_fixtures)
        println("\nSkipped fixtures (schema validation failed):")
        for name in report.skipped_fixtures
            println("  - $name")
        end
    end
    println()
end

# =============================================================================
# Main test execution
# =============================================================================

# Global compliance report for this test run
const COMPLIANCE = ComplianceReport()

"""
Run tests for a single fixture file.
Returns number of tests run.
"""
function run_fixture_tests(filepath::String, category::String, report::ComplianceReport)
    filename = basename(filepath)

    # Load fixture
    fixture_data = load_fixture_file(filepath)

    # Validate against schema (T009)
    is_valid, error_msg = validate_fixture(fixture_data)
    if !is_valid
        @warn "Skipping fixture $filename: $error_msg"
        # Count tests in this fixture as skipped
        test_count = length(get(fixture_data, :tests, []))
        report.skipped += test_count
        report.total += test_count
        push!(report.skipped_fixtures, filename)
        return 0
    end

    tests_run = 0
    description = get(fixture_data, :description, filename)

    @testset "$description" begin
        for test in fixture_data.tests
            report.total += 1
            tests_run += 1

            @testset "$(test.name)" begin
                try
                    if category == "encode"
                        input = normalize_json(test.input)
                        expected = test.expected
                        options = parse_encode_options(get(test, :options, nothing))

                        if get(test, :shouldError, false)
                            @test_throws Exception ToonFormat.encode(input; options=options)
                        else
                            result = ToonFormat.encode(input; options=options)
                            if result == expected
                                report.passed += 1
                            else
                                report.failed += 1
                            end
                            @test result == expected
                        end
                    else  # decode
                        input = test.input
                        expected = normalize_json(test.expected)
                        options = parse_decode_options(get(test, :options, nothing))

                        if get(test, :shouldError, false)
                            @test_throws Exception ToonFormat.decode(input; options=options)
                        else
                            result = ToonFormat.decode(input; options=options)
                            if result == expected
                                report.passed += 1
                            else
                                report.failed += 1
                            end
                            @test result == expected
                        end
                    end

                    # Count shouldError tests as passed if they threw
                    if get(test, :shouldError, false)
                        report.passed += 1
                    end
                catch e
                    if get(test, :shouldError, false)
                        # Expected to throw - this is a pass
                        report.passed += 1
                    else
                        report.failed += 1
                        rethrow(e)
                    end
                end
            end
        end
    end

    return tests_run
end

# =============================================================================
# Test execution entry point
# =============================================================================

if check_submodule_available()
    @testset "TOON Spec Fixtures" begin

        @testset "Encode Fixtures" begin
            encode_files = discover_fixtures("encode")

            for filepath in encode_files
                run_fixture_tests(filepath, "encode", COMPLIANCE)
            end
        end

        @testset "Decode Fixtures" begin
            decode_files = discover_fixtures("decode")

            for filepath in decode_files
                run_fixture_tests(filepath, "decode", COMPLIANCE)
            end
        end

        # Print compliance summary at the end
        print_compliance_summary(COMPLIANCE)
    end
else
    @testset "TOON Spec Fixtures" begin
        @test_skip "Spec submodule not available"
    end
end
