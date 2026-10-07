#!/usr/bin/env python3
"""pre_agent.py — the CALL GATE of GitHub #172 slice S4: a worker runs at its caps.
A Claude Code PreToolUse hook on `Agent|Task` (wired in `.claude/settings.json` beside
`pre_bash.py` and `pre_push.py`; spec `docs/project/agent_architecture_scope.md` §4 W).

COPIED INTO bbh (Phase A of docs/agents_scope.md, 2026-10-07) from the lineage's
`tools/agent/hooks/pre_agent.py` @ dbaed3a0. The paths and incidents in the prose are the LINEAGE's (history,
[BBH-86]); a change here is diffed against the lineage's copy first, and Phase B's
fidelity row F12 replaces this copy with the lifted tool.

Ruled 2026-09-23 (14z-177, `DECISIONS_HISTORY.md` "Ruled 2026-09-23 (14z-177)"): workers are at
most Opus-class — the maintainer's #172 ask. MEASURED the same sitting
(`tools/agent/probe_agents.sh`): the Agent call's `model` BEATS the definition's (A2), a call to
no definition with no `model` runs on the CALLER's model (A9) — which S5 makes Fable — and a
project hook on Agent sees the call's input and can deny it (A8). The definitions themselves are
held by `tests/test_agent_defs.sh`; this hook holds the CALL. It DENIES an Agent call that

  (a) passes a `model` above Opus-class (anything but opus / sonnet / haiku or a
      claude-(opus|sonnet|haiku)-<version> id);
  (b) passes a `model` to a DEFINED worker (`.claude/agents/<subagent_type>.md` exists): the
      definition is the cap of record, and the call would beat it;
  (c) names no definition and passes no `model` — it would run on the orchestrator's model —
      unless the type is a BUILT-IN measured to stay at most Opus-class under a caller ABOVE it
      (SELF_CAPPED below; `tools/agent/probe_agents.sh` A11: under a Fable 5.1 parent with no
      model, `Explore` ran on Opus 5.5 while `general-purpose` ran on Fable 5.1). Measured over
      the archive too: every `general-purpose` (139) and `Plan` (5) call without a model ran on
      its parent's model — 56 of them on Fable 5.1 — and `Explore` on Opus 5 under Fable parents.
      `Explore` is NOT "its own model": under a Sonnet parent it ran on Sonnet (A11's first form
      FAILED on that premise); it follows the caller, capped at Opus-class, which is all this
      rule needs. `claude-code-guide` does not exist in a headless run, so it cannot be probed
      and is not listed;
  (d) calls a defined worker whose definition is driven by the spec template (its body names
      `docs/project/worker_spec.md`) with a prompt missing one of the template's headings —
      so a spec cannot skip the template.

A FORK (`subagent_type: "fork"`) is ALLOWED: ruled *"Allow forks"* — a fork is the orchestrator
continuing, not a spec'd worker. The reason always names the allowed form, so the task is redone
and the session goes on (the 2026-09-23 ruling: a block binds the task at fault, never the
session).

FAIL-OPEN BY DESIGN, as `pre_bash.py`: an internal error ALLOWS the call and appends a line to
`build/agent_hooks/errors.log`.
"""
import json
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ALLOWED_MODEL = re.compile(r"^(opus|sonnet|haiku|claude-(opus|sonnet|haiku)-[0-9][0-9a-z.-]*)$")
TEMPLATE = ".claude/worker_spec.md"  # bbh: re-pointed from the lineage's docs/project/worker_spec.md
# built-in types measured to stay at most Opus-class under a caller ABOVE Opus-class, so a call
# with no model cannot breach the cap: tools/agent/probe_agents.sh A11 (14z-177). A type not
# listed here, with no definition and no model, is assumed to inherit the caller's model
# (general-purpose and Plan were measured to; A9, and the archive).
SELF_CAPPED = ("Explore",)
HEADINGS = ("TASK:", "INPUTS:", "COMMANDS:", "RETURN:", "MUST NOT:", "STOP:")


def root():
    return os.environ.get("CLAUDE_PROJECT_DIR") or os.path.dirname(os.path.dirname(os.path.dirname(HERE)))


def definition(name, base):
    """-> the definition file's text, or None when there is no such definition."""
    if not name or not re.fullmatch(r"[A-Za-z0-9_-]+", name):
        return None
    p = os.path.join(base, ".claude", "agents", name + ".md")
    return open(p, encoding="utf-8").read() if os.path.isfile(p) else None


def decide(event, base=None):
    """-> (decision, reason); decision is 'deny' or None."""
    if event.get("tool_name") not in ("Agent", "Task"):
        return None, None
    i = event.get("tool_input") or {}
    kind = str(i.get("subagent_type") or "")
    model = str(i.get("model") or "")
    if kind == "fork":
        return None, None
    base = base or root()
    defn = definition(kind, base)
    tag = "S4 call gate (#172, workers at their caps)"
    if model and not ALLOWED_MODEL.match(model):
        return "deny", (f"{tag}: model {model!r} is above Opus-class. Workers run at most on opus, "
                        "sonnet or haiku; call a defined worker without a model, or pass one of those.")
    if defn is not None and model:
        return "deny", (f"{tag}: {kind!r} is a defined worker (.claude/agents/{kind}.md) and its "
                        f"definition is the cap of record; a model parameter would override it. "
                        "Call it again WITHOUT the model parameter.")
    if defn is None and not model and kind not in SELF_CAPPED:
        return "deny", (f"{tag}: {kind or 'general-purpose'!r} has no definition under .claude/agents/, "
                        "so with no model parameter it would run on the orchestrator's own model. "
                        "Call a defined worker (measurer, reader), or pass model opus, sonnet or haiku "
                        f"(built-ins measured to stay capped under any caller: {', '.join(SELF_CAPPED)}).")
    if defn is not None and TEMPLATE in defn:
        prompt = str(i.get("prompt") or "")
        missing = [h for h in HEADINGS if not re.search(rf"(?m)^{re.escape(h)}", prompt)]
        if missing:
            return "deny", (f"{tag}: {kind!r} is driven by a spec written from {TEMPLATE}, and this "
                            f"prompt lacks {', '.join(missing)} (each at the start of a line). "
                            "Write the spec from the template and call it again.")
    return None, None


def main():
    raw = sys.stdin.read()
    try:
        decision, reason = decide(json.loads(raw))
    except Exception as e:  # fail open, but never silently
        try:
            d = os.path.join(root(), "build", "agent_hooks")
            os.makedirs(d, exist_ok=True)
            with open(os.path.join(d, "errors.log"), "a") as f:
                f.write(f"{time.strftime('%Y-%m-%dT%H:%M:%S')} pre_agent {type(e).__name__}: {e}\n")
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
