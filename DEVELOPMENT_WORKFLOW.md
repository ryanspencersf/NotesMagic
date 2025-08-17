# NotesMagic Development Workflow

## 🛡️ Branch Protection Rules (GitHub Settings)

### Main Branch Protection
- **Require pull request reviews before merging**: ✅ Enabled
- **Require status checks to pass before merging**: ✅ Enabled
- **Require branches to be up to date before merging**: ✅ Enabled
- **Restrict pushes that create files**: ✅ Enabled
- **Require linear history**: ✅ Enabled
- **Require signed commits**: Optional (recommended for production)

### Merge Options
- **Allow squash merging**: ✅ Enabled
- **Allow rebase merging**: ❌ Disabled
- **Allow merge commits**: ❌ Disabled

## 🌿 Branch Strategy

### Protected Branches (Never Develop On)
- `main` - Production-ready code only
- `stable/baseline-2025-08-16` - Permanent safety net, never touch

### Development Branches
- **One branch per bullet point** in your "Build To-dos" canvas
- **Naming convention**: `feature/description` or `fix/description`
- **Example**: `feature/editor-autosave`, `fix/trash-purge-timing`

## 📋 Pull Request Process

### Before Creating PR
1. **Create feature branch** from `main`
2. **Pin `.cursorrules`** in PR description: "touch only these files"
3. **Scope limitation**: Only modify specified files
4. **Test compilation**: Ensure project builds without errors

### PR Description Template
```markdown
## Scope
- **Files to modify**: [List specific files only]
- **Files to NOT touch**: [List files that should remain unchanged]

## Changes
- [ ] Feature/fix description
- [ ] Architecture compliance
- [ ] SwiftUI best practices
- [ ] Performance considerations

## Testing
- [ ] Compiles without errors
- [ ] Maintains existing functionality
- [ ] No regression in other components

## Cursor Rules
See attached `.cursorrules` file
```

## 🚨 Safety Measures

### If Cursor Goes Off Rails
1. **STOP** development immediately
2. **Discard all changes** to the branch
3. **Re-ask with smaller scope** or
4. **Start fresh branch** from `main`

### Recovery Commands
```bash
# Discard all changes
git reset --hard HEAD
git clean -fd

# Start fresh from main
git checkout main
git pull origin main
git checkout -b feature/new-attempt
```

## 🔄 Daily Workflow

### Starting Work
```bash
git checkout main
git pull origin main
git checkout -b feature/your-task
```

### During Development
- **Small, focused commits** per logical change
- **Frequent compilation checks**
- **Stay within `.cursorrules` scope**

### Finishing Work
```bash
git add .
git commit -m "feature: descriptive message"
git push origin feature/your-task
# Create PR with .cursorrules pinned
```

## 📁 File Organization

### Package Boundaries
- **Domain**: Protocols and models only
- **Data**: Implementation of Domain protocols
- **Features**: UI and business logic
- **UIComponents**: Reusable UI elements
- **MLKit**: AI/ML functionality

### Never Touch
- `.xcodeproj` files directly
- Build artifacts (`.build/`, `DerivedData/`)
- User-specific files (`xcuserdata/`)

## 🎯 Quality Gates

### Before PR Creation
- [ ] Code compiles without errors
- [ ] Follows existing patterns
- [ ] Maintains architecture boundaries
- [ ] Includes appropriate tests
- [ ] Performance budgets met

### PR Review Checklist
- [ ] Scope limited to specified files
- [ ] Architecture compliance
- [ ] SwiftUI best practices
- [ ] No breaking changes
- [ ] Documentation updated

## 🚀 Release Process

### Stable Baseline Creation
1. **Feature freeze** on main
2. **Create new baseline branch**: `stable/baseline-YYYY-MM-DD`
3. **Tag release**: `v1.0.0`
4. **Merge to main** after testing

### Hotfix Process
1. **Create hotfix branch** from stable baseline
2. **Minimal scope** changes only
3. **Test thoroughly** before merging
4. **Update baseline** with hotfix

---

**Remember**: Main is sacred. Every change goes through PR review. Stay within scope. Keep branches small and focused.
