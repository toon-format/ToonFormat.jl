using JSON
using LazyArtifacts

# GitHub release tarballs extract to a `spec-<version>` subdirectory.
const ARTIFACT_ROOT = artifact"toon_spec"
const FIXTURES_DIR = joinpath(
    ARTIFACT_ROOT,
    only(filter(startswith("spec-"), readdir(ARTIFACT_ROOT))),
    "tests",
    "fixtures",
)

normalize_json(value::AbstractDict) =
    ToonFormat.JsonObject(string(k) => normalize_json(v) for (k, v) in pairs(value))
normalize_json(value::AbstractVector) = [normalize_json(v) for v in value]
normalize_json(value) = value

function encode_options(options)
    isnothing(options) && return EncodeOptions()
    kwargs = Dict{Symbol,Any}()
    haskey(options, :delimiter) && (kwargs[:delimiter] = options.delimiter)
    haskey(options, :indentSize) && (kwargs[:indent] = options.indentSize)
    return EncodeOptions(; kwargs...)
end

function decode_options(options)
    isnothing(options) && return DecodeOptions()
    kwargs = Dict{Symbol,Any}()
    haskey(options, :indentSize) && (kwargs[:indent] = options.indentSize)
    haskey(options, :strict) && (kwargs[:strict] = options.strict)
    return DecodeOptions(; kwargs...)
end

# JSON-model equality per spec §2: ordered keys, and no `Bool`/`Number` coercion
# (`true == 1` holds in Julia, so plain `==` is too lenient).
json_equal(a::AbstractDict, b::AbstractDict) =
    collect(keys(a)) == collect(keys(b)) && all(json_equal(a[k], b[k]) for k in keys(a))
json_equal(a::AbstractVector, b::AbstractVector) =
    length(a) == length(b) && all(json_equal(x, y) for (x, y) in zip(a, b))
json_equal(a::Bool, b::Bool) = a == b
json_equal(::Bool, ::Any) = false
json_equal(::Any, ::Bool) = false
json_equal(a::Number, b::Number) = a == b
json_equal(a::AbstractString, b::AbstractString) = a == b
json_equal(::Nothing, ::Nothing) = true
json_equal(::Any, ::Any) = false

function run_case(test, category)
    options = get(test, :options, nothing)
    category == "encode" &&
        return ToonFormat.encode(normalize_json(test.input); options = encode_options(options))
    return ToonFormat.decode(test.input; options = decode_options(options))
end

expected_result(test, category) =
    category == "encode" ? test.expected : normalize_json(test.expected)

@testset "Spec Fixtures" begin
    for category in ("encode", "decode"),
        path in sort(readdir(joinpath(FIXTURES_DIR, category); join = true))

        endswith(path, ".json") || continue
        fixture_id = "$category/$(basename(path))"
        @testset "$fixture_id" begin
            for (index, test) in enumerate(JSON.parse(read(path, String)).tests)
                @testset "#$(index - 1) $(test.name)" begin
                    if get(test, :shouldError, false)
                        @test_throws Exception run_case(test, category)
                    else
                        @test json_equal(run_case(test, category), expected_result(test, category))
                    end
                end
            end
        end
    end
end
