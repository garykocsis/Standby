# Session 09 — Material Prompt Log

Initiating prompt: `docs/prompts/session-09-f7-o1-commitment-admission.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — Record F7 as implementation in progress, not complete

**Instruction.** Update `docs/project-status.md` to show F7 as "implementation in progress" rather than
implemented/complete, as had been proposed.

**Consequence.** `docs/project-status.md` records F7 as `AUTHORIZED / IMPLEMENTATION IN PROGRESS` and G7
as `OPEN`, rather than recording the F7 implementation as finished. The ladder row, current-blocker
section, next-action section, and handoff summary were written to that same status.

### Prompt 2 — Status-only edits to the live status document

**Instruction.** Only update status in `docs/project-status.md`; do not add any other commentary.

**Consequence.** The proposed descriptive paragraph documenting the F7 `establishCommitment` responsibility
in §7 was not added. The §2 status sentence was reduced to a bare status statement. The only other change
made was a stale-status correction in §10 ("commitment admission and exercise remain unimplemented" →
"exercise remains unimplemented"). No explanatory or design commentary was introduced.

### Prompt 3 — Record the independently reviewed F7 result

**Instruction.** Update status only in `docs/project-status.md` to reflect the independently reviewed F7
result: F7 — O1 Commitment Admission COMPLETE; G7 PASS; F6B — O3 Enforcement with Authentic `O > 0` as the
next authorized implementation slice and current blocker. Add no implementation details, design commentary,
test summaries, gate reasoning, retrospective observations, or other new descriptive content. Make only the
minimum edits needed to bring existing status fields, roadmap/ladder entries, current-blocker/next-action
fields, and any now-stale status statements into consistency. Record the instruction and the resulting
status-only action in this log as audit chronology only, without changing or expanding its normative
content, implementation report, or previously recorded evidence. Modify no other files.

**Consequence.** `docs/project-status.md` status-only edits: the header now reads current slice F6B
(NEXT AUTHORIZED / NOT STARTED), last closed gate G7 (CLOSED / PASS), and F7 COMPLETE in the status line;
§2 names F6B as the next authorized slice and G7 as the last closed gate; the §3 ladder marks F7
**COMPLETE — G7 CLOSED** and F6B **NEXT / NOT STARTED**; §7's stale claim that commitment admission is
unimplemented and the obligation is zero in every reachable state was corrected; §10 records no open gate
and F6B as the next unstarted responsibility; §18 and the §19 handoff summary were brought to the same
status. No other file was modified, and the report and evidence recorded above were left unchanged.

### Prompt 4 — Correct the stale registry-consumption statement in §9A

**Instruction.** Correct the stale statement in `docs/project-status.md` §9A that says `StandbyHook` "does
not yet consume or enforce registry results". Make only the minimum status correction necessary so the
statement accurately reflects the current implemented state after F6A and F7. Add no implementation
details, design commentary, test evidence, historical explanation, or new descriptive material. Record the
instruction and the resulting status-only correction in this log. Modify no other files.

**Consequence.** The §9A sentence was changed from "The registry owns no Standby economic state, and
`StandbyHook` does not yet consume or enforce registry results." to "The registry owns no Standby economic
state. `StandbyHook` consumes registry results as of F6A and F7." No other change was made to §9A or to any
other file.

---

# Required Task Completion Report — F7 O1 Commitment Admission

## Files Inspected

**Operating and governing artifacts**

- `CLAUDE.md`
- `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/prompts/session-09-f7-o1-commitment-admission.md` (initiating prompt)
- `docs/implementation-plan.md` §12 (F7 / G7), §13 (F6B boundary)
- `docs/uniswap-v4-realization.md` §10.1–10.9 (commitment basis, bounded reference set, RR-O1-2 – RR-O1-8),
  §11–11.4 (temporal semantics, RR-O1-18 – RR-O1-21), §12.1–12.10 (O1 admission flow, RR-O1-1, RR-O1-9 –
  RR-O1-15, RR-O1-17), §13.1–13.2 (O2 boundary, not implemented)
- `docs/spec.md` §3.1 (O1), §4.1 (SPEC-E1 – SPEC-E6), §4.3 (SPEC-B9), §5 (SPEC-D1 – SPEC-D13)
- `docs/testing-strategy.md` §4.1 (O1-V1 – O1-V9), §11 requirement-mapping table
- `docs/prompts/session-08-log.md` (log format)

**Repository source**

- `src/StandbyHook.sol`
- `src/EligibilityRegistry.sol`, `src/interfaces/IEligibilityRegistry.sol`
- `src/libraries/StandbyMath.sol`, `src/libraries/CommitmentRefs.sol`, `src/libraries/ServiceDomain.sol`
- `script/helpers/StandbyFixtureConfig.sol`, `script/DeployStandbyHook.s.sol`
- `test/shared/BaseStandbyServiceTest.t.sol`, `test/shared/BaseActorAwareStandbyTest.t.sol`,
  `test/shared/BaseCommitmentStorageTest.t.sol`, `test/shared/BaseDerivationTest.t.sol`,
  `test/shared/ReferenceCalculations.sol`
- `test/harness/StandbyHookHarness.sol`
- `test/integration/O3SwapEnforcement.t.sol`, `test/unit/StandbyServiceLiquidityPrecondition.t.sol`,
  `test/unit/AggregateObligation.t.sol`, `test/fuzz/AggregateObligationFuzz.t.sol`

**Pinned dependency source**

- `v4-core/types/PoolId.sol`, `v4-core/types/PoolKey.sol` — the persisted service reference type
- `v4-core/libraries/TickMath.sol` — boundary prices used by the capacity composition and the test oracle

## Files Changed

**Modified**

- `src/StandbyHook.sol` — adds the production O1 transition `establishCommitment`, the
  `CommitmentEstablished` event, nine admission-specific custom errors, and two internal helpers
  (`_validateCommitmentTerms`, `_admissibleReferenceSlot`). Two stale doc comments were corrected: the
  contract-level slice description, and `_recordCommitment`'s statement that no production path reaches it.
- `docs/project-status.md` — status-only synchronization recording F7 as authorized and in progress with
  G7 open (see Prompt 1 and Prompt 2 above).

**Created**

- `test/shared/BaseCommitmentAdmissionTest.t.sol` — shared F7 fixture layered on the F6A real-path
  fixture; adds the Beneficiary eligibility domain, production O1 invocation helpers, and the
  `AdmissionState` snapshot/residue machinery.
- `test/unit/CommitmentAdmission.t.sol` — 25 tests covering the admission predicates.
- `test/integration/CommitmentAdmission.t.sol` — 15 tests covering the economic admission behavior against
  real PoolManager state, including canonical A1.
- `test/fuzz/CommitmentAdmissionFuzz.t.sol` — 5 fuzz properties covering the temporal, backing, identity,
  and reference-reuse boundaries.
- `docs/prompts/session-09-log.md` — this file.

No frozen canonical artifact was modified. No existing test file was modified. No existing shared fixture
was modified; `BaseCommitmentAdmissionTest` extends `BaseActorAwareStandbyTest` rather than changing it.

## Requirements Implemented

- **SPEC-E1 / RR-STATE-5** — O1 is authoritative only when `msg.sender` is the configured
  commitment-establishment authority, resolved from the activated service and distinct from every other
  role.
- **SPEC-E2** — the caller supplies commitment terms only. Supporting Capacity, current and prospective
  Aggregate Capacity Obligation, the proposed commitment's Capacity Obligation, validity, binding status,
  the reference slot, the commitment identity, and the initial Remaining Entitlement are all derived.
- **SPEC-E3 / RR-O1-18, RR-O1-19** — successful admission establishes a valid entitlement and its Capacity
  Obligation immediately; a future `exercisableFrom` does not defer backing.
- **SPEC-E4 / SPEC-B9 / RR-O1-10** — admission requires `S_current >= O_current + CO_new`, with equality
  sufficient, evaluated before any authoritative write.
- **SPEC-E5 / RR-O1-1, RR-O1-12** — success atomically produces exactly one commitment: identity
  allocation, the complete F4 fact record with `Remaining == Original`, the bounded enforcement reference,
  and the identity-sequence advance.
- **SPEC-E6 / RR-O1-9** — every rejection leaves no residue, and bounded-reference exhaustion is a distinct
  failure from insufficient backing.
- **RR-O1-5** — identities begin at 1, are unique, monotonic, and never recycled; failed O1 consumes none.
- **RR-O1-6, RR-O1-7, RR-O1-8, RR-O1-13** — a reference may be taken over only when the F5 permanent
  non-binding predicate holds for its commitment, and reuse preserves the displaced historical record.
- **RR-O1-11** — the proposed commitment's Capacity Obligation is derived through the same
  `StandbyMath.commitmentObligation` used for authoritative commitments.
- **RR-O1-15, RR-O1-17** — no validity, exercisability, obligation, lifecycle, or aggregate value is
  persisted by admission.
- **RR-O1-20** — the half-open validity window is enforced at admission through `StandbyMath.isValid`.
- Beneficiary eligibility is read from the authoritative per-service `IEligibilityRegistry` at admission
  and is not a validity-ending condition afterwards.

## Tests Added or Changed

**`test/unit/CommitmentAdmission.t.sol` (25 tests)**

| Test | Requirement proved |
| --- | --- |
| `test_establishCommitment_byEstablishmentAuthority_isAdmitted` | G7.1 positive: the configured authority may admit |
| `test_establishCommitment_byUnauthorizedCaller_isRejected` | G7.1 rejection for a roleless caller |
| `test_establishCommitment_byEveryOtherRole_isRejected` | G7.1: configuration authority, registry admin, ExerciseRouter, exercise authority, Beneficiary, eligible trader, liquidity provider, and the trusted swap perimeter each confer no establishment authority |
| `test_establishCommitment_onAnUnconfiguredHook_isRejected` | G7.2: an unactivated PES admits nothing and consumes no identity |
| `test_establishCommitment_withZeroBeneficiary_isRejected` | G7.3 zero Beneficiary |
| `test_establishCommitment_withZeroExerciseAuthority_isRejected` | G7.3 zero exercise authority |
| `test_establishCommitment_withZeroEntitlement_isRejected` | G7.3 `q == 0` |
| `test_establishCommitment_withValidUntilEqualToExercisableFrom_isRejected` | G7.3 `TV == TE` |
| `test_establishCommitment_withValidUntilBeforeExercisableFrom_isRejected` | G7.3 `TV < TE` |
| `test_establishCommitment_withValidUntilInThePast_isRejected` | G7.3 `TV < now` |
| `test_establishCommitment_withValidUntilEqualToNow_isRejected` | G7.3 `TV == now`, the half-open endpoint |
| `test_establishCommitment_withAnAlreadyOpenWindow_isAdmitted` | G7.3 `TE < now < TV` admissible |
| `test_establishCommitment_withAWindowOpeningNow_isAdmitted` | G7.3 `TE == now < TV` admissible |
| `test_establishCommitment_withAFutureWindow_isAdmitted` | G7.3 `now < TE < TV` admissible |
| `test_establishCommitment_forAnIneligibleBeneficiary_isRejected` | G7.4 rejection |
| `test_establishCommitment_succeedsForTheSameBeneficiaryOnceEligible` | G7.4 attribution: the rejection is the eligibility predicate and nothing else |
| `test_establishCommitment_doesNotAcceptTraderOrLiquidityEligibility` | G7.4 predicate-domain separation |
| `test_revokingBeneficiaryEligibility_doesNotReleaseAnAdmittedObligation` | G7.4: later ineligibility changes no fact, no obligation, no reference |
| `test_admittedCommitment_hasFullRemainingEntitlement` | G7.5 `Original == Remaining`, `Original - Remaining == 0` |
| `test_successiveAdmissions_receiveUniqueMonotonicIdentities` | G7.14 uniqueness and monotonicity |
| `test_failedAdmission_consumesNoIdentity` | G7.14 failed O1 consumes no identity |
| `test_unadmittedIdentity_doesNotExist` | G7.14: an unallocated identity is not an empty commitment |
| `test_rejectedAdmission_alongsideExistingCommitments_leavesNoResidue` | G7.15 residue check against a Hook already holding authentic commitments |
| `test_successfulAdmission_emitsAdmissionEvidence` | admission evidence matches the returned identity and written slot |
| `test_fixtureCapacityFarExceedsTheEntitlementUsedHere` | guards the fixture assumption the predicate tests rely on |

Every rejection above additionally asserts the complete `AdmissionState` snapshot is unchanged (G7.15).

**`test/integration/CommitmentAdmission.t.sol` (15 tests)**

| Test | Requirement proved |
| --- | --- |
| `test_canonicalA1_firstAuthenticPositiveObligation` | G7.19: from `S = 80,000` / `O = 0`, a real O1 for `q = 50,000` yields `S = 80,000`, `O = 50,000`, `Remaining = 50,000`, one authentic identity, one bounded reference, unchanged price/tick/liquidity, no custody |
| `test_successfulAdmissions_takeNoCustodyAndMoveNoPoolState` | G7.16 across several admissions |
| `test_admittedCommitment_persistsTheCompleteAuthoritativeBasis` | G7.17 field-by-field, including the service reference |
| `test_futureWindowCommitment_isValidAndBindingButNotExerciseQualified` | G7.6: valid, not exercise-qualified, `CO > 0`, contributes to `O` |
| `test_admissionMeasuresAgainstTheDerivedCurrentObligation` | G7.7: the boundary moves with the derived `O` and returns when validity ends, with no expiry transaction |
| `test_proposedCommitmentObligation_matchesAnEquivalentAdmittedCommitment` | G7.8 plus differential agreement with `ReferenceCalculations` |
| `test_admissionDecision_followsAuthoritativePoolManagerState` | G7.9: a real swap changes `S`, and the admission decision follows it; post-swap `S` matches the independent oracle |
| `test_admission_belowCapacity_isPermitted` | G7.10 `S > O'` |
| `test_admission_exactlyAtCapacity_isPermitted` | G7.10 `S == O'` |
| `test_admission_oneUnitAboveCapacity_isRejected` | G7.10 `S < O'` |
| `test_admission_boundaryAppliesToTheAggregate` | G7.10 against the aggregate, not the individual commitment |
| `test_admission_insertsIntoAnEmptyReferenceSlotAndBecomesVisibleToTheAggregate` | G7.11 |
| `test_fullIndex_reusesAReclaimableReferenceWhilePreservingHistory` | G7.12: fresh identity, reclaimed slot, unchanged historical record, correct aggregate |
| `test_fullIndexOfBindingCommitments_isRejectedOnBoundedCapacity` | G7.13 with backing proved amply sufficient |
| `test_boundedExhaustion_isDistinctFromInsufficientBacking` | G7.13 distinctness |

