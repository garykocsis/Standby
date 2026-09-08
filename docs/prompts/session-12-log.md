# Session 12 — Material Prompt Log

Initiating prompt: `docs/prompts/session-12-f8b-o2-exact-output-execution.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — Correct stale F8A-era documentation about `maxInput` and the protected swap

**Instruction.** `docs/prompts/session-12-f8b-documentation-correction.md`, issued after independent
review of the completed F8B implementation. The review accepted F8B production behavior
substantively and identified one remaining issue before G8B closure: documentation written during
F8A that still states or implies **"no swap executes at this slice"**, which stopped being true when
F8B introduced the protected exact-output PoolManager execution. The prompt requires the corrected
wording to preserve the real boundary — the swap now executes and authoritative input debt therefore
exists, but deriving that debt, enforcing `actualInput <= maxInput`, and settling it remain F8C's —
so `maxInput` is inert through F8B because enforcement belongs to F8C, not because no swap occurs.
The correction is documentation-only: no production behavior, test behavior, assertion, interface,
storage, or fixture behavior may change, no F8C/F8D responsibility may be introduced, and
`docs/project-status.md` must not be updated.

**Consequence.** Four stale statements were corrected and one helper description was brought up to
date. No Solidity outside comments and NatSpec changed; `forge test` and
`FOUNDRY_PROFILE=ci forge test` both report the same 466 passing tests as before the correction.
The corrections are recorded under **Correction 1** at the end of this log.

### Prompt 2 — Synchronize `docs/project-status.md` with the reviewed F8B result

**Instruction.** Update **status only** in `docs/project-status.md` to reflect the independently
reviewed F8B result: F8B — O2 Exact-Output Execution / Execution Evidence **COMPLETE**, G8B **PASS**,
and F8C — Authoritative Settlement / Direct Beneficiary Delivery as the **next authorized
implementation slice / current blocker**. No implementation details, design commentary, test
summaries, gate reasoning, retrospective observations, reachability qualifications, or other new
descriptive content may be added to that document; only the minimum edits needed to bring existing
status fields, roadmap/ladder entries, current-blocker/next-action fields, and now-stale status
statements into consistency. This session log is to record the instruction and the resulting
status-only action as audit chronology, without changing or expanding its normative content,
implementation report, correction record, or previously recorded evidence. No other file may be
modified.

**Consequence.** `docs/project-status.md` was updated in place, status-only: the header slice, last
closed gate and status ladder; the §2 next-authorized-slice, last-closed-gate and gate-closure
statements; the §3 ladder rows for F8B and F8C; the §7 line that still said O2 execution was
unimplemented; the §10 current blocker and its carried-forward limitation wording; the §18 next
action; and the §19 handoff validated-state, current-gate, next-blocker and next-step entries. No new
descriptive content was introduced, no other file was changed, and no implementation, test, or
verification state changed.

---

## Implementation Chronology

1. Read `CLAUDE.md`, `docs/project-status.md`, the Session 12 prompt,
   `docs/implementation-plan.md` §14 (F8A), §15 (F8B) and §16 (F8C, for the boundary), and
   `docs/uniswap-v4-realization.md` §13 (RR-O2-6 … RR-O2-10), §14, §15 and §16.
2. Inspected the pinned Uniswap v4 dependency directly rather than relying on memory:
   - `lib/v4-hooks-public/lib/v4-core/src/types/PoolOperation.sol` — `SwapParams.amountSpecified`
     is documented as "the desired input amount if negative (exactIn), or the desired output
     amount if positive (exactOut)". The prompt's expected sign convention is confirmed against
     the installed source.
   - `lib/v4-hooks-public/lib/v4-core/src/types/BalanceDelta.sol` — `amount0()`/`amount1()` are the
     packed `int128` halves.
   - `lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol` `swap` — the `BalanceDelta` handed to
     `afterSwap` is the swap delta accounted to `msg.sender` of `PoolManager.swap`, so a positive
     currency amount is owed *to* the swap caller and a negative amount is owed *by* it.
   - `lib/v4-hooks-public/lib/v4-core/src/libraries/Pool.sol` `swap` — for an exact-output swap the
     specified side of the delta is `amountSpecified - amountSpecifiedRemaining`, i.e. the amount
     actually produced, which is strictly less than `q` when the price limit is reached first.
     Partial exact-output execution is therefore an ordinary success for Uniswap and must be
     rejected by Standby.
   - `lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol` — `beforeSwap`/`afterSwap` are
     handed `msg.sender` of `PoolManager.swap` as `sender`, and the `params` given to `afterSwap`
     are the original caller-proposed `SwapParams`.
   - `lib/v4-hooks-public/src/base/BaseHook.sol` — `_beforeSwap` and `_afterSwap` are non-view
     `virtual`, so the causal-state writes this slice needs require no base change.
3. Inspected the completed F8A implementation and its evidence: `src/StandbyHook.sol`,
   `src/ExerciseRouter.sol`, `test/shared/BaseExerciseAuthorizationTest.t.sol`,
   `test/shared/BaseUnbackedExerciseAuthorizationTest.t.sol`, `test/harness/StandbyHookHarness.sol`,
   and the four F8A suites.

---

## Implementation Decisions

### The production ExerciseRouter acquires R3, and F8B therefore has no completable production path

`implementation-plan.md` §14.0 decomposes the router into R1–R5, and the F8 slices map onto it
one-for-one: R1+R2 is F8A, **R3 — exactly one protected exact-output PoolManager execution — is
F8B**, R4 is F8C, R5 is F8D. Session-12 prompt §16 and G8B-12 require adversarial evidence about
what the *production* ExerciseRouter does when the protected swap fails, which is only meaningful
if the production router is the contract issuing that swap. R3 is therefore implemented here.

The direct consequence is that no production O2 transaction can complete at F8B. A real
PoolManager swap opens currency deltas, and `PoolManager.unlock` reverts with `CurrencyNotSettled`
unless they are closed; closing them is F8C's input settlement and Beneficiary delivery, which this
slice must not implement. The prompt anticipates exactly this in §21 and permits narrowly scoped
**test-only mechanical delta closure** so that an otherwise valid real-PoolManager execution can
commit and be examined.

That closure is `test/harness/ExerciseDeltaClosureRouter.sol`: a subclass of the production
`ExerciseRouter` that overrides `unlockCallback` alone, runs the complete production execution path
through it, and then closes whatever deltas the swap left from its own pre-funded balance. It
assigns no payer, enforces no `maxInput`, and delivers nothing to the Beneficiary — the protected
output is parked on the closure contract precisely so that no test can mistake it for delivery.

### Consequence for the F8A suites

Because a successful `exercise(...)` now continues into execution, the F8A fixture is activated
with the delta-closure router and the successful F8A paths end at `EXECUTED` rather than
`AUTHORIZED`. Every F8A authorization predicate is still proven by the same tests against the same
production `authorizeExercise`, and every F8A rejection test is unchanged, because each rejection
still occurs inside `authorizeExercise` before any unlock. Two F8A tests state facts that F8B
legitimately supersedes and are recorded under **F8A test adaptations** below.

### One reconstruction of the admitted protected execution, consumed by everything

F8A already reconstructed the canonical protected execution inline inside
`_prospectiveExerciseCapacity` in order to decide backing. F8B needs the same object in three more
places: the `beforeSwap` classifier, the `afterSwap` revalidation, and the proposal the router hands
the PoolManager. Restating it would have created up to four descriptions of what a Standby exercise
executes, which is exactly the duplication the authoritative-derivation rule forbids, so the
reconstruction was extracted to `_canonicalProtectedExecution(q)` and every consumer resolves
through it. The authorization decision and the execution requirement are therefore the same object
rather than two things that have to be kept in agreement.

The router obtains it through the new external view `authorizedProtectedExecution()`, which
describes the execution the *currently AUTHORIZED* context admits and reverts otherwise. That read
grants nothing: the Hook revalidates the operation on the authoritative callback path, so a router
that ignores what it read is refused exactly as one that never read it. The alternative — a router
composing direction, exact-output mode and `P_Q` itself — would have been a second production
statement of the qualification boundary, which §8.7 of the session prompt prohibits.

### Classification is one equality, not four policies

`_requireAuthorizedProtectedExecution` compares the proposed `SwapParams` against that single
reconstruction. Protected direction, exact-output mode, exact `q`, and the qualification price limit
are therefore not four independent checks that could drift apart; they are the one operation the
service defines. Callback sender identity is a separate, explicitly necessary-but-insufficient
conjunct, and the pool is established by `_requireConfiguredServicePool` on every path.

The pool is deliberately *not* re-compared against `context.serviceId`. The service is one-shot and
immutable and the authorization stamped the context with `_serviceId()`, so their equality is a
theorem rather than an assumption, and adding the comparison would have been duplicated checking.

### No extra causal field beyond `EXECUTING`

The minimum binding the prompt describes was sufficient. `beforeSwap` and `afterSwap` for one swap
are ordered and authenticated by the immutable PoolManager inside a single call frame nothing else
can enter, the Hook already holds every fact both callbacks must agree with, and `EXECUTING` records
that a proposal was accepted. No execution nonce, hash, router success flag, or swap ledger was
required, and no snapshot of any economic quantity was added.

### F8A test adaptations

Two F8A tests asserted facts that F8B changes, and both were rewritten rather than weakened:

- `test_successfulAuthorization_leavesEveryAuthoritativeFactUntouched` asserted that a successful
  request changes *no* authoritative state, including pool state. A request now performs the
  protected execution, so the pool legitimately moves. It became
  `test_completedRequest_fulfilsNothingAndDeliversNothing`, which asserts the fulfillment half that
  is still true and is the half G8A actually required: the commitment record, Remaining Entitlement,
  the derived obligation, the bounded reference, the identity counter, and the Beneficiary's and the
  Hook's protected-output balances all unchanged.
- `test_authorizedContext_doesNotAdvanceBeyondAuthorized` asserted that an ordinary swap proceeds
  normally while an authorization is live, because `AUTHORIZED -> EXECUTED` did not exist. F8B
  requires the opposite: while an O2 causal context is unresolved the ordinary path is closed. The
  test was removed and replaced by the stronger
  `ProtectedExecutionTest.test_ordinarySwap_whileAnO2ContextIsUnresolved_isRejected`.

One F8A fuzz property gained a branch. `ExerciseBackingFuzz` explores harness-written obligations the
pool never backed, and inside that region an authorization can be admitted for a quantity the pool
cannot deliver before `P_Q`. Those runs now execute and are refused by the execution evidence rather
than by the backing comparison, which the test asserts explicitly — and reaching that refusal is
itself evidence that the authorization was admitted. It also became the fuzzed real-PoolManager
evidence for partial-output rejection.

### Direction generality

The canonical fixture is protected `zeroForOne`, so a hard-coded direction would have passed every
other suite. `ProtectedExecutionDirectionTest` activates a real second service whose protected
direction is `oneForZero` and proves both direction-dependent mechanics mirror: the admitted
operation is the `oneForZero` exact-output swap bounded by a `P_Q` above the current price, and the
protected output is read from currency0. No liquidity or swap is needed, because neither mechanic
consults them.

---

## Required Task Completion Report

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/implementation-plan.md` §14 (F8A), §15 (F8B), §16 (F8C boundary)
- `docs/uniswap-v4-realization.md` §13 (RR-O2-6 … RR-O2-10), §14, §15, §16
- `docs/prompts/session-12-f8b-o2-exact-output-execution.md`, `docs/prompts/session-11-log.md`
- `src/StandbyHook.sol`, `src/ExerciseRouter.sol`, `src/demo/ActorAwareTestRouter.sol`
- `script/helpers/StandbyFixtureConfig.sol`
- `test/shared/BaseActorAwareStandbyTest.t.sol`, `BaseCommitmentAdmissionTest.t.sol`,
  `BaseAuthenticBackingTest.t.sol`, `BaseExerciseAuthorizationTest.t.sol`,
  `BaseUnbackedExerciseAuthorizationTest.t.sol`, `BaseDerivationTest.t.sol`,
  `ReferenceCalculations.sol`
