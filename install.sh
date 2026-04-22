#!/bin/sh
set -e

YOLO_VERSION="0.4.0"

# claude-yolo installer
# Adds a shell function that lets you use `claude --yolo`
# instead of `claude --dangerously-skip-permissions`.
#
# Survives other tools (e.g. terminal multiplexers) that redefine `claude()`
# by using a precmd/PROMPT_COMMAND hook that re-wraps after clobbering.

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

# Print a unified diff of two strings, indented for readability.
# Usage: show_block_diff <expected> <actual>
show_block_diff() {
    expected_str="$1"
    actual_str="$2"
    a=$(mktemp) && b=$(mktemp) || return 0
    printf '%s\n' "$actual_str"   > "$a"
    printf '%s\n' "$expected_str" > "$b"
    # Strip diff's file headers (first two lines) and indent the rest.
    diff -u "$a" "$b" 2>/dev/null | sed -n '3,$p' | sed 's/^/    /'
    rm -f "$a" "$b"
}

# Ask the user y/N. Returns 0 on yes, 1 on no.
# Works under `curl | sh` by reading from /dev/tty when stdin is piped.
# Bypassed (auto-yes) when YOLO_ASSUME_YES=1.
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

# Install $block into $rc_file. If an existing claude-yolo block is present
# that doesn't match the expected one, show a diff and ask before replacing.
install_to_rc() {
    rc_file="$1"
    block="$2"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if grep -q "$START_MARKER" "$rc_file" 2>/dev/null; then
        existing_block=$(sed -n "/$START_MARKER/,/$END_MARKER/p" "$rc_file")
        if [ "$existing_block" = "$block" ]; then
            echo "  Already up to date in $rc_file"
            return
        fi
        echo ""
        echo "  The claude-yolo block in $rc_file differs from the latest."
        echo "  Lines that would change (— existing, + new):"
        echo ""
        show_block_diff "$block" "$existing_block"
        echo ""
        if ! confirm "Replace the existing block?"; then
            echo "  Skipped $rc_file. Block left untouched."
            return
        fi
        sed -i.bak "/$START_MARKER/,/$END_MARKER/d" "$rc_file"
        rm -f "${rc_file}.bak"
        printf "\n%s\n" "$block" >> "$rc_file"
        echo "  Updated $rc_file"
        return
    fi
    printf "\n%s\n" "$block" >> "$rc_file"
    echo "  Added to $rc_file"
}

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo v${YOLO_VERSION}"
echo "  > ^ <  installer"
echo ""
echo "==> Sniffing shell config..."

installed=0

if [ -f "$HOME/.zshrc" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    touch "$HOME/.zshrc"
    install_to_rc "$HOME/.zshrc" "$ZSH_BLOCK"
    installed=1
fi

if [ -f "$HOME/.bashrc" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    touch "$HOME/.bashrc"
    install_to_rc "$HOME/.bashrc" "$BASH_BLOCK"
    installed=1
fi

if [ "$installed" -eq 0 ]; then
    echo ""
    echo "  /\\_/\\  "
    echo " ( x.x ) Meow! Could not detect shell config."
    echo "  > ^ <  "
    echo ""
    echo "  Manually add this to your shell rc file:"
    echo "$ZSH_BLOCK"
    exit 1
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Installed v${YOLO_VERSION}! *knocks things off desk*"
echo "  > ^ <  meow~"
echo ""
echo "  Open a new terminal, then run:"
echo ""
echo "    claude --yolo"
echo ""
echo "  Shortcuts:"
echo "    ccy  →  claude --yolo"
echo "    cxy  →  codex --yolo"
echo ""