**`test/fuzz/CommitmentAdmissionFuzz.t.sol` (5 properties, 1,000 runs default / 10,000 CI)**

| Test | Requirement proved |
| --- | --- |
| `testFuzz_admission_acceptsExactlyTheAdmissibleWindows` | G7.3: both endpoints fuzzed across a span straddling the present; the expected verdict and the exact rejection reason are composed independently |
| `testFuzz_admission_acceptsExactlyTheBackedEntitlements` | G7.10: entitlement fuzzed to twice capacity, with capacity confirmed against the independent oracle |
| `testFuzz_admission_boundaryFollowsTheExistingObligation` | G7.10 aggregate boundary with an existing commitment |
| `testFuzz_admissions_produceUniqueMonotonicSinglyReferencedIdentities` | G7.14 with a rejected attempt interleaved between every success |
| `testFuzz_fullIndex_reusesAnyReclaimableSlot` | G7.12 with the terminal slot fuzzed across the whole bounded index |

**G7.18** is carried by the differential assertions inside the integration and fuzz files: `S`, per-commitment
`CO`, and validity are each compared against `ReferenceCalculations`, and reclaimability is exercised only
where the production obligation derivation reports zero.

No existing assertion was removed or weakened.

## Commands Run

```bash
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test --match-path test/unit/CommitmentAdmission.t.sol
forge test --match-path test/integration/CommitmentAdmission.t.sol
forge test --match-path test/fuzz/CommitmentAdmissionFuzz.t.sol
forge test
FOUNDRY_PROFILE=ci forge test
```

