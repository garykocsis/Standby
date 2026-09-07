# Session 11 — Material Prompt Log

Initiating prompt: `docs/prompts/session-11-f8a-o2-authorization.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — Do not synchronize `docs/project-status.md`

**Instruction.** "don't update project.status at this time" — issued when the implementation was
otherwise complete and a minimal `docs/project-status.md` synchronization recording F8A as
AUTHORIZED / IN PROGRESS with G8A open had been proposed.

**Consequence.** No edit was made to `docs/project-status.md`. That document therefore still
records F8A as **NEXT AUTHORIZED / NOT STARTED**, which is stale with respect to this session's
implementation. Nothing in the implementation depends on it, and no gate state was recorded
anywhere. The synchronization remains available as a separate, explicitly instructed action.

> **Resolved by material prompt 3.** That instruction arrived and `docs/project-status.md` has been
> synchronized to the independently reviewed result: F8A COMPLETE, G8A CLOSED / PASS, F8B next.

### Prompt 2 — Restore `maxInput` to the F8A ExerciseRouter request surface

**Instruction.** `docs/prompts/session-11-f8a-maxinput-correction.md`, issued after independent
ChatGPT review of the completed F8A implementation. The review found the substantive F8A
authorization semantics and all fifteen G8A conditions conforming, and recorded **G8A as
CONDITIONAL PASS / NOT YET CLOSED** pending one bounded implementation-plan fidelity correction:
`ExerciseRouter.exercise` must carry the frozen three-field request surface
`exercise(uint256 commitmentId, uint256 q, uint256 maxInput)`. The omission was identified as a
request-surface fidelity issue, not an authorization-semantics failure. The prompt authorizes only
that correction and its directly necessary verification, requires `maxInput` to remain
semantically inert in F8A — not validated, compared, forwarded to the Hook, bound into the causal
context, or persisted — and prohibits any F8B/F8C/F8D responsibility.

**Consequence.** The parameter was restored and the session's earlier omission decision (recorded
below under **`maxInput` is not part of the F8A request surface**, now superseded) was reversed.
The correction is recorded in full under **Correction 1** at the end of this log. No authorization
predicate, causal-context field, or Hook signature changed.

---

## Implementation Chronology

1. Read `CLAUDE.md`, `docs/project-status.md`, the Session 11 prompt,
   `docs/implementation-plan.md` §14 (F8A) and §15 (F8B, for the boundary),
   `docs/uniswap-v4-realization.md` §2.2, §13, §14, §15, §16 and §20, and the
   `docs/spec.md` / `docs/state-machine.md` sections on Validity and Exercisability.
2. Inspected the existing production seam in full before changing anything:
   `src/StandbyHook.sol`, `src/demo/ActorAwareTestRouter.sol`,
   `src/interfaces/IActorAwarePeriphery.sol`, `src/interfaces/IEligibilityRegistry.sol`,
   `src/libraries/StandbyMath.sol`, `script/DeployStandbyHook.s.sol`, and the shared
   test fixtures.
3. Established the transaction-scoped context decision empirically before writing it
   (see **Transaction-scoped context** below).
4. Implemented the F8A production surface: `src/ExerciseRouter.sol` and the
   `authorizeExercise` transition, causal context, and read surface in `src/StandbyHook.sol`.
5. Added the F8A fixtures and the periphery, integration, unit, and fuzz suites.
6. Ran the narrow F8A suites, then the full suite under the default and `ci` profiles.
7. Confirmed the fuzz properties genuinely reach the decision boundaries by temporary mutation
   of the production predicates (see **Mutation checks** below). Every mutation was reverted and
   the reverted file was confirmed byte-identical to its pre-mutation copy before the recorded
   results were produced.

---

## Substantive Implementation Decisions

### Transaction-scoped context

Realized in EIP-1153 transient storage, which the validated toolchain baseline already supports
(Solidity `0.8.26`, Cancun EVM, and the existing `ActorAwareTestRouter` precedent). No persistent
O2 lifecycle state was introduced.

Two properties of transient storage are load-bearing rather than incidental: the context cannot
outlive its transaction, so an authorization can never be replayed in a later one; and a revert
discards the writes, so a failed authorization leaves nothing usable behind with no unwinding
code to get wrong.

Foundry's transaction boundary was verified empirically before it was relied on as evidence: a
throwaway probe confirmed that transient storage written during `setUp()` reads back as zero in
the test body, so `setUp()` and the test body are distinct transactions. The probe was deleted;
the property it established is what
`ExerciseAuthorizationTransactionScopeTest` depends on.

### Causal-context contents

The context binds exactly the frozen minimum of `uniswap-v4-realization.md` §16 — state,
serviceId, commitmentId, authenticated ExerciseRouter, authenticated exerciser, authoritative
Beneficiary, `q` — and nothing else. No derived economic quantity is bound: no `S`, no `S'`, no
`O`, no Remaining Entitlement, no validity, exercisability or eligibility flag.

