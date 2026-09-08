# Session 13 — Material Prompt Log

Initiating prompt: `docs/prompts/session-13-f8c-authoritative-settlement-delivery.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — Synchronize `docs/project-status.md` with the reviewed F8C result

**Instruction.** Update **status only** in `docs/project-status.md` to reflect the independently
reviewed F8C result: F8C — Authoritative Settlement / Direct Beneficiary Delivery **COMPLETE**, G8C
**PASS**, and F8D — O2 Causal Finalization / Remaining Entitlement Reduction as the **next authorized
implementation slice / current blocker**. No implementation details, design commentary, test
summaries, gate reasoning, retrospective observations, methodology observations, or other new
descriptive content may be added to that document; only the minimum edits needed to bring existing
status fields, roadmap/ladder entries, current-blocker/next-action fields, last-closed-gate fields,
and now-stale status statements into consistency. This session log is to record the instruction and
the resulting status-only action as audit chronology, without changing or expanding its normative
content, implementation report, verification evidence, proposed gate assessment, or previously
recorded evidence. No other file may be modified.

**Consequence.** `docs/project-status.md` was updated in place, status-only: the header slice, last
closed gate and status ladder; the §2 next-authorized-slice, last-closed-gate and gate-closure
statements; the §3 ladder rows for F8C and F8D; the §7 line that still said settlement and delivery
were unimplemented; the §10 current blocker, its downstream-authorization statement and the
carried-forward limitation wording; the §18 next action; and the §19 handoff validated-state,
current-gate, next-blocker and next-step entries. No new descriptive content was introduced, no other
file was changed, and no implementation, test, or verification state changed.

---

## Implementation Chronology

1. Read `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`,
   `docs/project-status.md`, the Session 13 prompt, `docs/implementation-plan.md` §14.0 (R1–R5
   decomposition), §15 (F8B) and §16 (F8C), and `docs/uniswap-v4-realization.md` §13.8 (RR-O2-10),
   §14 (RR-O2-11 … RR-O2-15), §15 (RR-O2-16 … RR-O2-22) and §16 (RR-O2-4, RR-O2-5).
2. Inspected the current production and test surfaces named by the prompt: `src/ExerciseRouter.sol`,
   `src/StandbyHook.sol`, `test/harness/ExerciseDeltaClosureRouter.sol`,
   `test/harness/AdversarialExerciseRouter.sol`, `test/harness/StandbyHookHarness.sol`,
   `test/shared/BaseExerciseAuthorizationTest.t.sol`, `test/shared/BaseAdversarialExerciseTest.t.sol`,
   `test/shared/BaseUnbackedExerciseAuthorizationTest.t.sol`, `test/integration/ProtectedExecution.t.sol`,
   `test/fuzz/ProtectedExecutionFuzz.t.sol` and `test/periphery/ProtectedExecutionPerimeter.t.sol`.
3. Inspected the pinned Uniswap v4 dependency directly rather than relying on remembered APIs.
4. Implemented R4 in `src/ExerciseRouter.sol` and the slice-completion barrier, then built the F8C
   test infrastructure and the four F8C test families.

---

## Implementation Decisions

### Decision 1 — R3 returns the execution facts R4 needs

`_executeAuthorizedExercise` now returns `(PoolKey, SwapParams, BalanceDelta)` rather than only the
delta. Settlement needs the exact currencies of exactly the operation R3 executed, and the alternative
— reconstructing a second protected-operation description inside R4 — would be a second statement of
what a Standby exercise trades. This is the shape §6 of the session prompt suggested, and it also
removed the delta-closure harness's own pre-read of the service `PoolKey`.

### Decision 2 — signed conversion of the authoritative input debt

The exact conversion is:

```solidity
int256 inputDelta = _params.zeroForOne ? int256(_delta.amount0()) : int256(_delta.amount1());

if (inputDelta >= 0) revert ExerciseRouter__NoAuthoritativeInputDebt(inputDelta);

