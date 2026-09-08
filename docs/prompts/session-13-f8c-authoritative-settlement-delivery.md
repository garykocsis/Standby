# Standby — Session 13

## F8C — Authoritative Settlement / Direct Beneficiary Delivery

We are continuing implementation of **Standby**, the ETHGlobal 2026 Uniswap v4 reference realization.

This Claude session corresponds only to:

> **F8C — Authoritative Settlement / Direct Beneficiary Delivery**

F8A and F8B are complete and independently reviewed.

The current authoritative implementation state is `main`.

Do not begin F8D, GI, F9, or any later slice.

---

# 1. Objective

Implement the exact frozen F8C responsibility:

> After the one F8B-proven protected exact-output PoolManager execution reaches Hook-owned `EXECUTED`, derive the authoritative actual input debt from the exact PoolManager execution result, enforce the originating exerciser's `maxInput` against that actual debt, settle exactly that debt directly from the authenticated exerciser to PoolManager, and discharge the corresponding protected-output PoolManager credit by transferring exactly `q` directly from PoolManager to the authoritative Beneficiary.

F8C must leave:

```text
Hook causal context = EXECUTED
Remaining Entitlement = unchanged
Original Entitlement = unchanged
no fulfillment consequence
no commitment-completion consequence
no F8D finalization
```

F8C must also preserve the slice-boundary atomicity restriction:

> **Until F8D exists, a production F8C-only top-level `exercise()` must not successfully commit settlement and Beneficiary delivery while the Hook remains `EXECUTED`.**

The production path must therefore remain **fail-closed at top-level completion pending F8D**, while narrowly scoped test support may be used to prove the R4 settlement/delivery mechanics independently.

Do not implement fake finalization merely to make the F8C transaction commit.

---

# 2. Repository Instruction Ownership

Follow the permanent repository instructions defined in:

```text
CLAUDE.md
.claude/rules/*
```

Do not duplicate or reinterpret those instructions here.

This session prompt owns only the F8C slice-specific:

```text
objective
scope
requirements
prohibitions
file boundaries
gate evidence
completion boundary
```

Maintain:

```text
docs/prompts/session-13-log.md
```

as the F8C implementation-session log.

Do not update:

```text
docs/project-status.md
```

---

# 3. Required Files / Artifacts to Inspect First

Before changing code, inspect at minimum:

```text
CLAUDE.md
.claude/rules/*
docs/project-status.md
docs/implementation-plan.md
docs/uniswap-v4-realization.md

src/StandbyHook.sol
src/ExerciseRouter.sol

test/harness/ExerciseDeltaClosureRouter.sol
test/harness/AdversarialExerciseRouter.sol
test/harness/StandbyHookHarness.sol

test/shared/BaseExerciseAuthorizationTest.t.sol
test/shared/BaseAdversarialExerciseTest.t.sol

test/integration/ProtectedExecution.t.sol
test/integration/ExerciseAuthorization.t.sol

test/fuzz/ProtectedExecutionFuzz.t.sol
test/fuzz/ExerciseAuthorizationFuzz.t.sol
test/fuzz/ExerciseBackingFuzz.t.sol

test/periphery/ProtectedExecutionPerimeter.t.sol
test/periphery/ExerciseAuthorizationPerimeter.t.sol
```

Also inspect the **pinned installed Uniswap v4 source** directly for the exact settlement APIs and accounting behavior used by this repository.

At minimum confirm from the installed dependency:

```text
BalanceDelta representation
PoolManager.swap accounting semantics
PoolManager currency-delta accounting
sync(...)
settle(...)
take(...)
safe signed conversion helpers
ERC20 transfer expectations used by the selected v4 version
```

Do not rely on remembered historical v4 APIs.

---

# 4. Frozen F8C Responsibility Boundary

The established ExerciseRouter decomposition is:

```text
R1 + R2 -> F8A
R3      -> F8B
R4      -> F8C
R5      -> F8D
```

