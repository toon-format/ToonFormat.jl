# Quickstart: Official Conformance Test Suite

**Feature**: 001-official-conformance-tests

## Prerequisites

- Git 2.x+ with submodule support
- Julia 1.6+

## Setup (One-Time)

### Option A: Fresh Clone

```bash
git clone --recurse-submodules https://github.com/toon-format/ToonFormat.jl.git
cd ToonFormat.jl
```

### Option B: Existing Clone

```bash
cd ToonFormat.jl
git submodule update --init --recursive
```

## Running Tests

### All Tests (Including Official Fixtures)

```julia
using Pkg
Pkg.test("ToonFormat")
```

### Fixture Tests Only

```julia
julia --project=. -e 'include("test/test_spec_fixtures.jl")'
```

## Expected Output

```
Test Summary:                     | Pass  Fail  Total
TOON Spec Fixtures                |  280    48    328
  ├ Encode Fixtures               |  150    20    170
  └ Decode Fixtures               |  130    28    158

Official Fixtures: 280/340 passing, 48 failing, 12 skipped (82.4%)
```

## Updating to Latest Spec

When the official TOON specification is updated:

```bash
# Update submodule to latest
git submodule update --remote test/spec

# Verify new fixtures work
julia --project=. -e 'include("test/test_spec_fixtures.jl")'

# Commit the update
git add test/spec
git commit -m "chore: update TOON spec to $(cd test/spec && git rev-parse --short HEAD)"
```

## Troubleshooting

### "Fixtures not found" Error

The submodule wasn't initialized. Run:

```bash
git submodule update --init --recursive
```

### Schema Validation Warnings

If you see warnings about skipped fixtures, the fixture file doesn't match the expected schema. This usually indicates:

1. A new fixture format the test runner doesn't support yet
2. A corrupt or incomplete submodule checkout

Try:

```bash
cd test/spec
git status
git checkout .  # Reset any local changes
```

### CI Failures

Ensure your CI workflow includes submodule checkout:

```yaml
- uses: actions/checkout@v4
  with:
    submodules: recursive
```

## Verification Checklist

After setup, verify:

- [ ] `test/spec/tests/fixtures/encode/` contains JSON files
- [ ] `test/spec/tests/fixtures/decode/` contains JSON files
- [ ] `test/spec/tests/fixtures.schema.json` exists
- [ ] `Pkg.test("ToonFormat")` completes without "fixtures not found" warning
- [ ] Compliance percentage is displayed in test output
