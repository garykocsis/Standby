# Standby — Session 15 Log

Implementation-process record for:

> **GI — Full Stateful Invariant Verification**

Initiating prompt: `docs/prompts/session-15-gi-full-stateful-invariant-verification.md`.

This log is a non-normative audit artifact. It records material follow-up instructions, design decisions,
counterexamples, verification commands, and results. It defines no protocol semantics.

---

## Material Prompts

### Prompt 1 — Session authorization

**Instruction:**

> Read root CLAUDE.md, then execute docs/prompts/session-15-gi-full-stateful-invariant-verification.md as
> the authorized Session 15 task. Stop at the completion boundary defined by that prompt.

**Consequence:** GI implementation proceeded under the Session 15 prompt scope: a production-only
handler-driven stateful invariant architecture, canonical and generalized campaigns, independent oracles,
the required stateful sequence classes, campaign diagnostics, and an advisory G-I assessment.

### Prompt 2 — Post-GI coverage refresh

**Instruction:**

> Execute `docs/prompts/session-15-post-coverage-report.md`. Stop at the completion boundary defined by that
> prompt.

That prompt authorizes a **diagnostic-only** post-GI refresh of the repository's established coverage
workflow, now that GI has passed independent review: reconstruct the exact post-F8D methodology from
repository evidence rather than assuming it, preserve it, update `docs/reports/coverage-summary.md` with the
post-F8D baseline, the post-GI result, the delta, newly covered production surfaces attributable to GI, and
the classification of what remains; record the commands, methodology, and result here; add no tests to
improve coverage; and modify no production code, invariant test, frozen artifact, or
`docs/project-status.md` in response to coverage percentages alone.

**Consequence:** the coverage baseline was refreshed and reported. One test-side compile obstacle had to be
resolved to run the established workflow at all — recorded in full below. No production code, frozen
artifact, or `docs/project-status.md` was touched, and no test was added, removed, weakened, or suppressed.

### Prompt 3 — Status-only project-status synchronization

**Instruction:**

> Update **status only** in `docs/project-status.md` to reflect the independently reviewed GI result: GI —
> Full Stateful Invariant Verification: COMPLETE; G-I: PASS; F9 — Canonical Acceptance: next authorized
> implementation slice / current blocker. Do not add implementation details, invariant architecture,
> campaign results, coverage results, design commentary, test summaries, gate reasoning, retrospective
> observations, or any other new descriptive content. Only make the minimum edits necessary to bring
> existing status fields, roadmap/ladder entries, current-blocker/next-action fields, and any now-stale
> status statements into consistency with that status. Also record this instruction in
> `docs/prompts/session-15-log.md` as the next material follow-up prompt and record the resulting
> status-only action, as audit chronology only. Do not modify any other files.

**Consequence:** `docs/project-status.md` was synchronized with the externally reviewed and closed G-I, as a
status-only edit. Recorded below.

**Material prompts recorded: 3.**

---

## Design Record

### Invariant architecture

```text
production fixture (BaseStandbyInvariantTest)
        ↓
adversarial handler (StandbyInvariantHandler)
        ↓
production interfaces (StandbyHook / ExerciseRouter / EligibilityRegistry / perimeters / PoolManager)
        ↓
authoritative production state
        ↓
independent reference + remembered-history observations
        ↓
transition-local assertions (handler) + global invariant closure (campaign)
```

Files:

- `test/invariant/StandbyInvariantHandler.sol` — the adversarial transaction generator, the ghost history,
  the diagnostic counters, and every transition-local assertion.
- `test/invariant/BaseStandbyInvariantTest.t.sol` — the production-only parameterized environment, the two
  independent oracles, and the nine global `invariant_` functions.
- `test/invariant/StandbySequenceEvidence.t.sol` — the required stateful sequence classes and the
  deterministic diagnostic campaign, both driven through the same handler.
- `test/invariant/StandbyInvariant.t.sol` — the canonical and generalized campaign configurations.

### Production-only decision

No `StandbyHookHarness` and no privileged economic seeding anywhere. The Hook is deployed through the
canonical `DeployStandbyHook` procedure, the service is activated by `configureAndActivate`, the service is
activated with the production `ExerciseRouter` (not the F8A/F8B/F8C stand-ins), and the bootstrap liquidity
is added through the production `beforeAddLiquidity` path by an eligible provider routed through the trusted
liquidity perimeter.

