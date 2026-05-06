# bash completion for krab's reserved subcommands.

_krab() {
    local cur prev words cword
    _init_completion 2>/dev/null || {
        COMPREPLY=()
        cur="${COMP_WORDS[COMP_CWORD]}"
        cword=$COMP_CWORD
    }

    if [ "${cword:-$COMP_CWORD}" -eq 1 ]; then
        local subs="yolo shell doctor version help-krab"
        # shellcheck disable=SC2207
        COMPREPLY=( $(compgen -W "$subs" -- "$cur") )
        return 0
    fi

    COMPREPLY=()
    return 0
}

complete -F _krab krab
