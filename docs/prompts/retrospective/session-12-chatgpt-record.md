# Session 12 --- ChatGPT Reasoning Record

## F8B --- O2 Exact-Output Execution / Execution Evidence

**Artifact type:** Non-normative curated reasoning record\
**Session:** 12\
**Final result:** F8B COMPLETE; G8B PASS / CLOSED\
**Next slice:** F8C --- Authoritative Settlement / Direct Beneficiary
Delivery

------------------------------------------------------------------------

## 1. Purpose

This is the curated contemporaneous user ↔ ChatGPT reasoning record for
Session 12. It is evidence for the later methodology retrospective, not
a normative protocol artifact and not a substitute for
`docs/prompts/session-12-log.md`.

It preserves the reasoning that materially affected F8B: responsibility
derivation, user challenges, design alternatives, G8B derivation, Claude
implementation scrutiny, independent source/test review, the bounded
correction cycle, and the final gate judgment.

Where exact conversational wording is unavailable, entries are labeled
or presented as recovered decision records rather than invented
quotations.

------------------------------------------------------------------------

## 2. Starting State --- What F8A Had Already Proven

Session 12 began with F8A complete and G8A closed.

F8A owned **authorization**, not execution. The Hook created one
transaction-scoped `AUTHORIZED` context only after proving:

1.  the request came through the configured ExerciseRouter/O2
    coordinator;
2.  the real originating exerciser was recovered through the router's
    authenticated transaction-local mechanism rather than trusted
    forwarded calldata;
3.  the commitment existed and belonged to the configured service;
4.  the originating exerciser equaled the commitment exercise authority;
5.  the commitment remained valid;
6.  `exercisableFrom <= now < validUntil`;
7.  the Beneficiary remained eligible;
8.  `0 < q <= Remaining`;
9.  the prospective protected exact-output execution yielded `S′`;
10. the Hook derived current authoritative `O`;
11. `S′ >= O - q`.

Equality was admissible.

F8A did not reduce Remaining or O and did not claim execution,
settlement, delivery, fulfillment, or finalization.

The F8B blocker was therefore narrower:

> Given one already-authorized exercise, what authoritative evidence is
> sufficient to prove that the exact protected AMM execution admitted by
> that authorization actually occurred?

------------------------------------------------------------------------

## 3. Exact F8B Responsibility

The key distinction was **authorization truth versus execution truth**.

The Hook-owned `AUTHORIZED` context can prove that an exact exercise
**may occur**. It cannot prove that the AMM execution **did occur**.

The ExerciseRouter cannot become the authority for execution merely
because it coordinates the call. A router success flag, return value,
forwarded assertion, or self-report would let the coordinator
manufacture Standby execution truth.

The Uniswap v4 PoolManager is authoritative over the actual AMM
transition. The Hook remains authoritative over the Standby
interpretation of that transition.

The responsibility was frozen as:

> **F8B authoritatively binds one existing Hook-owned AUTHORIZED
> exercise to exactly one qualifying protected PoolManager swap,
> classifies only that exact swap as O2, and transitions the causal
> context from AUTHORIZED to EXECUTED only after authoritative
> PoolManager callback evidence proves that the matching swap actually
> produced exactly the authorized protected output q.**

This decomposed into:

1.  **O2 Execution Classification**
2.  **Authoritative Execution Evidence**

The compact authority rule was:

> **PoolManager owns execution truth; Hook owns Standby causal
> interpretation; ExerciseRouter owns neither.**

------------------------------------------------------------------------

## 4. Deriving the Exact Qualifying O2 Swap

For authorized quantity `q`, the attempted protected operation had to
satisfy:

``` text
callback external msg.sender == immutable PoolManager
AND callback sender == configured ExerciseRouter
AND PoolId == configured/authorized service PoolId
AND params.zeroForOne == configured protected direction
AND params.amountSpecified > 0
AND params.amountSpecified == q
AND params.sqrtPriceLimitX96 == authoritative qualification limit
AND context phase == AUTHORIZED
```

Positive `amountSpecified` is exact-output in the pinned v4
implementation. Thus the sign is part of the execution mode, not merely
a numeric check.

