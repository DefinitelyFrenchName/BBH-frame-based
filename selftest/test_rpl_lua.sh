#!/bin/sh
# test_rpl_lua.sh — THE GRAMMAR EQUALITY CHECK: lua/mame/rpl_parse.lua and
# lib/py/bbh/rpl.py are two copies of one grammar (the harness's own rot
# class — a deleted mechanism on one side survives on the other), so their
# canonical parses are diffed over the example's replays and every malformed
# shape. Until 2026-10-11 the lineage's replays were diffed too when its tree
# sat beside this one (233 replays, 249694 lines on the last run); removed
# when bbh became its own project (docs/conventions.md 8).
# Needs a STANDALONE lua (lua / lua5.4 / lua5.3 / luajit): SKIPs with the
# reason when none is present. Until 2026-10-11 the same comparison also ran
# under MAME's own interpreter in fidelity F8, retired with the contract
# (docs/conventions.md 8); nothing else compares the two parses now. ~2 s.
set -eu
BBH_HOME="$(cd "$(dirname "$0")/.." && pwd)"; export BBH_HOME
PYTHONPATH="$BBH_HOME/lib/py"; export PYTHONPATH
LUA=""; for l in lua lua5.4 lua5.3 luajit; do command -v "$l" >/dev/null 2>&1 && { LUA="$l"; break; }; done
[ -n "$LUA" ] || { echo "SKIP: no standalone lua on this host (lua/lua5.4/lua5.3/luajit) — nothing else compares the two parses since fidelity F8 was retired (2026-10-11)"; exit 0; }
rc=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; rc=1; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT INT TERM
D="$BBH_HOME/lua/mame/rpl_dump.lua"

pair() {  # pair <label> <files…>
    lbl="$1"; shift
    "$LUA" "$D" "$@" > "$T/lua.txt" 2>&1 || true
    python3 -m bbh.rpl dump "$@" > "$T/py.txt" 2>&1 || true
    if cmp -s "$T/lua.txt" "$T/py.txt"; then ok "$lbl: identical ($(wc -l < "$T/lua.txt" | tr -d ' ') lines)"
    else fail "$lbl: differ"; diff "$T/lua.txt" "$T/py.txt" | head -8 | sed 's/^/        /'; fi
}

echo "== 1. the example's replays =="
pair "example replays" "$BBH_HOME"/example/replays/*.rpl

echo "== 2. every malformed shape, the same error text =="
i=0
for line in "abc p1=1" "10-5 p1=1" "0 wait" "100 p3=1" "100 p1=Z" "100 sys=S" "100 sys=S1C" "100" "100 p1" "5 p1=U p2=D sys=S1 wait"; do
    i=$((i + 1)); printf '# c\n\n%s\n' "$line" > "$T/m$i.rpl"
done
pair "malformed shapes" "$T"/m*.rpl
grep -c '^ERROR' "$T/lua.txt" | grep -q '^9$' && ok "nine of ten rejected on both sides (the tenth is valid)" || fail "rejections: $(grep -c '^ERROR' "$T/lua.txt")"

echo
[ "$rc" = 0 ] && echo "PASS: rpl_parse.lua == rpl.py" || { echo "FAIL: see above"; exit 1; }
