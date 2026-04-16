#!/usr/bin/env bash
# Tests for clawd.
#   tests/run-tests.sh
# Exit code is the number of failures.

set -uo pipefail

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
CLAWD="$REPO/clawd"
INSTALL="$REPO/install.sh"

pass=0
fail=0
ok()   { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
nope() { printf 'FAIL %s: %s\n' "$1" "$2" >&2; fail=$((fail+1)); }

test_syntax() {
    bash -n "$CLAWD" 2>/dev/null && ok "clawd: bash syntax" || nope "clawd: bash syntax" "bash -n failed"
    sh -n "$INSTALL" 2>/dev/null && ok "install.sh: sh syntax" || nope "install.sh: sh syntax" "sh -n failed"
}

test_shellcheck() {
    if ! command -v shellcheck >/dev/null 2>&1; then
        printf 'skip shellcheck: not installed\n'
        return
    fi
    shellcheck -S warning "$CLAWD" >/dev/null && ok "clawd: shellcheck" || nope "clawd: shellcheck" "see shellcheck $CLAWD"
    shellcheck -S warning "$INSTALL" >/dev/null && ok "install.sh: shellcheck" || nope "install.sh: shellcheck" "see shellcheck $INSTALL"
}

test_help_output() {
    local out
    out=$("$CLAWD" help-clawd 2>&1) || true
    local missing=()
    for want in "yolo" "shell" "doctor" "version"; do
        printf '%s' "$out" | grep -q "$want" || missing+=("$want")
    done
    if [ "${#missing[@]}" -eq 0 ]; then
        ok "help-clawd lists subcommands"
    else
        nope "help-clawd lists subcommands" "missing: ${missing[*]}"
    fi
}

test_absent_bwrap() {
    local stub
    stub=$(mktemp -d)
    for t in env bash sh cat grep tr id mkdir; do
        if src=$(command -v "$t"); then ln -sf "$src" "$stub/$t"; fi
    done
    local out
    out=$(env -i PATH="$stub" HOME="$HOME" "$CLAWD" version 2>&1 || true)
    if printf '%s' "$out" | grep -q "bubblewrap not found"; then
        ok "absent bwrap: clean error"
    else
        nope "absent bwrap: clean error" "got: $out"
    fi
    rm -rf "$stub"
}

test_sandbox_write_project() {
    if ! command -v bwrap >/dev/null 2>&1; then
        printf 'skip sandbox tests: bwrap not installed\n'
        return
    fi
    local testfile="$PWD/clawd-test-$$"
    "$CLAWD" shell -c "echo ok > $testfile" 2>/dev/null
    if [ -f "$testfile" ] && grep -q ok "$testfile"; then
        ok "sandbox: write to \$PWD allowed"
    else
        nope "sandbox: write to \$PWD allowed" "file not created"
    fi
    rm -f "$testfile"
}

test_sandbox_home_blocked() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local out
    out=$("$CLAWD" shell -c "touch $HOME/clawd-escape-test 2>&1" 2>/dev/null || true)
    if printf '%s' "$out" | grep -qi "read-only"; then
        ok "sandbox: write to \$HOME root blocked"
    else
        nope "sandbox: write to \$HOME root blocked" "got: $out"
    fi
    rm -f "$HOME/clawd-escape-test" 2>/dev/null || true
}

test_sandbox_cache_writable() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    mkdir -p "$HOME/.cache"
    local testfile="$HOME/.cache/clawd-test-$$"
    "$CLAWD" shell -c "echo ok > $testfile" 2>/dev/null
    if [ -f "$testfile" ]; then
        ok "sandbox: write to ~/.cache allowed"
    else
        nope "sandbox: write to ~/.cache allowed" "file not created"
    fi
    rm -f "$testfile"
}

test_sandbox_write_blocked() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local out
    out=$("$CLAWD" shell -c "touch /etc/clawd-test 2>&1" 2>/dev/null || true)
    if printf '%s' "$out" | grep -qi "read-only"; then
        ok "sandbox: write to /etc blocked"
    else
        nope "sandbox: write to /etc blocked" "got: $out"
    fi
}

test_sandbox_ssh_readonly() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    if [ ! -d "$HOME/.ssh" ]; then
        printf 'skip ssh readonly: ~/.ssh does not exist\n'
        return
    fi
    local out
    out=$("$CLAWD" shell -c "touch $HOME/.ssh/clawd-test 2>&1" 2>/dev/null || true)
    if printf '%s' "$out" | grep -qi "read-only"; then
        ok "sandbox: ~/.ssh is read-only"
    else
        nope "sandbox: ~/.ssh is read-only" "got: $out"
    fi
}

