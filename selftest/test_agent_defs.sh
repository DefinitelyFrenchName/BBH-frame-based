#!/bin/sh
# test_agent_defs.sh — every worker definition under .claude/agents/ STATES its caps: a model at most Opus-class, an effort at most xhigh, read-only tools (Bash only for the measurer's kind), no key that reads as enforcement and is not, and the pinned rule-checker launched without CLAUDE.md. ~1 s, no instrument.
#
# MUST-FIRE: perturbed-copy: fable-model — measurer.md's model set to claude-fable-5-1 must be refused as above Opus-class, and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: missing-effort — measurer.md's effort line removed must be refused (it would follow the caller's effort), and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: max-effort — measurer.md's effort set to max must be refused, and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: frontmatter-hooks — a hooks: block added to reader.md must be refused, and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: write-tool — Write added to reader.md's tools must be refused, and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: alias-model — rule-checker.md's model set to the alias opus must be refused (an alias can move to a new model with the definition unchanged), and the gate must FAIL (mode: the gate checks that copy)
# MUST-FIRE: perturbed-copy: context-leak — rule-checker.md's omitClaudeMd line removed must be refused (it would receive CLAUDE.md), and the gate must FAIL (mode: the gate checks that copy)
#
# WHY. A definition with no `model` runs on its CALLER's model and one with no
# `effort` at its caller's effort, while a `hooks:` block in a definition's
# frontmatter does not fire (all measured in the lineage by its probe_agents.sh,
# 14z-177): so a definition must STATE both caps and must not carry a key that
# reads as enforcement. What this gate does NOT hold: an Agent CALL's `model`
# beats the definition's — that is the call gate's (test_agent_hooks.sh).
#
# Lineage: tests/test_agent_defs.sh @ dbaed3a0 (GitHub #172 slice S4, 14z-177;
# the rule-checker's rows 14z-178), ported 2026-10-07 to this harness's control
# helpers (Phase A of docs/agents_scope.md). The checker is the copied
# .claude/agent/agent_defs.py.
#
# Usage: selftest/test_agent_defs.sh
set -eu
BBH_HOME="$(cd "$(dirname "$0")/.." && pwd)"; export BBH_HOME
. "$BBH_HOME/lib/sh/controls.sh"
bbh_ctl_mode "$0"
cd "$BBH_HOME"
rc=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; rc=1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT INT TERM
REAL=".claude/agents"
CHECK="python3 -B .claude/agent/agent_defs.py"

# perturb NAME DIR — plant control NAME's one defect into a copy at DIR; echo the reason
# fragment the check must print for it
perturb() {
    rm -rf "$2"; cp -R "$REAL" "$2"
    case "$1" in
        fable-model)    sed -i.bak 's/^model: .*/model: claude-fable-5-1/' "$2/measurer.md"; echo "is not Opus-class";;
        missing-effort) sed -i.bak '/^effort:/d' "$2/measurer.md"; echo "effort missing";;
        max-effort)     sed -i.bak 's/^effort: .*/effort: max/' "$2/measurer.md"; echo "effort 'max'";;
        frontmatter-hooks)
            python3 - "$2/reader.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
s = s.replace("\ntools:", "\nhooks:\n  PreToolUse:\n    - matcher: Bash\ntools:", 1)
open(p, "w").write(s)
PY
            echo "key 'hooks' not allowed";;
        write-tool)     sed -i.bak 's/^tools: .*/&, Write/' "$2/reader.md"; echo "tool 'Write'";;
        alias-model)    sed -i.bak 's/^model: .*/model: opus/' "$2/rule-checker.md"; echo "is an alias";;
        context-leak)   sed -i.bak '/^omitClaudeMd:/d' "$2/rule-checker.md"; echo "omitClaudeMd: true missing";;
    esac
    rm -f "$2"/*.bak
}

target="$REAL"
if [ -n "${BBH_CTL:-}" ]; then
    target="$W/mode"
    want="$(perturb "$BBH_CTL" "$target")"
    echo "  mode: checking a copy of $REAL with that defect planted ($want)"
fi
echo "== the definitions under $target"
out="$($CHECK "$target" 2>&1)" && crc=0 || crc=$?
echo "$out" | sed 's/^/        /'
if [ "$crc" -eq 0 ]; then ok "the check accepts every definition"; else fail "a definition breaks the caps (exit $crc)"; fi
for n in measurer reader rule-checker; do
    if echo "$out" | grep -q "^OK  $n.md$"; then ok "$n.md is an OK definition"; else fail "$n.md is not an OK definition"; fi
done

if [ -z "${BBH_CTL:-}" ]; then
    echo "== controls: one planted defect per copy, each must be refused with its reason"
    for c in fable-model missing-effort max-effort frontmatter-hooks write-tool alias-model context-leak; do
        want="$(perturb "$c" "$W/$c")"
        got="$($CHECK "$W/$c" 2>&1)" && grc=0 || grc=$?
        if [ "$grc" -ne 0 ] && echo "$got" | grep '^BAD ' | grep -qF "$want"; then
            bbh_ctl_fired "$c" "refused: $(echo "$got" | grep '^BAD ' | head -1 | cut -c1-120)"
        else
            bbh_ctl_dead "$c" "the planted defect was not refused with '$want' (exit $grc)" || rc=1
        fi
    done
fi

if [ "$rc" -eq 0 ]; then echo "PASS: every worker definition states its caps (model at most Opus-class, effort at most xhigh, an allowed tool list) and carries no unapproved key; the rule-checker launches without CLAUDE.md"
else echo "FAIL: a worker definition breaks its caps, or a control did not fire"; fi
exit "$rc"
