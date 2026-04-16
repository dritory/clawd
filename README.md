# clawd

Sandboxed Claude Code using bubblewrap. Your system stays read-only,
`$HOME` is writable so dev tools work, and `clawd yolo` skips all
permission prompts.

## Install

```
sudo apt install bubblewrap       # or pacman -S bubblewrap, dnf install bubblewrap
curl -fsSL https://raw.githubusercontent.com/dritory/clawd/main/install.sh | sh
```

From a checkout:

```
CLAWD_INSTALL_LOCAL=./clawd sh install.sh
```

## Usage

```
clawd                # claude with filesystem sandbox
clawd yolo           # sandbox + skip all permission prompts
clawd shell          # sandboxed bash (for debugging)
clawd doctor         # check bwrap and claude work
```

Anything not a reserved subcommand (`yolo`, `shell`, `doctor`, `version`,
`help-clawd`) is forwarded to `claude`. Use `clawd -- args` to escape.

## How it works

clawd wraps claude in a bubblewrap sandbox:

- **`/` is read-only.** Can't modify system files, `/etc`, `/usr`, other
  projects.
- **`$HOME` is writable.** Dev tools work normally: pip, npm, cargo,
  compilers, build systems.
- **`~/.ssh` and `~/.gnupg` are read-only.** Keys can be read (git
  pull works) but not modified or exfiltrated via write.
- **`~/.claude/.credentials.json` is read-only.** Auth token can't be
  overwritten.
- **`/tmp` and `/var/tmp` are tmpfs.** Isolated per session.
- **Process namespace is isolated.** Claude can't see or signal host
  processes.
- **Sensitive env vars are stripped.** Anything matching `AWS_*`,
  `*_SECRET*`, `*_TOKEN*`, `*_KEY*`, `*_PASSWORD*`, `*_CREDENTIAL*`
  is removed from the sandbox environment.

Same OS, same tools, same glibc, same plugins. No Docker, no image.

## Environment

```
CLAWD_ENV             env vars to keep (comma-separated, e.g. "AWS_PROFILE,GITHUB_TOKEN")
CLAWD_ALLOW_WRITE     extra writable paths (colon-separated, e.g. "/data:/mnt/shared")
```

## License

MIT or Apache 2.0.
