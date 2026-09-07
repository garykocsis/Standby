# Standby — Session 10 / F6B Implementation Handoff

You are implementing the next authorized Standby slice:

```text
F6B — O3 Enforcement with Authentic O > 0
Gate: G6B — Authentic O3 Backing Gate
```

Do not implement beyond F6B.

Permanent operating behavior is already owned by `CLAUDE.md`.

Permanent Solidity/testing conventions are already owned by `.claude/rules/*`.

This prompt owns only the F6B-specific objective, responsibility boundary, implementation scope, verification obligations, prohibitions, and completion boundary.

---

# 1. Current Implementation State

The following slices/gates are already complete and must be treated as trusted dependencies:

```text
F0   v4 Infrastructure / Deployment Foundation           COMPLETE — G0 CLOSED
F1   Deterministic Economic Fixture                      COMPLETE — G1 CLOSED
F2   EligibilityRegistry                                 COMPLETE — G2 CLOSED
F3   StandbyHook Trust + PES Configuration               COMPLETE — G3 CLOSED
F4   Commitment Storage / Bounded Enforcement References COMPLETE — G4 CLOSED
F5   Authoritative Derivation Kernel                     COMPLETE — G5 CLOSED
F6A  Preliminary O3 Enforcement with O = 0               COMPLETE — G6A CLOSED
F7   O1 Commitment Admission                             COMPLETE — G7 CLOSED

F6B  O3 Enforcement with Authentic O > 0                 CURRENT
```

No F8 slice is authorized.

---

# 2. F6B Objective

F6B must prove the central Standby shared-liquidity backing claim using an **authentic positive Capacity Obligation created through production O1**.

F6B does not introduce a new O3 mechanism.

It completes the economic proof of the O3 mechanism already established structurally in F6A by composing:

```text
F6A
existing structural O3 enforcement path

+

F5
authoritative current Aggregate Capacity Obligation O
authoritative prospective Supporting Capacity S'

+

F7
production creation of authentic O > 0
```

The operative backing condition is:

```text
permit backing-affecting O3 transition iff S' >= O
```

Therefore:

```text
S' > O   -> PERMIT
S' = O   -> PERMIT
S' < O   -> REJECT
```

Equality is sufficient.

---

# 3. Canonical Starting State

Use the canonical fixture already established by prior slices.

The relevant economic sequence begins:

```text
bootstrap:
S = 80,000 MockUSDC
O = 0

production F7 O1:
q = 50,000 MockUSDC

after admission:
S = 80,000
O = 50,000
Remaining Entitlement = 50,000
```

The positive obligation used as F6B evidence must be created through the **production F7 commitment-establishment path**.

No fake `O` setter is permitted.

Do not manufacture the authentic F6B obligation through:

```text
test-only commitment creation
direct storage mutation
vm.store
fake aggregate-obligation state
F4 storage harnesses used as substitutes for production O1
```

Harnesses may still be used where consistent with repository testing conventions for isolated mechanics, but they must not be the source of the authentic positive obligation that closes G6B.

---

# 4. Existing Responsibilities F6B Must Consume

## F5 ownership

F5 remains the single production owner of authoritative derivation logic for relevant economic facts, including:

```text
Supporting Capacity S
prospective Supporting Capacity S'
Aggregate Capacity Obligation O
per-commitment Capacity Obligation CO
binding / temporal classifications
reclaimability
```

F6B must consume those derivations.

Do not introduce parallel or shortcut economic logic.

In particular, do not replace prospective derivation with assumptions such as:

```text
S' = S - outputAmount
```

unless that expression is only an independently justified test oracle for a fixture where it is mathematically valid.

Production enforcement must continue through the authoritative F5 prospective-state derivation over real PoolManager state.

Do not rerun activation-time RR-SC-8A per O3 transition.

---

## F6A ownership

F6A already established the structural O3 enforcement seam, including:

```text
configured-service authentication
trusted transition perimeter
originating-user recovery
transition-family classification
transition-specific eligibility
service-domain/topology checks
prospective backing comparison plumbing
economically inert afterSwap completion behavior
```

F6B should extend and verify that existing seam.

Do not redesign F6A merely because F6B is a new slice.

If the existing production economic predicate already correctly consumes F5 `S'` and `O`, a small or even zero core-production-code delta is acceptable.

Do not force a Solidity modification simply to make F6B appear implementation-heavy.

---

## F7 ownership

F7 owns commitment admission.

Use it only to establish authentic positive obligation.

Do not redefine:

```text
commitment authority
commitment-term validity
Beneficiary eligibility at admission
admission backing condition
commitment identity
Original Entitlement
Remaining Entitlement
bounded enforcement-reference creation
```

---

# 5. Protected Ordinary Swap Semantics

For an ordinary protected-direction swap:

```text
derive prospective S'
derive current O

require S' >= O
```

Ordinary O3 transitions do not fulfill a commitment.