"Protected execution identity" is not a separate stored field. It is reconstructible without
duplication: the bound `serviceId` fixes the pool, the protected direction, and the qualification
boundary `P_Q` through the immutable service basis, and `q` fixes the exact output of the single
protected exact-output swap the context admits.

### Lifecycle enum and the in-flight marker

`ExerciseAuthorizationState` declares `EMPTY`, `AUTHORIZING`, `AUTHORIZED` and deliberately
declares no `EXECUTED`: F8A owns only `EMPTY -> AUTHORIZED`, and declaring the later position
would let something claim a transition no code can make.

`AUTHORIZING` is not a causal lifecycle position. It is the in-flight marker of one authorization
attempt, claimed before the authorization reads anything outside the Hook and replaced by
`AUTHORIZED` only on success. It is unobservable from any successful call.

### F8A economic-reentrancy finding

The prompt (§11) required determining whether the F8A call topology permits an overlapping valid
authorization to arise during an external interaction made before the context is written.

Finding: it does not. Every external interaction production authorization performs before writing
its result is a static call —

- `IActorAwarePeriphery.msgSender()` is declared `view`;
- `IEligibilityRegistry.canReceiveProtectedService(address)` is declared `view`;
- the prospective derivation's PoolManager reads go through `StateLibrary`, which is `view`.

so no callee can write state, and in particular none can re-enter `authorizeExercise` and complete
a second authorization inside the first.

The single-slot claim is nevertheless made before those reads rather than after them, because the
restriction has to hold structurally rather than by inspection of what the current callees happen
to declare. The cost is one transient word and one comparison; the benefit is that the property no
longer depends on a `view` modifier remaining on a configured dependency's interface.

The consequence for verification is that the in-flight guard cannot be exercised through any
production path, so it is verified in the unit suite through a harness pass-through that holds the
claim open across a call.

### `maxInput` is not part of the F8A request surface — SUPERSEDED by material prompt 2

> **Superseded.** Independent review found this reading wrong: `implementation-plan.md` §14.3
> places `maxInput` on the F8A request surface already, so omitting it was a fidelity defect
> rather than restraint. The parameter was restored under material prompt 2; see **Correction 1**.
> The reasoning below is retained as the record of what was decided and why it was corrected.

`implementation-plan.md` §14.3 gives the eventual conceptual request as
`exercise(commitmentId, q, maxInput)`. The F8A `ExerciseRouter.exercise` takes
`(commitmentId, q)` only.

`maxInput` is exercise-local cost protection derived and enforced against authoritative
PoolManager debt after the exact-output swap (RR-O2-12), and F8A implements neither the swap nor
the settlement. The prompt (§5) states that `maxInput` is not an F8A economic authorization fact
and that actual `maxInput` enforcement is out of scope. Accepting a parameter that nothing can
honour, and that must not influence any F8A decision, would be speculative request surface, so it
is deferred to the settlement slice that owns it. This is implementation discretion and is
recorded here for review.

### Prospective backing predicate and its unreachable failing side

Authorization requires `S' >= O - q`, with `S'` derived by the existing F5 prospective derivation
applied to the canonical protected exact-output execution of exactly `q` bounded by `P_Q`
(RR-O2-7, RR-O2-8), and `O` by the existing authoritative aggregate derivation. Equality passes.
Neither `O` nor Remaining Entitlement is reduced.

`O - q` uses checked subtraction deliberately. A commitment that reaches the comparison is valid
with positive Remaining Entitlement, so it is not permanently non-binding, so the bounded index
cannot have reclaimed its reference and its full remainder is inside the aggregate:
`q <= Remaining <= O` holds structurally. Clamping the difference at zero would weaken the
requirement into one that always passes; failing closed on the arithmetic is the correct outcome
if that reasoning ever ceases to hold.

