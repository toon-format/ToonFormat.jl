# Contributing to ToonFormat.jl

## Development Setup

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

## Pull Requests

Spec behavior is tested through the spec fixtures – a missing case goes to toon-format/spec as a fixture. Julia-specific behavior, such as host type normalization, gets a test under `test/`. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. Changes to the format itself belong in [toon-format/spec](https://github.com/toon-format/spec). Maintainers find CI, documentation deployment, and release setup in [`.github/MAINTAINER_GUIDE.md`](.github/MAINTAINER_GUIDE.md).

## Maintainers

- Sébastien Celles – [@s-celles](https://github.com/s-celles)
