# Standby — Claude Code Session 12

## F8B — O2 Exact-Output Execution / Execution Evidence

You are implementing the next bounded slice of **Standby**, an ETHGlobal 2026 Uniswap v4 project.

The current implementation state is already validated through:

```text
F0   v4 Infrastructure
     COMPLETE / G0 CLOSED

F1   Deterministic Economic Fixture
     COMPLETE / G1 CLOSED

F2   EligibilityRegistry
     COMPLETE / G2 CLOSED

F3   StandbyHook Trust + PES Configuration
     COMPLETE / G3 CLOSED

F4   Commitment Storage + Bounded References
     COMPLETE / G4 CLOSED

F5   Authoritative Derivation Kernel
     COMPLETE / G5 CLOSED

F6A  Preliminary O3 Enforcement with O = 0
     COMPLETE / G6A CLOSED

F7   O1 Commitment Admission
     COMPLETE / G7 CLOSED

F6B  O3 Enforcement with Authentic O > 0
     COMPLETE / G6B CLOSED

F8A  O2 Authorization / Hook-Owned Causal Context
     COMPLETE / G8A CLOSED
```

The only authorized implementation slice for this session is:

> **F8B — O2 Exact-Output Execution / Execution Evidence**

Do not implement F8C settlement/delivery or F8D fulfillment/finalization.

---

# 1. Repository Operating Model

Follow the permanent repository instructions already owned by:

```text
CLAUDE.md
.claude/rules/*
```

Do not duplicate or reinterpret those rules in this session.

This prompt owns only the F8B-specific:

- objective;
- responsibility boundary;
- required semantics;
- prohibited responsibility leakage;
- implementation scope;
- verification obligations;
- completion boundary.

Before modifying production code:

1. inspect the current repository implementation;
2. inspect the actual pinned Uniswap v4 source compiled by this repository;
3. inspect the frozen implementation plan and relevant canonical artifacts;
4. inspect the completed F8A implementation and tests;
5. reconstruct the actual existing transient-context representation;
6. verify all assumed v4 API and delta semantics against the pinned dependency rather than copying historical examples.

If the actual pinned interfaces materially contradict a requirement in this prompt, stop and record the contradiction rather than silently changing protocol semantics.

---

# 2. Session Implementation Record

Maintain the contemporaneous implementation chronology in:

```text
docs/prompts/session-12-log.md
```

The log should capture material implementation decisions, discoveries, commands/tests run, failures, corrections, and the eventual Claude-side assessment of G8B.

Do not turn the log into a duplicate of permanent repository documentation.

---

# 3. F8B Objective

Implement exactly this responsibility:

> **Bind one existing Hook-owned AUTHORIZED exercise to exactly one qualifying protected PoolManager swap, classify only that exact swap as O2, and transition the Hook-owned causal context to EXECUTED only after authoritative PoolManager callback evidence proves that the matching swap actually produced exactly the authorized protected output quantity `q`.**

F8B therefore owns exactly two substantive responsibilities:

1. **O2 Execution Classification**
   - determine whether a proposed PoolManager swap is the exact execution authorized by the active F8A context;

2. **Authoritative Execution Evidence**
   - determine whether that exact swap actually executed for the full authorized protected output `q`.

F8B does not own settlement, delivery, fulfillment, Remaining reduction, or finalization.

---

# 4. Existing Authority Boundaries

Preserve the established authority model.

## 4.1 PoolManager

The real immutable Uniswap v4 PoolManager is authoritative for:

```text
actual AMM execution
actual swap result
actual PoolManager-produced BalanceDelta
actual post-swap v4 state
```

Only authenticated callbacks from the immutable PoolManager may create Standby execution evidence.

## 4.2 StandbyHook

The Hook is authoritative for:

```text
Standby O2/O3 interpretation
matching an execution against Hook-owned AUTHORIZED context
Hook-owned transaction-scoped causal state
AUTHORIZED -> EXECUTED interpretation
```

## 4.3 ExerciseRouter

The configured ExerciseRouter is a transaction coordinator.

It does not own:

```text
execution truth
commitment truth
Beneficiary truth
S
S′
O
Remaining
fulfillment
a reusable execution ledger
```

Router intent, router return values, arbitrary calldata, and `hookData` are not proof that execution occurred.

Preserve the rule:

