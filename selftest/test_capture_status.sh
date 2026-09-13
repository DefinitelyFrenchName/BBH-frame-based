#!/bin/sh
# test_capture_status.sh — no shell script of the harness captures a command's OWN exit status unprotected under errexit: in a `set -e` script, a capture whose last command is `echo "exit=$?"` (or `rc=`) runs its command inside `(set +e; …)`, or a failing command ends the WHOLE script before its FAIL line prints. ROM-free, ~1 s.
#
# MUST-FIRE: known-bad: unprotected-capture — a synthetic `set -e` script carrying one unprotected status capture must be reported by the scan (mode: the same line appended to a copy of the harness's real shell scripts must FAIL this gate)
#
# WHY (2026-09-13). selftest/test_fidelity_vampire.sh's F11 captured the
# consumer's `gen_skill_guide.py --check` this way. When a guide went stale the
# check exited 1, the capture's subshell died under the inherited errexit
# before its `echo exit=`, and the assignment ended the script: no FAIL line,
# no F2, no verdict — a red that did not say why. Reproduced in a clean
# worktree of the consumer (33 lines, against 38 on the unperturbed control);
# F4, F6, F7 and F10 were already written `(set +e; …)`, F11 was not.
#
# THE SHAPE, and why it is precise: a capture ending in `echo "exit=$?"` or
# `echo "rc=$?"` exists to RECORD a status that may be non-zero, so under
# errexit it is either protected or a bug. The capture must close right after
# that echo — an `echo "rc=$?"` inside an `sh -c '…'` string runs in a child
# shell without errexit and is not the shape. Comment lines are not scanned.
# §3 measures the rule on this host's sh.
#
# Usage: selftest/test_capture_status.sh
set -eu
BBH_HOME="$(cd "$(dirname "$0")/.." && pwd)"; export BBH_HOME
. "$BBH_HOME/lib/sh/controls.sh"
bbh_ctl_mode "$0"
rc=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; rc=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT INT TERM

# The fixture lines, assembled from pieces so this file never carries the shape it bars.
D='$'
BAD="x=\"${D}(false 2>&1; echo \"exit=${D}?\")\""
GOOD="x=\"${D}( (set +e; false 2>&1; echo \"exit=${D}?\") )\""
SHC="y=\"${D}(sh -c 'false; echo \"rc=${D}?\"' _ z)\""
RX='\$\(.*;[[:space:]]*echo "?(exit|rc)=\$\?"?\)"?[[:space:]]*(;|$|#|\))'
DIRS="selftest lib bin drivers example/tests"

scan() {  # scan <root> <subdir>... — <path>:<line> of every unprotected status capture in a set -e shell script
    _root="$1"; shift
    for _s in "$@"; do
        [ -e "$_root/$_s" ] || continue
        find "$_root/$_s" -type f | sort | while read -r _f; do
            head -1 "$_f" 2>/dev/null | grep -q 'sh' || continue
            grep -qE '^set -[a-z]*e' "$_f" || continue
            grep -nE "$RX" "$_f" | grep -vE 'set \+e|^[0-9]+:[[:space:]]*#' | sed "s|^|${_f#"$_root"/}:|" || true
        done
    done
}
perturb() {  # perturb <copy-root> — the harness's shell scripts copied, ONE unprotected capture appended to one
    for _s in $DIRS; do
        [ -e "$BBH_HOME/$_s" ] || continue
        mkdir -p "$1/$(dirname "$_s")" && cp -R "$BBH_HOME/$_s" "$1/$_s"
    done
    printf '%s\n' "$BAD" >> "$1/selftest/test_capture_status.sh"
}

ROOT="$BBH_HOME"
if bbh_ctl_is unprotected-capture; then perturb "$W/mode"; ROOT="$W/mode"; echo "  mode: one unprotected capture appended to a copy of selftest/test_capture_status.sh"; fi

echo "== 1. the control and the allowed shapes =="
mkdir -p "$W/syn/t"
printf '#!/bin/sh\nset -eu\n%s\n' "$BAD" > "$W/syn/t/bad.sh"
printf '#!/bin/sh\nset -eu\n%s\n%s\n# %s\n' "$GOOD" "$SHC" "$BAD" > "$W/syn/t/good.sh"
printf '#!/bin/sh\n%s\n' "$BAD" > "$W/syn/t/no_errexit.sh"
out="$(scan "$W/syn" t)"
if printf '%s\n' "$out" | grep -q '^t/bad.sh:3:'; then bbh_ctl_fired unprotected-capture "the synthetic set -e capture is reported (t/bad.sh:3)"
else bbh_ctl_dead unprotected-capture "the synthetic unprotected capture was not reported: '$out'" || rc=1; fi
n="$(printf '%s\n' "$out" | awk 'NF' | wc -l | tr -d ' ')"
if [ "$n" = 1 ]; then ok "the protected form, an sh -c string, a commented copy and a script without errexit are not reported"
else fail "the scan reported $n line(s) where only t/bad.sh:3 is the shape: '$out'"; fi

echo "== 2. the harness's own shell scripts ($DIRS) =="
real="$(scan "$ROOT" $DIRS)"
if [ -z "$real" ]; then ok "no unprotected status capture"
else fail "unprotected status capture(s) — run the command inside (set +e; …):"; printf '%s\n' "$real" | sed 's/^/        /'; fi

echo "== 3. the measurement the rule rests on (this host's sh) =="
printf '#!/bin/sh\nset -eu\n%s\necho reached\n' "$BAD" > "$W/m.sh"
m="$(sh "$W/m.sh" 2>&1)" && st=0 || st=$?
if [ "$m" = reached ]; then ok "this sh continues past an unprotected status capture (exit $st); the rule still holds where errexit reaches the capture (macOS /bin/sh)"
else ok "this sh ENDS the script at an unprotected status capture (exit $st, 'reached' never printed) — the behaviour the rule exists for"; fi

echo
[ "$rc" = 0 ] && echo "PASS: no unprotected status capture under errexit" || { echo "FAIL: an unprotected status capture under errexit (see above)"; exit 1; }