F8C owns **R4 only**.

R4 consists of:

```text
authoritative actual-input derivation
+
maxInput enforcement
+
authenticated-exerciser-funded settlement
+
direct PoolManager Beneficiary delivery
+
input/output PoolManager delta closure
```

F8C does not authorize the exercise.

F8C does not determine whether the swap qualifies as O2.

F8C does not prove actual protected output equals `q`.

F8C does not reduce Remaining.

F8C does not finalize fulfillment.

---

# 5. Authoritative Facts F8C Must Consume

Use existing authoritative facts rather than recreating them.

The Hook-owned transaction-scoped context already binds the authenticated O2 cause, including:

```text
service / PoolId
commitmentId
configured ExerciseRouter
authenticated originating exerciser
authoritative Beneficiary
q
current causal state
```

F8B establishes:

```text
state == EXECUTED
```

only after authoritative PoolManager execution evidence proves that the exact protected swap produced actual output `q`.

F8C must consume that result.

Do not repeat F8A authorization logic.

Do not repeat F8B exact-execution classification logic.

---

# 6. Canonical Execution Object Reuse

F8B already obtains the Hook-authoritative protected operation through the existing execution read surface and executes it through PoolManager.

F8C needs the exact input/output currency identities of that same executed operation.

Preserve Single Normative Ownership.

Prefer carrying/reusing the already obtained execution facts from the R3 execution helper rather than independently reconstructing a second protected-operation description inside R4.

An internal helper may, where cleanly appropriate, return the execution facts it already possesses, for example conceptually:

```text
PoolKey
SwapParams
BalanceDelta
```

This is an implementation-shape choice, not a required exact signature.

The semantic requirement is:

> F8C must derive settlement currencies from the exact canonical operation that R3 just executed, not from caller-supplied currency identities and not from an independent duplicate economic description.

---

# 7. Authoritative Actual Input

The PoolManager result is authoritative.

Do not use:

```text
quoted input
estimated input
requested input
prospective authorization input
maxInput
pre-funded router amount
caller-supplied amount
```

as actual settlement truth.

For the executed protected swap:

## protected zeroForOne

```text
input currency  = currency0
output currency = currency1
```

The authoritative input-side delta is `amount0()` and must represent debt owed by the PoolManager swap caller.

The protected-output side is `amount1()` and F8B has already proven actual output == `q`.

## protected oneForZero

```text
input currency  = currency1
output currency = currency0
```

The authoritative input-side delta is `amount1()`.

The protected-output side is `amount0()` and F8B has already proven actual output == `q`.

The input-side PoolManager delta must have the authoritative debt sign.

Do not convert by blindly applying absolute value.

Fail closed if the expected input side does not represent a negative debt.

Use a conversion approach that cannot overflow or reinterpret the `int128` minimum value.

Prefer widening the signed value before negation, or an installed v4/utility conversion proven equivalent.

Document the exact conversion decision in the Session 13 log.

---

# 8. Where Actual Input Lives

Do **not** add actual input to persistent Hook state.

Do **not** add it to the Hook causal context merely for convenience.

The authoritative input value is already available transaction-locally from the exact PoolManager execution result at the R3 -> R4 boundary.

Consume it directly during the same unlock callback.

No settlement ledger is required.

No input snapshot is required.

---

# 9. `maxInput`

The public request surface remains:

```solidity
exercise(uint256 commitmentId, uint256 q, uint256 maxInput)
```

F8C activates the previously inert `maxInput`.

The exact predicate is:

```text
actualInput <= maxInput
```

Required boundaries:

```text
actualInput < maxInput   -> pass
actualInput == maxInput  -> pass
actualInput > maxInput   -> revert whole exercise
```

`maxInput` is exercise-local cost protection only.

It must not:

```text
affect commitment validity
affect q authorization
affect Beneficiary eligibility
affect Supporting Capacity
affect Aggregate Capacity Obligation
enter Hook economic state
enter persistent state
become a Hook causal-context field
```