> **PoolManager owns execution truth; StandbyHook owns Standby causal interpretation; ExerciseRouter owns neither.**

---

# 5. Existing F8A Context

F8A already creates one transaction-scoped Hook-owned AUTHORIZED context after all authorization predicates pass.

The context already binds the minimum causal facts required by later O2 stages, including the authoritative equivalent of:

```text
service / pool identity
commitmentId
authenticated ExerciseRouter
authenticated originating exerciser
authoritative Beneficiary
exact q
causal state
```

F8A deliberately does not snapshot economic state such as:

```text
S
S′
O
Remaining
Validity
Exercisability
eligibility
```

Do not introduce duplicate snapshots in F8B.

Existing F8A implementation-level states include:

```text
EMPTY
AUTHORIZING
AUTHORIZED
```

`AUTHORIZING` is an implementation-only in-flight guard rather than a new economic lifecycle state.

F8B may analogously add the implementation-only state:

```text
EXECUTING
```

as specified below.

---

# 6. F8B Causal State Model

The canonical economic causal progression remains:

```text
EMPTY
  -> AUTHORIZED
  -> EXECUTED
  -> later consumed / EMPTY
```

For implementation-level callback isolation, F8B should use:

```text
AUTHORIZED
  -> EXECUTING
  -> EXECUTED
```

`EXECUTING` means only:

> the unique `beforeSwap` corresponding to this authorization has been accepted as the exact O2 swap, and its corresponding authoritative `afterSwap` is now expected.

`EXECUTING` must not contain new economic truth.

Do not persist this lifecycle in ordinary contract storage.

Use the existing transaction-scoped context mechanism consistently.

Do not introduce a persistent execution ledger.

---

# 7. O2 Versus O3 Classification

Before F8B, swaps use the existing ordinary O3 path.

Preserve that behavior when no O2 operation is active.

The required classification is:

```text
context == EMPTY
    -> swap follows existing ordinary O3 classification/enforcement
```

Once F8A has created an AUTHORIZED context, the system is inside an O2 causal exclusion zone:

```text
context == AUTHORIZED
    + exact authorized O2 swap
        -> classify O2

context == AUTHORIZED
    + any non-matching swap
        -> REVERT
```

Do not silently route a mismatching swap through O3 while an authorization is unresolved.

This restriction preserves causal continuity between the state used during F8A authorization and the swap execution that authorization intended.

Likewise, an unresolved:

```text
EXECUTING
```

or:

```text
EXECUTED
```

context must not permit an unrelated swap to proceed as ordinary O3.

ExerciseRouter identity alone must never classify a swap as O2.

An AUTHORIZED context alone must never classify a swap as O2.

`hookData` alone must never classify a swap as O2.

A protected-direction swap alone must never classify a swap as O2.

A q-like amount alone must never classify a swap as O2.

Classification is conjunctive.

---

# 8. Exact O2 `beforeSwap` Matching

The actual proposed PoolManager swap must match the complete authorized O2 shape.

At minimum verify the authoritative equivalent of all of the following.

## 8.1 Callback authority

The Hook callback itself must come from the immutable configured PoolManager.

Reuse the existing trusted callback boundary rather than creating an alternate trust model.

## 8.2 PoolManager operation sender

The v4 callback `sender` for the canonical O2 swap must be the exact configured ExerciseRouter/O2 coordinator.

This is a required conjunct.

It is not by itself sufficient to establish O2.

## 8.3 Exact service / PoolId

The callback PoolKey must resolve to the exact configured service PoolId bound to the active authorization.

No pool substitution is permitted.

## 8.4 Protected direction

Require:

```text
params.zeroForOne == configured protected direction
```

Do not hard-code canonical zero-for-one into production logic.

The canonical fixture is zero-for-one, but generalized one-for-zero behavior must remain correct.

## 8.5 Exact-output mode

Under the pinned v4 `SwapParams` semantics, verify the repository's actual sign convention.

For the currently pinned v4 semantics this is expected to be:

```text
amountSpecified > 0
    => exact output

amountSpecified < 0
    => exact input
```

F8B must accept only exact-output O2.

Do not infer this from memory; confirm against the installed dependency.

## 8.6 Exact requested `q`

The requested output quantity must exactly equal the quantity bound by F8A.

Conceptually:

```text
params.amountSpecified == q
```

