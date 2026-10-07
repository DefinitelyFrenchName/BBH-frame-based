#!/usr/bin/env python3
"""pre_bash.py — C0.1 of GitHub #172: no invisible jobs. A Claude Code PreToolUse hook
on Bash (wired in `.claude/settings.json`; spec `docs/project/agent_architecture_scope.md`).

COPIED INTO bbh (Phase A of docs/agents_scope.md, 2026-10-07) from the lineage's
`tools/agent/hooks/pre_bash.py` @ dbaed3a0. The paths and incidents in the prose are the LINEAGE's (history,
[BBH-86]); a change here is diffed against the lineage's copy first, and Phase B's
fidelity row F12 replaces this copy with the lifted tool.

It DENIES a Bash call that
  - detaches a job the harness cannot track (`nohup`, `setsid`, `disown`, or a
    backgrounding `&` with no later `wait`) — such a job can never produce a completion
    notification, so once the agent ends its turn nothing wakes it: the 14z-174 failure,
    where all twelve long jobs were `nohup` launches and eleven idle gaps ended only when
    the maintainer asked for status; or
  - waits in a loop conditioned on `pgrep`, which can match its own shell and never exit
    (4 h 12 min lost at 14z-159).
The reason names the tracked alternative, so the TASK is redone in the allowed form and
the session goes on (the maintainer's ruling of 2026-09-23: a block binds the task at
fault, never the session). `run_in_background: true` does not exempt a detach: the
tracked shell would end at once and leave the detached child as invisible as before.

FAIL-OPEN BY DESIGN: any internal error ALLOWS the call and appends a line to
`build/agent_hooks/errors.log`, because a hook bug must not stop the work; the gate
`tests/test_agent_hooks.sh` is what keeps the logic from dying silently.
The classifier is `tools/agent/agentlib.py`, shared with the census that justified it.
"""
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

ALTERNATIVE = ("Run the job with the Bash tool's `run_in_background: true` in the FOREGROUND "
               "form (no nohup, no trailing &) — the harness tracks it and notifies on "
               "completion — or use the Monitor tool to wait for a condition. A foreground "
               "parallel run that ends in `wait` is allowed.")


def decide(event):
    """-> (decision, reason); decision is 'deny' or None."""
    if event.get("tool_name") != "Bash":
        return None, None
    cmd = str((event.get("tool_input") or {}).get("command", ""))
    import agentlib
    why = agentlib.detach_reason(cmd) or agentlib.waiter_reason(cmd)
    if why:
        return "deny", f"C0.1 (#172, no invisible jobs): {why}. {ALTERNATIVE}"
    return None, None


def main():
    raw = sys.stdin.read()
    try:
        decision, reason = decide(json.loads(raw))
    except Exception as e:  # fail open, but never silently
        try:
            root = os.environ.get("CLAUDE_PROJECT_DIR") or os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
            d = os.path.join(root, "build", "agent_hooks")
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, "errors.log"), "a") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} pre_bash {type(e).__name__}: {e}\n")
        except Exception:
            pass
        return 0
    if decision == "deny":
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                                 "permissionDecision": "deny",
                                                 "permissionDecisionReason": reason}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
