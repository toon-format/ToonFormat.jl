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

# Fixture options use the field names of `EncodeOptions` and `DecodeOptions`.
options_kwargs(test) = (Symbol(k) => v for (k, v) in get(test, :options, Dict()))

# JSON-model equality: ordered keys, and no `Bool`/`Number` coercion, since
# `true == 1` holds in Julia.
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
    category == "encode" &&
        return encode(test.input; options = EncodeOptions(; options_kwargs(test)...))
    return decode(test.input; options = DecodeOptions(; options_kwargs(test)...))
end

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
                        @test json_equal(run_case(test, category), test.expected)
                    end
                end
            end
        end
    end
end
