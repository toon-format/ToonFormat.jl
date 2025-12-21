# Tasks: Official Conformance Test Suite Integration

**Input**: Design documents from `/specs/001-official-conformance-tests/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: No explicit TDD requested. Tests are the feature itself (fixture test runner).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: Julia package at repository root
- Paths: `test/`, `Project.toml`, `.github/workflows/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add Git submodule and configure dependencies

- [x] T001 Add toon-format/spec as Git submodule at test/spec/ via `git submodule add https://github.com/toon-format/spec test/spec`
- [x] T002 Add JSONSchema.jl to test dependencies in Project.toml [extras] and [targets]
- [x] T003 [P] Update .github/workflows/CI.yml to checkout with `submodules: recursive`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create schema validation helper function in test/test_spec_fixtures.jl to load and cache fixtures.schema.json
- [x] T005 Create fixture discovery function in test/test_spec_fixtures.jl to glob encode/*.json and decode/*.json from submodule
- [x] T006 Create submodule availability check in test/test_spec_fixtures.jl with clear error message if not initialized

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Run Official Tests Automatically (Priority: P1) 🎯 MVP

**Goal**: Official fixtures automatically available and executed via `Pkg.test()` without manual setup

**Independent Test**: Run `Pkg.test("ToonFormat")` on fresh clone with `--recurse-submodules` and verify fixture tests execute

### Implementation for User Story 1

- [x] T007 [US1] Update fixture path constants in test/test_spec_fixtures.jl to use submodule path `test/spec/tests/fixtures/`
- [x] T008 [US1] Implement dynamic fixture file discovery in test/test_spec_fixtures.jl using `readdir()` instead of hardcoded list
- [x] T009 [US1] Add schema validation before test execution in test/test_spec_fixtures.jl - skip invalid fixtures with warning per FR-010
- [x] T010 [US1] Update test/runtests.jl to remove conditional fixture check (line 46-50) - fixtures always available via submodule
- [x] T011 [US1] Deprecate test/download_fixtures.jl by adding warning message pointing to submodule approach
- [x] T012 [US1] Remove test/fixtures/ directory (old downloaded fixtures) after verifying submodule works

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - View Compliance Status (Priority: P2)

**Goal**: Clear compliance summary with pass/fail/skipped counts and percentage

**Independent Test**: Run fixture tests with some known failures and verify summary output shows counts and percentage

### Implementation for User Story 2

- [x] T013 [US2] Create ComplianceReport struct in test/test_spec_fixtures.jl to track passed/failed/skipped/total counts
- [x] T014 [US2] Implement compliance tracking logic in test/test_spec_fixtures.jl to count results during test execution
- [x] T015 [US2] Add compliance summary output at end of fixture testset in test/test_spec_fixtures.jl with format: "Official Fixtures: X/Y passing, Z failing, W skipped (P%)"
- [x] T016 [US2] Track and report skipped fixture file names in test/test_spec_fixtures.jl for debugging schema issues

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Update to Latest Specification (Priority: P3)

**Goal**: Simple documented process to update spec submodule

**Independent Test**: Follow documented update process and verify new fixtures are discovered

### Implementation for User Story 3

- [x] T017 [US3] Document submodule update process in CONTRIBUTING.md with commands for updating to latest spec
- [x] T018 [US3] Add submodule initialization instructions to README.md for users cloning without --recurse-submodules
- [x] T019 [US3] Document version pinning approach in CONTRIBUTING.md for reproducible builds

**Checkpoint**: All user stories should now be independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Cleanup and validation

- [x] T020 [P] Update .gitignore to exclude any local fixture overrides if applicable
- [x] T021 [P] Verify Aqua.jl tests still pass after changes via `julia --project=. -e 'include("test/test_aqua.jl")'`
- [x] T022 Run full test suite and verify compliance percentage matches expected (~87.6% per README)
- [x] T023 Validate quickstart.md instructions work on fresh clone

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - US1 → US2 → US3 (sequential recommended due to shared file modifications)
- **Polish (Final Phase)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - Core functionality
- **User Story 2 (P2)**: Depends on US1 - Adds reporting on top of running fixtures
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Documentation only, independent of code

### Within Each User Story

- T007-T012: Sequential within US1 (shared file: test_spec_fixtures.jl)
- T013-T016: Sequential within US2 (shared file: test_spec_fixtures.jl)
- T017-T019: Can be parallelized (different files: CONTRIBUTING.md, README.md)

### Parallel Opportunities

- T002 and T003 can run in parallel (different files)
- T017, T018, T019 can run in parallel (different documentation files)
- T020 and T021 can run in parallel (different concerns)

---

## Parallel Example: Setup Phase

```bash
# After T001 (submodule add) completes, these can run in parallel:
Task: "Add JSONSchema.jl to test dependencies in Project.toml"
Task: "Update .github/workflows/CI.yml to checkout with submodules: recursive"
```

## Parallel Example: User Story 3

```bash
# These documentation tasks can run in parallel:
Task: "Document submodule update process in CONTRIBUTING.md"
Task: "Add submodule initialization instructions to README.md"
Task: "Document version pinning approach in CONTRIBUTING.md"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T006)
3. Complete Phase 3: User Story 1 (T007-T012)
4. **STOP and VALIDATE**: Run `Pkg.test("ToonFormat")` and verify fixtures execute
5. MVP delivered - fixtures work without manual download

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → MVP complete
3. Add User Story 2 → Compliance reporting visible
4. Add User Story 3 → Documentation complete
5. Polish → Production ready

### Single Developer Strategy

Recommended order for single developer:

1. T001 → T002 → T003 (Setup)
2. T004 → T005 → T006 (Foundational)
3. T007 → T008 → T009 → T010 → T011 → T012 (US1 - MVP)
4. T013 → T014 → T015 → T016 (US2 - Reporting)
5. T017 + T018 + T019 in parallel (US3 - Docs)
6. T020 + T021 in parallel, then T022 → T023 (Polish)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Most tasks modify test/test_spec_fixtures.jl - execute sequentially within story
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Primary file changes: test/test_spec_fixtures.jl, test/runtests.jl, Project.toml, CI.yml
