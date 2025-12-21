# Feature Specification: Official Conformance Test Suite Integration

**Feature Branch**: `001-official-conformance-tests`
**Created**: 2025-12-21
**Status**: Draft
**Input**: User description: "Use https://github.com/toon-format/spec as a submodule or similar and run the official conformance test suite instead of managing a custom one."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run Official Tests Automatically (Priority: P1)

As a developer working on ToonFormat.jl, I want the official TOON specification test fixtures to be automatically available and run as part of the standard test suite, so that I can validate compliance without manual fixture management.

**Why this priority**: This is the core value proposition - eliminating manual fixture downloads and ensuring tests always run against the authoritative specification fixtures.

**Independent Test**: Can be fully tested by running `Pkg.test("ToonFormat")` and verifying all official fixture tests execute without requiring manual setup steps.

**Acceptance Scenarios**:

1. **Given** a fresh clone of the repository, **When** I run the test suite, **Then** all official specification fixtures are available and tests execute successfully.
2. **Given** the official spec repository has been updated with new fixtures, **When** I update the submodule, **Then** new tests are automatically discovered and run.
3. **Given** CI runs on a pull request, **When** tests execute, **Then** official fixture tests are included in the results.

---

### User Story 2 - View Compliance Status (Priority: P2)

As a maintainer, I want to see a clear summary of which official fixture tests pass and fail, so that I can track progress toward 100% specification compliance.

**Why this priority**: Visibility into compliance status enables prioritization of bug fixes and provides confidence metrics for users evaluating the library.

**Independent Test**: Can be tested by running the fixture test suite and verifying that pass/fail counts are reported along with the specific failing test names.

**Acceptance Scenarios**:

1. **Given** some fixture tests fail, **When** I run the test suite, **Then** I see a summary showing X of Y tests passing and a list of failing test names.
2. **Given** all fixture tests pass, **When** I run the test suite, **Then** I see confirmation of 100% compliance.

---

### User Story 3 - Update to Latest Specification (Priority: P3)

As a maintainer, I want a simple way to update to the latest official specification fixtures, so that I can ensure the library stays current with specification changes.

**Why this priority**: The specification evolves over time; maintainers need a straightforward process to incorporate updates.

**Independent Test**: Can be tested by simulating a spec update and verifying the update process works correctly.

**Acceptance Scenarios**:

1. **Given** a new version of the spec is released, **When** I update the specification reference, **Then** the new fixtures are available for testing.
2. **Given** the update process is documented, **When** I follow the instructions, **Then** I can complete the update in under 5 minutes.

---

### Edge Cases

- What happens when the spec repository is temporarily unavailable during initial clone?
- How does the system handle fixtures with new test formats not yet supported by the test runner?
- What happens when a fixture file is malformed or contains invalid test data?
- How are conflicts handled if local test customizations exist alongside official fixtures?

## Clarifications

### Session 2025-12-21

- Q: How should schema validation failures be handled? → A: Skip invalid fixtures, report them, continue with valid ones
- Q: Should compliance percentage include skipped fixtures in the denominator? → A: Yes, include all fixtures in totals with skipped shown separately

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The official TOON specification repository MUST be included as a versioned dependency (submodule or similar mechanism).
- **FR-002**: Official test fixtures MUST be accessible without requiring manual download steps after initial repository clone.
- **FR-003**: The test runner MUST automatically discover and execute all official encode and decode fixture tests.
- **FR-009**: Each fixture file MUST be validated against `fixtures.schema.json` from the spec repository using JSONSchema.jl before test execution.
- **FR-010**: Fixtures that fail schema validation MUST be skipped with a warning report; valid fixtures MUST continue to execute.
- **FR-004**: Test results MUST clearly distinguish between official fixture tests and any additional library-specific tests.
- **FR-005**: The fixture integration MUST work offline after initial setup (no network required during test execution).
- **FR-006**: The test runner MUST report compliance metrics (pass count, fail count, skipped count, percentage) for official fixtures, with skipped fixtures included in the total denominator.
- **FR-007**: The update mechanism MUST allow pinning to a specific specification version for reproducible builds.
- **FR-008**: The integration MUST support CI environments without additional configuration beyond standard Julia package testing.

### Key Entities

- **Spec Repository**: The official toon-format/spec repository containing normative test fixtures.
- **Fixture File**: A JSON file containing test cases with input, expected output, and options.
- **Test Case**: An individual encode or decode scenario with input data, expected result, and optional configuration.
- **Compliance Report**: A summary of pass/fail status across all official fixture tests.

### Assumptions

- The official spec repository follows a stable structure for fixtures (currently `tests/fixtures/encode/*.json` and `tests/fixtures/decode/*.json`).
- Fixture JSON format includes `description`, `tests` array, with each test having `name`, `input`, `expected`, and optional `options` and `shouldError` fields.
- Git submodules are an acceptable dependency for users (standard Git feature).
- The current test runner implementation can be adapted to work with submodule paths.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers can run all official fixture tests with a single command (`Pkg.test()`) without any prior manual setup.
- **SC-002**: Test suite correctly identifies and reports on 100% of official fixture files present in the specification repository.
- **SC-003**: Time to update to a new specification version is under 5 minutes for a maintainer following documentation.
- **SC-004**: CI builds complete successfully without requiring network access to external fixture sources during test execution.
- **SC-005**: Compliance percentage is visible in test output showing passing, failing, and skipped counts (e.g., "Official Fixtures: 280/340 passing, 48 failing, 12 skipped (82.4%)").
- **SC-006**: New fixtures added to the spec repository are automatically discovered on next test run after submodule update.
