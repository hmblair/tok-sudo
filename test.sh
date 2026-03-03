#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════════════════
# tok-sudo integration tests
#
# WARNING: This script OVERWRITES /etc/tok-sudo-token-hash.
#          Any existing tok-sudo token will be destroyed.
#          A new token is generated at the end and printed to stdout.
#
# Usage: sudo ./test.sh
# ══════════════════════════════════════════════════════════════════════════════

# ── ANSI colours ──────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Constants ─────────────────────────────────────────────────────────────────

HASH_FILE="/etc/tok-sudo-token-hash"
EXEC="/usr/local/bin/tok-sudo-exec"
ROTATE="/usr/local/bin/tok-sudo-rotate"
CLI="/usr/local/bin/tok-sudo"
REAL_USER="${SUDO_USER:-$(whoami)}"

PASS=0
FAIL=0

# ── Preamble checks ──────────────────────────────────────────────────────────

[[ "$(id -u)" -eq 0 ]] || { echo "Must run as root: sudo ./test.sh"; exit 1; }
[[ -x "$EXEC" ]]       || { echo "tok-sudo-exec not installed at $EXEC"; exit 1; }
[[ -x "$ROTATE" ]]     || { echo "tok-sudo-rotate not installed at $ROTATE"; exit 1; }
[[ -x "$CLI" ]]        || { echo "tok-sudo not installed at $CLI"; exit 1; }

echo ""
echo -e "${BOLD}tok-sudo integration tests${NC}"
echo -e "${RED}WARNING: This will overwrite $HASH_FILE${NC}"
echo ""

# ── Helpers ───────────────────────────────────────────────────────────────────

pass() {
    PASS=$((PASS + 1))
    echo -e "  ${GREEN}PASS${NC}: $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo -e "  ${RED}FAIL${NC}: $1"
    [[ -z "${2:-}" ]] || echo "        $2"
}

sha256() {
    echo -n "$1" | { sha256sum 2>/dev/null || shasum -a 256; } | cut -d' ' -f1
}

strip_ansi() {
    sed 's/\x1b\[[0-9;]*m//g'
}

# Run tok-sudo-exec with a hash piped to stdin.
# Sets: LAST_RC, LAST_STDOUT, LAST_STDERR
run_exec() {
    local hash="$1"; shift
    local tmpout tmperr
    tmpout=$(mktemp)
    tmperr=$(mktemp)
    LAST_RC=0
    echo "$hash" | "$EXEC" "$@" >"$tmpout" 2>"$tmperr" || LAST_RC=$?
    LAST_STDOUT=$(cat "$tmpout")
    LAST_STDERR=$(cat "$tmperr")
    rm -f "$tmpout" "$tmperr"
}

assert_exec_fails() {
    local substring="$1" name="$2"
    if [[ "$LAST_RC" -eq 0 ]]; then
        fail "$name" "expected non-zero exit, got 0"
    elif echo "$LAST_STDERR" | grep -q "$substring"; then
        pass "$name"
    else
        fail "$name" "stderr missing '$substring': $(echo "$LAST_STDERR" | strip_ansi)"
    fi
}

assert_exec_succeeds() {
    local name="$1"
    if [[ "$LAST_RC" -ne 0 ]]; then
        fail "$name" "expected exit 0, got $LAST_RC: $(echo "$LAST_STDERR" | strip_ansi)"
    else
        pass "$name"
    fi
}

# ── Cleanup trap ──────────────────────────────────────────────────────────────

cleanup() {
    echo ""
    echo -e "${BOLD}── cleanup ─────────────────────────────────────────${NC}"
    local raw token
    raw=$("$ROTATE" 2>&1) || true
    token=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$' || echo "(could not extract)")
    echo "  New token: $token"
    echo ""
    echo -e "${BOLD}── results ─────────────────────────────────────────${NC}"
    echo -e "  ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}"
    if [[ "$FAIL" -gt 0 ]]; then
        exit 1
    fi
}
trap cleanup EXIT

# ── Disable errexit for test body ─────────────────────────────────────────────

set +e

# ══════════════════════════════════════════════════════════════════════════════
# Section A: tok-sudo CLI argument parsing
# ══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}── tok-sudo CLI ────────────────────────────────────${NC}"

