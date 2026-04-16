#!/bin/sh
# Install clawd to PATH. Prefers /usr/local/bin (sudo if needed),
# falls back to ~/.local/bin and updates shell rc if that isn't on PATH.
set -eu

REPO_RAW_BASE="${CLAWD_INSTALL_BASE:-https://raw.githubusercontent.com/dritory/clawd/main}"
REPO_RAW="${CLAWD_INSTALL_URL:-$REPO_RAW_BASE/clawd}"
COMPLETION_URL="${CLAWD_COMPLETION_URL:-$REPO_RAW_BASE/completions/clawd.bash}"
LOCAL_SRC="${CLAWD_INSTALL_LOCAL:-}"
LOCAL_COMPLETION="${CLAWD_INSTALL_LOCAL_COMPLETION:-}"
SCRIPT_NAME=clawd

msg() { printf 'clawd-install: %s\n' "$*"; }
die() { printf 'clawd-install: %s\n' "$*" >&2; exit 1; }

# Check dependencies.
command -v bwrap >/dev/null 2>&1 || {
    msg "bubblewrap (bwrap) is not installed"
    if command -v apt-get >/dev/null 2>&1; then
        msg "install it: sudo apt-get install bubblewrap"
    elif command -v pacman >/dev/null 2>&1; then
        msg "install it: sudo pacman -S bubblewrap"
    elif command -v dnf >/dev/null 2>&1; then
        msg "install it: sudo dnf install bubblewrap"
    fi
    die "install bubblewrap first, then re-run this installer"
}

SUDO=""
if [ -w /usr/local/bin ] 2>/dev/null; then
    DIR=/usr/local/bin
elif [ -d /usr/local/bin ] && command -v sudo >/dev/null 2>&1; then
    DIR=/usr/local/bin
    SUDO=sudo
    msg "installing to $DIR (sudo required)"
else
    DIR="$HOME/.local/bin"
    mkdir -p "$DIR"
fi

TMP=$(mktemp) || die "mktemp failed"
trap 'rm -f "$TMP"' EXIT INT TERM
if [ -n "$LOCAL_SRC" ]; then
    [ -r "$LOCAL_SRC" ] || die "cannot read $LOCAL_SRC"
    cp "$LOCAL_SRC" "$TMP"
    msg "using local source: $LOCAL_SRC"
else
    command -v curl >/dev/null 2>&1 || die "curl is required (or set CLAWD_INSTALL_LOCAL=/path/to/clawd)"
    msg "downloading clawd"
    curl -fsSL "$REPO_RAW" -o "$TMP"
fi

$SUDO install -m 0755 "$TMP" "$DIR/$SCRIPT_NAME"
msg "installed: $DIR/$SCRIPT_NAME"

install_completion() {
    comp_tmp=$(mktemp) || return 1
    if [ -n "$LOCAL_COMPLETION" ]; then
        [ -r "$LOCAL_COMPLETION" ] || { msg "skipping completion: $LOCAL_COMPLETION not readable"; rm -f "$comp_tmp"; return 1; }
        cp "$LOCAL_COMPLETION" "$comp_tmp"
    elif [ -n "$LOCAL_SRC" ]; then
        local_comp="$(dirname "$LOCAL_SRC")/completions/clawd.bash"
        if [ -r "$local_comp" ]; then
            cp "$local_comp" "$comp_tmp"
        else
            msg "skipping completion: no $local_comp"; rm -f "$comp_tmp"; return 0
        fi
    else
        command -v curl >/dev/null 2>&1 || { rm -f "$comp_tmp"; return 0; }
        curl -fsSL "$COMPLETION_URL" -o "$comp_tmp" 2>/dev/null || { msg "skipping completion: download failed"; rm -f "$comp_tmp"; return 0; }
    fi

    if [ -n "$SUDO" ] || [ "$DIR" = "/usr/local/bin" ]; then
        comp_dir=/etc/bash_completion.d
        $SUDO mkdir -p "$comp_dir"
        $SUDO install -m 0644 "$comp_tmp" "$comp_dir/clawd"
        msg "installed completion: $comp_dir/clawd"
    else
        comp_dir="${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions"
        mkdir -p "$comp_dir"
        install -m 0644 "$comp_tmp" "$comp_dir/clawd"
        msg "installed completion: $comp_dir/clawd"
    fi
    rm -f "$comp_tmp"
}
install_completion || true

case ":$PATH:" in
    *":$DIR:"*) msg "$DIR is on your PATH"; exit 0 ;;
esac

LINE="export PATH=\"$DIR:\$PATH\""
MARKER="# Added by clawd installer"
appended=0
already=0
for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    [ -f "$rc" ] || continue
    if grep -Fq "$MARKER" "$rc" 2>/dev/null; then
        already=1
    else
        printf '\n%s\n%s\n' "$MARKER" "$LINE" >>"$rc"
        msg "added $DIR to PATH in $rc"
        appended=1
    fi
done

if [ "$appended" -eq 0 ] && [ "$already" -eq 0 ]; then
    printf '%s\n%s\n' "$MARKER" "$LINE" >"$HOME/.profile"
    msg "created ~/.profile with PATH update"
fi

msg "start a new shell, or run: export PATH=\"$DIR:\$PATH\""
msg "then: clawd"
