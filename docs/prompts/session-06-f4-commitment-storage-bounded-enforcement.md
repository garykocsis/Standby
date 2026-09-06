# Standby — Claude Code Session 06

## F4 — Commitment Storage + Bounded Enforcement References

Working branch:

```text
feat/f4-commitment-storage-bounded-refs
```

Verified implementation frontier:

```text
F0  v4 Infrastructure / Hook Deployment                  COMPLETE — G0 CLOSED
F1  Deterministic Economic Fixture                       COMPLETE — G1 CLOSED
F2  EligibilityRegistry                                  COMPLETE — G2 CLOSED
F3  StandbyHook Trust + PES Configuration                COMPLETE — G3 CLOSED
F4  Commitment Storage + Bounded Enforcement References  CURRENT
F5  Authoritative Derivation Kernel                      NOT STARTED
F6A Preliminary O3 Enforcement with O = 0                NOT STARTED
F7  O1 Commitment Establishment                          NOT STARTED
F8+ Exercise path                                        NOT STARTED
```

---

# 1. Objective

Implement only:

> **Permanent commitment identity, the minimal authoritative commitment fact record, and a fixed-size non-economic reference index that bounds future commitment-derived enforcement work.**

F4 does **not** establish authentic commitments.

F4 does **not** interpret commitment facts economically.

F4 provides the authoritative storage and bounded-reference machinery that later slices consume.

The governing distinction is:

```text
Permanent history                         Bounded working index

commitments[id]  <----------------------- enforcementRefs[0..15]

      |
      +-- admitted immutable facts
      +-- mutable Remaining Entitlement

                                         later consumed by F5
                                                |
                                                v
                               validity / obligation /
                               reclaimability / O
```

Core F4 rule:

> **History is persistent and potentially unbounded. Enforcement discovery is bounded. Economic meaning is derived.**

---

# 2. F4 Responsibility Boundary

F4 owns:

1. commitment record representation;
2. permanent commitment identity;
3. monotonic non-recycled commitment-ID mechanics;
4. bounded enforcement-reference storage;
5. bounded reference-slot mechanics;
6. fact-only read access where useful;
7. isolated unit/fuzz testability of those mechanics.

F4 does **not** own:

- commitment admission;
- backing validation;
- Supporting Capacity `S`;
- Aggregate Capacity Obligation `O`;
- per-commitment Capacity Obligation;
- commitment validity;
- commitment exercisability;
- fulfillment classification;
- expiry classification;
- economic reclaimability;
- Beneficiary eligibility enforcement;
- O1;
- O2;
- O3.

Do not introduce downstream behavior merely to make F4 storage or tests easier to exercise.

---

# 3. Required Commitment Facts

Each historical commitment must preserve these semantic facts:

```solidity
struct Commitment {
    PoolId serviceId;
    address beneficiary;
    address exerciseAuthority;
    uint128 originalEntitlement;
    uint128 remainingEntitlement;
    uint64 exercisableFrom;
    uint64 validUntil;
}
```

Exact Solidity widths may be adjusted only for a deliberate implementation reason.

The semantic content must not change.

## 3.1 Admission-Fixed Facts

Once an authentic commitment is eventually admitted by F7, these facts represent the admitted economic relationship:

```text
serviceId
beneficiary
exerciseAuthority
originalEntitlement
exercisableFrom
validUntil
```

Their representation must support preservation without later reinterpretation or rewriting.

## 3.2 Remaining Entitlement

`remainingEntitlement` is authoritative persistent state.

It is **not** a redundant lifecycle classification.

It represents the remaining portion of the originally admitted entitlement after attributable fulfillment.

Later F8 owns authoritative reduction of Remaining Entitlement.

F4 owns only its persistent representation and the internal storage mechanics necessary for that later transition.

Remaining Entitlement must not be derived from:

```text
originalEntitlement
expiry
eligibility
reference membership
time
```

Expiry must not implicitly zero Remaining Entitlement.

Eligibility changes must not implicitly alter Remaining Entitlement.

---

# 4. Forbidden Persistent State

F4 must not persist any of the following:

```text
valid
isValid
exercisable
isExercisable
fulfilled
expired
per-commitment Capacity Obligation
Aggregate Capacity Obligation O
Supporting Capacity S
available capacity
backing health
reclaimable
lifecycle enum
```

Do not introduce equivalent duplicated derived state under different names.

F4 persists authoritative facts, not classifications that downstream derivation can determine from those facts.

---

# 5. Commitment Identity

Use unique, monotonic, non-recycled commitment IDs.

`0` is reserved as the nonexistent/sentinel identity.

The intended model is:

```text
nextCommitmentId starts at 1
```

with historical records conceptually accessible as:

```text
commitments[id]
```

Required semantics:

- every allocated ID is nonzero;
- an ID is used at most once;
- IDs increase monotonically;
- IDs are never recycled;
- enforcement-reference slot reuse does not reuse a commitment ID;
- enforcement-reference slot reuse does not erase or rewrite the historical commitment record.

