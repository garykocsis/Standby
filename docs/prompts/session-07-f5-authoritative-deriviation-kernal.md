# Claude Code Session 07 — F5 Authoritative Derivation Kernel

**Project:** Standby  
**Session:** 07  
**Implementation Slice:** F5 — Authoritative Derivation Kernel  
**Target repository path for this prompt:** `docs/prompt/session-07-f5-authoritative-deriviation-kernal.md`  
**Status at session start:** F0–F4 complete; G0–G4 closed; F5 authorized for implementation; F6+ not authorized  
**Primary objective:** Implement and verify the single authoritative production derivation layer for Supporting Capacity, commitment classification/obligation, Aggregate Capacity Obligation, service-domain/topology classification, and transition-specific prospective capacity derivation.

---

# Operating-Rule Ownership

This session prompt is intentionally limited to **slice-specific F5 content**.

Permanent behavior is inherited by reference:

> **`CLAUDE.md` owns permanent operating behavior.**

> **`.claude/rules/*` owns permanent Solidity/testing conventions.**

> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Therefore:

- follow `CLAUDE.md` for permanent repository operation, Git discipline, documentation discipline, prompt auditing, dependency discipline, gate authority, and completion-reporting behavior;
- follow `.claude/rules/*` for permanent Solidity and testing conventions;
- if this prompt appears to restate or conflict with a permanent rule, the permanent owner governs unless this prompt is explicitly specializing that rule for F5;
- do not infer a new permanent convention from an F5-specific instruction.

This prompt intentionally specifies only what is materially different for **F5 — Authoritative Derivation Kernel**.

---

# 1. Session Objective

Implement **F5 — Authoritative Derivation Kernel** as the single production source of Standby economic derivation.

This is the highest-risk derivation slice in the current implementation ladder. The purpose of this session is not merely to make formulas compile. The purpose is to establish a verified production derivation layer that later O1, O2, O3, read-only observability, and diagnostic previews can safely consume without recreating economic semantics.

The target outcome is:

> Every economically meaningful quantity or classification introduced by F5 is derived from authoritative facts exactly once in production, equals an independent normative reference derivation, and—where prospective v4 state is predicted—matches the state real PoolManager execution produces for the same transition.

Do **not** implement downstream transition behavior in this session.

---

# 2. Current Validated State

The implementation ladder at the start of Session 07 is:

```text
F0   v4 Infrastructure / Deployment Foundation              COMPLETE — G0 CLOSED
F1   Deterministic Economic Fixture                         COMPLETE — G1 CLOSED
F2   EligibilityRegistry                                    COMPLETE — G2 CLOSED
F3   StandbyHook Trust + PES Configuration                  COMPLETE — G3 CLOSED
F4   Commitment Storage / Bounded Enforcement References    COMPLETE — G4 CLOSED

F5   Authoritative Derivation Kernel                        THIS SESSION

F6A  Preliminary O3 Enforcement with O = 0                  NOT AUTHORIZED
F7   O1 Commitment Admission                                NOT AUTHORIZED
F6B  O3 with authentic O > 0                                NOT AUTHORIZED
F8A  O2 Authorization / Hook-owned causal context           NOT AUTHORIZED
F8B  O2 exact-output execution / execution evidence         NOT AUTHORIZED
F8C  O2 authoritative settlement / beneficiary delivery     NOT AUTHORIZED
F8D  O2 causal finalization / Remaining reduction           NOT AUTHORIZED
GI   Full Stateful Invariant Gate                           NOT AUTHORIZED
F9   Canonical Acceptance                                   NOT AUTHORIZED
F10  Demo Instrumentation                                   NOT AUTHORIZED
```

F3 established the immutable/one-shot PES configuration and trust basis.

F4 established:

- persistent commitment records;
- unique non-recycled commitment IDs;
- `0` as the empty-reference sentinel;
- bounded enforcement references;
- `MAX_LIVE_COMMITMENTS = 16`;
- persistent Remaining Entitlement;
- historical commitment preservation;
- no derived economic state.

F4 deliberately did **not** decide whether a stored commitment is currently economically binding. That interpretation begins in F5.

A useful summary of the F4/F5 boundary is:

> **History is persistent and potentially unbounded. Enforcement discovery is bounded. Economic meaning is derived.**

---

# 3. F5 Source Boundary

Follow the permanent repository-reading and operating behavior defined by `CLAUDE.md`.

For this slice, the materially relevant F5 sources include:

```text
docs/project-status.md
docs/implementation-plan.md
docs/uniswap-v4-realization.md
docs/spec.md
docs/state-machine.md
docs/invariants.md
docs/testing-strategy.md
docs/architecture.md

src/StandbyHook.sol
src/libraries/CommitmentRefs.sol

test/harness/StandbyHookHarness.sol
test/shared/ReferenceCalculations.sol
the existing F3/F4 shared fixtures and commitment tests
```

Consult additional repository files only as required to implement or verify F5 within the authorized boundary.

Do not treat this source list as a replacement for the permanent authority hierarchy in `CLAUDE.md`.

---

# 4. F5 Semantic Constraints

Permanent operating behavior and permanent Solidity/testing conventions are inherited from `CLAUDE.md` and `.claude/rules/*`; they are not redefined here.

