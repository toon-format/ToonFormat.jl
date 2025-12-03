# Contributing

Thank you for your interest in contributing to ToonFormat.jl!

## Getting Started

### Development Setup

1. Clone the repository:
```bash
git clone https://github.com/toon-format/ToonFormat.jl.git
cd ToonFormat.jl
```

2. Install dependencies:
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
```

3. Run tests:
```julia
Pkg.test()
```

### Project Structure

```
ToonFormat.jl/
├── src/
│   ├── ToonFormat.jl  # Main module
│   ├── constants.jl          # Constants and delimiters
│   ├── types.jl              # Type definitions
│   ├── string_utils.jl       # String utilities
│   ├── normalize.jl          # Value normalization
│   ├── primitives.jl         # Primitive encoding
│   ├── encoder.jl            # Main encoder
│   ├── scanner.jl            # Line scanner
│   └── decoder.jl            # Main decoder
├── test/
│   ├── runtests.jl           # Main test file
│   ├── test_encoder.jl       # Encoder tests
│   ├── test_decoder.jl       # Decoder tests
│   ├── test_compliance_*.jl  # Compliance tests
│   └── ...                   # Other test files
├── docs/
│   ├── make.jl               # Documentation builder
│   └── src/                  # Documentation source
├── Project.toml              # Package metadata
└── README.md                 # User documentation
```

## How to Contribute

### Reporting Issues

If you find a bug or have a feature request:

1. Check if the issue already exists
2. Create a new issue with:
   - Clear description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Julia version and OS
   - Minimal code example

### Submitting Pull Requests

1. Fork the repository
2. Create a feature branch:
```bash
git checkout -b feature/your-feature-name
```

3. Make your changes:
   - Write clear, documented code
   - Add tests for new functionality
   - Update documentation as needed
   - Follow existing code style

4. Run tests:
```julia
using Pkg
Pkg.test()
```

5. Commit your changes:
```bash
git commit -m "Add feature: description"
```

6. Push to your fork:
```bash
git push origin feature/your-feature-name
```

7. Create a pull request with:
   - Clear description of changes
   - Reference to related issues
   - Test results

## Pull Request Guidelines

To ensure smooth code reviews and merges, please follow these guidelines:

- **Title**: Use a clear, descriptive title that summarizes your changes
- **Description**: Explain what changes you made and why they were necessary
- **Tests**: Include tests for your changes - all new features must have test coverage
- **Documentation**: Update README or documentation if your changes affect the public API
- **Commits**: Use clear commit messages following [Conventional Commits](https://www.conventionalcommits.org/) format when possible

Your pull request should include:
- Clear description of what changed and motivation
- Reference to related issues (e.g., "Fixes #42" or "Addresses #123")
- Test results showing all tests pass
- Screenshots or examples if the change affects output

We aim to review pull requests within a few days. Be prepared to address feedback and make adjustments.

## Development Guidelines

### Code Style

- Follow Julia style conventions
- Use descriptive variable names
- Add docstrings for public functions
- Keep functions focused and small
- Use type annotations where helpful

Example:
```julia
"""
    encode_primitive(value, delimiter::Delimiter) -> String

Encode a primitive value to TOON format.

# Arguments
- `value`: The primitive value to encode
- `delimiter`: The active delimiter for quoting decisions

# Returns
- String representation in TOON format
"""
function encode_primitive(value, delimiter::Delimiter)
    # Implementation...
end
```

### Testing

- Write tests for all new functionality
- Aim for high test coverage (target: 85%+)
- Test edge cases and error conditions
- Use descriptive test names

Example:
```julia
@testset "Primitive Encoding" begin
    @testset "Numbers" begin
        @test TOON.encode(42) == "42"
        @test TOON.encode(3.14) == "3.14"
        @test TOON.encode(-0.0) == "0"
    end

    @testset "Strings" begin
        @test TOON.encode("hello") == "hello"
        @test TOON.encode("hello world") == "\"hello world\""
        @test TOON.encode("") == "\"\""
    end
