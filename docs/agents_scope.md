# The agent swarm for bbh — scope and proposal

> **ACCEPTED 2026-10-07; PHASE A BUILT THE SAME DAY, except the settings install (the maintainer's act, §4).** The maintainer, on reading it: *"The
> proposal is fine by me."* This is read as §6's open rulings R1–R7 taken as
> recommended; any of them can still be overturned by name. This is a scope page,
> not a reference page, so it carries no `**[BBH-N]**` anchor. Its rules move into
> anchored reference pages as Phase A lands. Modelled on the lineage's
> `docs/project/agent_architecture_scope.md` (its GitHub #172). Every figure below
> was measured on 2026-10-07 by the command quoted beside it, against the
> lineage's working tree at `dbaed3a0` and this repository at `57d5c5c`.

**Already ruled (maintainer, 2026-10-07, at the plan stage of this page):**
1. **The session record is the lineage's.** bbh gets no STATE.md or HANDOFF.md.
2. **A dev setup now, then a lift later.** Phase A is bbh's own `.claude/` (§4).
   Phase B lifts the deterministic pieces into the product, proved by fidelity (§5).
3. **This page is the proposal**, left uncommitted for review.

---

## 1. Why

There is no `.claude/` in this repository. A session started here runs without
any of the lineage's hooks, because project hooks load from the session's own
project. Today nothing mechanical binds four things in a bbh session:
- detached jobs;
- an agent call above its caps;
- a worker task without a spec;
- a push without a procedure check.

The lineage's CLAUDE.md says "Pushing bbh follows the same rule under its standing
authorisation". Its push hook, `pre_push.py`, ALLOWS pushes of other repositories,
so even a lineage session pushing bbh is bound by the ritual alone, not by a hook.

## 2. Census — the lineage swarm as it stands

**Agent definitions** (`.claude/agents/`, tracked; frontmatter read with `head -8`):

| definition | model | effort | tools | role |
|---|---|---|---|---|
| `measurer` | `sonnet` | `high` | Bash, Read, Grep, Glob | runs a spec's numbered COMMANDS exactly as written; returns `FIG <name> = <value> <- C<n>` or `NOT MEASURED: …`; no commentary |
| `reader` | `sonnet` | `high` | Read, Grep, Glob | the same for what a file SAYS; returns verbatim quotes with `path:line` |
| `rule-checker` | `claude-opus-5-5` (pinned id) | `high` | Read, Grep, Glob; `omitClaudeMd: true` | context-free; reads only the files a `tools/rulecheck.py`-prepared prompt names; answers fixed questions |

None of the three can spawn an agent, and none can Write or Edit. The rule-checker
also cannot run anything.

**The worker spec** (`docs/project/worker_spec.md`, 74 lines). Six fixed headings:
`TASK:` `INPUTS:` `COMMANDS:` `RETURN:` `MUST NOT:` `STOP:`.
- TASK is a QUESTION, never a conclusion to confirm.
- INPUTS pins what can move (`git show <sha>:<path>`, not HEAD).
- A fork is "the orchestrator continuing", not a worker, and takes no spec.

**Hooks** (`.claude/settings.json`, PreToolUse, each 10 s, each FAIL-OPEN with a log line):

| hook | matcher | denies |
|---|---|---|
| `tools/agent/hooks/pre_bash.py` (C0.1) | Bash | `nohup`, `setsid`, `disown`, a backgrounding `&` with no later `wait`; a `pgrep`-conditioned wait loop |
| `tools/agent/hooks/pre_push.py` (C1 binding) | Bash | `git push` of THIS repository unless `tests/rulecheck/ledger.tsv` holds an OK or resolved `procedure` run whose checked commit lies in the pushed range |
| `tools/agent/hooks/pre_agent.py` (S4 call gate) | Agent\|Task | (a) a `model` above Opus-class; (b) any `model` on a defined worker; (c) an undefined type with no model, unless self-capped (`Explore`); (d) a spec-driven worker whose prompt lacks a heading. A fork is allowed. |

`permissions.deny` edit-locks `.claude/settings.json`, `tools/agent/hooks/**` and
`tools/agent/agentlib.py`, so only the maintainer changes the enforcement.

**Tooling**, measured with `wc -l tools/agent/*.py tools/agent/hooks/*.py tools/rulecheck.py`:

| piece | lines |
|---|---|
| `agentlib.py` (the one launch classifier) | 187 |
| `agent_defs.py` (static cap check on every definition) | 137 |
| hooks: `pre_bash.py` | 71 |
| hooks: `pre_agent.py` | 123 |
| hooks: `pre_push.py` | 158 |
| `sweep.py` (C0.3, no process outlives its purpose) | 405 |
| `transcript_gaps.py` (idle-gap census, `--cap` worker-cap read) | 586 |
| `extract.py` (transcript extract for the procedure check) | 453 |
| `rulings_verbatim.py` | 246 |
| `close_loop_cost.py` | 206 |
| `cut_worker_fixture.py` | 111 |
| `tools/rulecheck.py` (prepare / record / resolve, paired plants, ledger) | 1266 |

`tools/agent/` totals 2,683 lines. Of those, the enforcement core (agentlib +
agent_defs + the three hooks) is 676.

**Gates:** `tests/test_agent_defs.sh` (102), `test_agent_hooks.sh` (337),
`test_agent_sweep.sh` (313), `test_agent_extract.sh` (105), `test_agent_worker.sh`
(141), `test_rule_checker.sh`.

**Specs:** `docs/project/agent_architecture_scope.md` (401), `docs/project/rule_checker.md` (448).

**The rulings in force.** These are quoted from lineage `STATE.md` "Standing rulings"; the full entries are in `DECISIONS_HISTORY.md`:
- *"No model used in the swarm is allowed to use max effort, under any
  circumstance"* (2026-09-29, 14z-185). The same ruling preferred workers on
  Sonnet at `xhigh`; that preference was dropped at 14z-192.
- The orchestrator is a PLAIN session, Opus 5.5 at effort High (2026-09-25). It has no
  orchestrator definition, because `--agent` replaces the default system prompt.
- A block binds the TASK AT FAULT, never the session (2026-09-23, 14z-175: *"Hard
  block + written resolve is fine but that doesn't mean that the session should
  grind to a halt"*).
- Forks are allowed and are the orchestrator continuing. A `/btw` fork is exempt
  from the worker cap.
- The rule-checker is pinned and context-free. Every real run is PAIRED with a
  planted violation, and a missed plant VOIDS the verdict. Its output reaches the
  maintainer verbatim.

## 3. Liftability — [BBH-1] asked of each piece

| piece | bin | why |
|---|---|---|
| `pre_bash.py` + `agentlib.py` | **code** | detached launches are a property of the agent platform, not of the subject |
| `pre_agent.py` | **code** + **config** | the logic is generic. Worker names, the spec path, the model cap and the self-capped built-ins are VALUES a consumer declares. |
| `agent_defs.py` | **code** + **config** | the same split: the allowed keys and tools are generic, the required set is declared |
| `pre_push.py` | **code** + **config** | "no push without X" is generic; X (a ledger, a green record) is the consumer's |
| the worker spec, `measurer`, `reader` | **code** (templates) | names no project |
| `sweep.py`, `transcript_gaps.py`, `extract.py` | **code** | about Claude Code sessions, not about any subject |
| `rulecheck.py`, its checklists, its calibration fixtures | **open** (R5) | generic in mechanism, but its subject is a DOCUMENT packet. Convention 5 put documentation tools OUT of bbh; lineage #119 parks a living-documentation sibling. |
| `--session 14z-N` regex, ledger path, the remote hosts | **stays with the consumer** | lineage literals |

Everything above passes the extraction question. But bbh's own precedent for lifting is
"a generic thing needs two instances" ([BBH-87]). Lineage #119 adds that extracting a second package is
"infrastructure built on infrastructure" while bbh's usefulness is "still untested by a second consumer".
Phase A therefore comes first: bbh's own `.claude/` is the SECOND instance that earns the lift.

## 4. Phase A — bbh's own dev setup (BUILT 2026-10-07; the settings file awaits the maintainer)

| file | what | source |
|---|---|---|
| `.claude/agents/measurer.md` | copy; spec path re-pointed | lineage `.claude/agents/measurer.md` @ `dbaed3a0` |
| `.claude/agents/reader.md` | copy; spec path re-pointed | lineage `.claude/agents/reader.md` |
| `.claude/agents/rule-checker.md` | copy, verbatim (pinned model id, `omitClaudeMd: true`) | lineage; driven by the LINEAGE's `tools/rulecheck.py`, because the session record and its ledger are the lineage's (ruling 1) |
| `.claude/worker_spec.md` | the template; lineage-only notes cut | lineage `docs/project/worker_spec.md` |
| `.claude/agent/agentlib.py`, `agent_defs.py`, `hooks/pre_bash.py`, `hooks/pre_agent.py` | copies in the lineage's own layout (R2 as amended), each carrying a `COPIED INTO bbh … @ dbaed3a0` paragraph; `TEMPLATE` re-pointed | lineage `tools/agent/` |
| `.claude/settings.json` | the two hooks, plus `permissions.deny` on `Edit(.claude/settings.json)`, `Edit(.claude/agent/hooks/**)` and `Edit(.claude/agent/agentlib.py)`. **NOT WRITTEN:** the agent's attempt was refused as self-modification (2026-10-07), and the content is handed to the maintainer to install | lineage `.claude/settings.json` |
| `selftest/test_agent_hooks.sh`, `test_agent_defs.sh`; `selftest/agent/c01_commands.jsonl`, `pre_agent_cases.py` | ported with their must-fire controls (7 and 4), plus one new control, `unwired-settings`. Push hook, ledger, hint and census not ported (R1) | lineage `tests/` |
| `CLAUDE.md` §6 | rewritten to the rules in force | — |

**Costs and edges:**
- **Copy drift.** The copies and the lineage's can diverge silently until Phase B's F12 proves them equal. Each header names the lineage commit it was taken from, so `git diff <sha> HEAD -- tools/agent` in the lineage shows what moved.
- **The settings file needs the maintainer.** It is maintainer-installed, as in the lineage, and an agent cannot edit it once the deny rule exists. The first install is the maintainer's act.
- **The selftest tally moves.** Two new gates take it from 34 to 36 tests, and the standing tally from PASS 32 to PASS 34. The only place that quoted it, `CLAUDE.md` §3, was found by grep and updated ([BBH-8]).
- **No `sweep.py` or `transcript_gaps.py` in Phase A.** The close that runs them is the lineage's (ruling 1).

## 5. Phase B — the lift (proposed; after Phase A has run)

- **The code.** `lib/py/bbh/agent/` holds `agentlib`, `defs`, and `hooks/{bash,agent,push}`. The CLI is
  `bbh agent-defs`, `bbh agent-hook bash|agent|push` (reads the hook JSON on stdin),
  `bbh agent-sweep` and `bbh agent-gaps`.
- **The config.** An `[agents]` table:
  - `workers` (name list);
  - `spec_template` (path);
  - `model_allow` (regex, default Opus-class);
  - `self_capped` (default `["Explore"]`);
  - `required_headings`;
  - `push_gate` (a command whose exit 0 allows the push).

  Missing-key FATAL ([BBH-62]); every default goes into `docs/config.md` and, if ruled, the register.
- **Fidelity F12.** The lineage's hooks and bbh's run over the lineage's own hook cases
  (`tests/lib/pre_push_cases.py`, the `test_agent_hooks.sh` fixtures), and the verdict
  text is diffed ([BBH-81]). After that, bbh's `.claude/settings.json` calls `bin/bbh agent-hook`,
  so bbh dogfoods its own product and the Phase A copies are deleted.
- **F13, if ruled into bbh at all.** The rule-checker: `prepare` / `record` / `resolve`,
  the paired plant, and the ledger.
- **A skill for the discipline.** Its own prefix (one candidate: `AGT`) and its own `[skill_AGT]` table, or rules
  folded into `BBH`. This is open (R6).

## 6. Open rulings — each with a recommendation

- **R1 — The push gate in Phase A.**
  - **Recommended:** no bbh push hook. The lineage's close binds bbh pushes, as it does today, and CLAUDE.md §5 says so.
  - Alternative: a bbh `pre_push.py` that denies `git push` unless a selftest run at HEAD recorded the standing tally. Declined for Phase A: it invents a ledger bbh does not have, and ruling 1 put the record in the lineage.
- **R2 — Where the dev copies live.**
  - **Recommended:** `.claude/hooks/` and `.claude/worker_spec.md`. They sit outside every product directory, so no consumer mistakes them for bbh.
  - **AMENDED AT BUILD (2026-10-07):** `.claude/agent/` in the lineage's own `tools/agent/` layout, with the fixtures in `selftest/agent/`. The copies then diff line for line against the lineage, the hooks' path arithmetic is unchanged, and F12 has less to bridge. Still outside every product directory.
  - Alternative: `tools/agent/` as in the lineage, which would add a fifth top-level kind of directory for one phase.
- **R3 — Inherit the lineage's swarm rulings wholesale?**
  - **Recommended:** yes, cited by date: no `max`, orchestrator Opus 5.5 High, worker caps, forks allowed, verbatim checker output.
  - Alternative: re-rule each for bbh.
- **R4 — The order.**
  - **Recommended:** Phase A, then one real bbh sitting under it, then F12. F13 waits for R5.
- **R5 — The rule-checker's home.**
  - **Recommended:** NOT bbh. Its subject is a document packet, so it belongs with the living-documentation sibling (lineage #119), per convention 5.
  - Alternative: bbh, as F13.
- **R6 — Skill shape after Phase B.**
  - **Recommended:** a separate prefix and skill. The agent discipline is about the CONTRIBUTOR, not the subject, and a consumer may want one without the other.
- **R7 — Do the dev-tool gates join `bbh selftest`?**
  - **Recommended:** yes. A check without a gate dies silently, and the lineage's hook gate is what keeps fail-open hooks honest.

## 7. What it will not catch

These are carried over from the lineage scope §7, because each still holds here:
- **A job launched other than through a tool.** The hooks see only tool calls.
- **A detaching form the denylist does not name.** Such a form passes until it is added.
- **A statement the transcript never recorded.** Any later procedure check can only miss on it, never flag it falsely.
- **The maintainer's time outside the session.**

These are new to bbh:
- **A session started in the lineage that edits bbh.** It runs under the LINEAGE's hooks, not these, which is the same caps in Phase A.
- **Copy drift before F12.** Nothing here catches it (§4).

## Appendix A — defects found while surveying (not fixed; offered as issues)

1. **`conventions 10` is cited in four places, but the register stops at 9.** The places are
   `docs/conventions.md:22`, `docs/rebaselines.md:4`, `selftest/test_fidelity_vampire.sh:71`, and,
   through the anchored [BBH-85] paragraph, `skill/blackbox-harness/GUIDE.md`. The rule meant is entry 8
   ([BBH-83]). Fixing it regenerates the guide.
2. **`bbh.toml.example` still shows `m3b_merged23` / `don_m20` / `hui54` / `pyron38` / `m5_stock15`**
   (lines 89, 173), but its header says the value shown is the DEFAULT. Those are the old
   values, and it is not in the re-point's four files.
3. **The `bin/bbh` usage text and some Python docstrings still carry the extraction slice tags
   `H2`…`H10`**, which [BBH-9] removed from the reference pages.

## Appendix B — remote state, 2026-10-07 (read-only; reported, not acted on)

- **bbh** (`DefinitelyFrenchName/BBH-frame-based`):
  - local `main` equals remote `main` (`57d5c5c`);
  - no PRs ever, no tags, no releases, no CI;
  - 3 open issues (#1–#3, `bug`), 0 closed.
- **The lineage** (`DefinitelyFrenchName/VampireSaved`):
  - local `main` (`dbaed3a0`) is 6 commits ahead of `origin/main` (`cd3693d0`) (`git rev-list --count origin/main..HEAD`), with uncommitted work in progress;
  - release `merged-m23` is published, but the commit recording it is among the unpushed six;
  - CI (`.github/workflows/ci.yml`) has failed every run since 2026-09-23. The last
    success was 2026-09-23T10:56Z (`gh run list -L 100`). The latest failure is a submodule
    checkout: `emu/jtcores` points at `793339da`, which its remote does not have.
- **bbh's selftest against that working tree.** It measured PASS 31 / SKIP 2 / FAIL 1 in 326 s (`bin/bbh selftest`).
  - The red is `test_fidelity_vampire`, rows F3b and F3c. The gate
    `tests/audit_release_linux_desktop.sh` is emulator-free but listed in neither
    `ci_static.txt` nor `ci_portable.txt`. It came in with the unpushed lineage commit `dbaed3a0`.
  - bbh's tier classifier names the gate as an orphan in both rows. Nothing in bbh moved (its HEAD equals the remote), so
    this is a finding about the lineage, not about bbh ([BBH-24]). The lineage's own anti-orphan check
    was not run here.