The qualification price limit had to reuse the authoritative service
qualification boundary already used by F5/F8A prospective
protected-exercise derivation. F8B was not allowed to independently
restate that economic boundary.

This produced a Single Normative Ownership requirement:

> The protected execution used for prospective authorization and the
> protected execution accepted during real execution must be one
> authoritative reconstruction rather than parallel descriptions that
> can drift.

The canonical fixture remained MockUSTB/MockUSDC, `zeroForOne`, while
production had to generalize to `oneForZero`.

------------------------------------------------------------------------

## 5. O2 Versus O3 --- Causal Exclusion

A major question was whether ordinary O3 activity could continue after
authorization but before the protected swap.

That was rejected. Allowing an unrelated swap could mutate pool state
after F8A had authorized against a specific prospective state.

The derived classifier was:

``` text
context == EMPTY:
    ordinary O3 classification/enforcement

context == AUTHORIZED:
    exact authorized O2 swap -> O2
    anything else -> REVERT

context == EXECUTING:
    any additional beforeSwap -> REVERT

context == EXECUTED:
    any additional beforeSwap -> REVERT
```

An active authorization therefore creates an **O2 causal exclusion
zone**.

Two important consequences followed:

-   unrelated O3 cannot mutate state between authorization and protected
    execution;
-   a malformed O2 attempt cannot fail O2 classification and silently
    fall through to O3.

This was treated as causal continuity, not merely as a reentrancy guard.

------------------------------------------------------------------------

## 6. Why `EXECUTING` Was Necessary --- and More State Was Not

The economic causal model was conceptually:

``` text
EMPTY -> AUTHORIZED -> EXECUTED -> later consumed
```

But PoolManager exposes distinct `beforeSwap` and `afterSwap` callbacks.

Moving directly to `EXECUTED` in `beforeSwap` would treat acceptance of
a proposal as proof of execution. Therefore the minimum implementation
guard was:

``` text
AUTHORIZED -> EXECUTING -> EXECUTED
```

Meaning:

-   `AUTHORIZED`: the exact operation may begin;
-   `EXECUTING`: the exact proposal passed authenticated `beforeSwap`
    classification and is in flight;
-   `EXECUTED`: authenticated `afterSwap` evidence proves exact
    protected output.

Rejected transitions included:

``` text
EMPTY -> EXECUTING/EXECUTED
AUTHORIZED -> EXECUTED from beforeSwap alone
AUTHORIZED -> ordinary O3
EXECUTING -> second beforeSwap
EXECUTING -> EXECUTED without q evidence
EXECUTED -> second execution
overwrite of EXECUTED authorization
```

A nonce, execution hash, persistent execution ID, or swap ledger was
considered unnecessary unless implementation revealed a genuine
ambiguity. Authenticated PoolManager sequencing plus exact callback
facts and Hook-owned context already provided causal binding.

This was a direct Semantic Minimality decision.

------------------------------------------------------------------------

## 7. Requested Output Is Not Actual Execution Evidence

A central distinction was:

``` text
params.amountSpecified == q
```

versus:

``` text
actual protected-output delta == +q
```

The first proves only that `q` was **requested**.

Pinned Uniswap v4 behavior permits an exact-output swap to stop at the
price limit before producing the full requested output. That may be a
valid Uniswap execution but cannot count as a successful Standby
protected exercise.

Therefore `afterSwap` evidence was mandatory.

For `zeroForOne`:

``` text
delta.amount1() == +q
```

For `oneForZero`:

``` text
delta.amount0() == +q
```

The sign is meaningful. No absolute-value shortcut is valid.

The rule became:

> **Exact-output request proves the attempted operation; exact signed
> PoolManager output delta proves successful protected execution.**

Partial output `< q` must reject.

------------------------------------------------------------------------

## 8. Partial Exact-Output and Economic Atomicity

If Uniswap reaches the qualification boundary before producing `q`,
Standby must not create a partial-execution economic state.

The correct sequence is:

1.  `beforeSwap`: `AUTHORIZED -> EXECUTING`;
2.  PoolManager executes;
3.  `afterSwap` observes actual output;
4.  output other than exactly `q` causes revert;
5.  the PoolManager transition and transient causal write unwind
    atomically.

