# Standby — Session 09

## F7 — O1 Commitment Admission

You are continuing implementation of **Standby**, an ETHGlobal 2026 Uniswap v4 protocol project.

This session owns only:

> **F7 — O1 Commitment Admission**

The objective is to implement the first production-reachable authoritative O1 transition that creates an authentic binding Standby commitment and therefore makes the first authentic positive Aggregate Capacity Obligation `O > 0` reachable.

---

# 1. Governing Instructions

Permanent operating behavior is owned by:

```text
CLAUDE.md
```

Permanent Solidity and testing conventions are owned by:

```text
.claude/rules/*
```

Follow those governing instructions without restating or redefining them here.

This session prompt owns only the F7-specific:

- objective;
- scope;
- requirements;
- prohibitions;
- dependency and responsibility boundaries;
- file/evidence requirements;
- G7 gate evidence;
- completion boundary.

The frozen canonical artifacts, frozen `uniswap-v4-realization.md`, and current `implementation-plan.md` remain authoritative for protocol and realization semantics.

---

# 2. Current Slice Position

Completed:

```text
F0   Bootstrap & Dependencies
F1   Fixture + Canonical Pool
F2   Eligibility Registry
F3   Hook Trust + PES Configuration
F4   Commitment Storage + Bounded References
F5   Authoritative Derivations
F6A  O3 Structural Enforcement with O = 0
```

Current:

```text
F7   O1 Commitment Admission
```

Next dependency:

```text
F6B  O3 Enforcement with authentic O > 0
```

Later:

```text
F8A  Exercise Initiation + Context
F8B  O2 Exact-Output Execution
F8C  Direct Beneficiary Delivery
F8D  Fulfillment Finalization
```

Dependency relation relevant to this session:

```text
F4 + F5 + F6A
      ↓
     F7
      ↓
     F6B
      ↓
   F8A–F8D
```

---

# 3. F7 Responsibility Boundary

F7 owns:

```text
proposed commitment
→ O1 admission validation
→ prospective obligation/backing evaluation
→ unique commitment identity allocation
→ authoritative commitment persistence
→ bounded enforcement-reference insertion
→ first authentic binding positive obligation
```

F7 does **not** own:

```text
ordinary O3 enforcement under authentic O > 0
    → F6B

exercise invocation authorization/context
    → F8A

protected exact-output execution
    → F8B

Beneficiary delivery
    → F8C

fulfillment attribution / Remaining reduction
    → F8D
```

Do not implement F6B or F8 behavior in this session.

---

# 4. O1 External Transition

The production O1 surface is conceptually:

```solidity
establishCommitment(
    address beneficiary,
    address exerciseAuthority,
    uint256 originalEntitlement,
    uint64 exercisableFrom,
    uint64 validUntil
) returns (uint256 commitmentId)
```

Adapt the concrete signature only as required by the existing verified implementation structure.

The caller supplies only the proposed commitment-specific facts:

```text
beneficiary
exerciseAuthority
originalEntitlement = q
exercisableFrom = TE
validUntil = TV
```

The caller does **not** supply:

```text
Supporting Capacity S
Aggregate Capacity Obligation O
Capacity Obligation CO
reference slot
Validity
binding classification
Exercisability
Remaining Entitlement independently from q
PoolManager state
```

---

# 5. Establishment Authority

O1 may be invoked authoritatively only by the configured commitment-establishment authority:

```text
msg.sender == configured commitment-establishment authority
```

This authority remains distinct from:

```text
configuration authority
Beneficiary
exercise authority
registry administrator
trader eligibility
liquidity-action eligibility
ExerciseRouter
```

No other role implicitly grants O1 establishment authority.

---

# 6. Activated PES

O1 requires an already-activated Protected Execution Service.

F7 consumes the authoritative PES basis established by F3.

F7 does not establish, reinterpret, or mutate PES semantics.

RR-SC-8A prospective derivability remains an activation/configuration constraint and is **not** rerun per commitment during F7.

---

# 7. Proposed Commitment Basis

For proposed commitment:

```text
B   = beneficiary
AE  = exerciseAuthority
q   = Original Entitlement
TE  = exercisableFrom
TV  = validUntil
```

Successful O1 establishes the existing F4 commitment representation using the configured service reference and:

```text
Beneficiary            = B
exercise authority     = AE
Original Entitlement   = q
Remaining Entitlement  = q
exercisableFrom        = TE
validUntil              = TV
```

There has been no fulfillment at establishment.

Therefore:

```text
Original Entitlement - Remaining Entitlement = 0
```

---

# 8. Commitment-Term Admission Predicates

Reject at minimum when:

```text
beneficiary == address(0)

exerciseAuthority == address(0)

q == 0

TV <= TE

TV <= block.timestamp
```

Do **not** require:

```text
TE > block.timestamp
```

All of these may be admissible:

```text
TE < now < TV

TE == now < TV

now < TE < TV
```

Successful O1 establishes a binding commitment immediately.

Therefore for:

```text
now < TE < TV
```

the admitted commitment is:

```text
Valid              = true
exercise-qualified = false
binding            = true
```

and contributes to Aggregate Capacity Obligation immediately.

F7 must preserve:

> **Binding is distinct from Exercisability.**

---

# 9. Beneficiary Eligibility at Admission

The proposed Beneficiary must satisfy the authoritative protected-service Beneficiary eligibility predicate at O1.

An ineligible Beneficiary must be rejected.

Admission-time eligibility does not redefine the later binding semantics of an already-authoritative commitment.

In particular, later temporary Beneficiary ineligibility must not by itself:

```text
end Validity
release Capacity Obligation
change Remaining Entitlement
delete commitment history
```

F7 need not implement later exercise behavior associated with that eligibility change.

---

# 10. F4 Commitment Identity

Consume the existing F4 identity semantics.

Required:

```text
commitment IDs begin at 1

0 remains nonexistent/sentinel

IDs are unique

IDs are monotonic

IDs are never recycled
```

Failed O1 must not consume an ID.

Reference-slot reuse must not recycle commitment identity.

Historical commitment records remain preserved when an enforcement-reference slot is reused.

---

# 11. F4 Bounded Enforcement References

F7 consumes the existing bounded enforcement-reference mechanism.

The realization supports 16 enforcement references.

Before admission becomes authoritative, F7 must identify either:

```text
an empty reference slot
```

or:

```text
a reference whose commitment is authoritatively reclaimable
according to the existing F5 economic classification
```

F4 owns structural reference mechanics.

F5 owns the economically meaningful reclaimability classification.

F7 composes those existing responsibilities.

A reference to a still-binding/non-reclaimable commitment must never be overwritten.

If all 16 references remain binding/non-reclaimable, O1 must reject because bounded reference capacity is exhausted.

This failure is distinct from insufficient economic backing.

Reference reuse must preserve the historical commitment record associated with the previous ID.

---

# 12. Current Aggregate Capacity Obligation

Let:

```text
O_current
```

denote the Aggregate Capacity Obligation derived by the existing F5 authoritative derivation over the bounded authoritative reference basis.

F7 must consume that derivation.

F7 must not introduce an independent Aggregate Capacity Obligation definition or duplicate economic aggregate.

---

# 13. Proposed Commitment Capacity Obligation

Let:

```text
CO_new
```

denote the Capacity Obligation of the proposed commitment.

`CO_new` must use the same authoritative F5 obligation semantics used for already-authoritative commitments.

F7 must not create a second per-commitment obligation definition merely because the proposed commitment is not yet persisted.

For a successfully admissible commitment:

```text
now < TE < TV
```

does not make `CO_new` zero merely because the exercise window has not yet opened.

Successful O1 establishes the binding obligation immediately.

---

# 14. Prospective Aggregate Obligation

Derive:

```text
O_post = O_current + CO_new
```

This is the prospective Aggregate Capacity Obligation if the proposed commitment becomes authoritative.

`O_post` is an admission-time derived value, not new persistent economic state.

---

# 15. Supporting Capacity

Let:

```text
S_current
```

denote Supporting Capacity derived through the existing F5 authoritative derivation from:

```text
authoritative PoolManager state
+
immutable PES basis
```

F7 consumes that derivation.

The O1 caller does not provide `S_current`.

---

# 16. Economic Admission Boundary

The proposed commitment is economically admissible only when:

```text
S_current >= O_post
```

Equality is sufficient.

Therefore:

```text
S_current > O_post
    → backing predicate passes

S_current == O_post
    → backing predicate passes

S_current < O_post
    → admission rejects
```

This predicate must be satisfied before the proposed commitment becomes authoritative.

---

# 17. O1 Authoritative Transition Order

The authoritative dependency order is:

```text
1. authenticate commitment-establishment authority

2. require activated PES

3. construct proposed commitment basis

4. validate commitment-specific terms

5. require current Beneficiary eligibility

6. inspect bounded enforcement references

7. derive O_current through F5

8. identify an empty or F5-authoritatively reclaimable
   reference slot

9. derive CO_new using F5 semantics

10. derive O_post

11. derive S_current through F5 from PoolManager state

12. require S_current >= O_post

13. allocate unique commitment ID

14. persist complete commitment basis

15. establish bounded enforcement reference

16. advance commitment ID sequence

17. emit/return admission evidence
```

