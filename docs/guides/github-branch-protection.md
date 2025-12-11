# GitHub Branch Protection Setup

## Why Branch Protection?

Protects the `main` branch from accidental changes and ensures all production deployments are reviewed.

## Recommended Settings for `main` Branch

Navigate to: **Settings → Branches → Add branch protection rule**

### Branch name pattern
```
main
```

### Protection Rules

#### ✅ Require a pull request before merging
- [x] Require approvals: **1** (or more for team projects)
- [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require review from Code Owners (optional - if you add CODEOWNERS file)

#### ✅ Require status checks to pass before merging
- [ ] Require branches to be up to date before merging (optional - can be strict)
- Status checks to require:
  - None for now (could add terraform plan validation later)

#### ✅ Require conversation resolution before merging
- [x] All conversations on code must be resolved

#### ✅ Require signed commits (optional but recommended)
- [x] Require signed commits for additional security

#### ✅ Include administrators
- [x] Apply rules to administrators too (best practice even for solo projects)

#### ⚠️ Do NOT enable (for solo projects):
- [ ] Require deployments to succeed - not needed for infrastructure repo
- [ ] Lock branch - too restrictive
- [ ] Restrict pushes - not needed for solo work

## What This Means for Your Workflows

### Lambda Deployment (`lambda-certbot-deploy.yml`)
- ✅ Triggers **ONLY** when code is merged to `main` via PR
- ✅ Feature branches and PRs will NOT deploy to production
- ✅ `workflow_dispatch` still available for manual emergency deployments

### K8s Infrastructure (`k8s-infra-pipeline.yml`)
- ✅ Manual `workflow_dispatch` only - no automatic deployments
- ✅ You control when `tofu plan` or `tofu apply` runs
- ✅ Good for infrastructure changes that need human judgment

## Workflow After Branch Protection

1. Create feature branch: `git checkout -b feature/my-change`
2. Make changes and commit
3. Push to GitHub: `git push origin feature/my-change`
4. Create Pull Request on GitHub
5. Review changes (even if it's just you!)
6. **Merge to main** → Lambda deployment auto-triggers
7. Infrastructure changes still require manual workflow trigger

## Testing This Setup

After enabling branch protection, try this:

```bash
# This should be blocked:
git checkout main
echo "test" > test.txt
git add test.txt
git commit -m "Direct commit to main"
git push  # ❌ Should fail with protection error

# This is the correct flow:
git checkout -b test/branch-protection
echo "test" > test.txt
git add test.txt
git commit -m "Test branch protection"
git push origin test/branch-protection
# Then create PR on GitHub and merge
```

## Future Enhancements

Once you have more automation:
- Add required status check for `tofu plan` validation
- Add CODEOWNERS file for automatic review assignments
- Add semantic commit message validation
- Add automated testing before merge