test_env_filtering() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local out
    out=$(AWS_SECRET_ACCESS_KEY=leaked "$CLAWD" shell -c 'echo "${AWS_SECRET_ACCESS_KEY:-stripped}"' 2>/dev/null)
    if [ "$out" = "stripped" ]; then
        ok "env: sensitive var stripped"
    else
        nope "env: sensitive var stripped" "got: $out"
    fi
}

test_env_passthrough() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local out
    out=$(AWS_SECRET_ACCESS_KEY=kept CLAWD_ENV=AWS_SECRET_ACCESS_KEY "$CLAWD" shell -c 'echo "$AWS_SECRET_ACCESS_KEY"' 2>/dev/null)
    if [ "$out" = "kept" ]; then
        ok "env: CLAWD_ENV passthrough"
    else
        nope "env: CLAWD_ENV passthrough" "got: $out"
    fi
}

test_config_file() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local testdir
    testdir=$(mktemp -d)
    echo "CLAWD_ALLOW_WRITE=$testdir" > "$PWD/.clawd"
    "$CLAWD" shell -c "echo ok > $testdir/test.txt" 2>/dev/null
    rm -f "$PWD/.clawd"
    if [ -f "$testdir/test.txt" ]; then
        ok "config: .clawd file sets CLAWD_ALLOW_WRITE"
    else
        nope "config: .clawd file sets CLAWD_ALLOW_WRITE" "file not created"
    fi
    rm -rf "$testdir"
}

test_allow_write() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    local testdir
    testdir=$(mktemp -d -p /tmp)
    CLAWD_ALLOW_WRITE="$testdir" "$CLAWD" shell -c "echo ok > $testdir/test.txt" 2>/dev/null
    if [ -f "$testdir/test.txt" ]; then
        ok "env: CLAWD_ALLOW_WRITE works"
    else
        nope "env: CLAWD_ALLOW_WRITE works" "file not created"
    fi
    rm -rf "$testdir"
}

test_doctor() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    if "$CLAWD" doctor >/dev/null 2>&1; then
        ok "clawd doctor"
    else
        nope "clawd doctor" "exited non-zero"
    fi
}

test_completion_sourceable() {
    if bash -c "source '$REPO/completions/clawd.bash' && complete -p clawd" >/dev/null 2>&1; then
        ok "completion: sources cleanly"
    else
        nope "completion: sources cleanly" "bash source + complete -p clawd failed"
    fi
}

test_installer_sandbox() {
    local testhome testbin
    testhome=$(mktemp -d)
    testbin=$(mktemp -d)
    for t in sh cat cp rm mkdir grep printf install mktemp chmod ls dirname command bwrap; do
        if src=$(command -v "$t"); then ln -sf "$src" "$testbin/$t"; fi
    done
    touch "$testhome/.bashrc"

    local runner="env -i HOME=$testhome PATH=$testbin SHELL=/bin/sh CLAWD_INSTALL_LOCAL=$CLAWD sh $INSTALL"

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
    ok "installer: first run"

    if [ -r "$testhome/.local/share/bash-completion/completions/clawd" ]; then
        ok "installer: completion placed"
    else
        nope "installer: completion placed" "not found"
    fi

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

test_syntax
test_shellcheck
test_help_output
test_absent_bwrap
test_sandbox_write_project
test_sandbox_home_blocked
test_sandbox_cache_writable
test_sandbox_write_blocked
test_sandbox_ssh_readonly
test_env_filtering
test_env_passthrough
test_config_file
test_allow_write
test_claude_starts() {
    if ! command -v bwrap >/dev/null 2>&1; then return; fi
    if ! command -v claude >/dev/null 2>&1; then
        printf 'skip claude start: claude not installed\n'
        return
    fi
    local out
    out=$("$CLAWD" -- --version 2>&1)
    if printf '%s' "$out" | grep -q "Claude Code"; then
        ok "sandbox: claude starts"
    else
        nope "sandbox: claude starts" "got: $out"
    fi
}

test_doctor
test_claude_starts
test_completion_sourceable
test_installer_sandbox

echo
printf 'summary: %d passed, %d failed\n' "$pass" "$fail"
exit "$fail"