## Results

- `forge fmt --check` — clean.
- `forge build --sizes` — compiles; `StandbyHook` deployed size 18,108 bytes, 6,468 bytes of margin.
- `forge test --match-path test/unit/CommitmentAdmission.t.sol` — 25 passed, 0 failed.
- `forge test --match-path test/integration/CommitmentAdmission.t.sol` — 15 passed, 0 failed.
- `forge test --match-path test/fuzz/CommitmentAdmissionFuzz.t.sol` — 5 passed, 0 failed (1,002 runs each).
- `forge test` — **362 passed, 0 failed, 0 skipped** across 32 suites.
- `FOUNDRY_PROFILE=ci forge test` — **362 passed, 0 failed, 0 skipped** (10,002 fuzz runs per property).

The pre-existing F4, F5, F5 real-PoolManager differential, and F6A suites are included in those totals and
all remain passing (G7.20).

## Gate Evidence

**Implemented and verified**

- G7.1 establishment authority, including non-conferral by seven other roles — unit.
- G7.2 activated-PES requirement — unit, against a real unactivated Hook deployed through the canonical
  procedure.
- G7.3 all six independent term rejections and all three admissible temporal configurations — unit and
  fuzz.
- G7.4 Beneficiary eligibility at admission, its attribution, its domain separation, and its
  non-release of an admitted obligation — unit.