- `test/harness/StandbyHookHarness.sol`, `StandbyDerivationHarness.sol`
- the four F8A suites and `test/integration/ProspectiveStateEquivalence.t.sol`

Pinned dependency:

- `lib/v4-hooks-public/lib/v4-core/src/types/PoolOperation.sol` (exact-output sign convention)
- `lib/v4-hooks-public/lib/v4-core/src/types/BalanceDelta.sol`
- `lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol` (`swap`, `_swap`, `unlock`)
- `lib/v4-hooks-public/lib/v4-core/src/libraries/Pool.sol` (`swap` delta construction)
- `lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol` (`beforeSwap`, `afterSwap`)
- `lib/v4-hooks-public/src/base/BaseHook.sol`, `lib/v4-hooks-public/lib/v4-periphery/src/base/ImmutableState.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/SafeCast.sol`

### Files Changed

Production:

- `src/StandbyHook.sol` — added `EXECUTING`/`EXECUTED` to the transaction-scoped causal lifecycle;
  added five F8B rejection conditions; split `beforeSwap` into the ordinary-O3 rule and the O2
  execution classifier; gave `afterSwap` the O2 execution-evidence branch; added
  `_beginProtectedExecution`, `_recordProtectedExecution`, `_requireAuthorizedProtectedExecution`,
  `_actualProtectedOutput`, `_canonicalProtectedExecution`, and the `authorizedProtectedExecution()`
  read surface; re-expressed `_prospectiveExerciseCapacity` through the one reconstruction.
