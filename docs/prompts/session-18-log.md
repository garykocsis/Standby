# Session 18 — Post-F10 README Institutional / Economic Framing — Implementation Log

Claude implementation chronology for the Session 18 README presentation task. Audit artifact only; it
defines no protocol semantics, closes no gate, and changes no project status.

---

## Repository state entering Session 18

Branch: `docs/session-18-readme-institutional-framing`, clean except the untracked session prompt
`docs/prompts/session-18-readme-presentation.md`.

Last commit: `e33f0c4 feat: complete F10 demo and submission readiness (#19)`.

`docs/project-status.md` records F0–F10 complete, every gate closed, G10 CLOSED / PASS, no open gate, and
F9T optional and off the critical path. The session prompt confirms that state and forbids reopening it.

Authorized modification for this session: `README.md` only.

---

## Scope-boundary note recorded before editing

Session prompt §22 lists `docs/` among the directories not to modify, while `CLAUDE.md` (Session Prompt
Discipline — Material Prompt Logging) permanently requires `docs/prompts/session-NN-log.md` to exist for a
version-controlled session and to be created before implementation changes. Session prompt §3 states the
prompt "does not modify or supersede permanent repository operating behavior", and §22's prohibitions are
directed at protocol code, tests, canonical artifacts, frozen diagrams, and `project-status.md`.

Resolution: this log file is created under `docs/prompts/` as the permanent instruction requires. No other
file under `docs/` is touched, and `docs/project-status.md` is not updated.

---

## Authoritative grounding read before editing

The new framing was checked against the canonical artifacts rather than composed from the existing README:

| README claim                                                         | Canonical source                                             |
| -------------------------------------------------------------------- | ------------------------------------------------------------ |
| Capacity Obligation begins at validity, before exercisability          | `economic-agreement.md` §6.4, §7.6; `mechanism.md` §3, M1      |
| Expiry releases the obligation and is not fulfillment                  | `economic-agreement.md` §9.11, §3.14; `mechanism.md` M4        |
| Fulfillment requires actual attributable Beneficiary delivery          | `economic-agreement.md` §9.3, §9.5; `mechanism.md` M3          |
| Compatible shared use continues while an obligation is outstanding     | `economic-agreement.md` §7.8, §10.1, §10.8; `mechanism.md` M5  |
| `S ≥ O`, equality sufficient, no excess-capacity requirement           | `economic-agreement.md` §7.4, §7.5; `mechanism.md` §3          |
| Capacity assurance is distinct from price assurance                    | `economic-agreement.md` §5.4, §6.7                            |
| Compensation is economically relevant but unprescribed                 | `economic-agreement.md` §7.10; `mechanism.md` §8              |
| Market is emerging, not commercially proven                            | `context.md` §5.10                                            |
| Half-open exercise window `exercisableFrom <= t < validUntil`          | `src/StandbyHook.sol` `_requireExercisableCommitment`, window validation |
| Three fail-closed eligibility predicates in an external registry       | `src/EligibilityRegistry.sol`                                 |

---

## Edit decisions

### D1 — Restructure by insertion, not rewrite

The existing README composition (problem → core idea → realization → demo → non-claims → verification →
documentation) was already sound. The institutional framing was inserted as new sections around it rather
than by rebuilding the document, per session prompt §21 ("adapting minimally to the existing README").

Preserved verbatim: both Mermaid diagrams, the A1–A4 table and bullets, the realization table, the demo
run instructions, the non-claim section's substance, the verification commands, and the documentation map.

### D2 — Keep illustrative and canonical numbers in separate evidence classes

The illustrative institutional example uses $5M / $500K and says explicitly that those figures are not the
canonical fixture. The canonical fixture keeps its 80,000 / 50,000 / 15,000 / 20,000 MockUSDC quantities
unchanged. The pre-existing "may need 50,000 USDC tomorrow" phrasing in **The problem** was generalized to
"a specific quantity of USDC tomorrow" so that the only place a reader meets 50,000 is the canonical fixture.

### D3 — Economics framed as unimplemented production-path reasoning

The **Protocol economics** section names the capacity-premium direction conceptually and then states
explicitly what the reference implementation does not implement (pricing, premium distribution, auctions,
utilization curves, LP attribution, a capacity marketplace), and separates payment for the capacity right
from the input settlement owed at exercise.