Finding worth recording for review: inside the canonical single-interval geometry an exact-output
exercise of `q` leaves `S - q`, and a complete successful exercise leaves `O - q`, so
`S' >= O - q` reduces to `S >= O` — the invariant O1 and O3 already maintain on every
authoritative transition. **No sequence of production transitions can reach a state in which the
F8A backing comparison fails.** This is the protocol working, not a gap; the check remains a
required predicate and is real defence in depth. Its failing side is therefore verified in the
unit and fuzz suites against harness-created unbacked state, which is precisely what harness
isolation exists for. Both passing sides — strict sufficiency and exact equality — are verified on
production-reachable state, the equality case by first drawing Supporting Capacity down to exactly
the canonical obligation with an ordinary protected swap.

A related consequence, already anticipated by the frozen design: when the obligation exceeds
capacity and `q` equals the whole remainder, the exercise truncates at `P_Q` with `S' = 0` against
`O - q = 0` and is authorized even though it cannot deliver exactly `q`. RR-O2-9 places that
outcome in the execution stage — an authorized O2 that cannot produce exact `q` before `P_Q` is a
realization-derivation failure and reverts the complete O2 — so nothing about it belongs to F8A.
The state it requires is unreachable in production in any case.

### Derivation reuse rather than duplication

`_prospectiveSwapState` and `_beginSwapDerivation` now take `SwapParams memory` rather than
`calldata`. This is a data-location change only; no F5 semantics were altered. It exists so that
the reconstructed canonical protected execution and a forwarded proposed swap resolve through the
same single derivation, rather than F8A acquiring a second one.

### No F8A event

No event is emitted on authorization. An authorization is transaction-scoped and is not an
economically final fact; emitting one would present a capability as though an exercise had
occurred. The observational surface is the Hook-owned context read, which reports what the Hook
decided and confers nothing.

### Shared-fixture hook points

`BaseActorAwareStandbyTest` gained two overridable internal functions with unchanged default
behaviour — `_deployServiceHook()` and `_resolveExerciseRouter()` — so that the F8A fixtures can
activate the service with a real `ExerciseRouter`, and the harness fixture can stand a
`StandbyHookHarness` in the production Hook's place without duplicating the fixture. Every
pre-existing suite is unaffected: the default resolution still produces the same
`makeAddr("exerciseRouter")` address and the same canonical deployment.

---

## Mutation Checks

Each mutation was applied to the production predicate, the relevant suite run, and the file then
restored and confirmed byte-identical:

| Mutation | Result |
| --- | --- |
| `prospectiveCapacity < prospectiveObligation` → `<=` (refuse at equality) | `ExerciseBackingFuzz` FAILS at `S' = O - q = 79,999,999,997` |
| `prospectiveCapacity < prospectiveObligation` → `+ 1 <` (accept one unit short) | `ExerciseBackingFuzz` FAILS ("next call did not revert as expected") |
| `_q > remainingEntitlement` → `>=` (exclude the full remainder) | `ExerciseAuthorizationFuzz` FAILS at `q == Remaining` |
| drop `_q == 0` (accept a zero quantity) | `ExerciseAuthorizationFuzz` FAILS at `q == 0` |

---

## Required Task Completion Report

