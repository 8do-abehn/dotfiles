- all my dotfiles should be idempotent
- let's review commits to github for secrets and security issues
- I use vi as an editor, not nano
- suggest faster ways, always give a few options

## Git
- always create a feature branch and PR instead of committing directly to main
- don't use git amend - prefer separate commits and squash merge on PRs
- never mention claude in commit messages or PR descriptions
- don't include Co-Authored-By lines in commits

## Ansible (homelab/beginner-friendly)
- use `no_log: true` on template tasks that render vault secrets to prevent password leaks in `--check --diff` output
- test playbooks with `--check --diff` before running
- use `ansible-lint` to catch issues early
- keep playbooks simple and readable
- use roles when I repeat the same tasks across hosts
- comment inventory files so I remember what each host does
- skip tags and handlers until I actually need them
- prefer simple task restarts over complex handler chains

## Secrets Management
- prefer Bitwarden CLI (`bw`) over macOS Keychain for cross-platform
- use ansible-vault for sensitive files in repos
- never hardcode API keys or passwords
- warn before committing PII or secrets to repos or anything published publicly

## Shell Scripts
- always include error handling (`set -euo pipefail`)
- prefer readable code over clever one-liners
- add comments explaining why, not what
- make scripts idempotent when possible
- exclude zsh files from shellcheck (different syntax)

## macOS/Dotfiles
- use brew bundle for package management (Brewfile)
- symlink configs, never copy them
- organize Brewfile by category (CLI tools, apps, etc)
- document setup steps in README files
- run `./status.sh` to check sync after pulling on a new machine

## UI Reports
- format job search entries in this column order: Date Applied, Company Name, Company Website, Position Title

## PR Strategy
- never chain PRs where each targets the previous feature branch — if the base branch gets deleted on merge, all downstream PRs auto-close
- target all PRs to main and rebase as needed, or merge chains bottom-up without deleting branches until all are merged
- squash merge + chained branches = conflict hell — the rewritten commit breaks downstream rebases
- when stuck with orphaned chained PRs, create one consolidated PR from the most advanced branch

## Session Workflow
- create GitHub issues for deferred work as you encounter it, not in a batch at the end — context drifts fast
- take breaks to make notes and update issues so progress isn't lost if a session ends
- track token usage on large projects for cost awareness

## Lab Work
- follow lesson plan checkpoints - verification steps catch config issues early
- test DNS resolution (internal AND external) before moving on
- move GitHub issues to "in progress" when starting each phase/task so project board shows current work

## Gitleaks
- `gitleaks detect` scans full history; `gitleaks protect --staged` scans staged changes only
- baseline files (`.gitleaksbaseline`) contain secret snippets — add to allowlist in `.gitleaks.toml`
- portable pre-commit hooks go in `.githooks/` with `git config core.hooksPath .githooks`

## Git History Rewriting
- git-filter-repo is preferred over BFG — already installed via Homebrew
- filter-repo removes origin remote and leaves `.git/filter-repo/already_ran` marker
- after filter-repo: re-add remote, force push, re-create tags, reset upstream tracking
