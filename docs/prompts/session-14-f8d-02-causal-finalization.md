# Standby — Session 14

## F8D — O2 Causal Finalization / Remaining Entitlement Reduction

You are implementing the next authorized Standby Solidity slice:

> **F8D — O2 Causal Finalization / Remaining Entitlement Reduction**

The preceding implementation slices are complete and independently gate-closed:

```text
F0   — Foundation                                      COMPLETE
F1   — Deterministic Economic Fixture                  COMPLETE
F2   — Eligibility Registry                            COMPLETE
F3   — StandbyHook Trust + PES Configuration           COMPLETE
F4   — Commitment Storage / Bounded References         COMPLETE
F5   — Authoritative Derivation Kernel                 COMPLETE
F6A  — Preliminary O3 Enforcement                      COMPLETE
F7   — O1 Commitment Admission                         COMPLETE
F6B  — O3 Bounded Enforcement                          COMPLETE
F8A  — Exercise Authorization                          COMPLETE
F8B  — Protected PoolManager Execution                 COMPLETE
F8C  — Authoritative Settlement / Direct Delivery      COMPLETE
F8D  — O2 Causal Finalization / Remaining Reduction    CURRENT
GI   — Full Stateful Invariant Verification            NOT AUTHORIZED
F9   — Canonical Acceptance                            NOT AUTHORIZED
F10  — Demo Instrumentation                            NOT AUTHORIZED
```

The last closed gate is:

> **G8C — PASS / CLOSED**

F8D is the only authorized implementation slice.

---

# 1. Clean Rule / Authority Boundary

Apply the established ownership rule:

> **`CLAUDE.md` owns permanent operating behavior.**
>
> **`.claude/rules/*` owns permanent Solidity/testing conventions.**
>
> **This session prompt owns only F8D-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Where permanent operating, Solidity, or testing behavior is already defined in those artifacts, follow it rather than restating or modifying it here.

---

# 2. Working Model

Use the established division of responsibility.

## ChatGPT

ChatGPT is the normative derivation and independent-review partner.

Before Claude implementation, ChatGPT has:

1. reconstructed the exact F8D responsibility from the frozen artifacts and completed implementation slices;
2. identified the authoritative causal and current-state facts F8D must consume;
3. derived the exact post-execution backing requirement;
4. derived the Remaining Entitlement mutation boundary;
5. derived the aggregate-obligation consequence;
6. derived the exact causal-context consumption rule;
7. analyzed replay, substitution, stale-context, nested-call, and relevant reentrancy threats;
8. performed the responsibility-leakage gate;
9. derived G8D before implementation;
10. obtained user acceptance of the F8D boundary and G8D.

After Claude implementation, ChatGPT will:

11. independently review the actual changed production code and tests;
12. verify implementation against G8D;
13. identify any semantic leakage or regression;
14. close G8D only if independently justified;
15. authorize the status-only project-status update only after gate closure.

Claude's completion report and gate assessment are advisory only.

## Claude

Claude is the implementation partner.

For F8D:

1. inspect the current production implementation and tests;
2. implement only the accepted F8D responsibility;
3. preserve already-gated F0–F8C semantics;
4. add the minimum tests required to provide G8D evidence;
5. update the Session 14 implementation log;
6. run the repository-standard verification required by the permanent instructions;
7. stop at the F8D completion boundary.

Claude does not independently redefine F8D semantics or close G8D.

---

# 3. Authoritative Sources

Before modifying production code, inspect the relevant frozen artifacts:

```text
docs/context.md
docs/economic-agreement.md
docs/mechanism.md
docs/spec.md
docs/architecture.md
docs/state-machine.md
docs/invariants.md
docs/testing-strategy.md
docs/uniswap-v4-realization.md
docs/implementation-plan.md
```

Inspect:

```text
docs/project-status.md
```

for current status only.

For already completed implementation slices, the current production code and tests are implementation truth.

Before implementing F8D, inspect the current F8A, F8B, and F8C production implementation and tests because they define the already-gated causal and execution surface that F8D must consume.

If a material discrepancy exists between the frozen artifacts and current implementation, surface it rather than silently redefining protocol semantics.

---

# 4. F8D Objective

The accepted F8D responsibility is:

> **F8D converts one transaction-local, causally proven, executed + settled + directly delivered O2 exercise into exactly one durable fulfillment consequence by verifying actual post-execution backing, reducing the authoritative commitment Remaining Entitlement by exactly the context-bound `q`, and consuming that causal evidence exactly once.**

