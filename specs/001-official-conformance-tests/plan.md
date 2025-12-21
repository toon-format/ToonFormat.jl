# Implementation Plan: Official Conformance Test Suite Integration

**Branch**: `001-official-conformance-tests` | **Date**: 2025-12-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-official-conformance-tests/spec.md`

## Summary

Integrate the official TOON specification repository (https://github.com/toon-format/spec) as a Git submodule to replace manual fixture downloads. The test runner will automatically discover fixtures, validate them against the JSON schema using JSONSchema.jl, and report compliance metrics with pass/fail/skipped counts.

## Technical Context

**Language/Version**: Julia 1.6+
**Primary Dependencies**: JSON3 (existing), JSONSchema.jl (new test dependency)
**Storage**: Git submodule at `test/spec/` containing official fixtures
**Testing**: Julia Test stdlib, Aqua.jl (existing)
**Target Platform**: Cross-platform (Windows, macOS, Linux)
**Project Type**: Single Julia package
**Performance Goals**: Test execution overhead <5% compared to current fixture tests
**Constraints**: Offline-capable after initial clone, CI-compatible without extra setup
**Scale/Scope**: ~340 fixture tests across encode/decode categories

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| I. Specification Fidelity | Fixture compliance tracked and reported | ✅ PASS | FR-006 requires compliance metrics |
| I. Specification Fidelity | Every normative requirement has test coverage | ✅ PASS | Official fixtures provide authoritative coverage |
| II. Test-Driven Quality | Tests cover unit, integration, contract, edge cases | ✅ PASS | Feature adds contract tests via official fixtures |
| II. Test-Driven Quality | Aqua.jl checks MUST pass | ✅ PASS | No changes to Aqua config |
| III. API Consistency | Error messages MUST be actionable | ✅ PASS | FR-010 requires clear skip warnings |
| IV. Performance Efficiency | No excessive computational overhead | ✅ PASS | Schema validation is O(n) per fixture file |

**Gate Status**: ✅ ALL GATES PASS

## Project Structure

### Documentation (this feature)

```text
specs/001-official-conformance-tests/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── contracts/           # N/A (no API contracts for this feature)
```

### Source Code (repository root)

```text
test/
├── spec/                    # NEW: Git submodule → toon-format/spec
│   └── tests/
│       ├── fixtures/
│       │   ├── encode/*.json
│       │   └── decode/*.json
│       └── fixtures.schema.json
├── test_spec_fixtures.jl    # MODIFIED: Use submodule path, add schema validation
├── runtests.jl              # MODIFIED: Remove conditional fixture check
├── download_fixtures.jl     # DEPRECATED: No longer needed
└── fixtures/                # DEPRECATED: Remove copied fixtures

.gitmodules                  # NEW: Submodule configuration
Project.toml                 # MODIFIED: Add JSONSchema.jl to test deps
```

**Structure Decision**: Single Julia package structure maintained. Git submodule added under `test/spec/` to isolate external dependency from source code.

## Complexity Tracking

No constitution violations requiring justification.
