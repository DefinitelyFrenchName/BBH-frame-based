#!/usr/bin/env python3
"""pre_agent_cases.py HOOK — drives the S4 CALL GATE (`tools/agent/hooks/pre_agent.py`, GitHub
#172 slice S4, installed by the maintainer 2026-09-23) through every rule both ways, run as a
SUBPROCESS exactly as the harness runs it, against a scratch copy of the tree's
`.claude/agents/` (so a missing definition cannot make a case pass by accident); nothing in the
tree is touched. Exit 0 = every case as expected; a wrong case prints `  BAD … expect <x>`.
Run by `tests/test_agent_hooks.sh` against the INSTALLED hook and, for its `open-agent-gate`
control, against a perturbed copy. Born as build/agent172/proposal_pre_agent/prove.py (14z-177),
whose archive replay and settings check stay with the proposal: the archive grows every session,
and the settings are held by the gate's own wiring check.

COPIED INTO bbh (Phase A of docs/agents_scope.md, 2026-10-07) from the lineage's
`tests/lib/pre_agent_cases.py` @ dbaed3a0; run by `selftest/test_agent_hooks.sh`. The only
change: the default HOOK is `.claude/agent/hooks/pre_agent.py`. The paths and incidents in
the prose are the LINEAGE's (history, [BBH-86]).
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TREE = os.path.dirname(os.path.dirname(HERE))
HOOK = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.join(TREE, ".claude", "agent", "hooks", "pre_agent.py")

SPEC = ("TASK: q\nINPUTS:\n- x\nCOMMANDS:\nC1: git show HEAD:README.md | wc -l\nRETURN:\n"
        "FIG n = <v> <- C1\nMUST NOT:\n- none\nSTOP:\n- on failure")

CASES = [  # (label, tool_input, expected 'deny'|'allow')
    ("(a) a fable model on general-purpose", {"subagent_type": "general-purpose", "model": "fable", "prompt": "x"}, "deny"),
    ("(a) a claude-fable id", {"subagent_type": "general-purpose", "model": "claude-fable-5-1", "prompt": "x"}, "deny"),
    ("(a) an unknown model name", {"subagent_type": "general-purpose", "model": "gpt", "prompt": "x"}, "deny"),
    ("(a) allow: opus on general-purpose (the rule-checker readers' form until 14z-178 pinned them)", {"subagent_type": "general-purpose", "model": "opus", "prompt": "x"}, "allow"),
    ("(a) allow: a claude-sonnet id", {"subagent_type": "general-purpose", "model": "claude-sonnet-5", "prompt": "x"}, "allow"),
    ("(b) a model on a defined worker", {"subagent_type": "measurer", "model": "sonnet", "prompt": SPEC}, "deny"),
    ("(b) allow: the defined worker with no model", {"subagent_type": "measurer", "prompt": SPEC}, "allow"),
    ("(c) general-purpose with no model", {"subagent_type": "general-purpose", "prompt": "x"}, "deny"),
    ("(c) no subagent_type and no model", {"prompt": "x"}, "deny"),
    ("(c) Plan with no model (measured to inherit)", {"subagent_type": "Plan", "prompt": "x"}, "deny"),
    ("(c) an unknown type with no model", {"subagent_type": "Mystery", "prompt": "x"}, "deny"),
    ("(c) allow: Explore with no model (measured capped, probe A11)", {"subagent_type": "Explore", "prompt": "x"}, "allow"),
    ("(c) claude-code-guide with no model (not probeable headless, so not listed)", {"subagent_type": "claude-code-guide", "prompt": "x"}, "deny"),
    ("(c) allow: claude-code-guide WITH an allowed model", {"subagent_type": "claude-code-guide", "model": "haiku", "prompt": "x"}, "allow"),
    ("(c) allow: Plan WITH an allowed model", {"subagent_type": "Plan", "model": "opus", "prompt": "x"}, "allow"),
    ("(d) a worker prompt missing the template headings", {"subagent_type": "measurer", "prompt": "count the lines of README.md"}, "deny"),
    ("(d) a worker prompt missing ONE heading (STOP:)", {"subagent_type": "measurer", "prompt": SPEC.replace("STOP:", "HALT:")}, "deny"),
    ("(d) a heading not at a line start does not count", {"subagent_type": "reader", "prompt": SPEC.replace("TASK: q", "  TASK: q")}, "deny"),
    ("(d) allow: the reader with a full spec", {"subagent_type": "reader", "prompt": SPEC}, "allow"),
    # the pinned rule-checker (14z-178): a defined worker, so a model is refused (b); its prompt is
    # a rulecheck.py packet, not a worker spec, so the template rule (d) must NOT apply to it
    ("(b) a model on the pinned rule-checker", {"subagent_type": "rule-checker", "model": "opus", "prompt": "You are an independent rule-checker"}, "deny"),
    ("(d) allow: the rule-checker with no model and a packet prompt (not a template worker)", {"subagent_type": "rule-checker", "prompt": "You are an independent rule-checker"}, "allow"),
    ("fork allowed (ruled)", {"subagent_type": "fork", "prompt": "x"}, "allow"),
    ("fork allowed even with no model", {"subagent_type": "fork"}, "allow"),
    ("a path-traversal type is no definition (and no model): denied by (c)", {"subagent_type": "../../etc/passwd", "prompt": "x"}, "deny"),
    ("a non-Agent tool is never judged", None, "allow"),
]


def run_hook(event, base):
    env = dict(os.environ, CLAUDE_PROJECT_DIR=base)
    p = subprocess.run([sys.executable, HOOK], input=event if isinstance(event, str) else json.dumps(event),
                       capture_output=True, text=True, env=env, timeout=20)
    if p.returncode != 0:
        return f"exit{p.returncode}"
    out = p.stdout.strip()
    return json.loads(out)["hookSpecificOutput"]["permissionDecision"] if out else "allow"


def main():
    base = tempfile.mkdtemp()
    try:
        shutil.copytree(os.path.join(TREE, ".claude", "agents"), os.path.join(base, ".claude", "agents"))
        wrong = n = 0
        for label, inp, want in CASES:
            ev = ({"tool_name": "Bash", "tool_input": {"command": "echo x"}} if inp is None
                  else {"tool_name": "Agent", "tool_input": inp})
            got = run_hook(ev, base)
            n += 1
            if got != want:
                wrong += 1
                print(f"  BAD {label}: expect {want} got {got}")
        for label, raw in (("fail-open: malformed JSON", "{not json"),
                           ("fail-open: a non-dict tool_input", json.dumps({"tool_name": "Agent", "tool_input": "x"}))):
            got = run_hook(raw, base)
            n += 1
            if got != "allow":
                wrong += 1
                print(f"  BAD {label}: expect allow got {got}")
        print(f"cases {n} wrong {wrong}")
        return 1 if wrong else 0
    finally:
        shutil.rmtree(base)


if __name__ == "__main__":
    sys.exit(main())
