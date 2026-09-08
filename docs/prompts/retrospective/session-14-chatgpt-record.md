# Session 14 — ChatGPT Reasoning Record

## F8D — O2 Causal Finalization / Remaining Reduction

**Project:** Standby
**Session:** 14
**Implementation slice:** F8D — O2 Causal Finalization / Remaining Reduction
**Final gate:** G8D — PASS / CLOSED
**Next implementation frontier:** GI — Full Stateful Invariant Verification
**Status:** Non-normative retrospective evidence

---

## 1. Purpose of This Record

This document is a **non-normative curated record of the substantive user ↔ ChatGPT reasoning associated with F8D**.

It preserves the reasoning that materially affected:

- reconstruction of the F8D responsibility;
- separation of F8D from F8A, F8B, F8C, F7, and F6B;
- derivation of final backing verification;
- authoritative fulfillment mutation;
- causal-context consumption;
- replay, substitution, stale-context, nested-call, and atomicity analysis;
- derivation of G8D;
- preparation and clean-rule review of the Claude implementation prompt;
- independent review of Claude's actual implementation and tests;
- review of the Foundry gas-limit infrastructure correction;
- independent G8D closure;
- post-F8D / pre-GI gas and coverage baseline;
- interpretation of the transition from implementation slices to full stateful invariant verification.

This record does not modify or supersede the frozen Standby artifacts.

Where exact conversational wording is not reproduced, the material is preserved as a **recovered decision record**.

---

# 2. Starting State

Session 14 began after independent completion of F8C.

The implementation ladder entering the session was:

```text
F0   Foundation                                      COMPLETE
F1   Deterministic Economic Fixture                  COMPLETE
F2   Eligibility Registry                            COMPLETE
F3   StandbyHook Trust + PES Configuration           COMPLETE
F4   Commitment Storage / Bounded References         COMPLETE
F5   Authoritative Derivation Kernel                 COMPLETE
F6A  Preliminary O3 Enforcement                      COMPLETE
F7   O1 Commitment Admission                         COMPLETE
F6B  O3 Bounded Enforcement                          COMPLETE
F8A  Exercise Authorization                          COMPLETE
F8B  Protected PoolManager Execution                 COMPLETE
F8C  Authoritative Settlement / Direct Delivery      COMPLETE

F8D  O2 Causal Finalization / Remaining Reduction    NEXT
GI   Full Stateful Invariant Verification            PENDING
F9   Canonical Acceptance                            PENDING
F10  Demo Instrumentation                            PENDING
```

The immediately preceding gate was:

> **G8C — PASS / CLOSED**

The central question for Session 14 was therefore not how an exercise becomes authorized, how the protected swap executes, or how settlement and delivery occur.

Those responsibilities already had normative owners.

The remaining question was:

> **What exact authoritative consequence converts a causally proven, executed, settled, and directly delivered O2 exercise into durable fulfillment of the corresponding commitment?**

---

# 3. Responsibility Inherited from F8A–F8C

The F8D derivation began by reconstructing what the previous three O2 slices had already established.

## 3.1 F8A — Exercise Authorization

F8A established Hook-owned transaction-scoped causal context binding the exercise to:

- service / pool identity;
- commitment identity;
- configured ExerciseRouter;
- authenticated originating exerciser;
- authoritative Beneficiary;
- exact exercise quantity `q`;
- causal lifecycle state.

The lifecycle was conceptually:

```text
EMPTY
  ↓
AUTHORIZED
  ↓
EXECUTING
  ↓
EXECUTED
  ↓
consumed / EMPTY
```

F8A owned authorization and prospective exercisability.

It did **not** own fulfillment reduction.

---

## 3.2 F8B — Protected PoolManager Execution

F8B established the exact protected execution path.

It required an `AUTHORIZED` context and performed the canonical protected exact-output swap using the bound:

- pool;
- protected direction;
- quantity `q`;
- supporting boundary;
- ExerciseRouter path.

The Hook transitioned the causal context through:

```text
AUTHORIZED
    ↓
EXECUTING
    ↓
EXECUTED
```

The authoritative callback evidence proved that the exact protected output quantity had executed.

F8B did **not** own:

- settlement;
- Beneficiary delivery;
- commitment fulfillment.

---

## 3.3 F8C — Settlement and Direct Delivery

F8C began from the proven `EXECUTED` context.

It:

- derived the actual input debt from `BalanceDelta`;
- enforced the exerciser's `maxInput`;
- used the bound exerciser as payer;
- settled the exact input debt to PoolManager;
- proved the input-side delta was zero;
- caused PoolManager to transfer the exact protected output `q` directly to the bound Beneficiary;
- proved the output-side delta was zero.

