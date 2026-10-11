#!/bin/sh
# test_agent_hooks.sh — the agent-discipline hooks decide what the evidence says: pre_bash.py DENIES every detached launch and pgrep waiter in its frozen fixture (the twelve nohup launches that opened the lineage's #172 among them) and ALLOWS the real look-alikes, pre_agent.py refuses an over-cap or under-specified Agent call and passes forks, both fail open, and .claude/settings.json still wires them with the edit-lock. ~3 s, no instrument.
#
# MUST-FIRE: perturbed-copy: blind-classifier — a copy of the hooks whose `detach_reason` always answers "no detach" must let the fixture's launches through, and the gate must FAIL on them (mode: the gate runs against that copy)
# MUST-FIRE: perturbed-copy: greedy-heredoc — a copy whose `strip_heredocs` swallows every line after an UNTERMINATED `<<` operator must hide the `nohup` in the arithmetic-shift rows, and the gate must FAIL on the must-deny side (mode: the gate runs against that copy)
# MUST-FIRE: perturbed-copy: no-heredoc-strip — a copy whose `strip_heredocs` returns the command unchanged must deny commands that only WRITE a script containing `&`, and the gate must FAIL on the must-allow side (mode: the gate runs against that copy)
# MUST-FIRE: perturbed-copy: open-agent-gate — a copy of the call gate whose `decide` allows every call must let an over-cap Agent call through, and the gate must FAIL on the must-deny call cases (mode: the gate drives that copy)
# MUST-FIRE: known-bad: unwired-settings — a copy of .claude/settings.json with the Bash hook removed must be refused by the installation check, and the gate must FAIL (mode: the check reads that copy)
#
# WHY. A job the agent detaches (`nohup`, `setsid`, `disown`, a trailing `&`)
# can never produce a completion notification, so once the agent ends its turn
# nothing wakes it: in the lineage (14z-174) all twelve long jobs of one sitting
# were `nohup` launches and eleven idle gaps ended only when the maintainer asked
# for status. A worker called with a model, or a built-in called with none,
# runs above the caps its definition states. Both hooks FAIL OPEN, because a
# hook bug must not stop the work; this gate is what keeps the logic from dying
# silently. The installation check exists because a settings edit that drops a
# hook switches the enforcement off with every other gate green.
#
# The fixture (selftest/agent/c01_commands.jsonl, 44 rows) was cut from the
# lineage's real session transcripts: must-deny launches and must-allow
# look-alikes (a `&` in a heredoc body or a quoted string, a foreground parallel
# run ending in `wait`, `&&` chains), beside synthetic edge cases.
#
# Lineage: tests/test_agent_hooks.sh @ dbaed3a0 (GitHub #172 slices S1, S4),
# ported 2026-10-07 (Phase A of docs/agents_scope.md). Not ported: the push hook,
# its ledger and its hint (R1; a bbh push gate is an open question since
# 2026-10-11), and the transcript census.
#
# Usage: selftest/test_agent_hooks.sh
set -eu
BBH_HOME="$(cd "$(dirname "$0")/.." && pwd)"; export BBH_HOME
. "$BBH_HOME/lib/sh/controls.sh"
bbh_ctl_mode "$0"
cd "$BBH_HOME"
rc=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; rc=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT INT TERM
FIX=selftest/agent/c01_commands.jsonl
CASES=selftest/agent/pre_agent_cases.py
export PYTHONDONTWRITEBYTECODE=1

# make_copy <name> — a copy of .claude/agent with ONE perturbation, for the controls
make_copy() {
    mkdir -p "$W/$1"; cp -R .claude/agent "$W/$1/agent"
    case "$1" in
        blind-classifier)
            python3 - "$W/$1/agent/agentlib.py" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
a = 'def detach_reason(cmd):\n'
assert s.count(a) == 1
s = s.replace(a, a + '    return None  # CONTROL blind-classifier\n', 1)
open(p, 'w').write(s)
PY
            ;;
        greedy-heredoc)
            python3 - "$W/$1/agent/agentlib.py" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
a = '            if end is not None:\n                i = end + 1\n'
assert s.count(a) == 1
s = s.replace(a, '            i = end + 1 if end is not None else len(lines)  # CONTROL greedy-heredoc\n', 1)
open(p, 'w').write(s)
PY
            ;;
        no-heredoc-strip)
            python3 - "$W/$1/agent/agentlib.py" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