### D4 — Permissioning boundary stated, no integration claimed

`EligibilityRegistry` is described as the implemented mechanism. The README states plainly that Standby is
not an integration with Uniswap Permissioned Pools, names no external institution, and adds no external
link.

### D5 — Verification numbers confirmed, suite not re-run

The accepted evidence figures were added to the Verification section. The test count was confirmed with
`forge test --list` (590 test functions) rather than by re-running the suite, which session prompt §25
excludes for documentation-only work. The coverage baseline is reported as the recorded F10 baseline.

---

## Verification performed

```text
git diff --check
git diff --stat
git status
grep -c mermaid / diagram byte comparison against HEAD
relative documentation link existence check
```

Results are recorded in the completion report appended below.

---

# Required Task Completion Report — Session 18

## Files Inspected

Repository instructions and process:

- `CLAUDE.md`
- `.claude/rules/solidity-style.md`, `.claude/rules/testing.md` (loaded by path scope; no Solidity touched)
- `docs/prompts/session-18-readme-presentation.md` (the authorizing session prompt)
- `docs/prompts/session-17-log.md` (log format; F10 evidence figures)

Canonical and live artifacts:

- `docs/project-status.md`
- `docs/context.md` (§§2–3, 5.6–5.10, 6)
- `docs/economic-agreement.md` (complete)
- `docs/mechanism.md` (complete)
- `docs/reports/coverage-summary.md` (computed-aggregate section)

Source:

- `src/StandbyHook.sol` — `Commitment` struct, `_requireExercisableCommitment`, commitment-window
  validation, half-open validity errors
- `src/EligibilityRegistry.sol` — the three fail-closed predicates and their isolation

Presentation baseline:

- `README.md` at `HEAD` (`e33f0c4`)

## Files Changed

| File                                 | Change   | Why                                                                 |
| ------------------------------------ | -------- | ------------------------------------------------------------------- |
| `README.md`                          | modified | The authorized Session 18 presentation task                          |
| `docs/prompts/session-18-log.md`     | created  | Required by `CLAUDE.md` Material Prompt Logging for this session     |

No other file was created, modified, or deleted. `docs/project-status.md` was not touched.

## Requirements Implemented

Session prompt §§6–21 README presentation requirements: judge-facing causal narrative, target actors,
illustrative institutional example, time-bounded commitment lifecycle, Uniswap v4 rationale, preserved
`S >= O` and non-reservation framing, protocol-economics boundary, permissioned-market relationship,
preserved realization/A1–A4/non-claim/verification/documentation material, and a new **Path to production**
section in the prescribed position.

No protocol requirement was implemented, changed, or reinterpreted. No gate was advanced.

## Tests Added or Changed

None. This is a documentation-only task; §25 excludes the protocol suite.

## Commands Run

```bash
git status
forge test --list                       # to confirm the 590 figure without re-running the suite
git diff --check
git diff -- README.md
git status --porcelain
python3  # mermaid block byte-comparison against HEAD; relative-link existence check
gh repo view --json repositoryTopics    # read-only metadata check
```

## Results

- `git diff --check` — clean, no whitespace errors.
- `git status --porcelain` — `M README.md` plus the two untracked `docs/prompts/session-18-*` files.
- Mermaid comparison — 2 blocks before, 2 after, **both byte-identical to `HEAD`**.
- README diff removals — exactly two lines, both in **The problem**, replaced by the generalized wording
  in D2. Every other change is an insertion, so the A1–A4 table, the A1–A4 bullets, the realization table,
  the demo instructions, the non-claim section, the verification commands and the documentation map are
  textually unchanged.
- `forge test --list` — 590 test functions, matching the accepted evidence figure.
- Relative links — all 14 `docs/` targets resolve; the referenced `script/demo/run-demo-environment.sh`,
  `script/DemoActions.s.sol`, `demo.env` and `frontend/` all exist.
- `gh repo view` — the repository topic already reads `protocol-engineering`; the typo no longer exists.

## Gate Evidence

None, and none sought. G10 is closed and no gate is open. This task produces presentation evidence only.

## Known Limitations / Blockers

