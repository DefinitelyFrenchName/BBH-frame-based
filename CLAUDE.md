# CLAUDE.md — the blackbox harness (`bbh`)

> **DRAFT 2026-10-07, not yet ruled.** Read this file first, then `README.md`.
> This file is the MAP and the working rules; the RULES THEMSELVES live in the
> docs, anchored `**[BBH-N]**`, and this file cites them and never restates them.
> A rule quoted here in a second wording is a second copy, and the second copy is
> the one that rots ([BBH-8]).

---

## 0. What this repository is

bbh is a test harness for black-box systems under deterministic, scripted input,
EXTRACTED from Project VAMPIRE SAVED — "the lineage" everywhere in this tree
(`~/Developer/Vampire_Saved/VampireSaved`, `github.com/DefinitelyFrenchName/VampireSaved`).
Every piece here passed the extraction question ([BBH-1]): *would this still be
true if the thing under test were not that ROM, not that board, not even a game?*
What failed it stayed in the lineage. Every file sits in one of the four bins
(code / config / machine profile / stays with the consumer — `README.md` "The
four bins").

**SCOPE: FRAME-DRIVEN SUBJECTS ONLY.** Every piece that judges the subject is
indexed by FRAME:
- the `.rpl` replay grammar;
- the driver log (one `<frame> <hash>` line per frame);
- the suite, the sweep and every oracle class;
- the field comparator;
- the Lua layer.

The frame-free pieces (classifier, static runners, tier, hygiene, skills lock)
serve those and are not offered as a general harness (`README.md` "Scope"). A
subject that is not driven frame by frame belongs to BBX, not here. Do not
describe bbh, in a doc, a commit or a reply, as handling one.

Within that scope, the harness is used DURING development, not only at release.
Its core is a verdict on a system the reader cannot see inside.

The extraction was PROVED, never asserted ([BBH-81]): `selftest/test_fidelity_vampire.sh`
ran the lineage's own tools and bbh's over the same input and diffed the verdict
text, rows F1–F11. **That contract is RETIRED** (maintainer, 2026-10-11:
*"Retire it"*; `docs/conventions.md` 8). Once the lineage became a separate project
and diverged on purpose, a live diff could only stay red. The tests are gone from
the tree; their last text is at `505417b`. The lineage's build names stay as
bbh's defaults, frozen at the M23 re-point, as dated literals ([BBH-70]).

**Siblings:**
- **The lineage** never consumes bbh (`docs/conventions.md` 6, [BBH-66]); its
  config lives here as `example/consumers/bbh.vampire.toml`. Since 2026-10-11 it is
  a separate project: no commit, record or ruling crosses between the two.
- **BBX** (`~/Developer/generalized-blackbox-harness/BBX`) generalizes bbh to any
  subject and uses bbh as its fidelity subject (`BBX_BBH_HOME`). A change here can
  move BBX's fidelity rows, and its F20 reads `example/consumers/bbh.vampire.toml`:
  say so in the commit when a change might.

## 1. Read first

1. **Load the `blackbox-harness` skill** (installed as a symlink to
   `skill/blackbox-harness/`) before writing, running, freezing or reviewing any
   gate, driver, replay, expectation or config, AND before changing bbh itself.
   Its `GUIDE.md` is the same rules with the incident behind each.
2. `docs/doctrine.md` (the seven sentences, long form) and `docs/conventions.md`
   — the register of ruled defaults. A change to any row of the register is a
   RULING, dated in place, never a silent edit ([BBH-84]).
3. The page for the area you touch:

| area | page |
|---|---|
| a gate, the prologue, verdicts, must-fire controls, registries | `docs/gate_contract.md` |
| a driver, the replay-family environment | `drivers/README.md` |
| a comparison class, a mask, reclassifying a replay | `docs/method/oracle_classes.md` |
| provenance, header defaults, ref-rot, gate index, accounting, shadow tools | `docs/hygiene.md` |
| a config key, its default, the TOML subset | `docs/config.md` |
| the MAME Lua layer, a machine profile | `docs/lua.md` |
| what the retired fidelity contract re-baselined (a closed log) | `docs/rebaselines.md` |
| the example consumer | `example/README.md` |

## 2. Hard rules (cited, not restated)

- No untested change survives — [BBH-2].
- SKIP is not PASS; exit status decides first — [BBH-6], [BBH-11..16].
- A red gate is a QUESTION, and its first question is which side rests on a
  measurement — [BBH-7].
- When a claim changes, grep for the claim, and show the empty re-grep — [BBH-8].
- The harness never weakens the classifier to make a consumer green; a delta is a
  finding about the consumer — [BBH-24].
- A replay moves to a looser oracle class only with a NEW MEASURED MECHANISM and
  the consumer's sign-off — [BBH-46].
- **The fidelity contract** — [BBH-83], RETIRED for bbh on 2026-10-11 and kept
  as the rule for any harness still bound to its original. While it stood: a
  verdict-text or classifier change lands on BOTH sides in one sitting, the moved
  rows re-baselined in the same commits, the HARNESS commit pushed FIRST, and a
  dated line in `docs/rebaselines.md` (its own commit, `rebaselines: …`).
- Every new check carries a MUST-FIRE control that has demonstrably failed on
  purpose, in the grammar of [BBH-88]..[BBH-91] (`lib/sh/controls.sh` is its only
  reader) — [BBH-21].
- A gate demands its inputs by EXPLICIT TEST after the trap is armed, never
  `${VAR:?}` — [BBH-17]; `bbh demand-after-trap` lints it.
- A driver that cannot honour a variable REFUSES it (exit 3) — [BBH-28].
- A missing config key with no default is FATAL; the config is a TOML subset —
  [BBH-62], [BBH-63].
- A literal with a date in its claim carries the date; an undated one is an
  assertion with no expiry — [BBH-70].
- **Portability floor:** every script is `#!/bin/sh` with no bashisms, and
  macOS `/bin/sh` (bash 3.2) is the floor, not Linux; Python 3.8+, standard
  library only (`bin/bbh-doctor` checks the host).

## 3. Layout and commands

| dir | holds |
|---|---|
| `bin/` | `bbh` (the dispatcher; `bbh help`) and the shell runners it calls: `bbh-run-static`, `-run-suite`, `-run-sweep`, `-classify`, `-doctor`, `-inp-play`, `-inp-corpus` |
| `lib/sh/` | the one classifier (`classify.sh`, [BBH-82]), the controls reader, config, prologue, registry, masked vocabulary, shadow tools, accounting |
| `lib/py/bbh/` | every Python subcommand (`python3 -m bbh.<x>` behind `bin/bbh`), the thresholds, the log grammar, the header parser |
| `lua/mame/` | the MAME Lua layer; board literals ONLY in `lua/mame/profiles/*.lua` |
| `drivers/` | the driver contract and the four drivers ([BBH-87]) |
| `example/` | a complete tiny consumer on a fake machine — copy from it, and the lineage's config in `consumers/` |
| `selftest/` | the harness's own gates, `run.sh` + one `test_*.sh` per piece |
| `skill/` | the consumer skill and its lock, `skills.toml` |
| `docs/` | the anchored reference pages and their `_history.md` twins |
| `.claude/` | DEV-ONLY, never part of the product: the agent definitions, the worker spec, the agent hooks copied from the lineage (`agent/`), and the maintainer-installed `settings.json` (§6) |

The consumer config is found from `--config`, then `$BBH_CONFIG`, then `./bbh.toml`.

```sh
bin/bbh selftest                                   # the harness's own gates (see the tally below)
bin/bbh check-skills --config skill/skills.toml    # the skill's ID lock, forbidden tokens, numbers-cite-a-log
bin/bbh skill-guide  --config skill/skills.toml --check   # GUIDE.md is current
cd example && ../bin/bbh run-static                # the example consumer, portable tier
FAKE_ROOT=. ../bin/bbh run-static                  # …with its static tier
FAKE_ROOT=. FAKE_ROMPATH=roms/build-a ../bin/bbh run-suite
FAKE_ROOT=. ../bin/bbh run-sweep --scope all
../bin/bbh doctor --config bbh.toml
```

**The standing selftest tally** is PASS 34 / SKIP 0 / FAIL 0 over 34 tests
(measured 2026-10-11 with a standalone lua 5.5.1: 235 s, GREEN). There is NO standing SKIP:
`test_rpl_lua` needs a standalone `lua` (`brew install lua`; `bbh doctor` says
whether one is found), and on a host without one its SKIP is a finding: the two
replay parsers then go uncompared ([BBH-73]). This line is a FILED COUNT, so
re-measure before quoting it.

No bbh gate reads the lineage's tree any more (since 2026-10-11).

## 4. Generated and locked artifacts

- **`skill/blackbox-harness/GUIDE.md` is GENERATED** (`bbh skill-guide --config
  skill/skills.toml`) and never hand-edited. Regenerate it in the same commit when
  you edit: a rule line in `SKILL.md`; any ANCHORED paragraph, table row or list
  item in a page listed under `docs` in `skill/skills.toml`; the heading above an
  anchor; `guide_header` or `guide_origin`. Editing text OUTSIDE an anchored block
  leaves the guide current — check with `--check`, do not assume.
- **Rule IDs are stable and never reused.** A new rule takes the next free
  `BBH-N` — measure it (`grep -rhoE '\*\*\[BBH-[0-9]+\]\*\*' docs drivers README.md`),
  do not remember it. Anchor it once, in the paragraph it distils, and add its
  line to `SKILL.md`.
- **The skill names no project, board, build or game, and no other skill's IDs**
  (`forbid` in `skill/skills.toml`); every number it quotes must appear verbatim in
  a log page. The incidents in GUIDE.md may name the lineage; the rules may not.
- **`_history.md` twins hold the LOG and never an anchor** ([BBH-9]): dated
  measurements, withdrawn drafts, narrative, newest first. A reference page says
  what is TRUE; nothing is deleted from either, and a corrected claim is marked in
  place with what replaced it.
- **The gate index is generated** from headers plus a family TSV (`bbh gate-index`,
  [BBH-57]) — in a consumer, and in `example/`.

## 5. Working in this project

**bbh is its OWN PROJECT** (maintainer-ruled 2026-10-11). Its sessions begin
and end here, and no commit comes from a Vampire Saved sitting. bbh does not rely
on a record in the lineage, and the lineage does not rely on one here. This
supersedes the 2026-10-07 ruling that put bbh's session record in the lineage.

- **The record.** bbh keeps no STATE or HANDOFF. Its durable record is:
  - its git log (the commit body is the session's account);
  - `docs/conventions.md` with `docs/conventions_history.md`;
  - `docs/rebaselines.md`;
  - this repository's GitHub issues.

  A ruling the maintainer gives in a sitting is recorded where it binds: in the
  register (a dated row), in the page it changes, or in this file. It is quoted in
  the commit that lands it.
- **Citations.** Lifted comments keep lineage incident citations (`14z-N`,
  `GitHub #N`) as HISTORY ([BBH-86]). No lineage RULE ANCHOR (`[VSP-N]` and kin)
  travels into this tree; translate it into words. New commits cite bbh's own
  issues (`#N`). A lineage incident is cited as `lineage #N` or `lineage 14z-N`,
  and only as the source of a fact.
- **Issues.** A bbh defect is an issue on THIS repository. Its body opens
  `**Status:** filed, NOT started (maintainer, <date>: "…")`, then the defect, a
  reproduction, and what a fix must hold. A defect that also exists in a
  consumer's copy names that copy; the consumer's own ticket is the consumer's.
- **Commits** go straight to `main` (there are no PRs here). Subject:
  `<area>: <what changed, in prose>`. Areas seen: `config`, `selftest`,
  `run-static`, `docs`, `README`, `rebaselines`, `consumer config`, `agents`.
  The body gives the cause, the fix, what is NOT claimed, and a `Verified:` line of
  tallies measured in that sitting: the selftest tally, `check-skills ALL PASS`,
  `skill-guide --check current`.
- **The lineage is history, not an input.** The fidelity contract is retired
  (`docs/conventions.md` 8), so the re-point ritual has ended. The lineage's build
  names in `lib/py/bbh/config.py` and in `example/consumers/bbh.vampire.toml` stay
  at the M23 re-point. BBX's fidelity gate (its F20) still reads that toml, so it
  stays in the tree.
- **Push** when every check is green: the selftest at its standing tally,
  `check-skills` ALL PASS, `skill-guide --check` current. A red, an extra SKIP or
  an unresolved item leaves the commits local, and the session's last message says
  so. No hook enforces the push rule here: R1's reason (the lineage's close binds
  bbh's push) is gone, and a push gate is an open question
  (`docs/agents_scope.md` R1).

## 6. Agents

The lineage's agent architecture (its GitHub #172) is installed here as a DEV
setup, Phase A of `docs/agents_scope.md` (accepted by the maintainer 2026-10-07).
Everything under `.claude/` is a copy from the lineage at `dbaed3a0`, and each file
names its source.

- **Workers:** `.claude/agents/measurer.md` (runs numbered commands, returns
  `FIG <name> = <value> <- C<n>`) and `reader.md` (returns verbatim quotes with
  `path:line`). Both are driven ONLY by a spec written from `.claude/worker_spec.md`:
  TASK (a question), INPUTS (pinned), COMMANDS, RETURN, MUST NOT, STOP. Call them
  with NO `model` parameter; their definition is the cap of record.
- **The rule-checker** (`.claude/agents/rule-checker.md`, pinned model,
  `omitClaudeMd: true`) is DORMANT. bbh has no packet producer and no ledger of
  its own, and since 2026-10-11 it may not borrow the lineage's. Do not spawn it
  until one is ruled in (`docs/agents_scope.md` R5). When it runs, hand its
  verdict to the maintainer verbatim.
- **The hooks** (`.claude/agent/hooks/`): `pre_bash.py` denies a detached job
  (`nohup`, `setsid`, `disown`, a trailing `&` with no `wait`) and a `pgrep`
  waiter loop, so use `run_in_background` or Monitor. `pre_agent.py` denies:
  - a model above Opus-class;
  - a model on a defined worker;
  - an undefined type with no model (`Explore` excepted);
  - a worker prompt missing a spec heading.

  Forks pass. A block binds the TASK at fault, never the session: redo the call in
  the allowed form.
- **The installation** is `.claude/settings.json`, written and changed ONLY by the
  maintainer. It edit-locks itself, `.claude/agent/hooks/**` and
  `.claude/agent/agentlib.py`. Agents may not create or edit it: an attempt on
  2026-10-07 was refused as self-modification, which is the intended outcome.
  Until it is installed, `selftest/test_agent_hooks.sh` is RED on its installation
  check, and the hooks do not run.
- **Gates:** `selftest/test_agent_defs.sh` (every definition states its caps) and
  `selftest/test_agent_hooks.sh` (the hooks against their frozen fixture and
  cases, and the installation). They are the only proof that the fail-open hooks
  still decide anything.
- **No push hook here.** The push rule is §5's, held by the session, not by a hook.

The rules that need no tooling hold everywhere:
- Every figure you quote comes from a command run in THIS sitting. A figure from a
  subagent, an issue, an older note or this file is a FILED COUNT until re-derived.
- No agent at `max` effort, ever (lineage ruling 2026-09-29). The orchestrator is a
  plain session (lineage ruling: Opus 5.5 at effort High, 2026-09-25); a sitting on
  another model says so at its opener.

## 7. Do-nots

- Do not hand-edit `GUIDE.md` or a generated gate index.
- Do not create or edit `.claude/settings.json`, `.claude/agent/hooks/**` or
  `.claude/agent/agentlib.py`; propose the change to the maintainer.
- Do not carry a number forward; re-measure it (§6).
- Do not put a lineage literal (game, build, board, `14z-`) into the skill.
- Do not loosen a classifier, a threshold or an oracle class to turn a red green.
- Do not make bbh depend on a consumer's tree, the lineage's included
  ([BBH-85]: found by `$BBH_HOME`, never a submodule).
- Do not push with a red or a SKIP.
