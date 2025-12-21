# Data Model: Official Conformance Test Suite Integration

**Feature**: 001-official-conformance-tests
**Date**: 2025-12-21

## Overview

This feature introduces no new persistent data models. All data structures are runtime-only for test execution. The primary data flows through fixture files sourced from the official spec repository.

## Entities

### 1. FixtureFile

Represents a single JSON fixture file from the spec repository.

**Source**: `test/spec/tests/fixtures/{encode,decode}/*.json`

**Structure** (defined by `fixtures.schema.json`):
```
FixtureFile
├── description: String      # Human-readable description of fixture category
└── tests: Array[TestCase]   # Collection of individual test cases
```

**Validation**: Must conform to `fixtures.schema.json` schema

**Lifecycle**:
1. Discovered via directory glob at test startup
2. Validated against schema
3. If valid: tests extracted and executed
4. If invalid: skipped with warning, counted in metrics

---

### 2. TestCase

Represents an individual encode or decode test within a fixture file.

**Structure**:
```
TestCase
├── name: String             # Unique test identifier within fixture
├── input: Any               # Input value (encode) or TOON string (decode)
├── expected: Any            # Expected TOON string (encode) or value (decode)
├── options?: Object         # Optional encode/decode options
│   ├── delimiter?: String   # ",", "\t", or "|"
│   ├── indent?: Integer     # Indentation spaces
│   ├── strict?: Boolean     # Strict mode for decode
│   ├── keyFolding?: String  # "off" or "safe"
│   ├── expandPaths?: String # "off" or "safe"
│   └── flattenDepth?: Integer
└── shouldError?: Boolean    # If true, operation should throw
```

**States**:
- **Pending**: Not yet executed
- **Passed**: Result matches expected (or error thrown when shouldError=true)
- **Failed**: Result differs from expected
- **Skipped**: Parent fixture failed schema validation

---

### 3. ComplianceReport

Runtime aggregate of test results for reporting.

**Structure**:
```
ComplianceReport
├── total: Integer           # Total test cases across all fixtures
├── passed: Integer          # Tests that passed
├── failed: Integer          # Tests that failed
├── skipped: Integer         # Tests skipped due to invalid fixtures
├── percentage: Float        # (passed / total) * 100
├── skipped_fixtures: Array[String]  # Names of skipped fixture files
└── failed_tests: Array[String]      # Names of failed test cases
```

**Computed At**: End of fixture test execution

---

### 4. FixtureSchema

The JSON Schema used to validate fixture files.

**Source**: `test/spec/tests/fixtures.schema.json`

**Usage**:
- Loaded once at test startup
- Parsed into `JSONSchema.Schema` object
- Used to validate each fixture file before test extraction

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        Test Execution                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  1. Load fixtures.schema.json → FixtureSchema                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Discover fixture files via glob → Array[FixtureFile path]   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. For each fixture file:                                      │
│     a. Parse JSON                                               │
│     b. Validate against FixtureSchema                           │
│     c. If invalid: record skip, continue                        │
│     d. If valid: extract TestCase array                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. For each TestCase:                                          │
│     a. Execute encode/decode with options                       │
│     b. Compare result to expected (or check error)              │
│     c. Record pass/fail                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Aggregate results → ComplianceReport                        │
│     Print summary to test output                                │
└─────────────────────────────────────────────────────────────────┘
```

## Relationships

```
FixtureSchema ──validates──▶ FixtureFile
                                  │
                                  │ contains
                                  ▼
                              TestCase
                                  │
                                  │ aggregated into
                                  ▼
                          ComplianceReport
```

## Notes

- No database or persistent storage required
- All entities are transient (exist only during test execution)
- Fixture files are read-only (sourced from submodule)
- Schema is read-only (sourced from submodule)
