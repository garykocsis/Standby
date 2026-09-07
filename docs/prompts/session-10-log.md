# Session 10 — Material Prompt Log

Initiating prompt: `docs/prompts/session-10-f6b-o3-enforcement.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — Record the independently reviewed F6B result

**Instruction.** Update status only in `docs/project-status.md` to reflect the independently
reviewed F6B result: F6B — O3 Enforcement with Authentic `O > 0` COMPLETE; G6B PASS; F8A —
O2 Authorization / Hook-Owned Causal Context as the next authorized implementation slice and
current blocker. Add no implementation details, design commentary, test summaries, gate
reasoning, retrospective observations, or other new descriptive content. Make only the
minimum edits needed to bring existing status fields, roadmap/ladder entries,
current-blocker/next-action fields, and any now-stale status statements into consistency.
Record the instruction and the resulting status-only action in this log as audit chronology
only, without changing or expanding its normative content, implementation report, or
previously recorded evidence. Modify no other files.

**Consequence.** `docs/project-status.md` status-only edits: the header now reads current
slice F8A (NEXT AUTHORIZED / NOT STARTED), last closed gate G6B (CLOSED / PASS), and F6B
COMPLETE in the status line; §2 names F8A as the next authorized slice and G6B as the last
closed gate; the §3 ladder marks F6B **COMPLETE — G6B CLOSED** and F8A **NEXT / NOT
STARTED**; §10 records no open gate, F8A as the next unstarted responsibility, and F8B/F8C/F8D
as the unauthorized downstream slices; §18 and the §19 handoff summary were brought to the
same status. No other file was modified, and the report and evidence recorded below were left
unchanged.

---

## Implementation Chronology

1. Read `CLAUDE.md`, `docs/project-status.md`, the Session 10 prompt, and
   `docs/implementation-plan.md` §11 (F6A), §12 (F7), §13 (F6B), plus the
   `docs/demo-spec.md` canonical A1–A4 sequence and DP/DEMO-AC evidence sections.
2. Inspected the F6A/F5/F7 production seam in `src/StandbyHook.sol` in full before
   considering any production change, per §19 Implementation Restraint.
3. Concluded the existing production seam already enforces the required predicate:
   `_beforeSwap` and `_beforeRemoveLiquidity` derive prospective state through the
   F5 derivations and call `_requireProspectiveBacking`, which compares prospective
   Supporting Capacity against `_aggregateObligation()` with `<` — so exact
   sufficiency passes and a positive obligation changes only what the derivation
   returns, not how enforcement reads it. **No production Solidity change was made.**
4. Verified the canonical A2/A3 integer expectations independently, off-chain, from
   the frozen fixture geometry (`L = 6,707,079,990,254`, `tickQ = -240`, initial tick
   `0`) and the pinned v4 exact-output price step, confirming `S' = 65,000.000000` and
   `S' = 45,000.000000` MockUSDC exactly, before writing any assertion against them.
5. Added the F6B shared fixture, integration suite, and focused fuzz suite (below).
6. Ran the narrow F6B suites, then the full suite under the default and `ci` profiles.
7. Confirmed the fuzz properties genuinely reach the decision boundary by temporary
   mutation: replacing `>=` with `>` and with `+ 1 >=` in each property's admission
   predicate made both properties fail with counterexamples at `S' = O` and
   `S' = O - 1` respectively. The mutations were reverted; the recorded results below
   are from the unmutated files.

---