Pass it only as far as needed to the R4 settlement stage.

---

# 10. Authoritative Economic Payer

The economic payer is:

> **the authenticated originating exerciser already bound in the Hook-owned causal context**

Do not infer payer merely from:

```text
ExerciseRouter address
PoolManager swap caller
Beneficiary
tx.origin
current test-harness funding
arbitrary supplied payer
```

The Router coordinates payment mechanics.

The Router is not Standby principal and must not become a pre-funded Standby reserve.

Use the already authenticated exerciser associated with this exact O2 causal context.

Do not add a second payer snapshot if the existing context already supplies the authoritative actor.

---

# 11. Input Settlement

Use the pinned installed v4 settlement interfaces.

For the supported ERC20 reference domain, the intended economic sequence is conceptually:

```text
derive actualInput

require actualInput <= maxInput

PoolManager.sync(inputCurrency)

transfer exactly actualInput
    from authenticated exerciser
    directly to PoolManager

PoolManager.settle()

prove relevant Router input-side PoolManager delta == 0
```

The exact installed signatures and helper libraries must be established from the repository dependency.

Calling `settle()` alone is insufficient proof.

The actual negative input-side PoolManager debt must be completely closed.

---

# 12. Direct Funding Requirement

The supported economic asset path is:

```text
authenticated exerciser
        ->
PoolManager
```

The Router may coordinate `transferFrom` / allowance mechanics.

Do not intentionally implement:

```text
exerciser -> Router -> PoolManager
```

and do not fund settlement from an existing Router balance.

Ordinary ERC20 allowance / `transferFrom` is sufficient for the MVP if compatible with the repository's existing token/test setup.

Permit2 is not required unless it materially improves the existing path without expanding scope.

Do not introduce unnecessary periphery complexity.

---

# 13. Exact Settlement Amount

The amount funded must be:

```text
exactly actualInput
```

Not:

```text
maxInput
actualInput - 1
actualInput + 1
quote
estimate
router balance
```

Verification must prove both:

```text
exact actualInput was sourced from the exerciser
```

and:

```text
the relevant PoolManager input debt is zero afterwards
```

Do not accept underpayment or overpayment as equivalent settlement.

---

# 14. Direct Beneficiary Delivery

After successful input settlement, resolve the protected output by the canonical path:

```text
PoolManager.take(
    outputCurrency,
    authoritativeBeneficiary,
    q
)
```

The Beneficiary must come from the existing authoritative Hook-owned O2 context.

Do not add:

```text
recipient
beneficiary
outputCurrency
```

as caller-controlled exercise parameters.

The quantity must be the existing bound `q`.

The currency must be the exact protected output currency of the executed canonical operation.

---

# 15. No Output Custody Substitution

The supported production path must never become:

```text
PoolManager -> ExerciseRouter -> Beneficiary
```

or:

```text
PoolManager -> StandbyHook -> Beneficiary
```

The PoolManager output credit is taken **directly to the authoritative Beneficiary**.

For canonical exact-transfer mocks, verification should establish:

```text
Beneficiary balance increase == q
ExerciseRouter protected-output balance increase == 0
StandbyHook protected-output balance increase == 0
relevant Router PoolManager output credit == 0
```

Do not create an alternate router-owned token balance as authoritative delivery evidence.

---

# 16. Causal Context

Do not add:

```text
SETTLED
DELIVERED
actualInput
settlement nonce
delivery nonce
payer snapshot
delivery flag
persistent execution record
settlement ledger
```

unless an unexpected implementation fact proves one is strictly necessary.

The expected correct result is:

```text
context remains EXECUTED
```

after successful R4 mechanics.

F8D owns eventual consumption.

---

# 17. F8D Boundary — Strictly Out of Scope

Do not implement:

```text
Remaining Entitlement reduction
Original Entitlement mutation
Aggregate Capacity Obligation release
fulfillment marking
fulfilled flag
commitment completion
post-execution final backing confirmation
finalization
context consumption
F8D replay protection
```