The following constraints are specific to the F5 derivation responsibility:

### Single Production Derivation Path

Every production behavior or production read requiring an F5 economic derivation must resolve through the same Hook-owned authoritative derivation layer.

Production code must not maintain separate formulas for the same F5 economic meaning.

### No Derived Economic Storage

F5 derives authoritative meaning from existing facts. It does not create a second persistent source of economic truth.

### Independent Derivation Evidence

For every economically meaningful F5 derivation under gate review:

```text
production derivation == independent normative reference
```

The independent test oracle must not simply call the production Standby helper being verified.

### Downstream Boundary

F6/F7/F8 may consume F5 only after independent review closes G5.

F5 may prepare authoritative derivations needed downstream; it must not implement downstream transition behavior.

### F5 Convergence Requirement

Implementation discretion may remain in ordinary Solidity organization, but it must not create competing economic interpretations of validity, obligation, Supporting Capacity, service-domain classification, or prospective state.

---

# 5. Exact F5 Responsibility

F5 owns the authoritative derivation of:

```text
1. temporal commitment validity
2. temporal exercise qualification
3. irreversible/permanent non-binding classification
4. per-commitment Capacity Obligation
5. Aggregate Capacity Obligation O
6. current Supporting Capacity S
7. service-domain / topology classification
8. prospective v4 state required for backing-affecting transitions
9. prospective Supporting Capacity S'
```

F5 does **not** own:

```text
O1 commitment-establishment authority or admission transition
O2 caller authorization
O2 Beneficiary eligibility composition
O2 exact-output execution
O2 execution evidence
O2 beneficiary delivery
O2 causal fulfillment
O2 Remaining Entitlement reduction
O3 callback enforcement/rejection
registry mutation
actor authentication
administrative commitment release
pause/deactivation
```

Use this boundary:

> **F5 derives what authoritative facts mean. Downstream slices decide whether a proposed transition may become authoritative using that meaning.**

Do not pull F6, F7, or F8 behavior forward simply because F5 now makes the required calculations available.

---

# 6. F5 Production Ownership

The candidate production footprint is:

```text
src/
├── StandbyHook.sol
└── libraries/
    ├── StandbyMath.sol
    ├── ServiceDomain.sol
    └── CommitmentRefs.sol
```

Expected tests:

```text
test/harness/StandbyHookHarness.sol
test/shared/ReferenceCalculations.sol

test/unit/
├── SupportingCapacity.t.sol
├── AggregateObligation.t.sol
├── CommitmentDerivation.t.sol
└── ServiceDomain.t.sol

test/fuzz/
├── SupportingCapacityFuzz.t.sol
├── AggregateObligationFuzz.t.sol
├── CommitmentDerivationFuzz.t.sol
└── ServiceDomainFuzz.t.sol
```

Additional narrowly-scoped integration/differential tests are permitted and likely necessary for prospective-state equivalence against real PoolManager.

Do not create additional production contracts merely for organizational convenience unless genuinely required.

---

# 7. Ownership by Component

## 7.1 `StandbyHook.sol`

`StandbyHook` remains the authoritative **composition owner**.

It owns obtaining authoritative inputs from:

```text
PoolManager
immutable/activated PES configuration
persistent commitment records
bounded enforcement references
block.timestamp
```

It composes those inputs through the F5 derivation primitives.

Later production consumers must resolve through the same Hook-owned derivation layer.

The Hook should be the place where authoritative reads and economic consequences meet.

It should not duplicate arithmetic that belongs in a pure library, but the libraries must not become alternate state/economic authorities.

## 7.2 `StandbyMath.sol`

`StandbyMath` should contain pure Standby numeric/predicate derivations whose inputs are already supplied as authoritative facts.

Appropriate responsibilities include:

```text
temporal validity
temporal exercise qualification
permanent non-binding predicate
commitment obligation
Supporting Capacity arithmetic
prospective arithmetic primitives where appropriate
```

It may use pinned Uniswap arithmetic primitives such as:

```text
TickMath
SqrtPriceMath
SwapMath
```

where those define actual v4 arithmetic semantics.

It must not:

```text
read PoolManager
read Hook storage
scan enforcement refs
call EligibilityRegistry
authenticate callers
persist state
authorize O1/O2/O3
```

## 7.3 `ServiceDomain.sol`

`ServiceDomain` owns pure geometric/topological predicates only.

Appropriate responsibilities include:

```text
direction-relative tickQ/tickO geometry
numeric service-domain bounds
price-in-domain classification
direction-consistent boundary classification
whether liquidity-range endpoints introduce an initialized
boundary strictly inside the configured domain
```

It must not own:

```text
PoolManager reads
registry policy
commitment storage/state
Aggregate O
transition authority
final Hook revert policy
```

The Hook owns the consequence of a domain classification.

## 7.4 `CommitmentRefs.sol`

Keep `CommitmentRefs` structural.

It owns bounded discovery mechanics, not economic liveness.

It may support:

```text
slot enumeration
empty-slot structure
reference replacement structure
```

It must not decide:

```text
whether a commitment is valid
whether it contributes O
whether it is economically live
whether it is reclaimable
```

Use:

> **F4 owns the container. F5 owns the economic classification. F7 will own the transition that consumes that classification.**

Do not move F5 semantics into `CommitmentRefs`.