a = 'def strip_heredocs(cmd):\n'
assert s.count(a) == 1
s = s.replace(a, a + '    return cmd  # CONTROL no-heredoc-strip\n', 1)
open(p, 'w').write(s)
PY
            ;;
        open-agent-gate)
            python3 - "$W/$1/agent/hooks/pre_agent.py" <<'PY'
import sys; p = sys.argv[1]; s = open(p).read()
a = '    """-> (decision, reason); decision is \'deny\' or None."""\n'
assert s.count(a) == 1
s = s.replace(a, a + '    return None, None  # CONTROL open-agent-gate\n', 1)
open(p, 'w').write(s)
PY
            ;;
    esac
    echo "$W/$1/agent"
}

# replay <agent dir> <out> — every fixture row through the Bash hook, one line per mismatch
replay() {
    python3 - "$1/hooks/pre_bash.py" "$FIX" > "$2" <<'PY'
import json, subprocess, sys
hook, fix = sys.argv[1:3]
bad = n = 0
for line in open(fix):
    row = json.loads(line); n += 1
    ev = {"hook_event_name": "PreToolUse", "tool_name": "Bash", "tool_input": {"command": row["command"]}}
    p = subprocess.run([sys.executable, hook], input=json.dumps(ev), capture_output=True, text=True)
    got = "allow"
    if p.returncode != 0:
        got = f"exit{p.returncode}"
    elif p.stdout.strip():
        got = json.loads(p.stdout)["hookSpecificOutput"]["permissionDecision"]
    if got != row["expect"]:
        bad += 1
        print(f"MISMATCH expect={row['expect']} got={got} [{row['source']}] {row['why']} :: {' '.join(row['command'].split())[:90]}")
print(f"ROWS {n} MISMATCHES {bad}")
PY
}

# wiring <settings.json> — the installation: Bash wired to pre_bash.py, Agent|Task to
# pre_agent.py, and the three edit-lock rules; prints findings, exit 1 on any
wiring() {
    python3 - "$1" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"settings unreadable ({e})"); sys.exit(1)
def cmds(matcher):
    return [h.get("command", "") for m in s.get("hooks", {}).get("PreToolUse", []) if m.get("matcher") == matcher
            for h in m.get("hooks", []) if h.get("type") == "command"]
deny = set(s.get("permissions", {}).get("deny", []))
need = {"Edit(.claude/settings.json)", "Edit(.claude/agent/hooks/**)", "Edit(.claude/agent/agentlib.py)"}
bad = []
if not any(".claude/agent/hooks/pre_bash.py" in c for c in cmds("Bash")):
    bad.append("no PreToolUse Bash hook runs .claude/agent/hooks/pre_bash.py")
if not any(".claude/agent/hooks/pre_agent.py" in c for c in cmds("Agent|Task")):
    bad.append("no PreToolUse Agent|Task hook runs .claude/agent/hooks/pre_agent.py")
if need - deny:
    bad.append(f"edit-lock rules missing: {sorted(need - deny)}")
for b in bad:
    print(b)
sys.exit(1 if bad else 0)
PY
}

# unwire <settings.json> <out> — a copy with every Bash PreToolUse entry removed; exit 1 when
# the input cannot be read (a control planted on a missing file would fire on the missing file)
unwire() {
    python3 - "$1" "$2" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1]))
    s["hooks"]["PreToolUse"] = [m for m in s["hooks"]["PreToolUse"] if m.get("matcher") != "Bash"]
except Exception as e:
    print(f"{sys.argv[1]} unreadable ({e})"); sys.exit(1)
json.dump(s, open(sys.argv[2], "w"), indent=2)
PY
}

echo "== the Bash hook over its frozen fixture"
n_deny=$(grep -c '"expect": "deny"' "$FIX"); n_allow=$(grep -c '"expect": "allow"' "$FIX")
n_174=$(grep -c '"source": "d5b070d5:' "$FIX")
echo "        fixture: $n_deny must-deny ($n_174 of them the lineage's 14z-174 launches), $n_allow must-allow"
if [ "$n_174" -eq 12 ]; then ok "the fixture carries the twelve 14z-174 launches"; else fail "the fixture must carry the twelve 14z-174 launches (has $n_174)"; fi

AG=.claude/agent
case "${BBH_CTL:-}" in
    blind-classifier|greedy-heredoc|no-heredoc-strip|open-agent-gate)
        AG="$(make_copy "$BBH_CTL")"; echo "  mode: the hooks under test are a copy with $BBH_CTL planted";;