No `PARTIALLY_EXECUTED` state was introduced because the economic
agreement did not assign meaning to one.

This was an application of Economic Atomicity:

> A protected exercise either establishes the complete execution fact
> required by the agreement or establishes no execution fact at all.

------------------------------------------------------------------------

## 9. `maxInput` and the F8B/F8C Boundary

`maxInput` already existed in the F8A request/context surface after the
Session 11 correction.

That correction had established:

> **Implementation discretion may fill genuinely open realization
> details, but it may not silently remove, reinterpret, or relocate a
> responsibility or surface already assigned by the frozen handoff.**

Once F8B executes the exact-output swap, PoolManager produces both
protected output and an input-side debt.

F8B needs only the protected-output side as execution evidence.

F8C owns:

``` text
authoritative actual input debt
actualInput <= maxInput
settlement of that debt
direct Beneficiary delivery
```

F8B therefore deliberately avoided storing `actualInput` merely because
BalanceDelta made it observable.

The boundary was:

> F8B may observe BalanceDelta but consumes only the protected-output
> component as execution evidence. The actual-input component becomes
> economically relevant in F8C.

This distinction later exposed the only issue found in independent
review: stale F8A-era explanatory comments.

------------------------------------------------------------------------

## 10. The Production Completion Problem

A real v4 swap opens PoolManager currency deltas. F8B could execute the
swap, but closing those deltas belongs to F8C settlement/delivery.

Therefore a production F8B transaction could not yet complete the full
unlock lifecycle.

The solution was **not** to leak F8C into F8B.

Instead, real-PoolManager tests were allowed narrowly scoped **test-only
mechanical delta closure** so the swap could commit and its post-state
could be inspected.

The test seam was prohibited from:

-   becoming production semantics;
-   assigning an authoritative payer;
-   enforcing `maxInput`;
-   claiming exerciser payment;
-   delivering to the Beneficiary;
-   reducing Remaining or O;
-   claiming fulfillment.

The resulting principle was:

> **The proof obligation is canonical; the concrete proof technique is
> downstream.**

------------------------------------------------------------------------

## 11. Failed Execution and Catch/Retry

If `afterSwap` rejects evidence, the `EXECUTING` write is inside the
reverted PoolManager call subtree and rolls back.

That raised a question: could the router catch the failure and try
another swap while the outer authorization survived?

The canonical answer was no.

The production ExerciseRouter must propagate protected-execution failure
and must not catch-and-retry. Then failure unwinds:

``` text
afterSwap failure
-> PoolManager swap revert
-> unlock revert
-> ExerciseRouter exercise revert
-> F8A authorization creation revert
```

No surviving authorization remains available for a second attempt.

Because catch/retry was prohibited in the canonical router, F8B did not
add a pre-PoolManager `beginExecution` surface, retry counter, or
persistent attempt nonce.

G8B had to verify the actual production router obeyed this assumption.

------------------------------------------------------------------------

## 12. G8B Derived Before Implementation

The expanded verification gate covered:

1.  authorization prerequisite;
2.  exact configured coordinator;
3.  exact service identity;
4.  exact protected direction and mirrored `oneForZero`;
5.  exact-output mode;
6.  exact requested `q`, including mismatch rejection;
7.  exact authoritative qualification boundary;
8.  O2 causal exclusion;
9.  `beforeSwap` reaches only `EXECUTING`;
10. nested/multiple isolation;
11. PoolManager execution authority;
12. exact signed actual output `+q`;
13. partial-output rejection;
14. causal correspondence without unnecessary nonce/hash state;
15. one transition to `EXECUTED`;
16. failure atomicity and router propagation;
17. F5 prediction versus actual committed PoolManager state;
18. Remaining and O unchanged;
19. no F8C leakage;
20. no F8D leakage;
21. O3 regression;
22. prior-gate regression;
23. unit, fuzz, adversarial, transition, real-PoolManager integration,
    and differential evidence, with GI deferred.

The gate tested responsibility and causal truth, not merely whether a
swap occurred.

------------------------------------------------------------------------

## 13. Claude Implementation --- Material Choices

Claude implemented F8B and maintained `docs/prompts/session-12-log.md`.

### Production ExerciseRouter acquired R3

