#!/bin/sh
set -e

YOLO_VERSION="0.4.0"

# claude-yolo installer
# Adds a shell function that lets you use `claude --yolo`
# instead of `claude --dangerously-skip-permissions`
#
# Survives other tools (e.g. terminal multiplexers) that redefine `claude()`
# by using a precmd/PROMPT_COMMAND hook that re-wraps after clobbering.

LEGACY_BLOCKS_COUNT=4
LEGACY_BLOCK_1=$(cat <<'EOF'
# >>> claude-yolo >>>
# https://github.com/mochiexists/yolo
claude() {
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == "--yolo" ]]; then
            args+=("--dangerously-skip-permissions")
        else
            args+=("$arg")
        fi
    done
    command claude "${args[@]}"
}
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_2_ZSH=$(cat <<'EOF'
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
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_2_BASH=$(cat <<'EOF'
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
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_3_ZSH=$(cat <<'EOF'
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
alias cly='claude --yolo'
alias coy='codex --yolo'
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_3_BASH=$(cat <<'EOF'
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
alias cly='claude --yolo'
alias coy='codex --yolo'
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_4_ZSH=$(cat <<'EOF'
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
alias cc='claude --yolo'
alias cx='codex --yolo'
# <<< claude-yolo <<<
EOF
)

LEGACY_BLOCK_4_BASH=$(cat <<'EOF'
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
alias cc='claude --yolo'
alias cx='codex --yolo'
# <<< claude-yolo <<<
EOF
)

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
alias cc='claude --yolo'
alias cx='codex --yolo'
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
alias cc='claude --yolo'
alias cx='codex --yolo'
alias ccy='claude --yolo'
alias cxy='codex --yolo'
# <<< claude-yolo <<<
EOF
)

START_MARKER=">>> claude-yolo >>>"
END_MARKER="<<< claude-yolo <<<"

install_to_rc() {
    rc_file="$1"
    block="$2"
    legacy_block="$3"
    legacy_block_2="$4"
    legacy_block_3="$5"
    legacy_block_4="$6"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if grep -q "$START_MARKER" "$rc_file" 2>/dev/null; then
        existing_block=$(sed -n "/$START_MARKER/,/$END_MARKER/p" "$rc_file")
        if [ "$existing_block" = "$block" ]; then
            echo "  Already up to date in $rc_file"
            return
        fi
        if [ "$existing_block" != "$legacy_block" ] \
           && [ "$existing_block" != "$legacy_block_2" ] \
           && [ "$existing_block" != "$legacy_block_3" ] \
           && [ "$existing_block" != "$legacy_block_4" ]; then
            echo "  WARNING: Found an unrecognized claude-yolo block in $rc_file"
            echo "  It may have been modified. Skipping to avoid overwriting it."
            echo "  Remove the block between '$START_MARKER' and '$END_MARKER' to reinstall."
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

# Install to zsh if .zshrc exists or zsh is the default shell
if [ -f "$HOME/.zshrc" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    touch "$HOME/.zshrc"
    install_to_rc "$HOME/.zshrc" "$ZSH_BLOCK" "$LEGACY_BLOCK_1" "$LEGACY_BLOCK_2_ZSH" "$LEGACY_BLOCK_3_ZSH" "$LEGACY_BLOCK_4_ZSH"
    installed=1
fi

# Install to bash if .bashrc exists or bash is the default shell
if [ -f "$HOME/.bashrc" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    touch "$HOME/.bashrc"
    install_to_rc "$HOME/.bashrc" "$BASH_BLOCK" "$LEGACY_BLOCK_1" "$LEGACY_BLOCK_2_BASH" "$LEGACY_BLOCK_3_BASH" "$LEGACY_BLOCK_4_BASH"
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
echo "    cc   →  claude --yolo"
echo "    cx   →  codex --yolo"
echo "    ccy  →  claude --yolo"
echo "    cxy  →  codex --yolo"
echo ""
