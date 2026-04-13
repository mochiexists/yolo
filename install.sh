#!/bin/sh
set -e

# claude-yolo installer
# Adds a shell function that lets you use `claude --yolo`
# instead of `claude --dangerously-skip-permissions`

FUNCTION_BLOCK='
# claude-yolo: --yolo flag support for Claude Code
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
}'

MARKER="claude-yolo"

install_to_rc() {
    rc_file="$1"
    if [ ! -f "$rc_file" ]; then
        return
    fi
    if grep -q "$MARKER" "$rc_file" 2>/dev/null; then
        echo "  Already installed in $rc_file — skipping."
        return
    fi
    printf "\n%s\n" "$FUNCTION_BLOCK" >> "$rc_file"
    echo "  Added to $rc_file"
}

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo"
echo "  > ^ <  installer"
echo ""
echo "==> Sniffing shell config..."

installed=0

# Install to zsh if .zshrc exists or zsh is the default shell
if [ -f "$HOME/.zshrc" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    touch "$HOME/.zshrc"
    install_to_rc "$HOME/.zshrc"
    installed=1
fi

# Install to bash if .bashrc exists or bash is the default shell
if [ -f "$HOME/.bashrc" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    touch "$HOME/.bashrc"
    install_to_rc "$HOME/.bashrc"
    installed=1
fi

if [ "$installed" -eq 0 ]; then
    echo ""
    echo "  /\\_/\\  "
    echo " ( x.x ) Meow! Could not detect shell config."
    echo "  > ^ <  "
    echo ""
    echo "  Manually add this to your shell rc file:"
    echo "$FUNCTION_BLOCK"
    exit 1
fi

echo ""
echo "  /\\_/\\  "
echo " ( ^.^ ) Installed! *knocks things off desk*"
echo "  > ^ <  meow~"
echo ""
echo "  Open a new terminal, then run:"
echo ""
echo "    claude --yolo"
echo ""