esac
replay "$AG" "$W/replay.txt"
sed -n '/^MISMATCH/p' "$W/replay.txt" | head -12 | sed 's/^/        /'
if grep -q ' MISMATCHES 0$' "$W/replay.txt"; then ok "every fixture row decided as expected ($(tail -1 "$W/replay.txt"))"
else fail "the Bash hook's decisions disagree with the fixture ($(tail -1 "$W/replay.txt"))"; fi

echo "== fail-open: a malformed event is allowed and recorded"
for h in pre_bash pre_agent; do
    E="$W/errroot_$h"; mkdir -p "$E"
    out="$(printf 'not json' | CLAUDE_PROJECT_DIR="$E" python3 "$AG/hooks/$h.py")" && hrc=0 || hrc=$?
    if [ "$hrc" = 0 ] && [ -z "$out" ] && grep -q "$h JSONDecodeError" "$E/build/agent_hooks/errors.log" 2>/dev/null; then
        ok "$h: exit 0, no decision, one line in build/agent_hooks/errors.log"
    else
        fail "$h: the fail-open path (exit $hrc, out '$out', log $( [ -f "$E/build/agent_hooks/errors.log" ] && echo present || echo absent))"
    fi
done

echo "== the call gate over its cases"
python3 "$CASES" "$AG/hooks/pre_agent.py" > "$W/agentgate.txt" 2>&1 || true
sed -n '/^  BAD /p' "$W/agentgate.txt" | head -8 | sed 's/^/      /'
if grep -q ' wrong 0$' "$W/agentgate.txt"; then ok "the call gate decides every case ($(tail -1 "$W/agentgate.txt"))"
else fail "the call gate's decisions disagree with its cases ($(tail -1 "$W/agentgate.txt"))"; fi

echo "== the installation"
SETTINGS=.claude/settings.json
if bbh_ctl_is unwired-settings; then
    unwire "$SETTINGS" "$W/settings_unwired.json" || true
    SETTINGS="$W/settings_unwired.json"; echo "  mode: the installation check reads a settings copy with the Bash hook removed"
fi
if wiring "$SETTINGS" > "$W/wiring.txt" 2>&1; then
    ok "$SETTINGS wires pre_bash.py on Bash and pre_agent.py on Agent|Task, and keeps the three edit-lock rules"
else
    sed 's/^/        /' "$W/wiring.txt"; fail "the installation in $SETTINGS is incomplete"
fi

if [ -z "${BBH_CTL:-}" ]; then
    echo "== controls: each perturbed copy must produce mismatches on ITS side"
    for c in blind-classifier greedy-heredoc no-heredoc-strip; do
        replay "$(make_copy "$c")" "$W/ctl_$c.txt"
        case "$c" in blind-classifier|greedy-heredoc) side=deny;; no-heredoc-strip) side=allow;; esac
        k=$(grep -c "^MISMATCH expect=$side " "$W/ctl_$c.txt" || true)
        if [ "${k:-0}" -gt 0 ]; then bbh_ctl_fired "$c" "$k must-$side rows mismatched on the perturbed copy"
        else bbh_ctl_dead "$c" "the perturbed copy matched every must-$side row — the replay cannot see this failure" || rc=1; fi
    done
    python3 "$CASES" "$(make_copy open-agent-gate)/hooks/pre_agent.py" > "$W/ctl_agent.txt" 2>&1 || true
    k=$(grep -c '^  BAD .*expect deny' "$W/ctl_agent.txt" || true)
    if [ "${k:-0}" -gt 0 ]; then bbh_ctl_fired open-agent-gate "$k must-deny call cases let through by the perturbed copy"
    else bbh_ctl_dead open-agent-gate "the always-allow copy matched every call case — the cases cannot see an open gate" || rc=1; fi
    if ! unwire .claude/settings.json "$W/ctl_settings.json" > "$W/ctl_unwire.txt" 2>&1; then
        bbh_ctl_dead unwired-settings "cannot plant the defect: $(cat "$W/ctl_unwire.txt")" || rc=1
    elif wiring "$W/ctl_settings.json" > "$W/ctl_wiring.txt" 2>&1; then
        bbh_ctl_dead unwired-settings "a settings copy with no Bash hook passed the installation check" || rc=1
    else bbh_ctl_fired unwired-settings "refused: $(head -1 "$W/ctl_wiring.txt")"; fi
fi

if [ "$rc" -eq 0 ]; then echo "PASS: the Bash hook denies every detached launch and waiter in its fixture and allows every look-alike, the call gate decides every case, both fail open on a malformed event, and the settings still wire them under the edit-lock"
else echo "FAIL: an agent-discipline hook decides against its evidence, or the installation is incomplete, or a control did not fire"; fi
exit "$rc"
