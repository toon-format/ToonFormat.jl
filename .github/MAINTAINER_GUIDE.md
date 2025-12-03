# CI/CD Setup Guide

Quick guide to set up GitHub Actions for ToonFormat.jl.

## Step 1: Enable GitHub Actions

GitHub Actions should be enabled by default. Verify in:
- Repository Settings → Actions → General
- Ensure "Allow all actions and reusable workflows" is selected

## Step 2: Set Up Documentation Deployment

### Generate SSH Deploy Key

Run this in Julia:

```julia
using Pkg
Pkg.add("DocumenterTools")

using DocumenterTools
DocumenterTools.genkeys(user="s-celles", repo="ToonFormat.jl")
```

This will generate two keys and provide instructions.

### Add Public Key as Deploy Key

1. Go to: https://github.com/toon-format/ToonFormat.jl/settings/keys
2. Click "Add deploy key"
3. Title: `documenter-key`
4. Key: Paste the **public key** from the output above
5. ✅ Check "Allow write access"
6. Click "Add key"

### Add Private Key as Secret

1. Go to: https://github.com/toon-format/ToonFormat.jl/settings/secrets/actions
2. Click "New repository secret"
3. Name: `DOCUMENTER_KEY`
4. Value: Paste the **private key** from the output above
5. Click "Add secret"

## Step 3: Set Up Code Coverage (Optional)

### Get Codecov Token

1. Go to https://codecov.io
2. Sign in with GitHub
3. Add your repository
4. Copy the upload token

### Add Codecov Secret

1. Go to: https://github.com/toon-format/ToonFormat.jl/settings/secrets/actions
2. Click "New repository secret"
3. Name: `CODECOV_TOKEN`
4. Value: Paste your Codecov token
5. Click "Add secret"

## Step 4: Enable GitHub Pages

1. Go to: https://github.com/toon-format/ToonFormat.jl/settings/pages
2. Source: Deploy from a branch
3. Branch: `gh-pages` / `root`
4. Click "Save"

**Note:** The `gh-pages` branch will be created automatically on the first documentation deployment.

## Step 5: Configure Branch Protection (Recommended)

1. Go to: https://github.com/toon-format/ToonFormat.jl/settings/branches
2. Click "Add rule"
3. Branch name pattern: `main`
4. Enable:
   - ✅ Require status checks to pass before merging
   - Select: `test (1, ubuntu-latest, x64)`
   - Select: `Aqua.jl Quality Assurance`
   - ✅ Require branches to be up to date before merging
5. Click "Create"

## Step 6: Test the Setup

### Trigger CI

Push a commit or create a pull request:
```bash
git commit --allow-empty -m "Test CI"
git push
```

### Check Workflow Status

1. Go to: https://github.com/toon-format/ToonFormat.jl/actions
2. You should see workflows running:
   - ✅ CI
   - ✅ Documentation
   - ✅ Aqua.jl Quality Assurance

### Verify Documentation

After the Documentation workflow completes:
1. Go to: https://s-celles.github.io/ToonFormat.jl/
2. Your documentation should be live!

## Troubleshooting

### Documentation Not Deploying

**Check the workflow logs:**
1. Go to Actions → Documentation → Latest run
2. Look for errors in the "Build and deploy" step

**Common issues:**
- DOCUMENTER_KEY not set correctly
- Public key not added as deploy key with write access
- gh-pages branch doesn't exist (will be created on first run)

**Manual fix:**
```bash
# Create gh-pages branch manually if needed
git checkout --orphan gh-pages
git rm -rf .
echo "Documentation" > index.html
git add index.html
git commit -m "Initialize gh-pages"
git push origin gh-pages
git checkout main
```

### Coverage Not Uploading

**Check:**
- CODECOV_TOKEN is set in secrets
- Codecov repository is activated
- Tests are generating coverage data

**Test locally:**
```bash
julia --project=. --code-coverage=user -e 'using Pkg; Pkg.test()'
```

### Aqua Tests Failing

**Common issues:**
- Missing compat entries in Project.toml
- Stale dependencies
- Type piracy

**Fix:**
```bash
# Update Project.toml with compat entries
# Remove unused dependencies
julia --project=. -e 'using Pkg; Pkg.test()'
```

## Next Steps

Once everything is set up:

1. **Add badges to README** (already done)
2. **Set up CompatHelper** (runs automatically daily)
3. **Register package** in Julia General registry
4. **Enable TagBot** (creates releases automatically)

## Maintenance

### Update Workflows

Workflows are in `.github/workflows/`:
- `CI.yml` - Main test suite
- `Documentation.yml` - Docs building
- `CompatHelper.yml` - Dependency updates
- `TagBot.yml` - Release automation

### Monitor Actions

Check regularly:
- https://github.com/toon-format/ToonFormat.jl/actions
- Review failed workflows
- Update dependencies via CompatHelper PRs

## Resources

- [Documenter.jl Guide](https://documenter.juliadocs.org/stable/)
- [GitHub Actions for Julia](https://github.com/julia-actions)
- [Codecov Documentation](https://docs.codecov.com/)