subject to the actual pinned integer types and safe conversions.

Reject:

```text
q - 1
q + 1
0
exact-input representation
overflowing / invalid conversion
```

## 8.7 Exact qualification boundary

The O2 swap must use the authoritative qualification price boundary already defined by the configured service and consumed by the F5 prospective protected-exercise derivation.

Verify:

```text
params.sqrtPriceLimitX96
```

matches that exact canonical execution boundary.

Do not derive an alternate F8B price-limit policy.

Do not duplicate F5 economics.

---

# 9. `beforeSwap` Consequence

A matching `beforeSwap` proves only:

> this is the exact authorized O2 execution attempt.

It does not prove that execution actually happened.

Therefore a matching `beforeSwap` may transition:

```text
AUTHORIZED
    -> EXECUTING
```

It must not transition directly to:

```text
EXECUTED
```

Router intent is not execution proof.

Requested output is not actual output.

A successful `beforeSwap` callback is not actual AMM execution evidence.

---

# 10. Authoritative `afterSwap` Evidence

Only the authoritative PoolManager `afterSwap` path may establish `EXECUTED`.

The Hook must require the execution context to be:

```text
EXECUTING
```

before accepting execution evidence.

Revalidate the callback facts necessary to prove this `afterSwap` belongs to the exact accepted O2 swap, including the authoritative equivalent of:

```text
immutable PoolManager callback authority
callback sender
PoolKey / PoolId
protected direction
exact-output mode
requested q
qualification price limit
```

Do not assume that the existence of `EXECUTING` alone permits arbitrary callback data to satisfy the execution.

---

# 11. `BalanceDelta` Semantics and Actual Protected Output

Verify the pinned v4 `BalanceDelta` semantics directly from the installed source.

The expected current v4 interpretation is:

```text
positive currency delta:
    currency owed to the swap caller

negative currency delta:
    currency owed by the swap caller to PoolManager
```

For a protected zero-for-one exercise:

```text
input  = currency0
output = currency1

actual protected output = delta.amount1()
```

The required successful execution evidence is:

```text
delta.amount1() == +q
```

For a protected one-for-zero exercise:

```text
input  = currency1
output = currency0

actual protected output = delta.amount0()
```

The required successful execution evidence is:

```text
delta.amount0() == +q
```

Use the actual pinned types and safe conversions.

Do not use absolute values.

Do not accept a negative output-side delta.

Do not accept partial output.

Do not infer actual output from:

```text
params.amountSpecified
router return values
router calldata
hookData
estimated execution
predicted S′
```

The distinction is required:

```text
beforeSwap:
requested exact output == q

afterSwap:
actual protected output == q
```

Both must hold.

---

# 12. Partial Exact-Output Execution

Treat the following as failure:

```text
requested exact output = q
actual PoolManager protected output < q
```

This matters because the existence of an exact-output request does not independently prove the full requested quantity was actually produced.

A partial output must never produce:

```text
EXECUTED
```

The containing swap/exercise should revert.

---

# 13. `EXECUTING -> EXECUTED`

The only valid transition to execution evidence is:

```text
EXECUTING
    + authoritative matching PoolManager afterSwap
    + actual protected output == q
        -> EXECUTED
```

`EXECUTED` means exactly:

> **The unique PoolManager swap causally bound to the active authorization actually executed the exact authorized protected output quantity `q`.**

It does not mean:

```text
actual input debt has been paid
maxInput has been satisfied
input settlement is complete
Beneficiary has received q
output credit has been discharged
commitment has been fulfilled
Remaining has been reduced
O has been reduced
commitment has been finalized
```

---

# 14. Minimum Causal Binding

Apply Semantic Minimality.

The agreed F8B model does not require a new execution nonce, execution hash, router-owned success flag, or duplicated swap ledger merely to bind `beforeSwap` to `afterSwap`.

The intended minimum binding is:

```text
existing authoritative F8A context
+
EXECUTING implementation guard
+
immutable PoolManager callback ordering/authentication
+
exact sender/PoolKey/SwapParams validation
+
authoritative afterSwap BalanceDelta
```

Do not add an execution nonce/hash unless the actual pinned implementation mechanics demonstrate a concrete causal ambiguity that cannot otherwise be resolved.

If such a contradiction is discovered, stop and document it before introducing new protocol state.

---