After F8C:

```text
protected execution     proven
input settlement        complete
Beneficiary delivery    complete
causal context           EXECUTED
Remaining                unchanged
```

This exposed the exact remaining F8D responsibility.

---

# 4. The F8C Completion Barrier and Why F8D Was Necessary

A particularly important observation entering F8D was the existing production completion barrier.

The top-level exercise path could not successfully return while the Hook-owned causal context remained unconsumed.

Therefore, F8C by itself produced an intentionally incomplete transaction:

```text
execute
  ↓
settle
  ↓
deliver
  ↓
context still EXECUTED
  ↓
top-level completion barrier fails
  ↓
whole transaction reverts
```

This was not treated as an F8C defect.

It was evidence that fulfillment had not yet occurred.

F8D needed to complete the causal chain such that:

```text
execute
  ↓
settle
  ↓
deliver
  ↓
finalize
  ↓
Remaining reduced
  ↓
context consumed
  ↓
completion barrier passes naturally
```

The barrier therefore did not need to be weakened, bypassed, or redesigned.

F8D needed to satisfy it.

---

# 5. Exact F8D Responsibility

The resulting compact responsibility statement was:

> **F8D converts one transaction-local, causally proven, executed + settled + directly delivered O2 exercise into exactly one durable fulfillment consequence by verifying actual post-execution backing, reducing authoritative commitment Remaining exactly by the context-bound `q`, and consuming the causal evidence exactly once.**

This formulation became the anchor for the rest of the derivation.

---

# 6. Authoritative Starting State

F8D must begin from the Hook-owned causal context in exactly:

```text
EXECUTED
```

It must not accept:

```text
EMPTY
AUTHORIZED
EXECUTING
```

as sufficient evidence.

`EXECUTED` means that the exact protected PoolManager execution already occurred through the F8B-owned authoritative path.

F8C then ensures settlement and Beneficiary delivery occur before finalization is invoked in the production router sequence.

Thus F8D does not independently reconstruct the entire exercise from caller claims.

It consumes already-established causal evidence.

---

# 7. Caller-Supplied Facts Were Minimized

A major design question was what information finalization should accept from the caller.

The preferred conceptual surface was:

```solidity
finalizeExercise(uint256 commitmentId)
```

The reasoning was that finalization should **not** accept independently caller-supplied versions of:

- `q`;
- Beneficiary;
- service identity;
- pool identity;
- exerciser.

Those facts already exist in the Hook-owned causal context.

The supplied `commitmentId` acts only as the requested target and must equal the commitment identity already proven by the context.

Therefore:

```text
caller says which commitment it intends to finalize
                ↓
Hook verifies that identity against causal context
                ↓
all economic facts come from authoritative state/context
```

This materially reduces substitution surface.

---

# 8. Final Backing Must Use Actual Post-Execution State

One of the central F8D derivations concerned backing.

F8A had already checked prospective backing before authorization.

That was insufficient for finalization.

By F8D, the protected execution has actually happened.

Therefore finalization must use **actual post-execution authoritative PoolManager state**.

The derived variables were:

```text
q        = exact quantity bound in causal context
Rcurrent = current authoritative Remaining
Ocurrent = current authoritative aggregate obligation
Sactual  = current post-execution Supporting Capacity
```

Then:

```text
require q <= Rcurrent

Ofinal = Ocurrent - q

require Sactual >= Ofinal
```

Equality must pass.

The resulting final backing relation is:

```text
Sactual >= Ocurrent - q
```

This is deliberately different from F8A's prospective backing check.

---

# 9. Why Prospective Backing Could Not Be Reused

Several alternatives were rejected as insufficient:

```text
F8A prospective S'
cached pre-execution capacity
router estimate
F8B output proof alone
caller-supplied backing information
```

The reason was temporal authority.

F8A asks:

> Is this exercise safe to authorize prospectively?

F8D asks:

> After the actual protected execution and delivery sequence, is the authoritative system state still sufficiently backed once this exact fulfillment is recognized?

Those are different questions at different causal positions.

The final check therefore belongs to current authoritative post-state.

---

# 10. Exact Fulfillment Mutation

The persistent economic mutation derived for F8D was intentionally minimal:

```text
Remaining_after = Remaining_before - q
```

after all finalization checks pass.

The original commitment quantity remains unchanged.

No independent fulfilled amount is required because it is derivable:

```text
Fulfilled = Original - Remaining
```

No separate completion flag is required because completion is derivable:

```text
Completed ⇔ Remaining == 0
```