---

# 8. Commitment Derivation — Exact Semantics

For a commitment `i`, define:

```text
t   = authoritative current block.timestamp
T_E = commitment.exercisableFrom
T_V = commitment.validUntil
R   = commitment.remainingEntitlement
```

## 8.1 Temporal validity

```text
valid(i, t) := t < T_V
```

At:

```text
t == validUntil
```

validity is already false.

Do not use `<=`.

## 8.2 Temporal exercise qualification

```text
temporallyExerciseQualified(i, t) :=
    T_E <= t
    AND
    t < T_V
```

This is intentionally only the temporal predicate.

It does **not** include:

```text
Beneficiary eligibility
exercise authority
caller identity
router state
capacity sufficiency
other O2 requirements
```

Do not expose or implement a complete F5 `isExercisable()` whose semantics accidentally absorb F8 responsibilities.

If a named predicate is useful, prefer a semantically precise name equivalent to:

```text
isTemporallyExerciseQualified
```

## 8.3 Permanent non-binding classification

In the MVP there are exactly two irreversible causes by which a commitment can no longer impose present or future Capacity Obligation:

```text
1. Remaining Entitlement is exhausted through qualifying fulfillment.
2. Temporal validity has ended at validUntil.
```

Therefore:

```text
permanentlyNonBinding(i, t) :=
    R == 0
    OR
    t >= T_V
```

This classification is important for bounded-reference reclaimability.

Do not define reclaimability from temporary non-exercisability.

## 8.4 Per-commitment Capacity Obligation

The exact MVP formula is:

```text
if R == 0:
    CO_i(t) = 0
else if t >= T_V:
    CO_i(t) = 0
else:
    CO_i(t) = R
```

Equivalent:

```text
CO_i(t) =
    R    if R > 0 AND t < T_V
    0    otherwise
```

A successfully admitted commitment therefore imposes Capacity Obligation immediately while it remains valid and has positive Remaining Entitlement.

Important consequences:

```text
future commitment before exercisableFrom + positive Remaining -> CO = Remaining
open commitment + positive Remaining                        -> CO = Remaining
temporarily Beneficiary-ineligible commitment               -> CO = Remaining
wrong current caller                                        -> CO unchanged
expired commitment + positive historical Remaining           -> CO = 0
fully fulfilled commitment                                   -> CO = 0
```

Do not zero obligation because current exercise is unavailable.

---

# 9. Binding Is Not Exercisability

Preserve this distinction throughout code and tests.

A valid positive entitlement may be:

```text
binding but not yet exercisable
binding but temporarily Beneficiary-ineligible
binding and presently exercise-qualified
```

All three can impose the same Capacity Obligation.

Do **not** encode:

```text
non-exercisable -> non-binding
```

That would violate the frozen state model.

EligibilityRegistry is specifically **not** an input to:

```text
validity
commitment obligation
Aggregate O
permanent non-binding classification
reference reclaimability
```

Exercise authority is also not an input to those quantities.

Temporary loss of Beneficiary eligibility affects later O2 exercisability only. It does not release backing.

There is no generic administrative commitment release in the MVP.

---

# 10. Remaining Entitlement Semantics

`remainingEntitlement` is an authoritative persistent fulfillment-history fact.

It is not a derived lifecycle cache.

Expiry does not mutate Remaining.

This means these states are intentionally distinct:

```text
expired + Remaining > 0
    -> historical unfulfilled remainder remains visible
    -> current Capacity Obligation is zero

Remaining == 0 before expiry
    -> qualifying fulfillment exhausted entitlement
    -> current Capacity Obligation is zero
```

Do not make expiry write Remaining to zero.

Do not add:

```text
expired flag
fulfilled flag
status enum
```

merely to classify these states.

---

# 11. Aggregate Capacity Obligation O

Let the bounded F4 enforcement-reference set contain up to:

```text
MAX_LIVE_COMMITMENTS = 16
```

non-empty commitment IDs.

For each non-zero reference:

```text
1. load the authoritative commitment record
2. derive current per-commitment CO through the F5 kernel
3. add CO into the aggregate
```

Definition:

```text
O(t) = Σ CO_i(t)
```

over the bounded referenced commitments.

Do not persist Aggregate O.

Reference membership itself is not economic liveness.

A stale reference to an expired or fulfilled commitment contributes zero.

Reference slot order must have no economic meaning.

Use normal checked arithmetic unless the existing type/bound invariants establish a stronger safe arithmetic design. Do not introduce unchecked aggregate arithmetic without proof.

If F4 has already proven structural invariants such as valid non-zero referenced IDs and uniqueness, F5 may rely on those verified dependencies. Do not silently build a second competing reference-validity model.

---

# 12. Reference Reclaimability Basis

F5 owns the economic classification that F7 will later consume.

In the current MVP:

```text
referenceReclaimable(i, t) :=
    R == 0
    OR
    t >= T_V
```

Equivalently:

```text
reclaimable
<=> permanently non-binding
<=> can never again contribute positive CO in the MVP
```

Do not make a reference reclaimable merely because:

```text
t < exercisableFrom
Beneficiary is currently ineligible
current caller lacks exercise authority
router is unavailable
S is currently too small for a requested operation
any other temporary operational condition exists
```

Recommended production design:

derive one irreversible classification equivalent to:

```text
isPermanentlyNonBinding
```

and have both commitment-obligation logic and later reference-reclaimability logic consume that shared semantic predicate.

Do not semantically define reclaimability only as `commitmentObligation() == 0`, because that would make the API conceptually fragile if future protocol versions ever distinguish zero present obligation from irreversible future release.

---

# 13. Current Supporting Capacity S — Authoritative Inputs

Supporting Capacity must be derived from authoritative PoolManager state plus immutable PES facts.

Current authoritative inputs are:

```text
sqrtP
    exact current sqrtPriceX96 from PoolManager Slot0

L
    current active PoolManager liquidity

protected direction
    immutable PES configuration

tickQ
    immutable PES configuration

sqrtQ
    TickMath.getSqrtPriceAtTick(tickQ)
```

Do **not** reconstruct the exact current sqrt price from current tick.

Correct:

```text
PoolManager Slot0.sqrtPriceX96 -> sqrtP
```

Incorrect:

```text
currentTick
-> TickMath.getSqrtPriceAtTick(currentTick)
-> treat that as exact sqrtP
```

Current tick remains useful for active-liquidity-range classification. It is not a substitute for Slot0 `sqrtPriceX96`.

---

# 14. Service-Domain Geometry

`tickQ` is the boundary in the **protected execution direction**.

Do not assume it is always the numerically lower boundary.

For protected `zeroForOne`:

```text
tickQ < tickO
price movement in protected direction is downward
sqrtQ < sqrtO
```

For protected `oneForZero`:

```text
tickQ > tickO
price movement in protected direction is upward
sqrtQ > sqrtO
```

The configured service domain is closed.

Use numeric min/max where geometric containment requires it, while preserving the direction-relative meanings of Q and O.

`P_Q` is the capacity-exhaustion boundary.

`P_O` is the opposite realization-domain boundary.

Do not treat `P_O` as capacity exhaustion.

No initialized liquidity boundary may exist strictly inside the configured service domain. Equality at configured boundaries is permitted where the frozen realization allows it.

That topology assumption is essential to the controlled capacity/prospective-state derivation.

---

# 15. Current Supporting Capacity S — Exact Formula

Supporting Capacity is denominated in **raw units of the protected output currency**.

Do not perform protocol-wide decimal normalization.

## 15.1 Protected `zeroForOne`

Protected output is currency1.

Within the valid closed domain:

```text
sqrtQ <= sqrtP <= sqrtO
```

If:

```text
sqrtP == sqrtQ
```

then:

```text
S = 0
```

Otherwise:

```text
S =
    SqrtPriceMath.getAmount1Delta(
        sqrtQ,
        sqrtP,
        L,
        false
    )
```

`roundUp = false`.

## 15.2 Protected `oneForZero`

Protected output is currency0.

Within the valid closed domain:

```text
sqrtO <= sqrtP <= sqrtQ
```

If:

```text
sqrtP == sqrtQ
```

then:

```text
S = 0
```

Otherwise:

```text
S =
    SqrtPriceMath.getAmount0Delta(
        sqrtP,
        sqrtQ,
        L,
        false
    )
```

`roundUp = false`.

## 15.3 Zero liquidity

If the current state is inside the supported domain and:

```text
L == 0
```

then:

```text
S = 0
```

Zero liquidity must never manufacture capacity.

## 15.4 At P_Q

At the direction-relative capacity exhaustion boundary:

```text
P == P_Q
```

Supporting Capacity is exactly:

```text
S = 0
```

This is a valid closed-domain state.

Whether the overall backing invariant is satisfied is a separate comparison against `O`.

## 15.5 At P_O

`P_O` is also included in the closed service domain.

If `L > 0`, Supporting Capacity at `P_O` will generally be positive.

Do not reject `P_O` equality merely because it is a boundary.

---

# 16. Supporting Capacity Is Not Inventory

Do not reinterpret `S` as:

```text
TVL
raw ERC-20 balance
token reserves
LP ownership
segregated assets
nominal liquidity
protected inventory
```

`S` is the greatest representable **protected-output amount** executable from the exact current v4 state toward `P_Q` under the configured qualifying execution model.

Standby does not reserve protected output inventory.

It protects qualifying executable capacity backed by shared mutable AMM liquidity.

---

# 17. Supporting Capacity Rounding

Use conservative output rounding:

```text
roundUp = false
```

The backing comparison is between:

```text
floor-executable S
and
exact integer O
```

Never ceil Supporting Capacity in a way that can overstate executable protected output.

Tests should include boundary values where one-unit rounding differences would matter.

---

# 18. Out-of-Domain Current State

Do not silently transform a current PoolManager state outside the configured Standby realization domain into:

```text
S = 0
```

as though that were ordinary valid zero capacity.

These are semantically different:

```text
A. valid domain state with S == 0
B. invalid authoritative derivation basis because current state is outside the configured realization domain
```

F5 should provide the classification/validation necessary for the Hook to fail closed in case B.

Do not reverse SqrtPriceMath arguments merely to manufacture a positive value from an invalid geometry.

F6 will later own transition enforcement that prevents ordinary authoritative transitions from creating such invalid state. F5 owns the derivational validity/classification.

---

# 19. No Decimal Assumptions

