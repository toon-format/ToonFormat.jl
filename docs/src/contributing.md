# Contributing

Thank you for your interest in contributing to TokenOrientedObjectNotation.jl!

## Getting Started

### Development Setup

1. Clone the repository:
```bash
git clone https://github.com/s-celles/TokenOrientedObjectNotation.jl.git
cd TokenOrientedObjectNotation.jl
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
TokenOrientedObjectNotation.jl/
├── src/
│   ├── TokenOrientedObjectNotation.jl              # Main module
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
- Aim for high test coverage
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

TokenOrientedObjectNotation.jl follows the [TOON Specification v2.0](https://github.com/toon-format/spec/blob/main/SPEC.md).

When making changes:

1. **Check the spec** - Ensure changes align with specification
2. **Add compliance tests** - Test against spec requirements
3. **Update validation reports** - Document compliance status
4. **Maintain 100% compliance** - All spec requirements must pass

### Running Compliance Tests

```julia
# Run all tests
using Pkg
Pkg.test()

# Run specific test file
include("test/test_compliance_requirements.jl")
```

## Areas for Contribution

### High Priority

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

## Getting Help

- **Questions:** Open a GitHub issue with the "question" label
- **Discussions:** Use GitHub Discussions for general topics
- **Bugs:** Open a GitHub issue with the "bug" label
- **Features:** Open a GitHub issue with the "enhancement" label

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Focus on constructive feedback
- Assume good intentions

## License

By contributing to TokenOrientedObjectNotation.jl, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes
- Documentation credits

Thank you for contributing to TokenOrientedObjectNotation.jl!
