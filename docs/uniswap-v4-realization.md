# Standby --- Uniswap v4 Reference Realization

**Artifact:** `uniswap-v4-realization.md`\
**Status:** FINAL PASS / FROZEN\
**Scope:** ETHGlobal 2026 / minimum Uniswap v4 reference realization\
**Authority:** This document realizes the frozen Standby canonical
package in Uniswap v4. It does not redefine general Standby protocol
semantics.

------------------------------------------------------------------------

## 1. Purpose and Scope

This document defines the minimum Uniswap v4 realization of Standby
sufficiently for implementation to proceed without inventing unresolved
protocol-correctness decisions.

The governing transformation is:

> **Frozen Canonical Requirement → Concrete Uniswap v4 Realization
> Decision → Implementation Obligation → Verification Evidence**

The frozen canonical package remains the authoritative source for
protocol meaning:

1.  `context.md`
2.  `economic-agreement.md`
3.  `mechanism.md`
4.  `spec.md`
5.  `architecture.md`
6.  `state-machine.md`
7.  `invariants.md`
8.  `testing-strategy.md`

This artifact owns only the Uniswap v4 reference-realization choices
needed to faithfully implement those semantics.

### 1.1 Governing separation

A realization restriction in this document is not automatically a
general Standby requirement.

The ETHGlobal realization deliberately narrows the implementation domain
where doing so makes authoritative derivation, enforcement completeness,
causal fulfillment, or bounded verification tractable.

### 1.2 Reference-realization design principle

Standby does not reserve liquidity. It protects qualifying execution
capacity.

For each Protected Execution Service (j), the backing condition remains:

\[ S_j(t) `\ge `{=tex}O_j(t) \]

where:

-   (S_j(t)) is current Supporting Capacity under the service's
    qualifying execution semantics; and
-   (O_j(t)) is current Aggregate Capacity Obligation derived from
    commitments that still impose a Capacity Obligation.

Equality is sufficient.

------------------------------------------------------------------------

## 2. Reference Realization Overview

The minimum realization contains these economically relevant components:

### 2.1 `StandbyHook`

The hook is the principal authoritative owner of:

-   Protected Execution Service state;
-   commitment state;
-   commitment admission;
-   authoritative Standby economic derivations;
-   O2 exercise authorization and causal fulfillment finalization;
-   O3 backing enforcement;
-   service-domain and topology enforcement.

The hook does not own mutable registry membership and does not act as an
LP or swap router.

### 2.2 `ExerciseRouter`

The ExerciseRouter coordinates the supported O2 transaction:

-   receives the exercise request;
-   preserves authenticated exercise-caller provenance;
-   opens the PoolManager execution context;
-   executes one exact-output protected swap;
-   settles the authoritative input debt from the exerciser;
-   directs PoolManager output to the authoritative Beneficiary;
-   invokes Standby finalization.

The router owns no Standby economic truth.

### 2.3 `EligibilityRegistry`

A dedicated on-chain registry owns mutable participant eligibility.

The hook reads the registry but does not expose registry-membership
management functions.

For the ETHGlobal demo, a minimal single-owner registry is sufficient.
The permission predicates remain logically distinct:

-   `canReceiveProtectedService(address)`
-   `canSwap(address)`
-   `canProvideLiquidity(address)`

The same demo administrator may control all three without collapsing
their semantic distinction.

### 2.4 Uniswap v4 infrastructure

The realization uses:

-   PoolManager as authoritative AMM execution/accounting state;
-   Universal Router as the approved trusted perimeter for ordinary
    swaps;
-   PositionManager as the approved trusted perimeter for liquidity
    actions.

The hook remains router-agnostic for backing safety but router-selective
for permissioned participation.

------------------------------------------------------------------------

## 3. Pool Setup and Initialization

### 3.1 Bootstrap sequence

The supported bootstrap is:

1.  deploy realization infrastructure;
2.  initialize the Uniswap v4 pool with the StandbyHook bound in its
    PoolKey;
3.  pool exists at an initial price with zero liquidity;
4.  call `configureAndActivate`;
5.  add topology-valid qualifying liquidity;
6.  admit commitments through O1.

Compactly:

> **Initialize Price → Configure PES → Add Controlled Liquidity → Admit
> Commitments**

### 3.2 RR-SETUP-1 --- Pool Initialization Precedes Standby Authority

Pool initialization is a pre-operational environmental transition. It
does not establish a Protected Execution Service or a Standby economic
relationship.

### 3.3 RR-SETUP-2 --- No Initialization Hook Requirement

The MVP does not require `beforeInitialize` or `afterInitialize`.

Standby does not need to control who supplied the pool's initialization
transaction or to assume a predetermined initialization price. Service
configuration independently validates the actual initialized environment
before adopting it.

### 3.4 RR-SETUP-3 --- Pre-Activation Operational Closure

Before successful service configuration:

-   no commitment may be admitted;
-   liquidity addition is rejected;
-   ordinary swap operation is rejected;
-   O2 is unavailable.

This prevents an uncontrolled topology or runtime history from preceding
service establishment.

### 3.5 RR-SETUP-4 --- Configuration-Time Environmental Validation

`configureAndActivate` validates the authoritative initialized pool
environment before establishing the PES, including hook binding, zero
liquidity, supported fee/accounting model, service-domain geometry,
protected direction, trusted perimeters, eligibility source, and
authorities.

### 3.6 RR-SETUP-5 --- Atomic Service Existence

The MVP has no independent configured-versus-active lifecycle. Before
successful `configureAndActivate`, no PES exists. After it, the complete
PES exists and runtime enforcement applies immediately.

------------------------------------------------------------------------

## 4. Service Configuration and Activation

### 4.1 One-shot configuration

Configuration occurs exactly once per MVP service.

`configureAndActivate` must:

1.  authenticate configuration authority;
2.  derive the PoolId from the supplied PoolKey;
3.  verify the PoolKey binds the expected StandbyHook;
4.  verify the pool is initialized;
5.  verify the PES does not already exist;
6.  verify current pool liquidity is zero;
7.  validate the supported fee/accounting model;
8.  read authoritative current pool price;
9.  validate protected direction;
10. validate `tickQ` and `tickO`;
11. validate current price lies in the closed service domain;
12. validate ExerciseRouter;
13. validate EligibilityRegistry;
14. validate establishment authority;
15. validate realization-wide trusted dependencies;
16. persist the complete PES atomically.

All validation precedes authoritative service persistence.

### 4.2 RR-CONFIG-1 --- Controlled Service Configuration and Activation

Pool initialization binds the hook; authorized Standby configuration
subsequently establishes the PES before liquidity or O1.

### 4.3 RR-CONFIG-2 --- Semantic Immutability with Operationally Mutable Inputs