The canonical fixture uses:

```text
MockUSTB = currency0
MockUSDC = currency1
both 6 decimals
protected direction = zeroForOne
```

That is a deterministic fixture, not a production semantic assumption.

Production F5 logic must not assume:

```text
currency0 has 6 decimals
currency1 has 6 decimals
both currencies have equal decimals
MockUSTB identity
MockUSDC identity
zeroForOne is always protected
```

`S` and `O` are both expressed in raw units of the configured protected output currency.

Therefore they are directly dimensionally comparable without global normalization.

A call to token `decimals()` must not be required to derive current `S`, commitment `CO`, or aggregate `O`.

Human-readable UI formatting is a separate concern.

---

# 20. Prospective-State Derivation Is Part of F5

F5 must provide the authoritative transition-specific derivation primitives that F6/F8 will later consume.

The canonical model is:

```text
current authoritative v4 state
+ proposed transition
-> prospective v4 state
-> recompute S'
```

Never use a generic shortcut such as:

```text
S' = S - tokenAmount
```

unless exact equivalence for that specific transition has been independently proven.

The preferred design is transition-specific helpers rather than one vague generic formula.

---

# 21. Prospective Swap S'

For a proposed backing-affecting swap, the derivation should consume the exact authoritative inputs needed to reproduce the v4 transition under the frozen controlled topology.

At minimum consider:

```text
current exact sqrtPriceX96
current active liquidity
authoritative SwapParams
effective v4 LP fee semantics
configured service domain
protected direction
caller price limit / reachable limit semantics
```

Use supported v4 `SwapMath.computeSwapStep` semantics rather than hand-written approximate price-impact formulas.

The derivation chain is:

```text
current exact v4 state
+ proposed swap
-> predicted prospective sqrt price / state
-> same Supporting Capacity kernel
-> S'
```

There must not be a separate "prospective Supporting Capacity formula."

Prospective `S'` is Supporting Capacity recomputed on the predicted post-transition authoritative state.

Preserve the frozen topology assumptions that make the controlled single-active-region calculation valid:

```text
no initialized liquidity boundary strictly inside service domain
reachable path confined to service domain
static fee assumptions required by realization
no unsupported custom-accounting delta semantics
```

Inspect the frozen realization carefully for exact fee/protocol-fee treatment.

Do not guess.

---

# 22. Prospective Liquidity-Removal S'

Liquidity removal does not move the current sqrt price.

The important classification is whether the removed position is active at the current tick.

Use v4 range semantics:

```text
active iff:
tickLower <= currentTick < tickUpper
```

If inactive:

```text
L' = L
sqrtP' = sqrtP
S' = S
```

If active:

```text
L' = L - removedActiveLiquidity
sqrtP' = sqrtP
S' = supportingCapacity(sqrtP', L', ...)
```

Do not approximate capacity reduction as a token amount.

Recompute it from the prospective authoritative liquidity state.

Liquidity addition may require topology classification in F5, but F6 owns whether the transition is accepted.

---

# 23. Minimum Production Read Surface

Implement or preserve the production read surface equivalent to:

```text
supportingCapacity()
aggregateObligation()
commitmentObligation(id)
```

These production reads must consume the **same F5 authoritative derivations** later used by enforcement.

Do not create a separate read-only economic formula.

A read-only prospective preview is allowed only if it exposes an already-authoritative production transition derivation for diagnostics/demo purposes.

It must not:

```text
introduce new economic semantics
become a prerequisite for enforcement
duplicate enforcement arithmetic
```

Avoid adding public lifecycle projection functions unless a genuine current requirement exists.

In particular, do not add public API merely for convenience such as:

```text
isExpired(id)
isFulfilled(id)
isLive(id)
status(id)
isExercisable(id)
```

unless upstream artifacts or an existing required interface specifically demand them.

Internal pure predicates are fine where they establish single ownership and are consumed by necessary derivations.

---

# 24. Suggested Internal Composition Shape

Exact names are implementation discretion, but the semantic dependency graph should resemble:

```text
Commitment facts + block.timestamp
    -> validity
    -> temporal qualification
    -> permanent non-binding
    -> commitment obligation

F4 bounded refs
    -> load referenced commitments
    -> commitment obligation
    -> Aggregate O

PoolManager exact state + PES config
    -> domain classification
    -> current Supporting Capacity S

PoolManager exact state + proposed transition
    -> prospective state
    -> same Supporting Capacity derivation
    -> S'
```

A possible implementation shape is:

```text
_isValid(...)
_isTemporallyExerciseQualified(...)
_isPermanentlyNonBinding(...)
_commitmentObligation(...)
_aggregateObligation(...)

_supportingCapacity(...)
_supportingCapacityFromState(...)

_prospectiveSwapCapacity(...)
_prospectiveLiquidityRemovalCapacity(...)

_requireCurrentStateInServiceDomain(...)
```

The exact naming is not normative.

The **single dependency path** is normative.

---

# 25. No New Economically Authoritative Storage

F5 should introduce zero new economically authoritative persistent derived quantities.

Do not persist:

```text
Supporting Capacity S
Aggregate O
commitment CO
validity
expiry
exercisability
fulfilled status
reclaimability
prospective S
active capacity
lifecycle enums
```

Persisted facts already exist upstream.