`DerivationTestCurrency` is imported from `test/shared/BaseDerivationTest.t.sol` for the generalized
campaign's asymmetric-decimal currencies. That file also declares the F5 derivation harness, which is
therefore a compile-time dependency of the generalized campaign — it is never deployed, never configured,
and contributes no GI evidence.

### `fail_on_revert = true`

Every production call the handler makes is wrapped, and refusals are recorded and asserted rather than
discarded. That makes an unwrapped revert — including a failed assertion inside a generated action — a
campaign failure rather than a silently dropped sequence. Verified empirically by injecting a deliberately
false conservation assertion into the handler and confirming the campaign failed with that message; the
injection was then reverted.

### Ghost / reference state

Remembered history only: admitted commitment identities, the immutable facts each admission recorded, the
last Remaining Entitlement observed, independently tracked successful fulfillment per commitment, protected
output delivered by completed O2 per Beneficiary, protected output donated by unrelated transfers per
Beneficiary (accounted separately), position custody per actor and range, and diagnostic counters. No
parallel validity, exercisability, binding, expiry, obligation, or lifecycle classification is maintained.

### Oracle independence

- **Supporting Capacity** — `ReferenceCalculations.referenceSupportingCapacity` over the authoritative
  Slot0 square-root price and active liquidity, with its own Q64.96 arithmetic. It calls no `StandbyMath`
  and no production derivation.
- **Aggregate Capacity Obligation** — `ReferenceCalculations.referenceCommitmentObligation` summed over the
  whole allocated history `[1, nextCommitmentId)` read through the fact-only commitment surface. Production
  sums the bounded index instead, so the two constructions differ: an obligation that escaped the index
  would be a disagreement rather than a shared blind spot.
- **Fulfillment** — `ghostFulfilled[id]`, increased only after an independently observed successfully
  completed O2, compared against `Original - Remaining`.
- **Beneficiary delivery** — Beneficiaries are funded with nothing and never trade, provide liquidity, or
  exercise, so their protected-output balance is a complete independent history: it must equal
  `ghostDelivered + ghostDonated` at all times.
- **Commitment history** — immutable facts snapshotted at admission and re-compared after every action,
  which is what makes survival across bounded-reference reclamation and slot reuse checkable.

### Action-selection tuning

Three generation adjustments were made after observing that the first campaigns reached very little
completed fulfillment. None of them is a safety pre-filter; each shapes the magnitude or target of a
generated request, and production alone decides admissibility:

1. generated amounts are drawn against the independently derived present backing headroom plus a margin,
   rather than against twice the starting capacity, so both admissible and inadmissible proposals are
   ordinary outcomes;
2. eligibility mutations grant three times as often as they revoke, because a history whose eligible
   identities spent half their life ineligible refused almost everything;
3. generated exercises prefer recent commitments, with every identity still reachable.

Time advancement was also softened from a 20% chance of a 31-day jump to 12.5%, so that expiry stays
reachable without ending every commitment's validity before it can be exercised.

### Counterexamples encountered

No production counterexample was found. The only failures encountered during implementation were the
campaign-quality floors of the deterministic diagnostic campaign (`full fulfillment` and then
`partial fulfillment` reaching zero), which were generator-shaping problems and were resolved by the tuning
above. No production code was changed.

### Campaign configuration

| Campaign                            | runs | depth | fail_on_revert | target                     |
| ----------------------------------- | ---- | ----- | -------------- | -------------------------- |
| default profile, both configurations | 256  | 96    | true           | 12 handler action selectors |
| ci profile, both configurations      | 512  | 192   | true           | 12 handler action selectors |

Set as inline `forge-config` on the campaign contracts rather than by changing `foundry.toml`, because each
invariant function re-runs the whole campaign and the repository-wide `ci` invariant configuration
(runs 1000 / depth 500) would make the GI suites the dominant cost of every CI run.

### Verification results

Recorded in the completion report below.

---

## Required Task Completion Report

### 1. Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`;
- `docs/project-status.md`; `docs/implementation-plan.md` §18 (GI) and §19 (F9 boundary);
- `docs/invariants.md` and `docs/testing-strategy.md` structure;
- `src/StandbyHook.sol` (complete), `src/ExerciseRouter.sol`, `src/EligibilityRegistry.sol`,
  `src/demo/ActorAwareTestRouter.sol`, `src/libraries/StandbyMath.sol`, `src/libraries/CommitmentRefs.sol`,
  `src/mocks/MockFixtureCurrency.sol`, `src/mocks/MockUSTB.sol`;
