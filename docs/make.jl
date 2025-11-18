using Documenter
using TokenOrientedObjectNotation

makedocs(
    sitename = "TokenOrientedObjectNotation.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://s-celles.github.io/TokenOrientedObjectNotation.jl",
        assets = String[],
    ),
    modules = [TokenOrientedObjectNotation],
    checkdocs = :none,  # Don't require all functions to be documented
    pages = [
        "Home" => "index.md",
        "Getting Started" => "getting-started.md",
        "User Guide" => [
            "guide/encoding.md",
            "guide/decoding.md",
            "guide/options.md",
            "guide/advanced.md",
        ],
        "Examples" => "examples.md",
        "API Reference" => "api.md",
        "Compliance" => "compliance.md",
        "Contributing" => "contributing.md",
    ],
)

deploydocs(
    repo = "github.com/s-celles/TokenOrientedObjectNotation.jl.git",
    devbranch = "main",
)