- `src/ExerciseRouter.sol` — added R3: the router now unlocks the PoolManager and performs exactly
  one protected execution, asked of the Hook rather than composed here, with no failure branch.

Test support:

- `test/harness/ExerciseDeltaClosureRouter.sol` (new) — production router plus test-only mechanical
  delta closure.
- `test/harness/AdversarialExerciseRouter.sol` (new) — hostile configured O2 coordinator.
- `test/harness/StandbyHookHarness.sol` — three F8B pass-throughs: write a causal context, run the
  classifier, run the evidence mechanic.
- `test/shared/BaseExerciseAuthorizationTest.t.sol` — configures the delta-closure router, funds its
  closure balance, adds the `_expectedContextRouter` seam and the `_assertExercisedContext`
  assertion.
- `test/shared/BaseAdversarialExerciseTest.t.sol` (new) — same fixture with a hostile router.

Tests:

- `test/integration/ProtectedExecution.t.sol` (new)
- `test/unit/ProtectedExecutionEvidence.t.sol` (new)
- `test/fuzz/ProtectedExecutionFuzz.t.sol` (new)
- `test/periphery/ProtectedExecutionPerimeter.t.sol` (new)
- `test/integration/ExerciseAuthorization.t.sol`, `test/unit/ExerciseAuthorization.t.sol`,
  `test/fuzz/ExerciseAuthorizationFuzz.t.sol`, `test/fuzz/ExerciseBackingFuzz.t.sol`,
  `test/periphery/ExerciseAuthorizationPerimeter.t.sol` — F8A adaptations described above.