- G7.5 initial entitlement basis — unit.
- G7.6 future-window binding with `CO > 0` and contribution to `O` — integration.
- G7.7 current `O` derived from bounded references, including release by expiry with no transaction —
  integration.
- G7.8 proposed `CO` under the same F5 semantics, differentially checked — integration.
- G7.9 `S` from authoritative PoolManager state driving the admission decision, after a real swap —
  integration.
- G7.10 exact backing boundary in all three regions, with fuzz coverage — integration and fuzz.
- G7.11 empty-slot insertion and F5 visibility — integration.
- G7.12 reclaimable reuse with preserved history and non-recycled identity, with the slot position fuzzed
  across the whole index — integration and fuzz.
- G7.13 bounded-set rejection, proved distinct from insufficient backing — integration.
- G7.14 identity uniqueness, monotonicity, non-consumption on failure, non-recycling — unit and fuzz.
- G7.15 failure residue for all five required rejection classes (unauthorized caller, invalid terms,
  ineligible Beneficiary, bounded exhaustion, insufficient backing) — every rejection assertion in the F7
  suites compares the full `AdmissionState` snapshot.
- G7.16 no reservation or custody: PoolManager price, tick, liquidity, and Beneficiary / Hook /
  ExerciseRouter protected-output balances — integration.