### Files Inspected

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`, `docs/implementation-plan.md` (§14, §15)
- `docs/uniswap-v4-realization.md` (§2, §13, §14, §15, §16, §20)
- `docs/spec.md`, `docs/state-machine.md` (Validity / Exercisability sections)
- `docs/prompts/session-11-f8a-o2-authorization.md`, `docs/prompts/session-10-log.md`
- `src/StandbyHook.sol`, `src/demo/ActorAwareTestRouter.sol`,
  `src/interfaces/IActorAwarePeriphery.sol`, `src/interfaces/IEligibilityRegistry.sol`,
  `src/libraries/StandbyMath.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/StandbyFixtureConfig.sol`
- `test/shared/BaseActorAwareStandbyTest.t.sol`, `test/shared/BaseCommitmentAdmissionTest.t.sol`,
  `test/shared/BaseAuthenticBackingTest.t.sol`, `test/shared/BaseCommitmentStorageTest.t.sol`
- `test/harness/StandbyHookHarness.sol`, `test/harness/LiquidityPermissiveStandbyHookHarness.sol`
- `test/periphery/ActorAttribution.t.sol`, `test/integration/O3AuthenticBackingEnforcement.t.sol`,
  `test/fuzz/O3AuthenticBackingFuzz.t.sol`
- `foundry.toml`

### Files Changed

**Created**

- `src/ExerciseRouter.sol` — the designated O2 coordinator, implementing only R1 request intake /
  originator attribution and R2 Hook authorization.
- `test/shared/BaseExerciseAuthorizationTest.t.sol` — the F8A real-path fixture: the F6B/F7
  fixture activated with a real `ExerciseRouter`, plus an identical unconfigured one and the
  causal-context assertions.
- `test/shared/BaseUnbackedExerciseAuthorizationTest.t.sol` — the same fixture with a
  `StandbyHookHarness` standing in for the production Hook, for the two predicates whose failing
  side production cannot reach.
- `test/periphery/ExerciseAuthorizationPerimeter.t.sol` — perimeter and attribution evidence.
- `test/integration/ExerciseAuthorization.t.sol` — the main F8A evidence, plus a second contract
  for the cross-transaction claim.
- `test/unit/ExerciseAuthorization.t.sol` — backing rejection, service binding, in-flight guard.
- `test/fuzz/ExerciseAuthorizationFuzz.t.sol` — extent and authority boundaries.
- `test/fuzz/ExerciseBackingFuzz.t.sol` — the prospective backing decision boundary.
- `docs/prompts/session-11-log.md` — this record.

**Modified**

- `src/StandbyHook.sol` — added the O2 causal-context type declarations, the transient slot
  layout, six errors, the `authorizeExercise` transition, the `exerciseAuthorization()` read
  surface, and the authorization internals; changed `_prospectiveSwapState` /
  `_beginSwapDerivation` to `memory` parameters; updated the contract-level documentation.
- `test/harness/StandbyHookHarness.sol` — added the `beginExerciseAuthorization()` pass-through
  and updated the harness documentation.
- `test/shared/BaseActorAwareStandbyTest.t.sol` — added the `_deployServiceHook()` and
  `_resolveExerciseRouter()` hook points with unchanged default behaviour.

### Requirements Implemented

F8A §6.1–§6.12 authorization predicates; §7 Hook-owned transaction-scoped causal context; §8
`EMPTY -> AUTHORIZED` only; §9 transaction-scoped realization; §10 replay and substitution
prevention; §11 economic-reentrancy restriction. Upstream: RR-O2-4, RR-O2-5, RR-O2-6, RR-O2-7,
RR-O2-8, RR-O2-10, RR-PATH-3; `implementation-plan.md` §14.0 R1/R2, §14.1–§14.4.

### Tests Added or Changed

Periphery (`ExerciseAuthorizationPerimeterTest`, 11 tests) — direct caller, unconfigured router,
ordinary-transition perimeters, originator recovery, wrong originator, direct-caller-not-tx.origin,
forged attribution, router identity never satisfying commitment authority, attribution failing
closed with no request in flight, no exerciser exposed outside a request, exerciser context
cleared afterwards.

Integration (`ExerciseAuthorizationTest`, 20 tests) — exact causal bindings; authorization changes
no authoritative fact; the context does not advance beyond AUTHORIZED; nonexistent commitment;
commitment substitution; the four temporal boundaries plus post-expiry release with Remaining
intact; Beneficiary ineligibility and restoration; the four extent cases; strict and exact
prospective backing; second/replacement authorization refused; every kind of failed authorization
leaving no usable context.

Integration (`ExerciseAuthorizationTransactionScopeTest`, 2 tests) — the authorization does not
survive its transaction, and the next transaction may authorize afresh.

Unit (`ExerciseAuthorizationUnitTest`, 6 tests) — insufficient prospective exercise backing; the
one-raw-unit decision boundary; a refused backing check reducing nothing; a commitment of another
service; the in-flight guard blocking another authorization; a failed authorization discarding its
claim.

Fuzz (`ExerciseAuthorizationFuzzTest`, 2 properties) — extent authorized exactly on
`0 < q <= Remaining`; authorization exactly for the commitment's own exercise authority.

Fuzz (`ExerciseBackingFuzzTest`, 1 property) — authorization exactly when the complete successful
exercise stays backed, against an independently reconstructed obligation and an independently
stated prospective capacity.

### Commands Run

```bash
git status
forge --version
forge build
forge build --sizes
forge fmt
forge fmt --check
forge lint
forge test --match-path test/periphery/ExerciseAuthorizationPerimeter.t.sol -vv
forge test --match-path test/integration/ExerciseAuthorization.t.sol -vv
forge test --match-path test/unit/ExerciseAuthorization.t.sol -vv
forge test --match-path 'test/fuzz/Exercise*.t.sol' -vv
forge test
FOUNDRY_PROFILE=ci forge test
```

### Results

- `forge build` / `forge build --sizes`: successful. `StandbyHook` runtime size 20,091 bytes
  (4,485 bytes of margin).
- `forge fmt --check`: clean. `forge lint`: no findings.
- Full suite, default profile: **430 passed, 0 failed, 0 skipped** across 40 suites.
- Full suite, `ci` profile (fuzz runs 10,000; invariant runs 1,000 / depth 500; seed `0x1`):
  **430 passed, 0 failed, 0 skipped**.
- F8A suites specifically: 11 periphery, 22 integration, 6 unit, 3 fuzz properties — all passing.
- Mutation checks: all four mutations produced the expected failures at the expected boundaries.

### Gate Evidence

**Implemented and verified**

| G8A condition | Evidence |
| --- | --- |
| 1 — exact configured ExerciseRouter required | `test_directCaller_*`, `test_unconfiguredExerciseRouter_*`, `test_ordinaryTransitionPerimeters_*` |
| 2 — router identity never satisfies exercise authority | `test_exerciseRouterIdentity_neverSatisfiesCommitmentExerciseAuthority` |
| 3 — originator recovered only after authentication, unforgeable | `test_authorization_recoversTheOriginatorFromTheConfiguredRouter`, `test_originatingExerciser_isTheDirectCallerAndNotTheTransactionOrigin`, `test_forgedAttribution_isRefusedBeforeItIsConsulted`, `test_configuredRouter_cannotAuthorizeOutsideARequest` |
| 4 — one authentic commitment of the configured service | `test_nonexistentCommitment_isRejected`, `test_commitmentSubstitution_isRejected`, `test_commitmentOfAnotherService_isRejected` |
| 5 — authenticated exerciser equals exercise authority | `test_wrongOriginatingExerciser_isRejected`, `testFuzz_onlyTheCommitmentExerciseAuthority_mayAuthorize` |
| 6 — validity, exercisability, temporal, eligibility | the four temporal-boundary tests, `test_afterValidUntil_*`, `test_ineligibleBeneficiary_*`, `test_restoredBeneficiaryEligibility_*` |
| 7 — extent exactly `0 < q <= Remaining` | the four extent tests, `testFuzz_exerciseExtent_*` |
| 8 — `S' >= O - q` via the F5 derivation, equality accepted | `test_prospectiveBacking_permitsWhenCapacityStrictlyExceeds*`, `test_prospectiveBacking_permitsAtExactSufficiency`, `test_insufficientProspectiveExerciseBacking_isRejected`, `test_prospectiveExerciseBacking_decidesAtTheExactUnit`, `testFuzz_authorization_isAdmittedExactlyWhenTheCompleteExerciseStaysBacked` |
| 9 — exactly one context, minimum bindings | `test_qualifiedRequest_bindsExactlyOneAuthorizedCausalContext`; the context struct carries no derived quantity |
| 10 — no router / commitment / actor / Beneficiary / service / quantity substitution | the perimeter suite, `test_commitmentSubstitution_isRejected`, `test_secondAuthorization_cannotOverwriteOrCoexist` |
| 11 — no second or nested active authorization | `test_secondAuthorization_cannotOverwriteOrCoexist`, `test_authorizationInFlight_blocksAnotherAuthorization` |
| 12 — failed authorization leaves nothing; no cross-transaction reuse | `test_failedAuthorizations_leaveNoUsableContext`, `test_failedAuthorization_discardsItsInFlightClaim`, `ExerciseAuthorizationTransactionScopeTest` |
| 13 — Remaining and `O` unchanged; no fulfillment, evidence, settlement or delivery | `test_successfulAuthorization_leavesEveryAuthoritativeFactUntouched`, `test_refusedBackingCheck_reducesNoObligation`, `testFuzz_*` post-assertions |
| 14 — F8B/F8C/F8D unimplemented | `test_authorizedContext_doesNotAdvanceBeyondAuthorized`; no `EXECUTED` state exists; no swap, take, settle, or entitlement write is reachable from authorization |
| 15 — previously closed gates green | full suite, both profiles |

