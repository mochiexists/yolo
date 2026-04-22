#!/bin/sh
set -e

# End-to-end test for claude --yolo
# Flow: clean slate → verify broken → install → verify working → uninstall → verify broken
# Also tests: update-in-place, clobbering resilience, tampered block safety
# Always ends in uninstalled state so you can re-run or install fresh after

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAKE_HOME=$(mktemp -d)
FAKE_BASH_HOME=$(mktemp -d)
REAL_HOME="$HOME"
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

assert_contains() {
    label="$1"; needle="$2"; haystack="$3"
    if echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected to contain: $needle"
        echo "    actual: $haystack"
        failed=$((failed + 1))
    fi
}

assert_not_contains() {
    label="$1"; needle="$2"; haystack="$3"
    if ! echo "$haystack" | grep -q "$needle"; then
        echo "  PASS: $label"
        passed=$((passed + 1))
    else
        echo "  FAIL: $label"
        echo "    expected NOT to contain: $needle"
        echo "    actual: $haystack"
        failed=$((failed + 1))
    fi
}

count_matches() {
    result=$(grep -c "$1" "$2" 2>/dev/null) || result=0
    printf "%s" "$result"
}

cleanup() {
    rm -rf "$FAKE_HOME"
    rm -rf "$FAKE_BASH_HOME"
}
trap cleanup EXIT

# Find the real claude binary
REAL_CLAUDE="$(HOME="$REAL_HOME" command -v claude 2>/dev/null || true)"
if [ -z "$REAL_CLAUDE" ]; then
    echo "ABORT: claude binary not found on PATH — can't run e2e tests"
    exit 1
fi

echo ""
echo "  /\\_/\\  "
echo " ( o.o ) claude --yolo test suite"
echo "  > ^ <  "
echo ""
echo "  Using real claude at: $REAL_CLAUDE"
echo ""

# ─────────────────────────────────────────────
# Step 1: Check if --yolo exists natively
# ─────────────────────────────────────────────
echo "=== Step 1: Check claude has no native --yolo ==="
direct_version=$("$REAL_CLAUDE" --version 2>&1 || true)
assert_contains "claude binary exists and returns version" "[0-9]\.[0-9]" "$direct_version"
echo ""

# ─────────────────────────────────────────────
# Step 2: Clean slate — remove any existing install
# ─────────────────────────────────────────────
echo "=== Step 2: Ensure clean slate ==="
touch "$FAKE_HOME/.zshrc"
sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
assert_eq "zshrc has no claude-yolo marker" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 3: Try claude --yolo without install — should fail
# ─────────────────────────────────────────────
echo "=== Step 3: verify --yolo is not natively --dangerously-skip-permissions ==="
no_func=$(zsh -c "source '$FAKE_HOME/.zshrc' && type claude" 2>&1 || true)
assert_not_contains "claude is not a function without install" "function" "$no_func"
echo ""

# ─────────────────────────────────────────────
# Step 4: Install
# ─────────────────────────────────────────────
echo "=== Step 4: Install claude --yolo ==="
sh "$SCRIPT_DIR/install.sh"
assert_eq "zshrc has claude-yolo marker" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"

# Verify the installed block contains key elements
ACTUAL_BLOCK=$(sed -n '/>>> claude-yolo >>>/,/<<< claude-yolo <<</p' "$FAKE_HOME/.zshrc")
assert_contains "block has __claude_yolo function" "__claude_yolo()" "$ACTUAL_BLOCK"
assert_contains "block has precmd hook" "add-zsh-hook precmd" "$ACTUAL_BLOCK"
assert_contains "block has --dangerously-skip-permissions rewrite" "dangerously-skip-permissions" "$ACTUAL_BLOCK"
assert_contains "block has __claude_yolo_inner fallback" "__claude_yolo_inner" "$ACTUAL_BLOCK"
assert_contains "block has ccy alias" "alias ccy=" "$ACTUAL_BLOCK"
assert_contains "block has cxy alias" "alias cxy=" "$ACTUAL_BLOCK"
assert_not_contains "block does not add cc alias (conflicts with /usr/bin/cc)" "alias cc=" "$ACTUAL_BLOCK"
assert_not_contains "block does not add cx alias" "alias cx=" "$ACTUAL_BLOCK"

# Verify line count is reasonable
block_lines=$(echo "$ACTUAL_BLOCK" | wc -l | tr -d ' ')
assert_eq "block has 30 lines" "30" "$block_lines"
echo ""

# ─────────────────────────────────────────────
# Step 5: claude --yolo works after install
# ─────────────────────────────────────────────
echo "=== Step 5: claude --yolo works after install ==="

# Version through function matches direct
func_version=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --version" 2>&1 || true)
assert_eq "claude --version through function matches direct" "$direct_version" "$func_version"

# --yolo --version should succeed and match --dangerously-skip-permissions --version
yolo_version=$(zsh -c "source '$FAKE_HOME/.zshrc'; claude --yolo --version" 2>&1 || true)
dsp_version=$("$REAL_CLAUDE" --dangerously-skip-permissions --version 2>&1 || true)
assert_eq "claude --yolo --version matches claude --dangerously-skip-permissions --version" "$dsp_version" "$yolo_version"
assert_contains "yolo version output has version number" "[0-9]\.[0-9]" "$yolo_version"