No additional aggregate-obligation storage is required because aggregate obligation remains derived from binding Remaining values.

This preserves the existing fact-and-consequence state model.

---

# 11. Aggregate Obligation Is a Consequence, Not a Second Mutation

A key semantic distinction was preserved:

F8D does not perform:

```text
Remaining -= q
aggregateObligation -= q
```

as two independent authoritative mutations.

Instead:

```text
Remaining -= q
        ↓
aggregate O is re-derived
        ↓
aggregate O falls by q as a consequence
```

This prevents duplicated economic truth.

The authoritative persistent fact remains commitment Remaining.

---

# 12. Partial and Full Fulfillment

The same rule handles both cases.

## Partial

```text
Rbefore > q

Rafter = Rbefore - q
Rafter > 0
```

The commitment remains binding.

A subsequent exercise requires a fresh F8A authorization and fresh causal context.

## Full

```text
Rbefore == q

Rafter = 0
```

The commitment is exhausted.

No additional completed state is needed.

This was important for preserving state minimality.

---

# 13. Causal Evidence Must Be Consumed Exactly Once

Successful finalization must also consume the Hook-owned causal context.

Conceptually:

```text
EXECUTED
    ↓
final backing verified
    ↓
Remaining reduced
    ↓
context consumed
    ↓
EMPTY
```

The finalization transaction must not durably contain only one of:

```text
Remaining reduction
context consumption
```

Because both occur in the same EVM transaction, any later revert unwinds both.

This gave F8D exact-once semantics without introducing another persistent replay registry.

---

# 14. Replay Analysis

After successful finalization:

```text
context = EMPTY
```

Therefore replay cannot reuse the prior proof.

A second finalization attempt has no valid `EXECUTED` context.

This provides the exact-once causal boundary.

The system does not need a separate:

```text
finalized[exerciseId]
```

mapping merely to prevent replay.

The causal evidence itself is consumable.

---

# 15. Substitution Analysis

The derivation explicitly examined several substitution threats.

## Quantity substitution

Rejected because `q` comes from Hook-owned causal context.

## Beneficiary substitution

Rejected because Beneficiary is already bound in context and F8C delivers directly to that Beneficiary.

## Commitment substitution

Rejected because the requested commitment identity must equal the context commitment identity.

## Service / pool substitution

Rejected because those facts are already causally bound.

## Exerciser substitution

Rejected because the authenticated originating exerciser is bound earlier and is not reintroduced by the finalizer.

The finalization surface therefore does not create a second independent source of exercise facts.

---

# 16. Stale Context and Sequential Exercise

A successful top-level exercise cannot leave the context active.

F8D consumes it.

The existing ExerciseRouter completion barrier independently requires the exercise to finish without lingering causal state.

Therefore a successful exercise cannot carry stale causal evidence into another successful top-level exercise.

For a partially fulfilled commitment:

```text
exercise q1
  ↓
finalize q1
  ↓
consume context
  ↓
Remaining = R0 - q1
  ↓
new top-level exercise
  ↓
fresh F8A authorization
```

The second exercise cannot reuse the first exercise's causal proof.

---

# 17. Nested Exercise / Reentrancy Reasoning

The transaction-scoped causal lifecycle also constrains overlapping exercises.

A non-empty causal context represents an exercise already in progress.

A nested or overlapping exercise cannot simply overwrite that context and establish an unrelated authorization.

This preserved the one-causal-exercise-at-a-time discipline already established by F8A and the ExerciseRouter path.

F8D therefore did not need to invent another reentrancy mechanism.

---

# 18. Whole-O2 Atomicity

The complete O2 production path after F8D becomes:

```text
authorize
    ↓
protected PoolManager execution
    ↓
settle exact input debt
    ↓
direct Beneficiary delivery
    ↓
verify final actual backing
    ↓
Remaining -= q
    ↓
consume causal context
    ↓
top-level completion barrier
    ↓
success
```

Any failure during finalization reverts the enclosing transaction.

Therefore the system cannot durably retain:

```text
delivery without fulfillment
```

or:

```text
fulfillment without delivery
```

for the production O2 path.

This completed the economic atomicity requirement.

---

# 19. Responsibility-Leakage Gate

Before implementation, F8D was explicitly checked against neighboring responsibilities.

## F8A retains ownership of

- exercise authority;
- eligibility;
- validity window;
- Remaining availability at authorization;
- prospective backing;
- causal-context establishment.

## F8B retains ownership of

- exact protected PoolManager swap;
- direction;
- quantity execution;
- execution callback proof;
- transition to `EXECUTED`.