**Verified with harness-supplied preconditions rather than production-reachable state** —
condition 8's refusing side, condition 4's foreign-service case, and condition 11's in-flight
case. Each is unreachable in production for the structural reasons recorded above, and each is
verified against the production predicate. No integration, periphery, or acceptance claim rests on
harness state.

**Still unverified** — nothing within F8A. The behaviors F8A must not have are evidenced
negatively (no state advance, no fulfillment, no delivery) rather than by the positive execution
evidence that belongs to F8B.

### Known Limitations / Blockers

> **Status of this list.** As recorded at the F8A implementation boundary, before Correction 1 and
> before independent review closed G8A. The two items marked RESOLVED below are no longer current
> limitations.

- No blocker. No frozen-document contradiction was encountered.
- **RESOLVED (material prompt 3).** `docs/project-status.md` was deliberately not synchronized
  (material prompt 1) and therefore still records F8A as NEXT AUTHORIZED / NOT STARTED.
- The F8A backing predicate's failing side is unreachable in production, as analysed above. This
  is reported as a finding for review rather than treated as a defect.
- **RESOLVED (Correction 1).** `maxInput` is absent from the F8A request surface (implementation
  discretion, above).

### Scope Check

Work remained within F8A. No `PoolManager.swap`, exact-output execution, execution evidence, input
settlement, `maxInput` enforcement, `PoolManager.take`, Beneficiary delivery, fulfillment
finalization, or Remaining Entitlement reduction was implemented. No F4/F5/F6A/F7/F6B semantics
were changed; the only touch to existing production code outside the new transition is the
`calldata` → `memory` data-location change on two internal derivation helpers, which exists to
avoid duplicating the derivation. No frozen canonical artifact was modified.