# Mixed args with fake binary
mkdir -p "$FAKE_HOME/bin"
cat > "$FAKE_HOME/bin/claude" << 'FAKEBIN'
#!/bin/sh
echo "$@"
FAKEBIN
chmod +x "$FAKE_HOME/bin/claude"
mixed=$(zsh -c "export PATH='$FAKE_HOME/bin:\$PATH'; source '$FAKE_HOME/.zshrc'; claude --model opus --yolo --verbose" 2>&1)
assert_eq "mixed args rewritten correctly" "--model opus --dangerously-skip-permissions --verbose" "$mixed"

# Shortcut aliases
ccy_def=$(zsh -c "source '$FAKE_HOME/.zshrc'; alias ccy" 2>&1)
cxy_def=$(zsh -c "source '$FAKE_HOME/.zshrc'; alias cxy" 2>&1)
assert_contains "ccy alias defined" "claude --yolo" "$ccy_def"
assert_contains "cxy alias defined" "codex --yolo" "$cxy_def"

# Idempotent reinstall
reinstall_output=$(sh "$SCRIPT_DIR/install.sh" 2>&1)
assert_contains "reinstall says already up to date" "Already up to date" "$reinstall_output"
assert_eq "reinstall doesn't duplicate" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 6: Update-in-place works
# ─────────────────────────────────────────────
echo "=== Step 6: Update replaces old block ==="
# Simulate an old-format block by replacing the current one
sed -i.bak '/>>> claude-yolo >>>/,/<<< claude-yolo <<</d' "$FAKE_HOME/.zshrc"
rm -f "$FAKE_HOME/.zshrc.bak"
cat >> "$FAKE_HOME/.zshrc" << 'OLD_BLOCK'

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
OLD_BLOCK
assert_eq "old block is present" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"

# Run install — should prompt (block differs) then overwrite with YOLO_ASSUME_YES
install_output=$(YOLO_ASSUME_YES=1 sh "$SCRIPT_DIR/install.sh" 2>&1)
assert_contains "install says Updated" "Updated" "$install_output"
assert_eq "still exactly one marker after update" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"

# Verify it's the new format
UPDATED_BLOCK=$(sed -n '/>>> claude-yolo >>>/,/<<< claude-yolo <<</p' "$FAKE_HOME/.zshrc")
assert_contains "updated block has precmd hook" "add-zsh-hook precmd" "$UPDATED_BLOCK"
assert_contains "updated block has __claude_yolo" "__claude_yolo()" "$UPDATED_BLOCK"
echo ""

# ─────────────────────────────────────────────
# Step 7: Clobbering resilience
# ─────────────────────────────────────────────
echo "=== Step 7: Survives function clobbering ==="

