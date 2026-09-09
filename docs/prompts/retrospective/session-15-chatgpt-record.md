# Standby — Session 15 ChatGPT Reasoning Record

## GI — Full Stateful Invariant Verification

**Artifact type:** Non-normative curated retrospective record  
**Session scope:** GI — Full Stateful Invariant Verification  
**Gate:** G-I  
**Outcome:** PASS / CLOSED  
**Next authorized slice:** F9 — Canonical Acceptance

---

## 1. Purpose of This Record

This file preserves the substantive user ↔ ChatGPT reasoning associated with Session 15 and GI — Full Stateful Invariant Verification.

It is intentionally non-normative. It does not define Standby protocol semantics, replace frozen artifacts, or supersede the implementation plan, invariant package, testing strategy, or project status.

Its purpose is to retain contemporaneous evidence of:

- the user’s questions, concerns, challenges, and decisions;
- ChatGPT’s derivation of the GI verification boundary;
- distinctions between GI and prior implementation/testing slices;
- the invariant architecture and oracle/ghost-state reasoning;
- the derivation of G-I;
- independent review of Claude’s actual implementation and evidence;
- corrections and process refinements made during the session;
- post-GI coverage reasoning and review;
- methodology observations that may matter for the later project retrospective.

---

## 2. Session Starting Point

Session 15 began after completion of the full O2 implementation chain through F8D.

At entry:

- F0 through F8D were complete.
- G8D had passed.
- Production semantics were presumed complete.
- GI — Full Stateful Invariant Verification was the current blocker.
- F9 — Canonical Acceptance and F10 — Demo / Submission Readiness were not yet authorized.
- Post-F8D engineering baselines already existed for gas and coverage.
- The major question was no longer “what production behavior remains to be implemented?” but instead “can arbitrary authoritative histories violate any frozen invariant or produce divergence from independently derived expected state?”

The central shift in Session 15 was therefore from implementation construction to compositional verification.

---

## 3. User Question: What Does GI Actually Own?

The user asked an important responsibility-boundary question early in the session:

> If GI is the full stateful invariant gate, does that mean it would only include tests, and is the Hook contract basically complete pending significant issues found during testing?

### ChatGPT derivation

The answer was yes, with an important qualification.

GI is fundamentally a verification-side slice. It does not own new Standby semantics. By the time GI begins, production responsibility should already have converged through F8D.

The derived principle was:

> **GI verifies composition. It does not invent semantics.**

Therefore:

- GI should primarily add stateful invariant infrastructure and evidence.
- Production code should remain unchanged unless GI discovers a genuine counterexample against a frozen invariant.
- Any production defect found by GI must be traced back to the existing normative owner — for example F4, F5, F6B, F7, or F8A–F8D.
- A correction would reopen the affected prior gate before GI could be considered complete.

This distinction prevented GI from becoming a catch-all “fix whatever the invariant campaign encounters” implementation slice.

---

## 4. GI Responsibility Reconstruction

The exact GI responsibility was derived as:

> **GI is the production-path stateful compositional verification boundary for Standby. It must demonstrate that arbitrary sequences of successful and rejected O1, O2, O3, lifecycle, eligibility, and relevant external actions cannot drive the completed realization into an authoritative state that violates a frozen invariant, corrupts commitment history or attribution, releases obligation illegitimately, leaves reusable causal evidence, or creates a divergence between authoritative production derivations and independent verification oracles.**

A more compact accepted formulation was:

> **GI — Full Stateful Invariant Verification proves the temporal and compositional safety of the completed Standby realization by adversarially composing authoritative O1, O2, O3, lifecycle, eligibility, and relevant environmental actions through production interfaces. It uses independently derived oracle/history state to establish backing derivation equivalence, backing sufficiency, commitment conservation, fulfillment attribution and exactness, bounded-reference integrity, causal isolation, authority and rejection atomicity, custody integrity, and verification-domain completeness across canonical and generalized reachable-state campaigns. GI introduces no new protocol semantics.**

This became the governing semantic boundary for the implementation prompt and later independent review.

---

## 5. Distinguishing GI from Existing Testing

A major derivation was that GI is not simply “more fuzzing.”

The distinctions were:

- **Unit tests** establish local behavior of individual functions or responsibilities.
- **Integration tests** establish fidelity across concrete component paths.
- **Fuzz tests** explore adversarial parameter variation.
- **GI stateful invariants** explore temporal and compositional adversariality across persistent histories.