- `script/DeployStandbyHook.s.sol`, `script/helpers/StandbyFixtureConfig.sol`,
  `script/helpers/DeterministicFixtureDeployer.sol`;
- `test/shared/BaseStandbyServiceTest.t.sol`, `test/shared/BaseActorAwareStandbyTest.t.sol`,
  `test/shared/BaseCommitmentAdmissionTest.t.sol`, `test/shared/BaseAuthenticBackingTest.t.sol`,
  `test/shared/BaseExerciseAuthorizationTest.t.sol`, `test/shared/BaseExerciseSettlementTest.t.sol`,
  `test/shared/BaseExerciseFinalizationTest.t.sol`, `test/shared/BaseDerivationTest.t.sol`,
  `test/shared/ReferenceCalculations.sol`, `test/shared/BaseV4Test.t.sol`,
  `test/integration/DerivationGeneralization.t.sol`;
- `foundry.toml`, `remappings.txt`.

### 2. Files Changed

Created:

| File | Why |
| --- | --- |
| `test/invariant/StandbyInvariantHandler.sol` | The adversarial stateful transaction generator, the ghost history, the diagnostic counters, and every transition-local assertion. |
| `test/invariant/BaseStandbyInvariantTest.t.sol` | The production-only parameterized campaign environment, the two independent oracles, and the nine global `invariant_` functions. |
| `test/invariant/StandbySequenceEvidence.t.sol` | The required stateful sequence classes and the deterministic diagnostic campaign, driven through the same handler. |
| `test/invariant/StandbyInvariant.t.sol` | The canonical and generalized campaign configurations, with their inline campaign configuration. |
| `docs/prompts/session-15-log.md` | The Session 15 implementation-process record. |

No production source, script, frozen document, existing test, or `docs/project-status.md` was modified.

### 3. Invariant Architecture

```text
production fixture (BaseStandbyInvariantTest)
        ↓
adversarial handler (StandbyInvariantHandler)
        ↓
production interfaces (StandbyHook / ExerciseRouter / EligibilityRegistry / perimeters / PoolManager)
        ↓
authoritative production state
        ↓
independent reference + remembered-history observations
        ↓
transition-local assertions (handler) + global invariant closure (campaign)
```

Campaigns run with `fail_on_revert = true`. The handler wraps every production call and records refusals
itself, so an unwrapped revert — including a failed assertion inside a generated action — fails the
campaign instead of being discarded as an uninteresting sequence. This was verified empirically by
injecting a deliberately false conservation assertion into the handler and confirming the campaign failed
with that message; the injection was then reverted.

### 4. Production Components Exercised

Real pinned `PoolManager`; production `StandbyHook` deployed through the canonical `DeployStandbyHook`
mining and deployment procedure; production `configureAndActivate`; production `establishCommitment`;
production `ExerciseRouter` (the complete one, not the F8A/F8B/F8C stand-ins) driving
`authorizeExercise` → protected PoolManager execution → settlement and direct Beneficiary delivery →
`finalizeExercise`; production `beforeSwap` / `afterSwap` / `beforeAddLiquidity` / `beforeRemoveLiquidity`
enforcement; real `EligibilityRegistry` under its own administrator; two separately deployed
`ActorAwareTestRouter` perimeters holding distinct trust roles; canonical `MockUSTB` / `MockUSDC` deployed
through `DeterministicFixtureDeployer`.

No `StandbyHookHarness`, no privileged economic seeding, and no direct write of Remaining Entitlement,
admitted extent, bounded reference, capacity, obligation, validity, exercisability, fulfillment, or causal
context anywhere.

### 5. Handler Actions Implemented

Twelve generated actions, all of which can succeed and all of which can be refused:

`establishCommitment`, `exercise`, `ordinaryProtectedSwap`, `ordinaryOppositeSwap`, `addLiquidity`,
`removeLiquidity`, `advanceTime`, `setBeneficiaryEligibility`, `setTraderEligibility`,
`setLiquidityEligibility`, `directTransferProtectedTokenToBeneficiary`, `attemptOrphanExerciseEvidence`.

The twelfth is the traceable addition beyond the prompt's minimum set: it probes GI-D / G-I-21 behaviorally
by attempting `authorizeExercise` outside the configured ExerciseRouter and `finalizeExercise` with no
causally proven exercise behind it, including immediately after successful and failed exercises.

