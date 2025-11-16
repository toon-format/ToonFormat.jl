#!/usr/bin/env julia

"""
Download TOON specification test fixtures from GitHub
"""

using Downloads

const BASE_URL = "https://raw.githubusercontent.com/toon-format/spec/main/tests/fixtures"
const FIXTURES_DIR = joinpath(@__DIR__, "fixtures")

# Ensure directories exist
mkpath(joinpath(FIXTURES_DIR, "encode"))
mkpath(joinpath(FIXTURES_DIR, "decode"))

# Encode fixtures
encode_files = [
    "arrays-nested.json",
    "arrays-objects.json",
    "arrays-primitive.json",
    "arrays-tabular.json",
    "delimiters.json",
    "key-folding.json",
    "objects.json",
    "primitives.json",
    "whitespace.json"
]

# Decode fixtures
decode_files = [
    "arrays-nested.json",
    "arrays-primitive.json",
    "arrays-tabular.json",
    "blank-lines.json",
    "delimiters.json",
    "indentation-errors.json",
    "numbers.json",
    "objects.json",
    "path-expansion.json",
    "primitives.json",
    "root-form.json",
    "validation-errors.json",
    "whitespace.json"
]

println("Downloading TOON test fixtures...")

# Download encode fixtures
for file in encode_files
    url = "$BASE_URL/encode/$file"
    dest = joinpath(FIXTURES_DIR, "encode", file)
    print("  encode/$file... ")
    try
        Downloads.download(url, dest)
        println("✓")
    catch e
        println("✗ ($(e))")
    end
end

# Download decode fixtures
for file in decode_files
    url = "$BASE_URL/decode/$file"
    dest = joinpath(FIXTURES_DIR, "decode", file)
    print("  decode/$file... ")
    try
        Downloads.download(url, dest)
        println("✓")
    catch e
        println("✗ ($(e))")
    end
end

println("\nFixtures downloaded to: $FIXTURES_DIR")
println("Run tests with: julia --project test/test_spec_fixtures.jl")
