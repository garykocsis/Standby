# Standby — Session 05

## Objective

Implement:

> **F3 — StandbyHook Trust + PES Configuration**

Validated prerequisite frontier:

- F0 / G0 — PASS
- F1 / G1 — PASS
- F2 / G2 — PASS

F3 implements only **H1 — Trust / Configuration** from the frozen StandbyHook decomposition.

The result must be a correctly permissioned `StandbyHook` with immutable realization-wide trust dependencies and one complete, one-shot Protected Execution Service configuration, without implementing commitment economics or O3 enforcement.

G3 is the verification boundary for this session.

---

# F3 Implementation Boundary

## 1. Hook-Wide Immutable Trust

The reference realization requires these realization-wide Hook dependencies to be fixed immutably and not duplicated into per-PES state:

- PoolManager;
- configuration authority;
- trusted Universal Router / ordinary-swap perimeter;
- trusted PositionManager / liquidity perimeter.

Preserve the existing immutable PoolManager binding.

Extend the canonical Hook deployment path as necessary so the production Hook receives the additional F3 Hook-wide trust dependencies.

There must remain one canonical `StandbyHook` deployment path.

The Universal Router and PositionManager are distinct trusted-perimeter **roles**. Do not collapse them into one generic trusted-router concept.

Do not infer that semantically distinct authority roles must necessarily be held by different Ethereum addresses unless an authoritative requirement independently demands address inequality.

---

## 2. One-Shot PES Lifecycle

One Hook instance realizes one configured PES / one PoolId for the MVP.

The only service lifecycle is:

```text
UNCONFIGURED -> ACTIVATED
```

Implement one atomic:

```text
configureAndActivate(...)
```

transition.

There must be no:

- partial configuration setters;
- separate configured-versus-active lifecycle;
- generic active flag that can later be toggled;
- pause;
- deactivation;
- reconfiguration;
- semantic replacement;
- migration;
- cancellation;
- post-activation service setter.

A failed activation attempt must leave the Hook unconfigured with no partial PES basis persisted.

---

## 3. Authoritative PES Basis

Successful activation must persist the minimum complete PES semantic basis required by the frozen realization:

- service-existence/configured fact;
- complete PoolKey;
- protected direction;
- `tickQ`;
- `tickO`;
- designated ExerciseRouter / O2 coordinator;
- EligibilityRegistry reference;
- commitment-establishment authority.

PoolId may be derived and/or used as the service identity/index, but it is not a substitute for the complete persisted PoolKey basis.

EligibilityRegistry, ExerciseRouter, establishment authority, direction and service geometry become immutable service semantics after activation.

The EligibilityRegistry reference is fixed; Registry membership remains externally mutable under the F2 Registry.

Do not implement Registry membership consumption in F3.

---

## 4. Do Not Persist Derived Service Facts

F3 must not persist redundant authoritative copies of facts deterministically derivable from the PES basis.

In particular, do not persist independent:

- `sqrtQ`;
- `sqrtO`;
- numeric service-domain minimum/maximum;
- promised-result/output currency;
- Supporting Capacity;
- Aggregate Capacity Obligation;
- commitment obligation;
- prospective Supporting Capacity;
- lifecycle classifications belonging to later slices.

The canonical persisted service boundaries are `tickQ` and `tickO`.

---

## 5. Activation Authority

Only the configured Hook-wide configuration authority may successfully execute `configureAndActivate`.

Unauthorized attempts must create no PES state.

Configuration authority remains semantically distinct from:

- commitment-establishment authority;
- exercise authority;
- EligibilityRegistry administration;
- trader eligibility;
- liquidity-action eligibility.

Do not add role hierarchy, ownership transfer, governance, multisig, timelock or upgradeability machinery.

---

## 6. Activation Environmental Validation

Before any PES state is persisted, `configureAndActivate` must validate the authoritative initialized Uniswap v4 environment.

The activation path must:

1. authenticate configuration authority;
2. derive the PoolId from the supplied PoolKey;
3. verify the PoolKey binds this exact `StandbyHook`;
4. verify the pool is initialized;
5. verify the PES does not already exist;
6. verify authoritative current pool liquidity is zero;
7. validate the supported fee/accounting model;
8. read authoritative current pool price;
9. validate protected direction;
10. validate `tickQ` and `tickO`;
11. validate current price lies in the closed configured service domain;
12. validate the designated ExerciseRouter;
13. validate the EligibilityRegistry;
14. validate commitment-establishment authority;
15. validate the Hook-wide trusted realization dependencies;
16. persist the complete PES atomically.

Pool initialization, current liquidity and current price must be established from the real pinned PoolManager state, not caller-supplied substitutes.

All validation must occur before authoritative PES persistence.

---

## 7. Supported Pool / Accounting Model

Activation must accept only the frozen reference-realization pool model.

Preserve the static-fee-compatible, no-custom-accounting realization restrictions.

Do not introduce dynamic-fee support or custom-accounting interpretation in F3.

Do not duplicate PoolKey fee information into a separate mutable or persisted fee mirror.

---

## 8. Service-Domain Validation

`tickQ` and `tickO` are direction-relative semantic boundaries.

For protected `zeroForOne`:

```text
tickQ < tickO
```

For protected `oneForZero`:

```text
tickQ > tickO
```

Both boundaries must be valid Uniswap ticks and aligned to the configured pool tick spacing.

The service domain is closed.

Therefore activation may succeed when authoritative current price lies:

- strictly inside the domain;
- exactly at `tickQ`;
- exactly at `tickO`.

Activation must reject authoritative current price outside the service domain.

Do not derive or implement Supporting Capacity in F3.

---

## 9. Trusted Perimeter Ownership

Universal Router and PositionManager are Hook-wide immutable trusted infrastructure.

They must not be redundantly stored as independent per-PES semantic fields.

`configureAndActivate` must validate that the service is being established against the Hook's already-fixed trusted realization dependencies.

The designated ExerciseRouter is different in ownership:

- it is a per-PES semantic fact;
- it is fixed during activation;
- its role remains distinct from ordinary-swap and liquidity trusted-perimeter roles.

F3 binds the designated ExerciseRouter address/role only.

Do not implement ExerciseRouter transaction behavior in this slice.

Do not invent an ExerciseRouter bytecode/interface/protocol probe unless required by an authoritative source or the actual pinned implementation boundary.

---

## 10. EligibilityRegistry Binding

Use the F2 `EligibilityRegistry` as the external mutable eligibility source.

The PES must retain the exact configured Registry reference after activation.

The Hook must not:

- duplicate Registry membership;
- expose membership-management functions;
- implement Beneficiary eligibility enforcement;
- implement trader eligibility enforcement;
- implement liquidity eligibility enforcement;
- derive commitment consequences from eligibility.

Those behaviors belong to downstream slices.

---

## 11. Callback Trust Boundary

Preserve the existing four enabled Hook callbacks:

- `beforeAddLiquidity`;
- `beforeRemoveLiquidity`;
- `beforeSwap`;
- `afterSwap`.

All other callbacks and all return-delta/custom-accounting permissions remain disabled.

Every enabled callback must remain authoritative only when invoked by the immutable PoolManager.

F3 does not implement H4 callback classification or O3 policy.

Existing downstream callbacks may remain fail-closed until their owning slice.

Do not implement:

- trader provenance resolution;
- liquidity actor provenance resolution;
- liquidity eligibility;
- topology enforcement;
- service-domain swap enforcement;
- prospective backing enforcement.

F6A owns those responsibilities.

---

# Explicitly Out of Scope

Do not implement:

- F4 commitment storage;
- bounded commitment references;
- commitment IDs;
- F5 Supporting Capacity;
- Aggregate Capacity Obligation;
- authoritative economic derivation helpers;
- prospective `S'`;
- F6A O3 enforcement;
- liquidity admission;
- ordinary-swap Standby enforcement;
- F7 O1 commitment establishment;
- F8 ExerciseRouter behavior;
- O2 authorization;
- transaction-scoped exercise context;
- PoolManager exercise execution;
- Beneficiary delivery;
- fulfillment evidence;
- Remaining Entitlement reduction;
- invariant handlers for downstream economic state;
- acceptance behavior;
- frontend/demo instrumentation.