# Test: another tool redefines claude(), then our hook re-wraps
clobber_result=$(zsh -c "
    export PATH='$FAKE_HOME/bin:\$PATH'
    source '$FAKE_HOME/.zshrc'
    # Simulate another tool clobbering claude()
    claude() { command claude \"INNER\" \"\$@\"; }
    # Simulate precmd firing — our hook should re-wrap
    __claude_yolo_hook
    # Now --yolo should work AND chain through the clobbered function
    claude --yolo --test
" 2>&1)
assert_contains "yolo rewrites after clobber" "dangerously-skip-permissions" "$clobber_result"
assert_contains "inner wrapper is preserved" "INNER" "$clobber_result"
echo ""

# ─────────────────────────────────────────────
# Step 8: Uninstall and verify it's gone
# ─────────────────────────────────────────────
echo "=== Step 8: Uninstall and verify removal ==="
sh "$SCRIPT_DIR/uninstall.sh"
assert_eq "zshrc has no marker after uninstall" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
assert_not_contains "zshrc has no __claude_yolo" "__claude_yolo" "$(cat "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 9: Uninstall prompts when the block differs from the expected one.
# Declining keeps the block; accepting (YOLO_ASSUME_YES=1) removes it.
# ─────────────────────────────────────────────
echo "=== Step 9: Uninstall prompts on tampered block, obeys confirmation ==="
sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1
assert_eq "zshrc has marker before tampering" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
sed -i.bak "/>>> claude-yolo >>>/a\\
# INJECTED LINE" "$FAKE_HOME/.zshrc"
rm -f "$FAKE_HOME/.zshrc.bak"

# Decline the prompt (no TTY, no YOLO_ASSUME_YES) → read fails → treated as no.
decline_output=$(sh "$SCRIPT_DIR/uninstall.sh" </dev/null 2>&1 || true)
assert_contains "uninstall shows diff" "doesn't match the expected block" "$decline_output"
assert_contains "uninstall diff shows injected line" "INJECTED LINE" "$decline_output"
assert_eq "marker still present after decline" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"

# Accept via env var — block removed despite mismatch.
YOLO_ASSUME_YES=1 sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
assert_eq "marker removed after YOLO_ASSUME_YES=1" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
assert_not_contains "injected line gone after confirmed uninstall" "INJECTED LINE" "$(cat "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 10: Install prompts when existing block differs; obeys confirmation.
# ─────────────────────────────────────────────
echo "=== Step 10: Install prompts on mismatched block, obeys confirmation ==="
sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1
sed -i.bak "/>>> claude-yolo >>>/a\\
# USER CUSTOM LINE" "$FAKE_HOME/.zshrc"
rm -f "$FAKE_HOME/.zshrc.bak"

# Decline → block untouched.
decline_install=$(sh "$SCRIPT_DIR/install.sh" </dev/null 2>&1 || true)
assert_contains "install shows diff" "differs from the latest" "$decline_install"
assert_contains "install diff shows custom line" "USER CUSTOM LINE" "$decline_install"
assert_contains "custom line still present after decline" "USER CUSTOM LINE" "$(cat "$FAKE_HOME/.zshrc")"

# Accept → overwritten cleanly.
YOLO_ASSUME_YES=1 sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1
assert_eq "still exactly one marker after overwrite" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
assert_not_contains "custom line gone after overwrite" "USER CUSTOM LINE" "$(cat "$FAKE_HOME/.zshrc")"
YOLO_ASSUME_YES=1 sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
echo ""

# ─────────────────────────────────────────────
# Step 11: Legacy block — diff prompt handles older formats cleanly.
# ─────────────────────────────────────────────
echo "=== Step 11: Uninstall handles legacy block via confirmation ==="
cat >> "$FAKE_HOME/.zshrc" << 'LEGACY_BLOCK'

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
LEGACY_BLOCK
assert_eq "legacy block is present" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
YOLO_ASSUME_YES=1 sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
assert_eq "legacy block removed after confirmation" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_HOME/.zshrc")"
echo ""

# ─────────────────────────────────────────────
# Step 12: Bash install/uninstall path works
# ─────────────────────────────────────────────
echo "=== Step 12: Bash install/uninstall works ==="
touch "$FAKE_BASH_HOME/.bashrc"
HOME="$FAKE_BASH_HOME" SHELL="/bin/bash" sh "$SCRIPT_DIR/install.sh" >/dev/null 2>&1
assert_eq "bashrc has claude-yolo marker" "1" "$(count_matches '>>> claude-yolo >>>' "$FAKE_BASH_HOME/.bashrc")"
BASH_BLOCK=$(sed -n '/>>> claude-yolo >>>/,/<<< claude-yolo <<</p' "$FAKE_BASH_HOME/.bashrc")
assert_contains "bash block has PROMPT_COMMAND hook" "PROMPT_COMMAND=" "$BASH_BLOCK"
assert_contains "bash block has __claude_yolo hook" "__claude_yolo_hook()" "$BASH_BLOCK"
assert_contains "bash block has ccy alias" "alias ccy=" "$BASH_BLOCK"
assert_contains "bash block has cxy alias" "alias cxy=" "$BASH_BLOCK"
assert_not_contains "bash block does not add cc alias" "alias cc=" "$BASH_BLOCK"
assert_not_contains "bash block does not add cx alias" "alias cx=" "$BASH_BLOCK"

mkdir -p "$FAKE_BASH_HOME/bin"
cat > "$FAKE_BASH_HOME/bin/claude" << 'FAKEBASHBIN'
#!/bin/sh
echo "$@"
FAKEBASHBIN
chmod +x "$FAKE_BASH_HOME/bin/claude"

bash_clobber_result=$(HOME="$FAKE_BASH_HOME" bash --rcfile "$FAKE_BASH_HOME/.bashrc" -ic "export PATH='$FAKE_BASH_HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'; claude(){ command claude INNER \"\$@\"; }; __claude_yolo_hook; claude --yolo --test" 2>&1)
assert_contains "bash yolo rewrites after clobber" "dangerously-skip-permissions" "$bash_clobber_result"
assert_contains "bash inner wrapper is preserved" "INNER" "$bash_clobber_result"

HOME="$FAKE_BASH_HOME" sh "$SCRIPT_DIR/uninstall.sh" >/dev/null 2>&1
assert_eq "bashrc marker removed on uninstall" "0" "$(count_matches '>>> claude-yolo >>>' "$FAKE_BASH_HOME/.bashrc")"
echo ""

# ─────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────
echo "================================"
echo "  $passed passed, $failed failed"
echo "================================"
echo ""

if [ "$failed" -eq 0 ]; then
    echo "  /\\_/\\  "
    echo " ( ^.^ ) All tests passed! meow~"
    echo "  > ^ <  "
    echo ""
    echo "  Tests ended in uninstalled state."
    echo "  To install for real, run:"
    echo ""
    echo "    sh $SCRIPT_DIR/install.sh"
    echo ""
else
    echo "  /\\_/\\  "
    echo " ( x.x ) Some tests failed!"
    echo "  > ^ <  "
    echo ""
fi

[ "$failed" -eq 0 ]