## Required Task Completion Report

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`, `docs/implementation-plan.md` (§11, §12, §13), `docs/demo-spec.md`
- `docs/prompts/session-10-f6b-o3-enforcement.md`, `docs/prompts/session-09-log.md`
- `src/StandbyHook.sol` (complete), `src/demo/ActorAwareTestRouter.sol`,
  `src/libraries/CommitmentRefs.sol`
- `script/helpers/StandbyFixtureConfig.sol`
- `test/shared/BaseActorAwareStandbyTest.t.sol`, `test/shared/BaseCommitmentAdmissionTest.t.sol`,
  `test/shared/BaseStandbyServiceTest.t.sol`, `test/shared/ReferenceCalculations.sol`
- `test/integration/O3SwapEnforcement.t.sol`, `test/integration/O3LiquidityEnforcement.t.sol`,
  `test/integration/CommitmentAdmission.t.sol`
- `test/fuzz/O3SwapFuzz.t.sol`, `test/fuzz/O3LiquidityFuzz.t.sol`
- `test/harness/LiquidityPermissiveStandbyHookHarness.sol`

Dependency behavior consumed (already reproduced in the pinned-source-derived F5 kernel):
the v4 exact-output swap step and the `zeroForOne` output price update, used only to
justify the independent integer expectations off-chain.

### Files Changed

Created:

- `test/shared/BaseAuthenticBackingTest.t.sol` — F6B shared real-path fixture. Extends the
  F7 admission fixture unchanged, adding the exact-output protected transition form, the
  canonical-position removal form, the backing-specific rejection expectation, the
  independent Supporting Capacity and Aggregate Capacity Obligation oracles built on
  `ReferenceCalculations`, commitment-fact and actor-balance invariance assertions.
- `test/integration/O3AuthenticBackingEnforcement.t.sol` — 24 integration tests: the G6B
  evidence against an authentic positive obligation.
- `test/fuzz/O3AuthenticBackingFuzz.t.sol` — 2 focused fuzz properties over the swap and
  removal decision boundaries.
- `docs/prompts/session-10-log.md` — this log.

Modified:

- `script/helpers/StandbyFixtureConfig.sol` — added the two frozen `demo-spec.md` expected
  verification values `EXPECTED_A2_S = 65,000.000000` and
  `EXPECTED_A3_PROSPECTIVE_S = 45,000.000000` MockUSDC, alongside the existing
  `EXPECTED_INITIAL_S`. Fixture/verification constants only; no production contract reads
  this library.

Not changed:

- `src/StandbyHook.sol` and every other production source file. No production Solidity
  change was necessary or made.

### Requirements Implemented

F6B — O3 Enforcement with Authentic `O > 0`, as specified by
`docs/implementation-plan.md` §13 and the Session 10 prompt. F6B introduces no new O3
mechanism; it composes the existing F6A enforcement seam, the F5 authoritative
derivations, and the F7 production admission transition, and supplies the economic proof.

### Tests Added or Changed

Integration — `test/integration/O3AuthenticBackingEnforcement.t.sol`:

| Test | Requirement proven |
| --- | --- |
| `test_authenticObligation_arisesOnlyFromTheProductionAdmissionTransition` | G6B-1: every enabled ordinary O3 family runs first and leaves `O = 0`; only production O1 makes it positive |
| `test_canonicalA2_compatibleOrdinarySwap_succeedsAgainstAuthenticObligation` | G6B-4, G6B-7, G6B-10: A2 succeeds, trader receives exactly 15,000, ends `S = 65,000` / `O = 50,000` / `Remaining = 50,000`, commitment facts and index untouched |
| `test_successfulOrdinarySwaps_leaveEveryCommitmentFactIntact` | G6B-10: repeated bidirectional ordinary swaps change no commitment fact, reference, identity, or obligation |
| `test_exactBoundarySwap_whereProspectiveCapacityEqualsTheObligation_isPermitted` | G6B-5: `S' = O` is permitted, proven as prediction and as authoritative post-state |
| `test_oneRawUnitBeyondTheBoundary_isRejectedForInsufficientBacking` | G6B-6: one raw unit past the boundary is refused on `(O - 1, O)` |
| `test_canonicalA3_destructiveOrdinarySwap_isRejectedForInsufficientBacking` | G6B-6, G6B-8, G6B-9: A3 derives `S' = 45,000`, is refused on `(45,000, 50,000)`, leaves no residue, and leaves the A2 state exactly |
| `test_afterTheDestructiveRefusal_aCompatibleRequestBySameTraderStillSucceeds` | The refusal bounds the transition, not the actor or the pool |
| `test_oppositeDirectionSwap_withAuthenticObligation_isPermittedAndIncreasesCapacity` | G6B-11 |
| `test_oppositeDirectionSwap_leavingTheServiceDomain_isRejectedForDomainNotBacking` | G6B-11: domain refusal is not substituted by a backing verdict under `O > 0` |
| `test_safeLiquidityRemoval_withAuthenticObligation_isPermitted` | G6B-12 |
| `test_exactBoundaryLiquidityRemoval_whereProspectiveCapacityEqualsTheObligation_isPermitted` | G6B-13 |
| `test_destructiveLiquidityRemoval_isRejectedForInsufficientBacking` | G6B-14, G6B-9 |
| `test_safeLiquidityRemoval_afterProviderEligibilityLoss_stillExecutes` | G6B-15: exit after eligibility loss, with the same provider then proven genuinely barred from adding |
| `test_destructiveLiquidityRemoval_afterEligibilityLoss_isStillRejectedForBacking` | G6B-14/15: eligibility does not change which removals are economically admissible either way |
| `test_liquidityAddition_withAuthenticObligation_isPermittedAndLeavesTheObligationAlone` | G6B-16 |
| `test_liquidityAddition_byIneligibleProvider_isStillRejectedUnderAuthenticObligation` | G6B-16 |
| `test_liquidityAddition_withAnInteriorBoundary_isStillRejectedUnderAuthenticObligation` | G6B-16: topology holds even though the addition improves backing |
| `test_expiry_releasesTheObligationByDerivationWithoutChangingRemaining` | G6B-17: `O` at `validUntil - 1` vs `validUntil`, Remaining untouched, and the previously refused transition now executes |
| `test_beneficiaryIneligibility_neitherReducesTheObligationNorRemovesProtection` | G6B-18 |
| `test_untrustedPerimeter_isStillRefusedUnderAuthenticObligation` | G6B-20 |
| `test_forgedHookData_stillCannotEstablishTheActorUnderAuthenticObligation` | G6B-20 |
| `test_permissioningAndBackingRemainDistinctRefusals` | G6B-20: the two refusals never substitute for each other |
| `test_aggregateObligation_ofMultipleAuthenticCommitments_isWhatEnforcementProtects` | G6B-19: refused on `(40,000, 45,000)` though safe against every single commitment |
| `test_aggregateObligation_shrinksByDerivationAsMembersExpire` | G6B-17, G6B-19: the aggregate falls by derivation alone |