The required semantic ordering is:

> **Derive first → persist last.**

No economically authoritative commitment write may precede completion of the admission predicates.

---

# 18. Successful O1 Postconditions

After successful O1:

```text
exactly one new authoritative commitment exists

its ID is nonzero, unique, and non-recycled

its complete F4 commitment basis is persisted

Remaining Entitlement == Original Entitlement

exactly one bounded enforcement reference identifies it

its Capacity Obligation is derivable through F5

Aggregate Capacity Obligation includes it

Supporting Capacity still satisfies S >= O
```

Successful O1 itself does **not**:

```text
perform a swap

change PoolManager liquidity

change PoolManager price/tick

deliver protected output to Beneficiary

place protected output in Hook custody

place protected output in ExerciseRouter custody

reserve or segregate protected output

perform fulfillment

reduce Remaining Entitlement
```

---

# 19. Failed O1 Postconditions

For every rejected O1, no part of the proposed commitment becomes authoritative.

As applicable, rejection must leave unchanged:

```text
next commitment ID

commitment records

bounded enforcement references

F5-derived Aggregate Capacity Obligation

PoolManager state

Beneficiary protected-output balance

Hook protected-output balance

ExerciseRouter protected-output balance
```

Where Aggregate Capacity Obligation is checked after failure, it must be re-derived through the existing authoritative derivation.

At minimum G7 requires failed-attempt residue evidence for:

```text
unauthorized caller

invalid commitment terms

ineligible Beneficiary

bounded-reference exhaustion

insufficient backing
```

---

# 20. G7 — O1 Commitment Admission Gate

F7 is complete only when the implementation provides evidence for the following F7-specific obligations.

### G7.1 — Establishment Authority

Prove:

```text
configured establishment authority
→ valid O1 may proceed

unauthorized caller
→ rejected
```

Also prove unrelated roles do not implicitly confer establishment authority.

### G7.2 — Activated PES

Prove:

```text
inactive/unconfigured PES
→ rejected

activated PES
→ this predicate permits continued evaluation
```

### G7.3 — Independent Commitment-Term Predicates

Independently prove rejection for:

```text
zero Beneficiary
zero exercise authority
zero entitlement
TV == TE
TV < TE
TV <= now
```

Prove valid admission boundaries for:

```text
TE < now < TV
TE == now < TV
now < TE < TV
```

### G7.4 — Beneficiary Eligibility

Prove:

```text
eligible Beneficiary
→ eligibility predicate passes

ineligible Beneficiary
→ O1 rejects
```

Also prove that later temporary Beneficiary ineligibility does not release an already-admitted binding obligation.

### G7.5 — Initial Entitlement Basis

After successful O1:

```text
Original = q
Remaining = q
Original - Remaining = 0
```

### G7.6 — Future Commitment Binding

Explicitly establish a commitment satisfying:

```text
now < TE < TV
```

and prove:

```text
Valid = true
exercise-qualified = false
binding = true
CO > 0
commitment contributes to O
```

### G7.7 — Current O Derivation

With existing authentic commitments, prove O1 uses the F5-derived current Aggregate Capacity Obligation from bounded authoritative references.

### G7.8 — Proposed CO Derivation

Prove the proposed commitment's Capacity Obligation uses the same F5 authoritative semantics as an equivalent authoritative commitment basis.

### G7.9 — Authoritative Supporting Capacity

Using the real PoolManager integration fixture, prove:

```text
authoritative PoolManager state
→ F5-derived S
→ F7 admission decision
```

### G7.10 — Exact Backing Boundary

Prove:

```text
S > O_post
→ pass

S == O_post
→ pass

S < O_post
→ reject
```

Include appropriate fuzz evidence for this boundary.

### G7.11 — Empty Reference Insertion

Prove successful O1 inserts the new commitment ID into an appropriate empty bounded reference slot and makes the commitment visible to the existing F5 aggregate derivation.

### G7.12 — Reclaimable Reference Reuse

Using authentic commitment history, prove:

```text
authoritatively reclaimable ref
→ may be reused
```

while:

```text
old historical commitment record remains unchanged

new commitment receives fresh ID

old identity is never recycled

Aggregate O remains correctly derived
```

### G7.13 — Full Bounded-Set Rejection

With all 16 references binding/non-reclaimable and backing otherwise sufficient:

```text
new O1
→ bounded-capacity rejection
```

The failure must remain distinct from insufficient backing.

### G7.14 — Commitment Identity

Prove across successful admission, failed admission, and reference reuse:

```text
IDs remain nonzero

successful IDs remain unique

failed O1 consumes no ID

IDs remain monotonic

historical IDs are never recycled
```

### G7.15 — Admission Atomicity / Failure Residue

Prove each materially distinct rejected admission leaves no partial authoritative commitment, reference, obligation, custody, or PoolManager effect.

### G7.16 — No Reservation or Custody

After successful O1 prove unchanged:

```text
PoolManager liquidity

PoolManager price/tick

Beneficiary protected-output balance

Hook protected-output balance

ExerciseRouter protected-output balance
```

### G7.17 — Complete Authoritative Commitment Basis

Read the admitted commitment through the production representation and verify all required F4 authoritative facts were persisted exactly.

### G7.18 — F5 Ownership Preservation

Provide evidence that F7 consumes the existing F5 derivations for:

```text
binding/reclaimability
Capacity Obligation
Aggregate Capacity Obligation
Supporting Capacity
```

without creating duplicate authoritative economic truth.

### G7.19 — Canonical A1 Integration

Using the canonical real PoolManager fixture:

```text
Before O1:

S = 80,000 MockUSDC
O = 0
```

Establish:

```text
q = 50,000 MockUSDC
```

Required result:

```text
S = 80,000 MockUSDC
O = 50,000 MockUSDC
Remaining = 50,000 MockUSDC
```

Also prove:

```text
authentic commitment exists

unique commitment ID exists

bounded reference exists

PoolManager price/liquidity unchanged

no protected-output custody/reservation occurred
```

This is the decisive F7 proof that the production system can create the first authentic positive obligation.

### G7.20 — Prior-Gate Preservation

Relevant F4, F5, F5 real-PoolManager differential, and F6A evidence must remain passing after the F7 implementation.

This does **not** require F6B behavior.

---

# 21. F7-Specific Test Evidence

G7 requires sufficient evidence across:

```text
unit

fuzz

derivation-equivalence / differential verification

real PoolManager integration
```

The evidence must collectively prove G7.1–G7.20.

In particular:

```text
temporal boundaries
backing equality/rejection boundary
identity/reference behavior
```

must receive appropriate boundary/fuzz coverage.

Tests used as evidence that a commitment is an authentic production Standby commitment must create it through the production O1 path rather than through the F4 storage harness.

---

# 22. F7 File Boundary

Modify only files required to implement and verify F7.

Expected areas include:

```text
StandbyHook production O1 surface / internal admission composition

F7-specific tests

existing shared test fixtures only where F7 requires extension

docs/prompts/session-09-log.md
```

If implementation requires changing a verified F3/F4/F5/F6A production responsibility rather than merely consuming/extending its intended interface, identify that explicitly before treating the change as part of F7.

Do not modify frozen canonical artifacts as part of this slice.

---

# 23. Explicit F6B Prohibition

F7 ends once authentic binding `O > 0` is production-reachable.

Do not implement the next transition:

```text
ordinary swap / liquidity transition
→ prospective S'
→ compare against authentic O
→ economic O3 rejection
```

That is F6B.

F7 creates the authentic obligation that F6B will consume.

---

# 24. Explicit F8 Prohibition

Do not implement:

```text
exercise caller authentication

exercise initiation

exercise causal context

protected exact-output execution

input settlement

direct Beneficiary delivery

fulfillment attribution

Remaining Entitlement reduction
```

Those responsibilities belong to F8A–F8D.

Persisting `exerciseAuthority`, Beneficiary, timing, and Remaining facts during O1 does not grant F7 authority to act on them.

---

# 25. Session 09 Evidence Record

Maintain:

```text
docs/prompts/session-09-log.md
```

for the Session 09 implementation chronology and evidence required by the project's existing session-log conventions.

For this slice, ensure the record identifies:

```text
F7 implementation performed

files changed

F7-specific implementation decisions/discretion

G7 tests/evidence produced

commands/tests executed and results

deviations or corrections materially affecting F7

final implementation status
```

Do not use this file to redefine F7 normative semantics.

---

# 26. Completion Boundary

Stop when:

```text
production O1 is implemented

G7 evidence has been produced

relevant prior gates remain passing

first authentic positive O is reachable through production O1

no F6B behavior has been implemented

no F8 behavior has been implemented
```

At completion, provide the implementation and test evidence needed for independent ChatGPT G7 review.

Do **not** proceed to F6B.

---

# 27. Immediate Task

Inspect the existing verified F3/F4/F5/F6A implementation surfaces needed by F7.

Then implement and verify only:

> **F7 — O1 Commitment Admission**

against G7 above.

Stop at the F7 completion boundary.