F8D does not establish:

- exercise authorization;
- protected swap execution;
- exact protected output;
- exerciser input settlement;
- Beneficiary delivery.

Those are already owned by F8A, F8B, and F8C.

F8D makes the already-proven O2 transaction count as durable fulfillment.

Conceptually:

```text
F8A
authorization + causal binding
        ↓
F8B
exact protected PoolManager execution
        ↓
F8C
authoritative settlement + direct delivery
        ↓
F8D
actual post-state backing
        ↓
Remaining -= q
        ↓
causal evidence consumed
        ↓
durable fulfillment
```

---

# 5. Required F8D Starting State

F8D begins only from the exact active Hook-owned causal lifecycle state:

```text
EXECUTED
```

The F8A/F8B/F8C causal context already binds authoritative facts including:

- service / pool identity;
- commitment identity;
- configured ExerciseRouter;
- authenticated originating exerciser;
- authoritative Beneficiary;
- exact authorized exercise quantity `q`;
- causal lifecycle state.

At F8D entry:

```text
execution proven         yes
input settlement         complete
Beneficiary delivery     complete
Remaining                unchanged
Original Entitlement     unchanged
context                  EXECUTED
durable fulfillment      not yet established
```

F8D must consume these authoritative causal facts rather than allow caller substitution.

---

# 6. Finalization Boundary

Finalization is Hook-owned.

A conceptual interface is:

```solidity
finalizeExercise(uint256 commitmentId)
```

Use the actual repository architecture when determining the concrete implementation.

Prefer not to pass any semantic fact that already exists authoritatively in Hook-owned causal context.

Do not require caller-supplied:

- `q`;
- Beneficiary;
- exerciser;
- service identity;
- pool identity;
- execution amount;
- settlement amount.

If `commitmentId` is supplied, it is only the requested finalization target and must exactly match the Hook-bound causal commitment identity.

The active finalization path must remain constrained to the configured ExerciseRouter / active O2 causal path.

F8D must not create a generally usable public fulfillment transition.

---

# 7. Authoritative Fact Ownership

Preserve the distinction between causally bound facts and current economic facts.

## Causally bound facts

Recover from the active Hook context:

```text
commitmentId
q
service / pool identity where required
originating exerciser where required
Beneficiary where required
```

Do not accept caller substitution for these facts.

## Current authoritative economic facts

Reload or rederive at finalization:

```text
current Remaining
current aggregate O
actual post-execution PoolManager state
actual Supporting Capacity S
```

F8D requires current authoritative state where final economic safety depends on the post-execution result.

---

# 8. Authoritative Final-Backing Derivation

The finality derivation is:

```text
q        = exact exercise quantity from Hook causal context
Rcurrent = current authoritative Remaining
Ocurrent = current authoritative Aggregate Capacity Obligation
Sactual  = Supporting Capacity from actual post-execution PoolManager state
```

Require:

```text
q <= Rcurrent
```

Then derive:

```text
Ofinal = Ocurrent - q
```

and require:

```text
Sactual >= Ofinal
```

Equality must pass.

Only after all final checks succeed may:

```text
Rnew = Rcurrent - q
```

be persisted.

---

# 9. Actual Post-Execution Supporting Capacity

F8D must use the existing Hook-owned authoritative derivation layer.

`Sactual` must reflect the actual current post-execution PoolManager state.

Do not substitute:

- F8A prospective `S′`;
- cached pre-execution capacity;
- Router estimates;
- F8B output proof;
- a new duplicate Supporting Capacity formula.

The semantic distinction is:

```text
F8A:
Would this proposed exercise be prospectively safe?

F8D:
After the exact exercise actually occurred,
is the resulting authoritative state safe after
releasing exactly q of obligation?
```

Preserve production derivation singularity.

---

# 10. Aggregate Obligation Consequence

Reload or rederive:

```text
Ocurrent
```

from authoritative current commitment state.

Before F8D persists fulfillment, the delivered `q` still contributes to the current obligation because Remaining has not yet been reduced.

Therefore:

```text
Ofinal = Ocurrent - q
```

After:

```text
Remaining := Remaining - q
```

the normal authoritative aggregate-obligation derivation should naturally reflect the same obligation release.

