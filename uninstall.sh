#!/bin/sh
set -e

YOLO_VERSION="0.4.0"

# claude-yolo uninstaller
# Removes whatever sits between the claude-yolo markers in each rc file.

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