## F8C retains ownership of

- actual input debt;
- `maxInput`;
- payer identity;
- PoolManager settlement;
- direct Beneficiary delivery;
- delta closure.

## F7 retains ownership of

- O1 commitment admission.

## F6B retains ownership of

- ordinary O3 bounded backing enforcement.

F8D owns none of those behaviors.

Its responsibility begins only after the causally proven protected execution and ends after exact fulfillment plus context consumption.

The responsibility-leakage gate passed.

---

# 20. G8D Derivation

Before Claude implementation, G8D was derived as six independent evidence families.

## G8D-A — Causal Authority

Required evidence that:

1. finalization is Hook-owned;
2. only the authorized active O2 path may finalize;
3. context must be exactly `EXECUTED`;
4. requested commitment must equal context commitment;
5. `q` comes from context;
6. caller cannot substitute Beneficiary, service, pool, exerciser, or quantity;
7. commitment state is reread authoritatively.

---

## G8D-B — Final Economic Backing

Required:

```text
q <= current Remaining

Sactual = actual current post-execution Supporting Capacity

Ocurrent = current authoritative aggregate obligation

Ofinal = Ocurrent - q

Sactual >= Ofinal
```

with equality accepted.

Prospective backing could not substitute for this check.

---

## G8D-C — Exact Fulfillment

Required:

```text
Remaining_after = Remaining_before - q
```

with:

- Original unchanged;
- partial fulfillment exact;
- full fulfillment reaching zero;
- completion derived from Remaining;
- no independent completion flag;
- aggregate obligation changing only as a consequence of Remaining.

---

## G8D-D — Exact-Once Consumption

Required:

- successful finalization consumes `EXECUTED`;
- no reusable causal context remains;
- replay fails;
- cross-commitment finalization fails;
- stale context cannot survive a successful top-level exercise;
- non-O2 activity cannot manufacture valid finalization evidence.

---

## G8D-E — Atomicity

Required any finalization failure to unwind:

- protected execution;
- settlement;
- Beneficiary delivery;
- Remaining mutation;
- context mutation.

No durable delivery without fulfillment and no durable fulfillment without delivery.

---

## G8D-F — Integration / Regression

Required evidence for:

- partial fulfillment;
- full fulfillment;
- equality backing;
- failure paths;
- replay;
- natural satisfaction of the existing production completion barrier;
- preservation of F8A/F8B/F8C behavior;
- existing regression suite;
- fuzz/integration evidence;
- canonical terminal state.

The canonical A4 terminal state remained:

```text
S = 15,000
O = 0
Remaining = 0
Beneficiary +50,000
```

---

# 21. Claude Prompt and Clean-Rule Review

A slice-specific Claude implementation prompt was prepared.

The user then explicitly challenged the prompt against the established clean rule:

> **CLAUDE.md owns permanent operating behavior.**
>
> **.claude/rules/\* owns permanent Solidity/testing conventions.**
>
> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

The prompt was reviewed for leakage.

Generic testing/configuration instructions were reduced or delegated to their permanent owners.

The resulting Session 14 prompt remained responsible only for:

- F8D objective;
- F8D semantic boundary;
- required authoritative facts;
- final backing requirement;
- exact fulfillment mutation;
- causal consumption;
- F8D-specific replay/atomicity constraints;
- G8D evidence;
- F8D-specific prohibitions;
- authorized scope;
- completion boundary.

This preserved the clean separation between permanent repository behavior and slice-local implementation authority.

---

# 22. Claude Implementation Result

Claude implemented F8D primarily in:

```text
src/StandbyHook.sol
src/ExerciseRouter.sol
```

with corresponding test/harness changes.

The production ExerciseRouter sequence became conceptually:

```text
unlock
  ↓
execute protected swap
  ↓
resolve settlement and delivery
  ↓
request Hook finalization
  ↓
existing completion barrier
```

The barrier was not weakened.

F8D instead made the valid production exercise satisfy it naturally.

---

# 23. Independent Review — Hook Finalization

ChatGPT independently reviewed the actual changed production code rather than accepting Claude's advisory gate assessment.

The reviewed Hook finalization behavior:

1. reads the Hook-owned exercise authorization context;
2. requires state `EXECUTED`;
3. requires `msg.sender` to equal the bound ExerciseRouter;
4. requires requested commitment identity to equal the context commitment;
5. rereads current commitment Remaining;
6. requires context `q <= Remaining`;
7. verifies final actual backing;
8. writes:

```text
Remaining := Remaining - q
```

9. consumes the causal context;
10. emits an observational finalization event.

The event does not create independent economic state.