F5 adds authoritative interpretation, not a second source of truth.

A compile-time constant or non-economic implementation constant is not prohibited merely because it is stored in code.

---

# 26. Harness Boundary

`StandbyHookHarness.sol` may be expanded narrowly to support isolated F5 unit/fuzz verification.

Permitted harness roles include:

```text
expose otherwise inaccessible production F5 functions
seed narrowly required authoritative input facts
exercise pure/internal classifications
```

Harness-only seeded state is valid evidence for:

```text
isolated derivation equivalence
unit boundary behavior
fuzz equivalence of pure/current-state derivation
```

It is **not** valid evidence for:

```text
production transition correctness
real O1 storage transition
real O2 execution/finalization
real O3 callback enforcement
periphery identity correctness
stateful invariant correctness
canonical acceptance correctness
```

Do not use the harness to make F5 appear integrated with downstream transitions that do not yet exist.

---

# 27. Independent `ReferenceCalculations.sol`

This file is a critical part of G5.

For every F5 property under independent verification:

> `ReferenceCalculations.sol` must independently compose the normative derivation and must not call the production Standby-specific helper being verified.

For example, when verifying Supporting Capacity:

Do not:

```text
ReferenceCalculations.referenceS(...)
    -> StandbyMath.supportingCapacity(...)
```

That is not independent verification.

Likewise for:

```text
validity
temporal qualification
commitment obligation
Aggregate O
domain classification
prospective state
```

The reference oracle may use authoritative pinned Uniswap math primitives such as:

```text
TickMath
SqrtPriceMath
SwapMath
```

where appropriate, because the purpose is not to independently reimplement Uniswap itself.

The intended verification topology is:

```text
frozen normative semantics
        /              \
       /                \
production F5       independent reference
       \                /
        \              /
           compare
```

Intentional duplication across the production/test boundary is required here.

Production duplication is forbidden.

Independent test-oracle duplication is required.

---

# 28. Unit Test Requirements — Commitment Derivation

Create comprehensive deterministic tests for at least these temporal/Remaining combinations:

```text
t < exercisableFrom
t == exercisableFrom
exercisableFrom < t < validUntil
t == validUntil
t > validUntil

Remaining > 0
Remaining == 0
```

Explicit expected cases:

```text
future window, Remaining > 0:
    valid = true
    temporally qualified = false
    CO = Remaining
    permanently non-binding = false

exact opening, Remaining > 0:
    valid = true
    temporally qualified = true
    CO = Remaining

open window, Remaining > 0:
    CO = Remaining

one second before expiry:
    CO = Remaining

exact expiry:
    valid = false
    temporally qualified = false
    CO = 0
    permanently non-binding = true

after expiry:
    CO = 0
    permanently non-binding = true

fully fulfilled before expiry:
    Remaining = 0
    CO = 0
    permanently non-binding = true
```

Also prove:

```text
temporary Beneficiary eligibility toggles do not change CO
temporary Beneficiary eligibility toggles do not change O
temporary Beneficiary eligibility toggles do not change reclaimability basis
exercise-authority identity does not change CO/O
```

Eligibility may later affect complete O2 exercisability. That is outside F5.

---

# 29. Unit Test Requirements — Aggregate O

Cover at least:

```text
all 16 slots empty
one binding commitment
multiple binding commitments
future-window commitments
expired stale refs
fulfilled stale refs
mixed binding/non-binding refs
maximum occupied bounded refs
different slot ordering
```

Prove slot ordering does not change O.

Prove stale terminal references contribute zero without needing an expiry transaction.

Prove Aggregate O is derived and not cached.

Prove temporary non-exercisability does not reduce Aggregate O.

---

# 30. Unit Test Requirements — Supporting Capacity

Cover both protected directions.

## zeroForOne

Prove:

```text
interior valid-domain S matches independent reference
S monotonically decreases as price approaches P_Q
P == P_Q -> S == 0
P == P_O accepted
L == 0 -> S == 0
```

## oneForZero

Mirror the same evidence:

```text
interior valid-domain S matches independent reference
S monotonically decreases as price approaches direction-relative P_Q
P == P_Q -> S == 0
P == P_O accepted
L == 0 -> S == 0
```

Also prove:

```text
exact Slot0 sqrtPriceX96 is used
rounding does not overstate executable output
invalid/out-of-domain geometry cannot manufacture positive S
```

---

# 31. Canonical Fixture Evidence

The deterministic canonical fixture must independently produce:

```text
Supporting Capacity S = 80,000 MockUSDC
```

under the canonical fixture's initial state.

Do not obtain this expected result from production `StandbyMath`.

The expected value must remain an independent economic fixture proof.

The production F5 result must then equal that reference value.

---

# 32. Fuzz Test Requirements

Fuzz tests should establish equivalence and boundary robustness, not merely absence of reverts.

At minimum fuzz:

```text
validity around time boundaries
temporal qualification
Remaining values
commitment obligation
bounded Aggregate O compositions
zeroForOne Supporting Capacity
oneForZero Supporting Capacity
valid domain geometry
service-domain boundary cases
different liquidity values
different valid tick configurations
```

Where input generation must respect upstream valid-state assumptions, bound/generate accordingly and document those assumptions.

