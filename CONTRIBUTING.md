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

Spec behavior is tested through the spec fixtures – a missing case goes to [toon-format/spec](https://github.com/toon-format/spec) as a fixture. Changes to the format itself belong there too. A test under `test/` is only for API the spec does not describe, such as host type normalization. Use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages. Maintainers find the release flow and the documentation deploy key in [`.github/MAINTAINER_GUIDE.md`](.github/MAINTAINER_GUIDE.md).

## Maintainers

- Sébastien Celles – [@s-celles](https://github.com/s-celles)