# 15. Nested / Multiple / Reentrant Paths

The MVP O2 model remains:

```text
one commitment exercise
-> one qualifying protected exact-output swap
-> later one settlement/delivery path
-> later one finalization
```

Reject causal ambiguity.

At minimum ensure the implementation cannot successfully perform:

```text
EMPTY -> EXECUTING

EMPTY -> EXECUTED

AUTHORIZED -> second AUTHORIZED

AUTHORIZED -> EXECUTED from beforeSwap alone

AUTHORIZED -> unrelated ordinary O3 swap

EXECUTING -> second beforeSwap

EXECUTING -> nested unrelated swap

EXECUTING -> second authorization

EXECUTING -> EXECUTED without matching actual q

EXECUTED -> second execution

EXECUTED -> overwritten authorization

EXECUTED -> unrelated second swap while the context remains unresolved
```

Do not introduce a broad generic reentrancy framework if the narrow causal-state machine already rejects the relevant transitions.

---

# 16. Failed Swap / Caught-Revert Boundary

The production ExerciseRouter must treat failure of the protected O2 PoolManager swap as failure of the containing exercise transaction.

It must not implement:

```text
authorize
-> try PoolManager swap
-> catch failed swap
-> retry another O2 swap
```

or:

```text
authorize
-> failed O2 swap
-> catch
-> continue with unrelated protocol actions
```

A failed protected PoolManager execution must propagate.

This matters because an `EXECUTING` transient-state write performed inside the reverted PoolManager callback path may roll back to the earlier AUTHORIZED state.

The canonical production behavior therefore requires the failed PoolManager call to unwind the containing exercise, so the earlier F8A authorization also disappears.

Do not introduce a new pre-PoolManager `beginExecution()` transition solely to support retry/catch behavior that the canonical ExerciseRouter does not permit.

G8B must contain adversarial evidence that production behavior cannot convert a failed execution into a second execution attempt against the same authorization.

---

# 17. Economic Atomicity

The eventual complete O2 operation is economically atomic:

```text
authorization
+ execution
+ settlement
+ Beneficiary delivery
+ finalization

must ultimately be complete-or-zero
```

F8B does not independently finalize those economics.

However, its transaction-scoped evidence must remain compatible with later atomic rollback.

If F8C or F8D later fails, the containing transaction must be capable of reverting the earlier PoolManager execution and F8B causal evidence.

Do not introduce an irreversible persistent F8B side effect that could survive an incomplete O2 transaction.

Persistent commitment state must remain unchanged during F8B.

---

# 18. Actual Input Debt / `maxInput`

The actual PoolManager `BalanceDelta` may expose the input-side debt at the same point that F8B observes protected-output execution.

Visibility does not assign responsibility.

F8B must not implement:

```text
actualInput <= maxInput
```

F8B must not settle input debt.

F8B must not assign payment responsibility.

F8B should not add actual input debt to Hook causal context merely because it is available during `afterSwap`, unless the pinned mechanics demonstrate that F8C cannot authoritatively recover the necessary settlement truth later in the same transaction.

The current normative ownership is:

```text
F8B:
    prove actual protected output == q

F8C:
    derive authoritative actual input debt
    enforce actualInput <= maxInput
    settle that debt
```

`maxInput` remains semantically inert in F8B.

---

# 19. F8C Responsibilities That Must Remain Absent

Do not implement any F8C behavior.

F8C later owns:

```text
authoritative actual input debt
actualInput <= maxInput
exerciser payment
PoolManager input settlement
settlement-delta closure
PoolManager.take(...)
direct protected-output delivery to authoritative Beneficiary
Beneficiary balance consequence
output-side accounting closure
```

Do not send protected output to:

```text
ExerciseRouter
StandbyHook
arbitrary caller-provided recipient
```

Do not claim delivery.

Any mechanical PoolManager delta closure needed only by F8B tests must remain test-only and must not be presented as protocol settlement semantics.

---

# 20. F8D Responsibilities That Must Remain Absent

Do not implement:

```text
Remaining reduction
authoritative O reduction
fulfillment
commitment completion
economic finalization
consumption of the complete O2 causal proof
```

F8B owns only execution evidence.

Persistent commitment Remaining must remain unchanged.

Aggregate Obligation must remain authoritative under the existing derivation and must not be reduced by F8B.

---