Claude mapped the router decomposition as:

``` text
R1 + R2 -> F8A
R3      -> F8B
R4      -> F8C
R5      -> F8D
```

R3 is exactly one protected exact-output PoolManager execution.

The production ExerciseRouter therefore unlocks PoolManager and issues
one protected swap after authorization.

This became a major independent-review item: coordination could move to
the router, but Standby economic truth could not.

The implementation preserved that boundary by asking the Hook for the
canonical currently authorized operation instead of composing direction,
quantity, or qualification boundary independently.

### One canonical reconstruction

Claude extracted `_canonicalProtectedExecution(q)` and reused it for:

-   F8A prospective derivation;
-   the router proposal;
-   `beforeSwap` classification;
-   `afterSwap` revalidation.

This was a strong Single Normative Ownership result.

### `authorizedProtectedExecution()` read surface

The router obtains the current admitted operation through a Hook view.

Independent review treated this as acceptable because it grants no
authority: the Hook still revalidates everything on the authenticated
PoolManager callback path.

### Minimal causal state

Claude added `EXECUTING`/`EXECUTED` but no nonce, hash, persistent
execution record, or economic snapshot.

### Test-only delta closure

`ExerciseDeltaClosureRouter` follows the production execution path and
then mechanically closes deltas from its own pre-funded balances.
Protected output is parked on the closure contract, intentionally
preventing tests from confusing mechanical closure with Beneficiary
delivery.

------------------------------------------------------------------------

## 14. Independent Review Inputs

ChatGPT did not accept Claude's proposed PASS as the gate decision.

The user uploaded the changed production, harness, shared-test,
integration, unit, fuzz, and perimeter files. ChatGPT reconciled the
uploads against Claude's changed-file list and identified two initially
missing files:

``` text
test/unit/ExerciseAuthorization.t.sol
test/fuzz/ExerciseBackingFuzz.t.sol
```

The user supplied both before the final review.

This ensured the gate review covered the actual reported F8B change
surface rather than a representative subset.

------------------------------------------------------------------------

## 15. Independent Review --- Production Boundary

The production implementation passed substantive review.

### Hook-owned classification

With `EMPTY`, `_beforeSwap` follows existing O3 behavior.

With active O2 context, the operation must pass protected-execution
classification. Only `AUTHORIZED` can begin execution. `AUTHORIZING`,
`EXECUTING`, and `EXECUTED` cannot fall through to O3.

### Exact operation

The canonical operation contains:

-   configured direction;
-   positive exact-output amount;
-   exact `q`;
-   exact qualification limit.

### Router identity is necessary but insufficient

The callback sender must be the configured ExerciseRouter, but router
identity alone cannot manufacture O2. Adversarial tests show an
O2-shaped swap from the configured router without Hook authorization
remains subject to the ordinary perimeter.

### `beforeSwap` is not execution proof

The accepted proposal reaches only `EXECUTING`.

### `afterSwap` establishes execution evidence

`afterSwap` rechecks causal facts, selects the direction-correct
BalanceDelta side, and requires exact positive `q` before `EXECUTED`.

No absolute-value bug or request-as-evidence shortcut was found.

------------------------------------------------------------------------

## 16. Independent Review --- Failure Atomicity

The production ExerciseRouter was inspected for:

-   `try/catch`;
-   retry logic;
-   alternate success branches;
-   second PoolManager execution;
-   router-authored success flags.

None were found.

It performs one protected execution and propagates failure. Therefore an
evidence failure unwinds the entire exercise transaction, including
authorization.

The minimal causal model was sufficient.

------------------------------------------------------------------------

## 17. Independent Review --- Delta-Closure Harness

The test-only closure seam passed the responsibility-leakage review.

It does not:

-   enforce `maxInput`;
-   define the exerciser as payer;
-   establish an authoritative payer;
-   deliver output to the Beneficiary;
-   reduce Remaining;
-   reduce O;
-   record fulfillment;
-   finalize the commitment.

Output is deliberately parked on the closure contract.

This was important because a convenient test router could otherwise have
silently pre-implemented F8C merely to make F8B integration tests
complete.

------------------------------------------------------------------------

## 18. Independent Review --- Prediction Differential

