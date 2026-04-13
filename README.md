# claude --yolo

Life's too short for `--dangerously-skip-permissions`.

```diff
- claude --dangerously-skip-permissions
+ claude --yolo
```

## Install

```sh
curl -fsSL https://mochiexists.com/yolo/install.sh | sh
```

Then **open a new terminal**.

## What it does

Adds a shell function to your `.zshrc` / `.bashrc` that rewrites `--yolo` to `--dangerously-skip-permissions` before passing it to whatever `claude` binary is on your PATH. Works with any install method (npm, Homebrew, CVM, etc).

Here's the entire install script — no surprises:

https://github.com/mochiexists/yolo/blob/main/install.sh

<details>
<summary>View full source</summary>

```sh
#!/bin/sh
set -e

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
    if [ ! -f "$rc_file" ]; then return; fi
    if grep -q "$MARKER" "$rc_file" 2>/dev/null; then
        echo "  Already installed in $rc_file — skipping."; return
    fi
    printf "\n%s\n" "$FUNCTION_BLOCK" >> "$rc_file"
    echo "  Added to $rc_file"
}

echo ""
echo "  /\_/\  "
echo " ( o.o ) claude --yolo"
echo "  > ^ <  installer"
echo ""
echo "==> Sniffing shell config..."

installed=0

if [ -f "$HOME/.zshrc" ] || [ "$(basename "$SHELL")" = "zsh" ]; then
    touch "$HOME/.zshrc"; install_to_rc "$HOME/.zshrc"; installed=1
fi
if [ -f "$HOME/.bashrc" ] || [ "$(basename "$SHELL")" = "bash" ]; then
    touch "$HOME/.bashrc"; install_to_rc "$HOME/.bashrc"; installed=1
fi

if [ "$installed" -eq 0 ]; then
    echo " ( x.x ) Meow! Could not detect shell config."; exit 1
fi

echo ""
echo "  /\_/\  "
echo " ( ^.^ ) Installed! *knocks things off desk*"
echo "  > ^ <  meow~"
echo ""
echo "  Open a new terminal, then run:  claude --yolo"
echo ""
```

</details>

## Uninstall

Remove the `claude-yolo` block from your shell rc file (`~/.zshrc` or `~/.bashrc`).

## License

MIT