# 21. Test-Only PoolManager Delta Closure

A real PoolManager swap produces currency accounting that must eventually be closed for the surrounding unlock transaction to complete.

Production settlement/delivery belongs to F8C.

Therefore F8B integration/differential tests may use narrowly scoped **test-only mechanical delta closure** where required to allow the real PoolManager transition to commit and its post-state to be examined.

Such test plumbing must not establish or claim:

```text
maxInput semantics
economic payer semantics
Beneficiary delivery semantics
fulfillment
Remaining reduction
O reduction
production F8C behavior
```

Its purpose is only:

> allow an otherwise valid real-PoolManager execution to complete sufficiently for F8B execution evidence and F5 predicted-versus-actual state equivalence to be tested.

Keep this boundary explicit in test names/comments/helpers.

Do not move equivalent settlement code into production as part of F8B.

---

# 22. Predicted Versus Actual Pool State

Reuse the existing F5 authoritative prospective-execution derivation.

For successful allowed executions, G8B must include differential evidence that:

```text
F5 predicted prospective PoolManager state
```

matches:

```text
actual PoolManager post-swap state
```

and that predicted prospective Supporting Capacity:

```text
S′
```

matches authoritative Supporting Capacity derived from actual PoolManager post-state.

Do not reimplement an F8B-specific swap simulator.

Do not derive S or S′ using shortcuts such as token amount subtraction.

Preserve the corrected F5 traversal semantics.

---

# 23. Ordinary O3 Regression

The introduction of O2 classification must not weaken the existing F6B ordinary-swap enforcement.

Required behavior:

```text
no O2 context
-> ordinary swaps continue through existing O3 path
```

An ordinary protected swap must not bypass:

```text
prospective S′
current O
S′ >= O
```

merely because F8B exists.

Conversely, an exact authorized O2 swap must not accidentally fall through into the ordinary O3 rule, because O2 authorization used the prospective post-fulfillment condition:

```text
S′ >= O - q
```

rather than ordinary O3:

```text
S′ >= O
```

Preserve the distinction.

---

# 24. Required Adversarial Cases

G8B evidence must cover, as applicable to the actual implementation, all of the following threat families.

## 24.1 Positive classification

Prove an authentic:

```text
AUTHORIZED context
+
configured ExerciseRouter
+
correct PoolId
+
protected direction
+
exact-output q
+
correct qualification limit
```

is classified as the unique O2 swap.

## 24.2 No authorization

A swap with no active AUTHORIZED context cannot create O2 execution evidence.

Ordinary swaps remain O3.

## 24.3 Router identity alone

Configured ExerciseRouter identity without a valid AUTHORIZED context is insufficient.

## 24.4 Forged hookData

Forged or imitative `hookData` cannot manufacture O2 classification or EXECUTED evidence.

## 24.5 Wrong pool

A swap against any other PoolId rejects while O2 is unresolved.

## 24.6 Wrong direction

Opposite direction cannot satisfy the authorization.

## 24.7 Exact-input substitution

An exact-input swap cannot satisfy an exact-output authorization.

## 24.8 Quantity substitution

Reject at least:

```text
q - 1
q + 1
```

and other fuzzed mismatches.

## 24.9 Qualification-boundary substitution

A different `sqrtPriceLimitX96` cannot satisfy O2 even if other fields match.

## 24.10 BeforeSwap-only proof

Demonstrate that a matching `beforeSwap` does not itself produce EXECUTED.

## 24.11 Partial actual output

A requested exact-output `q` whose actual PoolManager protected output is less than `q` cannot produce EXECUTED.

## 24.12 Malformed afterSwap / wrong evidence

Wrong output side, wrong sign, wrong quantity, or unexpected callback ordering cannot produce EXECUTED.

Use an appropriate harness only where direct malformed-callback testing cannot be obtained through the real PoolManager path.

Do not weaken production callback authentication for testing.

## 24.13 Second swap

A second matching or unrelated swap against the same unresolved authorization rejects.

## 24.14 Nested swap

A nested PoolManager interaction cannot substitute for the expected execution.

## 24.15 Second authorization

Another authorization cannot overwrite or coexist with the unresolved execution context.

## 24.16 Second execution after EXECUTED

Execution evidence cannot be reused for another swap.

## 24.17 Failed execution / catch-retry