Test-infrastructure changes outside the new F8A files are limited to two behaviour-neutral
override points in `BaseActorAwareStandbyTest` and one pass-through in `StandbyHookHarness`, both
permitted by the prompt's file boundary as F8A test/harness support.

### Proposed Gate Assessment

> **Historical.** This is the assessment Claude proposed at the F8A implementation boundary, before
> Correction 1 and before independent review. It is not the F8A result. The final independently
> reviewed result is **G8A PASS / CLOSED**, recorded under material prompt 3.

**PASS (proposed).** All fifteen G8A conditions have implementation and verification evidence; the
full suite passes under both profiles; the fuzz properties were shown by mutation to bind at the
exact decision boundaries. Three conditions have failing sides that are unreachable through
production paths and are verified against the production predicates under harness isolation, which
is the point a reviewer should weigh most carefully.

This is implementation evidence only. G8A is determined by independent review.

### Recommended Next Step

> **Historical.** Recorded before independent review. That review has since closed G8A, and F8B is
> now the authorized next slice; see material prompt 3.

Independent G8A review. If it closes, the smallest coherent next responsibility is **F8B — O2
Exact-Output Execution / Execution Evidence**: classifying a swap as O2 only when it exactly
matches the AUTHORIZED context, and marking `AUTHORIZED -> EXECUTED` in `afterSwap` only after
observing actual matching PoolManager execution of exactly `q`. It is not started and is not
authorized.

### Prompt Audit

> **Superseded count.** Accurate at the F8A implementation boundary. The current total is recorded
> in the final Prompt Audit at the end of this log.

All material follow-up instructions were recorded above. **1 material prompt recorded.**

---

# Correction 1 — `maxInput` Request-Surface Fidelity

Authorized by material prompt 2 (`docs/prompts/session-11-f8a-maxinput-correction.md`).

## Independent-review finding

> **Gate state.** The CONDITIONAL PASS recorded below is the pre-correction review state. The
> condition it named was satisfied by this correction, and G8A was subsequently closed as **PASS**;
> see material prompt 3.