- The coverage figures are reported as the **protocol-core** aggregate (hook, router, registry, three
  libraries) because that is the scope `docs/reports/coverage-summary.md` attaches them to; the unqualified
  form would have overstated the scope.
- The verification figures are carried from the accepted F10 evidence rather than regenerated; only the test
  count was independently re-confirmed.
- No external link to Uniswap Permissioned Pools was added. §14 makes linking optional, and inventing a URL
  would have been worse than omitting one.

## Scope Check

Within scope. `README.md` was the only authorized file and the only substantive change.

One file outside §22's literal list was created: `docs/prompts/session-18-log.md`. `CLAUDE.md` requires it
for a version-controlled session and requires it before implementation changes; §3 of the session prompt
states the prompt does not supersede permanent repository operating behavior. Recorded above as the
scope-boundary note. No protocol code, test, frozen artifact, diagram, or status document was touched.

## Proposed Gate Assessment

**NOT EVALUATED.** No gate is open. G10 is closed and this task does not bear on it.

## Recommended Next Step

Commit the README change on the current branch. Nothing further is required for the demonstration; F9T
remains optional and off the critical path.

## Prompt Audit

The session was initiated from `docs/prompts/session-18-readme-presentation.md`. **0 material follow-up
prompts** were received and therefore 0 are recorded. The only follow-up instruction was the initiating
directive to read `CLAUDE.md` and execute the session prompt, which is the prompt itself rather than a
material change to it.

*(Superseded by Prompt 1 below, received after this report was produced. The audit count for the session as
a whole is **1 material prompt**.)*

---

# Material Follow-Up Prompts

## Prompt 1 — Correct the expiry paragraph to admit prior partial fulfillment

**Source:** `docs/prompts/session-18-followup-correct-paragraph.md`

**Instruction.** One narrow semantic correction to the Session 18 README update. In the time-bounded
commitment lifecycle section the text "An expired commitment was never exercised and the Beneficiary
received nothing..." is too strong, because a commitment may be partially fulfilled before `validUntil` and
then expire with remaining unfulfilled entitlement. Preserve the callout **"Expiry releases an obligation.
Expiry is not fulfillment."** and replace the explanation immediately following it with wording equivalent
to: when a commitment reaches `validUntil`, any remaining unfulfilled entitlement ceases contributing to
Capacity Obligation; expiration does not represent that remaining entitlement as fulfilled or imply
additional Beneficiary delivery; the practical consequence is that Standby protects a bounded quantity of
future execution capacity for a bounded period rather than imposing an open-ended constraint on shared
liquidity. Make no other editorial changes unless strictly necessary. Record the follow-up in this log and
re-run the lightweight documentation verification.

**Why the correction is right.** It restores agreement with the canonical artifacts. `economic-agreement.md`
§9.6 establishes partial fulfillment, and §9.11 with `mechanism.md` §7.2 (Release) states that prior partial
fulfillment remains fulfillment and does not change the economic classification of the later release of the
remainder. The superseded sentence asserted "the Beneficiary received nothing", which is false for a
partially fulfilled commitment that later expires.

**Implementation consequence.** One paragraph replaced in `README.md` under **A commitment is bounded in
quantity *and* in time*. The callout above it is unchanged. No other README text was touched; the preceding
bullet ("Once `t >= validUntil`, the commitment stops contributing to Capacity Obligation") was already
correct and was deliberately left alone under the no-other-edits constraint. The resulting distinction the
README now carries is:

```text
successful fulfillment
    → fulfilled quantity reduces Remaining Entitlement and O
    → actual attributable Beneficiary delivery occurred

expiration
    → any remaining unfulfilled entitlement ceases contributing to O
    → expiration is not fulfillment
    → no additional Beneficiary delivery is implied
```

**Verification re-run after the correction.**

```text
git diff --check            → clean
git status --porcelain      → M README.md only
mermaid byte-comparison     → 2 blocks, both identical to HEAD
relative link check         → 14 links, 0 broken
canonical fixture counts    → 80,000 / 15,000 / 20,000 / 45,000 / 65,000 unchanged vs HEAD;
                              50,000 unchanged apart from the earlier D2 generalization
```

**Note.** An untracked `readme-diff.md` exists at the repository root. It was not created by this session
and was left untouched.
