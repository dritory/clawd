# clawd

[![CI](https://github.com/dritory/clawd/actions/workflows/ci.yml/badge.svg)](https://github.com/dritory/clawd/actions/workflows/ci.yml)

Sandboxed [Claude Code](https://code.claude.com) using
[bubblewrap](https://github.com/containers/bubblewrap). The system
is read-only, `$HOME` is writable but sensitive dotfiles are protected.
`clawd yolo` skips all permission prompts.

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

- **`/` is read-only.** Can't modify system files, `/etc`, `/usr`.
- **`$HOME` is writable.** Dev tools, package managers, and claude's
  own config all work without hitting walls.
- **`$PWD` is writable.** The project you're working in.
- **Sensitive dotfiles are read-only.** `~/.ssh`, `~/.gnupg`,
  `~/.bashrc`, `~/.profile`, `~/.zshrc`, `~/.bash_history`. Keys and
  shell rc can be read but not modified.
- **`/tmp` and `/var/tmp` are writable.** Shared with host (already
  world-writable and ephemeral, so no security benefit to isolating).
- **Process namespace is isolated.** Claude can't see or signal host
  processes.
- **Sensitive env vars are stripped.** Anything matching `AWS_*`,
  `*_SECRET*`, `*_TOKEN*`, `*_KEY*`, `*_PASSWORD*`, `*_CREDENTIAL*`
  is removed from the sandbox environment.

Same OS, same tools, same glibc, same plugins. No Docker, no image.

## Configuration

Per-project (`.clawd` in project root, walks up like `.gitignore`):

```
# .clawd
CLAWD_ALLOW_WRITE=/data:/mnt/shared
CLAWD_ENV=GITHUB_TOKEN
```

Global defaults (`~/.config/clawd/config`, same format):

```
CLAWD_ENV=AWS_PROFILE,GITHUB_TOKEN
```

Precedence: env var > project `.clawd` > global config.

## Contributing

```
git clone git@github.com:dritory/clawd.git
cd clawd
tests/run-tests.sh            # needs bwrap + shellcheck
CLAWD_INSTALL_LOCAL=./clawd sh install.sh
```

The test suite covers sandbox isolation (write permissions, symlink
escapes, PID namespace, credential protection, env var filtering),
the installer, and shell completion.

## Disclaimer

clawd makes a dangerous tool slightly less dangerous. It does not make
it safe. `clawd yolo` lets Claude Code run any command without asking,
and the sandbox doesn't restrict network access, doesn't isolate
`$HOME`, and can't stop a sufficiently determined model from doing
something destructive within those bounds (`rm -rf` your project,
exfiltrate via the network, push to git, etc.).

Use at your own risk. The authors make no warranty and accept no
liability for damage to your files, data, infrastructure, or
relationships. Read the [LICENSE](LICENSE-MIT.md) for the legal
version of this paragraph.

## License

Dual-licensed under [MIT](LICENSE-MIT.md) or
[Apache 2.0](LICENSE-APACHE.md), at your option.
