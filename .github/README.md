# GitHub Actions CI/CD

This directory contains GitHub Actions workflows for continuous integration, testing, and documentation deployment.

## Workflows

### CI.yml - Continuous Integration

**Triggers:**
- Push to `main` or `master` branches
- Pull requests
- Manual workflow dispatch

**Jobs:**

#### Test Matrix
Tests the package across multiple Julia versions and operating systems:
- **Julia versions:** 1.6 (minimum), 1.10, 1.12, latest stable, nightly
- **Operating systems:** Ubuntu, macOS, Windows
- **Architecture:** x64

**Steps:**
1. Checkout code
2. Setup Julia environment
3. Cache Julia packages for faster builds
4. Build package
5. Run test suite
6. Generate coverage report
7. Upload to Codecov

#### Aqua Quality Assurance
Runs Aqua.jl quality checks separately:
- Method ambiguities
- Unbound type parameters
- Undefined exports
- Project structure validation
- Stale dependencies
- Dependency compatibility
- Type piracy detection
- Persistent tasks

### Documentation.yml - Documentation Building

**Triggers:**
- Push to `main` or `master` branches
- Tags (for versioned docs)
- Pull requests

**Steps:**
1. Checkout code
2. Setup Julia
3. Install documentation dependencies
4. Build documentation with Documenter.jl
5. Deploy to GitHub Pages (on main branch)

**Permissions:**
- `contents: write` - Deploy to gh-pages branch
- `statuses: write` - Update commit status

### CompatHelper.yml - Dependency Updates

**Triggers:**
- Daily at midnight UTC
- Manual workflow dispatch

**Purpose:**
Automatically creates pull requests when new versions of dependencies are available in the Julia registry.

**Permissions:**
- `contents: write` - Create branches
- `pull-requests: write` - Create PRs

### TagBot.yml - Release Automation

**Triggers:**
- Issue comments (from JuliaRegistrator)
- Manual workflow dispatch

**Purpose:**
Automatically creates GitHub releases when new versions are registered in the Julia General registry.

**Permissions:**
- Full repository access for creating releases and tags

## Setup Requirements

### Secrets

The following secrets should be configured in your repository settings:

#### Required for Documentation Deployment

**DOCUMENTER_KEY** - SSH deploy key for GitHub Pages
```bash
# Generate the key
julia -e 'using DocumenterTools; DocumenterTools.genkeys(user="s-celles", repo="TOON.jl")'

# Follow the instructions to:
# 1. Add the public key as a deploy key in repo settings (with write access)
# 2. Add the private key as a secret named DOCUMENTER_KEY
```

#### Optional for Coverage

**CODECOV_TOKEN** - Token for uploading coverage reports
- Get from https://codecov.io after adding your repository
- Add as repository secret named `CODECOV_TOKEN`

### Branch Protection

Recommended branch protection rules for `main`:

1. **Require status checks to pass:**
   - `test (1.6, ubuntu-latest, x64)`
   - `test (1, ubuntu-latest, x64)`
   - `Aqua.jl Quality Assurance`

2. **Require pull request reviews:** 1 approval

3. **Require linear history:** Optional

4. **Include administrators:** Recommended

## Local Testing

### Run tests locally
```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Run only Aqua tests
```bash
julia --project=. -e 'ENV["TEST_GROUP"] = "aqua"; using Pkg; Pkg.test()'
```

### Build documentation locally
```bash
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()'
julia --project=docs docs/make.jl
```

### Check for outdated dependencies
```bash
julia --project=. -e 'using Pkg; Pkg.update()'
```

## Troubleshooting

### CI Failures

**Test failures on specific Julia versions:**
- Check if the failure is version-specific
- Review Julia version compatibility in Project.toml
- Consider if it's a known issue in that Julia version

**Documentation build failures:**
- Ensure all docstrings are valid
- Check for broken cross-references
- Verify all examples in docs run correctly

**Aqua failures:**
- Review the specific Aqua check that failed
- Common issues:
  - Missing compat entries
  - Stale dependencies
  - Type piracy
  - Method ambiguities

### Coverage Issues

**Low coverage reports:**
- Ensure tests are actually running
- Check that `julia-processcoverage` step completes
- Verify Codecov token is set correctly

**Coverage not uploading:**
- Check Codecov token in repository secrets
- Verify the `codecov-action` step runs
- Check Codecov dashboard for errors

### Documentation Deployment

**Docs not deploying:**
- Verify DOCUMENTER_KEY is set correctly
- Check that gh-pages branch exists
- Ensure GitHub Pages is enabled in repository settings
- Review Documenter.jl logs for errors

**Broken links in docs:**
- Run `julia --project=docs docs/make.jl` locally
- Check for 404 errors in the output
- Verify all referenced files exist

## Maintenance

### Updating Workflows

When updating workflow files:
1. Test changes in a fork or feature branch first
2. Review GitHub Actions documentation for syntax changes
3. Check for deprecation warnings in workflow runs
4. Update this README if behavior changes

### Dependency Updates

CompatHelper will automatically create PRs for dependency updates. Review these PRs by:
1. Checking the changelog of the updated package
2. Running tests locally with the new version
3. Verifying no breaking changes affect your code

### Julia Version Support

When dropping support for old Julia versions:
1. Update `julia` compat in Project.toml
2. Remove the version from CI.yml matrix
3. Document the change in release notes
4. Consider deprecation period for major changes

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Julia Actions](https://github.com/julia-actions)
- [Documenter.jl](https://documenter.juliadocs.org/)
- [Aqua.jl](https://github.com/JuliaTesting/Aqua.jl)
- [CompatHelper.jl](https://github.com/JuliaRegistries/CompatHelper.jl)
- [TagBot](https://github.com/JuliaRegistries/TagBot)