F3 must not introduce production state merely to prepare these later slices.

---

# File Boundary

Expected production changes are limited to the F3 trust/configuration responsibility, principally:

```text
src/StandbyHook.sol
```

The existing canonical Hook deployment path and its helpers/tests may change as required to bind the new Hook-wide immutable F3 dependencies.

F3 may add focused unit, fuzz, integration or shared activated-fixture test files when they provide direct G3 evidence.

Do not create:

```text
src/ExerciseRouter.sol
src/libraries/StandbyMath.sol
src/libraries/CommitmentRefs.sol
```

or other downstream production components in this slice.

Do not create speculative future test infrastructure that F3 itself does not consume.

---

# G3 Verification Evidence

## G3-H — Hook Deployment Fidelity

Using the actual production Hook through the canonical deployment path, prove:

1. immutable PoolManager is exact;
2. immutable configuration authority is exact;
3. immutable ordinary-swap trusted perimeter is exact;
4. immutable liquidity trusted perimeter is exact;
5. exactly the four required callbacks remain enabled;
6. every other callback remains disabled;
7. all return-delta permissions remain false;
8. deployed Hook address bits match declared permissions;
9. non-PoolManager direct callback invocation cannot become authoritative.

Harness-only evidence is insufficient for G3-H.

---

## G3-C — Configuration / Trust Fidelity

Prove positive activation when every required condition is satisfied.

Prove independently that each necessary activation boundary participates in admission, including as applicable:

1. only configuration authority can activate;
2. activation succeeds exactly once;
3. wrong Hook binding is rejected;
4. uninitialized pool is rejected;
5. nonzero-liquidity pool is rejected using authoritative PoolManager state;
6. unsupported fee/accounting form is rejected;
7. invalid protected-direction/domain relationship is rejected;
8. invalid or misaligned service ticks are rejected;
9. authoritative current price outside the closed service domain is rejected;
10. boundary equality at `tickQ` is accepted;
11. boundary equality at `tickO` is accepted;
12. invalid Registry configuration is rejected;
13. invalid ExerciseRouter configuration is rejected;
14. invalid establishment-authority configuration is rejected;
15. invalid trusted realization dependency configuration is rejected where applicable.

For every rejected activation attempt, prove no partial PES configuration becomes authoritative.

After successful activation, prove exact read fidelity for the complete persisted PES basis:

- PoolKey / PoolId identity;
- Registry;
- direction;
- `tickQ`;
- `tickO`;
- ExerciseRouter;
- establishment authority;
- service existence.

Also prove:

- Registry reference cannot be replaced;
- direction/domain cannot be replaced;
- ExerciseRouter cannot be replaced;
- establishment authority cannot be replaced;
- trusted ordinary-swap and liquidity roles remain semantically distinct;
- ExerciseRouter trust remains semantically distinct from ordinary periphery trust;
- establishment authority remains semantically distinct from configuration/exercise/eligibility authority;
- no post-activation service reinterpretation path exists.

Where geometry has a meaningful input domain, use fuzz evidence to exercise direction-relative ordering, valid-tick bounds and tick-spacing alignment rather than proving only the canonical fixture values.

Use real PoolManager integration evidence for initialized-state, current-liquidity and current-price activation conditions.

---

# Canonical Fixture Integration

The F1 Hook-bound canonical pool remains the intended canonical positive activation fixture:

- MockUSTB = currency0;
- MockUSDC = currency1;
- fee = 500;
- tick spacing = 10;
- initial tick = 0;
- zero liquidity before F3 activation;
- protected direction = zeroForOne;
- `tickQ = -240`;
- `tickO = +240`.

F3 must not modify the accepted F1 two-pool sequencing model.

The separate no-Hook geometry pool remains an F1 verification fixture and is not the authoritative activated Standby service.

Production F3 logic must not hard-code the canonical token identities, direction, ticks, fee or decimal properties.

---

# Completion Boundary

Complete F3 and produce the evidence required for G3.

At task completion, provide a **proposed G3 assessment** and stop.

Do not begin F4 or any downstream implementation slice.