Therefore a successful ordinary swap may modify real PoolManager state and consequently authoritative `S`, but must not modify:

```text
commitment identity
Original Entitlement
Remaining Entitlement
O because of fulfillment
bounded enforcement references
```

---

# 6. Canonical A2 — Compatible Shared Use

Beginning from:

```text
S = 80,000
O = 50,000
Remaining = 50,000
```

execute the canonical ordinary protected-direction exact-output transition consuming 15,000 MockUSDC of supporting capacity.

Required prospective result:

```text
S' = 65,000
O  = 50,000

65,000 >= 50,000
```

The transition must succeed.

Required post-state:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

This is the primary positive **non-reservation** proof:

> outstanding Standby obligations do not freeze otherwise-compatible ordinary shared-liquidity use.

---

# 7. Canonical A3 — Destructive Shared Use

Starting from the canonical A2 post-state:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

attempt the canonical ordinary protected-direction exact-output transition that would consume another 20,000 MockUSDC of supporting capacity.

Required prospective result:

```text
S' = 45,000

45,000 < 50,000
```

The transition must reject.

The failure must specifically demonstrate Standby insufficient backing.

Do not allow A3 to pass merely because of an unrelated failure such as:

```text
balance
allowance
router trust
actor eligibility
slippage
service-domain failure
topology failure
unrelated PoolManager revert
```

After rejection, authoritative state must remain:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

Prospective `45,000` must never become authoritative state.

---

# 8. Exact Boundary

G6B requires explicit evidence for:

```text
S' = O
```

The transition must succeed.

Do not infer equality behavior only from `>` and `<` examples.

Prove it directly.

---

# 9. Atomic Rejection

For an O3 transition rejected because:

```text
S' < O
```

verify that the attempted transition leaves no economically relevant residue.

At minimum inspect the authoritative state appropriate to the transition, including relevant PoolManager state and Standby commitment state.

For the canonical destructive swap, the test should establish that the pre-transition state survives the revert.

Do not only assert the revert selector.

---

# 10. Liquidity Removal with Authentic O

F6B must also prove that F6A's liquidity-removal enforcement works against authentic positive obligation.

Required semantics:

```text
prospective S' > O  -> safe removal succeeds
prospective S' = O  -> safe removal succeeds
prospective S' < O  -> destructive removal rejects
```

Continuing LP eligibility is not required to exit safely.

Therefore include evidence that:

```text
LP loses liquidity-action eligibility
+
proposed removal is economically safe
+
removal still succeeds
```

Do not convert permissioning into a lock on safe liquidity exit.

---

# 11. Liquidity Addition Preservation

Liquidity additions retain the F6A structural rules even if the proposed addition would increase `S`.

Required behavior remains:

```text
eligible actor required
valid configured topology required
```

Do not bypass eligibility or topology merely because backing improves.

F6B should verify preservation of those existing constraints rather than redefine them.

---

# 12. Opposite-Direction Swap Preservation

Opposite-direction swaps may increase supporting capacity.

They nevertheless remain subject to the configured Standby realization/service domain.

Verify that the F6A domain behavior remains intact under authentic `O > 0`.

Positive backing effect must not bypass domain constraints.

---

# 13. Lifecycle Interactions

## Expiry

When:

```text
t >= validUntil
```

the relevant commitment must cease contributing to derived `O` according to the already-established F5 lifecycle derivation.

Expiry must not modify Remaining Entitlement.

Required relationship:

```text
before expiry:
Remaining may be 50k
O includes live obligation

after expiry:
Remaining still 50k
derived O no longer includes expired obligation
```

Do not introduce a mutation whose purpose is to manually zero `O`.

---

## Beneficiary ineligibility

Loss of current Beneficiary eligibility:

```text
must NOT reduce O
must NOT remove O3 backing protection
must NOT alter Remaining merely because eligibility changed
```

Permissioning/exercisability remains orthogonal to outstanding backing obligation unless an already-authorized normative lifecycle transition says otherwise.

---

# 14. Aggregate Obligation

Do not limit F6B verification to one commitment.

Create multiple authentic commitments through production O1 and prove that O3 enforcement protects against authoritative aggregate `O`.

The transition predicate must effectively protect:

```text
S' >= aggregate O
```

not merely one selected commitment.

Use the existing F5 bounded-reference aggregate derivation.

Do not implement a parallel aggregation path inside F6B or its tests.

---

# 15. Verification Requirements

Choose test layers because they prove G6B rather than mechanically creating every possible test category.

Strong integration evidence is required because F6B is an economic enforcement boundary over real Uniswap v4 execution.

Use:

```text
production F7 O1 for authentic O > 0
real PoolManager
existing trusted ordinary-swap / liquidity perimeter
existing F5 current-O derivation
existing F5 prospective-S' derivation
```

Where expected economic values are asserted, use independent reference/oracle calculations where appropriate.

Do not “prove”:

```text
S' >= O
```