The semantic service basis is immutable after activation.

Operational inputs whose mutability is part of that fixed semantic basis
may change. Registry membership is the primary MVP example.

### 4.4 RR-CONFIG-3 --- One-Shot Service Configuration and Activation

Configuration and activation are one atomic transition. There is no
generic active/false switch, reconfiguration path, or post-activation
semantic setter.

### 4.5 RR-CONFIG-4 --- Fact-Complete Atomic Service Establishment

Successful configuration persists a complete service basis. Failure
leaves no PES and no partial service state.

### 4.6 RR-CONFIG-5 --- Configuration Does Not Manufacture Capacity

Configuration does not require positive Supporting Capacity and does not
mutate the pool. With zero liquidity, Supporting Capacity may be zero.

### 4.7 RR-CONFIG-6 --- Immediate Enforcement After Establishment

Successful configuration immediately activates every applicable
liquidity, swap, commitment, exercise, topology, and permission rule.

------------------------------------------------------------------------

## 5. Service Domain and Liquidity Topology

### 5.1 Boundary meanings

The MVP uses two direction-relative service boundaries:

-   `tickQ`: the protected execution-quality boundary in the protected
    direction;
-   `tickO`: the opposite realization-domain boundary.

Their exact Q64.96 square-root prices are derived using Uniswap TickMath
when required.

For protected `zeroForOne`:

\[ tickQ \< tickO \]

For protected `oneForZero`:

\[ tickQ \> tickO \]

Numeric minimum/maximum are used for domain containment checks.

### 5.2 RR-SC-3 --- Tick-Canonical Service Boundaries

`tickQ` and `tickO` are valid tick-spacing-aligned Uniswap ticks and are
the canonical persisted boundary representation.

Independent authoritative `sqrtQ` or `sqrtO` values are not stored.

### 5.3 RR-SC-5 --- Direction-Relative Boundary Semantics

`tickQ` is defined by protected direction rather than by numerical
low/high position. `tickO` is the opposite boundary.

### 5.4 RR-SC-6 --- Closed Boundary / Strict Interior Topology

The supported price domain includes its boundaries.

LP position endpoints may equal or lie outside the configured boundaries
but may not lie strictly inside the numeric interval.

This permits positions that span the complete domain and harmless
positions entirely outside it while excluding an initialized liquidity
boundary that would invalidate the single-active-liquidity-region
capacity model.

### 5.5 RR-TOPO-1 --- Controlled Service-Topology Establishment

The reference realization starts from zero liquidity and does not
retroactively attach to arbitrary pre-existing liquidity topology.

Every post-configuration liquidity addition encounters Standby
enforcement.

### 5.6 RR-TOPO-2 --- Persistent Supported Operating Domain

The configured service domain remains enforced even when Aggregate
Capacity Obligation is zero.

This preserves the authoritative derivation basis for future Supporting
Capacity.

> **Economic Backing ≠ Realization-Domain Validity**

------------------------------------------------------------------------

## 6. Supporting Capacity Realization

### 6.1 Authoritative inputs

Supporting Capacity is derived, not persisted.

Its authoritative inputs are:

-   current PoolManager `sqrtPriceX96`;
-   current active liquidity;
-   immutable protected direction;
-   canonical `tickQ`, from which `sqrtQ` is derived.

The current PoolManager square-root price is used directly. It is not
reconstructed from the current tick.

### 6.2 RR-SC-1 --- Exact Output-to-Boundary Supporting Capacity

For protected `zeroForOne`, where `sqrtQ < sqrtP`:

\[ S =
`\texttt{SqrtPriceMath.getAmount1Delta}`{=tex}(sqrtQ,sqrtP,L,false) \]

For protected `oneForZero`, where `sqrtQ > sqrtP`:

\[ S =
`\texttt{SqrtPriceMath.getAmount0Delta}`{=tex}(sqrtP,sqrtQ,L,false) \]

The round-down convention matches output-to-target semantics and
prevents overstatement of qualifying output.

### 6.3 RR-SC-2 --- Output-Side Fee Independence

Under the selected promised-result/output denomination, swap fees affect
required input rather than the output-side amount executable to `P_Q`.

Protocol-fee mutation therefore does not directly reduce Supporting
Capacity under this realization, subject to verification of derivation
equivalence.

### 6.4 RR-SC-4 --- Exact Current-Price Derivation

Current price is read from authoritative PoolManager Slot0
`sqrtPriceX96`.

### 6.5 Boundary equality

At `P_Q`:

\[ S=0 \]

This is a valid service-domain state only when:

\[ O=0 \]

because backing still requires (S `\ge `{=tex}O).

------------------------------------------------------------------------

## 7. Prospective State Derivation

### 7.1 Governing rule

A proposed transition is never evaluated by subtracting an independently
estimated amount from Supporting Capacity.

Instead:

> **derive the exact prospective post-transition pool state using the
> same supported v4 semantics, then recompute Supporting Capacity from
> that prospective state.**

### 7.2 RR-SC-7 --- Prospective-State Backing Evaluation

