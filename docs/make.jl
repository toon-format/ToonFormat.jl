using Documenter
using ToonFormat

makedocs(
    sitename = "ToonFormat.jl",
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", nothing) == "true",
        canonical = "https://toon-format.github.io/ToonFormat.jl",
        assets = String[],
    ),
    modules = [ToonFormat],
    checkdocs = :none,  # Don't require all functions to be documented
    pages = [
        "Home" => "index.md",
        "Options" => "options.md",
        "API Reference" => "api.md",
    ],
)

deploydocs(repo = "github.com/toon-format/ToonFormat.jl.git", devbranch = "main")