The key distinction is:

> **Commitment identity is permanent; enforcement membership is temporary bookkeeping.**

---

# 6. Bounded Enforcement References

Implement a fixed-size reference structure equivalent to:

```solidity
uint256 public constant MAX_LIVE_COMMITMENTS = 16;
uint256[16] enforcementRefs;
```

A materially different representation is acceptable only if it preserves the same semantics and provides a clear implementation benefit.

Required meaning:

```text
0       = empty slot
nonzero = historical commitment ID
```

A nonzero reference means only:

> **This commitment is included in the bounded set that downstream derivation may need to inspect.**

Reference membership must **not** encode or imply:

```text
valid
binding
exercisable
eligible
fulfilled / unfulfilled
obligation > 0
economically live
```

The reference structure is an index, not an economic ledger.

Historical commitment storage may grow over the lifetime of the service.

The bounded enforcement index provides a maximum candidate universe of:

```text
MAX_LIVE_COMMITMENTS = 16
```

for later production derivation.

Every nonzero enforcement reference must resolve to an existing historical commitment.

Duplicate nonzero references must not be permitted.

---

# 7. Reclaimability Boundary

F4 must **not** implement authoritative economic reclaimability.

Later economic semantics will use permanent non-binding conditions including:

```text
remainingEntitlement == 0

OR

block.timestamp >= validUntil
```

Temporary Beneficiary ineligibility and pre-exercisability are not permanent release conditions.

The authoritative economic interpretation of those facts belongs to **F5**.

F4 may own structural reference mechanics such as:

```text
scan bounded slots
detect an empty slot
detect duplicate references
write a selected slot
replace a selected slot
```

F4 must not introduce economic predicates such as:

```text
isReclaimable(commitment)
isBinding(commitment)
isLive(commitment)
```

or equivalent logic under different names.

---

# 8. `CommitmentRefs` Responsibility

A narrow library such as:

```text
src/libraries/CommitmentRefs.sol
```

may be introduced if extraction materially improves clarity.

Its responsibility is limited to bounded structural mechanics.

Permitted responsibilities include:

```text
fixed-size scan mechanics
empty-slot discovery
duplicate-reference detection
slot replacement mechanics
bounded uniqueness helpers
```

Forbidden responsibilities include:

```text
economic reclaimability
validity
exercisability
per-commitment obligation
Aggregate O
Supporting Capacity
eligibility interpretation
```

If these mechanics are clearer directly within `StandbyHook`, do not introduce a library solely because one was considered in the implementation plan.

Use the smallest clear production structure.

---

# 9. Production API Boundary

F4 must not introduce:

```solidity
establishCommitment(...)
```

or an equivalent public/external path that creates an authentic Standby commitment.

Authentic O1 commitment establishment belongs to **F7**.

F4 must not create a production path through which an arbitrary caller can manufacture economically authoritative commitments or obligations.

The F4 production surface is limited to:

```text
storage representation
internal commitment storage mechanics
internal bounded-reference mechanics
fact-only read observability where justified
```

Fact-only reads may expose information such as:

```text
commitment(id)
enforcement reference by slot
```

F4 must not expose derived economic reads such as:

```text
isValid(id)
isExercisable(id)
isBinding(id)
isReclaimable(id)
commitmentObligation(id)
aggregateObligation()
supportingCapacity()
```

Those belong downstream.

---

# 10. F3 Preservation Requirements

F4 must preserve the closed F3 behavior and responsibility boundary.

In particular:

- one-shot PES configuration remains unchanged;
- no post-activation semantic reinterpretation path is introduced;
- the four enabled Hook callbacks remain fail-closed at the current implementation frontier;
- no O1/O2/O3 behavior is introduced;
- PoolManager trust semantics remain unchanged;
- ExerciseRouter trust semantics remain unchanged;
- EligibilityRegistry trust semantics remain unchanged;
- commitment-establishment authority configuration remains unchanged;
- configured service domain and protected-direction semantics remain unchanged.

F4 must not weaken the behavior already established by F0–F3.

---

# 11. Harness Boundary

A harness is optional.

If internal F4 mechanics require narrow isolated exposure for unit/fuzz verification, a `StandbyHookHarness` may provide that exposure.

Any F4 harness surface must:

- exercise the actual production storage/reference mechanics;
- avoid defining a second economic model;
- remain limited to isolated F4 verification;
- avoid manufacturing state that tests later treat as authentic O1 evidence.

Harness-seeded commitments are not authentic Standby obligations.

Do not use harness-seeded commitment state as evidence for integration, invariant, periphery, or acceptance behavior.

Do not create a harness if F4 can be tested cleanly without one.

---

# 12. File / Responsibility Boundary

Expected production files that may change or be added include:

```text
src/StandbyHook.sol

possibly:
src/libraries/CommitmentRefs.sol
src/types/StandbyTypes.sol
```

Expected F4 test locations include:

```text
test/unit/*
test/fuzz/*

possibly:
test/harness/*
```

Modify only files necessary to implement or verify F4.

Do not change `EligibilityRegistry` semantics.

Do not implement `ExerciseRouter` economic behavior.

Do not implement F5 derivation libraries or economic formulas.

Do not implement downstream O1/O2/O3 behavior.

---

# 13. Setup Boundary

F4 is not expected to introduce a deployment or environment configuration requirement.

The following are internal protocol structure rather than environment configuration:

```text
MAX_LIVE_COMMITMENTS
commitment storage layout
commitment IDs
enforcement-reference slots
```

Therefore no `docs/setup.md` change is expected unless the implementation reveals a genuine F4-specific deployment/environment requirement.

---

# 14. G4 Verification Evidence

F4 implementation must produce evidence satisfying all five G4 families below.

## G4-A — Identity Integrity

Establish that:

1. allocated IDs are nonzero;
2. IDs are unique;
3. IDs are monotonically increasing;
4. IDs are never recycled;
5. enforcement-slot reuse does not change historical identity;
6. historical records remain readable after reference-slot reuse.

## G4-B — Commitment Fact Fidelity

Establish exact round-trip preservation of:

```text
serviceId
beneficiary
exerciseAuthority
originalEntitlement
remainingEntitlement
exercisableFrom
validUntil
```

Establish that F4 storage/reference mechanics do not rewrite admission-fixed facts.

Establish that Remaining Entitlement is represented independently of expiry and eligibility classification.

Do not simulate future O2 semantics beyond what is necessary to verify the F4 storage primitive.

## G4-C — Bounded-Reference Integrity

Establish that:

1. exactly 16 reference slots exist;
2. `0` is unambiguously empty;
3. no more than 16 nonzero references can exist;
4. every nonzero reference resolves to an existing historical commitment;
5. duplicate nonzero references cannot exist;
6. replacing a slot does not erase historical commitment records;
7. reference membership carries no lifecycle or economic classification.

## G4-D — Persistence Minimality

The production implementation must not persist:

```text
S
O
per-commitment obligation
validity
exercisability
fulfilled flag
expired flag
reclaimable flag
lifecycle enum
backing-health classification
```

No duplicated derived economic accounting may be introduced.

## G4-E — Slice Isolation

Establish that:

- no production commitment-establishment transition exists;
- no O1 admission logic exists;
- no O2 logic exists;
- no O3 economic enforcement exists;
- no Beneficiary eligibility enforcement is introduced;
- no authoritative economic reclaimability derivation is introduced;
- callbacks remain fail-closed at the current implementation frontier;
- behavior established by F0–F3 remains intact.

---

# 15. F4 Test Evidence

F4-specific evidence requires:

```text
unit tests
fuzz tests
full repository regression
CI-profile regression
```

A new F4 economic integration transition is **not** required because F4 intentionally introduces no authentic economic transition.

Do not manufacture a fake integration transition solely to satisfy a test-category hierarchy.

F4 fuzz coverage should stress, as applicable:

```text
arbitrary commitment fact values
monotonic ID allocation
many sequential historical allocations
all 16 reference-slot positions
full reference-set occupancy
slot replacement
historical lookup after repeated replacements
duplicate-reference prevention
zero-sentinel handling
counter monotonicity
```

Do not make F4 fuzz tests define F5 economic reclaimability semantics.

Verification evidence must include results from at least:

```bash
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

Also include focused F4 unit/fuzz results with useful verbosity.

The completion evidence must identify:

```text
files changed
production storage/reference design
tests added or changed
focused F4 test results
full repository test results
CI-profile results
fuzz evidence
StandbyHook runtime-size impact
warnings, deviations, or unresolved questions
```

---

# 16. F4 Semantic Gate Conditions

The completed implementation must satisfy all three conditions.

### Semantic Minimality

Every new persistent field must represent an authoritative fact that cannot safely remain derived.

### Single Normative Ownership

F4 must not implement economic interpretation owned by F5, commitment admission owned by F7, or fulfillment semantics owned by F8.

### Downstream Non-Contamination

F4 must not introduce an authentic O1/O2/O3 transition or downstream economic decision merely to make the storage machinery usable.

---

# 17. Completion Boundary

F4 is complete for review when:

1. the commitment representation is implemented;
2. permanent commitment-ID mechanics are implemented;
3. the fixed-size bounded enforcement-reference structure is implemented;
4. required internal/reference mechanics are implemented;
5. F4 unit verification passes;
6. F4 fuzz verification passes;
7. full prior regression passes;
8. CI-profile regression passes;
9. G4-A through G4-E evidence is reported;
10. the F4 semantic gate conditions are satisfied.

Stop at the F4 boundary.

Do **not** implement:

```text
F5   authoritative economic derivation
F6A  preliminary O3 enforcement
F7   O1 commitment establishment
F8   O2 authorization/execution/delivery/finalization
```

The output of this session is the **F4 implementation plus G4 review evidence**.