- G7.17 complete authoritative commitment basis read through the production surface — integration.
- G7.18 F5 ownership: `S`, `CO`, `O`, and validity checked against `ReferenceCalculations`; reclaimability
  routed through the same `StandbyMath.isPermanentlyNonBinding` the obligation derivation uses.
- G7.19 canonical A1 — integration.
- G7.20 prior-gate preservation — full suite green under both profiles.

**Still unverified**

- Stateful invariant coverage of admission is not part of G7; it belongs to the later GI slice.
- No public-testnet or live-Anvil broadcast evidence exists for O1, consistent with the carried-forward F0
  limitation.

## Known Limitations / Blockers

No blockers. Two implementation decisions are recorded for review rather than buried:

1. **External signature uses `uint128 originalEntitlement`, not `uint256`.** The prompt's conceptual
   surface names `uint256`, and permits adapting the concrete signature to the existing verified
   implementation structure. The F4 commitment record persists `originalEntitlement` and
   `remainingEntitlement` as `uint128`, and `StandbyMath.commitmentObligation` takes `uint128`. Accepting a
   `uint256` would have required inventing a narrowing-rejection predicate that no frozen artifact names.
   Taking `uint128` keeps the admitted extent exactly the persisted extent with no lossy conversion and no
   invented predicate.

