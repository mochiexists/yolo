# claude --yolo

Life's too short for `--dangerously-skip-permissions`.

```diff
- claude --dangerously-skip-permissions
+ claude --yolo
```

## Install

```sh
curl -fsSL https://mochiexists.github.io/claude-yolo/install.sh | sh
```

Then **open a new terminal**.

## What it does

Adds a shell function to your `.zshrc` / `.bashrc` that rewrites `--yolo` to `--dangerously-skip-permissions` before passing it to whatever `claude` binary is on your PATH. Works with any install method (npm, Homebrew, CVM, etc).

## Uninstall

Remove the `claude-yolo` block from your shell rc file (`~/.zshrc` or `~/.bashrc`).

## License

MIT