end
```

### Quality Assurance with Aqua.jl

This project uses [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl) for automated quality assurance testing to maintain high code quality standards.

**What Aqua.jl checks:**
- Method ambiguities - Detects ambiguous method dispatch that could cause runtime issues
- Unbound type parameters - Finds potential performance issues in type definitions
- Undefined exports - Verifies all exported symbols are actually defined
- Project structure - Checks Project.toml configuration and dependencies
- Stale dependencies - Identifies unused dependencies in Project.toml
- Dependency compatibility - Ensures proper [compat] entries for all dependencies
- Type piracy - Detects extending methods on types you don't own (anti-pattern)
- Persistent tasks - Checks for proper task cleanup to avoid resource leaks

**Running Aqua tests:**

Aqua tests run automatically with the test suite:
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

Or run only Aqua tests:
```bash
julia --project=. test/test_aqua.jl
```

All pull requests must pass Aqua.jl checks before merging. If Aqua reports issues, address them or document why they're acceptable in the specific case.

### For Maintainers

Repository maintainers and administrators should refer to [.github/MAINTAINER_GUIDE.md](.github/MAINTAINER_GUIDE.md) for:
- CI/CD setup and configuration
- Documentation deployment with Documenter.jl
- GitHub Pages and Codecov setup
- Release process and TagBot configuration
- Infrastructure troubleshooting

### Documentation

- Update documentation for new features
- Add examples to demonstrate usage
- Keep API reference up to date
- Update README if needed

### Commit Messages

Use clear, descriptive commit messages:

- **Good:** "Add support for custom delimiters in tabular arrays"
- **Good:** "Fix: Handle empty strings in key folding"
- **Bad:** "Update code"
- **Bad:** "Fix bug"

Format:
```
Type: Brief description

Detailed explanation if needed.

Fixes #123
```

Types: `Add`, `Fix`, `Update`, `Remove`, `Refactor`, `Docs`, `Test`

## Specification Compliance

ToonFormat.jl follows the [TOON Specification v2.0](https://github.com/toon-format/spec/blob/main/SPEC.md).

When making changes:

1. **Check the spec** - Ensure changes align with specification
2. **Add compliance tests** - Test against spec requirements
3. **Run fixture tests** - Verify against official test fixtures
4. **Document compliance status** - Update known issues if needed

### Running Compliance Tests

```julia
# Run all tests including fixture tests
using Pkg
Pkg.test()

# Run only fixture tests
include("test/test_spec_fixtures.jl")

# Run specific test file
include("test/test_compliance_requirements.jl")
```

**Current Status:** 87.6% fixture compliance (298/340 passing)
See [REPOSITORY_CLEANUP_ISSUES.md](./REPOSITORY_CLEANUP_ISSUES.md) for known issues and priorities.

## Areas for Contribution

### High Priority

- **Spec compliance fixes** - See [REPOSITORY_CLEANUP_ISSUES.md](./REPOSITORY_CLEANUP_ISSUES.md) for P0-P3 issues
- Performance optimizations
- Better error messages
- Additional examples
- Documentation improvements

### Medium Priority

- Integration with other packages (DataFrames, CSV, etc.)
- Streaming support for large files
- Benchmarking suite
- Additional utility functions

### Low Priority

- Pretty-printing utilities
- Schema validation (when spec adds support)
- Additional delimiter types (if spec adds them)

## Communication

We welcome questions, discussions, and contributions!

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion about TOON and this implementation
- **Pull Requests**: For code reviews and implementation discussion

When communicating:
- Be respectful and inclusive
- Provide context and examples
- Search existing issues/discussions before creating new ones
- Use appropriate labels to categorize issues

## Maintainers

This is a collaborative project. Current maintainers:

- Sébastien Celles – [@s-celles](https://github.com/s-celles)

All maintainers have equal and consensual decision-making power. For major architectural decisions, please open a discussion issue first to gather feedback from the community.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions
- Follow the Julia community standards

## License

By contributing to ToonFormat.jl, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes (CHANGELOG.md)
- Documentation credits

Thank you for contributing to ToonFormat.jl!