Adversarial shaping inside the existing actions rather than as new actions: routing swaps through the
liquidity perimeter and liquidity actions through the swap perimeter; price limits beyond the service
domain; liquidity ranges with endpoints strictly inside the domain; removal sizes beyond the actor's own
position; `q = 0`, `q = Remaining`, and `q > Remaining`; cost bounds no real debt can satisfy; unauthorized
callers; a permanently ineligible Beneficiary; already-ended and impossible commitment windows.

### 6. Persistent Actor Model

Thirteen persistent identities, one role each: `registryAdmin`, `establishmentAuthority`, `beneficiaryA`,
`beneficiaryB`, `ineligibleBeneficiary`, `authorizedExerciser`, `unauthorizedExerciser`, `eligibleTrader`,
`ineligibleTrader`, `eligibleProvider`, `ineligibleProvider`, `donor`, `outsider` (plus the separate
`configurationAuthority`). Callers are never fuzzed addresses, so authority relationships stay stable
across a whole history.

Funding is asymmetric on purpose: Beneficiaries are funded with nothing, exercisers hold input currency
only, the donor holds protected output and no Standby role. The three permanently ineligible identities are
never granted eligibility by any action.

### 7. Ghost / Reference State Used

Admitted commitment identities; the immutable facts each admission recorded; the last Remaining Entitlement
observed; independently tracked successful fulfillment per commitment; protected output delivered by
completed O2 per Beneficiary; protected output donated by unrelated transfers per Beneficiary, accounted
separately; position custody per actor and range; diagnostic counters.

No parallel validity, exercisability, binding, expiry, obligation, or lifecycle classification is
maintained anywhere.

### 8. Independent Oracle Strategy

| Quantity | Independent basis |
| --- | --- |
| Supporting Capacity | `ReferenceCalculations` Q64.96 arithmetic over the authoritative Slot0 square-root price and active liquidity. Calls no `StandbyMath` and no production derivation. |
| Aggregate Capacity Obligation | `ReferenceCalculations.referenceCommitmentObligation` summed over the **whole allocated history** `[1, nextCommitmentId)` read through the fact-only commitment surface — production sums the bounded index instead, so the two constructions differ and an obligation that escaped the index shows up as disagreement. |
| Fulfillment | `ghostFulfilled[id]`, increased only after an independently observed completed O2, compared against `Original − Remaining`. |
| Beneficiary delivery | Beneficiary balances, which are a complete independent history because Beneficiaries start with nothing and never trade, provide liquidity, or exercise: balance must equal `delivered + donated`. |
| Commitment history | Immutable facts snapshotted at admission, re-compared after every action, including after reference reclamation and slot reuse. |
| Reference integrity | Structural properties of the index checked directly, plus the contrapositive of reclamation: a commitment still carrying obligation must still be referenced. |

### 9. Invariant Functions Added (per configuration)

`invariant_supportingCapacityEqualsIndependentReference`,
`invariant_capacityObligationEqualsIndependentReference`,
`invariant_supportingCapacityCoversCapacityObligation`,
`invariant_commitmentConservation`,
`invariant_beneficiaryHoldingsMatchIndependentDeliveryHistory`,
`invariant_boundedReferenceIntegrity`,
`invariant_bindingCommitmentsRetainALiveReference`,
`invariant_protocolHoldsNoCurrencyCustody`,
`invariant_noReusableCausalEvidenceSurvives`.

### 10. Transition-Local Stateful Assertions Added

Around every generated or scripted action: admitted facts unchanged for every historical commitment;
`Remaining ≤ Original`; Remaining never increases; `Original − Remaining == ghostFulfilled`; Beneficiary
holdings equal delivery plus donation; zero Hook and Router custody in both currencies; empty O2 causal
context.

Around a successful O2 additionally: exactly one commitment reduced, by exactly `q`, every other commitment
untouched, and exactly `q` protected output delivered to the authoritative Beneficiary.

Around a refused O2: no Remaining moved anywhere, nothing delivered, no obligation released, and the
authoritative pool state unchanged.

Around a refused O1: no commitment identity consumed and the bounded reference index untouched, slot for
slot.

Around every eligibility mutation: the Aggregate Capacity Obligation is unchanged.

### 11. Canonical Campaign Configuration

`MockUSTB` = currency0, `MockUSDC` = currency1, both six-decimal, deployed through the deterministic
ordered deployment path; protected direction `zeroForOne`; `tickQ = −240`, `tickO = +240`; LP range
`[−300, +300]`; tick spacing 10; fee 500; canonical liquidity 6,707,079,990,254; initial Supporting
Capacity 80,000.000000 MockUSDC.

### 12. Generalized Campaign Configuration

