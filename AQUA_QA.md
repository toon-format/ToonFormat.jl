# Aqua.jl Quality Assurance

This project uses [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl) for automated quality assurance testing.

## What is Aqua.jl?

Aqua.jl is a comprehensive quality assurance tool for Julia packages that automatically checks for common issues and best practices violations.

## Tests Performed

The following quality checks are automatically run as part of the test suite:

### 1. Method Ambiguities
Detects method ambiguities that could lead to unexpected dispatch behavior.

### 2. Unbound Type Parameters
Ensures no functions have unbound type parameters that could cause performance issues.

### 3. Undefined Exports
Verifies that all exported names are actually defined in the module.

### 4. Project Structure
Checks that `Project.toml` and test dependencies are properly configured.

### 5. Stale Dependencies
Identifies dependencies listed in `Project.toml` but not actually used in the code.

### 6. Dependency Compatibility
Ensures all dependencies have proper `[compat]` entries for version management.

### 7. Type Piracy
Detects type piracy (extending methods on types you don't own), which is considered bad practice.

### 8. Persistent Tasks
Checks for tasks that might not be cleaned up properly.

## Running Aqua Tests

Aqua tests run automatically as part of the standard test suite:

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or run only the Aqua tests:

```bash
julia --project=. -e 'using Pkg; Pkg.test("TOON"; test_args=["aqua"])'
```

## Configuration

The Aqua.jl configuration is in `test/test_aqua.jl`. All checks are currently enabled. If you need to disable specific checks, modify the configuration in that file.

## Benefits

- Catches common quality issues early
- Enforces Julia package best practices
- Improves code maintainability
- Helps prevent breaking changes
- Ensures proper dependency management
