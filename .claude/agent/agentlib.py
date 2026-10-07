#!/usr/bin/env python3
"""agentlib.py — the ONE classifier behind the #172 agent-discipline hooks and census.

COPIED INTO bbh (Phase A of docs/agents_scope.md, 2026-10-07) from the lineage's
`tools/agent/agentlib.py` @ dbaed3a0. The paths and incidents in the prose are the LINEAGE's (history,
[BBH-86]); a change here is diffed against the lineage's copy first, and Phase B's
fidelity row F12 replaces this copy with the lifted tool.

Everything here reads either a Bash command string or a Claude Code session transcript
(`~/.claude/projects/<project>/<session>.jsonl`). Stdlib only. Used by
`tools/agent/hooks/pre_bash.py` (C0.1) and `tools/agent/transcript_gaps.py` (the census),
so the hook and the measurement that justified it can never disagree about what a
detached launch or a finished task is (`docs/project/agent_architecture_scope.md`).
C0.2 was measured and moved to the procedural checker (ruled 2026-09-23); no Stop hook
uses this module.

THE TWO TRAPS PAID FOR WHILE MEASURING (both from rule-checker runs 2026-09-23-97/98):
- a single `&` is not a detach when it is half of `&&`, a `>&`/`&>` redirect, inside a
  quoted string or a heredoc BODY (a script being written, not run), or followed later
  in the same command by `wait` (a foreground parallel run);
- a task-completion notification is recorded in TWO forms: a user message when it
  arrives while the agent is idle, and a `queued_command` attachment when it arrives
  mid-turn. And never grep a transcript: it embeds the system prompt, which names these
  markers — parse records by type.
"""
import json
import re

# ---------------------------------------------------------------- commands (C0.1)

# a heredoc operator: `<<TAG`, `<<-TAG`, `<<'TAG'`, `<<"TAG"` — NOT a here-string
# (`<<<word`) and NOT a shift (`1<<3`): the tag starts with a letter or `_`, and the
# operator touches no third `<` (rule-checker run 2026-09-23-100, Q3/Q4)
_HEREDOC = re.compile(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_]\w*)\1")
# quoted strings may span lines (a `node -e "..."` program is data, and its `&` is bitwise)
_QUOTED = re.compile(r"'[^']*'|\"(?:\\.|[^\"\\])*\"")
_DETACH_WORD = re.compile(r"\b(nohup|setsid|disown)\b")
# a backgrounding &: not half of &&, not a redirect (>& <& &> |&)
_BG_AMP = re.compile(r"(?<![&><|])&(?![&>])")
_WAIT = re.compile(r"\bwait\b")
_PGREP_WAITER = re.compile(r"\b(until|while)\b[^;\n]*\bpgrep\b")


def strip_heredocs(cmd):
    """Drop every heredoc BODY (the text is data being written, not commands run)."""
    out, lines, i = [], cmd.split("\n"), 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        # search the RAW line: blanking quoted strings first erases a quoted tag ('EOF')
        m = _HEREDOC.search(line)
        i += 1
        if m:
            tag = m.group(2)
            # strip ONLY a body whose terminator line exists: an operator with no
            # terminator (a `<<` inside a quoted program, an arithmetic shift) used to
            # swallow every later line — hiding a real `nohup`, and un-closing a quoted
            # string so a quoted `&` was flagged (both measured, 14z-175)
            end = next((k for k in range(i, len(lines)) if lines[k].strip() == tag), None)
            if end is not None:
                i = end + 1
    return "\n".join(out)


def detach_reason(cmd):
    """-> a one-line reason if the command detaches a job the harness cannot track, else None."""
    body = _QUOTED.sub("''", strip_heredocs(cmd))
    m = _DETACH_WORD.search(body)
    if m:
        return f"`{m.group(1)}` detaches a job the harness cannot track"
    for m in _BG_AMP.finditer(body):
        if not _WAIT.search(body, m.end()):
            return "a backgrounding `&` with no later `wait` returns while the job still runs"
    return None


def waiter_reason(cmd):
    """-> a reason if the command waits on a process-table query (the self-matching waiter)."""
    body = _QUOTED.sub("''", strip_heredocs(cmd))
    if _PGREP_WAITER.search(body):
        return "a loop conditioned on `pgrep` can match its own shell and never exit"
    return None


# ---------------------------------------------------------------- transcripts (C0.2)

