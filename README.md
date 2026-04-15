# clawd

Run Claude Code in a Docker container, using your existing host login.

## Install

```
curl -fsSL https://raw.githubusercontent.com/dritory/clawd/main/install.sh | sh
```

Requires docker. The container image is built the first time you run `clawd`.

Local checkout:

```
CLAWD_INSTALL_LOCAL=./clawd sh install.sh
```

Updating:

```
clawd self-update     # refresh the wrapper script
clawd update          # rebuild the image (newer Claude Code)
```

Bash completion is installed alongside the wrapper. For zsh, put
`autoload -U bashcompinit && bashcompinit` in `~/.zshrc` before sourcing the
completion file.

## Usage

```
clawd                # claude in $PWD
clawd -p "hello"     # one-shot prompt; pipes work
clawd shell          # bash inside the container
clawd yolo           # --dangerously-skip-permissions, this invocation only
clawd version
```

Reserved subcommands: `build`, `update`, `self-update`, `shell`, `yolo`,
`version`, `help-clawd`. Anything else is passed to `claude`. Use
`clawd -- args` if something collides.

`clawd yolo` runs Claude Code with permission prompts disabled for that one
invocation. It's opt-in per-call, not persistent. The container sandbox is
the only thing protecting your host if Claude does something unexpected, so
use it accordingly.

## What's mounted

- `$PWD` at `/workspace`
- `~/.claude` at `/home/clawd/.claude` (live bind mount)
- `~/.claude.json` at `/home/clawd/.claude.json` (copy in, copy out)

That's all. No `~/.ssh`, no `~/.gitconfig`, nothing else from your home.
The container runs as your host UID, so files in the workspace come out
owned by you.

## Concurrency

Multiple clawd sessions run fine side-by-side. Each gets its own
ephemeral HOME, so settings writes and claude's lock files don't
collide.

Don't mix clawd with host `claude` at the same time. They share
`~/.claude`, so `history.jsonl` / `sessions/` / `projects/` race, and
clawd's copy-back of `.claude.json` on exit can overwrite something
host claude just wrote.

`.claude.json` is copy-in, copy-out rather than a live mount. Claude
rewrites it with atomic rename, which docker file bind mounts reject
with EBUSY. Each clawd gets its own snapshot from invocation time;
changes persist on clean exit (`Ctrl-C`, `SIGTERM`, `SIGHUP`). A
`SIGKILL` or daemon crash drops the copy-back. Two concurrent clawds
don't see each other's `.claude.json` edits until they restart.

## Platforms

Linux, macOS, WSL 2. x86_64 and arm64. Native Windows: use WSL.

## Environment

```
CLAWD_IMAGE               image tag (default clawd:latest)
CLAWD_WORKSPACE           what to mount at /workspace (default $PWD)
CLAWD_HOST_CLAUDE_DIR     live-mount source (default $HOME/.claude)
CLAWD_HOST_CLAUDE_JSON    copy-in source (default $HOME/.claude.json)
CLAWD_CLAUDE_VERSION      passed to claude installer (latest | stable | X.Y.Z)
CLAWD_ALPINE_IMAGE        base image override (digest-pinned by default)
CLAWD_REPO, CLAWD_BRANCH  for self-update
```

## Security

Your credentials live in `~/.claude/.credentials.json`, which the
container can read. The trust boundary is the same as running host
claude. There are no network restrictions.

## License

MIT or Apache 2.0.
