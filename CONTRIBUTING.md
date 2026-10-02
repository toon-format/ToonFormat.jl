# Contributing to ToonFormat.jl

## Development Setup

`Project.toml` declares Julia 1.6 or newer; CI tests 1.10, 1.12, and the latest release.

```bash
git clone https://github.com/toon-format/ToonFormat.jl.git
cd ToonFormat.jl
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

The test suite downloads the spec's conformance fixtures as a lazy artifact pinned in `test/Artifacts.toml`.

Build the documentation site into `docs/build/`:

```bash
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

## Coding Standards

- Public functions carry docstrings – `docs/src/api.md` renders them.
- Pull requests pass the Aqua.jl checks configured in `test/test_aqua.jl`.

## Pull Requests

Add tests for every behavior change and use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. Changes to the format itself belong in [toon-format/spec](https://github.com/toon-format/spec). Maintainers find CI, documentation deployment, and release setup in [`.github/MAINTAINER_GUIDE.md`](.github/MAINTAINER_GUIDE.md).

## Maintainers

- Sébastien Celles – [@s-celles](https://github.com/s-celles)

## License

By contributing, you agree that your contributions are licensed under the MIT License.