Independent ChatGPT review of the completed F8A implementation found the substantive F8A
authorization semantics and all fifteen G8A conditions conforming, and recorded **G8A as
CONDITIONAL PASS / NOT YET CLOSED** pending one bounded correction: the implemented
`ExerciseRouter.exercise(uint256 commitmentId, uint256 q)` omits the `maxInput` field that
`implementation-plan.md` §14.3 already places on the F8A R1 request surface. Because `maxInput`
carries no F8A economic authorization semantics, the finding is request-surface fidelity, not an
authorization-semantics failure.

## Exact request-surface change

```solidity
// before
function exercise(uint256 _commitmentId, uint256 _q) external;

// after
function exercise(uint256 _commitmentId, uint256 _q, uint256 /* maxInput */ ) external;
```

The ABI selector changes from `exercise(uint256,uint256)` to `exercise(uint256,uint256,uint256)`.
The function body is unchanged: begin exerciser context, call
`i_hook.authorizeExercise(_commitmentId, _q)`, end exerciser context.

## Why the parameter is unnamed

The prompt requires `maxInput` to be present on the request surface and semantically inert in F8A.
Leaving the parameter unnamed makes that structural rather than a matter of review discipline: the
value arrives in calldata and is part of the ABI, and no F8A code can read, compare, forward,
bind, or persist it, because there is no identifier to reach it through. It also keeps the build
warning-free, where a named-but-unused parameter would emit one.

The cost is one missing `@param` line, which is replaced by explicit `@dev` prose stating what the
field is, why it is inert at this slice, and that the settlement stage that can honour the bound is
the stage that should name it. This is implementation discretion within the correction's scope and
is recorded here for review.

## Files changed

- `src/ExerciseRouter.sol` — restored the third request field; rewrote the `exercise` documentation
  to state the frozen three-field surface and the inertness boundary. No other change; no change to
  `src/StandbyHook.sol`.
- `test/shared/BaseExerciseAuthorizationTest.t.sol` — added `UNCONSTRAINED_MAX_INPUT`
  (`type(uint256).max`) and a four-argument `_authorizeAs` overload. The existing three-argument
  helper now delegates to it, so no pre-existing F8A test changed shape.
- `test/periphery/ExerciseAuthorizationPerimeter.t.sol` — three direct router invocations updated;
  four new tests and one assertion helper added.
- `test/integration/ExerciseAuthorization.t.sol` — one direct router invocation updated. No test
  logic changed.
- `test/fuzz/ExerciseAuthorizationFuzz.t.sol` — one new fuzz property.

## Verification added

Deterministic (`ExerciseAuthorizationPerimeterTest`):

- `test_maxInputOfZero_authorizesIdentically`
- `test_maxInputBelowTheRequestedQuantity_authorizesIdentically`
- `test_maxInputAtTheTopOfTheDomain_authorizesIdentically`
- `test_maxInput_neitherRescuesNorCausesARefusal`

The three positive cases sit at substantially different points in the `uint256` domain — `0`,
`q - 1`, and `type(uint256).max` — and each asserts the whole outcome through
`_assertMaxInputIndependentAuthorization`: identical state, serviceId, commitmentId, ExerciseRouter,
exerciser, Beneficiary and `q` bindings, plus `S` and `O` matching their independent
`ReferenceCalculations` reconstructions and Remaining Entitlement unchanged. The fourth shows an
otherwise-invalid request refused identically with the same error and operands at both ends of the
domain, and then authorized when made permissible while still carrying `maxInput = 0`.

Fuzz (`ExerciseAuthorizationFuzzTest`):

- `testFuzz_maxInput_changesNoAuthorizationOutcome(uint256)` — for every generated value, an
  impermissible request is refused with the same error and operands and leaves no causal context,
  and a permissible one is then authorized with identical bindings and untouched economics. Both
  directions in one run, the refusal first because a refusal leaves the single authorization slot
  free.

Mutation check: naming the parameter and adding `if (_maxInput < _q) revert ...` to the router made
`testFuzz_maxInput_changesNoAuthorizationOutcome` fail immediately at `maxInput = 0`. The mutation
was reverted and the file confirmed byte-identical to its pre-mutation copy before the recorded
results were produced.

## Results

- `forge build`: successful, no warnings. `forge fmt --check`: clean. `forge lint`: no findings.
- `ExerciseRouter` runtime size 590 bytes; `StandbyHook` unchanged at 20,091 bytes.
- Full suite, default profile: **435 passed, 0 failed, 0 skipped** (was 430; +5 new tests).
- Full suite, `ci` profile (fuzz runs 10,000; invariant runs 1,000 / depth 500; seed `0x1`):
  **435 passed, 0 failed, 0 skipped**.