Do not fuzz arbitrary impossible F4/F3 states and then treat resulting behavior as evidence of reachable protocol correctness.

When testing invalid input classifications deliberately, make that test purpose explicit.

---

# 33. G5-B — Prospective-State Equivalence Against Real PoolManager

This is mandatory evidence for prospective helpers.

For each supported prospective transition helper:

```text
1. derive predicted prospective v4 state / S'
2. execute the same transition against real PoolManager where allowed
3. compare actual post-state to the prediction
4. derive authoritative current S from the actual post-state
5. prove predicted S' == S(actual post-state)
```

For swaps, verify the relevant predicted v4 state, including exact prospective `sqrtPriceX96` under the supported topology/transition.

For active liquidity removal:

```text
predicted active liquidity == actual post-removal active liquidity
predicted sqrtP remains unchanged
predicted S' == authoritative S after actual transition
```

For inactive removal:

```text
predicted active liquidity unchanged
actual active liquidity unchanged
predicted S' unchanged
actual S unchanged
```

These tests should use real PoolManager execution, not harness-seeded pseudo-transitions.

---

# 34. G5-C — Fixture Generalization

G5 cannot close on only the canonical fixture.

Prove at least one generalized configuration and collectively cover:

```text
oneForZero protected direction
different token identities/order
different valid ticks
different liquidity
heterogeneous currency decimals
an asymmetric-decimal configuration
```

Production logic must not assume:

```text
6 decimals
equal decimals
canonical token identities
canonical token ordering
canonical protected direction
```

For each generalized configuration, verify:

```text
production derivation == independent reference derivation
```

in raw protected-output units.

---

# 35. G5-D — Production Derivation Singularity Review

In addition to the frozen G5-A/B/C tests, perform an explicit structural review.

Confirm there is exactly one production semantic derivation path for each of:

```text
validity
temporal exercise qualification
permanent non-binding classification
commitment obligation
Aggregate O
Supporting Capacity
prospective swap capacity
prospective liquidity-removal capacity
```

Then inspect all production reads introduced or touched by F5.

They must call those authoritative derivations.

Search for duplicate formulas in production.

Examples of prohibited duplication:

```text
supportingCapacity() has one formula
future O3 helper hand-writes another equivalent formula

aggregateObligation() scans refs one way
future admission helper manually reconstructs O another way

read-only status function defines validity differently
```

Independent `ReferenceCalculations` duplication is allowed because it is verification-only.

---

# 36. G5-E — Semantic Minimality / Downstream Non-Contamination Review

Before proposing G5 PASS, inspect the diff and prove F5 did not introduce:

```text
O1 commitment establishment
O2 authority decisions
O2 causal context
O2 execution
O2 settlement
O2 beneficiary delivery
Remaining Entitlement mutation
O3 transition authorization/rejection
participant authentication
eligibility mutation
admin commitment release
pause/deactivation
derived persistent economic state
```

It is acceptable for F5 to implement pure derivations that those future slices will consume.

It is not acceptable to implement future transition semantics early.

---

# 37. G5-F — Invalid-Basis / Failure Correctness

Explicitly verify that invalid derivation bases fail closed or are classified as invalid rather than producing plausible economic capacity.

Cover relevant cases such as:

```text
invalid service geometry
wrong direction-relative Q/O relationship
current price outside configured service domain
invalid SqrtPriceMath argument ordering
unsupported prospective transition assumptions
```

Distinguish:

```text
valid state with S == 0
```

from:

```text
state for which authoritative Standby S is not validly derivable
because the service-domain basis has already been violated
```

Do not manufacture positive capacity from invalid geometry by swapping/reversing arithmetic arguments.

---

# 38. Frozen G5-A — Normative Derivation Equivalence

G5-A requires production to equal the independent normative reference for:

```text
validity
exercise-time qualification
commitment obligation
Aggregate O
current Supporting Capacity S
service-domain/topology classification
```

This is not satisfied by tests that compare one production helper with another production helper.

The oracle must remain independently derived.

---

# 39. Frozen G5-B — Prospective-State Equivalence

For each prospective helper:

```text
predicted prospective state
==
actual state real v4 produces
```

and:

```text
predicted S'
==
authoritative current S derived after the real transition
```

This is a required dependency gate for downstream pre-transition enforcement.

---

# 40. Frozen G5-C — Fixture Generalization

Prove:

```text
canonical fixture
+
generalized direction/order/tick/liquidity configuration
+
heterogeneous/asymmetric decimals
```

with independent derivation equivalence.

`S` and `O` must remain raw protected-output currency units.

No protocol-wide decimal normalization.

---

# 41. Final G5 Statement

Use the frozen gate statement:

> **Every economically meaningful quantity/classification used by later transitions equals its normative derivation from authoritative facts, and every prospective-state derivation used for pre-transition enforcement equals the state real v4 execution would produce for the same transition.**

Session 07 may **propose** G5 PASS only after the full evidence exists.

Do not independently declare G5 closed in canonical project status.

Gate closure will occur only after independent review.

---

# 42. Expected Test Organization

Prefer the planned structure:

```text
test/unit/
├── SupportingCapacity.t.sol
├── AggregateObligation.t.sol
├── CommitmentDerivation.t.sol
└── ServiceDomain.t.sol

test/fuzz/
├── SupportingCapacityFuzz.t.sol
├── AggregateObligationFuzz.t.sol
├── CommitmentDerivationFuzz.t.sol
└── ServiceDomainFuzz.t.sol
```