# A1: --help exits 0
out=$(sudo -u "$REAL_USER" "$CLI" --help 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "Usage"; then
    pass "cli: --help exits 0"
else
    fail "cli: --help exits 0" "rc=$rc"
fi

# A2: -h exits 0
out=$(sudo -u "$REAL_USER" "$CLI" -h 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "Usage"; then
    pass "cli: -h exits 0"
else
    fail "cli: -h exits 0" "rc=$rc"
fi

# A3: --version exits 0
out=$(sudo -u "$REAL_USER" "$CLI" --version 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "tok-sudo"; then
    pass "cli: --version exits 0"
else
    fail "cli: --version exits 0" "rc=$rc"
fi

# A4: -v exits 0
out=$(sudo -u "$REAL_USER" "$CLI" -v 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "tok-sudo"; then
    pass "cli: -v exits 0"
else
    fail "cli: -v exits 0" "rc=$rc"
fi

# A5: no token, no args exits 1
out=$(sudo -u "$REAL_USER" env -u TOK_SUDO_TOKEN "$CLI" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "Usage"; then
    pass "cli: no token no args exits 1"
else
    fail "cli: no token no args exits 1" "rc=$rc"
fi

# A6: token set but no command exits 1
out=$(sudo -u "$REAL_USER" env TOK_SUDO_TOKEN=x "$CLI" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "Usage"; then
    pass "cli: token but no command exits 1"
else
    fail "cli: token but no command exits 1" "rc=$rc"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Section B: tok-sudo-exec security validation
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}── tok-sudo-exec validation ────────────────────────${NC}"

# B1: no arguments
run_exec "x"
assert_exec_fails "missing arguments" "exec: no arguments"

# B2: TTY stdin rejected
if command -v script >/dev/null 2>&1; then
    if [[ "$(uname)" == "Darwin" ]]; then
        out=$(script -q /dev/null "$EXEC" echo hi 2>&1) || true
    else
        out=$(script -qec "$EXEC echo hi" /dev/null 2>&1) || true
    fi
    if echo "$out" | grep -q "internal command"; then
        pass "exec: TTY stdin rejected"
    else
        fail "exec: TTY stdin rejected" "output: $(echo "$out" | strip_ansi | head -1)"
    fi
else
    echo -e "  ${YELLOW}SKIP${NC}: exec: TTY stdin rejected (script not found)"
fi

# B3: empty hash rejected
run_exec "" echo hi
assert_exec_fails "empty token" "exec: empty hash rejected"

# B4: hash file missing
rm -f "$HASH_FILE"
run_exec "somehash" echo hi
assert_exec_fails "token not configured" "exec: hash file missing"

# B5: hash file not owned by root
echo "fakehash" > "$HASH_FILE"
chown nobody "$HASH_FILE" 2>/dev/null || chown 65534 "$HASH_FILE"
chmod 600 "$HASH_FILE"
run_exec "somehash" echo hi
assert_exec_fails "not owned by root" "exec: hash file not owned by root"

# B6: hash file empty
: > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"
run_exec "somehash" echo hi
assert_exec_fails "token not configured" "exec: hash file empty"

# B7: malformed hash rejected
echo "not-a-valid-hash" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"
run_exec "wronghash" echo hi
assert_exec_fails "malformed" "exec: malformed hash rejected"

# B8: correct hash accepted
TEST_TOKEN="testtoken123"
TEST_HASH=$(sha256 "$TEST_TOKEN")
echo "$TEST_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
assert_exec_succeeds "exec: correct hash accepted"
if [[ "$LAST_STDOUT" == "hi" ]]; then
    pass "exec: correct hash stdout"
else
    fail "exec: correct hash stdout" "expected 'hi', got '$LAST_STDOUT'"
fi

# B9: multi-arg passthrough
run_exec "$TEST_HASH" echo hello world
assert_exec_succeeds "exec: multi-arg passthrough"
if [[ "$LAST_STDOUT" == "hello world" ]]; then
    pass "exec: multi-arg stdout"
else
    fail "exec: multi-arg stdout" "expected 'hello world', got '$LAST_STDOUT'"
fi

# B10: symlinked hash file rejected (even if target is root-owned)
SYMLINK_TARGET=$(mktemp)
echo "$TEST_HASH" > "$SYMLINK_TARGET"
chown 0:0 "$SYMLINK_TARGET"
chmod 600 "$SYMLINK_TARGET"
rm -f "$HASH_FILE"
ln -s "$SYMLINK_TARGET" "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
assert_exec_fails "symlink" "exec: symlinked hash file (root-owned target)"
rm -f "$HASH_FILE" "$SYMLINK_TARGET"

# B11: symlinked hash file to non-root owner rejected
SYMLINK_TARGET=$(mktemp -p /tmp)
echo "$TEST_HASH" > "$SYMLINK_TARGET"
chown 65534 "$SYMLINK_TARGET"
chmod 644 "$SYMLINK_TARGET"
ln -s "$SYMLINK_TARGET" "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
assert_exec_fails "symlink" "exec: symlinked hash file (non-root target)"
rm -f "$HASH_FILE" "$SYMLINK_TARGET"
# Restore a valid hash file for subsequent tests
echo "$TEST_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"

# B12: hash file with trailing whitespace / extra lines
printf '%s \n\nextra\n' "$TEST_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
# cat + command substitution strips trailing newlines, but the leading line
# will include the hash plus a trailing space. This should NOT match.
if [[ "$LAST_RC" -ne 0 ]]; then
    pass "exec: hash file with trailing whitespace rejected"
else
    fail "exec: hash file with trailing whitespace rejected" "expected failure, got success"
fi
# Restore clean hash file
echo "$TEST_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"

# B13: nonexistent command
run_exec "$TEST_HASH" /usr/bin/this-command-does-not-exist-xyz
if [[ "$LAST_RC" -ne 0 ]]; then
    pass "exec: nonexistent command fails"
else
    fail "exec: nonexistent command fails" "expected non-zero exit"
fi

# B14: world-readable hash file rejected
echo "$TEST_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 644 "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
assert_exec_fails "accessible to non-root" "exec: world-readable hash file rejected"

# B15: group-readable hash file rejected
chmod 640 "$HASH_FILE"
run_exec "$TEST_HASH" echo hi
assert_exec_fails "accessible to non-root" "exec: group-readable hash file rejected"
# Restore
chmod 600 "$HASH_FILE"

# B16: exit code propagation
run_exec "$TEST_HASH" true
if [[ "$LAST_RC" -eq 0 ]]; then
    pass "exec: exit code 0 from true"
else
    fail "exec: exit code 0 from true" "got $LAST_RC"
fi
run_exec "$TEST_HASH" false
if [[ "$LAST_RC" -eq 1 ]]; then
    pass "exec: exit code 1 from false"
else
    fail "exec: exit code 1 from false" "got $LAST_RC"
fi

# B17: tok-sudo-rotate blocked through tok-sudo-exec
run_exec "$TEST_HASH" tok-sudo-rotate
assert_exec_fails "tok-sudo-rotate cannot be run through tok-sudo" "exec: tok-sudo-rotate blocked"

# B18: tok-sudo-rotate blocked via absolute path
run_exec "$TEST_HASH" /usr/local/bin/tok-sudo-rotate
assert_exec_fails "tok-sudo-rotate cannot be run through tok-sudo" "exec: tok-sudo-rotate blocked (absolute path)"

# ══════════════════════════════════════════════════════════════════════════════
# Section C: tok-sudo-rotate
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}── tok-sudo-rotate ─────────────────────────────────${NC}"

# C1: non-root rejected
out=$(sudo -u nobody "$ROTATE" 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "must be run as root"; then
    pass "rotate: non-root rejected"
else
    fail "rotate: non-root rejected" "rc=$rc"
fi

# C2: --help exits 0
out=$("$ROTATE" --help 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "Usage"; then
    pass "rotate: --help exits 0"
else
    fail "rotate: --help exits 0" "rc=$rc"
fi

# C3: -v exits 0
out=$("$ROTATE" -v 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "tok-sudo-rotate"; then
    pass "rotate: -v exits 0"
else
    fail "rotate: -v exits 0" "rc=$rc"
fi

# C4: produces 32-char alphanumeric token
raw=$("$ROTATE" 2>&1); rc=$?
ROTATE_TOKEN=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$')
if [[ $rc -eq 0 ]] && [[ ${#ROTATE_TOKEN} -eq 32 ]]; then
    pass "rotate: produces 32-char token"
else
    fail "rotate: produces 32-char token" "rc=$rc, token='$ROTATE_TOKEN'"
fi

# C5: hash file permissions
if [[ -f "$HASH_FILE" ]]; then
    perms=$(stat -c %a "$HASH_FILE" 2>/dev/null || stat -f %Lp "$HASH_FILE")
    owner=$(stat -c %u "$HASH_FILE" 2>/dev/null || stat -f %u "$HASH_FILE")
    if [[ "$perms" == "600" ]] && [[ "$owner" == "0" ]]; then
        pass "rotate: hash file perms 600, owned by root"
    else
        fail "rotate: hash file perms 600, owned by root" "perms=$perms, owner=$owner"
    fi
else
    fail "rotate: hash file perms 600, owned by root" "hash file does not exist"
fi

# C6: stored hash matches token
if [[ -n "$ROTATE_TOKEN" ]]; then
    expected=$(sha256 "$ROTATE_TOKEN")
    stored=$(cat "$HASH_FILE")
    if [[ "$expected" == "$stored" ]]; then
        pass "rotate: stored hash matches token"
    else
        fail "rotate: stored hash matches token" "expected=$expected, stored=$stored"
    fi
else
    fail "rotate: stored hash matches token" "no token from C4"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Section D: end-to-end flow
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}── end-to-end ──────────────────────────────────────${NC}"

# D1: rotate then tok-sudo succeeds
raw=$("$ROTATE" 2>&1)
TOKEN_D1=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$')
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D1" "$CLI" echo e2e-test 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "e2e-test"; then
    pass "e2e: rotate then tok-sudo succeeds"
else
    fail "e2e: rotate then tok-sudo succeeds" "rc=$rc, out=$(echo "$out" | strip_ansi)"
fi

# D2: old token rejected after re-rotate
OLD_TOKEN="$TOKEN_D1"
raw=$("$ROTATE" 2>&1)
TOKEN_D2=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$')
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$OLD_TOKEN" "$CLI" echo should-fail 2>&1); rc=$?
if [[ $rc -ne 0 ]] && echo "$out" | grep -q "invalid token"; then
    pass "e2e: old token rejected after rotate"
else
    fail "e2e: old token rejected after rotate" "rc=$rc, out=$(echo "$out" | strip_ansi)"
fi

# D3: new token works after re-rotate
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D2" "$CLI" echo should-pass 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "should-pass"; then
    pass "e2e: new token works after rotate"
else
    fail "e2e: new token works after rotate" "rc=$rc, out=$(echo "$out" | strip_ansi)"
fi

# D4: exit code propagation through tok-sudo
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D2" "$CLI" true 2>&1); rc=$?
if [[ $rc -eq 0 ]]; then
    pass "e2e: exit code 0 propagates"
else
    fail "e2e: exit code 0 propagates" "got $rc"
fi
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D2" "$CLI" false 2>&1); rc=$?
if [[ $rc -eq 1 ]]; then
    pass "e2e: exit code 1 propagates"
else
    fail "e2e: exit code 1 propagates" "got $rc"
fi

# D5: command with special characters in arguments
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D2" "$CLI" sh -c 'echo "hello world"' 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "hello world"; then
    pass "e2e: sh -c with quoted args"
else
    fail "e2e: sh -c with quoted args" "rc=$rc, out=$(echo "$out" | strip_ansi)"
fi

# D6: token with shell metacharacters
# Set up a hash file for a token containing $, backticks, and spaces
NASTY_TOKEN='$HOME $(whoami) `id`'
NASTY_HASH=$(sha256 "$NASTY_TOKEN")
echo "$NASTY_HASH" > "$HASH_FILE"
chown 0:0 "$HASH_FILE"
chmod 600 "$HASH_FILE"
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$NASTY_TOKEN" "$CLI" echo safe 2>&1); rc=$?
if [[ $rc -eq 0 ]] && echo "$out" | grep -q "safe"; then
    pass "e2e: token with shell metacharacters"
else
    fail "e2e: token with shell metacharacters" "rc=$rc, out=$(echo "$out" | strip_ansi)"
fi

# D7: stdin passthrough
raw=$("$ROTATE" 2>&1)
TOKEN_D7=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$')
out=$(echo "stdin-content" | sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D7" "$CLI" cat 2>&1); rc=$?
if [[ $rc -eq 0 ]] && [[ "$out" == "stdin-content" ]]; then
    pass "e2e: stdin passthrough"
else
    fail "e2e: stdin passthrough" "rc=$rc, out='$(echo "$out" | strip_ansi)'"
fi

# D8: stdin passthrough with multiple lines
out=$(printf 'line1\nline2\nline3' | sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D7" "$CLI" cat 2>&1); rc=$?
expected=$(printf 'line1\nline2\nline3')
if [[ $rc -eq 0 ]] && [[ "$out" == "$expected" ]]; then
    pass "e2e: stdin passthrough multi-line"
else
    fail "e2e: stdin passthrough multi-line" "rc=$rc, out='$(echo "$out" | strip_ansi)'"
fi

# D9: stdin passthrough with tee
TEETMP=$(mktemp)
echo "tee-content" | sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D7" "$CLI" tee "$TEETMP" >/dev/null 2>&1; rc=$?
tee_got=$(cat "$TEETMP")
rm -f "$TEETMP"
if [[ $rc -eq 0 ]] && [[ "$tee_got" == "tee-content" ]]; then
    pass "e2e: stdin passthrough with tee"
else
    fail "e2e: stdin passthrough with tee" "rc=$rc, file='$tee_got'"
fi

# D10: nonexistent command through tok-sudo
raw=$("$ROTATE" 2>&1)
TOKEN_D10=$(echo "$raw" | strip_ansi | grep -o '[a-zA-Z0-9]\{32\}$')
out=$(sudo -u "$REAL_USER" env "TOK_SUDO_TOKEN=$TOKEN_D10" "$CLI" /usr/bin/this-does-not-exist-xyz 2>&1); rc=$?
if [[ $rc -ne 0 ]]; then
    pass "e2e: nonexistent command fails"
else
    fail "e2e: nonexistent command fails" "expected non-zero exit"
fi

# ══════════════════════════════════════════════════════════════════════════════
# Section E: make install correctness
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${BOLD}── make install ────────────────────────────────────${NC}"

SRCDIR="$(cd "$(dirname "$0")" && pwd)"

if [[ -f "$SRCDIR/Makefile" ]]; then
    # Run make install from the project directory
    make -C "$SRCDIR" install >/dev/null 2>&1; rc=$?
    if [[ $rc -eq 0 ]]; then
        pass "install: make install succeeds"
    else
        fail "install: make install succeeds" "exit $rc"
    fi

    # E1: sudoers entry contains the real user, not root
    SUDOERS="/etc/sudoers.d/tok-sudo"
    if [[ -f "$SUDOERS" ]]; then
        entry=$(cat "$SUDOERS")
        if echo "$entry" | grep -q "^${REAL_USER} "; then
            pass "install: sudoers entry has correct user"
        else
            fail "install: sudoers entry has correct user" "got: $entry"
        fi
    else
        fail "install: sudoers entry has correct user" "sudoers file missing"
    fi

    # E2: installed scripts have VERSION substituted
    all_clean=true
    for s in tok-sudo tok-sudo-exec tok-sudo-rotate; do
        if grep -q '@VERSION@' "/usr/local/bin/$s" 2>/dev/null; then
            fail "install: $s has VERSION substituted" "still contains @VERSION@"
            all_clean=false
        fi
    done
    if $all_clean; then
        pass "install: all scripts have VERSION substituted"
    fi

    # E3: installed scripts are executable
    all_exec=true
    for s in tok-sudo tok-sudo-exec tok-sudo-rotate; do
        if [[ ! -x "/usr/local/bin/$s" ]]; then
            fail "install: $s is executable" "not executable"
            all_exec=false
        fi
    done
    if $all_exec; then
        pass "install: all scripts are executable"
    fi
else
    echo -e "  ${YELLOW}SKIP${NC}: make install tests (Makefile not found)"
fi

# (EXIT trap fires: rotates fresh token, prints summary)
