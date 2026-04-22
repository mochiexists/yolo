#!/bin/sh
set -e

YOLO_VERSION="0.4.0"

# claude-yolo uninstaller
# Removes the claude-yolo block, checking it matches what we installed.
# If it differs (hand-edited or older version), show a diff and ask.

ZSH_BLOCK=$(cat <<'EOF'
# >>> claude-yolo >>>
# https://github.com/mochiexists/yolo
__claude_yolo() {
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--yolo" ]]; then
            args+=("--dangerously-skip-permissions")
        else
            args+=("$arg")
        fi
    done
    if (( $+functions[__claude_yolo_inner] )); then
        __claude_yolo_inner "${args[@]}"
    else
        command claude "${args[@]}"
    fi
}
__claude_yolo_hook() {
    if (( $+functions[claude] )); then
        [[ "${functions[claude]}" == *__claude_yolo* ]] && return 0
        functions[__claude_yolo_inner]="${functions[claude]}"
    fi
    claude() { __claude_yolo "$@"; }
}
autoload -Uz add-zsh-hook
__claude_yolo_hook
add-zsh-hook precmd __claude_yolo_hook
alias ccy='claude --yolo'
alias cxy='codex --yolo'
# <<< claude-yolo <<<
EOF
)

BASH_BLOCK=$(cat <<'EOF'
# >>> claude-yolo >>>
# https://github.com/mochiexists/yolo
__claude_yolo() {
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--yolo" ]]; then
            args+=("--dangerously-skip-permissions")
        else
            args+=("$arg")
        fi
    done
    if declare -f __claude_yolo_inner >/dev/null 2>&1; then
        __claude_yolo_inner "${args[@]}"
    else
        command claude "${args[@]}"
    fi
}
__claude_yolo_hook() {
    if declare -f claude >/dev/null 2>&1; then
        declare -f claude | grep -q __claude_yolo && return 0
        eval "$(declare -f claude | sed '1s/^claude /__claude_yolo_inner /')"
    fi
    claude() { __claude_yolo "$@"; }
}
__claude_yolo_hook
[[ "${PROMPT_COMMAND-}" == *__claude_yolo_hook* ]] || PROMPT_COMMAND="__claude_yolo_hook;${PROMPT_COMMAND-}"
alias ccy='claude --yolo'
alias cxy='codex --yolo'
# <<< claude-yolo <<<
EOF
)

START_MARKER=">>> claude-yolo >>>"
END_MARKER="<<< claude-yolo <<<"

show_block_diff() {
    expected_str="$1"
    actual_str="$2"
    a=$(mktemp) && b=$(mktemp) || return 0
    printf '%s\n' "$actual_str"   > "$a"
    printf '%s\n' "$expected_str" > "$b"
    diff -u "$a" "$b" 2>/dev/null | sed -n '3,$p' | sed 's/^/    /'
    rm -f "$a" "$b"
}

confirm() {
    if [ "${YOLO_ASSUME_YES-}" = "1" ]; then
        return 0
    fi
    printf '  %s [y/N] ' "$1"
    if [ -r /dev/tty ]; then
        read reply < /dev/tty || return 1
    else
        read reply || return 1
    fi
    case "$reply" in
        [Yy]|[Yy][Ee][Ss]) return 0 ;;
        *) return 1 ;;
    esac
}

# Remove the claude-yolo block from $rc_file. Compares against $expected; if
# the block on disk differs (tampered / older install), show a diff and ask
# before removing.
uninstall_from_rc() {
    rc_file="$1"
    expected="$2"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if ! grep -q "$START_MARKER" "$rc_file" 2>/dev/null; then
        return
    fi

    existing_block=$(sed -n "/$START_MARKER/,/$END_MARKER/p" "$rc_file")
    if [ "$existing_block" != "$expected" ]; then
        echo ""
        echo "  The claude-yolo block in $rc_file doesn't match the expected block."
        echo "  Lines that differ (— on disk, + expected):"
        echo ""
        show_block_diff "$expected" "$existing_block"
        echo ""
        if ! confirm "Remove it anyway?"; then
            echo "  Skipped $rc_file. Block left in place."
            return
        fi
    fi
    sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$rc_file"
    rm -f "${rc_file}.bak"
    echo "  Removed from $rc_file"
}

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo"
echo "  > ^ <  uninstaller"
echo ""
echo "==> Cleaning up..."

if [ -f "$HOME/.zshrc" ]; then
    uninstall_from_rc "$HOME/.zshrc" "$ZSH_BLOCK"
fi

if [ -f "$HOME/.bashrc" ]; then
    uninstall_from_rc "$HOME/.bashrc" "$BASH_BLOCK"
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Uninstalled! *walks away*"
echo "  > ^ <  "
echo ""
echo "  Open a new terminal to complete removal."
echo ""