actualInput = uint256(-inputDelta);
```

The `int128` delta amount is **widened to `int256` before negation**. Negating `int128` in place is
unsafe at `type(int128).min`, whose negation is not representable in `int128` and wraps back to
itself; widening first makes the whole signed domain the PoolManager can express convert exactly.
`uint256(-inputDelta)` is then a value in `[1, 2^127]` and cannot overflow. No absolute value is
taken anywhere, and a zero or positive input side is refused rather than reinterpreted. This is
verified directly at `type(int128).min`, at `-1`, at `0`, at a credit-signed input side, and across
the full `int128` × `int128` × direction domain by fuzz.

### Decision 3 — the completion barrier is a completion condition, not a stub

`exercise` requires the Hook-owned causal context to have been **consumed** (`EMPTY`) after the
unlock returns. At F8C nothing can consume it, so every production exercise reverts with
`ExerciseRouter__ExerciseNotFinalized(EXECUTED)` and the swap, settlement and delivery unwind with it.
The condition is stated as what completion actually requires rather than as a slice marker, so the
later finalization slice satisfies it by consuming the context inside the same unlock, with nothing
here to remove or revisit. No pseudo-finalization function was invented and no completion flag is
persisted.

### Decision 4 — `maxInput` transport

`maxInput` is carried to the settlement stage as the `unlock` payload and nowhere else. It is not
passed to the Hook, does not enter the causal context, and is not persisted. The unlock payload is
returned verbatim by the PoolManager to a callback that only the PoolManager can enter, and it is
compared against authoritative accounting rather than trusted.

### Decision 5 — two delta-closure requirements rather than trusting `settle`/`take`

`settle()` credits whatever actually moved and `take()` accounts whatever was actually taken, so
neither is proof. Each side is required to be closed by `TransientStateLibrary.currencyDelta(...) == 0`
immediately after the operation that was supposed to close it. `PoolManager.unlock` would also refuse
to return with any delta open, but that is a count of open deltas rather than a statement about this
exercise's own input debt and output credit.

### Decision 6 — F8B evidence preserved, F8C evidence built alongside

`ExerciseDeltaClosureRouter` was **not** retired. Its purpose changed rather than disappeared: F8A and
F8B evidence is about authorization and Hook-owned execution evidence *in isolation*, and observing
that a committed real execution delivers nothing to the Beneficiary now requires a router with no R4
behind it, because production has one. It was narrowed to that role, re-parented onto the new
`UnfinalizedExerciseRouter`, and adapted to the new R3 return shape; no F8A or F8B test was changed,
weakened, or removed.

F8C-facing positive paths use new R4-accurate infrastructure instead: `UnfinalizedExerciseRouter` is
the production `ExerciseRouter` with the completion barrier lifted and nothing else changed, and
`BaseExerciseSettlementTest` configures it, funds the exerciser with input currency only, and
deliberately keeps the router's inherited pre-funding so that "the router could have paid and did not"
is checkable rather than absent.

### Decision 7 — the authoritative debt is obtained from production, not estimated

`maxInput` boundary tests need the exact debt before choosing a bound. The fixture obtains it by
requesting the exercise under a cost bound of zero and decoding the debt out of production's own
`ExerciseRouter__ExerciseCostExceedsMaxInput` refusal. The refusal unwinds the swap, so the pool is
unchanged and the subsequent real request produces the same debt. A bound derived from a quote or an
arithmetic reconstruction would be a bound on a different number than the one production compares
against, and equality against the wrong number would prove nothing.

---

## Pinned Uniswap v4 Mechanics Confirmed

Read directly from the installed dependency at the pinned revisions rather than from memory:

- `BalanceDelta` — packed `int128` pair, `amount0()`/`amount1()` attached globally, sign convention
  negative = owed by the swap caller (`v4-core/src/types/BalanceDelta.sol`);
- `PoolManager.swap` accounts the resulting delta to `msg.sender`, which is the unlocking router
  (`v4-core/src/PoolManager.sol`);
- `sync(Currency)` records the currency and its current reserve balance;
- `settle()` is `onlyWhenUnlocked`, computes `paid = balanceOfSelf() - reservesBefore` and credits it
  to `msg.sender`, so an ERC-20 settlement is `sync` → transfer in → `settle`;
- `take(Currency, address to, uint256 amount)` is `onlyWhenUnlocked`, debits `amount` from
  `msg.sender`'s delta and transfers directly to `to`;
- `TransientStateLibrary.currencyDelta(manager, target, currency)` reads a participant's outstanding
  delta through `exttload`;
- `IERC20Minimal.transferFrom(address,address,uint256) returns (bool)`
  (`v4-core/src/interfaces/external/IERC20Minimal.sol`);
- the pinned fixture currencies perform exact transfers with no fee and no rebasing, satisfying
  RR-O2-22.

---

## Reachability Caveats Recorded

1. **Real-stack direction generality.** The canonical Standby fixture is `zeroForOne`, and the
   direction-sensitive part of R4 — which currency is spent, which is produced, and which delta side
   is the debt — is a pure derivation. It is verified in both directions by unit tests and across the
   full signed domain by fuzz. A real-stack `oneForZero` exercise would require a mirrored service
   fixture that does not exist in the repository; F8B's execution evidence carries the same caveat.
2. **Under/over settlement is unreachable by construction.** The settled amount is not a caller-supplied
   quantity: it is the derived debt, and production transfers exactly it. `ExerciseRouter__UnresolvedExerciseDelta`
   is the fail-closed guard that would catch either, and it is unreachable with exact-transfer
   currencies.
3. **`ExerciseRouter__InputTransferFailed` is unreachable with the fixture currencies**, which revert
   rather than returning `false`. Both failing payment conditions — insufficient balance and
   insufficient allowance — are exercised and unwind the whole exercise.
4. **Delivery failure after successful settlement is unreachable.** `take` of exactly the proven
   credit cannot fail against an exact-transfer currency; the Hook has already proven the credit is
   exactly `q`.

---

## Required Task Completion Report

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`;
- `docs/project-status.md`, `docs/implementation-plan.md` (§14.0, §15, §16, §17),
  `docs/uniswap-v4-realization.md` (§13–§16);
