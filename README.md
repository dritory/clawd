# krab

[![CI](https://github.com/dritory/krab/actions/workflows/ci.yml/badge.svg)](https://github.com/dritory/krab/actions/workflows/ci.yml)

Sandboxed [Claude Code](https://code.claude.com) using
[bubblewrap](https://github.com/containers/bubblewrap). The system
is read-only, `$HOME` is writable but sensitive dotfiles are protected.
`krab yolo` skips all permission prompts.

## Install

```
sudo apt install bubblewrap       # or pacman -S bubblewrap, dnf install bubblewrap
curl -fsSL https://raw.githubusercontent.com/dritory/krab/main/install.sh | sh
```

From a checkout:

```
KRAB_INSTALL_LOCAL=./krab sh install.sh
```

## Usage

```
krab                # claude with filesystem sandbox
krab yolo           # sandbox + skip all permission prompts
krab shell          # sandboxed bash (for debugging)
krab doctor         # check bwrap and claude work
```

Anything not a reserved subcommand (`yolo`, `shell`, `doctor`, `version`,
`help-krab`) is forwarded to `claude`. Use `krab -- args` to escape.

## How it works

krab wraps claude in a bubblewrap sandbox:

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

Per-project (`.krab` in project root, walks up like `.gitignore`):

```
# .krab
KRAB_ALLOW_WRITE=/data:/mnt/shared
KRAB_ENV=GITHUB_TOKEN
```

Global defaults (`~/.config/krab/config`, same format):

```
KRAB_ENV=AWS_PROFILE,GITHUB_TOKEN
```

Precedence: env var > project `.krab` > global config.

## Contributing

```
git clone git@github.com:dritory/krab.git
cd krab
tests/run-tests.sh            # needs bwrap + shellcheck
KRAB_INSTALL_LOCAL=./krab sh install.sh
```

The test suite covers sandbox isolation (write permissions, symlink
escapes, PID namespace, credential protection, env var filtering),
the installer, and shell completion.

## Disclaimer

krab makes a dangerous tool slightly less dangerous. It does not make
it safe. `krab yolo` lets Claude Code run any command without asking,
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