TRACKED_RESULT = ("Command running in background with ID:", "moved to the background (ID:")
_TASK_ID = re.compile(r"\(ID: (\w+)\)|with ID: (\w+)")
_OUT_PATH = re.compile(r"Output is being written to: (\S+?\.output)")
_NOTE_ID = re.compile(r"<task-id>(\w+)</task-id>")
_NOTE_STATUS = re.compile(r"<status>(\w+)</status>")
_PATHISH = re.compile(r"[\w./~$-]*[/.][\w./-]*\.(?:log|txt|tsv|out|output|json)\b")
# a tracked launch's result STARTS with one of these; a result that merely QUOTES the
# marker (a `sed` of this file, a selftest printed) is not a launch — 7 of 798 marker-
# carrying results in the archive were quotes (14z-176): 3 phantom tasks
_LAUNCH_HEADS = ("Command running in background with ID:", "Command did not complete within")


def tracked_launch(text):
    """-> the task id if this tool-result text IS a tracked launch, else None."""
    s = text.lstrip()
    if not s.startswith(_LAUNCH_HEADS):
        return None
    m = _TASK_ID.search(s)
    return (m.group(1) or m.group(2)) if m else None


def records(path):
    """Yield (index, record) for every main-thread record of a transcript."""
    with open(path, encoding="utf-8", errors="replace") as f:
        for n, line in enumerate(f):
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if not r.get("isSidechain"):
                yield n, r


def _content(r):
    m = r.get("message")
    return m.get("content") if isinstance(m, dict) else None


def notifications(r):
    """-> [(task_id, status, form)] carried by this record, in either form."""
    out = []
    c = _content(r)
    if r.get("type") == "user" and isinstance(c, str) and c.lstrip().startswith("<task-notification>"):
        texts = [(c, "idle")]
    else:
        texts = []
    att = r.get("attachment") or {}
    if att.get("type") == "queued_command" and "<task-notification>" in str(att.get("prompt")):
        texts.append((str(att["prompt"]), "mid-turn"))
    for text, form in texts:
        i, s = _NOTE_ID.search(text), _NOTE_STATUS.search(text)
        if i:
            out.append((i.group(1), s.group(1) if s else "?", form))
    return out


def tasks(path):
    """Every harness-tracked Bash task of a transcript, as dicts:
    id, started (ts), start_n (record index), output (path), command, description,
    ended (ts or None), end_n, status, form, and read_after (bool): whether any tool
    call AFTER the notification mentions the task id, its output path, or a file path
    the task's own command writes (a job that redirects into its own log is read by
    reading that log)."""
    calls, found, order = {}, {}, []
    later_inputs = []  # (record index, json text of a tool_use input)
    for n, r in records(path):
        c = _content(r)
        if isinstance(c, list):
            for b in c:
                if b.get("type") == "tool_use":
                    inp = b.get("input") or {}
                    calls[b.get("id")] = inp
                    later_inputs.append((n, json.dumps(inp)))
                elif b.get("type") == "tool_result":
                    body = json.dumps(b.get("content"))
                    cont = b.get("content")
                    tid = tracked_launch(cont if isinstance(cont, str) else " ".join(
                        x.get("text", "") for x in cont or [] if isinstance(x, dict)))
                    if tid:
                        op = _OUT_PATH.search(body)
                        inp = calls.get(b.get("tool_use_id"), {})
                        cmd = str(inp.get("command", ""))
                        found[tid] = {"id": tid, "started": r.get("timestamp"), "start_n": n,
                                      "output": op.group(1) if op else None, "command": cmd,
                                      "description": inp.get("description", ""),
                                      "ended": None, "end_n": None, "status": None, "form": None,
                                      "paths": set(_PATHISH.findall(cmd))}
                        if tid not in order:
                            order.append(tid)
        for tid, status, form in notifications(r):
            t = found.get(tid)
            if t and t["ended"] is None:
                t.update(ended=r.get("timestamp"), end_n=n, status=status, form=form)
    for tid in order:
        t = found[tid]
        keys = {tid} | ({t["output"]} if t["output"] else set()) | t["paths"]
        t["read_after"] = t["end_n"] is not None and any(
            n > t["end_n"] and any(k in text for k in keys) for n, text in later_inputs)
        t["paths"] = sorted(t["paths"])
    return [found[t] for t in order]


def unread_finished(path):
    """The C0.2 question: tracked tasks that finished (a notification arrived) and whose
    result no later tool call has looked at."""
    return [t for t in tasks(path) if t["end_n"] is not None and not t["read_after"]]