2. **Service existence is checked immediately before authority authentication, not after.** §17 of the
   session prompt lists "authenticate commitment-establishment authority" as step 1 and "require activated
   PES" as step 2. The commitment-establishment authority is a per-service fact (RR-STATE-5) and does not
   exist until activation, so step 1 depends on step 2 and cannot precede it in substance. Both predicates
   still precede every other check and every write, and neither is weakened; the ordering only determines
   which reason an unconfigured Hook reports. `StandbyHook__ServiceNotConfigured` was preferred over
   reporting an unauthorized caller against a zero-valued authority field, so the rejection is attributable.

Neither is a semantic change and neither weakens a canonical requirement, but both are reported explicitly
rather than treated as implementation trivia.

## Scope Check

Work remained within F7. No out-of-scope changes.

- No F6B behavior was implemented. The O3 enforcement path was not touched; it consumes the same
  `_aggregateObligation()` derivation it consumed before, which now returns a positive value in states
  where an admitted commitment exists. No enforcement test was added or changed.
- No F8 behavior was implemented: no exercise authentication, no exercise initiation, no causal context, no
  exact-output execution, no settlement, no Beneficiary delivery, no fulfillment attribution, and no
  Remaining Entitlement reduction. `_writeRemainingEntitlement` remains unreachable from any production
  path.
- No frozen canonical artifact was modified.
- `docs/project-status.md` was synchronized to record F7 as the authorized, in-progress slice with G7 open,
  as instructed. It records no gate closure.

## Proposed Gate Assessment

**PASS (proposed).**

Every G7.1–G7.20 obligation has implementation and passing verification evidence produced through
production paths: the production `StandbyHook`, the production `establishCommitment` transition, the real
pinned `PoolManager`, real canonical liquidity added through the production `beforeAddLiquidity` path, and
the F2 registry under its own administrator. No commitment presented as authentic anywhere in the F7
evidence was created by the F4 storage harness. Every economic quantity O1 consumes resolves through the
existing F5 derivations, and each is differentially checked against the independent
`ReferenceCalculations` oracle.

This is a proposed assessment only. G7 has not been closed and no downstream slice is authorized.

## Recommended Next Step

Submit the F7 implementation and G7 evidence for independent review. On closure, the smallest coherent next
responsibility is **F6B — O3 Enforcement with Authentic `O > 0`**: exercise the existing ordinary-transition
enforcement path against the authentic positive obligation F7 now creates, beginning with canonical A2
(`S = 65,000`, `O = 50,000`, permitted) and A3 (the backing-destructive attempt, refused). No F6B behavior
was implemented in this session.

## Prompt Audit

All material follow-up instructions were recorded in `docs/prompts/session-09-log.md`.

**Material prompts recorded: 2.**