The practical consequence was that the existing large test suite could not by itself close GI.

GI needed:

- persistent state across actions;
- arbitrary action sequencing;
- successful and rejected transitions;
- histories containing multiple commitments;
- eligibility churn;
- expiry and reference reuse;
- partial and full exercise;
- backing-threatening swaps and liquidity actions;
- failure followed by later valid operations;
- independent expected-value derivation.

This is where the first true Foundry stateful invariant suite belonged.

---

## 6. Stateful Architecture Derived Before Implementation

The required architecture was derived as:

```text
production fixture
    ↓
adversarial handler
    ↓
production interfaces
    ↓
authoritative production state
    ↓
independent oracle / remembered history
    ↓
transition-local assertions + global invariant closure
```

The production fixture had to use:

- real PoolManager;
- real StandbyHook;
- real ExerciseRouter;
- real EligibilityRegistry;
- real production swap/liquidity perimeters where needed;
- real canonical mock currencies;
- no StandbyHookHarness as authoritative GI evidence;
- no direct economic state mutation.

The handler was explicitly defined as:

> **an adversarial transaction generator, not a semantic pre-filter.**

Invalid requests were expected and useful. Inputs could be bounded only to avoid mechanical nonsense such as impossible TickMath domains, unbounded numerical noise, or an unbounded actor universe.

---

## 7. Ghost-State Boundary

A central design risk was allowing the test suite to accidentally become a second implementation of Standby.

The derived rule was:

> **Ghost state may remember history the production system does not persist for verification purposes, or independently calculate an oracle; it may not prescribe what the production state ought to be by duplicating the protocol state machine.**

Legitimate remembered state included:

- successfully admitted commitment IDs;
- immutable admission fact snapshots;
- previous observed Remaining values;
- independently tracked successful fulfillment per commitment;
- independently observed Beneficiary deliveries;
- direct unrelated donations;
- campaign counters.

The suite should not maintain parallel authoritative classifications such as:

- ghost validity;
- ghost exercisability;
- ghost binding status;
- ghost expiry state;
- ghost obligation;
- ghost expected Remaining;
- ghost O2 lifecycle.

That distinction became one of the most important independent-review criteria.

---

## 8. Independent Oracle Requirement

The frozen testing strategy requires independent normative derivation rather than expected values that reuse implementation logic.

Two primary GI oracles were derived.

### Supporting Capacity

The reference S calculation had to derive from authoritative PoolManager state using independent arithmetic.

It could not simply call the same production helper that StandbyHook uses.

### Aggregate Capacity Obligation

The reference O construction should differ structurally from production.

The especially strong derived strategy was:

- production may derive O by scanning the bounded live reference index;
- GI should independently walk the full allocated commitment identity history and calculate which commitments currently contribute obligation.

That creates a meaningful disagreement surface: if a still-binding commitment ever escaped the bounded reference index, production O and reference O would diverge.

This became one of the strongest elements of the final implementation.

---

## 9. Actor and Action Universe

A persistent bounded actor universe was preferred over arbitrary fuzzed addresses because authority relationships must remain stable across a history.

The proposed roles included:

- registry admin;
- commitment authority;
- Beneficiary A;
- Beneficiary B;
- authorized exerciser;
- unauthorized exerciser;
- eligible trader;
- ineligible trader;
- eligible liquidity provider;
- ineligible liquidity provider;
- outsider.

The action universe needed to include at least:

```text
establishCommitment
ordinaryProtectedSwap
ordinaryOppositeSwap
addLiquidity
removeLiquidity
exercise
advanceTime
setBeneficiaryEligibility
setTraderEligibility
setLiquidityEligibility
directTransferProtectedTokenToBeneficiary
```

The implementation later added an orphan-evidence probe to test O2 causal isolation behaviorally.

---

## 10. Required Stateful Sequence Classes

The session identified dangerous sequence classes that GI had to be capable of reaching.

Examples included:

### Reference churn

```text
many O1
→ partial/full fulfillment
→ expiry
→ bounded-reference reclamation
→ new O1
→ old/new commitment interaction
```

### Causal churn

```text
O2(C1)
→ failed O2(C2)
→ O2(C1)
→ O2(C2)
```

### Authority churn

```text
O1
→ Beneficiary eligibility off
→ destructive O3 attempt
→ eligibility on
→ O2
```

### Backing-boundary churn

