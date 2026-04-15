# bash completion for clawd's reserved subcommands.

_clawd() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        cword=$COMP_CWORD
    }

    if [ "${cword:-$COMP_CWORD}" -eq 1 ]; then
        local subs="build update self-update shell version help-clawd"
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
        return 0
    fi

    COMPREPLY=()
    return 0
}

complete -F _clawd clawd
