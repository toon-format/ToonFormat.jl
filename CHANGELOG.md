# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Targets TOON spec v4.4.

### Added

- Decoding of comment lines, `\uXXXX` escapes, a leading byte-order mark, `[]` empty arrays, nested field groups (`orders[2]{id,customer{name,country}}:`), and keyed tabular objects (`users[2:]{id,role}:`)
- Encoding of uniform object columns as nested field groups, and of objects of uniform objects in keyed tabular form
- `decode` accepts any `AbstractString`

### Changed

- **Breaking:** the `indent` option of `EncodeOptions` and `DecodeOptions` is now `indentSize`
- Empty arrays encode as `key: []` and `[]` instead of `key[0]:` and `[0]:`
- Numbers other than integers encode with the shortest digits that decode back to the same `Float64`, in exponent form below `1e-6` and from `1e21` on – `0.1 + 0.2` as `0.30000000000000004` instead of the lossy `0.3`
- Strings starting with `#` or looking like a `+`-signed number, and a root string starting with U+FEFF, are quoted; strings padded with non-ASCII whitespace or containing DEL are not
- Control characters encode as `\u00xx` escapes
- `encode` throws an `ArgumentError` for strings that are not valid Unicode
- `EncodeOptions` and `DecodeOptions` throw an `ArgumentError` for an `indentSize` below 1, and `EncodeOptions` also for a delimiter other than `COMMA`, `TAB`, or `PIPE`
- Complex numbers encode as their `string` form and matrices as flat arrays in column-major order – both threw before
- Finite reals beyond the `Float64` range, such as `big"1e400"`, encode as a quoted string of their `BigFloat` value, and `1//0` as `null` – both encoded as a bare `Inf` before
- Integers beyond `Int64` decode as `BigInt` instead of strings
- The decoder follows the spec's line classification, header grammar, and depth rules, and strict mode rejects duplicate sibling keys; every decode error is an `ErrorException` naming the line

### Removed

- **Breaking:** key folding and path expansion, with the `keyFolding`, `flattenDepth`, and `expandPaths` options – spec v4.0 dropped them
- **Breaking:** the exported internal helpers `escape_string`, `unescape_string`, `find_first_unquoted`, `is_safe_identifier`, `needs_quoting`, `to_parsed_lines`, `parse_array_header`, `parse_delimited_values`, and `parse_key`

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