Do not introduce an independently stored aggregate-obligation decrement unless the existing frozen model explicitly requires one.

Avoid duplicate authoritative economic state.

---

# 11. Persistent Fulfillment Consequence

F8D owns exactly one persistent economic mutation:

```text
newRemaining = oldRemaining - q
```

This mutation occurs only after all final checks pass.

Preserve:

```text
Original Entitlement = unchanged
```

Do not add an independent:

```text
fulfilled
completed
settled
delivered
expired
```

or equivalent lifecycle flag.

Completion is derived from:

```text
Remaining == 0
```

Partial fulfillment must produce the exact remaining entitlement.

Exact exhaustion must produce zero Remaining.

Historical commitment identity and immutable facts remain preserved.

Reference membership does not need to be synchronously removed merely because Remaining becomes zero unless already required by the frozen/current model.

---

# 12. Causal Context Consumption

Successful F8D finalization consumes the active `EXECUTED` causal evidence exactly once.

Conceptually:

```text
EXECUTED
    ↓ successful F8D
EMPTY / consumed
```

One active executed context may cause at most:

```text
one Remaining reduction of exactly q
```

After a successfully completed top-level exercise, no reusable O2 causal evidence may remain.

Do not introduce a separate persistent `FINALIZED` or success flag unless unavoidable under the existing architecture and clearly reported.

Successful consumption of the existing causal context is the preferred completion evidence.

---

# 13. Required Finalization Sequence

Preserve the following semantic dependency:

```text
require active EXECUTED context
        ↓
authenticate permitted finalization path
        ↓
require matching commitment identity
        ↓
recover q from causal context
        ↓
reload authoritative commitment
        ↓
require q <= current Remaining
        ↓
derive actual post-execution S
        ↓
derive current aggregate O
        ↓
derive Ofinal = Ocurrent - q
        ↓
require Sactual >= Ofinal
        ↓
Remaining -= q
        ↓
consume causal context exactly once
        ↓
success
```

Concrete internal code ordering may follow the existing implementation architecture, but observable semantics must preserve these dependencies.

No persistent fulfillment consequence may survive failed finalization.

---

# 14. Economic Atomicity

The complete O2 transaction remains economically atomic.

If F8D finalization fails for any reason, including final-backing failure, the full transaction must revert.

No durable effects may survive from:

- protected PoolManager execution;
- exerciser input settlement;
- Beneficiary delivery;
- Remaining mutation;
- causal-context mutation.

Required property:

> **No durable state may exist where delivery survives but Standby finalization fails, or entitlement reduction survives without delivery.**

Do not introduce asynchronous delivery/finalization semantics.

---

# 15. Production Completion Barrier

Preserve the existing production top-level completion barrier established through F8C.

Before F8D:

```text
R4 settlement + delivery succeeds internally
        ↓
context remains EXECUTED
        ↓
top-level completion barrier fails
        ↓
entire transaction reverts
```

After successful F8D:

```text
R4 settlement + delivery
        ↓
F8D final backing
        ↓
Remaining -= q
        ↓
context consumed
        ↓
existing completion barrier passes naturally
        ↓
top-level exercise succeeds
```

Do not weaken, remove, or bypass the existing completion barrier.

Prefer successful causal-context consumption to satisfy that barrier naturally.

Do not introduce an independent F8D success boolean unless unavoidable and explicitly reported.

---

# 16. Replay, Substitution, and Stale-Evidence Requirements

F8D must reject or make impossible the following.

## Replay

A consumed context cannot reduce Remaining again.

## Cross-commitment substitution

If a commitment ID is supplied:

```text
suppliedCommitmentId == context.commitmentId
```

must hold.

## Quantity substitution

Caller must not choose `q`.

Use:

```text
q = context.q
```

## Beneficiary substitution

F8D performs no Beneficiary selection or delivery.

Caller cannot replace the Beneficiary associated with the causally proven exercise.

## Service / pool substitution

Use the authoritative configured service and Hook-owned causal facts.

Do not accept arbitrary service or pool substitution.

## Stale causal evidence

A successfully completed O2 transaction must leave no reusable `EXECUTED` context.

## Non-O2 fulfillment

The following alone must never reduce Remaining:

- ordinary swaps;
- liquidity actions;
- direct token transfers;
- settlement-only activity;
- delivery-only activity;
- failed O2 attempts;
- expiry alone;
- eligibility changes alone.