Documentation:

- `docs/prompts/session-12-log.md` (new, this file).

### Requirements Implemented

F8B — O2 execution classification and authoritative execution evidence: `implementation-plan.md`
§15.1–§15.5; `uniswap-v4-realization.md` RR-O2-7, RR-O2-8, RR-O2-9, RR-O2-4, RR-O2-5, §16.3; and
§§3–20 of the session prompt. Router R3 of `implementation-plan.md` §14.0.

### Tests Added or Changed

See **Files Changed**. Coverage by gate item is recorded under **Gate Evidence** below.

### Commands Run

```
forge fmt --check
forge lint
forge build
forge test --match-path 'test/**/Exercise*'
forge test --match-path test/integration/ProtectedExecution.t.sol
forge test --match-path test/unit/ProtectedExecutionEvidence.t.sol
forge test --match-path test/fuzz/ProtectedExecutionFuzz.t.sol
forge test --match-path test/periphery/ProtectedExecutionPerimeter.t.sol
forge test
FOUNDRY_PROFILE=ci forge test
```

### Results

`forge fmt --check` clean. `forge lint` reports nothing. `forge build` succeeds.
`forge test`: 466 tests passed, 0 failed, 0 skipped, across 47 suites.
`FOUNDRY_PROFILE=ci forge test`: 466 tests passed, 0 failed, 0 skipped (fuzz runs 10,000).

### Gate Evidence

Implemented and verified: G8B-1 through G8B-11, G8B-13 through G8B-19.
Verified with a documented reachability caveat: G8B-12.
Not evaluated: none of G8B; the stateful invariant campaign (GI) remains out of scope.

### Known Limitations / Blockers

1. No production O2 transaction can complete at F8B. The protected execution opens PoolManager
   deltas that only F8C may close, so every production exercise reverts at the unlock boundary.
   Positive execution evidence therefore comes through the test-only delta-closure router.
2. Genuinely nested reentry (`EXECUTING -> second beforeSwap`) is unreachable through the real
   PoolManager, because the accepted swap's `beforeSwap` and `afterSwap` occur inside one call frame
   nothing else can enter. It is verified at unit level against the production predicate instead.
3. Partial actual output is likewise unreachable from a backed state, and is verified through the
   real PoolManager from a harness-written unbacked remainder.

### Scope Check

Within F8B. No settlement, `maxInput` enforcement, Beneficiary delivery, Remaining reduction,
obligation reduction, fulfillment, or finalization was implemented, and no persistent state was
added. `docs/project-status.md` was deliberately not modified.

