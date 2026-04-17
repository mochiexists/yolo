# claude --yolo

Life's too short for `--dangerously-skip-permissions`.

```diff
- claude --dangerously-skip-permissions
+ claude --yolo
```

Also installs shortcuts:

| Shortcut | Expands to |
|----------|------------|
| `cc` / `ccy` | `claude --yolo` |
| `cx` / `cxy` | `codex --yolo` |

## Install

```sh
curl -fsSL https://mochiexists.com/yolo/install.sh | sh
```

Then **open a new terminal**.

## What it does

Adds a shell function to your `.zshrc` / `.bashrc` that rewrites `--yolo` to `--dangerously-skip-permissions` before passing it to whatever `claude` binary is on your PATH. Works with any install method (npm, Homebrew, CVM, etc).

Survives other tools that redefine `claude()` (terminal multiplexers, shell integrations, etc.) by using a precmd hook that re-wraps after clobbering. Re-running the installer updates recognized legacy installs in-place.

If the marked `claude-yolo` block was modified by hand, install and uninstall both refuse to overwrite it and print a warning instead.

Here's the entire install script — no surprises:

https://github.com/mochiexists/yolo/blob/main/install.sh

## Uninstall

```sh
curl -fsSL https://mochiexists.com/yolo/uninstall.sh | sh
```

Then **open a new terminal**.

## License

MIT