---

# 24. Independent Review — Final Backing

The reviewed backing helper derives:

```text
actualCapacity = current Supporting Capacity

finalObligation = current aggregate obligation - q
```

and rejects:

```text
actualCapacity < finalObligation
```

Thus equality passes.

This uses actual current state rather than F8A's prospective derivation.

---

# 25. Structural Observation: `_aggregateObligation() - q`

During independent review, particular attention was given to the implementation's direct subtraction:

```solidity
_aggregateObligation() - q
```

There is no separate explicit:

```text
q <= aggregate O
```

check immediately before this subtraction.

The review concluded this was not a gate defect because successful finalization first establishes:

```text
q <= current Remaining
```

for the authentic context-bound commitment.

That still-binding commitment contributes its Remaining to authoritative aggregate obligation.

Therefore:

```text
q <= Remaining_of_binding_commitment <= aggregate O
```

under the authoritative commitment model.

Additionally, Solidity checked arithmetic would fail closed if the structural assumption were violated.

This was preserved as a useful implementation-review observation rather than treated as a reason to duplicate a derived check.

---

# 26. Independent Review — Context Consumption

The context-consumption implementation clears all transaction-scoped causal fields and returns the lifecycle to `EMPTY`.

This means successful finalization leaves no reusable exercise proof.

The existing top-level completion barrier therefore succeeds naturally after valid finalization.

Replay attempts cannot reuse the prior context.

This matched the F8D derivation.

---

# 27. Independent Review — Test Architecture

The F8D test changes included purpose-built harnesses to preserve responsibility boundaries.

Notably:

```text
NonFinalizingExerciseRouter
```

preserved a production-like exercise path without finalization so prior F8C behavior could still be tested.

```text
MisdirectedFinalizationRouter
```

made finalization failure constructible behind a real exercise path, allowing atomic unwind to be verified.

This was preferable to weakening production behavior merely to make failure cases testable.

---

# 28. Independent Review — F8D Evidence

The reviewed tests covered, among other things:

- partial fulfillment;
- full fulfillment;
- minimal one-unit fulfillment;
- sequential partial exercises;
- exact Remaining reduction;
- canonical A1→A4 sequence;
- equality backing;
- actual post-state backing;
- replay refusal;
- absent causal context;
- wrong finalizer;
- cross-commitment finalization;
- ordinary swaps not causing fulfillment;
- direct token transfer not causing fulfillment;
- refused exercises leaving no residue;
- unpayable exercises leaving no residue;
- misdirected finalization unwinding the complete exercise;
- context consumption;
- fuzzing over admissible exercise quantities;
- sequential remainder behavior.

Repository verification reported:

```text
58 suites
539 tests passed
0 failed
0 skipped
```

with the CI profile also passing.

---

# 29. Foundry / HookMiner Infrastructure Issue

During full-suite verification, the deterministic fixture encountered a local Forge gas-budget failure in the pinned Hook address-mining procedure.

The cause was not Standby protocol execution.

The fixture's `HookMiner.find` repeatedly hashes Hook creation code while searching for a salt producing the required Uniswap v4 Hook permission bits.

As the Hook creation code grew through implementation, the deterministic search required more local execution budget.

A diagnostic run with a larger Forge gas limit allowed the deterministic fixture to complete successfully.

Claude therefore introduced an elevated local Foundry execution gas limit.

---

# 30. Independent Review of the Gas-Limit Change

Because this change was adjacent to F8D rather than part of F8D semantics, it received a separate responsibility review.

The conclusion was:

> **Infrastructure/configuration change — ACCEPTABLE.**

The setting affects the local Foundry / Forge execution budget used by tests and local script simulation.

It does not change:

- Standby protocol semantics;
- Solidity source behavior;
- generated contract semantics;
- deployed-chain block gas limits;
- deployed contract gas rules;
- F8D responsibility.

The change was necessary to keep the deterministic regression environment executable as Hook bytecode evolved.

It was therefore accepted as verification infrastructure rather than responsibility leakage.

---

# 31. Gas-Limit Wording Precision

A wording issue was identified during that review.

Calling the setting simply a:

```text
test gas limit
```

was too narrow because Forge execution configuration may also apply to local script simulation.

The accepted terminology became:

```text
local Forge execution gas limit
```

or equivalently:

```text
local Foundry execution budget used by Forge tests and local script simulation
```

A narrowly scoped Claude follow-up corrected the documentation/comment wording without changing configuration values or behavior.

A final stale phrase in the Session 14 log was later corrected from:

```text
test gas limit
```

to:

```text
local Forge execution gas limit
```

