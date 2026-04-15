#!/usr/bin/env bash
# Tests for clawd.
#   tests/run-tests.sh [--no-build]
# Exit code is the number of failures.

set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
CLAWD="$REPO/clawd"
INSTALL="$REPO/install.sh"

SKIP_BUILD=0
[ "${1:-}" = "--no-build" ] && SKIP_BUILD=1

pass=0
fail=0
ok()   { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
nope() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; fail=$((fail+1)); }

test_syntax() {
    if bash -n "$CLAWD" 2>/dev/null; then
        ok "clawd: bash syntax"
    else
        nope "clawd: bash syntax" "bash -n failed"
    fi
    if sh -n "$INSTALL" 2>/dev/null; then
        ok "install.sh: sh syntax"
    else
        nope "install.sh: sh syntax" "sh -n failed"
    fi
}

test_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        printf 'skip shellcheck: not installed\n'
        return
    fi
    if shellcheck -S warning "$CLAWD" >/dev/null; then
        ok "clawd: shellcheck"
    else
        nope "clawd: shellcheck" "see 'shellcheck $CLAWD'"
    fi
    if shellcheck -S warning "$INSTALL" >/dev/null; then
        ok "install.sh: shellcheck"
    else
        nope "install.sh: shellcheck" "see 'shellcheck $INSTALL'"
    fi
}

test_help_output() {
    local out
    if ! out=$(PATH=/usr/bin:/bin "$CLAWD" help-clawd 2>&1); then
        # If docker probe runs first we'll see an error; that's a regression.
        nope "help-clawd without docker" "exited non-zero: $out"
        return
    fi
    # Expect the doc to mention all reserved subcommands.
    local missing=()
    for want in "build" "update" "self-update" "shell" "yolo" "version"; do
        if ! printf '%s' "$out" | grep -q "$want"; then
            missing+=("$want")
        fi
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        ok "help-clawd lists subcommands"
    else
        nope "help-clawd lists subcommands" "missing: ${missing[*]}"
    fi
}

test_help_without_docker() {
    local stub
    stub=$(mktemp -d)
    for t in env bash sh cat grep tr head id mkdir; do
        if src=$(command -v "$t"); then ln -sf "$src" "$stub/$t"; fi
    done
    local out
    out=$(env -i PATH="$stub" HOME="$HOME" "$CLAWD" build 2>&1 || true)
    if printf '%s' "$out" | grep -q "docker not found"; then
        ok "absent docker: clean error"
    else
        nope "absent docker: clean error" "got: $out"
    fi
    rm -rf "$stub"
}

test_installer_sandbox() {
    local testhome testbin
    testhome=$(mktemp -d)
    testbin=$(mktemp -d)
    # No sudo in PATH so the installer takes the ~/.local/bin path.
    for t in sh cat cp rm mkdir grep printf install mktemp chmod ls dirname; do
        if src=$(command -v "$t"); then ln -sf "$src" "$testbin/$t"; fi
    done
    touch "$testhome/.bashrc"

    local runner="env -i HOME=$testhome PATH=$testbin SHELL=/bin/sh CLAWD_INSTALL_LOCAL=$CLAWD sh $INSTALL"

    # First run: installs binary, appends rc line
    if ! $runner >/dev/null 2>&1; then
        nope "installer: first run" "exit non-zero"
        rm -rf "$testhome" "$testbin"
        return
    fi
    if ! [ -x "$testhome/.local/bin/clawd" ]; then
        nope "installer: first run" "binary not placed"
        rm -rf "$testhome" "$testbin"
        return
    fi
    if ! grep -q "# Added by clawd installer" "$testhome/.bashrc"; then
        nope "installer: first run" "rc not updated"
        rm -rf "$testhome" "$testbin"
        return
    fi
    ok "installer: first run"

    # Completion should be installed into the per-user XDG location.
    if [ -r "$testhome/.local/share/bash-completion/completions/clawd" ]; then
        ok "installer: completion placed"
    else
        nope "installer: completion placed" "not found at ~/.local/share/bash-completion/completions/clawd"
    fi

    # Second run: idempotent — no duplicate marker, no stray .profile
    $runner >/dev/null 2>&1
    local marker_count
    marker_count=$(grep -c "# Added by clawd installer" "$testhome/.bashrc")
    if [ "$marker_count" -ne 1 ]; then
        nope "installer: idempotent" "marker count=$marker_count"
    elif [ -f "$testhome/.profile" ]; then
        nope "installer: idempotent" "stray .profile created"
    else
        ok "installer: idempotent"
    fi

    rm -rf "$testhome" "$testbin"
}

test_completion_sourceable() {
    if bash -c "source '$REPO/completions/clawd.bash' && complete -p clawd" >/dev/null 2>&1; then
        ok "completion: sources cleanly"
    else
        nope "completion: sources cleanly" "bash source + complete -p clawd failed"
    fi
}

test_image_build_and_version() {
    if [ "$SKIP_BUILD" = "1" ]; then
        printf 'skip image build: --no-build\n'
        return
    fi
    if ! command -v docker >/dev/null 2>&1; then
        printf 'skip image build: docker not installed\n'
        return
    fi
    if ! docker info >/dev/null 2>&1; then
        printf 'skip image build: docker daemon unavailable\n'
        return
    fi

    local tag="clawd-test-$$:latest"
    if ! CLAWD_IMAGE="$tag" "$CLAWD" build >/dev/null 2>&1; then
        nope "image: builds" "build failed"
        return
    fi
    ok "image: builds"

    local version_out
    if ! version_out=$(CLAWD_IMAGE="$tag" "$CLAWD" version 2>&1); then
        nope "image: claude runs" "version command failed"
    elif ! printf '%s' "$version_out" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+ \(Claude Code\)"; then
        nope "image: claude runs" "unexpected output: $version_out"
    else
        ok "image: claude runs"
    fi

    docker rmi "$tag" >/dev/null 2>&1 || true
}

test_syntax
test_shellcheck
test_help_output
test_help_without_docker
test_installer_sandbox
test_completion_sourceable
test_image_build_and_version

echo
printf 'summary: %d passed, %d failed\n' "$pass" "$fail"
exit "$fail"