For every backing-affecting transition, derive prospective authoritative
pool state and then derive (S').

### 7.3 RR-SC-8 --- Single-Step Swap Prospective Derivation

Within the no-interior-boundary topology, `beforeSwap` derives
prospective swap price using the same supported
`SwapMath.computeSwapStep` semantics from:

-   current exact square-root price;
-   current active liquidity;
-   authoritative SwapParams;
-   effective v4 fee.

The simplification is valid because:

-   there is no initialized liquidity boundary strictly inside the
    service domain;
-   caller price limits are confined to the domain;
-   LP fee behavior is static;
-   custom accounting is excluded;
-   `beforeSwap` return deltas are excluded.

After deriving prospective price, recompute (S').

### 7.4 RR-SC-9 --- Prospective Liquidity-Removal Derivation

Liquidity removal does not itself move square-root price.

Using the v4 active-range convention:

\[ tickLower `\le `{=tex}currentTick \< tickUpper \]

an active removal changes active liquidity; an inactive removal does
not.

Then derive (S') and require backing preservation.

### 7.5 RR-SC-10 --- Non-Impairing Addition Simplification

After permission and topology checks pass, positive liquidity addition
cannot reduce Supporting Capacity:

-   active addition increases active liquidity;
-   inactive addition leaves active liquidity unchanged.

No independent backing rejection is required beyond the applicable
topology/permission constraints.

------------------------------------------------------------------------

## 8. Permission and Identity Control

### 8.1 Permission domains

The realization preserves separate authority/permission concepts:

-   configuration authority;
-   commitment-establishment authority;
-   Beneficiary eligibility;
-   exercise authority;
-   trader eligibility;
-   liquidity-action eligibility;
-   registry administration authority.

A demo wallet may hold several roles, but the protocol surfaces and
predicates remain semantically distinct.

### 8.2 RR-PERM-1 --- Authoritative Beneficiary Eligibility

The authoritative Beneficiary must be eligible at O1 and must be
rechecked at O2.

### 8.3 RR-PERM-2 --- Eligibility as Exercisability Condition

Loss of Beneficiary eligibility does not invalidate or release a
commitment.

It yields:

-   Validity unchanged;
-   Exercisability false;
-   Remaining Entitlement unchanged;
-   Capacity Obligation unchanged.

Eligibility restoration may restore Exercisability.

### 8.4 RR-PERM-3 --- Admission-Stable Permission Semantics

The registry/predicate semantic role is fixed for the service.
Membership may change.

### 8.5 RR-PERM-4 --- Trusted-Perimeter Participant Resolution

The hook does not infer the economic participant from raw callback
sender or arbitrary hook data.

The immediate caller must be an approved trusted perimeter capable of
authenticated original-caller resolution.

### 8.6 RR-PERM-4A --- Standard Uniswap Trusted Perimeters

The ETHGlobal realization uses:

-   Universal Router for ordinary swaps;
-   PositionManager for liquidity actions;
-   ExerciseRouter for O2.

### 8.7 RR-PERM-5 --- Safety-Complete but Permission-Closed Boundary

Every relevant O3 PoolManager transition remains subject to hook safety
enforcement, while permissioned participation requires an approved
identity-preserving perimeter.

### 8.8 RR-PERM-6 --- Permission-Domain Separation

Beneficiary, trader, liquidity-action, establishment, and exercise
predicates are not collapsed into one generic whitelist concept.

### 8.9 RR-PERM-7 --- Asymmetric Liquidity Permission

Current liquidity-action eligibility is required to introduce or
increase liquidity.

Loss of that eligibility does not prevent economically valid
reduction/full withdrawal or neutral fee collection. Exits remain
subject to backing preservation.

### 8.10 RR-PERM-8R --- Liquidity-Action Eligibility

The MVP permissions the authenticated actor initiating liquidity
add/increase, not eventual PositionManager NFT ownership.

NFT ownership or transfer is not itself a Standby permission event
because it does not change Supporting Capacity.

### 8.11 RR-PERM-10 --- External Eligibility Administration

StandbyHook only queries a dedicated external EligibilityRegistry.

It exposes no membership-management function.

The registry's own authorized administrator mutates membership, while
the PES registry reference and predicate meanings remain immutable.

### 8.12 RR-PERM-11 --- Minimal Demo Registry Administration

The ETHGlobal demo may use a minimal single-owner registry.

Beneficiary, trader, and liquidity-action eligibility remain separate
predicates even if one owner administers all of them.

------------------------------------------------------------------------

## 9. Persistent State and Derived State

### 9.1 Protected Execution Service state

The conceptual minimum PES basis is:

-   service-existence/configured fact;
-   PoolKey;
-   protected direction;
-   `tickQ`;
-   `tickO`;
-   ExerciseRouter;
-   EligibilityRegistry;
-   establishment authority.

### 9.2 RR-STATE-1 --- Persistent PoolKey Basis

PoolKey is persisted because PoolId is not a reversible source for all
immutable pool-key facts required by the service.

PoolId may still serve as a mapping/index key.

### 9.3 RR-STATE-2 --- Hook-Wide Trusted Infrastructure

PoolManager, trusted Universal Router, and trusted PositionManager are
immutable realization-wide dependencies and are not duplicated per
service.

### 9.4 RR-STATE-3 --- Per-Service Exercise Perimeter

ExerciseRouter is bound immutably per PES.

### 9.5 RR-STATE-4 --- Per-Service Eligibility Source

EligibilityRegistry is persisted per PES. Membership may evolve; the
referenced source cannot be replaced for an active PES.

### 9.6 RR-STATE-5 --- Per-Service Establishment Authority

Commitment-establishment authority is persisted per PES.

### 9.7 RR-STATE-6 --- Minimal Service Geometry Basis

Persist protected direction, `tickQ`, and `tickO`.

Derive boundary square-root prices, promised-result currency, and
numeric domain min/max.

### 9.8 RR-STATE-7 --- Single Service-Existence Fact

No independent active/paused state is persisted.

### 9.9 RR-STATE-8 --- No Redundant Fee Mirror

PoolKey is validated against the supported fee model; Standby does not
persist a redundant independent fee-state mirror.

------------------------------------------------------------------------

## 10. Commitment State and Bounded Enforcement References

### 10.1 Commitment basis

A commitment record conceptually persists:

-   immutable service reference;
-   Beneficiary;
-   exercise authority;
-   Original Entitlement;
-   Remaining Entitlement;
-   `exercisableFrom`;
-   `validUntil`.

The mapping key supplies the unique commitment identity.

### 10.2 RR-O1-2 --- Immutable Semantic Reference Sufficiency

A commitment need not duplicate immutable PES semantics when those
semantics remain uniquely and deterministically recoverable from the
immutable service reference.

### 10.3 RR-O1-3 --- No Redundant Semantic Snapshotting

Direction, denomination, service boundaries, qualification semantics,
registry identity, and ExerciseRouter semantics are not copied into
every commitment merely for continuity.

### 10.4 Bounded enforcement-reference set

The MVP supports at most:

\[ MAX_LIVE_COMMITMENTS = 16 \]

simultaneously relevant enforcement references.

`MAX_LIVE_COMMITMENTS` is an implementation constant name only. Membership in the bounded reference structure is **not** authoritative evidence that a commitment is currently valid, exercisable, or Capacity-Obligation-bearing. The economically accurate concept is the **bounded enforcement-reference set**.

This is not a lifetime commitment limit.

Conceptually:

-   `nextCommitmentId`;
-   `commitments[commitmentId]`;
-   fixed-size commitment-reference slots.

Commitment IDs are unique and never recycled. Slots are reusable.

A physically referenced commitment may already be expired and awaiting
reclamation. Slot membership is never authoritative evidence of Validity
or Capacity Obligation.

### 10.5 RR-O1-4 --- Bounded Derived Aggregate Obligation

Aggregate Capacity Obligation is derived by scanning the bounded
references and deriving each commitment's current Capacity Obligation.

It is not independently persisted.

### 10.6 RR-O1-5 --- Non-Reusable Commitment Identity

Commitment IDs are unique and non-recycled.

### 10.7 RR-O1-6 --- Consequence-Governed Live-Set Removal

A commitment reference becomes reclaimable only when authoritative facts
establish that the commitment cannot impose a present or future Capacity
Obligation in the MVP.

### 10.8 RR-O1-7 --- Historical Continuity Across Slot Reuse

Reusing a bounded reference does not delete or overwrite the historical
commitment record.

### 10.9 RR-O1-8 --- Derived Obligation Despite Stale Slot Membership

A stale reference to a terminal commitment contributes zero Capacity
Obligation according to current authoritative derivation and may be
reclaimed during a bounded scan.

------------------------------------------------------------------------

## 11. Temporal Semantics

Define:

-   (T_E): admitted `exercisableFrom`;
-   (T_V): admitted `validUntil`;
-   (t): current authoritative `block.timestamp`.

A successfully established commitment is binding immediately.

Temporal validity is:

\[ t \< T_V \]

Temporal exercise qualification is:

\[ T_E `\le `{=tex}t \< T_V \]

Admission requires:

\[ T_E \< T_V \]

and:

\[ t\_{O1} \< T_V \]

The MVP does not require (T_E `\ge `{=tex}t\_{O1}); an already-open
exercise window may be admitted.

### 11.1 RR-O1-18 --- Establishment-Begins Binding Validity

Successful O1 itself establishes the binding future claim.

### 11.2 RR-O1-19 --- Exercisability-Opening Time

Before `exercisableFrom`, a commitment may remain valid and
backing-binding while not yet exercisable.

### 11.3 RR-O1-20 --- Half-Open Validity Window

At `block.timestamp >= validUntil`:

-   Validity is false;
-   Exercisability is false;
-   Remaining Entitlement is unchanged;
-   Capacity Obligation is zero.

### 11.4 RR-O1-21 --- Derived Time Consequences / No Expiry State

No expiry transaction or cached expired/valid flag is required.

------------------------------------------------------------------------

## 12. O1 --- Commitment Establishment

### 12.1 Authoritative admission flow

O1 performs, in substance:

1.  authenticate establishment authority;
2.  derive the complete proposed commitment;
3.  validate commitment-specific terms;
4.  resolve immutable PES basis;
5.  check current Beneficiary eligibility from the authoritative
    registry;
6.  scan bounded references;
7.  derive current Aggregate Capacity Obligation (O);
8.  find an empty or authoritatively reclaimable slot;
9.  derive proposed commitment Capacity Obligation (CO\_{new});
10. derive (O' = O + CO\_{new});
11. derive current Supporting Capacity (S);
12. require (S `\ge `{=tex}O');
13. allocate a unique commitment ID;
14. persist the complete commitment record;
15. write the bounded reference;
16. advance the ID sequence;
17. emit/return admission evidence.

All economic derivation occurs before authoritative writes.

### 12.2 RR-O1-1 --- Fact-Complete Atomic Admission

A proposed commitment becomes authoritative only after every
establishment predicate succeeds.

### 12.3 RR-O1-9 --- Independent Bounded-Admissibility Constraint

O1 requires both economic backing and an available/reclaimable bounded
reference.

Slot exhaustion is a realization limit, not economic insufficiency.

### 12.4 RR-O1-10 --- Derive-First / Persist-Last Admission

No economically authoritative commitment write occurs before complete
admission validation.

### 12.5 RR-O1-11 --- Single Capacity-Obligation Derivation

The proposed commitment uses the same Capacity Obligation derivation as
existing commitments.

### 12.6 RR-O1-12 --- Atomic Commitment and Live-Index Establishment

Successful O1 atomically establishes identity, commitment basis, bounded
reference, and ID-sequence advance.

### 12.7 RR-O1-13 --- In-Admission Slot Reclamation

O1 may directly reuse a reference belonging to an authoritatively
terminal commitment while preserving its historical record.

### 12.8 RR-O1-14 --- Entitlement Basis Preservation

Persist Original Entitlement and Remaining Entitlement.

Remaining decreases only through qualifying fulfillment.

Cumulative fulfilled amount derives as:

\[ OriginalEntitlement - RemainingEntitlement \]

### 12.9 RR-O1-15 --- Fact-Based Validity Persistence

Validity and Exercisability are derived from authoritative facts rather
than stored lifecycle labels.

### 12.10 RR-O1-17 --- No Redundant Commitment-Derived State

Do not independently persist fulfillment totals, Capacity Obligation,
Validity, Exercisability, lifecycle status, live status, Aggregate
Obligation, or duplicated PES semantics when reconstructible.

------------------------------------------------------------------------

## 13. O2 --- Exercise and Fulfillment

### 13.1 Supported path

The minimum O2 path is:

> Authorized exerciser → ExerciseRouter → PoolManager execution context
> → one exact-output protected swap → StandbyHook `beforeSwap` →
> PoolManager execution → StandbyHook `afterSwap` → authoritative
> input-debt validation/settlement → PoolManager direct output delivery
> to authoritative Beneficiary → Standby finalization → exact Remaining
> Entitlement reduction.

### 13.2 Authority separation

The ExerciseRouter coordinates but does not determine:

-   commitment existence;
-   Beneficiary;
-   exercise authority;
-   Validity;
-   Exercisability;
-   Remaining Entitlement;
-   permissible (q);
-   Supporting Capacity;
-   fulfillment;
-   entitlement reduction.

`hookData` transports causal context but conveys no economic authority.

### 13.3 O2 pre-execution checks

Before the qualifying swap is authorized, Standby verifies:

-   configured ExerciseRouter path;
-   commitment identity;
-   service/pool binding;
-   authoritative Beneficiary;
-   authenticated exercise authority;
-   current Validity;
-   current Exercisability;
-   current Beneficiary eligibility;
-   (q\>0);
-   (q `\le `{=tex}RemainingEntitlement);
-   protected direction;
-   exact-output specification;
-   exact configured `P_Q` price limit;
-   prospective successful post-fulfillment backing.

### 13.4 RR-O2-6 --- Prospective Atomic Backing Evaluation

Before execution, O2 evaluates prospective successful backing against:

\[ O' = O-q \]

but does not authoritatively reduce obligation yet.

Remaining Entitlement changes only after qualifying execution, actual
delivery, causal attribution, and finalization.

### 13.5 RR-O2-7 --- Fixed Qualifying Execution Boundary

Every O2 swap uses the configured `P_Q` as its exact v4 price limit.

Exercise-local boundary substitution is unsupported.

### 13.6 RR-O2-8 --- Exact-Output Qualification Equivalence

O2 uses a protected-direction exact-output swap for exactly canonical
exercise amount (q).

The same direction, boundary convention, active-liquidity model, and
output math used for Supporting Capacity define qualifying execution.

### 13.7 RR-O2-9 --- Exact Individual Exercise Completion

A supported individual exercise either produces exactly (q) under the
qualifying semantics or the complete O2 fails.

Partial commitment fulfillment across multiple successful exercises is
allowed; partial success of one individual exercise is not.

If an O2 that passed authoritative preconditions cannot produce exact
(q) before `P_Q`, that indicates a realization-derivation failure and
the transaction reverts.

### 13.8 RR-O2-10 --- Exercise Cost / Qualification Separation

`P_Q` is the immutable service qualification boundary.

`maxInput` is exercise-local cost protection and does not change
commitment validity, entitlement, obligation, or service semantics.

------------------------------------------------------------------------

## 14. O2 Input Settlement

### 14.1 RR-O2-11 --- Exerciser-Funded Input Settlement

The authenticated exercise caller is the MVP payer.

Arbitrary third-party payer substitution is unsupported.

### 14.2 RR-O2-12 --- Authoritative Debt-Based `maxInput`

After the exact-output swap, the ExerciseRouter derives actual input
obligation from authoritative PoolManager currency debt.

Execution continues only if that exact debt does not exceed the
exerciser's `maxInput`.

### 14.3 RR-O2-13 --- Direct PoolManager Settlement

The exact input debt is funded by the authenticated exerciser and
settled to PoolManager in the same execution context.

The router coordinates but does not intentionally custody the input.

### 14.4 RR-O2-14 --- Settlement / Fulfillment Separation

Paying input debt is not Beneficiary fulfillment and cannot reduce
Remaining Entitlement.

### 14.5 RR-O2-15 --- Exercise-Local Delta Isolation

The supported O2 execution contains no unrelated swaps, cross-commitment
netting, ERC6909 substitution, or other PoolManager activity that would
contaminate exercise-local deltas.

------------------------------------------------------------------------

## 15. O2 Direct Delivery and Finalization

### 15.1 RR-O2-16 --- Direct PoolManager Beneficiary Delivery

The supported output resolution is:

`PoolManager.take(outputCurrency, authoritativeBeneficiary, q)`

The router does not intentionally custody O2 output.

### 15.2 RR-O2-17 --- Structural Delivery Authority

The PoolManager operation that consumes the router's attributable output
credit and transfers exactly (q) to the authoritative Beneficiary is the
reference realization's authoritative delivery mechanism.

### 15.3 RR-O2-18 --- Finalization from Bound Causal Context

Finalization accepts no router-supplied Beneficiary or fulfilled amount
as economic authority.

It operates only on the existing transaction-scoped causal context.

### 15.4 RR-O2-19 --- Restricted Output Resolution Surface

The ExerciseRouter exposes no supported path to clear, tokenize,
redirect, net, or withdraw O2 output elsewhere while still finalizing
fulfillment.

### 15.5 RR-O2-20 --- Actual Post-Execution Backing Confirmation

Before entitlement reduction becomes authoritative, Standby derives
Supporting Capacity from the actual authoritative post-swap PoolManager
state and requires backing against the post-fulfillment obligation.

The prospective check authorizes the transition; the actual-state check
confirms realization equivalence.

Any discrepancy reverts the complete O2.

### 15.6 RR-O2-21 --- Admission-Stable Exercise Perimeter

The configured ExerciseRouter and economically relevant behavior are
immutable for the lifetime of the MVP PES.

### 15.7 RR-O2-22 --- Exact-Transfer Currency Compatibility

The MVP supports currencies whose transfer/settlement behavior preserves
the exact amounts represented by v4 accounting.

Fee-on-transfer, rebasing-transfer, or equivalent incompatible semantics
are outside the reference scope.

------------------------------------------------------------------------

## 16. O2 Transaction-Scoped Causal Proof

The reference causal proof is transaction-scoped rather than a
persistent commitment lifecycle.

Conceptually:

> `EMPTY → AUTHORIZED → EXECUTED → consumed/EMPTY`

The context binds at least:

-   PoolId/service;
-   commitment ID;
-   authenticated ExerciseRouter;
-   authenticated exerciser;
-   authoritative Beneficiary;
-   (q);
-   protected execution context.

### 16.1 RR-O2-4 --- Transaction-Scoped Causal Proof Integrity

Generic swaps cannot manufacture or mutate O2 proof.

Execution evidence cannot be reused across commitments, pools,
exercises, or transactions.

Finalization consumes the proof exactly once.

### 16.2 RR-O2-5 --- Single-Exercise Atomicity Restriction

The MVP supports exactly:

-   one commitment exercise;
-   one qualifying swap;
-   one direct Beneficiary delivery;
-   one finalization

per top-level exercise invocation.

Batching, split execution, multi-commitment netting, and nested O2 are
unsupported.

### 16.3 Economic reentrancy restriction

While an O2 causal context is unresolved, another authoritative Standby
operation may not interleave in a way that observes or mutates an
economically intermediate state.

The exact Solidity guard mechanism is an implementation choice; the
behavioral restriction is not.

------------------------------------------------------------------------

## 17. O3 --- Backing-Affecting Shared-Resource Transitions

O3 classification is based on economic effect rather than function name,
caller, router, component, or nominal code path.

### 17.1 Protected-direction ordinary swap

Derive prospective price using supported v4 semantics, recompute (S'),
and require:

\[ S' `\ge `{=tex}O \]

Ordinary swaps do not reduce obligation.

### 17.2 Opposite-direction ordinary swap

Supporting Capacity normally increases, but the prospective price must
remain within the configured service domain.

### 17.3 RR-O3-1 --- Ordinary Swap Limit Confinement

Ordinary swaps retain caller-selected price limits, but their reachable
path must remain within the configured Standby domain.

The O2 requirement that price limit equal `P_Q` does not apply to
ordinary swaps.

### 17.4 Liquidity removal

For an active removal, derive prospective active liquidity and (S'),
then require:

\[ S' `\ge `{=tex}O \]

For an inactive removal, active liquidity and Supporting Capacity are
unchanged.

### 17.5 Liquidity addition

An addition must:

-   come through an approved participant-provenance perimeter for the
    permissioned MVP;
-   satisfy liquidity-action eligibility when introducing/increasing
    liquidity;
-   not introduce a position boundary strictly inside the service
    domain.

After these checks, positive addition does not require an additional
backing rejection because it cannot reduce Supporting Capacity.

### 17.6 Zero-liquidity-delta operations

An economically neutral zero-delta operation is classified by its actual
effect:

\[ L'=L,`\quad `{=tex}S'=S \]

It receives no special economic meaning merely because of callback
dispatch.

### 17.7 RR-O3-2 --- Prospective Authorization / Verification Equivalence Separation

Runtime O3 authorization uses deterministic prospective state before the
transition becomes authoritative.

The MVP need not duplicate every prospective check with a post-operation
callback. Verification independently proves that the prospective
derivation equals actual v4 transition behavior throughout the supported
domain.

------------------------------------------------------------------------

## 18. Complete Pool Enforcement Surface

### 18.1 Hook permission surface

The minimum hook permissions are:

-   `beforeAddLiquidity = true`
-   `beforeRemoveLiquidity = true`
-   `beforeSwap = true`
-   `afterSwap = true`

All other hook callbacks are disabled for the reference realization.

All return-delta/custom-accounting permissions are disabled.

Every enabled Standby v4 callback must reject authoritative interpretation unless invoked by the immutable PoolManager. Callback enablement defines the enforcement surface; PoolManager authentication defines the authoritative callback boundary.

### 18.2 Economically relevant transition classification

-   initialize: pre-operational setup, not live O3;
-   protected-direction swap: can reduce Supporting Capacity;
-   opposite-direction swap: can violate the supported domain;
-   liquidity removal: can reduce active liquidity and Supporting
    Capacity;
-   liquidity addition: can introduce an interior initialized boundary;
-   donate: not a backing mutation under the selected model;
-   settlement/accounting claim operations: do not independently mutate
    pool price/active-liquidity topology under the selected model;
-   protocol-fee mutation: not directly capacity-reducing under selected
    output-side semantics, subject to derivation-equivalence
    verification;
-   dynamic LP fee behavior: excluded;
-   custom accounting: excluded.

### 18.3 Hook-originated mutation exclusion

StandbyHook must not itself originate backing-affecting PoolManager
swaps or liquidity modifications.

This avoids a self-call enforcement gap.

------------------------------------------------------------------------

## 19. Control Boundaries

### 19.1 RR-CTRL-1 --- Authority-Domain Separation

Configuration, establishment, exercise, eligibility administration,
trader permission, and liquidity permission remain semantically
distinct.

### 19.2 RR-CTRL-2 --- Post-Activation Semantic Immutability

No admin path changes the PES semantic basis after activation.

### 19.3 RR-CTRL-3 --- Operational-Membership Mutability Only

Registry membership may change only as an operational input under the
already-fixed permission semantics.

### 19.4 RR-CTRL-4 --- No Administrative Backing Rewrite

No authority can directly reduce Remaining Entitlement, Aggregate
Capacity Obligation, Supporting Capacity requirements, or bounded
enforcement participation to accommodate backing pressure.

### 19.5 RR-CTRL-5R --- No Administrative Commitment Release in MVP

A commitment ceases to impose future Capacity Obligation only through:

1.  qualifying fulfillment exhaustion; or
2.  temporal validity ending at `validUntil`.

### 19.6 RR-CTRL-6 --- No Generic Semantic Deactivation

There is no pause/deactivate mechanism that terminates, releases, or
reinterprets existing commitments.

------------------------------------------------------------------------

## 20. Authoritative-Path and Bypass Closure

### 20.1 RR-PATH-1 --- PoolManager-Authenticated Hook Callbacks

Authoritative v4 callback evidence is accepted only from the immutable
PoolManager.

Direct fabricated callback invocation cannot establish Standby economic
truth.

### 20.2 Generic router cannot masquerade as O2

O2 classification requires the configured authenticated ExerciseRouter
path.

Commitment-shaped hook data from an ordinary router remains ordinary O3
behavior.

### 20.3 Direct finalization cannot manufacture fulfillment

Finalization requires the matching transaction-scoped EXECUTED causal
context.

No context means no entitlement mutation.

### 20.4 No proof reuse

Causal evidence cannot be reused:

-   twice;
-   for another commitment;
-   for another pool;
-   in another transaction.

### 20.5 Registry administration cannot release backing

Changing Beneficiary eligibility affects current Exercisability only. It
does not reduce Remaining Entitlement or Capacity Obligation.

### 20.6 Configuration cannot be replayed

Once the service exists, configuration cannot be used to replace
boundaries, registry, router, direction, or establishment authority.

### 20.7 RR-PATH-2 --- Behavioral Immutability of Semantic Dependencies

A dependency whose behavior is relied upon as immutable PES semantics
must not retain an administrative upgrade/replacement path capable of
changing economically relevant behavior for existing commitments.

The MVP therefore uses non-upgradeable semantic dependencies.

### 20.8 RR-PATH-3 --- No Economic Reentrancy Across Unresolved O2

Nested or interleaved authoritative Standby operations may not observe
or mutate unresolved O2 intermediate state.

### 20.9 RR-PATH-4 --- Single Authoritative Mutation Paths

Every economically meaningful Standby mutation has one authoritative
transition path.

### 20.10 RR-PATH-5 --- No Hidden Release Surface

Administrative, registry, routing, indexing, or bookkeeping operations
cannot release a still-binding Capacity Obligation.

### 20.11 RR-PATH-6 --- Enforcement-Surface Closure

Every supported authoritative PoolManager path capable of impairing the
protected backing property encounters Standby enforcement. Approved
perimeters determine participant authentication, not backing-safety
completeness.

------------------------------------------------------------------------

## 21. Authoritative Consequence Ownership

  -----------------------------------------------------------------------
  Economic consequence                Authoritative path
  ----------------------------------- -----------------------------------
  PES establishment                   `configureAndActivate`

  PES semantic mutation after         none
  establishment                       

  Registry membership mutation        EligibilityRegistry administrator

  Commitment establishment            O1

  Remaining Entitlement reduction     successful O2 finalization

  Fulfillment                         exact qualifying O2 execution +
                                      direct delivery + causal
                                      finalization

  Capacity Obligation release         fulfillment exhaustion or derived
                                      expiry

  Supporting Capacity change          authoritative v4 pool transition

  Protected-capacity impairment       PoolManager transition subject to
                                      O3

  Bounded-reference reclamation       canonical consequence derivation
                                      during bounded processing

  Historical commitment deletion      none required
  -----------------------------------------------------------------------

------------------------------------------------------------------------

## 22. Failure Atomicity and Economic Finality

### 22.1 Configuration failure

Failure establishes no PES and leaves no partial service state.

### 22.2 O1 failure

Failure creates no authoritative commitment, bounded reference, or
partial economic relationship.

### 22.3 O2 failure

Failure produces no authoritative fulfillment and no Remaining
Entitlement reduction.

Any PoolManager execution, settlement, delivery, or causal-proof
intermediate effect must roll back with the failed top-level exercise.

### 22.4 O3 failure

A rejected backing-affecting transition does not become authoritative in
PoolManager.

### 22.5 Reference atomicity mechanism

The MVP uses EVM transaction rollback as the realization mechanism for
the canonical requirement of authoritative economic atomicity.

This is a realization choice, not the general definition of economic
atomicity.

------------------------------------------------------------------------

## 23. Positive Permissiveness

Safety is not sufficient if the realization rejects behavior that the
frozen semantics permit.

The reference implementation must preserve at least these boundary
cases:

-   backing equality (S=O);
-   O1 equality (S=O');
-   O1 whose exercise window is already open;
-   service configuration with zero Supporting Capacity;
-   current price exactly on a closed service boundary where other
    requirements hold;
-   topology-valid LP positions whose endpoints equal or lie outside the
    service domain;
-   harmless positions entirely outside the service domain;
-   LP reduction/exit after loss of add eligibility, subject to backing;
-   reclaiming an authoritatively terminal bounded reference during O1
    without a prior keeper transaction;
-   zero Aggregate Capacity Obligation while retaining
    service-domain/topology enforcement.

------------------------------------------------------------------------

## 24. Currency, Fee, Pool, and Accounting Compatibility

The ETHGlobal realization supports only the domain for which its
authoritative derivations have been established.

### 24.1 Supported assumptions

-   Uniswap v4 PoolManager;
-   static LP fee model compatible with the selected prospective
    derivation;
-   exact-transfer-compatible currencies;
-   no custom accounting return deltas;
-   no dynamic LP-fee behavior that invalidates the selected derivation;
-   no unsupported exercise-local output substitution.

### 24.2 Excluded behaviors

The MVP does not claim correctness for:

-   fee-on-transfer currencies;
-   rebasing-transfer behavior capable of breaking exact delivery;
-   dynamic LP-fee semantics outside the selected proof;
-   custom accounting that changes authoritative swap amounts;
-   arbitrary tick traversal through interior initialized boundaries;
-   exercise output represented only by claims rather than direct
    Beneficiary delivery.

------------------------------------------------------------------------

## 25. Atomicity and Reentrancy Assumptions

The supported O2 execution is intentionally narrow:

-   one top-level exercise;
-   one commitment;
-   one exact-output swap;
-   one input settlement;
-   one direct output delivery;
-   one finalization.

No batching, nested O2, split execution, or unrelated PoolManager
netting is supported.

Transaction-scoped evidence is used only for intermediate causal facts.
Persistent state records the economically final consequence.

------------------------------------------------------------------------

## 26. Verification Obligations

Implementation acceptance remains governed by the frozen
`testing-strategy.md`.

The reference realization must supply evidence across the frozen
verification families:

### VF-1 --- Positive Acceptance Verification

Prove required/permitted behavior succeeds, including equality and
permissiveness boundaries.

### VF-2 --- Negative Rejection Verification

Prove forbidden behavior cannot become authoritative.

### VF-3 --- Authoritative Derivation Equivalence

Independently prove implementation derivations equal the
normative/reference derivations.

Critical v4-specific VF-3 targets include:

-   Supporting Capacity delta formulas versus actual v4 execution to
    `P_Q`;
-   prospective swap price derivation versus actual PoolManager result;
-   active-liquidity removal derivation versus actual v4 liquidity
    behavior;
-   output-side fee-independence assumption;
-   protocol-fee treatment under the selected capacity denomination;
-   exact current-price handling;
-   boundary rounding conventions.

### VF-4 --- Transition-Result Verification

Verify the authoritative post-state of configuration, O1, O2, and O3.

### VF-5 --- Invariant Preservation Verification

Verify all frozen canonical invariants, including backing sufficiency
and complete enforcement.

### VF-6 --- Domain-Completeness Verification

Verify every supported authoritative path capable of producing the
relevant economic effect is covered, including alternate PoolManager
callers.

### VF-7 --- Economic-Finality Verification

Verify failed attempts leave zero prohibited authoritative economic
residue.

### 26.1 O2-specific verification

Verification must establish:

-   generic routers cannot obtain O2 semantics through hook data;
-   caller provenance cannot be forged;
-   exact-output (q) is enforced;
-   `P_Q` is fixed;
-   prospective (S' `\ge `{=tex}O-q) is correct;
-   actual output equals (q);
-   actual post-state Supporting Capacity satisfies post-fulfillment
    backing;
-   actual PoolManager input debt governs `maxInput`;
-   payer is the authenticated exerciser;
-   output goes directly to authoritative Beneficiary;
-   finalization requires and consumes matching causal proof;
-   double/cross-commitment/cross-pool proof reuse fails;
-   failure rolls back entitlement and pool effects.

### 26.2 O3-specific verification

Verification must establish:

-   protected ordinary swaps preserve (S' `\ge `{=tex}O);
-   opposite swaps remain inside the service domain;
-   alternate router paths cannot bypass backing enforcement;
-   liquidity removals preserve backing;
-   topology-invalid additions reject;
-   topology-valid additions remain permissive;
-   zero-delta operations are economically neutral;
-   zero-obligation state does not disable domain/topology continuity;
-   hook-originated backing mutation is absent.

### 26.3 Permission-specific verification

Verification must establish:

-   Beneficiary, trader, and liquidity-action predicates remain
    distinct;
-   registry membership changes affect only the intended operational
    predicates;
-   eligibility loss does not release obligation;
-   LP exits are not incorrectly blocked by loss of add eligibility;
-   unapproved identity perimeters cannot manufacture participant
    identity;
-   StandbyHook cannot mutate registry membership.

------------------------------------------------------------------------

## 27. MVP Restrictions vs Production Generalization

The following are deliberate reference-realization restrictions, not
general Standby semantics.

  ----------------------------------------------------------------------------------
  MVP restriction               Why it exists           Production generalization /
                                                        additional proof burden
  ----------------------------- ----------------------- ----------------------------
  Uniswap v4 shared AMM         Concrete ETHGlobal      New AMM requires equivalent
                                target                  authoritative capacity and
                                                        enforcement model

  One protected direction per   Reduces service/state   Bidirectional service
  PES                           complexity              requires independent
                                                        directional
                                                        obligations/capacity and
                                                        composition proof

  No initialized liquidity      Makes Supporting        Arbitrary topology requires
  boundary strictly inside      Capacity and            authoritative tick traversal
  domain                        prospective swaps       and equivalence proof
                                single-region           
                                derivations             

  Zero-liquidity configuration  Establishes known       Adoption of existing pools
  bootstrap                     topology without        requires complete
                                historical scan         authoritative topology
                                                        discovery/admission proof

  `MAX_LIVE_COMMITMENTS = 16`   Bounded gas and         Larger/unbounded sets
                                deterministic scan      require scalable aggregate
                                                        derivation without
                                                        synchronization weakness

  Aggregate obligation derived, Avoids synchronization  Cached/accumulator model
  not cached                    invariant at bounded    requires update-completeness
                                size                    and reconciliation proof

  One exact-output swap per O2  Preserves exact         Split/batched execution
                                promised-result         requires exact multi-leg
                                semantics and simple    attribution and atomic
                                causal attribution      fulfillment proof

  No O2 batching/netting        Prevents delta          Batching requires per-cause
                                contamination           accounting and isolation
                                                        proof

  Direct PoolManager delivery   Strong actual-delivery  Alternate delivery mechanism
                                evidence                requires equivalent
                                                        Beneficiary-receipt proof

  Exerciser is payer            Removes                 Third-party payer requires
                                payer-attribution       authenticated
                                ambiguity               consent/payment semantics

  Exact-transfer currencies     Makes v4 amount         Non-standard currencies
                                correspond to actual    require independent
                                delivery                actual-receipt measurement

  Static LP fee compatibility   Keeps prospective       Dynamic fee support requires
                                derivation              exact authoritative fee
                                deterministic           resolution in prospective
                                                        derivation

  No custom accounting          Prevents amount         Custom accounting requires
                                reinterpretation        derivation equivalence
                                                        across hook deltas

  Approved Universal Router /   Supplies trusted        Additional periphery
  PositionManager               participant provenance  requires equivalent
                                                        authenticated
                                                        original-caller semantics

  Dedicated simple registry     Makes mutable           Rich
                                permission source       KYC/attestation/governance
                                explicit                systems require stable
                                                        semantic-source and
                                                        failure-mode proof

  Single-owner demo registry    Hackathon simplicity    Production administration
                                                        may use
                                                        RBAC/multisig/governance
                                                        without changing permission
                                                        semantics

  Non-upgradeable semantic      Preserves               Upgradeable systems require
  dependencies                  admission-time meaning  version binding or
                                                        equivalent semantic
                                                        continuity

  One-shot immutable PES        Eliminates              Production evolution should
                                reinterpretation        use versioned service
                                                        generations

  No admin commitment release   Avoids new release      Production
                                authority/cause         cancellation/invalidation
                                                        requires canonical cause,
                                                        authority, persistence, and
                                                        backing-release verification

  No generic pause/deactivate   Avoids ambiguous        Production emergency
                                obligation semantics    controls require explicit
                                                        treatment of Validity,
                                                        Exercisability, and
                                                        continuing obligation

  EVM rollback for atomicity    Native implementation   Other execution environments
                                mechanism               require equivalent
                                                        economic-finality mechanism
  ----------------------------------------------------------------------------------

Production generalization must preserve the frozen canonical semantics
rather than treating these MVP restrictions as the semantics themselves.

------------------------------------------------------------------------

## 28. Cross-System Composition

The reference lifecycle is:

> **Initialize pool → Establish immutable PES → Add controlled liquidity
> → Derive Supporting Capacity → Admit backed commitments → Preserve
> backing through O3 → Fulfill through O2 or release through expiry →
> Reclaim bounded references without deleting history**

### RR-SYS-1 --- Reachable Controlled Bootstrap

The lifecycle has no circular dependency: configuration requires zero
liquidity; liquidity requires configured service.

### RR-SYS-2 --- Immediate Cross-Operation State Visibility

O1, O2, and O3 derive from the same authoritative service, commitment,
registry, PoolManager, and temporal facts.

A successful operation's authoritative consequences are immediately
visible to the next operation without a cached aggregate synchronization
step.

### RR-SYS-3 --- Exhaustive MVP Non-Binding Causes

The only MVP causes that permanently eliminate future Capacity
Obligation are:

-   qualifying fulfillment exhaustion;
-   temporal validity ending.

### RR-SYS-4 --- Realization-Domain Continuity Independent of Current Obligation

Service-domain/topology enforcement remains active even when (O=0).

------------------------------------------------------------------------

## 29. Implementation-Handoff Boundary

### RR-HANDOFF-1 --- Authoritative Realization Sufficiency

This realization determines:

-   authoritative components;
-   trust boundaries;
-   persistent economic facts;
-   derived facts;
-   service-establishment path;
-   permission sources;
-   Supporting Capacity derivation;
-   O1 behavior;
-   O2 behavior;
-   O3 behavior;
-   obligation-ending causes;
-   failure semantics;
-   bypass exclusions.

Implementation should not invent additional protocol-correctness
decisions.

### RR-HANDOFF-2 --- Implementation Freedom Below Semantic Boundary

The following remain implementation-design choices where behavior is
equivalent:

-   Solidity function names;
-   internal helper decomposition;
-   struct/storage packing;
-   custom errors;
-   event naming and indexing;
-   library boundaries;
-   equivalent guard implementation;
-   gas optimizations that do not alter authoritative semantics.

### RR-HANDOFF-3 --- MVP Restriction Explicitness

Every narrowing restriction must remain identified as a
reference-realization choice and must not silently migrate into the
general Standby canonical semantics.

------------------------------------------------------------------------

## 30. Reference-Realization Decision Index

The frozen realization families represented by this artifact are:

-   **RR-SETUP-\*** --- pool establishment and pre-activation closure
-   **RR-CONFIG-\*** --- one-shot service configuration and activation
-   **RR-TOPO-\*** --- controlled topology and persistent domain
-   **RR-SC-\*** --- Supporting Capacity and prospective-state
    derivation
-   **RR-STATE-\*** --- persistent PES basis and state minimality
-   **RR-PERM-\*** --- participant identity, eligibility, and registry
    administration
-   **RR-O1-\*** --- commitment admission, bounded references,
    persistence, and time semantics
-   **RR-O2-\*** --- exercise, execution, settlement, delivery, causal
    proof, and finalization
-   **RR-O3-\*** --- shared-resource transition authorization
-   **RR-CTRL-\*** --- administrative/control boundaries
-   **RR-PATH-\*** --- authoritative-path and bypass closure
-   **RR-SYS-\*** --- cross-system composition
-   **RR-HANDOFF-\*** --- implementation-handoff sufficiency

------------------------------------------------------------------------

## 31. Draft Status and Required Final Gate

All substantive realization decisions represented here have individually
or compositionally passed their derivation gates.

This artifact itself is not yet declared final merely because its source
decisions are frozen.

Before freezing `uniswap-v4-realization.md`, perform a whole-artifact
fidelity gate proving:

1.  every frozen realization decision is represented;
2.  no decision has been strengthened or weakened;
3.  no general Standby semantic has been replaced by an MVP restriction;
4.  no implementation detail has been accidentally promoted to canonical
    protocol meaning;
5.  terminology remains consistent with the frozen canonical package;
6.  all authoritative state and derived-state distinctions are
    preserved;
7.  O1/O2/O3 compose exactly as frozen;
8.  setup, configuration, registry administration, and control-plane
    behavior are complete;
9.  bypass and failure semantics are complete;
10. every implementation-significant realization decision has a
    corresponding verification obligation or traceable verification
    family.

**Final artifact status: FINAL PASS / FROZEN.**

The whole-artifact fidelity gate passed after the two non-semantic fidelity corrections already incorporated into this artifact. The post-correction final gate passed without reopening or changing any frozen realization decision.

**UNISWAP v4 REFERENCE REALIZATION / IMPLEMENTATION HANDOFF — FINAL PASS / FROZEN.**