- `src/ExerciseRouter.sol`, `src/StandbyHook.sol`, `src/mocks/MockFixtureCurrency.sol`,
  `src/interfaces/IActorAwarePeriphery.sol`;
- `script/helpers/StandbyFixtureConfig.sol`;
- `test/harness/ExerciseDeltaClosureRouter.sol`, `test/harness/AdversarialExerciseRouter.sol`,
  `test/harness/StandbyHookHarness.sol`;
- `test/shared/BaseActorAwareStandbyTest.t.sol`, `test/shared/BaseCommitmentAdmissionTest.t.sol`,
  `test/shared/BaseAuthenticBackingTest.t.sol`, `test/shared/BaseExerciseAuthorizationTest.t.sol`,
  `test/shared/BaseUnbackedExerciseAuthorizationTest.t.sol`,
  `test/shared/BaseAdversarialExerciseTest.t.sol`, `test/shared/BaseDerivationTest.t.sol`;
- `test/integration/ProtectedExecution.t.sol`, `test/fuzz/ProtectedExecutionFuzz.t.sol`,
  `test/periphery/ProtectedExecutionPerimeter.t.sol`.

Pinned dependency:

- `v4-core/src/PoolManager.sol`, `v4-core/src/interfaces/IPoolManager.sol`,
  `v4-core/src/libraries/TransientStateLibrary.sol`, `v4-core/src/types/BalanceDelta.sol`,
  `v4-core/src/interfaces/external/IERC20Minimal.sol`;
- `lib/forge-std/src/Vm.sol`.

### Files Changed

Production:

- `src/ExerciseRouter.sol` — **modified.** Implements R4: the causal-context prerequisite, the
  authoritative settlement derivation, the `maxInput` comparison, exerciser-funded direct settlement,
  direct Beneficiary delivery, both delta-closure requirements, and the slice-completion barrier.
  `_executeAuthorizedExercise` now returns the executed `PoolKey`/`SwapParams` alongside the delta.

Test infrastructure:

- `test/harness/UnfinalizedExerciseRouter.sol` — **new.** The production router with the completion
  barrier lifted, plus two bare pass-throughs of production internals that no production path can
  present malformed input to.
- `test/harness/ExerciseDeltaClosureRouter.sol` — **modified.** Re-parented onto
  `UnfinalizedExerciseRouter`, adapted to the new R3 return shape, and its purpose restated: it is now
  what keeps F8B evidence isolated from the settlement and delivery production performs.
- `test/shared/BaseExerciseSettlementTest.t.sol` — **new.** The F8C fixture: production R4 router,
  funded and approving exerciser, the authoritative-debt probe, and the settlement state snapshot and
  assertions.
- `test/shared/BaseExerciseAuthorizationTest.t.sol` — **modified, comments only.** Two doc comments
  that described the pre-F8C world were brought up to date. No behavior, assertion, or fixture value
  changed.

