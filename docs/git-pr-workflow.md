# Make an Attendance Pull Request

These commands use PowerShell. The worktree path below is specific to this
computer. A worktree is a separate checkout of the same Git repository.

## 1. Start on the branch that has the work

```powershell
Set-Location 'C:\Users\hamda\.codex\worktrees\attendance-public-startup\Attendance-app'
git status --short --branch
git switch -c codex/attendance-ui-refresh
```

- `Set-Location` changes the terminal's working folder. It does not change any files.
- `git status --short --branch` shows the current branch and which files are
  modified, staged, or new. This PR started from `codex/combined-attendance-test`,
  where the app and website work already existed.
- `git switch -c` creates the named branch at the current commit and switches to it.
  Starting from that same commit keeps the existing history and uncommitted
  files in place. The edits are not saved to Git until you commit them. Run
  `-c` only once; to return later, use `git switch codex/attendance-ui-refresh`.

## 2. Stage, inspect, and commit

```powershell
git add -- attendance site .github/workflows/attendance-site.yml docs/git-pr-workflow.md ':(exclude,glob)attendance/test/failures/**'
git diff --cached --name-status
git diff --cached --check
```

- `git add` stages a snapshot of just the named paths. The `--` ends option
  parsing; everything after it is a path or a path pattern. The quoted
  `:(exclude,glob)...` pattern leaves generated test-failure images out.
  The website and its Pages workflow are outside `attendance/`, so they
  are named explicitly.
- `git diff --cached --name-status` lists what the next commit would add
  (`A`), modify (`M`), or delete (`D`). Use `git diff --cached` to read the
  actual staged changes. Check for unintended deletions and never include
  `.env` files, signing keys, APKs, or private SOAP code.
- `git diff --cached --check` flags whitespace errors and leftover merge
  conflict markers. It is not a substitute for reviewing the staged content.

If a file was staged by mistake, replace the example path below with the real
path. This unstages the file but leaves your copy on disk:

```powershell
git restore --staged -- 'path/to/file'
```

Once the staging list looks right:

```powershell
git commit -m "Polish Attendance and add a public showcase site"
```

`git commit` saves the staged snapshot on the current branch. `-m` sets the
commit message. This is still local; neither the branch nor the files have
been sent to GitHub yet.

## 3. Compare, push, and open the draft

```powershell
git fetch origin
git log --oneline origin/main..HEAD
git diff --stat origin/main...HEAD
```

- `git fetch origin` refreshes your local record of GitHub's branches, including
  `origin/main`. It does not merge anything or edit your project files.
- `git log --oneline origin/main..HEAD` lists commits on your branch that
  GitHub's `main` does not reach. `HEAD` means the commit currently checked out.
- `git diff --stat origin/main...HEAD` compares your branch with the shared
  starting commit. It shows the size and filenames of the changes the PR
  is proposing. Remove `--stat` to inspect the full patch.

Read that output before publishing. Then run:

```powershell
git push -u origin codex/attendance-ui-refresh
gh pr create --base main --head codex/attendance-ui-refresh --draft
```

- `git push` publishes the named branch to GitHub, not to `main`. `-u`
  sets that remote branch as the upstream so future updates can use
  plain `git push`.
- [`gh pr create`](https://cli.github.com/manual/gh_pr_create) opens a PR from
  `--head` into `--base`. `--draft` marks it as not ready for review yet.
  The command can ask for a title and description. If GitHub CLI asks for
  authentication, run `gh auth login`.

Opening a PR does not merge it. It may run configured checks. Publishing
the website is a separate manual action described in the
[website guide](../site/README.md).

## 4. Update the same PR

Make your edits on the same branch, stage the specific files, commit, and
run `git push`. GitHub updates the existing PR automatically. Use
`gh pr view --web` to open the PR for the current branch in your browser.