Durable fulfillment requires the exact causally attributable O2 path.

---

# 17. Nested-Call / Reentrancy Requirements

Preserve the causal exclusion properties already established by the F8A–F8C lifecycle.

Verify that F8D does not permit unsafe:

- nested exercise;
- nested authorization;
- nested finalization;
- callback reentrancy;
- replacement of active context;
- reuse of one `EXECUTED` context;
- multiple Remaining reductions from one execution;
- finalization outside the valid active ExerciseRouter / PoolManager causal operation where the current architecture requires that boundary.

Do not create an independent parallel lifecycle mechanism when the existing Hook-owned causal lifecycle already owns this responsibility.

---

# 18. Responsibility Leakage / Out of Scope

F8D must not absorb responsibilities from earlier slices.

## F8A remains owner of

- exercise authority;
- originating exerciser authentication;
- Beneficiary eligibility;
- validity / time admission;
- authorization-time `q <= Remaining`;
- prospective backing admission;
- ExerciseRouter authorization semantics.

## F8B remains owner of

- protected-operation identity;
- canonical exact-output swap construction;
- protected PoolManager execution;
- exact protected-output proof.

## F8C remains owner of

- actual input derivation;
- input-side sign handling;
- `maxInput`;
- payer identity;
- PoolManager input settlement;
- direct Beneficiary delivery;
- PoolManager delta closure.

## F7 remains owner of

- commitment admission.

## F6B remains owner of

- ordinary O3 bounded enforcement.

F8D consumes authoritative results from those responsibilities rather than revalidating or redefining them.

Also out of scope:

- GI;
- F9;
- F10;
- frontend/demo work;
- unrelated refactoring;
- unrelated documentation changes;
- redesign of already-gated protocol semantics.

---

# 19. G8D — F8D Gate

Implementation and tests must provide evidence for all six sub-gates.

Claude may give an advisory assessment but does not close G8D.

## G8D-A — Causal Authority

Prove:

1. finalization is Hook-owned;
2. finalization is reachable only through the authorized active O2 path;
3. exact `EXECUTED` context is required;
4. commitment identity is exact;
5. `q` is sourced from Hook-owned causal context;
6. caller cannot substitute `q`, Beneficiary, service, pool, or exerciser;
7. authoritative commitment state is re-read.

## G8D-B — Final Economic Backing

Prove:

```text
q <= current Remaining
```

Prove that:

```text
Sactual
```

is derived from actual post-execution authoritative PoolManager state.

Prove that:

```text
Ocurrent
```

is the authoritative current aggregate obligation.

Derive:

```text
Ofinal = Ocurrent - q
```

and require:

```text
Sactual >= Ofinal
```

Equality must pass.

Authorization-time prospective capacity must not substitute for actual final capacity.

## G8D-C — Exact Fulfillment Consequence

On successful finalization prove:

```text
Remaining_after = Remaining_before - q
```

Also prove:

- no Remaining mutation occurs before final checks pass;
- Original Entitlement remains unchanged;
- partial fulfillment produces the exact remainder;
- exact exhaustion produces zero;
- completion is derived from `Remaining == 0`;
- no independent fulfillment/completion flag is introduced;
- aggregate O changes only through the authoritative commitment/Remaining derivation.

## G8D-D — Exact-Once Causal Consumption

Prove:

- successful finalization consumes `EXECUTED` exactly once;
- one causal context causes at most one Remaining reduction;
- successful top-level O2 leaves no reusable causal evidence;
- replayed finalization fails;
- cross-commitment substitution fails;
- quantity substitution is impossible;
- stale context cannot fulfill;
- ordinary swaps cannot fulfill;
- direct transfers cannot fulfill;
- settlement alone cannot fulfill;
- delivery alone cannot fulfill.

## G8D-E — Economic Atomicity

Prove that F8D failure, especially final-backing failure, unwinds the complete O2 transaction including:

- protected AMM execution;
- input settlement;
- Beneficiary delivery;
- Remaining mutation;
- causal-context effects.

There must be:

```text
no durable delivery without fulfillment
```

and:

```text
no durable fulfillment without delivery
```

## G8D-F — Integration / Regression

Prove through the appropriate production paths:

- partial fulfillment;
- full fulfillment;
- final-backing equality;
- final-backing failure;
- replay rejection;
- production top-level `exercise()` succeeds only after successful F8D finalization;
- the existing completion barrier passes naturally after context consumption;
- F8A semantics remain preserved;
- F8B semantics remain preserved;
- F8C semantics remain preserved;
- existing F0–F8C behavior remains passing;
- meaningful boundary/fuzz evidence exists;
- authoritative post-execution PoolManager state is used where required.

Also preserve the canonical terminal acceptance relationship from the frozen implementation plan, including the applicable A4 terminal state:

```text
S = 15,000
O = 0
Remaining = 0
Beneficiary increase = 50,000
```

where that scenario belongs to the existing canonical fixture.

---

# 20. F8D Gate Evidence Requirements

Use the testing architecture and conventions already owned by `.claude/rules/*`.

For G8D specifically, ensure the evidence demonstrates the F8D semantic boundaries above.

Relevant cases include:

```text
q = 1
q = Remaining
0 < q < Remaining
Sactual = Ofinal
Sactual < Ofinal
multiple sequential partial exercises
```

where those cases are valid under the existing fixture and architecture.

Production-path evidence for successful finalization and economic atomicity must use the actual production components required by the existing test strategy.

Harness-only seeded state is not sufficient evidence for the production causal transition where real PoolManager state is semantically required.

Do not weaken production semantics to simplify testing.

---

# 21. F8D Scope / Implementation Prohibitions

Implement the minimum conforming F8D change.

Do not:

- duplicate authoritative Supporting Capacity derivation;
- duplicate authoritative aggregate-obligation derivation;
- introduce redundant economic state;
- introduce an independent fulfillment lifecycle flag;
- introduce caller-controlled economic truth;
- broaden finalization authority;
- bypass the Hook-owned causal lifecycle;
- weaken the existing production completion barrier;
- redesign F8A, F8B, or F8C;
- refactor unrelated production code;
- begin later implementation slices.

Reuse existing authoritative F5/F7/F8A/F8B/F8C state and derivation surfaces where responsibility ownership permits.

---

# 22. Verification Evidence

Run the repository-standard verification required by:

```text
CLAUDE.md
.claude/rules/*
```

In addition, run whatever focused F8D verification is required to establish G8D-A through G8D-F.

The completion report must state the actual commands executed and their actual results.

Do not claim verification that was not executed.

---

# 23. Session Evidence / Post-Project Retrospective

Maintain:

```text
docs/prompts/session-14-log.md
```

as the Claude implementation-process record for F8D.

Preserve materially relevant:

- implementation decisions;
- files changed;
- test decisions;
- ambiguities encountered;
- corrections;
- verification commands and results;
- deviations, if any;
- advisory G8D assessment.

This log is non-normative.

Do not update:

```text
docs/project-status.md
```

during F8D implementation.

The status-only update will occur only after independent ChatGPT review and explicit G8D closure.

A separate ChatGPT retrospective record will be produced after independent review:

```text
docs/prompts/retrospective/session-14-chatgpt-record.md
```

Claude does not create or modify that file.

---

# 24. Completion Report

When F8D implementation is complete, report:

1. files changed;
2. production behavior implemented;
3. tests added or changed;
4. verification commands and actual results;
5. contract-size result where applicable;
6. advisory G8D-A assessment;
7. advisory G8D-B assessment;
8. advisory G8D-C assessment;
9. advisory G8D-D assessment;
10. advisory G8D-E assessment;
11. advisory G8D-F assessment;
12. unresolved concerns, deviations, or discrepancies.

Do not declare G8D closed.

Use wording equivalent to:

```text
Claude advisory assessment: G8D requirements appear satisfied.

Final G8D closure requires independent ChatGPT review of the actual
changed production code and tests.
```

---

# 25. Accepted F8D Semantic Statement

Before editing, preserve this accepted responsibility:

> **Successful O2 delivery remains transaction-local evidence until F8D proves the actual post-execution state remains backed after releasing exactly the delivered obligation. Only then may the Hook reduce Remaining by the context-bound `q` and consume the causal evidence, making fulfillment durable.**

The intended implementation shape is:

```text
Final Backing
    +
Exact Persistent Consequence
    +
Exact-Once Causal Consumption
```

Implement that responsibility and nothing broader.

---

# 26. Completion Boundary

The F8D completion boundary is:

```text
F8D production implementation complete
F8D gate evidence complete
repository verification complete
session-14-log.md updated
```

Stop at the F8D completion boundary.