```text
multiple O1
→ protected swap toward S == O
→ liquidity removal attempt
→ opposite swap
→ partial O2
→ protected swap again
```

The important point was not that every sequence had to be a deterministic test. Rather, the campaign architecture had to demonstrate that the corresponding semantic histories were actually reachable and verified.

---

## 11. Post-F8D Coverage Observations Carried into GI

The post-F8D coverage report identified several potentially interesting surfaces.

They were evaluated individually rather than automatically converted into GI obligations.

The resulting treatment was:

1. **Untrusted-perimeter liquidity removal** — relevant behavioral GI input.
2. **Nested exercise attribution** — relevant causal-isolation property, but not necessarily a normal handler action if production structurally forbids nested O2.
3. **Causal-position read-surface refusal** — subsumed by broader causal-context verification; not a separate invariant.
4. **Extreme tick-bound clamping** — principally an F5 derivation concern; not a standalone GI obligation unless a reachable compositional counterexample touched it.
5. **Unresolved exercise-delta fail-closed behavior** — relevant only if reachable through adversarial O2; otherwise prior F8 evidence remains sufficient.

This prevented coverage observations from redefining the frozen verification scope.

---

## 12. Exact G-I Derivation

The frozen implementation plan contained 23 detailed gate conditions.

For implementation and review clarity, these were organized into seven families without replacing the exact checklist.

### GI-A — Independent Economic Backing

- reference S == production S;
- reference O == production O;
- reference S >= reference O.

### GI-B — Commitment Conservation & Historical Integrity

- immutable admitted facts;
- Remaining <= Original;
- Remaining monotonic non-increasing;
- Original - Remaining == independently tracked successful fulfillment;
- expiry, eligibility mutation, swaps, liquidity, direct transfers, and failed O2 do not manufacture fulfillment;
- history survives reference reclamation and slot reuse.

### GI-C — Fulfillment Exclusivity & Exactness

- only successful authoritative O2 creates fulfillment;
- exactly one commitment is reduced;
- exactly q is fulfilled;
- exactly q is delivered to the authoritative Beneficiary under canonical mock semantics.

### GI-D — O2 Causal Isolation & Atomicity

- no reusable causal evidence survives a completed top-level action;
- failed or prior O2 evidence cannot authorize a later reduction;
- post-failure histories remain clean.

### GI-E — Reference & Lifecycle Integrity

- at most 16 references;
- references are unique and non-dangling;
- historical identity survives reuse;
- reclamation occurs only for frozen permanent non-binding causes.

### GI-F — Authority, Rejection Atomicity & Custody

- invalid, unauthorized, ineligible, and backing-threatening requests cannot create prohibited authoritative mutations;
- rejected transitions preserve relevant state;
- Hook and ExerciseRouter do not retain protocol-created custody.

### GI-G — Campaign Completeness & Generalization

- canonical zeroForOne campaign;
- generalized oneForZero/different ordering campaign;
- heterogeneous decimals where supported;
- diagnostics must prove meaningful O1/O2/O3/lifecycle activity.

The exact 23 criteria remained the final PASS/FAIL checklist.

---

## 13. Clean-Rule Correction to the Claude Prompt

The user caught an important process issue before implementation.

Earlier draft language risked reintroducing permanent role/process guidance into the session prompt.

The user reaffirmed the clean rule:

> **CLAUDE.md owns permanent operating behavior.**  
> **.claude/rules/* owns permanent Solidity/testing conventions.**  
> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

The implementation prompt was regenerated to follow the mature Session 13-style structure:

- direct slice objective;
- repository instruction ownership;
- authoritative files to inspect;
- GI-specific semantic boundary;
- stateful architecture;
- action/actor universe;
- ghost/oracle constraints;
- G-I criteria;
- evidence requirements;
- file boundary;
- completion boundary.

The standing “Working Model” / ChatGPT-vs-Claude role section was intentionally removed from the Claude implementation prompt.

This was a useful methodology refinement: even a good recurring section should not remain in a slice prompt if permanent repository instructions already own it.

---

## 14. Claude Implementation — Independent Review

Claude implemented four GI test-side files:

```text
test/invariant/StandbyInvariantHandler.sol
test/invariant/BaseStandbyInvariantTest.t.sol
test/invariant/StandbySequenceEvidence.t.sol
test/invariant/StandbyInvariant.t.sol
```

and updated the Session 15 log.

No production code was changed.

ChatGPT independently reviewed the actual diff rather than relying on Claude’s completion report alone.

---

## 15. Independent Review Findings

### Production-path fidelity

PASS.

The suite uses:

- real PoolManager;
- production StandbyHook;
- production ExerciseRouter;
- real EligibilityRegistry;
- real production perimeters;
- canonical deployment/configuration;
- no direct mutation of economic state.

### Handler adversariality

PASS.

The handler intentionally generates both successful and rejected actions.

Action tuning based on independent backing headroom was reviewed carefully and accepted as campaign-shaping rather than a safety pre-filter because production still determines admissibility and substantial refusal activity remained.

### Independent Supporting Capacity oracle

PASS.

Reference S uses independent Q64.96 arithmetic over authoritative PoolManager state and does not call the production StandbyMath derivation.

### Independent Obligation oracle

PASS, and notably strong.

Reference O walks the full allocated commitment history while production derives from the bounded enforcement index. This creates a real disagreement surface if a binding obligation ever escapes the production index.

### Ghost-state discipline

PASS.

No parallel validity/exercisability/binding/expiry/obligation state machine was found.

### Fulfillment conservation

PASS.

After successful O2:

- ghost fulfillment increases only after production success;
- exactly one commitment is reduced;
- reduction equals q;
- all other commitments remain unchanged;
- Beneficiary receives exactly q.

Global closure checks:

```text
Original - Remaining == ghostFulfilled
```

### Failure atomicity

PASS.

Rejected O2 paths assert no Remaining movement, no delivery, no O release, unchanged relevant pool state, zero protocol custody, and empty causal context.

Directed sequences also test failure followed by valid later operations.

### Causal isolation

PASS.

All causal-context fields are required to be empty after completed actions.

An additional orphan-evidence action attempts authorization/finalization without valid causal context.

Nested O2 itself is not artificially manufactured because production structurally forbids it; the reachable causal-isolation shape is tested instead.

### Reference integrity

PASS.

The suite verifies:

- <=16 live refs;
- uniqueness;
- non-dangling identity;
- binding commitments remain referenced;
- historical facts survive reclamation;
- IDs are not recycled.

A deterministic sequence explicitly reaches slot exhaustion, expiry, reclamation, reuse, and historical verification.

### Eligibility and expiry

PASS.

Eligibility mutation does not release O or alter Remaining.

Expiry can release O without zeroing Remaining, preserving the distinction between non-enforceability and fulfillment.

### Direct-transfer discrimination

PASS.

The suite separately tracks:

```text
Standby-delivered protected output
unrelated donated protected output
```

This establishes that Beneficiary receipt by itself is not fulfillment.

### Custody

PASS.

Hook and ExerciseRouter are checked for zero protocol-created custody in both currencies after actions and globally.

### Generalization

PASS.

The generalized campaign materially differs from canonical:

- oneForZero protected direction;
- protected output is currency0;
- 18/8 decimal currencies;
- different service ticks;
- different LP range;
- different fee;
- different liquidity.

### Campaign quality

PASS.

The deterministic campaigns reached:

- admitted and refused O1;
- completed and refused O2;
- partial and full exercise;
- protected and opposite swaps;
- backing-refused swaps and liquidity;
- successful liquidity additions/removals;
- eligibility churn;
- expiry;
- direct transfers;
- orphan causal probes;
- 16 simultaneous refs;
- reference reuse.

This was sufficient to reject the possibility of a semantically empty all-revert campaign.

---

## 16. Independent G-I Determination

ChatGPT independently assessed all 23 conditions as satisfied.

Final determination:

> **GI — Full Stateful Invariant Verification: COMPLETE**  
> **G-I: PASS / CLOSED**  
> **No production correction required.**  
> **F9 — Canonical Acceptance is the next authorized implementation slice.**

This was an independent closure decision, not acceptance of Claude’s advisory assessment by default.

---

## 17. Minor Non-Blocking Report Correction

One wording issue was identified in Claude’s Session 15 log:

> “Twelve generated actions, all of which can succeed and all of which can be refused.”

This is not literally true for every action category.

For example:

- time advancement is not a production request with success/refusal semantics;
- orphan-evidence probing is intentionally expected to fail.

The issue was classified as a non-blocking report wording problem, not a code or gate defect.

A more precise description would be:

> “Twelve generated action selectors spanning successful, rejected, lifecycle, environmental, and adversarial transitions.”

No code change was required.

---

## 18. User Decision: Re-run Coverage After GI

After G-I closure, the user proposed re-running coverage.

ChatGPT agreed, but explicitly classified it as:

> **post-GI diagnostic evidence, not part of G-I closure.**

The reasoning was:

- GI added substantial new test infrastructure;
- production code did not change;
- coverage could reveal newly exercised production surfaces;
- coverage must not be used as semantic proof;
- no tests should be added merely to improve percentages;
- any newly observed uncovered branch should be classified against frozen obligations rather than automatically chased.

The user also correctly challenged an initial prompt phrase:

> “Use the same coverage methodology…”

because Claude was operating in a fresh session and should not depend on conversational memory.

The prompt was strengthened to require Claude to reconstruct the exact established coverage methodology from repository artifacts and stop if it could not do so unambiguously.

This reinforced the project’s reconstructibility principle.

---

## 19. Post-GI Coverage Execution

Claude reconstructed the prior methodology as:

```text
forge coverage
forge coverage --report debug
```

with:

- default profile;
- no filtering;
- no `--match`;
- no `--ir-minimum`;
- no `foundry.toml` change;
- production aggregates recomputed from per-file rows;
- separate Standby core and all-src aggregates;
- lines/statements/branches/functions reported separately.

The post-GI core result was:

```text
Lines       99.42%  ->  99.42%   (514/517)
Statements  98.33%  ->  98.52%   (531/540 -> 532/540)
Branches    91.35%  ->  92.31%   (95/104  -> 96/104)
Functions   100%    ->  100%     (107/107)
```

Exactly one production surface became newly covered:

> the `beforeRemoveLiquidity` refusal for liquidity removal proposed through an untrusted perimeter.

This was significant because it was the first post-F8D candidate specifically identified as a meaningful GI input.

No new frozen verification obligation was discovered.

---

## 20. Coverage Compile Obstacle and Review

The coverage run initially failed with `Stack too deep` in the invariant handler because `forge coverage` disables optimization.

Claude had two options:

1. use `--ir-minimum`, changing the reconstructed coverage methodology;
2. reduce the local stack frame in the test handler.

Claude chose the second option by extracting generated swap amount and price-limit selection into helpers.

ChatGPT independently reviewed this decision and accepted it because:

- it was required to preserve the established coverage methodology;
- it was a test-side compile-time frame-size refactor;
- it did not change production;
- it did not add tests for coverage;
- deterministic campaign counters remained byte-for-byte identical;
- default and CI verification still passed.

Therefore the change did not reopen G-I and was not considered scope leakage.

---

## 21. Final Coverage Assessment

The coverage outcome was considered excellent, but deliberately not treated as proof of correctness.

The key interpretation was:

- line coverage remained extremely high;
- statement and branch coverage improved;
- functions remained at 100%;
- the one newly covered branch was semantically meaningful;
- remaining gaps had already been classified;
- no reason existed to chase 100% branch coverage artificially.

The stronger safety story is the combination of:

- unit testing;
- integration testing;
- fuzz testing;
- independent derivation checks;
- stateful invariant verification;
- generalized direction/token-decimal testing;
- explicit coverage diagnostics.

---

## 22. Gas / Coverage Baseline Decision

The user asked whether gas and coverage should be rerun later now that production code was complete.

The derived policy was:

### Gas

Keep the existing post-F8D production gas snapshot as the current baseline.

Do not rerun merely because GI added tests.

Rerun if:

- production code changes;
- or at final F10 / submission readiness for a final engineering baseline.

### Coverage

The post-GI refresh becomes the primary current coverage baseline.

F9 does not automatically require another refresh if it adds acceptance tests only.

At F10, rerunning both gas and coverage is useful as a final submission-state evidence package.

### General rule

> **Any production-code change after GI should trigger renewed engineering baselines after the affected prior gate has been re-established.**

---

## 23. User Assessment: Did the Project Do Well on Coverage and Gas?

The user asked whether the project’s results should be considered strong or whether more improvement was warranted.

The conclusion was:

### Coverage

Excellent.

Not merely because of the percentages, but because remaining gaps were inspected and classified, and GI supplied semantic/global closure that raw coverage cannot provide.

### Gas / size

Healthy.

No deployment-size pressure or concrete hot-path cost problem was identified.

Further optimization may be theoretically possible, but no evidence showed that speculative optimization would have higher value than completing F9/F10.

### Priority decision

The highest-value next work is not chasing 100% branch coverage or arbitrary gas reduction.

It is:

> **F9 — Canonical Acceptance**

because F9 demonstrates that a fresh system deterministically realizes the full canonical economic story through production interfaces.

---

## 24. Status Transition

After independent GI closure and the post-GI coverage refresh, the user authorized the normal status-only update.

The intended status was:

- **GI — Full Stateful Invariant Verification: COMPLETE**
- **G-I: PASS**
- **F9 — Canonical Acceptance: next authorized implementation slice / current blocker**

The project-status update was intentionally restricted to status fields only.

Coverage figures, invariant architecture, implementation details, review commentary, and retrospective observations were explicitly excluded from `docs/project-status.md`.

---

## 25. Methodology Observations from Session 15

### Observation 1 — Stateful verification should begin only after responsibility convergence

GI worked cleanly because production semantics had already been assigned and closed through F8D.

This prevented invariant failures from becoming ambiguous “GI design work.”

The sequence was:

```text
semantic ownership
→ implementation ownership
→ local gate closure
→ compositional invariant verification
```

This supports the Implementation Convergence Principle.

### Observation 2 — Independent oracle construction matters more than invariant syntax

The strongest parts of GI were not the presence of `invariant_*` functions themselves.

They were the intentional disagreement surfaces:

- independent S arithmetic;
- full-history O reconstruction versus bounded-index production derivation;
- ghost fulfillment versus production Remaining;
- Beneficiary balance history versus protocol delivery accounting.

A stateful invariant suite can still be weak if its expected state is derived from the same logic as production.

### Observation 3 — Campaign diagnostics are part of evidence quality

A green stateful campaign is insufficient if:

- no O1 succeeds;
- O never becomes positive;
- no O2 completes;
- no backing-threatening O3 attempt occurs;
- no reference churn occurs.

Session 15 treated reachability diagnostics as evidence-quality checks rather than protocol semantics.

That distinction was productive.

### Observation 4 — Coverage observations should be mapped to normative owners

The post-F8D uncovered paths were not automatically converted into new tests.

Each was evaluated against:

- frozen invariant responsibility;
- production reachability;
- prior slice ownership;
- GI’s compositional boundary.

This prevented coverage from silently becoming a new specification.

### Observation 5 — Fresh implementation sessions must be repository-reconstructible

The user’s challenge about “use the same coverage methodology” exposed a broader process rule:

> A new implementation session should not need hidden conversational continuity to reproduce prior engineering procedure.

Where a prior method matters, the prompt should require reconstruction from checked-in evidence.

This strengthens auditability and handoff quality.

### Observation 6 — Verification tooling may require non-semantic refactoring

The coverage-only stack-depth issue showed that instrumentation can expose build constraints not present in the optimized verification profile.

The correct response was not to change semantics or silently alter methodology.

Instead:

- preserve methodology;
- make the smallest behavior-preserving test-side refactor;
- rerun gate-relevant verification;
- disclose the change.

This is a useful precedent for future engineering evidence work.

### Observation 7 — “Complete production code” does not mean “never measure again”

Post-F8D gas and post-GI coverage are milestone baselines.

A later production change should trigger renewed measurements.

F10 should produce the final submission-state baseline even if the implementation remains unchanged.

---

## 26. Final Session 15 Determination

Session 15 achieved its intended responsibility.

### GI

**COMPLETE**

### G-I

**PASS / CLOSED**

### Production defects found

**None**

### Production changes required

**None**

### Post-GI coverage

```text
Lines       99.42%
Statements  98.52%
Branches    92.31%
Functions   100%
```

### New verification obligation discovered by coverage

**None**

### Current blocker

**F9 — Canonical Acceptance**

---

## 27. Handoff State

The repository is now in a strong verification state:

```text
F0–F8D   COMPLETE
GI       COMPLETE
G-I      PASS / CLOSED
F9       NEXT AUTHORIZED SLICE
F10      NOT YET AUTHORIZED
```

The next session should reconstruct and derive the exact F9 responsibility from the frozen acceptance requirements and implementation plan before authorizing implementation.

F9 should remain distinct from GI:

- GI proved adversarial temporal/compositional safety;
- F9 must prove deterministic realization of the canonical accepted economic story through production interfaces.

That distinction should remain explicit in the next-session handoff.