Protected direction `oneForZero`, so the protected output is currency0; eighteen- and eight-decimal
currencies, so neither `1e6` nor equal precision is a usable universal scale; `tickQ = +1200`,
`tickO = −600`; LP range `[−1200, +1800]`; tick spacing 60; fee 3000; liquidity 1e15. Supporting Capacity
and Capacity Obligation remain raw amounts of the protected output currency and the identical invariant
closure is asserted.

### 13. Campaign Diagnostics

Deterministic diagnostic campaign, 600 generated actions per configuration, fixed seed:

| Diagnostic | Canonical | Generalized |
| --- | --- | --- |
| O1 admitted / refused | 18 / 26 | 16 / 28 |
| O2 completed / refused | 15 / 36 | 15 / 36 |
| O2 partial / full | 6 / 9 | 7 / 8 |
| protected swaps attempted / executed | 46 / 16 | 46 / 15 |
| opposite swaps attempted / executed | 60 / 40 | 60 / 35 |
| backing-refused swaps / liquidity actions | 1 / 6 | 5 / 4 |
| liquidity added / removed | 39 / 9 | 39 / 11 |
| eligibility mutations B / T / L | 49 / 25 / 52 | 49 / 25 / 52 |
| eligibility mutations refused | 18 | 18 |
| time advances / expiry events | 59 / 2 | 59 / 1 |
| direct Beneficiary transfers / orphan-evidence probes | 40 / 49 | 40 / 49 |
| reference reuse events | 2 | 0 |
| max simultaneous live references | 16 | 16 |
| max observed Aggregate Capacity Obligation | 606,322,699,893 | 652,582,229,995,934 |

The generated Foundry campaigns additionally reported per-selector call metrics: all twelve action
selectors were exercised roughly uniformly (≈650–735 calls each per invariant at the default profile), with
0 reverts and 0 discards.

### 14. GI-Specific Campaign Commands Executed

```bash
forge test --match-contract StandbyCanonicalInvariantTest   --match-test "invariant_"
forge test --match-contract StandbyGeneralizedInvariantTest --match-test "invariant_"
forge test --match-path test/invariant/StandbyInvariant.t.sol -vv
FOUNDRY_PROFILE=ci forge test --match-contract StandbyCanonicalInvariantTest --match-test "invariant_supportingCapacityEqualsIndependentReference"
```

Campaign configuration, set as inline `forge-config` on both campaign contracts:

| Profile | runs | depth | calls per invariant | fail_on_revert | target |
| --- | --- | --- | --- | --- | --- |
| default | 256 | 96 | 24,576 | true | 12 handler selectors on the handler contract |
| ci | 512 | 192 | 98,304 | true | 12 handler selectors on the handler contract |

`foundry.toml` was deliberately not changed: each invariant function re-runs the whole campaign, so the
repository-wide `ci` invariant setting (runs 1000 / depth 500) would have made the two GI suites the
dominant cost of every CI run.

### 15. Repository Verification Results

```bash
forge fmt --check          # clean
forge build --sizes        # successful
forge test                 # 579 passed, 0 failed, 0 skipped (60 suites, 43.8s)
FOUNDRY_PROFILE=ci forge test  # 579 passed, 0 failed, 0 skipped (60 suites, 175.8s)
```

Canonical campaign: 9 invariants × 24,576 calls, 0 reverts, all passing. Generalized campaign: identical
configuration, all passing. All 20 scripted stateful sequence tests (10 per configuration) pass.

### 16. Material Counterexamples Encountered

None against production. The only failures encountered were campaign-quality floors in the deterministic
diagnostic campaign — first `full fulfillment` and then `partial fulfillment` reaching zero — which were
generator-shaping problems, not protocol behavior. They were resolved by drawing generated amounts against
the independently derived present backing headroom, biasing eligibility mutations toward granting, biasing
generated exercises toward recent commitments, and softening the frequency of the 31-day time jump. None of
these is a safety pre-filter: production alone decides whether any generated request is admissible, and
refusal rates remain high (26–28 refused O1 and 36 refused O2 per 600 actions).

### 17. Production Defects Discovered

None.

### 18. Production Code Changed

None. GI was verification-only, as presumed by the session prompt.

### 19. Advisory G-I Assessment

