- never put claude in code commits
- all my dotfiles should be idempotent
- never mention claude in git commits
- let's review commits to github for secrets and security issues
- always create a feature branch and PR instead of committing directly to main
- I use vi as an editor, not nano
- suggest faster ways, always give a few options

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
- warn me before committing anything with secrets

## Shell Scripts
- always include error handling (`set -e`)
- prefer readable code over clever one-liners
- add comments explaining why, not what
- make scripts idempotent when possible

## macOS/Dotfiles
- use brew bundle for package management (Brewfile)
- symlink configs, never copy them
- organize Brewfile by category (CLI tools, apps, etc)
- document setup steps in README files
- don't use git amend