Fuzz — `test/fuzz/O3AuthenticBackingFuzz.t.sol`:

| Test | Requirement proven |
| --- | --- |
| `testFuzz_protectedSwap_isAdmittedExactlyWhenProspectiveCapacityCoversTheObligation` | G6B-23: biconditional decision boundary for protected exact-output swaps against a fuzzed authentic aggregate of up to three commitments |
| `testFuzz_liquidityRemoval_isAdmittedExactlyWhenProspectiveCapacityCoversTheObligation` | G6B-23, G6B-15: same biconditional for removals, with eligibility revoked on half the runs |

### Commands Run

```bash
git status
forge build
forge fmt
forge fmt --check
forge build --sizes
forge test --match-path test/integration/O3AuthenticBackingEnforcement.t.sol
forge test --match-path test/fuzz/O3AuthenticBackingFuzz.t.sol -vv
forge test
FOUNDRY_PROFILE=ci forge test
```

### Results

- `forge fmt --check` — clean.
- `forge build` / `forge build --sizes` — successful.
- `forge test --match-path test/integration/O3AuthenticBackingEnforcement.t.sol` —
  24 passed, 0 failed.
- `forge test --match-path test/fuzz/O3AuthenticBackingFuzz.t.sol` — 2 passed, 0 failed
  (1,002 runs each under the default profile).
- `forge test` — **388 passed, 0 failed, 0 skipped** across 34 suites.
- `FOUNDRY_PROFILE=ci forge test` — **388 passed, 0 failed, 0 skipped** (10,000 fuzz runs
  per property).

Boundary-coverage mutation checks (temporary, reverted):

- swap property, `>=` → `>`: FAIL at run 23 — an `S' = O` case is generated and is
  required to succeed.
- swap property, `>=` → `+ 1 >=`: FAIL at run 7 with
  `InsufficientProspectiveBacking(13926, 13927)` — an `S' = O - 1` case is generated and
  is required to be refused.