No verification rerun was required for this documentation-only correction.

---

# 32. Independent G8D Determination

After independent review of the actual implementation, tests, causal behavior, atomicity, and adjacent infrastructure correction:

```text
G8D-A — Causal Authority             PASS
G8D-B — Final Economic Backing       PASS
G8D-C — Exact Fulfillment            PASS
G8D-D — Exact-Once Consumption       PASS
G8D-E — Atomicity                    PASS
G8D-F — Integration / Regression     PASS
```

Therefore:

> **G8D — PASS / CLOSED**

and:

> **F8D — O2 Causal Finalization / Remaining Reduction: COMPLETE**

This determination was independent of Claude's advisory assessment.

---

# 33. Post-F8D / Pre-GI Engineering Baseline

After G8D closure, the user raised when gas snapshots and coverage should be captured.

The conclusion was that the immediate post-F8D checkpoint was particularly valuable because F8D completes the planned O1/O2/O3 production path.

The sequence chosen was:

```text
F8D implementation complete
        ↓
independent G8D closure
        ↓
post-F8D / pre-GI engineering baseline
        ↓
project-status update
        ↓
Session 14 retrospective / closeout
        ↓
GI
```

The baseline was deliberately captured before GI altered the verification surface.

---

# 34. Separate Engineering Reports

The user asked whether gas and coverage results should live only in the Claude session log or in separate reports.

The conclusion was to create:

```text
docs/reports/gas-snapshot.md
docs/reports/coverage-summary.md
```

while retaining only audit chronology in:

```text
docs/prompts/session-14-log.md
```

The distinction is:

```text
session-14-log.md
    = chronological implementation/evidence record

gas-snapshot.md
    = human-readable gas baseline

coverage-summary.md
    = human-readable coverage baseline

.gas-snapshot
    = machine-comparable Foundry gas baseline
```

Both Markdown reports explicitly identify themselves as:

> **Non-normative engineering evidence.**

This preserved artifact responsibility.

---

# 35. Baseline Prompt and Clean Rule

The first baseline prompt was reviewed against the same clean rule used for implementation prompts.

It was intentionally simplified.

General operating instructions were removed.

The final prompt owned only:

- post-F8D / pre-GI measurement objective;
- authorized reports;
- reproducibility evidence;
- requested gas and coverage measurements;
- interpretation boundary;
- prohibitions;
- authorized files;
- Session 14 log update;
- completion report;
- completion boundary.

It explicitly prohibited:

- production-code changes;
- test changes;
- harness changes;
- gas optimization;
- coverage-driven test additions;
- configuration changes;
- frozen-artifact changes;
- project-status changes;
- GI work.

This was treated as a Session 14 evidence follow-up rather than another implementation slice.

---

# 36. Gas Baseline Result

The post-F8D / pre-GI gas report successfully captured:

```text
forge snapshot
```

with:

```text
58 suites
539 tests passed
0 failed
0 skipped
```

and preserved:

```text
.gas-snapshot
```

as the machine-comparable artifact.

The baseline correctly recorded that the measured state was the current uncommitted Session 14 F8D working tree rather than falsely attributing the results to the preceding F8C `HEAD`.

The report also captured deployed contract size.

At this checkpoint:

```text
StandbyHook runtime size = 21,996 bytes
remaining EIP-170 margin = 2,580 bytes
```

This was recorded as engineering evidence, not as an optimization requirement.

---

# 37. `--gas-report` Measurement Limitation

A supplementary attempt using:

```text
forge test --gas-report
```

did not provide a valid whole-path O2 measurement.

The isolated execution behavior used for gas attribution caused transaction-scoped EIP-1153 causal evidence to disappear between calls that logically belong to one exercise transaction.

The resulting failures were therefore measurement artifacts rather than Standby defects.

The invalid per-function gas tables were not used.

No production or test changes were made to accommodate the measurement tool.

This was considered the correct response: preserve the limitation rather than distort the implementation to satisfy instrumentation.

---

# 38. Why `.gas-snapshot` Is Version-Controlled

The user explicitly asked whether `.gas-snapshot` should be committed or ignored.

The conclusion was:

> **Commit `.gas-snapshot`.**

It is not being treated as disposable generated output.

It is the machine-comparable representation of the post-F8D / pre-GI baseline.

The repository therefore preserves:

```text
.gas-snapshot
docs/reports/gas-snapshot.md
docs/reports/coverage-summary.md
```

The snapshot creates no automatic gas-regression gate.

Future changes may be compared against it without treating every delta as a defect.

---

# 39. Coverage Baseline Result

