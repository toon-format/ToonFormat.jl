using Documenter
using ToonFormat

makedocs(
    sitename = "ToonFormat.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://s-celles.github.io/ToonFormat.jl",
        assets = String[],
    ),
    modules = [ToonFormat],
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
    ],
)

deploydocs(
    repo = "github.com/s-celles/ToonFormat.jl.git",
    devbranch = "main",
)