Prove the production ExerciseRouter does not catch a failed protected swap and retry or continue against the restored AUTHORIZED context.

## 24.18 Cross-transaction replay

No authorization/execution evidence can be reused in a later transaction.

## 24.19 Commitment/service/actor/Beneficiary substitution

Existing F8A bindings must remain intact; F8B must not create an execution path that can substitute another commitment, service, exerciser, or Beneficiary.

## 24.20 Persistent-state non-interference

After F8B execution evidence:

```text
Remaining unchanged
authoritative O unchanged
```

No fulfillment is recorded.

---

# 25. G8B — O2 Exact-Output Execution / Execution-Evidence Gate

F8B is complete only when the implementation and evidence establish all of the following.

### G8B-1 — Authorization prerequisite

No swap obtains O2 semantics without an existing Hook-owned AUTHORIZED context.

### G8B-2 — Router non-authority

ExerciseRouter identity alone is insufficient to classify O2 or establish execution.

### G8B-3 — Exact operation identity

O2 requires exact agreement on:

```text
configured ExerciseRouter callback sender
service / PoolId
protected direction
exact-output mode
exact requested q
qualification sqrtPriceLimitX96
```

### G8B-4 — O2/O3 exclusion

With EMPTY context, ordinary swaps retain the existing O3 path.

With unresolved O2 causal state, only the exact authorized O2 path may proceed; mismatching swaps reject rather than silently becoming O3.

### G8B-5 — BeforeSwap is not execution

A matching `beforeSwap` establishes only the in-flight execution attempt and cannot produce EXECUTED.

### G8B-6 — Minimal in-flight guard

`EXECUTING` or an equivalent minimal transaction-scoped mechanism binds the accepted O2 `beforeSwap` to the expected authoritative `afterSwap` without introducing duplicate economic truth.

### G8B-7 — PoolManager execution authority

Only the immutable PoolManager callback path can advance execution evidence.

Router assertions, hookData, arbitrary calldata, or external success flags cannot.

### G8B-8 — Actual protected output

`afterSwap` uses authoritative pinned-v4 `BalanceDelta` semantics to derive actual protected output in the configured output currency.

### G8B-9 — Exact actual `q`

Only:

```text
actual protected output == +q
```

can establish EXECUTED.

Partial, excessive, wrong-sign, or wrong-currency-side evidence rejects.

### G8B-10 — Correct causal transition

Only:

```text
EXECUTING
-> matching authoritative afterSwap
-> actual protected output == q
-> EXECUTED
```

is permitted.

No:

```text
EMPTY -> EXECUTED
AUTHORIZED -> EXECUTED from intent/beforeSwap
second EXECUTED transition
execution overwrite
```

is permitted.

### G8B-11 — Exactly one swap

One authorization permits exactly the single canonical protected swap path.

Nested/multiple/second execution paths reject.

### G8B-12 — Failed execution atomicity

A failed O2 execution propagates through the production ExerciseRouter and cannot be caught and converted into a retry or continuing O2 transaction.

No false or reusable execution evidence survives failure.

### G8B-13 — Predicted/actual equivalence

For successful real-PoolManager execution:

```text
F5 predicted post-state
==
actual PoolManager post-state
```

and:

```text
predicted S′
==
authoritative S from actual post-state
```

within the existing authoritative derivation model.

Test-only mechanical delta closure may be used where needed without implementing F8C production semantics.

### G8B-14 — Commitment state unchanged

F8B does not change:

```text
Remaining
persistent commitment terms
authoritative O by fulfillment
```

### G8B-15 — No Beneficiary-delivery assumption

EXECUTED does not mean the Beneficiary received q.

No production protected-output delivery is implemented in F8B.

### G8B-16 — No input-settlement assumption

EXECUTED does not mean actual input debt is settled.

No `maxInput` enforcement is implemented.

### G8B-17 — No fulfillment/finalization

F8B does not implement F8D.

### G8B-18 — O3 regression safety

Existing F6B O3 backing enforcement remains intact and cannot be bypassed through the new O2 classifier.

### G8B-19 — Prior gates preserved

Previously closed F4/F5/F6A/F6B/F7/F8A behavior remains green.

### G8B-20 — Verification breadth

Appropriate:

```text
unit
fuzz
transition/adversarial
real-PoolManager integration
predicted-vs-actual differential
```

evidence passes.