by simply asking the same production function used by enforcement for both:

```text
expected result
actual result
```

That would be implementation mirroring, not independent verification.

---

# 16. Focused Fuzz Evidence

Add or extend focused fuzz evidence where useful for the F6B decision boundary.

The important property is conceptually:

```text
given:
    authentic live O > 0
    valid backing-affecting O3 transition
    independent expected prospective relationship

if prospective S' >= O:
    transition must not reject for insufficient Standby backing

if prospective S' < O:
    transition must reject for insufficient Standby backing
```

Generated cases must avoid unrelated invalidity masking the backing result.

Do not expand this slice into the full arbitrary-sequence invariant campaign.

That remains the later `GI` gate unless implementation exposes a genuinely new F6B-specific invariant that requires earlier stateful verification.

---

# 17. G6B — Completion Gate

F6B is complete only when evidence proves all of the following:

```text
1.  authentic O > 0 is created exclusively through production F7 O1;

2.  current O is consumed through the authoritative F5 bounded-reference derivation;

3.  prospective S' is consumed through the authoritative F5 real-PoolManager derivation;

4.  a compatible transition with S' > O succeeds;

5.  an exact-boundary transition with S' = O succeeds;

6.  a destructive transition with S' < O rejects specifically for
    insufficient Standby backing;

7.  canonical A2 succeeds and ends:
        S = 65k
        O = 50k
        Remaining = 50k;

8.  canonical A3 derives prospective S' = 45k, rejects backing-specific,
    and leaves the A2 authoritative state unchanged;

9.  rejected O3 transitions leave no relevant PoolManager or Standby
    economic residue;

10. successful ordinary O3 transitions do not modify commitment facts,
    Remaining Entitlement, or O through fulfillment semantics;

11. opposite-direction domain constraints remain intact;

12. safe liquidity removal succeeds with authentic live O;

13. exact-boundary liquidity removal where S' = O succeeds;

14. destructive liquidity removal where S' < O rejects;

15. safe liquidity removal remains possible after LP eligibility loss;

16. liquidity-add eligibility and topology constraints remain intact;

17. expiry changes O only through authoritative derivation and does not
    change Remaining;

18. Beneficiary ineligibility does not reduce O or remove O3 protection;

19. multiple authentic commitments are protected through aggregate O;

20. F6A structural classification, trust, actor-attribution, permissioning,
    domain, and topology behavior remains intact;

21. F5 remains the single production owner of S, S', O, and related
    economic derivations;

22. no F8 authorization, causal-context, protected-execution, delivery,
    fulfillment, or entitlement-reduction behavior is introduced;

23. focused F6B integration and fuzz evidence passes;

24. prior F4, F5, F6A, and F7 verification suites remain green.
```

Treat this as a single gate.

Do not declare F6B complete because only A2/A3 pass if another required G6B property fails.

---

# 18. Explicit F8 Exclusion

Do not implement any future O2/F8 responsibility.

Out of scope:

```text
exercise initiation
exercise authority enforcement
hook-owned O2 causal context
protected exact-output exercise execution
execution evidence for exercise
Beneficiary delivery
fulfillment attribution
Remaining Entitlement reduction
O reduction caused by fulfillment
exercise finalization
```

Also do not introduce:

```text
liquidity reservation
asset custody
pre-positioned Beneficiary assets
dedicated protected reserves
```

F6B concerns preservation of backing under O3 shared-resource transitions only.

---

# 19. Implementation Restraint

Inspect the existing F6A/F5/F7 production implementation before changing production code.

A valid result of that inspection may be:

```text
the F6A production seam already enforces the correct F5-derived
S' >= O predicate, and F6B primarily requires authentic integration
and verification coverage
```

If so, preserve that implementation rather than refactoring or duplicating it.

Make production changes only where actual F6B evidence exposes a missing implementation requirement.

The goal is semantic conformity, not source-code churn.

---

# 20. Session Evidence Log

Maintain the existing Session 10 Claude implementation log:

```text
docs/prompts/session-10-log.md
```

Capture implementation chronology and evidence according to the established repository process, including materially relevant:

```text
files inspected
files changed
implementation decisions
test additions/changes
commands run
test results
failures
corrections
material deviations or interpretations
final claimed G6B evidence
```

Do not use that log to redefine normative semantics.

Do not update `project-status.md` to mark F6B complete until independent ChatGPT review has occurred and the user authorizes the status update.

---

# 21. Completion Response

When your implementation work is complete, report:

```text
1. production files changed, if any;
2. test files changed/added;
3. concise explanation of how the existing F6A/F5/F7 seam was used;
4. whether any production Solidity change was actually necessary;
5. evidence mapped against each G6B requirement;
6. exact test commands executed and results;
7. any remaining uncertainty, deviation, or unverified requirement;
8. the files ChatGPT should review independently.
```

Do not begin F8.

Stop at the F6B/G6B boundary.