| Condition | Assessment | Evidence |
| --- | --- | --- |
| G-I-1 Supporting Capacity equivalence | **PASS** | `invariant_supportingCapacityEqualsIndependentReference` over 24,576 generated calls per configuration plus every scripted sequence's closure; oracle is independent Q64.96 arithmetic over authoritative pool state. |
| G-I-2 Capacity Obligation equivalence | **PASS** | `invariant_capacityObligationEqualsIndependentReference`; the oracle sums the whole allocated commitment history rather than the bounded index production scans. |
| G-I-3 Backing sufficiency | **PASS** | `invariant_supportingCapacityCoversCapacityObligation` over reference values, with authentic positive obligation reached throughout (max 6.06e11 canonical / 6.53e14 generalized). |
| G-I-4 Remaining bound | **PASS** | Global invariant and per-action observation over every historical commitment. |
| G-I-5 Immutable commitment facts | **PASS** | All six admitted facts re-compared against the admission snapshot after every action, including after slot reclamation. |
| G-I-6 Remaining monotonicity | **PASS** | Per-action comparison against the last observed remainder, then updated. |
| G-I-7 Fulfillment conservation | **PASS** | `Original − Remaining == ghostFulfilled` after every action, with 15 completed exercises per diagnostic campaign and many more in the generated campaigns. |
| G-I-8 Expiry is not fulfillment | **PASS** | Scripted expiry sequence: obligation falls to zero while Remaining stays at the admitted extent and tracked fulfillment stays zero; generated campaigns reach expiry too. |
| G-I-9 Eligibility mutation integrity | **PASS** | Every eligibility mutation asserts unchanged obligation and unchanged remainders; scripted churn sequence shows an ineligible Beneficiary's commitment still refusing a destructive O3 and still unexercisable, then exercisable again once restored. |
| G-I-10 Ordinary swap non-fulfillment | **PASS** | No-fulfillment assertion around every swap, successful or refused, in both directions. |
| G-I-11 Liquidity non-fulfillment | **PASS** | Same assertion around every liquidity addition and removal. |
| G-I-12 Direct transfer non-fulfillment | **PASS** | Same assertion around every direct transfer, plus the global delivery-accounting invariant that separates donation from delivery. |
| G-I-13 Exact O2 attribution | **PASS** | Every successful exercise asserts exactly one commitment reduced by exactly `q` with every other commitment untouched. |
| G-I-14 Exact Beneficiary delivery | **PASS** | Per-exercise delivery equality plus the global `balance == delivered + donated` invariant. |
| G-I-15 Failed O2 integrity | **PASS** | Refused exercises assert zero fulfillment, zero Remaining movement, zero delivery, no obligation release, unchanged pool state, zero protocol custody, and an empty causal context. |
| G-I-16 Protocol custody integrity | **PASS** | Both currencies, Hook and Router, after every action and as a global invariant. No campaign action donates to a protocol address, so any balance would be protocol-created. |
| G-I-17 Reference bound | **PASS** | Live reference count checked; the bound of 16 is reached in both diagnostic campaigns. |
| G-I-18 Reference validity | **PASS** | Every nonzero reference unique and resolving to an allocated identity. |
| G-I-19 History across reuse | **PASS** | Scripted sequence exhausts the index, expires it, reuses a slot, and proves the displaced commitment's facts and remainder intact and its identity unrecycled; the canonical generated campaign also reached reuse. |
| G-I-20 Reclamation cause integrity | **PASS** | `invariant_bindingCommitmentsRetainALiveReference` — every commitment still carrying obligation still occupies a reference, so eligibility loss, backing pressure, swaps, liquidity transitions, direct transfers, and failed exercises cannot reclaim one. |
| G-I-21 O2 context isolation | **PASS** | All seven causal-context fields asserted empty after every completed action; orphan authorization and orphan finalization probes refused; scripted contamination sequence covering failed→valid, valid→valid, and post-success attempts. |
| G-I-22 Generalization | **PASS** | Identical closure passes under the canonical `zeroForOne` six-decimal service and a generalized `oneForZero` service with 18/8-decimal currencies, different domain, spacing, fee, position, and liquidity. |
| G-I-23 Campaign quality | **PASS** | Diagnostics in §13: admitted and refused O1, completed and refused O2, partial and full fulfillment, protected and opposite swaps, backing refusals against authentic positive obligation, liquidity activity, all three eligibility domains, time advance and expiry, direct transfers, orphan probes, 16 simultaneous live references, and reference reuse. |

This is an advisory assessment only. Claude does not close G-I.

### 20. Known Limitations / Reachability Gaps

- The generated generalized campaign did not reach bounded-reference slot reuse within 600 actions
  (canonical reached it twice); both configurations reach it deterministically through the scripted
  expiry/reuse sequence.
