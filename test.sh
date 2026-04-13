#!/bin/sh
set -e

# Test the full install → verify → uninstall → verify cycle
# Uses a temp HOME so it never touches your real rc files

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_HOME=$(mktemp -d)
export HOME="$FAKE_HOME"
export SHELL="/bin/zsh"

passed=0
failed=0

assert_eq() {
    label="$1"; expected="$2"; actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected: $expected"
        echo "    actual:   $actual"
        failed=$((failed + 1))
    fi
}

cleanup() {
    rm -rf "$FAKE_HOME"
}
trap cleanup EXIT

echo ""
echo "=== Test: fresh install ==="
touch "$FAKE_HOME/.zshrc"
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc contains claude function" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: idempotent reinstall ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc still has exactly 1 marker" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: function works ==="
# Source the rc and check that claude function exists
result=$(zsh -c "source '$FAKE_HOME/.zshrc' && type claude" 2>&1 || true)
assert_eq "claude is a function" "1" "$(echo "$result" | grep -c 'function')"

echo ""
echo "=== Test: --yolo rewrite ==="
# Create a fake claude binary that prints its args
mkdir -p "$FAKE_HOME/bin"
cat > "$FAKE_HOME/bin/claude" << 'FAKEBIN'
#!/bin/sh
echo "$@"
FAKEBIN
chmod +x "$FAKE_HOME/bin/claude"
result=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --yolo" 2>&1)
assert_eq "--yolo becomes --dangerously-skip-permissions" "--dangerously-skip-permissions" "$result"

echo ""
echo "=== Test: other args pass through ==="
result=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --model opus --yolo --verbose" 2>&1)
assert_eq "mixed args rewritten correctly" "--model opus --dangerously-skip-permissions --verbose" "$result"

echo ""
echo "=== Test: uninstall ==="
sh "$SCRIPT_DIR/uninstall.sh"
assert_eq "zshrc has no marker after uninstall" "0" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: reinstall after uninstall ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc has marker after reinstall" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.zshrc")"

echo ""
echo "=== Test: real claude spawns with --yolo ==="
# Use the real claude binary — just check --version works through the function
REAL_CLAUDE="$(command -v claude 2>/dev/null || true)"
if [ -n "$REAL_CLAUDE" ]; then
    # Reset to zsh with the installed function
    export SHELL="/bin/zsh"
    rm -f "$FAKE_HOME/.bashrc"
    touch "$FAKE_HOME/.zshrc"
    sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
    sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1

    # claude --version via the real binary (no function)
    direct_version=$("$REAL_CLAUDE" --version 2>&1 || true)

    # claude --version via the yolo function (should pass through unchanged)
    func_version=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --version" 2>&1 || true)
    assert_eq "real claude --version matches through function" "$direct_version" "$func_version"

    # claude --yolo --version should spawn real claude with --dangerously-skip-permissions --version
    # It will error on --dangerously-skip-permissions + --version combo but proves it launched
    yolo_output=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --yolo --version" 2>&1 || true)
    # Should contain version info (claude prints version even with other flags)
    yolo_has_version=$(echo "$yolo_output" | grep -c '[0-9]\.[0-9]' || true)
    assert_eq "real claude --yolo --version produces version output" "1" "$yolo_has_version"

    # Prove --yolo isn't passed literally to the binary
    # Our fake binary test already covers rewriting, but let's double check with real claude
    # claude --yolo (no --version) would start interactive mode, so we just verify --version path
    direct_dsp=$("$REAL_CLAUDE" --dangerously-skip-permissions --version 2>&1 || true)
    assert_eq "real --yolo output matches real --dangerously-skip-permissions output" "$direct_dsp" "$yolo_output"
else
    echo "  SKIP: claude binary not found on PATH"
fi

echo ""
echo "=== Test: bash support ==="
rm -f "$FAKE_HOME/.zshrc"
export SHELL="/bin/bash"
touch "$FAKE_HOME/.bashrc"
sh "$SCRIPT_DIR/uninstall.sh"
sh "$SCRIPT_DIR/install.sh"
assert_eq "bashrc contains claude function" "1" "$(grep -c 'claude-yolo' "$FAKE_HOME/.bashrc")"

echo ""
echo "================================"
echo "  $passed passed, $failed failed"
echo "================================"
echo ""

[ "$failed" -eq 0 ]
