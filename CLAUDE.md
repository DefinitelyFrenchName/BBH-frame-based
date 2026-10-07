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

The extraction is PROVED, never asserted ([BBH-81]): `selftest/test_fidelity_vampire.sh`
runs the lineage's own tools and bbh's over the same input and diffs the verdict
text, rows F1–F11. That is why bbh still carries the lineage's build names as
defaults, and why it moves when the lineage moves (§5).

**Siblings:**
- **The lineage** never consumes bbh (`docs/conventions.md` 6, [BBH-66]); its
  config lives here as `example/consumers/bbh.vampire.toml`. It reaches back in
  through its own gate `tests/test_bbh_fidelity.sh`, which runs our fidelity test
  with `BBH_FIDELITY_ROOT` set.
- **BBX** (`~/Developer/generalized-blackbox-harness/BBX`) generalizes bbh to any
  subject and uses bbh as its fidelity subject (`BBX_BBH_HOME`). A change here can
  move BBX's fidelity rows: say so in the commit when it might.

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
| a fidelity row's text moved | `docs/rebaselines.md` |
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
- **The fidelity contract's text is never changed silently** — [BBH-83]: a
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

**The standing selftest tally** is PASS 32 / SKIP 2 / FAIL 0, as last recorded
green in `ca014d9`'s body (2026-09-26). The two standing SKIPs are
`test_fidelity_mame` (opt-in) and `test_rpl_lua` (no standalone `lua` on the
host). Any other SKIP is a finding, not weather. This line is a FILED COUNT, so
re-measure before quoting it. On 2026-10-07 at `57d5c5c` the selftest measured
PASS 31 / SKIP 2 / FAIL 1 in 326 s. The one red was fidelity F3b/F3c reading an
orphan gate in the lineage's unpushed working tree: a lineage finding, not a bbh
one ([BBH-24]).

`test_fidelity_vampire` reads the lineage's WORKING TREE, not a commit. So a red
there is first a question about the lineage's state ([BBH-7]): check the lineage's
`git status` and its newest commits before suspecting bbh.

**Fidelity against the lineage** (`selftest/test_fidelity_vampire.sh`) finds the
lineage through `example/consumers/bbh.vampire.toml`'s relative `[project].root`,
or `BBH_FIDELITY_ROOT` (absolute) when set, and SKIPs if the tree is absent.
Opt-in depth: `BBH_FIDELITY_F5=<N>` (every Nth masked spec; `1` = all),
`BBH_FIDELITY_F6=all`, `BBH_FIDELITY_F7=all`, `BBH_FIDELITY_F2=1` (the lineage's
whole portable tier — never beside another gate in that tree), and
`BBH_MAME_FIDELITY=1` with `ROMDIR` for F8 on real emulators (`test_fidelity_mame.sh`).

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

## 5. Working with the lineage

- **The session record is the LINEAGE's** (maintainer-ruled 2026-10-07). bbh keeps
  no STATE or HANDOFF. A sitting that changes bbh records itself in the lineage's
  `STATE.md` under its `14z-N` tag; a sitting begun here closes with a line there.
  bbh's own durable record is its git log, `docs/conventions_history.md`,
  `docs/rebaselines.md`, and this repository's GitHub issues.
- **Citations.** Lifted comments and commits keep lineage incident citations
  (`14z-N`, `GitHub #N`) as history; no lineage RULE ANCHOR (`[VSP-N]` and kin)
  travels into this tree ([BBH-86]) — translate it into words.
- **Issues.** A defect only in bbh is an issue on this repository. A defect in
  BOTH copies is one lineage ticket that names both (the shape of lineage #140,
  fixed here as `ca014d9`).
- **Commits** go straight to `main` (there are no PRs here). Subject
  `<area>: <what changed, in prose>` — areas seen: `config`, `selftest`,
  `run-static`, `docs`, `README`, `rebaselines`, `consumer config`. The body gives
  the cause, the fix, what is NOT claimed, and a `Verified:` line of tallies
  measured in that sitting (e.g. the selftest tally, `check-skills ALL PASS`,
  `skill-guide --check current`, the fidelity verdict). Cite the lineage sitting:
  `(lineage 14z-N)`.
- **The re-point.** When the lineage freezes a milestone, its current build
  directories move one step and bbh must follow, or fidelity F4 goes red. The
  lineage's own re-point sweep cannot see this repository, so the re-point is a
  bbh commit of its own, `config: the M<N> re-point (lineage 14z-<S>) — …`,
  touching four files: `lib/py/bbh/config.py` (the `[sweep]` placeholders and the
  `[inp].build` default), `docs/config.md` (the documented `[inp].build` default),
  `example/consumers/bbh.vampire.toml` (`[inp].build`, with its chained
  re-pointed comment), `selftest/test_fidelity_vampire.sh` (F6's sampled build
  dirs). Template: `git show 57d5c5c`.
- **Push** only under the lineage's close rule, which governs bbh pushes too: the
  selftest at its standing tally, `check-skills` ALL PASS, `skill-guide --check`
  current, fidelity green when the lineage is present — and, for a fidelity-text
  change, bbh pushed BEFORE the lineage ([BBH-83]). A red, an extra SKIP or an
  unresolved item leaves the commits local, and the close says so. Nothing in
  THIS repository enforces that mechanically yet: see §6.

## 6. Agents

The lineage's agent architecture (its GitHub #172: worker definitions, a spec
template, deterministic hooks, a context-free rule-checker) is NOT installed here:
there is no `.claude/` in this repository, so a session started here runs with
none of the lineage's hooks. The equivalent is `docs/agents_scope.md`, **ACCEPTED
by the maintainer 2026-10-07, NOT YET BUILT** (Phase A next). Until Phase A
lands, these hold because they need no tooling:

- Every figure you quote comes from a command run in THIS sitting. A figure from a
  subagent, an issue, an older note or this file is a FILED COUNT until re-derived.
- No detached job (`nohup`, `setsid`, `disown`, a trailing `&`): use
  `run_in_background` or Monitor, so its end wakes the session.
- No agent at `max` effort, ever (lineage ruling 2026-09-29). The orchestrator is a
  plain session (lineage ruling: Opus 5.5 at effort High, 2026-09-25); a sitting on
  another model says so at its opener.
- A worker task is written as a spec — TASK as a question, pinned INPUTS, numbered
  COMMANDS, a RETURN of figures with their command — never as "confirm that X".
- Hand the maintainer a checker's verdict verbatim, never summarised.

## 7. Do-nots

- Do not hand-edit `GUIDE.md` or a generated gate index.
- Do not carry a number forward; re-measure it (§6).
- Do not put a lineage literal (game, build, board, `14z-`) into the skill.
- Do not loosen a classifier, a threshold or an oracle class to turn a red green.
- Do not change a fidelity row's text without the two-sided, loud re-baseline.
- Do not make bbh depend on a consumer's tree; the lineage is a fidelity input,
  never a runtime dependency ([BBH-85]: found by `$BBH_HOME`, never a submodule).
- Do not push with a red, or with a SKIP beyond the two standing ones.
