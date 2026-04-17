#!/bin/sh
set -e

YOLO_VERSION="0.4.0"

# claude-yolo uninstaller
# Removes the claude-yolo shell function from rc files

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

uninstall_from_rc() {
    rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if ! grep -q "$START_MARKER" "$rc_file" 2>/dev/null; then
        return
    fi

    # Extract the block and verify it matches a known install exactly.
    block=$(sed -n "/$START_MARKER/,/$END_MARKER/p" "$rc_file")
    if [ "$block" != "$ZSH_BLOCK" ] && [ "$block" != "$BASH_BLOCK" ] \
       && [ "$block" != "$LEGACY_BLOCK_1" ] \
       && [ "$block" != "$LEGACY_BLOCK_2_ZSH" ] && [ "$block" != "$LEGACY_BLOCK_2_BASH" ] \
       && [ "$block" != "$LEGACY_BLOCK_3_ZSH" ] && [ "$block" != "$LEGACY_BLOCK_3_BASH" ] \
       && [ "$block" != "$LEGACY_BLOCK_4_ZSH" ] && [ "$block" != "$LEGACY_BLOCK_4_BASH" ]; then
        echo "  WARNING: Block in $rc_file does not match a known claude-yolo install."
        echo "  It may have been modified. Skipping to be safe."
        echo "  Manually review the block between '$START_MARKER' and '$END_MARKER'."
        return
    fi

    # Safe to remove
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
    uninstall_from_rc "$HOME/.zshrc"
fi

if [ -f "$HOME/.bashrc" ]; then
    uninstall_from_rc "$HOME/.bashrc"
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Uninstalled! *walks away*"
echo "  > ^ <  "
echo ""
echo "  Open a new terminal to complete removal."
echo ""
