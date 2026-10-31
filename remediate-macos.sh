#!/usr/bin/env bash
# Removes the backdoor from tampered copies of the Claude Code extension for VS Code-based editors (macOS).
# Run once as each affected user, without sudo. Exits 1 if anything is left behind.
set -uo pipefail
shopt -s nullglob
[[ $EUID -ne 0 ]] || { echo "run as the affected user, not root" >&2; exit 1; }

MARKER='svc-telemetry'
export KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDdvylCEJ/k2TpezcTfedrkHyFSK9IZ3vmP6vhY4Ss0P $MARKER"
# Both tunnel loops pass one of the two key files to ssh -i; the LaunchAgent runs .smt.
PROCS='/\.stk_[0-9a-f]{10}|/\.config/\.smtk|^/bin/sh .*/\.config/\.smt$'
AUTH_KEYS=~/.ssh/authorized_keys
USER_TMP=$(getconf DARWIN_USER_TEMP_DIR) TMP_DIR=${TMPDIR:-/tmp}
rc=0 found=0
fixed() { echo "$*"; found=1; }

# Persistence and running tunnels
for domain in gui user; do
    launchctl bootout "$domain/$(id -u)/com.apple.sysmond" 2>/dev/null && fixed "unloaded launchd job $domain/com.apple.sysmond"
done
pkill -f "$PROCS" && fixed "killed tunnel processes"

# Infected extensions. The tampered bundle keeps the real version number, so match on content.
for js in ~/.[!.]*/extensions/anthropic.claude-code-*/extension.js; do
    grep -qF "$MARKER" "$js" && { rm -rf "${js%/*}" && fixed "removed ${js%/*}" || rc=1; }
done

# Dropped files
for f in ~/Library/LaunchAgents/com.apple.sysmond.plist ~/.config/.smt ~/.config/.smtk \
    "${USER_TMP:-/tmp/}".stk_* "${TMP_DIR%/}"/.stk_* /tmp/.stk_*; do
    [[ -e $f ]] && { rm -f "$f" && fixed "removed $f" || rc=1; }
done

# Attacker key. It's appended without a leading newline, so it may share a line with a real key.
# Writing back through the existing file keeps symlinks, ownership and mode.
if [[ -f $AUTH_KEYS ]] && grep -qF "$KEY" "$AUTH_KEYS"; then
    tmp=$(mktemp)
    perl -0pe 's/^\Q$ENV{KEY}\E\n//mg; s/\Q$ENV{KEY}\E//g' "$AUTH_KEYS" >"$tmp" &&
        cat "$tmp" >"$AUTH_KEYS" && fixed "removed key from $AUTH_KEYS"
    rm -f "$tmp"
fi

# Report
pgrep -fl "$PROCS" >&2 && { echo "tunnel processes still running" >&2; rc=1; }
grep -qF "$KEY" "$AUTH_KEYS" 2>/dev/null && { echo "key still in $AUTH_KEYS" >&2; rc=1; }
if (( rc )); then
    echo "incomplete: see errors above" >&2
elif (( found )); then
    nc -z -G1 127.0.0.1 22 2>/dev/null && echo "note: something listens on localhost:22; the tunnel exposed it"
    echo "done: backdoor removed"
else
    echo "clean: no backdoor found"
fi
exit $rc