Add narrow real-PoolManager differential/integration tests where G5-B requires them.

Do not force a prospective-state proof into a pure unit harness if doing so weakens the evidence.

Harness proof and real PoolManager proof have different responsibilities.

---

# 43. F5 Verification Execution Boundary

Use the permanent verification commands, profiles, formatting conventions, and test-running behavior defined by `.claude/rules/*` and `CLAUDE.md`.

This prompt adds only the **F5-specific evidence requirement**:

```text
commitment derivation evidence
Aggregate O evidence
Supporting Capacity evidence
service-domain/topology evidence
fuzz equivalence where parameterized
real-PoolManager prospective-state equivalence
fixture/generalization evidence
full regression evidence required by the permanent test rules
```

The completion evidence must make it possible to assess G5-A through G5-F without inventing a new session-specific testing convention.

---

# 44. F5 Documentation Mutation Boundary

Do not edit frozen normative artifacts merely to make F5 implementation convenient.

Do not update `docs/project-status.md` to claim F5 complete or G5 closed during this implementation session.

Any permanent documentation/setup behavior is governed by `CLAUDE.md`; this prompt does not redefine it.

---

# 45. Session 07 Evidence Artifact Boundary

The Session 07 implementation record is:

```text
docs/prompts/session-07-log.md
```

Create or update that artifact as required by the permanent logging/prompt-audit rules in `CLAUDE.md`.

This prompt does **not** redefine the log format, prompt-audit mechanics, or permanent completion-reporting behavior.

The slice-specific requirement is only that the Session 07 record provide enough F5 implementation and verification evidence for independent G5 review.

A separate ChatGPT-side retrospective record owns the reasoning/review history; do not duplicate that retrospective chronology into the Claude implementation log.

---

# 46. Repository Operation

Follow the permanent repository and Git operating behavior in `CLAUDE.md`.

This prompt defines no F5-specific Git convention.

The slice-specific completion boundary remains:

```text
produce a reviewable F5 implementation + required G5 evidence
stop before F6A/F7/F8
do not treat Claude's proposed gate assessment as canonical G5 closure
```

---

# 47. Explicit Non-Goals

Do not implement any of the following during Session 07:

```text
F6A O3 callback enforcement
F7 O1 commitment admission
F6B O3 with authentic obligations
F8A O2 authorization
F8B exact-output exercise execution
F8C beneficiary settlement/delivery
F8D causal finalization / Remaining mutation
invariant handler work that depends on unfinished downstream transitions
demo frontend
public testnet deployment
```

Do not make callback stubs live merely because capacity math now exists.

The existing callback fail-closed posture should remain until its authorized enforcement slice.

---

# 48. Implementation Questions That Are Engineering Discretion

You may exercise ordinary engineering discretion over:

```text
internal function names
library organization within the authorized footprint
small helper structs used only to avoid stack complexity
test helper naming
test file internal organization
gas-neutral refactoring
```

provided those choices preserve the semantic ownership above.

You do **not** have discretion to redefine:

```text
what makes a commitment binding
when validity ends
whether pre-exercisable commitments contribute O
whether eligibility releases O
what Remaining means
what S measures
which boundary is P_Q
which currency units S/O use
how current exact price is sourced
whether derived economic state is persisted
whether production formulas may be duplicated
```

If an implementation decision reaches one of these semantic questions, consult upstream authority rather than inventing a local interpretation.

---

# 49. F5 Completion Evidence

Follow the permanent completion-reporting format in `CLAUDE.md`.

For this slice, the report/evidence must be sufficient to independently assess:

```text
G5-A  normative derivation equivalence
G5-B  prospective-state / real-v4 equivalence
G5-C  fixture and decimal generalization
G5-D  production derivation singularity
G5-E  semantic minimality / no downstream contamination
G5-F  invalid-basis / boundary failure correctness
```

It must also identify:

```text
the implemented production ownership of each F5 derivation
the independence boundary of ReferenceCalculations
any unresolved ambiguity or deviation affecting F5 semantics
whether F6+ behavior was avoided
```

Claude may state:

```text
G5 overall: PASS PROPOSED
```

only if the required evidence exists.

Claude must not mark G5 canonically closed and must not begin F6A.

---

# 50. Final Session Constraint

The implementation must converge on this semantic result:

> For any authoritative pool state inside the configured Standby realization domain, F5 derives the greatest representable protected-output amount executable from the exact current PoolManager price to the direction-relative P_Q using current active liquidity and conservative output rounding. For every referenced commitment, F5 derives current obligation from authoritative Remaining Entitlement and temporal validity without allowing temporary non-exercisability to release backing. Aggregate O is the bounded sum of those independently derived obligations. Prospective backing calculations first derive the actual prospective v4 state and then reuse the same Supporting Capacity derivation. No derived economic truth is persisted, no production formula is duplicated, and independent reference tests—not production self-comparison—establish derivation correctness.

That is the F5 implementation target.

Do not advance beyond it during Session 07.

The output of this session is the F5 implementation plus G5 review evidence. It is not G5 closure and does not authorize F6A, F7, or F8.