Do not call a newly invented pseudo-finalization function merely to make F8C complete.

F8D will later:

```text
require matching EXECUTED context
re-read authoritative commitment
revalidate q <= current Remaining
derive actual post-swap Supporting Capacity
derive current Aggregate Capacity Obligation
derive Ofinal = Ocurrent - q
require Sactual >= Ofinal
reduce Remaining exactly q
consume context exactly once
```

F8C must leave that responsibility untouched.

---

# 18. Critical F8C Slice-Completion Restriction

This requirement was derived after reviewing the actual F8A/F8B transient-context implementation and is mandatory.

If production F8C allowed the top-level exercise to return successfully before F8D exists, the following durable state could occur:

```text
swap committed
exerciser paid
Beneficiary received q
Remaining unchanged
Hook context still EXECUTED
```

At transaction end, EIP-1153 transient context disappears.

That would destroy the causal proof required by F8D while leaving the entitlement unreduced, allowing the commitment to be exercised again.

Therefore:

> **A production F8C-only exercise must remain fail-closed at top-level completion until F8D has consumed/finalized the EXECUTED context.**

Implement a minimal completion barrier that preserves this rule.

Conceptually:

```text
exercise
    ->
authorize
    ->
unlock
        ->
execute
        ->
settle
        ->
deliver
        [F8D will later finalize here]
    ->
require causal context consumed
```

At F8C, because F8D is absent:

```text
context remains EXECUTED
=> production top-level request must revert
```

At F8D, the later implementation should be able to insert finalization such that:

```text
context consumed
=> production top-level request completes
```

Do not move F8D semantics upstream to satisfy the barrier.

Do not persist a fake completion flag.

The exact Solidity shape is an implementation choice, but the behavioral property is mandatory.

---

# 19. F8C Verification Strategy

F8C must use the **real pinned PoolManager** wherever authoritative settlement/accounting behavior is under test.

Mocks may not replace PoolManager debt/settlement truth.

Because production remains intentionally fail-closed pending F8D, positive committed R4 mechanics may use a narrowly scoped test harness if necessary.

Such test support must:

```text
exercise the real production R3/R4 mechanics
use the real PoolManager
not redefine payer semantics
not redefine maxInput semantics
not redirect output to itself
not mutate Remaining
not claim fulfillment
not become production semantics
```

Document why the harness exists and what it does not prove.

---

# 20. Existing F8B Delta-Closure Harness

Reassess:

```text
test/harness/ExerciseDeltaClosureRouter.sol
```

Its current purpose is F8B-only mechanical delta closure.

Its behavior — pre-funded Router input settlement and Router custody of protected output — is deliberately **not** valid F8C economic semantics.

Do not use it as positive F8C evidence.

It may remain only where F8B-isolated tests still genuinely need it.

Where appropriate, narrow its use or replace F8C-facing positive paths with new R4-accurate test infrastructure.

Do not unnecessarily rewrite valid F8B evidence.

---

# 21. Adversarial Threats to Verify

At minimum test or otherwise provide evidence against:

```text
fake router-supplied actual input
quote substituted for actual input
requested amount substituted for actual input
wrong BalanceDelta side
wrong sign
absolute-value reinterpretation
zeroForOne / oneForZero direction confusion
unsafe signed conversion
maxInput checked against anything except actual input
maxInput equality incorrectly rejected
settlement attempted before maxInput validation
underpayment
overpayment
partial settlement
wrong payer
Router-funded settlement
arbitrary third-party payer substitution
insufficient exerciser funds
insufficient exerciser allowance
wrong recipient
caller-selected recipient
Router output custody
Hook output custody
less than q delivery
greater than q delivery
wrong output currency
stale or absent EXECUTED context
settlement before EXECUTED
repeated settlement
repeated delivery
second protected execution
cross-commitment contamination
unrelated PoolManager netting
nested/interleaved O2
relevant reentrancy
failure after swap but before settlement
failure during settlement
failure after settlement but before delivery
delivery failure
malformed O2 falling into ordinary O3 semantics
Remaining mutation before F8D
obligation release before F8D
fulfillment claim before F8D
successful production F8C-only top-level completion
```