## Confirmations

- **`maxInput` is semantically inert in F8A.** `grep -rn "maxInput" src/` matches only the
  `ExerciseRouter.exercise` signature and its documentation. It appears nowhere in
  `src/StandbyHook.sol`, is not a parameter of `authorizeExercise`, and is not a field of
  `ExerciseAuthorizationContext`.
- **No F8A authorization semantics changed.** All twelve reviewed predicates, the causal-context
  contents, the transient realization, the `AUTHORIZING` in-flight guard, `EMPTY -> AUTHORIZED` as
  the only transition, router-authentication-before-attribution, F5 derivation reuse, and
  `S' >= O - q` with equality accepted are untouched. `src/StandbyHook.sol` was not modified by this
  correction.
- **Nothing is stored or interpreted by the Hook.** The Hook never receives the value.
- **No F8B/F8C/F8D responsibility was introduced.** No `PoolManager.swap`, exact-output execution,
  `AUTHORIZED -> EXECUTED`, execution evidence, input-debt derivation, `maxInput` enforcement,
  settlement, `PoolManager.take`, Beneficiary delivery, fulfillment determination, Remaining
  Entitlement reduction, or obligation reduction exists.
- **No regression.** Every pre-existing F8A authorization, perimeter, integration, unit, fuzz, and
  transaction-scope test and every prior-gate suite passes unchanged under both profiles.

## Unexpected issues

None. The correction required no change outside the router signature, its callers, and the added
verification.

## Prompt Audit (updated)

> **Superseded count.** Accurate at the Correction 1 boundary. The current total is recorded in the
> final Prompt Audit at the end of this log.

All material follow-up instructions were recorded in this log. **2 material prompts recorded.**

---

# Status Synchronization — Material Prompt 3

Status-only audit chronology. No implementation change, no verification change, and no new
normative content.

## Instruction

Update status only in `docs/project-status.md` to reflect the independently reviewed F8A result:
F8A — O2 Authorization / Hook-Owned Causal Context COMPLETE; G8A PASS; F8B — O2 Exact-Output
Execution / Execution Evidence as the next authorized implementation slice and current blocker. Add
no implementation details, design commentary, test summaries, gate reasoning, retrospective
observations, or other new descriptive content; make only the minimum edits needed to bring
existing status fields, roadmap/ladder entries, current-blocker/next-action fields, and now-stale
status statements into consistency. Record the instruction and the resulting status-only action in
this log, and make the minimum audit-hygiene edits needed to remove ambiguity from stale
pre-correction statements about `maxInput` and pre-correction gate state — preserving the
historical record and the chronology, and qualifying rather than rewriting superseded statements.
Modify no other files. Do not begin F8B.

## Resulting action

`docs/project-status.md`, status-only edits: the header now reads current slice F8B (NEXT
AUTHORIZED / NOT STARTED), last closed gate G8A (CLOSED / PASS), and F8A COMPLETE / F8B NOT STARTED
in the status line; §2 names F8B as the next authorized slice and G8A as the last closed gate; the
§3 ladder marks F8A **COMPLETE — G8A CLOSED** and F8B **NEXT / NOT STARTED**; §7 records the F8A
authorization transition and its causal context in place of the now-false "Exercise remains
unimplemented"; §10 records no open gate, F8B as the next unstarted responsibility, F8C/F8D as the
unauthorized downstream slices, and the same correction to its carried-forward limitation; §18 and
the §19 handoff summary were brought to the same status.

`docs/prompts/session-11-log.md`, audit-hygiene qualifiers only. The pre-correction Known
Limitations entries for the unsynchronized project status and the absent `maxInput` field are
marked RESOLVED; the pre-correction Proposed Gate Assessment and Recommended Next Step are marked
historical and distinguished from the final **G8A PASS / CLOSED** result; the Correction 1
independent-review finding is annotated to show that its CONDITIONAL PASS was the pre-correction
state; and the two earlier prompt-audit counts are marked superseded by the final count below. No
chronology, implementation report, design reasoning, or test evidence was deleted or rewritten.

No other file was modified. F8B was not begun.

## Prompt Audit (final)

All material follow-up instructions were recorded in this log. **3 material prompts recorded.**
