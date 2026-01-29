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
