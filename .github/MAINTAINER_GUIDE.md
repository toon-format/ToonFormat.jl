# Maintainer Guide

## Releases

1. Bump `version` in `Project.toml` and move the `[Unreleased]` changelog entries under the new version.
2. Comment `@JuliaRegistrator register` on the release commit on `main`. Registrator opens a pull request against the Julia General registry, which merges it automatically once its checks pass.
3. TagBot then tags the release and creates the GitHub release. It pushes the tag with the `DOCUMENTER_KEY` deploy key, so the tag triggers the Documentation workflow, which publishes the `stable` docs.

## Documentation Deploy Key

The Documentation workflow pushes to `gh-pages` with the `DOCUMENTER_KEY` secret, whose public half is a deploy key with write access. To rotate it:

```julia
using DocumenterTools
DocumenterTools.genkeys(user = "toon-format", repo = "ToonFormat.jl")
```

Replace the deploy key under Settings → Deploy keys with the printed public key (allow write access), and the `DOCUMENTER_KEY` secret under Settings → Secrets and variables → Actions with the printed private key.