- Exact `S == O` boundary acceptance is reached by the scripted backing-boundary sequence rather than by
  chance in the generated campaigns; the counter for spontaneous boundary states is zero.
- Nested O2 is not generated: the handler acts at top level, and production forbids nesting in both the
  router's own attribution context and the Hook's authorization guard. GI probes the reachable shape of the
  same property instead — orphan authorization and orphan finalization, after successful and after failed
  exercises.
- Per §28 of the session prompt, causal-position read-surface refusal and extreme tick-bound clamping were
  not given separate GI obligations; no compositional counterexample touching either was found.
- The generalized campaign's currencies reuse `DerivationTestCurrency` from `test/shared/BaseDerivationTest.t.sol`,
  which also declares the F5 derivation harness. That harness is a compile-time dependency only: it is never
  deployed, never configured, and contributes no GI evidence.

### 21. Scope Check

Work remained inside GI. No production semantics were changed. No frozen document was modified.
`docs/project-status.md` was not touched. F9 was not started, no acceptance test was written, and no
frontend or deployment work was performed. The only files added are test-side plus the Session 15 log.

### 22. Recommended Next Step

Independent review of this GI evidence and an explicit G-I closure decision. If G-I closes, the next
authorized responsibility would be F9 — Canonical Acceptance, which is neither started nor authorized.

### 23. Prompt Audit

All material follow-up instructions were captured in `docs/prompts/session-15-log.md`.
**1 material prompt recorded at the GI completion boundary** (the session authorization itself); no further
material follow-up instruction had been received at that point. Two further material prompts — the post-GI
coverage refresh and the status-only project-status synchronization — were received afterwards and are
recorded above; the session total is now **3**.

---

## Post-GI Diagnostic Follow-Up — Coverage Refresh

Captured under Prompt 2, after GI passed independent review. **Non-normative engineering evidence:** it
defines no protocol semantics and neither establishes, closes, nor reopens G-I.

The detailed evidence lives in the report and is deliberately not duplicated here:

```text
docs/reports/coverage-summary.md
```

### Methodology reconstructed from repository evidence

Sources consulted before running anything: the previous revision of `docs/reports/coverage-summary.md`
(its "Command and Result" section, its limitation notes, and its computed-aggregate convention),
`docs/prompts/session-14-post-f8d-engineering-baseline.md` §5, and the coverage section of
`docs/prompts/session-14-log.md`.

The reconstructed methodology is unambiguous:

1. `forge coverage` — default profile, default summary report, no filtering, exclusion, `--match`, or
   `--ir-minimum`, and no change to `foundry.toml`;
2. `forge coverage --report debug` — read-only, used only to locate individual uncovered items, producing no
   repository artifact;
3. production aggregates computed by summing the per-file rows, because Foundry's `Total` row aggregates
   `src/`, `script/` and `test/` together;
4. two computed aggregates reported: the Standby protocol core (Hook, ExerciseRouter, EligibilityRegistry,
   and the three libraries) and all of `src/`;
5. the four coverage dimensions reported separately and never collapsed into one figure.

That methodology was preserved exactly.

### Measured state

Branch `feat/gi-stateful-invariant-verification`, `HEAD` = `e698c22fb6396585cd7bd57cbe120be53b7724cc`,
Foundry `1.3.5-stable`, `default` profile. **The Session 15 GI work was staged but uncommitted when the
measurement was taken**, so the report does not describe commit `e698c22`; it enumerates the four
`test/invariant/` files and two `docs/prompts/` files it actually measured on top of it. No production
source, script, harness, existing test, frozen artifact, or configuration file differs from that commit.

### Commands

```bash
forge coverage
forge coverage --report debug
```

Both completed successfully — 60 suites, 579 tests passed, 0 failed, under coverage instrumentation
(110.85 s for the summary run). The debug invocation produced no repository artifact.

### Compile obstacle and the one test-side change it required

The first `forge coverage` invocation failed to compile with `Stack too deep` at
`test/invariant/StandbyInvariantHandler.sol:941`, inside the generated ordinary-swap action. `forge coverage`
disables the optimizer, and that frame held enough locals to exceed the unoptimized stack limit; the
optimized build the gates were verified against compiles it without difficulty, so the problem was visible
only under coverage instrumentation.