F8B did not rely solely on observing `EXECUTED`.

The integration evidence captures the F5/F8A prospective Supporting
Capacity, executes through the real PoolManager, then compares the
actual production post-state and independent reference reconstruction
against the prediction.

The fuzz suite repeats the relationship across admissible quantities.

This was strong evidence that authorization-time economic derivation and
real AMM execution converge on the same state.

------------------------------------------------------------------------

## 19. Independent Review --- Direction Generality

Because the canonical fixture is `zeroForOne`, direction hard-coding
could have escaped ordinary tests.

The mirrored `oneForZero` test verified:

-   the admitted canonical exact-output operation uses the mirrored
    direction and appropriate qualification boundary;
-   protected output is read from currency0 instead of currency1.

This was accepted as sufficient F8B direction-generality evidence for
the direction-dependent mechanics.

------------------------------------------------------------------------

## 20. Reachability Qualifications

Two notable qualifications were reviewed and accepted.

### Nested `EXECUTING -> beforeSwap`

A genuine second `beforeSwap` between the accepted swap's `beforeSwap`
and `afterSwap` is structurally unreachable through the real PoolManager
call frame. The production predicate is therefore tested directly at
unit level.

This was accepted because the missing integration path follows from
PoolManager sequencing rather than missing test effort.

### Partial output from authentic backed state

Authentically backed authorization should prevent a protected execution
from reaching the qualification boundary before producing `q`.

To test F8B's independent defense, a harness writes an
otherwise-unreachable unbacked remainder and then executes through the
real PoolManager. Partial output is produced and `afterSwap` rejects it.

This was accepted as defense-in-depth evidence: upstream state should
make the condition unreachable, but F8B still refuses invalid evidence
if forced.

------------------------------------------------------------------------

## 21. F8C/F8D Leakage Review

No production implementation was found for:

``` text
actualInput <= maxInput
input debt settlement
direct Beneficiary delivery
Remaining reduction
O reduction
fulfillment
commitment completion
final causal-context consumption
```

`EXECUTED` therefore means only:

> the exact authorized AMM execution occurred and produced exactly the
> authorized protected output.

It does **not** mean that the exercise is settled, delivered, fulfilled,
or finalized.

------------------------------------------------------------------------

## 22. Defect Found --- Documentation Drift

The substantive implementation passed, but ChatGPT did not immediately
close G8B.

Several F8A-era comments still explained `maxInput` by saying, in
effect:

> no swap executes at this slice, so there is no input debt yet.

That had been true in F8A but became false after F8B implemented R3.

The correct statement is:

> `maxInput` remains inert through F8B not because no swap occurs, but
> because enforcement of the actual input debt belongs to F8C together
> with settlement.

This was classified as:

-   not a production-semantic defect;
-   not a reason to redesign F8B;
-   a documentation-only gate hold.

The interim judgment was:

``` text
F8B implementation semantics: PASS
G8B behavioral/evidence obligations: PASS
Responsibility-leakage gate: PASS
Semantic-minimality gate: PASS
Economic-atomicity gate: PASS
Single-normative-ownership gate: PASS

G8B: HOLD for one documentation-only correction
```

------------------------------------------------------------------------

## 23. Bounded Correction

The follow-up prompt was:

``` text
docs/prompts/session-12-f8b-documentation-correction.md
```

It prohibited production behavior changes, test behavior changes,
assertion changes, storage changes, fixture changes, F8C/F8D
implementation, GI, and project-status changes.

Claude corrected four stale statements:

1.  `src/ExerciseRouter.sol` --- `exercise(...)` NatSpec;
2.  `test/fuzz/ExerciseAuthorizationFuzz.t.sol` ---
    `testFuzz_maxInput_changesNoAuthorizationOutcome`;
3.  `test/periphery/ExerciseAuthorizationPerimeter.t.sol` ---
    `test_maxInputOfZero_authorizesIdentically`;
4.  `test/shared/BaseExerciseAuthorizationTest.t.sol` ---
    `UNCONSTRAINED_MAX_INPUT`.

The `_authorizeAs` helper description was also updated to reflect the
full production coordination path.

Importantly, similar-looking statements were deliberately retained when
still accurate:

-   `StandbyHook.authorizeExercise` itself executes no swap;
-   authorization remains distinct from exercise;
-   no production exercise **completes** in F8B because settlement is
    absent;
-   fulfillment still does not exist.

This selective correction was preferable to mechanical
search-and-replace because it respected the subject and scope of each
statement.

------------------------------------------------------------------------

## 24. Verification and Final Gate

After the correction Claude reported:

``` text
forge fmt --check                    clean
forge lint                           no findings
forge build                          successful
forge test                           466 passed, 0 failed, 0 skipped
FOUNDRY_PROFILE=ci forge test        466 passed, 0 failed, 0 skipped
```

No production logic, test logic, assertion, interface, storage layout,
or fixture behavior changed.

The final independent decision was:

> **F8B --- O2 Exact-Output Execution / Execution Evidence: COMPLETE**

> **G8B --- PASS / CLOSED**

The reachability qualifications did not prevent closure because they
reflect genuine properties of the staged architecture and PoolManager
call structure.

------------------------------------------------------------------------

## 25. Status Synchronization

Only after independent G8B closure was Claude authorized to update
`docs/project-status.md`.

The status-only instruction was:

``` text
F8B — O2 Exact-Output Execution / Execution Evidence: COMPLETE
G8B: PASS
F8C — Authoritative Settlement / Direct Beneficiary Delivery:
    next authorized implementation slice / current blocker
```

The prompt prohibited implementation details, design commentary, test
summaries, gate reasoning, and retrospective observations in the status
artifact.

This preserved artifact ownership:

> `project-status.md` records project state; session logs and
> retrospectives preserve the evidence and reasoning that established
> it.

------------------------------------------------------------------------

## 26. Material User Challenges and Process Decisions

### Recovered decision record --- preserve the Working Model

The user had previously challenged handoffs that omitted the explicit
Working Model. That concern governed Session 12:

-   ChatGPT derives responsibility and gate before implementation;
-   Claude implements within the frozen boundary;
-   ChatGPT independently reviews actual source/tests;
-   Claude's proposed PASS is evidence, not the gate decision.

### Recovered decision record --- complete review inputs

When the user asked whether any uploaded files were missing, ChatGPT
reconciled them against Claude's recorded change set rather than
reviewing an incomplete sample. The two missing tests were requested and
supplied.

### Recovered decision record --- bounded correction

When only stale comments remained, ChatGPT held G8B for a
documentation-only correction instead of ignoring the inconsistency or
reopening architecture. The user accepted the bounded correction path.

### Recovered decision record --- status discipline

After closure, the user requested the same constrained status-update
pattern used in prior sessions. The resulting prompt authorized state
synchronization only.

------------------------------------------------------------------------

## 27. Rejected Alternatives

### Router-authored execution truth

Rejected because coordination does not confer authority over the
economic meaning of execution.

### `beforeSwap` as execution proof

Rejected because acceptance of a proposal is not evidence of its result.

### `amountSpecified == q` as sufficient proof

Rejected because v4 exact-output may stop at the price limit with output
`< q`.

### Absolute-value delta checks

Rejected because signed delta direction is authoritative evidence.

### Ordinary O3 during `AUTHORIZED`

Rejected because it can mutate pool state between authorization and
protected execution.

### Malformed O2 falling through to O3

Rejected because an active authorization creates an exclusive causal
window.

### Persistent nonce/hash/ledger

Rejected under Semantic Minimality because callback sequencing and
Hook-owned context already resolve correspondence.

### Catch-and-retry

Rejected because failure propagation gives cleaner atomicity and
prevents repeated attempts without extra state.

### Early F8C settlement for test convenience

Rejected because verification convenience does not justify
responsibility leakage.

### Storing `actualInput` in F8B

Rejected because F8B does not own its economic use.

### Mechanical replacement of every "no swap" comment

Rejected because some statements remained correctly scoped to
authorization or completion.

------------------------------------------------------------------------

## 28. Methodology Observations

### 28.1 Authority follows the fact being proven

F8B cleanly separates three roles:

-   the router coordinates;
-   PoolManager establishes the AMM execution fact;
-   the Hook interprets that fact under Standby semantics.

Candidate retrospective formulation:

> **Execution Authority Separation = Coordinator ≠ Executor ≠ Protocol
> Interpreter**

This is preserved as a methodology observation, not frozen here as a new
principle.

### 28.2 Requested behavior is not observed behavior

`q` in the call parameters expresses intent. The signed PoolManager
delta expresses outcome.

General observation:

> Admission/request facts should not substitute for authoritative
> post-transition evidence when the underlying mechanism may legally
> produce a different result.

### 28.3 Verification plumbing must not acquire economic meaning

The delta-closure harness made real execution provable without changing
the production responsibility boundary.

Candidate formulation:

> **Verification Mechanism ≠ Protocol Mechanism**

Again, this is an observation for post-project evaluation rather than a
frozen principle.

### 28.4 Stable responsibility does not imply stable implementation-era rationale

The `maxInput` owner never changed, but the old explanation for why it
was downstream became false once F8B began executing the swap.

Observation:

> **Stable responsibility does not imply stable implementation-era
> rationale.**

Staged implementation reviews should therefore inspect explanatory text
for stale reasons even when normative ownership is unchanged.

### 28.5 Continuity with the Session 11 `maxInput` lesson

Session 11 established that implementation discretion cannot silently
remove or relocate an assigned surface.

Session 12 added the complementary lesson: as upstream behavior
advances, explanatory text must evolve without moving the responsibility
itself.

Together:

> A frozen responsibility boundary must survive both implementation
> convenience and implementation progression.

### 28.6 Implementation Convergence evidence

Before Claude implemented F8B, the session had already fixed:

-   authorization ownership;
-   execution-truth ownership;
-   exact qualifying swap;
-   causal states;
-   exact evidence;
-   partial-output behavior;
-   retry policy;
-   F8C boundary;
-   verification obligations.

Claude's remaining discretion was largely realization-level: helper
extraction, the Hook read surface, R3 router coordination, and test-only
closure.

The independent review could therefore evaluate implementation against
pre-existing responsibilities rather than retroactively inventing the
design standard. This is direct evidence for the previously frozen
Implementation Convergence Principle.

------------------------------------------------------------------------

## 29. Final Session State and Handoff

At Session 12 completion:

``` text
F0   COMPLETE / G0 PASS
F1   COMPLETE / G1 PASS
F2   COMPLETE / G2 PASS
F3   COMPLETE / G3 PASS
F4   COMPLETE / G4 PASS
F5   COMPLETE / G5 PASS
F6A  COMPLETE / G6A PASS
F7   COMPLETE / G7 PASS
F6B  COMPLETE / G6B PASS
F8A  COMPLETE / G8A PASS
F8B  COMPLETE / G8B PASS
```

The next authorized slice is:

> **F8C --- Authoritative Settlement / Direct Beneficiary Delivery**

F8C inherits the F8B fact that an exact authorized protected PoolManager
execution occurred and produced exactly `q` protected output.

F8C must not re-decide F8A authorization or F8B execution truth. Its
blocker is to:

-   identify the authoritative actual input debt produced by that exact
    execution;
-   enforce carried `maxInput` against that debt;
-   settle the PoolManager debt;
-   deliver exactly `q` protected output directly to the authoritative
    Beneficiary;
-   preserve the later F8D fulfillment/finalization boundary.

No F8C implementation was authorized during Session 12.

------------------------------------------------------------------------

## 30. Retrospective Verdict

Session 12 preserved a difficult staged integration boundary without
collapsing execution, settlement, delivery, and fulfillment into one
implementation step.

The causal proof established by F8B is:

``` text
Hook-owned authorization
    ->
exact PoolManager proposal
    ->
authenticated beforeSwap classification
    ->
in-flight causal guard
    ->
authoritative PoolManager execution
    ->
authenticated afterSwap result
    ->
exact signed protected-output evidence
    ->
Hook-owned EXECUTED interpretation
```

while deliberately refusing to claim settlement, Beneficiary delivery,
fulfillment, or finalization.

The independent review found no substantive F8B defect. The only
correction required was explanatory documentation whose F8A-era
rationale became stale after R3 was implemented. The correction changed
no behavior, and G8B then closed.

**Final Session 12 result: F8B COMPLETE; G8B PASS / CLOSED.**