Coverage completed successfully under instrumentation:

```text
58 suites
539 tests passed
0 failed
0 skipped
```

Repository-wide Foundry results were recorded separately by dimension rather than collapsed into a single percentage.

The more relevant protocol-core aggregate was:

```text
Lines       99.42%
Statements  98.33%
Branches    91.35%
Functions  100.00%
```

These figures were explicitly not treated as semantic proof.

The coverage report preserved the distinction:

```text
coverage measurement
    ≠ semantic correctness

high coverage
    ≠ invariant proof

uncovered code
    ≠ automatic protocol defect
```

This distinction became an important process result.

---

# 40. Coverage as Diagnostic Evidence, Not a Gate

The user and ChatGPT explicitly rejected the idea that coverage percentage should become a new verification gate merely because it had now been measured.

Coverage was instead used diagnostically to expose potentially interesting stateful verification surfaces.

The report identified several uncovered or partially covered production areas.

Importantly, it did not automatically classify those paths as defects.

This preserved the hierarchy:

```text
frozen invariant
    ↓
derived verification obligation
    ↓
test evidence
```

rather than reversing it into:

```text
coverage hole
    ↓
invent new protocol requirement
```

---

# 41. Potential GI Inputs Surfaced by Coverage

The coverage baseline identified potential areas for later GI examination, including:

1. untrusted-perimeter liquidity removal;
2. nested exercise attribution;
3. causal-position refusal on an authorization read surface;
4. extreme tick-bound clamping in prospective swap derivation;
5. the unresolved exercise-delta fail-closed guard.

The report explicitly classified these as:

> **potential GI inputs, not established GI requirements**

and deferred their interpretation to GI's own derivation against the frozen invariants and testing strategy.

This was accepted as the correct responsibility boundary.

No GI derivation was performed during Session 14.

---

# 42. Transition Question: Is Production Implementation Now Complete?

Immediately before this retrospective, the user asked:

> If GI is the full stateful invariant gate, does that mean it would only include tests, and our Hook contract is basically completed pending any significant issues found during the testing?

The answer was essentially yes, with an important qualification.

F0–F8D now complete the planned production behavior for the canonical Standby realization.

Therefore the intended transition is:

```text
F0–F8D
production behavior implementation
        ↓
G8D PASS / CLOSED
        ↓
planned production semantics complete
        ↓
GI
full stateful invariant verification
```

GI is not intended to be another feature-development slice.

Its planned work should primarily be verification-side infrastructure such as:

- stateful invariant handlers;
- adversarial action generation;
- ghost/accounting state where justified;
- bounds/selectors;
- invariant assertions;
- sequence-sensitive verification.

---

# 43. GI Does Not Own New Protocol Semantics

A key responsibility principle emerged from this transition:

> **GI is a verification gate, not a new semantic owner.**

The default expectation entering GI is therefore:

```text
production code is feature-complete
```

not:

```text
GI is where remaining Hook behavior will be designed
```

GI should attempt to break the completed realization against the already-frozen invariants.

It should not introduce new production behavior merely because an invariant test would be easier to write that way.

---

# 44. What Happens If GI Finds a Real Defect?

Production code is not declared immune from correction.

If GI discovers a genuine counterexample, the appropriate sequence is:

```text
GI discovers counterexample
        ↓
identify violated frozen invariant / responsibility
        ↓
trace defect to existing normative owner
        ↓
correct that implementation
        ↓
rerun affected gate/regression evidence
        ↓
continue GI
```

The correction belongs to the responsibility that was implemented incorrectly.

GI itself does not become the semantic owner of the fix.

This distinction prevents stateful testing from becoming an uncontrolled redesign phase.

---

# 45. Methodology Observation — Implementation Convergence

F8D provided another strong example of the previously frozen Implementation Convergence Principle:

> **Implementation Convergence = Semantic Completeness + Responsibility Clarity + Bounded Implementation Discretion + Verification-Gated Dependencies.**

By the time Claude received F8D:

- the authoritative starting state was known;
- causal facts had one owner;
- final backing had one authoritative derivation;
- persistent mutation was exactly defined;
- context consumption was defined;
- neighboring responsibilities were excluded;
- G8D was already derived.

As a result, the implementation required comparatively little semantic discretion.

The independent review found implementation choices that closely matched the pre-implementation derivation.

---

# 46. Methodology Observation — Causal Evidence as Consumable Authority

F8D reinforced a useful architectural pattern:

> Transaction-scoped causal evidence can serve not merely as authorization context but as **consumable proof authority** for a later consequence in the same economic transaction.

The lifecycle:

```text
AUTHORIZED
    ↓
EXECUTING
    ↓
EXECUTED
    ↓
CONSUMED
```

allowed the system to prove:

- which exercise was authorized;
- which protected execution occurred;
- which fulfillment consequence may occur;
- that the proof cannot be reused.

This avoided introducing an independent persistent replay ledger for exercise finalization.

---

# 47. Methodology Observation — Actual-State Finalization

F8D also reinforced a temporal distinction in authoritative derivation:

```text
prospective safety
    ≠
post-execution final safety
```

A prospective authorization proof does not eliminate the need for actual-state verification when durable economic consequences are committed after execution.

The correct authoritative source depends on the causal position at which the question is being asked.

This was central to choosing `Sactual` rather than cached or prospective capacity.

---

# 48. Methodology Observation — Verification Infrastructure Is Not Protocol Semantics

The HookMiner gas-limit issue provided a useful process example.

A verification environment may require configuration changes as the implementation evolves.

Such a change should be reviewed for responsibility leakage rather than automatically accepted or rejected.

The relevant question is:

> Does this change alter the protocol realization, or does it merely allow the intended verification environment to execute the unchanged realization?

For the local Forge execution gas limit, the answer was the latter.

The change was therefore acceptable infrastructure.

---

# 49. Methodology Observation — Measurement Is Not Verification

The gas and coverage baseline produced another useful distinction:

```text
measurement
    ≠
requirement

coverage
    ≠
correctness

gas delta
    ≠
regression

high coverage
    ≠
invariant proof
```

Engineering measurements are useful because they expose characteristics and potential investigation targets.

They should not silently acquire normative authority.

This is why the baseline reports were explicitly classified as non-normative engineering evidence.

---

# 50. Methodology Observation — Coverage Should Feed Derivation, Not Replace It

The post-F8D coverage report surfaced several paths that may be interesting during GI.

The correct process is:

```text
coverage observation
        ↓
GI responsibility derivation
        ↓
compare against frozen invariants/testing strategy
        ↓
determine whether stateful evidence is actually required
```

not:

```text
uncovered branch
        ↓
automatically add invariant test
```

This preserves specification-first verification.

---

# 51. Methodology Observation — Verification Gates Need Not Own Implementation

The transition into GI sharpens another useful distinction.

Earlier gates corresponded closely to implementation slices.

GI is different.

Its purpose is to verify the integrated completed realization through adversarial state sequences.

Therefore a verification gate can legitimately own:

```text
evidence generation
counterexample discovery
stateful adversarial exploration
```

without owning new protocol semantics.

This is an important boundary for the next session.

---

# 52. Final Session 14 State

At Session 14 closeout:

```text
F8D — O2 Causal Finalization / Remaining Reduction
STATUS: COMPLETE

G8D
STATUS: PASS / CLOSED
```

The production realization now contains the complete planned O1/O2/O3 path through durable O2 fulfillment.

The post-F8D / pre-GI engineering baseline has been captured:

```text
Gas baseline       CAPTURED
Coverage baseline  CAPTURED
.gas-snapshot      PRESERVED
```

The project status has been advanced to:

```text
GI — Full Stateful Invariant Verification
next authorized implementation slice / current blocker
```

GI has **not** been started.

---

# 53. Handoff Principle for GI

The next ChatGPT session should begin from the following premise:

> **F0–F8D complete the planned production semantics of the canonical Standby realization. GI is a full stateful invariant verification gate, not a new production-semantic owner. Its responsibility must be derived from the frozen invariants and testing strategy before any invariant implementation prompt is given to Claude.**

The next session should therefore first derive:

- the exact GI verification responsibility;
- which frozen invariants require stateful evidence;
- which actors/actions belong in the state machine explored by handlers;
- what authoritative state and ghost state may be observed;
- which action sequences must be adversarially generated;
- what must remain outside GI;
- how coverage-baseline observations should or should not influence GI;
- the exact GI gate.

Only after that derivation is accepted should Claude receive the GI implementation prompt.

---

# 54. Session 14 Final Determination

Session 14 closes with:

```text
F8D implementation                  COMPLETE
G8D independent review              PASS / CLOSED
O2 causal finalization              COMPLETE
Remaining reduction                 AUTHORITATIVE
causal proof consumption            EXACT-ONCE
whole-O2 atomicity                  VERIFIED
post-F8D gas baseline               CAPTURED
post-F8D coverage baseline          CAPTURED
planned production semantics        COMPLETE
GI                                  NEXT / NOT STARTED
```

The project has therefore transitioned from **planned production-path implementation** to **integrated adversarial stateful verification**.
