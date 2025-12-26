# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.1] - 2025-12-26

### Changed

- Updated documentation to reference TOON Specification v3.0
- Updated installation instructions for Julia General Registry

### Fixed

- Fixed encoding of `Vector{Pair}`, `NamedTuple`, and `Tuple` of `Pair`s as objects ([#11](https://github.com/toon-format/ToonFormat.jl/pull/11))

## [0.1.0] - 2025-11-16

### Added

- Initial release
- Full TOON Specification v3.0 compliance (349/349 fixture tests passing)
- `encode` and `decode` functions with configurable options
- Support for all delimiters (comma, tab, pipe)
- `EncodeOptions` for customizing encoding behavior
- `DecodeOptions` for customizing decoding behavior
- Key folding support (safe mode with depth limits)
- Path expansion support (safe mode with conflict detection)
- Strict mode validation for all §14 error conditions
- Comprehensive test suite (1750 tests)
- Full documentation with Documenter.jl

[Unreleased]: https://github.com/toon-format/ToonFormat.jl/compare/v0.1.1...HEAD
[0.1.1]: https://github.com/toon-format/ToonFormat.jl/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/toon-format/ToonFormat.jl/releases/tag/v0.1.0
