# Workflow Discipline (Until Branch Protection is Active)

## Why This Matters

Branch protection requires GitHub Pro or a public repository. Until this repo is public, we rely on manual discipline to maintain the PR workflow.

## The Golden Rule

**NEVER commit directly to `main`**

## Correct Workflow

### 1. Create Feature Branch
```bash
git checkout main
git pull
git checkout -b feature/my-change
```

### 2. Make Changes and Commit
```bash
# Make your changes
git add .
git commit -m "descriptive message"
git push origin feature/my-change
```

### 3. Create PR
```bash
gh pr create --title "Your change" --body "Description"
```

### 4. Review (even if it's just you!)
```bash
# View the PR
gh pr view

# Look at the diff
gh pr diff

# Check CI status
gh pr checks
```

### 5. Merge via GitHub
```bash
gh pr merge --squash
```

### 6. Update Local Main
```bash
git checkout main
git pull
git branch -d feature/my-change
```

## What This Prevents

- ❌ Direct commits to main (should fail once protected)
- ❌ Bypassing CI/CD workflows
- ❌ Skipping Lambda deployments
- ❌ Missing the review step

## What This Enables

- ✅ Lambda auto-deploys only from main
- ✅ Clean git history
- ✅ CI/CD validation on every change
- ✅ Audit trail of all changes

## Quick Check: Am I on Main?

```bash
git branch --show-current
```

If output is `main` → **STOP!** Create a feature branch first.

## Oops, I Committed to Main!

If you haven't pushed yet:

```bash
# Move your commit to a new branch
git branch feature/my-fix
git reset --hard origin/main
git checkout feature/my-fix
# Now create a PR
```

## Once Repo is Public

Branch protection will be automatically enabled with:
- ✅ Required PR before merge
- ✅ Required conversation resolution
- ✅ Dismiss stale reviews on push
- ✅ No force pushes
- ✅ Linear history

Until then, **discipline > automation**!