Add any implementation-specific threat revealed during the work.

---

# 22. Required Failure Atomicity

All of the following must cause the entire protected exercise to revert:

```text
actualInput > maxInput
insufficient exerciser balance
insufficient allowance
failed exact transfer
failed PoolManager settlement
non-zero residual input debt
failed direct output take/delivery
invalid settlement/delivery causal state
F8C-only production completion before F8D
```

After such failure, prove as applicable:

```text
PoolManager swap does not survive
exerciser payment does not survive
Beneficiary output does not survive
Remaining unchanged
Original unchanged
obligation consequence unchanged
no reusable EXECUTED context survives the transaction
```

---

# 23. G8C — Authoritative Settlement / Delivery Gate

Implement and provide evidence for all of the following.

## G8C-1 — Authoritative currency identity

Input and output currencies derive only from the exact configured protected execution.

Prove both protected directions.

## G8C-2 — Authoritative actual input

Actual input derives from the negative input-side authoritative PoolManager `BalanceDelta` produced by the exact F8B swap.

No quote, request amount, prospective value, or `maxInput` substitutes.

## G8C-3 — Signed interpretation

Wrong side, wrong sign, zero/non-debt input-side interpretation, and absolute-value substitution fail closed.

## G8C-4 — Safe conversion

Signed conversion/negation is proven safe and semantically correct for the supported `int128` PoolManager delta domain.

## G8C-5 — Exact `maxInput`

Prove:

```text
actualInput < maxInput
actualInput == maxInput
actualInput > maxInput
```

with equality accepted and breach atomically reverted.

## G8C-6 — Cost-protection isolation

`maxInput` remains request-local settlement protection only.

No Hook economic-state or causal-context contamination.

## G8C-7 — Authenticated exerciser pays

The exact exerciser bound by the authoritative Hook context funds the debt.

Router, Beneficiary, arbitrary payer, and pre-funded Router balances cannot substitute.

## G8C-8 — Exact funding

Exactly `actualInput` moves from authenticated exerciser directly to PoolManager.

## G8C-9 — Exact v4 settlement

Use the pinned installed PoolManager settlement semantics correctly and prove relevant input delta is fully cleared.

## G8C-10 — No under/over settlement

Less or more than the authoritative debt is not accepted as the supported payment.

## G8C-11 — Authoritative Beneficiary

Recipient derives only from the existing Hook-owned causal context.

Caller cannot redirect output.

## G8C-12 — Direct exact delivery

PoolManager transfers exactly `q` of the correct protected output currency directly to the authoritative Beneficiary.

## G8C-13 — No Router/Hook output custody

Production R4 does not substitute Router or Hook token custody for Beneficiary delivery.

Relevant PoolManager output credit is closed.

## G8C-14 — EXECUTED prerequisite

Settlement/delivery occur only for the same O2 that reached Hook-owned `EXECUTED`.

Stale, absent, substituted, or unrelated context cannot authorize R4.

## G8C-15 — Single R4 sequence

No split settlement, split delivery, repeated settlement/delivery, unrelated PoolManager activity, cross-commitment netting, or second protected execution is supported.

## G8C-16 — F8D non-contamination

Throughout F8C:

```text
Remaining unchanged
Original unchanged
Aggregate Capacity Obligation consequence unchanged
no fulfillment
no completion
no context consumption
```

## G8C-17 — No new O2 lifecycle state

Context remains `EXECUTED`.

No `SETTLED`, `DELIVERED`, or equivalent persistent/transient lifecycle state is introduced.

## G8C-18 — Full failure atomicity