Tests:

- `test/unit/ExerciseSettlementDerivation.t.sol` — **new** (11 tests).
- `test/integration/ExerciseSettlement.t.sol` — **new** (15 tests).
- `test/fuzz/ExerciseSettlementFuzz.t.sol` — **new** (3 tests).
- `test/periphery/ExerciseSettlementPerimeter.t.sol` — **new** (7 tests).

Documentation:

- `docs/prompts/session-13-log.md` — **new.** This file.

`docs/project-status.md` was not modified, as the session prompt requires.

### Requirements Implemented

R4 of the frozen ExerciseRouter decomposition (`implementation-plan.md` §14.0), realizing
`implementation-plan.md` §16.1–§16.9 and `uniswap-v4-realization.md` RR-O2-10 through RR-O2-17 and
RR-O2-19, plus the slice-boundary completion restriction of session-prompt §18. Finalization
(RR-O2-18, RR-O2-20, §17 of the implementation plan) is untouched.

### Tests Added or Changed

Added, by requirement:

| Test | Proves |
| --- | --- |
| `test_protectedDirection_spendsCurrency0AndProducesCurrency1` | G8C-1 currency identity, protected direction |
| `test_oppositeDirection_spendsCurrency1AndProducesCurrency0` | G8C-1 currency identity, `oneForZero` |
| `test_creditSignedInputSide_isRefused` | G8C-3 a credit is not a debt |
| `test_zeroInputSide_isRefused` | G8C-3 zero is not a debt |
| `test_debtOnTheWrongSide_isRefused` | G8C-3 the side is chosen by the operation, not by the values |
| `test_minimumSignedDebt_convertsExactly` | G8C-4 `type(int128).min` converts rather than wrapping |
| `test_smallestSignedDebt_isSettleable` | G8C-4 the refusal boundary is exactly at zero |
| `testFuzz_authoritativeDebt_isTheExecutedDirectionsInputSide` | G8C-1 … G8C-4 across the full signed domain and both directions |
| `test_absentContext_authorizesNoResolution` | G8C-14 no context authorizes no R4 |
| `test_authorizedButUnexecutedContext_authorizesNoResolution` | G8C-14 complete bindings without execution proof authorize no R4 |
| `test_inFlightContext_authorizesNoResolution` | G8C-14 an accepted proposal is not an execution |
| `test_undecidedContext_authorizesNoResolution` | G8C-14 an undecided authorization authorizes no R4 |
| `test_authorizedExercise_settlesExactlyAndDeliversDirectly` | G8C-8, G8C-9, G8C-12, G8C-13 on the real stack |
| `test_settlementAmount_isTheAuthoritativeDebtRatherThanTheRequest` | G8C-2 the debt is neither `q` nor `maxInput` |
| `test_costBoundEqualToTheDebt_isAccepted` | G8C-5 equality passes |
| `test_costBoundAboveTheDebt_isAccepted` | G8C-5 one unit above passes |
| `test_costBoundBelowTheDebt_unwindsTheWholeExercise` | G8C-5, G8C-18 one unit below reverts atomically |
| `test_costBound_leavesNoTraceInAuthoritativeState` | G8C-6 cost protection reaches no Hook state |
| `test_delivery_followsTheExercisedCommitmentsBeneficiary` | G8C-11 recipient is Hook-owned |
| `test_delivery_followsTheOtherCommitmentsBeneficiary` | G8C-11 recipient tracks the commitment, not a constant |
| `test_settledAndDeliveredExercise_fulfilsNothing` | G8C-16 no fulfillment consequence |
| `test_causalContext_remainsExecutedAfterSettlementAndDelivery` | G8C-17 no new lifecycle state |
| `test_secondExerciseAfterSettlement_isRejected` | G8C-15 exactly one delivery |
| `test_exerciserWithoutFunds_unwindsTheWholeExercise` | G8C-7, G8C-18 an unfunded exerciser is a failed exercise, not a router-funded one |
| `test_insufficientAllowance_unwindsTheWholeExercise` | G8C-18 partial permission is not partial settlement |
| `test_productionExercise_cannotCompleteWhileUnfinalized` | G8C-19 production is fail-closed |
| `test_productionExercise_isRefusedWhateverTheRequest` | G8C-19 the barrier is not about the request |
| `testFuzz_exercise_settlesTheExactDebtAndDeliversExactlyQ` | G8C-8, G8C-12, G8C-16 at every admissible quantity |
| `testFuzz_costBound_admitsExactlyTheAuthoritativeDebt` | G8C-5, G8C-10, G8C-18 the accepted and refused regions meet at equality |
| `test_directSettlementCallback_isRefused` / `...ForTheExerciseAuthority` | G8C-14 settlement is unreachable except through the PoolManager |
| `test_fundedRouter_neitherFundsNorReceives` | G8C-7, G8C-13 the coordinator is neither payer nor custodian |
| `test_fundedThirdParty_cannotBecomeThePayer` | G8C-7 no third-party payer substitution |
| `test_thirdPartyApproval_doesNotFundAnAuthorizedExercise` | G8C-7 the payer is the authenticated exerciser |
| `test_protectedOutput_movesOnlyFromThePoolManagerToTheBeneficiary` | G8C-12, G8C-13 delivery as a closed system |
| `test_resolvedExercise_cannotBeResolvedAgain` | G8C-15 no second settlement or delivery |

