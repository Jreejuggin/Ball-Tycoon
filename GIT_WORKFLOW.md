# Git Workflow Cheat Sheet

A quick reference for how we use git day to day. For the full explanation (why, Rojo-specific caveats, troubleshooting), see [CONTRIBUTING.md](CONTRIBUTING.md) sections 6–9. This file is the short version to keep open while you work.

## The golden rule

**Never commit or push directly to `main`.** All work happens on a feature branch, merged in via a reviewed Pull Request.

## Branch naming

`<type>/<short-description>`, e.g.:

- `feature/spectator-mode`
- `bugfix/timer`
- `refactor/round-system`

## Starting new work

```bash
git switch main
git pull
git switch -c feature/your-thing
```

## While you're working

Commit in small, logical chunks as you go — don't wait until everything is "done":

```bash
git status          # see what changed
git add <files>
git commit -m "short description of this chunk"
```

Push whenever you want a backup or to open/update a PR. Pushing WIP commits to **your own branch** is safe — it never affects `main` or your teammates' branches:

```bash
git push -u origin feature/your-thing   # first push
git push                                 # subsequent pushes
```

## A teammate pushed changes — do I pull?

Pulling never destroys your uncommitted edits. Git will refuse to pull if it detects a real conflict rather than silently overwriting anything. Still, don't pull with a messy working directory — commit or stash first:

```bash
git add .
git commit -m "WIP: description"   # ok to commit unfinished work
git pull
```

or, if you don't want a commit yet:

```bash
git stash
git pull
git stash pop
```

**Note:** their push only affects your branch if you merge/pull it in. If you're both on separate feature branches, their push to their branch (or even to `main`) doesn't touch your branch until you explicitly bring it in (see below).

## Keeping your branch up to date with `main`

Do this periodically if your branch is long-lived, or right before opening/merging a PR:

```bash
git switch main
git pull
git switch feature/your-thing
git merge main       # or: git rebase main
```

If Git reports a conflict, it marks the conflicting section in the file with `<<<<<<<` / `=======` / `>>>>>>>`. Read both sides, decide the correct combined result, then:

```bash
git add <resolved files>
git commit
git push
```

Never blindly take "ours" or "theirs" without reading both sides — that can silently discard someone's fix.

## Opening a Pull Request

- One focused change per PR.
- Descriptive title (what changed, not the branch name).
- Description: what changed, why, and anything a reviewer should pay attention to (e.g. touches `default.project.json`, modifies a `.rbxm`).
- Say what you tested in Studio before opening it.
- Merge once approved, then delete the branch and update local `main`:

```bash
git switch main
git pull
git branch -d feature/your-thing
```

## Quick command reference

| Command | What it does |
|---|---|
| `git status` | What's modified/staged/untracked |
| `git pull` | Fetch + merge latest remote changes into current branch |
| `git switch main` | Switch to `main` |
| `git switch -c feature/name` | Create and switch to a new branch |
| `git add <files>` | Stage changes |
| `git commit -m "message"` | Commit staged changes |
| `git push` | Upload commits to GitHub |
| `git stash` / `git stash pop` | Temporarily shelve / restore uncommitted changes |
| `git log` | Commit history |
| `git diff` | Unstaged changes since last commit |

## Accidentally committed to `main`?

Don't push. Rescue your work onto a branch, then reset `main`:

```bash
git switch -c feature/rescue-my-work
git switch main
git reset --hard origin/main
```

See [CONTRIBUTING.md §14](CONTRIBUTING.md#14-troubleshooting) if you've already pushed to `main` — stop and coordinate with the team before doing anything further.
