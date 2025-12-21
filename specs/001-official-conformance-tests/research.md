# Research: Official Conformance Test Suite Integration

**Feature**: 001-official-conformance-tests
**Date**: 2025-12-21

## Research Questions

### 1. JSONSchema.jl for Fixture Validation

**Decision**: Use JSONSchema.jl v1.x for validating fixture files against `fixtures.schema.json`

**Rationale**:
- Official Julia package for JSON Schema validation, MIT licensed
- Supports JSON Schema draft v4 and v6 (sufficient for TOON spec fixtures)
- Version 1.1.0+ includes JSON3 support (already a ToonFormat dependency)
- Simple API: `isvalid(schema, parsed_json)` returns boolean
- Detailed errors via `validate(schema, parsed_json)` for skip reporting
- Maintained and actively updated (recent version addressed Julia 1.6+ compatibility)

**Alternatives Considered**:
- Manual validation: Rejected - reinventing the wheel, error-prone
- Custom schema parser: Rejected - significant effort, no benefit over proven library

**Implementation Notes**:
- Add `JSONSchema = "7d188eb4-7ad8-530c-ae41-71a32a6d4692"` to `[extras]` in Project.toml
- Load schema once at test startup: `FIXTURE_SCHEMA = JSONSchema.Schema(JSON3.read(schema_path))`
- Validate each fixture file before iterating its tests

**Sources**:
- [JSONSchema.jl GitHub](https://github.com/fredo-dedup/JSONSchema.jl)
- [JSONSchema.jl Documentation](https://docs.juliahub.com/General/JSONSchema/stable/)

---

### 2. Git Submodule vs Alternatives

**Decision**: Use Git submodule pointing to `https://github.com/toon-format/spec`

**Rationale**:
- Versioned reference: submodule commit hash ensures reproducible builds
- Offline after clone: no network required during test execution (FR-005)
- Standard Git feature: no additional tooling required
- CI-compatible: GitHub Actions handles submodules with `submodules: recursive`
- Easy updates: `git submodule update --remote` for latest spec

**Alternatives Considered**:
- Julia Artifacts: Rejected - would require hosting fixtures separately, complex setup
- Download at test time: Current approach, rejected due to FR-005 (offline requirement)
- Copy fixtures into repo: Rejected - duplicates data, divergence risk
- Julia package dependency: Not applicable - spec repo is not a Julia package

**Implementation Notes**:
- Add submodule: `git submodule add https://github.com/toon-format/spec test/spec`
- CI workflow needs: `actions/checkout@v4` with `submodules: recursive`
- Document update process in CONTRIBUTING.md

**Known Limitations**:
- Users must clone with `--recurse-submodules` or run `git submodule update --init`
- Pkg.jl cannot add packages with submodules directly (GitError), but this doesn't affect ToonFormat since submodule is in test/ only

**Sources**:
- [Julia Package Testing Best Practices](https://blog.glcs.io/package-testing)
- [Pkg.jl Submodule Issue](https://github.com/JuliaLang/Pkg.jl/issues/708)

---

### 3. Fixture Discovery Strategy

**Decision**: Dynamic discovery via directory globbing

**Rationale**:
- FR-003 requires automatic discovery of all fixtures
- SC-006 requires new fixtures to be discovered after submodule update
- Hardcoded file lists (current approach) break when spec adds/removes fixtures

**Implementation**:
```julia
const SPEC_DIR = joinpath(@__DIR__, "spec", "tests")
const FIXTURES_DIR = joinpath(SPEC_DIR, "fixtures")

encode_files = readdir(joinpath(FIXTURES_DIR, "encode"); join=true)
decode_files = readdir(joinpath(FIXTURES_DIR, "decode"); join=true)

# Filter to .json files only
filter!(f -> endswith(f, ".json"), encode_files)
filter!(f -> endswith(f, ".json"), decode_files)
```

**Alternatives Considered**:
- Maintain hardcoded list: Rejected - violates SC-006 auto-discovery requirement
- Config file listing fixtures: Rejected - adds maintenance burden

---

### 4. Compliance Reporting Format

**Decision**: Summary line at end of fixture testset with counts and percentage

**Rationale**:
- SC-005 requires visible compliance percentage with pass/fail/skipped counts
- Julia Test stdlib provides `@testset` results that can be inspected
- Consistent with existing test output style

**Implementation**:
```julia
# After running all fixture tests
total = passed + failed + skipped
pct = round(passed / total * 100, digits=1)
@info "Official Fixtures: $passed/$total passing, $failed failing, $skipped skipped ($pct%)"
```

**Output Example**:
```
Test Summary:                     | Pass  Fail  Total
TOON Spec Fixtures                |  280    48    328
  ├ Encode Fixtures               |  150    20    170
  └ Decode Fixtures               |  130    28    158

Official Fixtures: 280/340 passing, 48 failing, 12 skipped (82.4%)
```

---

### 5. CI Configuration Updates

**Decision**: Update GitHub Actions workflow to checkout submodules

**Rationale**:
- FR-008 requires CI to work without additional configuration
- GitHub Actions supports submodules natively

**Implementation**:
```yaml
# .github/workflows/CI.yml
- uses: actions/checkout@v4
  with:
    submodules: recursive
```

**Alternatives Considered**:
- Separate submodule init step: Works but more verbose than built-in option

---

## Resolved Clarifications

All technical context questions resolved. No NEEDS CLARIFICATION items remain.

## Dependencies Summary

| Dependency | Version | Purpose | Scope |
|------------|---------|---------|-------|
| JSONSchema.jl | ^1.0 | Fixture schema validation | Test only |
| toon-format/spec | main branch | Official test fixtures | Git submodule |

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Spec repo restructures fixtures | Low | Medium | Pin to specific commit, update intentionally |
| JSONSchema.jl breaks on new schema features | Low | Low | Schema is simple, fallback to skip validation |
| Submodule not initialized | Medium | Medium | Clear error message with fix instructions |