### Proposed Gate Assessment

PASS (proposed only). Every G8B condition has passing implementation and verification evidence, with
the reachability caveats recorded above. G8B closure is ChatGPT's to determine.

### Recommended Next Step

F8C — authoritative input settlement, `maxInput` enforcement against the actual PoolManager debt,
and direct Beneficiary delivery of exactly `q`. Not authorized by this session.

### Prompt Audit

All material follow-up instructions were recorded. **0** material follow-up prompts were issued in
this session; the initiating prompt was executed as written.

---

## Correction 1 — Stale F8A-era documentation

Issued by `docs/prompts/session-12-f8b-documentation-correction.md` after independent review of the
F8B implementation. Documentation-only.

### What was stale

F8A's ExerciseRouter executed no swap, so the `maxInput` field could be described as inert *because
there was no input debt to bound*. F8B implements R3: the protected exact-output swap now executes,
and it produces authoritative PoolManager input debt. The reason `maxInput` is still inert therefore
changed, and any wording resting on the old reason became false.

The corrected boundary is:

```text
F8B: the protected exact-output swap executes
     authoritative PoolManager execution evidence is established
     actual input debt therefore exists

F8C: derive the authoritative actual input debt
     enforce actualInput <= maxInput
     settle that debt
     deliver protected output directly to the authoritative Beneficiary
```

### Statements corrected

1. `src/ExerciseRouter.sol` — `exercise(...)` NatSpec. Was: "…and no swap executes here, so there is
   no debt to bound and nothing to enforce it against yet… it is the F8A boundary made structural".
   Now: the debt exists because the protected swap executes here, and deriving it, requiring
   `actualInput <= maxInput`, and settling it are one responsibility that belongs to F8C — so the
   bound is not enforced here, and the parameter stays unnamed as the settlement boundary made
   structural.
2. `test/fuzz/ExerciseAuthorizationFuzz.t.sol` — `testFuzz_maxInput_changesNoAuthorizationOutcome`
   NatSpec. Was: "…and no swap executes at this slice". Now: the swap executes and the debt exists,
   but enforcing the bound belongs to F8C together with settling it, so nothing consumes it yet. The
   property's claim was widened from "no F8A outcome" to "no outcome", which is what the test
   actually asserts now that a permissible request also executes.
3. `test/periphery/ExerciseAuthorizationPerimeter.t.sol` — `test_maxInputOfZero_authorizesIdentically`
   NatSpec. Was: "…there is no debt at this slice". Now: the bound is measured against the input debt
   the executed swap produces, and enforcing it belongs to F8C together with settling that debt.
4. `test/shared/BaseExerciseAuthorizationTest.t.sol` — `UNCONSTRAINED_MAX_INPUT`. Was: "F8A neither
   reads nor forwards this field". Now: nothing implemented so far reads or forwards it, and
   enforcement against the executed swap's input debt belongs to F8C.

One further description was brought up to date rather than corrected for falsehood:
`_authorizeAs` in `test/shared/BaseExerciseAuthorizationTest.t.sol` described itself as requesting
authorization; it now states that the request is the whole production coordination — authorization
followed by the one protected execution that authorization admits — so a refused request never
reaches an execution and a passing one leaves execution evidence rather than a standing
authorization.

### Statements deliberately left unchanged

- `StandbyHook.authorizeExercise` NatSpec ("It executes no swap, moves no price, settles no
  input…"). Its subject is the authorization transition itself, which genuinely executes no swap;
  the swap is performed by the router's unlock afterwards.
- `StandbyHook` contract NatSpec ("Authorization is not exercise. It executes no swap…"), for the
  same reason, and because the following paragraph already states what execution evidence is and is
  not.
- `ExerciseRouter` contract NatSpec ("Because they are absent, no exercise completes at this
  slice"). This is an F8B statement written this session and remains true: the unsettled deltas
  unwind every production exercise.
- `test/integration/O3AuthenticBackingEnforcement.t.sol` ("Fulfillment does not exist yet"), which
  remains true — F8B attributes no fulfillment.

### Verification

```
forge fmt --check     clean
forge lint            no findings
forge build           successful
forge test            466 passed, 0 failed, 0 skipped
FOUNDRY_PROFILE=ci forge test   466 passed, 0 failed, 0 skipped
```

Behaviorally identical to the reviewed F8B implementation: no production logic, test logic,
assertion, interface, storage layout, or fixture behavior changed. `docs/project-status.md` was not
modified.