Every payment, settlement, `maxInput`, or delivery failure unwinds:

```text
swap
payment
delivery
causal intermediate effects
```

with no prohibited authoritative residue.

## G8C-19 — Slice-boundary completion safety

Before F8D exists, the production F8C-only top-level exercise cannot successfully commit settlement and Beneficiary delivery while Remaining remains unreduced and the transient `EXECUTED` proof would disappear.

Positive R4 mechanics may be demonstrated through narrowly isolated test infrastructure, but such infrastructure is not production O2 semantics.

---

# 24. Required Test Families

Use the repository's existing test architecture and permanent testing conventions.

Provide F8C gate evidence across at least:

```text
unit
integration
fuzz
periphery/adversarial
```

where each family adds meaningful proof rather than duplicated examples.

Real PoolManager integration evidence is mandatory for:

```text
actual BalanceDelta interpretation
input debt
settlement
delta closure
direct take
failure rollback
```

Direction-general evidence must cover `oneForZero` as well as the canonical `zeroForOne` fixture where the mechanic is direction-sensitive.

Fuzz tests should target meaningful F8C boundaries such as:

```text
actualInput vs maxInput
input-debt extraction
payer funding
q delivery
```

within supported ranges.

Do not weaken existing F8A/F8B tests merely to accommodate F8C.

If a prior F8B test must change because F8C legitimately supersedes its staging mechanics, document exactly why.

---

# 25. Production Scope Expectations

Production changes should remain narrowly concentrated.

Expected likely production files:

```text
src/ExerciseRouter.sol
```

and only if genuinely necessary:

```text
src/StandbyHook.sol
```

A Hook change must have a causal or completion-boundary justification.

Do not add Hook economic state.

Do not expand unrelated F5/F6/F7 derivation logic.

Do not change O1 or O3 semantics.

Do not add F8D finalization.

Test support may change as required to replace the F8B-only mechanical closure where F8C semantics now need real evidence.

---

# 26. Completion Report

At the end of implementation, provide a concise but complete F8C report covering:

```text
Files Inspected
Files Changed
Requirements Implemented
Implementation Decisions
Pinned v4 Mechanics Confirmed
Tests Added / Changed
Commands Run
Results
Gate Evidence by G8C Condition
Known Limitations / Reachability Caveats
Scope Check
Proposed Gate Assessment
Recommended Next Step
Prompt Audit
```

The proposed gate assessment is advisory only.

---

# 27. Required Gate Evidence

Follow the permanent testing and verification conventions in:

```text
CLAUDE.md
.claude/rules/*
```

For G8C evidence, the completed slice must at minimum report successful results for:

```bash
forge fmt --check
forge lint
forge build
forge test
FOUNDRY_PROFILE=ci forge test
```

Also report contract size where required by the permanent repository process or where F8C materially changes production bytecode.

Do not report F8C complete while required verification is failing.

---

# 28. Status / Documentation Boundary

Do not edit:

```text
docs/project-status.md
```

during implementation.

Do not change frozen canonical semantics.

If you discover a genuine inconsistency between the frozen artifacts and the implementation needed for F8C:

1. do not invent or reinterpret semantics;
2. record the issue clearly in the Session 13 log;
3. implement only what remains unambiguous;
4. identify the unresolved blocker explicitly in the completion report.

---

# 29. Completion Boundary

F8C is complete only when the implementation and evidence establish:

```text
one F8B-proven protected execution
        ->
authoritative actual input debt
        ->
actualInput <= maxInput
        ->
authenticated exerciser funds exactly actualInput
        ->
PoolManager input debt exactly settled
        ->
PoolManager directly delivers exactly q
to authoritative Beneficiary
        ->
both relevant PoolManager currency deltas closed
        ->
Hook context still EXECUTED
        ->
Remaining / obligation consequence unchanged
        ->
production top-level path remains fail-closed
pending F8D
        ->
session-13-log.md updated
```

Stop at the F8C completion boundary.