- removal property, both mutations: FAIL at runs 4 and 1 respectively, the second with
  `InsufficientProspectiveBacking(13909, 13910)`.

### Gate Evidence

Implemented and verified, on the real pinned Uniswap v4 execution stack with no harness
and no seeded economic state:

1. authentic `O > 0` created exclusively through production F7 O1 — verified;
2. current `O` consumed through the F5 bounded-reference derivation, cross-checked against
   an independent reconstruction from the persisted commitment facts — verified;
3. prospective `S'` consumed through the F5 real-PoolManager derivation, cross-checked
   against frozen canonical expectations and against authoritative post-state — verified;
4. `S' > O` succeeds — verified;
5. `S' = O` succeeds, for both swaps and removals — verified;
6. `S' < O` refused specifically on the `(prospectiveCapacity, obligation)` pair — verified;
7. canonical A2 ends `S = 65,000` / `O = 50,000` / `Remaining = 50,000` — verified;
8. canonical A3 derives `S' = 45,000`, is refused backing-specifically, and leaves the A2
   state unchanged — verified;
9. rejected O3 transitions leave no PoolManager, commitment, reference, obligation,
   capacity, or currency-balance residue — verified;
10. successful ordinary O3 transitions modify no commitment fact, no Remaining Entitlement,
    and no obligation — verified;
11. opposite-direction domain constraints intact under `O > 0` — verified;
12–15. safe removal, exact-boundary removal, destructive removal, and safe removal after
    eligibility loss — verified;
16. liquidity-add eligibility and topology constraints intact under `O > 0` — verified;
17. expiry changes `O` only by derivation and leaves Remaining Entitlement — verified;
18. Beneficiary ineligibility neither reduces `O` nor lifts protection — verified;
19. aggregate `O` over multiple authentic commitments is the enforced quantity — verified;
20. F6A trust, actor attribution, permissioning, domain, and topology behavior intact under
    `O > 0` — verified, and the whole F6A suite remains green;
21. F5 remains the single production owner of `S`, `S'`, and `O` — no production derivation
    was added, changed, or duplicated; the only new calculations are test-side oracles in
    `ReferenceCalculations`, which never call the production derivations;
22. no F8 authorization, causal context, protected execution, delivery, fulfillment, or
    entitlement-reduction behavior was introduced — no production file was touched;
23. focused F6B integration and fuzz evidence passes — verified;
24. prior F4, F5, F6A, and F7 suites remain green — verified.

Still unverified (out of F6B scope): everything that depends on O2 exercise, and the
stateful arbitrary-sequence invariant campaign reserved for `GI`.

### Known Limitations / Blockers

- No blocker. No contradiction between frozen artifacts was found.
- The independent prospective-capacity expectations used by the fuzz properties are exact
  for the frozen canonical fixture geometry, where the whole service domain is one
  constant-liquidity interval. They are fixture-specific test oracles by construction and
  must not be reused for a fixture that admits interior liquidity boundaries; the
  production enforcement path does not depend on them.
- The limitations carried forward from earlier gates (local-only `HelperConfig`
  infrastructure resolution, `run()` verified in script simulation rather than against a
  broadcasting node) are unchanged.

### Scope Check

Work remained inside the authorized F6B slice. No production Solidity was modified. The
only non-test change is the addition of two frozen `demo-spec.md` expected verification
constants to the fixture-constants library. No downstream slice was started.

### Proposed Gate Assessment

**PASS (proposed).** All 24 G6B requirements have passing evidence on the real execution
stack, from authentic obligations created only by production O1. This is a proposed
assessment only; G6B remains open until external review closes it.

### Recommended Next Step

Independent review of the F6B evidence and an explicit G6B decision. The smallest coherent
next implementation responsibility after that is **F8A — O2 Authorization / Hook-Owned
Causal Context**, which is not authorized and has not been started.

### Prompt Audit

All material follow-up instructions were recorded in this log. **0 material follow-up
prompts** were issued during Session 10; the session executed the preserved initiating
prompt `docs/prompts/session-10-f6b-o3-enforcement.md` as written.