No existing test was changed, weakened, or removed. Two doc comments in
`test/shared/BaseExerciseAuthorizationTest.t.sol` were corrected because they described a world in
which no settlement existed.

### Commands Run

```bash
forge fmt
forge fmt --check
forge lint
forge build
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

### Results

- `forge fmt --check` — clean.
- `forge lint` — clean, no findings.
- `forge build` — successful.
- `forge test` — **502 passed, 0 failed, 0 skipped** across 54 suites (466 before this slice; 36
  added).
- `FOUNDRY_PROFILE=ci forge test` — **502 passed, 0 failed, 0 skipped**, at 10,000 fuzz runs.
- Contract sizes: `ExerciseRouter` 4,128 B runtime (20,448 B margin); `StandbyHook` unchanged at
  21,255 B.

### Gate Evidence

**Implemented and verified:** G8C-1, G8C-2, G8C-3, G8C-4, G8C-5, G8C-6, G8C-7, G8C-8, G8C-11,
G8C-12, G8C-13, G8C-14, G8C-15, G8C-16, G8C-17, G8C-19; G8C-18 for every reachable failure
(cost-bound breach, insufficient balance, insufficient allowance), each proven to leave no residue on
balances, PoolManager state, commitment facts, obligation, or causal context.

**Implemented, structurally sound, not directly exercised:** G8C-9's residual-input-delta guard and
G8C-10's under/over-settlement guard. The settled amount is the derived debt rather than a
caller-supplied quantity, so neither can be reached with exact-transfer currencies; the successful
commit is itself evidence that the exact debt closed the delta, since underpayment would leave a
negative delta and overpayment a positive one, and both are refused.

**Not attempted:** anything belonging to finalization.

### Known Limitations / Blockers

No blockers. The four reachability caveats above are recorded rather than worked around. No frozen
document was found to be contradictory, and no unauthorized state was introduced.

### Scope Check

Work stayed within F8C / R4. `StandbyHook.sol` was not modified. No Hook economic state was added, no
O1 or O3 semantics changed, no F5/F6/F7 derivation logic was touched, and no finalization behavior —
Remaining Entitlement reduction, obligation release, fulfillment marking, context consumption — was
implemented. `docs/project-status.md` was not edited.

### Proposed Gate Assessment

**PASS (proposed, advisory only).**

Every G8C condition has implementation and verification evidence, with the two guards noted above
unreachable by construction rather than unverified by omission. Both required profiles pass with no
failures, formatting and linting are clean, and the production path remains fail-closed pending
finalization.

### Recommended Next Step

F8D — O2 Causal Finalization / Remaining Entitlement Reduction. The smallest coherent next
responsibility is Hook-owned finalization that requires the matching `EXECUTED` context, re-derives
actual post-execution Supporting Capacity and the post-fulfillment obligation, reduces Remaining
Entitlement exactly once, and consumes the context — which is also exactly what makes the production
completion barrier introduced here pass. Not to be started without explicit authorization.

### Prompt Audit

All material follow-up instructions were recorded in this log. **One** material follow-up prompt was
issued: the post-review instruction to synchronize `docs/project-status.md` with the closed G8C
result, recorded as Prompt 1 above. It followed the implementation and gate review recorded here and
changed no implementation, test, or verification state.
