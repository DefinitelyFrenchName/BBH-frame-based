# THE WORKER SPEC — the template every task handed to a worker is written from

**What this is.** A worker is a named, capped definition under `.claude/agents/`
(`measurer`, `reader`) that the orchestrator drives by a SPEC: a prompt written from
this template, nothing else. The call gate (`.claude/agent/hooks/pre_agent.py`) REFUSES
a call to a defined worker whose prompt lacks one of the headings below. So the headings
are fixed, spelled exactly, and each on its own line.

Copied into bbh 2026-10-07 (Phase A of `docs/agents_scope.md`) from the lineage's
`docs/project/worker_spec.md` @ dbaed3a0, its GitHub #172. The template block is
verbatim; the lineage-only notes (its procedure checker's question numbers, its slice
plan) are cut.

**Why a spec and not a request.** The lineage maintainer's ask was for workers
*"specialized, driven by very precise specifications and directives given by the
orchestrator"*. The blind spot it names is the orchestrator's framing propagating into
every worker. The answer is to make the framing INSPECTABLE: what the worker was told,
what it ran, and what it returned are three things a reviewer can put side by side.

## The template

Copy it, fill every section, and delete nothing. A section with nothing to say says `none`.

```
TASK: <one sentence: the question the worker answers — a question, not a conclusion to confirm>

INPUTS:
- <path, commit, build dir or session id the commands read; each pinned where it can move>

COMMANDS:
C1: <the exact command, as it is to be run>
C2: <...>

RETURN:
FIG <name> = <value> <- C<n>
NOT MEASURED: <what> — <why>
(nothing else: no conclusion, no recommendation, no summary line)

MUST NOT:
- infer, estimate or recall a figure: every FIG comes from a command's output
- run a command that is not in COMMANDS; if one is needed, stop and say which and why
- edit, create or delete a tracked file; launch a detached job; spawn an agent
- <anything else this task forbids>

STOP:
- at the first command that fails or prints something the task did not expect: report the
  command and its output verbatim, and return what was measured before it
```

## What each section is for

- **TASK** is a QUESTION. "Confirm that X is 12" hands the worker the answer; "how many
  rows does X have" does not.
- **INPUTS** pins what can move. A figure from `HEAD` is a figure about a commit nobody
  named; a figure from `git show <sha>:<path>` is reproducible forever. In bbh, the
  lineage's WORKING TREE moves under a running sitting, so a lineage input is pinned by
  commit whenever the question allows it.
- **COMMANDS** are numbered so each figure can name its source. The worker runs them as
  written; a worker that improvises a better command has answered a different question,
  and says so under STOP instead.
- **RETURN** is one line per figure, `FIG <name> = <value> <- C<n>`, because a figure
  without its command cannot be re-derived. `NOT MEASURED` lines are how a worker says
  what it could not do without guessing.
- **MUST NOT** is where the orchestrator writes what the task forbids beyond the standing
  items. The standing items restate what the definitions already enforce: they carry no
  Write, Edit or Agent tool (`selftest/test_agent_defs.sh` holds that), and the Bash hook
  denies a detached job. They are repeated so a review can hold the return to them.
  Bash can still write a file; that one is held by the spec alone.
- **STOP** makes a failed command a report rather than a detour.

## What a spec does not do

- It does not make a figure RIGHT. It makes it traceable: the command that produced it,
  run again, must reproduce it. Whether that command answers the TASK is the reviewer's
  to judge.
- It does not bind a fork. A fork is the orchestrator continuing (lineage ruling,
  2026-09-23), not a worker. Its return is read like the orchestrator's own statements.
- It does not make a worker's figure a measurement of THIS sitting for the orchestrator.
  Until re-derived, it is a filed count (`CLAUDE.md` §6).