Two resolutions existed. `--ir-minimum` would have changed the reconstructed procedure this refresh is
required to preserve. Splitting the generator's amount and price-limit selection into
`_generatedSwapAmount` and `_generatedSwapLimitTick` changes no behavior and restores the established
procedure, so that was done. It is a compile-time frame-size change, not a response to a coverage
percentage, and it changes nothing about what the campaigns generate, bound, or assert.

Verified behavior-preserving before the measurement was taken:

| Check | Result |
| --- | --- |
| GI deterministic campaign counters, both configurations | byte-for-byte identical to the pre-change run |
| `forge fmt --check` | clean |
| `forge build --sizes` | successful |
| `forge test` | 579 passed, 0 failed |
| `FOUNDRY_PROFILE=ci forge test` | 579 passed, 0 failed |

### Result

Standby protocol core, post-F8D baseline → post-GI:

```text
Lines       99.42%  ->  99.42%   (514/517, unchanged)
Statements  98.33%  ->  98.52%   (531/540 -> 532/540, +1 statement)
Branches    91.35%  ->  92.31%   (95/104  -> 96/104,  +1 branch)
Functions   100%    ->  100%     (107/107, unchanged)
```

Exactly one production surface moved from uncovered to covered: `src/StandbyHook.sol` L1668, the
`beforeRemoveLiquidity` refusal of a liquidity removal proposed through an untrusted perimeter — which was
**potential GI input #1** in the post-F8D report. Every other production file is identical to the baseline.

Of the other four post-F8D potential GI inputs: nested exercise attribution was considered and is not
reachable by a top-level generator (recorded as a known GI reachability gap); the causal-position read-surface
refusal and the tick-bound clamps were deliberately excluded by §28 of the GI session prompt and no
compositional counterexample touching them appeared; the unresolved-delta guard remains structurally
unreachable on the production path.

No coverage observation exposed a previously unrecognized frozen verification obligation.

### Scope confirmation

No production code, script, harness, fixture, frozen artifact, compiler, optimizer, EVM, or dependency
configuration was changed. `foundry.toml` was not changed. `docs/project-status.md` was not modified. No
test was added, removed, weakened, or suppressed to affect coverage, and no production code was excluded
from measurement. The single test-side change was a compile-time frame-size split required to run the
established coverage workflow at all, and is disclosed in both this log and the coverage report. F9 and F10
were not started.

---

## Post-GI Status Synchronization

Recorded under Prompt 3, after G-I was independently reviewed and closed. **Audit chronology only.** This
entry records that a status-only synchronization occurred; it adds no evidence, no assessment, and no
normative content, and it does not itself close a gate or authorize any implementation slice.

### Authorization

External review closed G-I as PASS. Under the Project Status Synchronization rule in `CLAUDE.md`, that
closure is what permits `docs/project-status.md` to be brought into consistency with it.

### File changed

```text
docs/project-status.md
```

No other file was modified.

### Status-only edits made

| Field | Before | After |
| --- | --- | --- |
| Current Implementation Slice | GI (NEXT AUTHORIZED / NOT STARTED) | F9 — Canonical Acceptance (NEXT AUTHORIZED / NOT STARTED) |
| Last Closed Gate | G8D | G-I — Full Stateful Invariant Gate (CLOSED / PASS) |
| Status line | … F8D COMPLETE — GI NOT STARTED | … F8D COMPLETE — GI COMPLETE — F9 NOT STARTED |
| §2 next authorized slice / last closed gate | GI / G8D | F9 / G-I |
| §2 gate-closed list and review sentence | ends at F8D; GI not started | includes GI; GI reviewed and G-I closed, F9 next |
| §3 ladder — GI row | **NEXT / NOT STARTED** | **COMPLETE — G-I CLOSED** |
| §3 ladder — F9 row | NOT STARTED | **NEXT / NOT STARTED** |
| §10 Current Blocker | GI unstarted; F9 not authorized | F9 unstarted; F10 not authorized |
| §18 Next Action | GI | F9 |
| §19 Handoff — Validated State | ends at F8D / G8D | adds GI complete / G-I closed |
| §19 Handoff — Current Gate | G8D CLOSED / PASS | G-I CLOSED / PASS |
| §19 Handoff — Next Blocker / Next Step | GI not started / begin GI | F9 not started / begin F9 |

### Scope confirmation

No implementation detail, invariant architecture, campaign result, coverage result, design commentary, test
summary, gate reasoning, or retrospective observation was added to `docs/project-status.md`. No production
code, test, script, frozen artifact, or configuration was changed. The normative content, implementation
report, GI evidence, and post-GI coverage evidence already recorded in this log are unchanged. F9 was not
started.