Do not prematurely implement the later full GI stateful invariant campaign.

---

# 26. Verification Technique Boundary

The canonical proof obligations above are mandatory.

The exact test file organization is downstream implementation discretion unless already constrained by repository conventions.

Use the narrowest effective combination of:

```text
unit tests
fuzz tests
integration tests
mutation-style negative cases
callback/order adversarial tests
differential tests
targeted harnesses where justified
```

Do not create a broad new invariant handler merely because this slice has adversarial requirements.

The full stateful invariant campaign remains:

```text
GI — Full Stateful Invariant Gate
```

after complete F8 and before G9.

---

# 27. Responsibility-Leakage Gate

Before declaring F8B complete, explicitly inspect the production diff and answer:

1. Did F8B introduce any second authoritative source for commitment identity?
2. Did F8B duplicate S/S′/O derivation?
3. Did the ExerciseRouter acquire economic truth?
4. Did hookData acquire authority it did not previously have?
5. Did F8B introduce a persistent execution ledger?
6. Did F8B bind snapshots that later logic could derive authoritatively?
7. Did F8B implement input settlement?
8. Did F8B implement `actualInput <= maxInput`?
9. Did F8B implement Beneficiary delivery?
10. Did F8B reduce Remaining?
11. Did F8B reduce O as fulfillment?
12. Did F8B claim fulfillment or finalization?
13. Did test-only delta closure leak into production semantics?
14. Did O2 classification weaken ordinary O3 enforcement?

Any affirmative answer requires justification against this prompt or correction before G8B can pass.

---

# 28. Single Normative Ownership Review

At completion, confirm:

```text
commitment truth                 -> existing Hook commitment storage
economic derivations             -> existing F5 derivation kernel
ordinary O3 enforcement          -> existing F6A/F6B path
exercise authorization           -> F8A Hook logic
authorized causal identity       -> F8A Hook context
actual AMM execution             -> PoolManager
O2 interpretation                -> F8B Hook logic
actual-output execution evidence -> F8B Hook interpretation of PoolManager delta
input debt settlement            -> future F8C
maxInput enforcement             -> future F8C
Beneficiary delivery             -> future F8C
fulfillment / Remaining change   -> future F8D
```

Do not blur these owners.

---

# 29. Semantic Minimality Review

The preferred F8B causal addition is only:

```text
EXECUTING
```

or its exact equivalent if the current implementation representation makes another minimal encoding clearer.

Do not add:

```text
execution nonce
execution hash
actualInput snapshot
S snapshot
S′ snapshot
O snapshot
Remaining snapshot
delivery flag
settlement flag
fulfillment flag
persistent execution status
```

without a demonstrated requirement.

If implementation mechanics prove one additional transaction-scoped binding is genuinely necessary, document why the existing context plus callback facts are insufficient before adding it.

---

# 30. Economic Atomicity Review

Confirm that:

```text
F8B execution evidence is transaction-scoped
```

and that later F8C/F8D failure can still cause the entire exercise to revert.

No incomplete O2 transaction may leave irreversible F8B economic state.

---

# 31. Required Final Claude Report

When implementation and testing are complete, report:

1. production files changed;
2. test/support files changed;
3. exact F8B causal-state implementation;
4. exact `beforeSwap` O2 matching logic;
5. exact `afterSwap` actual-output derivation;
6. how protected zero-for-one and one-for-zero output are interpreted;
7. how partial-output failure is proven;
8. how nested/second/replay paths are prevented;
9. how failed swap propagation/caught-revert risk is handled;
10. whether any extra causal field beyond `EXECUTING` was required and why;
11. how real-PoolManager integration testing closes deltas without introducing production F8C behavior;
12. predicted-versus-actual F5 differential evidence;
13. confirmation Remaining/O remain unchanged;
14. confirmation no settlement/delivery/finalization behavior was introduced;
15. exact test commands run and their results;
16. prior suites/regression evidence;
17. Claude's own G8B item-by-item assessment;
18. any unresolved concern that should prevent G8B closure.

Do not declare the project ready for F8C merely because your own tests pass.

ChatGPT will independently review the implementation and independently determine whether G8B closes.

---

# 32. Completion Boundary

This Claude session ends at:

```text
F8B implemented
+
G8B evidence produced
+
session-12-log.md updated
```

Stop at the F8B completion boundary.
