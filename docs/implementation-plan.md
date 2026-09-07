## Standby — Implementation Plan

**Status:** FINAL PASS / FROZEN
**Amendments:** 2026-09-05 — §10.11 G5-C clarified to require heterogeneous currency-decimal generalization and prohibit production dependence on the canonical 6-decimal fixture. This is a verification-strengthening clarification and does not alter frozen protocol semantics.  
2026-09-06 — F5 real-PoolManager differential verification corrected the Uniswap v4 prospective-swap realization: no-interior initialized liquidity boundaries do not imply single-step `computeSwapStep` execution because tick-bitmap word boundaries may require multiple arithmetic steps. The plan now requires exact bounded prospective traversal plus admission-time validation that an immutable PES domain lies within the supported traversal bound. This is a Uniswap v4 realization correction and does not alter frozen Standby economics.
**Project:** Standby  
**Tagline:** _Execution capacity when you need it._  
**Technical descriptor:** Protocol-enforced future execution capacity from shared AMM liquidity.

---

## 1. Purpose

This document defines the implementation order, production component decomposition, deployment/bootstrap structure, test architecture, verification gates, demo instrumentation, and evidence boundaries for the Standby Uniswap v4 reference implementation.

It is an implementation handoff. It does not redefine Standby economics, specification semantics, state semantics, invariants, architecture, or verification obligations. Where this document appears to conflict with a frozen upstream canonical artifact, the upstream artifact is authoritative and this plan must be corrected.

The implementation objective is to realize the frozen Standby behavior on the actual Uniswap v4 execution stack while preserving the core economic relationship:

- **Supporting Capacity, S** is qualifying directional executable capacity derived from authoritative PoolManager state.
- **Aggregate Capacity Obligation, O** is derived from live binding commitment facts.
- Every reachable authoritative state must preserve **S >= O**.

Standby does not reserve protected output inventory. It protects qualifying execution capacity while compatible shared AMM use remains possible.

---

## 2. Governing Implementation Rules

### 2.1 Upstream semantic authority

The frozen canonical package remains authoritative:

1. `context.md`
2. `economic-agreement.md`
3. `mechanism.md`
4. `spec.md`
5. `architecture.md`
6. `state-machine.md`
7. `invariants.md`
8. `testing-strategy.md`
9. `uniswap-v4-realization.md`
10. `demo-spec.md`

This plan may sequence, decompose, test, and operationalize those semantics. It may not strengthen, weaken, reinterpret, or replace them.

### 2.2 Verification-gated dependency

A downstream implementation responsibility may depend on an upstream responsibility only after the upstream responsibility has produced the verification evidence required by its gate.

> **Dependency Readiness = Implementation + Required Verification Evidence**

Compilation or code existence is not sufficient dependency readiness.

### 2.3 Production derivation singularity

Every production behavior or production read that requires a Standby economic derivation must resolve through the same Hook-owned authoritative derivation layer.

O1, O2, O3, read-only observability, and preview diagnostics may consume that layer. Production code must not maintain duplicated formulas for Supporting Capacity, Aggregate Capacity Obligation, validity, exercisability, commitment obligation, or prospective safety.

Independent test/reference derivations are permitted only as verification oracles and must never be consumed by production behavior.

### 2.4 Harness isolation

A test harness may expose otherwise inaccessible production logic and may narrowly seed authoritative input facts for isolated unit/fuzz verification.

Harness-only access or seeded state is not valid evidence for:

- production transition correctness,
- integration correctness,
- invariant correctness,
- periphery/identity correctness,
- canonical acceptance correctness.

### 2.5 Acceptance-fixture independence

Canonical acceptance must construct economically meaningful state through the same deployment, configuration, and behavioral paths expected in the real system.

> **Acceptance Fidelity = Real Construction Path + No Privileged Economic State**

No acceptance evidence may depend on direct Hook storage mutation, `vm.store`, harness seeding, test-only economic setters, pre-created commitments, or inherited prepared economic state.

### 2.6 Authoritative action construction

Helpers may package authoritative actions; they may not substitute for authoritative actions.

Examples:

- `_establishCanonicalCommitment()` may call the real O1 entry point.
- `_executeCompatibleSwap()` may execute the real router → PoolManager → Hook path.
- No helper may directly set S, O, Remaining Entitlement, commitment liveness, current tick, or O2 causal state.

### 2.7 Demo authority

The demo UI is instrumentation, not a second state machine.

Every persistent economic value shown in the canonical demo must come from authoritative on-chain state or transaction results. The frontend may format and label values but may not independently derive or maintain Standby economic truth.

---

## 3. Critical-Path Implementation Ladder

The implementation sequence is:

```text
F0   v4 Infrastructure / Deployment Foundation
F1   Deterministic Economic Fixture
F2   EligibilityRegistry
F3   StandbyHook Trust + PES Configuration
F4   Commitment Storage / Bounded Enforcement References
F5   Authoritative Derivation Kernel
F6A  Preliminary O3 Enforcement with O = 0
F7   O1 Commitment Admission
F6B  O3 Enforcement with Authentic O > 0
F8A  O2 Authorization / Hook-Owned Causal Context
F8B  O2 Exact-Output Execution / Execution Evidence
F8C  O2 Authoritative Settlement / Direct Beneficiary Delivery
F8D  O2 Causal Finalization / Remaining Reduction
GI   Full Stateful Invariant Gate
F9   Canonical Acceptance
F10  Demo Instrumentation
F9T  Public Testnet / Production-Periphery Evidence — off critical path
```

Primary dependency flow:

```text
F0 -> F1

F2 --\
F3 ----> F5 -> F6A -> F7 -> F6B -> F8A -> F8B -> F8C -> F8D -> GI -> F9 -> F10
F4 --/

F9T branches after sufficient protocol completion and never blocks G9/G10.
```

The highest implementation risk is concentrated in:

1. F5 — prospective/current authoritative derivation correctness,
2. F8 — causal exact-output execution, settlement, delivery, finalization,
3. F6 — complete backing-affecting transition enforcement.

Low-risk infrastructure or frontend polish must not displace those slices on the hackathon critical path.

---

## 4. Repository / Source Layout

Candidate repository structure:

```text
src/
├── StandbyHook.sol
├── EligibilityRegistry.sol
├── ExerciseRouter.sol
├── interfaces/
│   ├── IEligibilityRegistry.sol
│   ├── IStandbyHook.sol
│   └── IExerciseRouter.sol        # optional if useful
├── libraries/
│   ├── StandbyMath.sol
│   ├── ServiceDomain.sol
│   └── CommitmentRefs.sol
├── types/
│   └── StandbyTypes.sol           # only if type extraction improves clarity
├── demo/
│   └── ActorAwareTestRouter.sol   # Anvil/demo periphery only; no Standby economics
└── mocks/
    ├── MockUSTB.sol
    └── MockUSDC.sol

script/
├── DeployStandbyHook.s.sol
├── DeployDemoEnvironment.s.sol
├── BootstrapStandby.s.sol
├── DemoActions.s.sol
└── helpers/
    ├── HelperConfig.s.sol
    ├── NetworkConfig.sol
    └── StandbyFixtureConfig.sol

test/
├── harness/
│   └── StandbyHookHarness.sol
├── shared/
│   ├── BaseV4Test.t.sol
│   ├── BaseStandbyTest.t.sol
│   ├── BaseActivatedStandbyTest.t.sol
│   ├── BaseBackedStandbyTest.t.sol
│   ├── BaseActorAwareStandbyTest.t.sol
│   ├── BaseInvariantStandbyTest.t.sol
│   └── ReferenceCalculations.sol
├── unit/
├── fuzz/
├── integration/
├── periphery/
├── invariant/
└── acceptance/

frontend/
├── public/
├── src/
│   ├── components/
│   ├── hooks/
│   ├── lib/
│   ├── App.jsx
│   ├── index.css
│   └── main.jsx
├── index.html
├── package.json
├── package-lock.json
├── tailwind.config.js
├── postcss.config.js
├── vite.config.js
└── README.md
```

The frontend structure intentionally follows the lightweight RangeGuard React/Vite/Tailwind organization for implementation familiarity and speed, while excluding RangeGuard-specific economic semantics, simulated economic demo state, and event-derived protocol truth.

## 4.1 Dependency pinning and API-drift discipline

F0 must establish a reproducible dependency baseline before protocol logic is built. Pin mutually compatible versions/commits of the actual dependencies selected for the repository, including at minimum:

- Uniswap `v4-core`,
- Uniswap `v4-periphery` where production-compatible periphery is used,
- Permit2 if required by the selected periphery/settlement path,
- Foundry/compiler configuration,
- frontend Web3/runtime packages such as viem used by the demo.

Record the resolved versions/commits in repository lock/configuration files and the implementation checkpoint. Do not copy API signatures from RangeGuard or older examples when the pinned v4 dependency exposes a different current interface. All PoolManager settlement, hook callback, PositionManager, and periphery assumptions must be verified against the pinned source actually compiled by Standby.

Dependency upgrades after a gate has closed are not routine refactors: rerun every gate whose evidence depends on the changed dependency/API behavior.

---

# 5. F0 — v4 Infrastructure / Deployment Foundation

## 5.1 Objective

Establish a deterministic real Uniswap v4 execution foundation and one canonical Hook deployment procedure before introducing Standby economics.

## 5.2 Production / script footprint

```text
script/
├── DeployStandbyHook.s.sol
└── helpers/
    ├── HelperConfig.s.sol
    └── NetworkConfig.sol

test/
├── shared/BaseV4Test.t.sol
└── integration/V4Infrastructure.t.sol
```

## 5.3 `HelperConfig.s.sol`

Responsibility: chain/infrastructure selection only.

It must not contain:

- Standby economic constants,
- fixture currencies,
- service ticks,
- eligibility state,
- commitments,
- Supporting Capacity or obligation logic.

Anvil mode may deploy:

- a real `PoolManager`,
- official v4-core `PoolSwapTest`,
- official v4-core `PoolModifyLiquidityTest`.

Public supported-chain mode resolves corresponding deployed v4 infrastructure/periphery.

Candidate `NetworkConfig` fields may include:

- `poolManager`,
- `coreSwapRouter`,
- `coreLiquidityRouter`,
- `positionManager`,
- `permit2`,
- `productionSwapRouter`,
- `peripheryMode`.

Not every field must be populated in every environment.

## 5.4 `DeployStandbyHook.s.sol`

This is the single canonical StandbyHook deployment path reused by tests, Anvil/demo, public testnet, and eventual production.

Responsibilities:

1. resolve selected PoolManager,
2. derive required Hook permission mask,
3. mine/find deployable Hook address/salt,
4. deploy `StandbyHook`,
5. validate deployed address permissions,
6. verify immutable PoolManager binding,
7. return/report Hook address.

The deployer is fixture-agnostic. It must not know MockUSTB, MockUSDC, PoolKey, tickQ, tickO, LP range, canonical commitment amount, or demo actors.

Required Hook permissions from the beginning:

- `beforeAddLiquidity = true`
- `beforeRemoveLiquidity = true`
- `beforeSwap = true`
- `afterSwap = true`
- all other hook callbacks false
- all return-delta/custom-accounting permissions false

## 5.5 G0 — v4 infrastructure gate

A fresh deterministic environment must prove:

1. real PoolManager deployed/resolved,
2. vanilla v4 pool initializes,
3. vanilla liquidity can be added,
4. vanilla swap executes,
5. Hook deployment path deterministically produces a permission-valid Hook address.

No Standby economics are required yet.

---

# 6. F1 — Deterministic Economic Fixture

## 6.1 Objective

Establish the canonical economic fixture independently of the production Standby derivation kernel.

## 6.2 Canonical fixture

Currencies:

- `MockUSTB` — 6 decimals
- `MockUSDC` — 6 decimals

Required ordering:

```text
address(MockUSTB) < address(MockUSDC)
currency0 = MockUSTB
currency1 = MockUSDC
protected direction = zeroForOne
```

The deployment must guarantee this ordering deterministically. Do not rely on ordinary CREATE order and do not dynamically relabel/sort currencies after deployment.

Canonical economic constants:

```text
initial tick              = 0
tickQ                     = -240
tickO                     = +240
LP tickLower              = -300
LP tickUpper              = +300
tick spacing              = 10
static fee                = 500 pips / 0.05%
liquidity L               = 6,707,079,990,254
expected initial S        = 80,000.000000 MockUSDC
canonical commitment q    = 50,000.000000 MockUSDC
compatible ordinary swap  = 15,000.000000 MockUSDC
destructive attempt       = 20,000.000000 MockUSDC
```

`StandbyFixtureConfig.sol` may own these non-production fixture constants.

`EXPECTED_INITIAL_S` is permitted as an expected test/demo fixture value. It is not a production derivation.

## 6.3 Mocks

Mocks should be boring ERC-20s:

- six decimals,
- deterministic mint/funding capability for fixture setup,
- no fee-on-transfer/rebase behavior,
- no embedded Standby semantics.

## 6.4 Independent fixture proof

`ReferenceCalculations.sol` independently proves the canonical liquidity/tick/domain fixture yields the expected initial capacity before F5 exists.

It must not import or call production `StandbyMath` for the same derivation under verification.

## 6.5 G1 — deterministic fixture gate

### G1-A — currency identity

Prove:

- both currencies have six decimals,
- `MockUSTB < MockUSDC`,
- currency0 is MockUSTB,
- currency1 is MockUSDC,
- protected direction is zeroForOne.

### G1-B — independent economics

From the canonical initial v4 state, independently derive exact initial S = 80,000 MockUSDC.

General protocol tests later must vary token identities/order/protected direction to prove no hard-coding.

---

# 7. F2 — EligibilityRegistry

## 7.1 Objective

Implement a dedicated external mutable eligibility authority that is queried by StandbyHook but does not own Standby economics.

## 7.2 Production footprint

```text
src/
├── EligibilityRegistry.sol
└── interfaces/IEligibilityRegistry.sol
```

## 7.3 Required independent predicates

```text
canReceiveProtectedService(address)
canSwap(address)
canProvideLiquidity(address)
```

The predicates remain logically independent even if one demo wallet receives multiple permissions.

A minimal single-owner/admin registry is sufficient for the reference implementation.

Default behavior should fail closed.

## 7.4 Registry exclusions

The registry must know nothing about:

- PoolId or PoolManager economics,
- Supporting Capacity,
- Aggregate Obligation,
- commitment Remaining,
- exercise authority,
- commitment validity,
- time-based lifecycle,
- O1/O2/O3 state transitions.

## 7.5 Tests

```text
test/unit/EligibilityRegistry.t.sol
test/fuzz/EligibilityRegistryFuzz.t.sol
```

Prove:

- default denial,
- only authorized admin can mutate,
- predicates are independent,
- latest authorized write is reflected exactly,
- no coupling to protocol economic state.

## 7.6 G2 — registry gate

F2 closes when authority and predicate independence are proven by unit + fuzz evidence.

No stateful protocol invariant is required yet; later GI includes registry mutation in arbitrary protocol sequences.

---

# 8. F3 — StandbyHook Trust + PES Configuration

## 8.1 Objective

Deploy a correctly permissioned Hook that trusts exactly one immutable PoolManager and owns a complete one-shot PES service configuration without yet implementing commitment economics.

## 8.2 StandbyHook decomposition

One authoritative `StandbyHook` contract owns Standby state and interpretation. Narrow internal libraries may compute pure transformations.

Hook regions:

- H1 Trust / Configuration
- H2 Commitment Storage
- H3 Economic Derivations
- H4 Callback Classification + O3 Enforcement
- H5 O1 Admission
- H6 O2 Transaction Context
- H7 O2 Finalization

F3 implements H1.

## 8.3 Deployment-time facts

At minimum:

- immutable PoolManager,
- deployment/configuration authority if chosen as immutable.

Do not constructor-bind service facts such as currencies, ticks, direction, registry, trusted periphery, or PoolKey unless required by the frozen architecture.

## 8.4 One-shot service activation

One Hook instance realizes one configured PES / one PoolId for the MVP.

Lifecycle:

```text
UNCONFIGURED -> ACTIVATED
```

No pause/deactivate/cancel/reinterpret/migrate path is introduced.

`configureAndActivate(...)` should atomically establish the complete service basis, including at least:

- exact PoolKey / PoolId basis,
- eligibility registry,
- tickQ,
- tickO,
- protected direction,
- trusted ordinary-swap periphery,
- trusted liquidity periphery,
- designated ExerciseRouter / O2 coordinator,
- commitment-establishment authority,
- activation state.

The service configuration must preserve sufficient immutable facts for later deterministic derivation. A bare PoolId is insufficient if later derivation requires currencies/tick spacing/direction.

## 8.5 Activation validation

Before persistence:

- authenticate configuration authority,
- require not already activated,
- require configured PoolKey points to this Hook,
- validate structural pool facts,
- validate ticks/domain form,
- derive the maximum prospective swap traversal demand implied by the proposed immutable service domain and PoolKey tick spacing,
- require that traversal demand does not exceed the F5 reference realization's supported prospective-swap traversal bound,
- require nonzero registry,
- require explicit trusted ordinary-swap and liquidity periphery roles,
- require explicit designated ExerciseRouter / O2 coordinator,
- require explicit commitment-establishment authority,
- persist all facts atomically,
- mark activated,
- emit one strong activation event.

No partial config setters followed by later activation. No post-activation setter may replace the registry, service domain/direction, trusted ordinary-swap periphery, trusted liquidity periphery, designated ExerciseRouter, or commitment-establishment authority.

## 8.6 Callback trust

All enabled callbacks must reject authoritative interpretation unless `msg.sender` is the immutable PoolManager.

Do not confuse:

- Hook `msg.sender` = PoolManager,
- callback `sender` = periphery/locker,
- economic actor = authenticated originator from trusted periphery.

## 8.7 G3-H — Hook deployment fidelity

Using the actual Hook deployed by `DeployStandbyHook.s.sol`, prove:

- immutable PoolManager correct,
- exactly four required callbacks enabled,
- all other callbacks disabled,
- all return-delta permissions false,
- deployed address bits match permissions.

Harness evidence is invalid for this gate.

## 8.8 G3-C — configuration/trust fidelity

Prove:

- only configuration authority activates,
- activation exactly once,
- config complete and atomic,
- exact Pool identity,
- registry fixed,
- domain/direction fixed,
- every activated domain satisfies the supported prospective-swap derivability bound,
- an over-bound domain rejects atomically before service persistence,
- trusted ordinary-swap/liquidity periphery roles remain distinct,
- designated ExerciseRouter/O2 coordinator is explicitly fixed and distinct from ordinary periphery trust,
- commitment-establishment authority remains distinct,
- callbacks authoritative only from immutable PoolManager,
- no post-activation reinterpretation.

---

# 9. F4 — Commitment Storage / Bounded Enforcement References

## 9.1 Objective

Implement only the persistent commitment facts and bounded enforcement-reference structure required by the frozen state model.

## 9.2 Persistent commitment facts

Each commitment stores exactly the frozen facts:

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

Exact widths may be adjusted deliberately if required, but semantic content must not change.

Do not persist:

- valid,
- exercisable,
- fulfilled,
- expired,
- commitment Capacity Obligation,
- Aggregate Capacity Obligation,
- Supporting Capacity,
- lifecycle enum.

## 9.3 IDs

Use unique monotonic non-recycled commitment IDs.

Candidate:

```text
nextCommitmentId starts at 1
```

Historical commitment identity is independent of bounded reference-slot reuse.

## 9.4 Bounded enforcement references

```solidity
uint256 public constant MAX_LIVE_COMMITMENTS = 16;
uint256[16] enforcementRefs;
```

`0` represents empty.

A nonzero ref is bookkeeping to locate potentially binding commitments. Membership is not proof of economic liveness.

A ref is reclaimable only when the frozen permanent non-binding condition is derivable:

- Remaining Entitlement == 0, or
- `block.timestamp >= validUntil`.

Temporary Beneficiary ineligibility and pre-exercisability are not reclaimability conditions.

Reference reuse must never erase or rewrite historical commitment records.

## 9.5 `CommitmentRefs` library

`CommitmentRefs` owns bounded mechanics only:

- scan slots,
- identify empty candidate,
- replace selected slot,
- bounded uniqueness mechanics.

It must not independently define economic reclaimability. F5 owns that derivation.

## 9.6 Harness use

`StandbyHookHarness` may expose narrow storage seeders/getters for isolated F4/F5 unit/fuzz tests only.

## 9.7 G4 — persistence minimality gate

Prove:

1. IDs unique, monotonic, non-recycled,
2. history survives slot reuse,
3. max 16 refs,
4. empty/occupied representation unambiguous,
5. every ref resolves to real historical commitment,
6. membership does not encode lifecycle/economics,
7. only frozen persistent facts stored,
8. no derived economic state stored,
9. harness mutation remains test-only,
10. unit + fuzz evidence passes.

---

# 10. F5 — Authoritative Derivation Kernel

## 10.1 Objective

Implement the single authoritative production derivation layer consumed by O1, O2, O3, read functions, and diagnostic previews.

This is the highest-risk slice and must close before downstream enforcement relies on it.

## 10.2 Candidate production footprint

```text
src/
├── StandbyHook.sol
└── libraries/
    ├── StandbyMath.sol
    ├── ServiceDomain.sol
    └── CommitmentRefs.sol
```

Tests:

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

## 10.3 Commitment derivations

Validity:

```text
t < validUntil
```

Temporal exercise qualification:

```text
exercisableFrom <= t < validUntil
```

This temporal predicate does not include Beneficiary eligibility or exercise authority.

Commitment obligation:

```text
if Remaining == 0 -> 0
else if t >= validUntil -> 0
else -> Remaining
```

Therefore:

- a future commitment contributes O before `exercisableFrom`,
- temporary Beneficiary ineligibility does not reduce O,
- expiry makes obligation zero without changing Remaining.

Aggregate O is the bounded sum of commitment obligations referenced by enforcement slots.

## 10.4 Current Supporting Capacity

For protected `zeroForOne`:

```text
S = getAmount1Delta(sqrtQ, sqrtP, L, false)
```

For protected `oneForZero`:

```text
S = getAmount0Delta(sqrtP, sqrtQ, L, false)
```

Inputs come from authoritative PoolManager state and immutable service facts.

Do not branch on MockUSTB/MockUSDC identity. Branch on configured protected direction.

At P_Q, S = 0. Backing validity then depends separately on O.

## 10.5 Prospective state derivation

For any backing-affecting transition:

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

unless independently proven exactly equivalent for that transition.

Separate transition-specific helpers are preferred where clearer:

- prospective swap S′,
- prospective liquidity-removal S′,
- topology/domain checks.

For prospective swaps, the production derivation must reproduce the
economically relevant Uniswap v4 swap-loop semantics required to obtain
the exact prospective state. No-interior initialized liquidity
boundaries guarantee stable active liquidity across the service-domain
interior; they do not imply a single `SwapMath.computeSwapStep`, because
uninitialized tick-bitmap word boundaries may divide execution into
multiple arithmetic steps.

The reference realization keeps prospective swap traversal bounded. Let:

- `D` be the maximum prospective traversal demand implied by the proposed
  immutable service domain and PoolKey tick spacing under the supported
  v4 traversal semantics;
- `M` be the implementation's supported maximum prospective swap-step
  count.

PES activation requires:

```text
D <= M
```

A configuration with `D > M` must reject before activation. The runtime
step-bound revert remains defensive fail-closed protection and must not
serve as the normal discovery mechanism for an unsupported domain that
was already admitted.

Liquidity removal must account for whether the removed liquidity is active at the current tick.

## 10.6 Service-domain / topology library

`ServiceDomain` should contain pure geometric/topological predicates only.

It must not own:

- PoolManager reads,
- registry policy,
- commitment state,
- O derivation,
- transition authority,
- final revert policy.

Liquidity introduction may not introduce an initialized liquidity boundary strictly inside the configured service domain. Equality at configured boundaries is permitted where frozen semantics allow it.

`ServiceDomain` may also own the pure derivation/classification of prospective traversal demand from service geometry and tick spacing. It does not own the supported traversal limit or the activation decision. `StandbyHook` applies the realization's bound during `configureAndActivate` before authoritative PES persistence.

## 10.7 Read-only observability

Production read methods such as:

- `supportingCapacity()`,
- `aggregateObligation()`,
- `commitmentObligation(id)`

must call the same H3/F5 derivations used by enforcement.

A read-only prospective preview may expose existing authoritative transition derivations for diagnostics/demo instrumentation. It must not introduce economic semantics unavailable to enforcement and must never become an enforcement prerequisite.

## 10.8 Independent reference calculations

`ReferenceCalculations.sol` independently composes the normative derivation and must not call production Standby-specific helpers for the property under test.

It may use authoritative Uniswap math primitives where appropriate.

## 10.9 G5-A — normative derivation equivalence

Prove production equals independent normative reference for:

- validity,
- exercise-time qualification,
- commitment obligation,
- aggregate O,
- current S,
- service-domain/topology classification.

## 10.10 G5-B — prospective-state equivalence

For prospective transition helpers:

1. derive predicted prospective v4 state/S′,
2. execute the same transition against real PoolManager where allowed,
3. compare actual post-state to prediction,
4. compare predicted S′ to authoritative S derived from actual post-state,
5. include paths that cross uninitialized tick-bitmap word boundaries,
6. prove the admission-time traversal-demand classifier is sufficient for
   the production traversal bound.

Traversal-bound verification must include at minimum:

- a configuration whose maximum demand is exactly `M` and activates,
- a configuration whose maximum demand exceeds `M` and rejects before
  activation,
- both protected directions,
- positive and negative tick regions,
- bitmap-word-aligned boundary cases,
- atomic rejection with no partial PES persistence,
- canonical fixture activation unchanged.

For every configuration accepted by the derivability check, real-PoolManager
differential evidence must establish that supported domain-extreme swap
paths remain within the production traversal bound. The runtime
prospective-step-bound revert is retained as defensive fail-closed
protection.

## 10.11 G5-C — fixture generalization

Prove canonical fixture plus at least one generalized configuration:

- oneForZero protected direction,
- different token identities/order,
- different valid ticks/liquidity,
- heterogeneous currency decimals, including an asymmetric-decimal configuration.

Production Standby logic MUST NOT assume that either currency uses six decimals, that both currencies use the same number of decimals, or that the canonical 6-decimal fixture scale applies outside that fixture.

Supporting Capacity and the corresponding Capacity Obligation MUST be represented in raw units of the protected output currency so that they remain dimensionally comparable without protocol-wide decimal normalization.

Generalization evidence MUST verify that authoritative derivation remains equivalent to the independent reference derivation across the exercised currency-decimal configuration.

## 10.12 G5-D — production derivation singularity

Structural review must establish exactly one production derivation path
for validity, temporal exercise qualification, permanent non-binding
classification, commitment obligation, Aggregate Capacity Obligation,
and Supporting Capacity. Public reads, prospective helpers, and later
enforcement must consume those derivations rather than reconstructing
competing formulas.

## 10.13 G5-E — semantic minimality / downstream non-contamination

F5 must introduce no O1 commitment establishment, O2 authorization or
fulfillment behavior, O3 callback transition authorization, registry
mutation, participant authentication, administrative release,
pause/deactivation behavior, lifecycle persistence, or derived economic
storage.

## 10.14 G5-F — invalid-basis / bounded-derivability correctness

Prove that invalid service geometry, invalid direction-relative boundary
ordering, current state outside the service domain, invalid arithmetic
ordering, or unsupported prospective traversal demand cannot yield a
plausible authoritative Supporting Capacity or prospective state.

Verification must distinguish:

```text
S == 0
```

from:

```text
S is not authoritatively derivable because the realization basis is invalid
```

and must prove that unsupported immutable traversal demand is rejected at
PES activation rather than first discovered during ordinary supported
runtime operation.

## 10.15 G5 statement

> Every economically meaningful quantity/classification used by later transitions equals its normative derivation from authoritative facts, every prospective-state derivation used for pre-transition enforcement equals the state real v4 execution would produce for the same transition, and every activated PES lies within the bounded derivation domain required to make those authoritative prospective derivations available.

---

# 11. F6A — Preliminary O3 Enforcement with O = 0

## 11.1 Objective

Establish the real callback enforcement perimeter, service-domain/topology enforcement, and user-level actor attribution before authentic obligations exist.

F6A is not evidence for the central O > 0 backing claim.

## 11.2 Actor attribution

Canonical identity chain:

```text
Hook msg.sender = PoolManager
callback sender = trusted periphery
actor = authenticated originator exposed by trusted periphery
```

The Hook must first authenticate the configured trusted periphery before trusting an exposed `msgSender()`-style originator.

`hookData` is never authoritative actor identity.

## 11.3 Actor-aware Anvil periphery

Official v4-core test routers remain useful for core economics but do not expose originating user identity to the Hook.

Therefore add `src/demo/ActorAwareTestRouter.sol`, a minimal Anvil/demo periphery capable of exposing authenticated original caller semantics for the permissioned path. It is not a production Standby authority and owns no Standby economic truth. Keeping it under an explicitly demo-scoped source directory allows deployment scripts and acceptance tests to reuse the same bytecode without importing privileged test harness state.

Two local evidence paths remain distinct:

### Core harness

- real PoolManager,
- `PoolSwapTest`,
- `PoolModifyLiquidityTest`.

Proves execution/callback/economic math, not user identity.

### Actor-aware harness

- real PoolManager,
- ActorAwareTestRouter,
- StandbyHook.

Proves user-level `canSwap` / `canProvideLiquidity` semantics and trusted-periphery attribution.

## 11.4 O3 behavior at O = 0

Ordinary protected-direction swap:

- authenticate PoolManager,
- resolve configured service,
- authenticate trusted swap periphery,
- resolve actor,
- require `canSwap(actor)`,
- derive prospective S′,
- derive current O (= 0 in F6A),
- require S′ >= O,
- preserve service-domain rules.

Opposite direction:

- may increase S,
- must still preserve configured realization/service domain.

Liquidity addition:

- trusted liquidity periphery,
- authenticated actor,
- `canProvideLiquidity(actor)`,
- topology validity.

Liquidity removal:

- no continuing `canProvideLiquidity` requirement,
- prospective backing/domain enforced.

Loss of LP eligibility must not by itself trap capital.

## 11.5 Callback classification

At F6A there is no active O2 context, therefore all swaps are ordinary O3 transitions.

Never classify O2 by ExerciseRouter identity.

## 11.6 G6A — structural enforcement gate

Prove:

1. only immutable PoolManager callbacks authoritative,
2. only trusted periphery can supply authenticated actor,
3. forged hookData cannot establish actor,
4. ordinary swap requires `canSwap`,
5. liquidity add requires `canProvideLiquidity`,
6. removal does not require continuing eligibility,
7. direction classification correct,
8. opposite-direction domain enforced at O=0,
9. topology enforced at O=0,
10. F5 prospective derivations consumed,
11. valid transitions positively permitted,
12. integration + fuzz passes.

---

# 12. F7 — O1 Commitment Admission

## 12.1 Objective

Create the first authentic binding Standby obligation through the real O1 transition.

## 12.2 Conceptual external surface

```solidity
establishCommitment(
    address beneficiary,
    address exerciseAuthority,
    uint256 originalEntitlement,
    uint64 exercisableFrom,
    uint64 validUntil
) returns (uint256 commitmentId)
```

The caller does not supply:

- S,
- O,
- obligation value,
- reference slot,
- validity classification,
- current PoolManager state.

## 12.3 Authority

`msg.sender` must equal the configured commitment-establishment authority.

This role remains distinct from configuration authority, Beneficiary, exercise authority, registry admin, trader eligibility, and liquidity eligibility.

## 12.4 Proposed commitment

Construct in memory with:

- configured service,
- Beneficiary,
- exercise authority,
- Original Entitlement = q,
- Remaining Entitlement = q,
- exercisableFrom,
- validUntil.

At minimum reject:

- zero Beneficiary,
- zero exercise authority,
- q == 0,
- `validUntil <= exercisableFrom`,
- `validUntil <= block.timestamp`.

Immediate exercisability is permitted; do not require `exercisableFrom > now`.

## 12.5 Admission sequence

Canonical implementation order:

1. authenticate establishment authority,
2. require activated service,
3. construct/validate proposed commitment,
4. require Beneficiary eligible for protected service,
5. bounded scan enforcement refs,
6. derive current O,
7. identify empty/reclaimable slot using F5-derived semantics,
8. derive proposed commitment obligation,
9. derive O′,
10. derive current S from PoolManager,
11. require S >= O′,
12. allocate unique ID,
13. atomically persist commitment + enforcement reference + counter update.

> **Derive first -> persist last.**

## 12.6 Admission semantics

A commitment with future `exercisableFrom` contributes O immediately while valid.

Beneficiary ineligibility later does not release O.

If all 16 refs remain binding, reject with a distinct max-live-commitment failure, not a backing failure.

Equality passes:

```text
S == O′ -> PASS
```

## 12.7 No reservation

A successful O1 must not change:

- PoolManager liquidity,
- PoolManager price/tick,
- protected-output token custody,
- Beneficiary balance.

The Hook and ExerciseRouter should hold zero protected output through O1.

## 12.8 Rejection atomicity

Any O1 failure leaves unchanged:

- next commitment ID,
- commitments,
- refs,
- O,
- PoolManager state.

## 12.9 G7 — O1 gate

Prove:

1. establishment authority only,
2. exact term validation,
3. activated PES required,
4. Beneficiary eligible at admission,
5. O derived from bounded refs,
6. only empty/permanently reclaimable slots reused,
7. future commitments contribute O,
8. temporary ineligibility does not release O,
9. S from authoritative PoolManager state,
10. `S >= O′`, equality passes,
11. insufficient backing causes no partial persistence,
12. IDs unique/non-recycled,
13. commitment + ref atomic,
14. slot reuse preserves history,
15. no reservation/custody,
16. unit + fuzz + integration pass,
17. canonical A1 ends S=80k, O=50k, Remaining=50k.

---

# 13. F6B — O3 Enforcement with Authentic O > 0

## 13.1 Objective

Prove the central Standby shared-liquidity backing claim using authentic obligations created only by real O1.

## 13.2 Canonical start

```text
bootstrap: S = 80k, O = 0
real O1 q=50k: S = 80k, O = 50k, Remaining = 50k
```

No fake O setter is permitted.

## 13.3 Protected ordinary swaps

For an ordinary protected-direction swap:

```text
derive prospective S′
derive current O
require S′ >= O
```

Ordinary swaps never reduce O or Remaining.

### Canonical A2

Exact-output 15k protected output:

```text
prospective/actual S = 65k
O = 50k
65k >= 50k -> PASS
```

Post-state:

```text
S = 65k
O = 50k
Remaining = 50k
```

This is the primary positive non-reservation proof.

### Canonical A3

From S=65k, O=50k, attempt exact-output 20k:

```text
prospective S′ = 45k
45k < 50k -> REJECT
```

Failure must be specifically Standby insufficient backing, not unrelated balance/allowance/eligibility/slippage/domain failure.

After revert:

```text
S = 65k
O = 50k
Remaining = 50k
```

Prospective 45k never becomes authoritative state.

## 13.4 Liquidity and domain

Liquidity removal with live O:

- safe if prospective S′ >= O,
- equality passes,
- destructive removal rejects,
- continuing LP eligibility not required for exit.

Liquidity addition:

- requires eligible actor,
- topology validity remains required even if S would increase.

Opposite-direction swaps:

- may increase S,
- must remain within configured realization domain.

## 13.5 Lifecycle interactions

Expiry:

- automatically reduces derived O to zero when `t >= validUntil`,
- does not change Remaining.

Beneficiary ineligibility:

- does not reduce O,
- O3 protection remains in force.

## 13.6 G6B — authentic backing gate

Prove:

1. authentic O arises only through O1,
2. compatible ordinary protected swaps pass when S′ >= O,
3. equality passes,
4. destructive ordinary swaps reject S′ < O,
5. rejected state unchanged,
6. ordinary swaps never alter Remaining/O,
7. opposite direction remains domain constrained,
8. safe removal succeeds even after LP eligibility loss,
9. destructive removal rejects,
10. liquidity-add eligibility/topology preserved,
11. expiry changes O only by derivation,
12. Beneficiary ineligibility does not reduce O,
13. multiple commitments protected by aggregate O,
14. integration + fuzz pass,
15. canonical A2 ends S=65k/O=50k,
16. canonical A3 derives 45k, rejects backing-specific, and leaves state unchanged.

---

# 14. F8A — O2 Authorization / Hook-Owned Causal Context

## 14.0 ExerciseRouter decomposition and authority boundary

`ExerciseRouter` is a transaction coordinator with no persistent Standby economic truth. Its implementation is organized as:

- **R1 Request Intake / Originator Attribution** — accept `exercise(commitmentId, q, maxInput)` from the external exerciser and expose/bind that originating caller through an authenticated router-local mechanism that the Hook can query only after authenticating the configured ExerciseRouter.
- **R2 Hook Authorization** — request Hook-owned O2 authorization; the Hook resolves commitment, Beneficiary, exercise authority, time/eligibility, S, O, and prospective safety.
- **R3 Exact-Output PoolManager Execution** — coordinate exactly one protected exact-output swap matching the authorized context.
- **R4 Input Settlement / Direct Output Delivery** — settle actual PoolManager input debt from the authenticated exerciser and direct PoolManager output to the Hook-resolved Beneficiary.
- **R5 Hook Finalization** — invoke Hook-owned causal finalization after execution, settlement, and delivery.

The Router must not persist commitment state, S, O, Remaining, validity, Beneficiary truth, fulfillment state, or reusable authorization state. `maxInput` remains exerciser cost protection only.

Originating-exerciser attribution is analogous to the trusted-periphery rule used for ordinary permissioning: the Hook first authenticates that the caller is the exact ExerciseRouter fixed during activation, then obtains the Router's transaction-local originating caller through `msgSender()` or an equivalent authenticated mechanism. An arbitrary exerciser address in calldata or `hookData` is not authoritative identity. The Router's address itself is never the exercise authority.

## 14.1 Objective

Establish transaction-scoped authorization binding exactly one commitment, one authenticated exerciser, one authoritative Beneficiary, and one quantity q before any protected exercise swap occurs.

## 14.2 Causal state model

Use transaction-scoped context, preferably transient storage where supported:

```text
EMPTY -> AUTHORIZED -> EXECUTED -> consumed / EMPTY
```

Do not persist O2 lifecycle state.

Context may bind:

- service/pool,
- commitmentId,
- authenticated exerciser,
- authoritative Beneficiary,
- q,
- state.

Do not store:

- S snapshot,
- O snapshot,
- Remaining snapshot,
- validity snapshot,
- eligibility flags.

## 14.3 Router request surface

Conceptual `ExerciseRouter` external request:

```solidity
exercise(uint256 commitmentId, uint256 q, uint256 maxInput)
```

The request does not supply:

- Beneficiary,
- PoolKey,
- direction,
- exercise authority,
- Remaining,
- S,
- O.

## 14.4 Authorization predicates

Hook authorization must verify:

1. request arrives through the exact ExerciseRouter/O2 coordinator fixed during service activation,
2. actual originating exerciser is recovered from the authenticated ExerciseRouter's transaction-local originator mechanism, not arbitrary forwarded calldata,
3. commitment exists and belongs to configured service,
4. originating exerciser equals commitment exercise authority,
5. commitment valid,
6. `exercisableFrom <= now < validUntil`,
7. Beneficiary currently eligible,
8. `0 < q <= Remaining`,
9. prospective protected exact-output exercise yields S′,
10. derive current O,
11. require `S′ >= O - q`.

Remaining and O remain unchanged during authorization.

Equality passes.

Only after all predicates pass write one AUTHORIZED context.

Nested/multiple active authorizations are rejected.

## 14.5 G8A — authorization gate

Prove:

- router path required but router identity is not exercise authority,
- originator recovered only after exact ExerciseRouter authentication and cannot be forged through calldata/hookData,
- authoritative commitment/authority/time/eligibility/q checks,
- prospective `S′ >= O - q`, equality passes,
- Remaining/O unchanged,
- no Beneficiary delivery yet,
- one exact context written,
- no cross-transaction reuse,
- failed authorization leaves EMPTY,
- unit + fuzz + integration pass.

---

# 15. F8B — O2 Exact-Output Execution / Execution Evidence

## 15.1 Objective

Treat a swap as O2 only when it exactly matches an existing Hook-owned AUTHORIZED context, and mark execution evidence only after observing actual matching PoolManager execution.

## 15.2 Sequence

```text
ExerciseRouter request
-> Hook authorization / AUTHORIZED
-> one exact-output protected swap
-> PoolManager beforeSwap -> Hook
-> Hook matches AUTHORIZED context and classifies O2
-> PoolManager executes
-> PoolManager afterSwap -> Hook
-> Hook verifies actual protected output == q
-> AUTHORIZED -> EXECUTED
```

Persistent commitment state remains unchanged.

## 15.3 O2 classification

- No active AUTHORIZED context => swap is ordinary O3.
- Active AUTHORIZED context => swap must exactly match the authorized O2 shape.

ExerciseRouter identity alone never classifies O2.

## 15.4 Exact matching

At minimum bind/verify:

- PoolId,
- protected direction,
- exact-output mode,
- exact q,
- one swap only.

Reject:

- wrong pool,
- wrong direction,
- exact-input,
- q ± 1 mismatch,
- second swap,
- nested exercise,
- stale/no authorization.

MVP may reject arbitrary ordinary swaps while O2 context is active to preserve causal simplicity.

## 15.5 Execution evidence timing

`beforeSwap` is not execution proof.

Only `afterSwap`, using authoritative v4 delta semantics, may transition AUTHORIZED -> EXECUTED after proving actual protected output equals q.

`EXECUTED` means exact authorized AMM execution occurred. It does not yet mean:

- input debt settled,
- Beneficiary paid,
- commitment fulfilled.

## 15.6 G8B — execution gate

Prove:

1. AUTHORIZED required,
2. Router identity alone insufficient,
3. pool/direction/exact-output/q exact,
4. beforeSwap not execution proof,
5. afterSwap verifies actual q,
6. only then EXECUTED,
7. exactly one swap,
8. nested/multiple paths reject,
9. Remaining unchanged,
10. Beneficiary delivery not assumed,
11. input settlement not fulfillment,
12. predicted post-state can be compared to actual PoolManager post-state,
13. unit + fuzz + integration pass.

---

# 16. F8C — Authoritative Settlement / Direct Beneficiary Delivery

## 16.1 Objective

Settle exactly the actual PoolManager input debt produced by the protected swap, enforce exerciser `maxInput`, and discharge the protected-output PoolManager credit by sending exactly q directly to the authoritative Beneficiary without ExerciseRouter protected-output custody.

## 16.2 Input/output identities

Derive currencies from configured service direction.

Canonical zeroForOne:

```text
input  = currency0 = MockUSTB
output = currency1 = MockUSDC
```

General oneForZero reverses them.

Do not accept user-supplied currency identities.

## 16.3 Actual input debt

Settlement truth comes from authoritative PoolManager delta accounting for the router/unlock participant after execution.

Do not settle using:

- estimated input,
- requested input,
- `maxInput`.

Derive exact actual input debt and enforce:

```text
actualInput <= maxInput
```

Equality passes.

If actual input exceeds maxInput, revert the entire O2 transaction.

## 16.4 Economic payer

The authenticated exerciser is the economic payer.

The ExerciseRouter may coordinate transfer/allowance mechanics but must not become a pre-funded Standby reserve or principal.

For the minimal reference implementation, ordinary ERC-20 allowance/`transferFrom` may be used if sufficient; Permit2 may be used where the chosen periphery path benefits from it. The semantic requirement is that the authenticated exerciser pays the actual PoolManager debt.

## 16.5 Settlement sequence

For ERC-20 input, follow the pinned v4 version's actual PoolManager settlement interfaces. Conceptually:

```text
sync(inputCurrency)
-> transfer exact actualInput to PoolManager
-> settle()
-> verify relevant input delta cleared
```

Use the installed/pinned v4 interface rather than blindly copying historical API signatures.

Calling `settle()` is not itself proof; relevant authoritative input debt must be closed.

## 16.6 Protected output delivery

The canonical output path is:

```text
PoolManager.take(outputCurrency, authoritativeBeneficiary, q)
```

Never:

```text
PoolManager -> ExerciseRouter -> Beneficiary
```

The Beneficiary comes from authoritative commitment/context truth, not caller-supplied recipient calldata.

Exactly one q delivery is used. No split delivery, batching, or arbitrary redirection.

For canonical plain mocks, assert:

```text
beneficiaryBalanceAfter - beneficiaryBalanceBefore == q
```

ExerciseRouter protected-output balance must not increase through protocol execution.

## 16.7 Delta closure

Before finalization, relevant router PoolManager accounting for both input and output should be closed.

## 16.8 Failure atomicity

Any of the following must revert the entire exercise:

- maxInput breach,
- insufficient exerciser funds,
- insufficient allowance,
- failed settlement,
- failed output take/delivery.

After revert:

- PoolManager state unchanged,
- Remaining unchanged,
- Beneficiary output unchanged,
- no reusable O2 context survives.

## 16.9 Causal context state

Do not introduce `SETTLED` or `DELIVERED` persistent/transient lifecycle states merely because the router has intermediate steps.

Context remains EXECUTED until finalization consumes it.

## 16.10 G8C — settlement/delivery gate

Prove:

1. currencies derived from configured direction,
2. actual input from PoolManager accounting,
3. estimated input not settlement truth,
4. `actualInput <= maxInput`, equality passes,
5. authenticated exerciser pays,
6. exact v4 settlement semantics used,
7. input debt proven cleared,
8. Beneficiary derived from commitment truth,
9. caller cannot redirect output,
10. PoolManager directly sends exactly q protected output,
11. canonical Beneficiary receives exactly q,
12. Router never takes protected-output custody,
13. output credit closed,
14. settlement/payment failures unwind entire transaction,
15. Remaining unchanged through F8C,
16. no new persistent O2 lifecycle state,
17. integration + fuzz pass.

---

# 17. F8D — Causal Finalization / Remaining Entitlement Reduction

## 17.1 Objective

Convert one fully proven O2 transaction into the one persistent Standby economic consequence: reduce the exercised commitment's Remaining Entitlement exactly once, only after actual post-execution backing is rederived and verified.

## 17.2 Hook-owned finalization

ExerciseRouter never modifies commitment state directly.

Conceptual finalization call:

```solidity
finalizeExercise(uint256 commitmentId)
```

Prefer not to pass q or Beneficiary again; they are already bound in Hook-owned EXECUTED context.

## 17.3 Finalization prerequisites

Hook must:

1. require active EXECUTED context,
2. require matching commitment identity,
3. reload authoritative commitment state,
4. revalidate `q <= current Remaining`,
5. derive actual post-execution S from current PoolManager state,
6. derive current aggregate O from authoritative commitments,
7. derive post-fulfillment obligation `Ofinal = Ocurrent - q`,
8. require `Sactual >= Ofinal`, equality passes.

Do not reuse prospective S′ from authorization as actual final state.

## 17.4 Persistent mutation

Only after all final checks pass:

```text
newRemaining = oldRemaining - q
```

Original Entitlement remains unchanged.

No `fulfilled` flag is persisted. Full fulfillment is derived from Remaining == 0.

Reference membership need not be synchronously cleared after full fulfillment; later O1 may reclaim the slot while historical record remains intact.

## 17.5 Causal consumption / replay resistance

Consume the EXECUTED context exactly once.

One consumed context permits at most one entitlement reduction of q.

Reject:

- replayed finalization,
- cross-commitment substitution,
- quantity substitution,
- finalization after ordinary swap/direct transfer/settlement-only paths.

## 17.6 Economic finality atomicity

If final backing verification fails, the entire O2 transaction reverts, including:

- AMM execution,
- input settlement,
- Beneficiary delivery,
- causal context effects.

No durable state may exist where delivery survives but Standby finalization fails, or entitlement reduction survives without delivery.

## 17.7 G8D — economic finality gate

Prove:

1. Hook owns finalization,
2. exact EXECUTED context required,
3. commitment identity exact,
4. q sourced from context,
5. authoritative commitment re-read,
6. q <= current Remaining,
7. actual post-state S rederived,
8. current O rederived,
9. `Ofinal = O - q`,
10. `Sactual >= Ofinal`, equality passes,
11. Remaining decreases exactly q only after all checks,
12. Original unchanged,
13. no fulfilled/expired/lifecycle flag,
14. full fulfillment yields zero obligation by derivation,
15. ref need not be immediately cleared,
16. context consumed exactly once,
17. replay/cross-commitment/quantity substitution impossible,
18. ordinary swaps/direct transfers/settlement/delivery alone cannot reduce Remaining,
19. failed finalization unwinds entire O2 transaction,
20. unit + fuzz + integration pass,
21. canonical A4 ends S=15k, O=0, Remaining=0, Beneficiary +50k.

---

# 18. GI — Full Stateful Invariant Gate

## 18.1 Objective

Exercise arbitrary sequences of authoritative O1/O2/O3/lifecycle/eligibility transitions through production interfaces and prove all frozen safety, state, attribution, and derivation invariants remain true in every reachable authoritative state.

GI occurs after F8 and before G9.

## 18.2 Production-only environment

No `StandbyHookHarness`.

Use real:

- PoolManager,
- StandbyHook deployed through canonical deployer,
- EligibilityRegistry,
- ExerciseRouter,
- ActorAwareTestRouter where needed,
- real mock fixture currencies.

No direct economic state mutation.

## 18.3 Handler

Candidate actions:

```text
establishCommitment(...)
ordinaryProtectedSwap(...)
ordinaryOppositeSwap(...)
addLiquidity(...)
removeLiquidity(...)
exercise(...)
advanceTime(...)
setBeneficiaryEligibility(...)
setTraderEligibility(...)
setLiquidityEligibility(...)
directTransferProtectedTokenToBeneficiary(...)
```

The handler is an adversarial transaction generator, not a safety pre-filter.

Invalid Standby requests are intentionally generated and allowed to revert.

Bound only mechanically impossible/noisy inputs such as invalid TickMath domain, unbounded amounts, or unknown actor universe.

## 18.4 Ghost/reference state

Ghost state is permitted only as an independent oracle.

Examples:

- successful commitment IDs for action selection,
- independently tracked successful fulfillment per commitment,
- immutable original commitment facts snapshots,
- optionally independently observed delivery quantities.

Ghost values are never authoritative protocol state.

## 18.5 Invariant families

### Backing

Independently derive referenceS/referenceO and assert:

```text
referenceS == productionS
referenceO == productionO
referenceS >= referenceO
```

This avoids correlated production derivation bugs escaping behind `productionS >= productionO`.

### Commitment state

For every historical commitment:

- immutable facts never change,
- Remaining <= Original,
- Remaining monotonic non-increasing,
- expiry does not change Remaining,
- eligibility mutation does not change Remaining,
- eligibility loss does not release O.

### Fulfillment attribution

Maintain:

```text
ghostFulfilled[id] = sum(q of successfully completed attributable O2)
```

Assert:

```text
Original[id] - Remaining[id] == ghostFulfilled[id]
```

Therefore ordinary swaps, liquidity actions, expiry, eligibility changes, direct token transfers, and failed O2 attempts cannot create fulfillment.

For canonical plain mocks, optionally assert attributable delivery equals ghost fulfillment.

### Reference integrity

Always:

- <= 16 refs,
- nonzero refs unique,
- every nonzero ref resolves to historical commitment,
- history survives slot reuse,
- only Remaining==0 or expiry permits economic reclaimability.

### O2 context

No completed top-level transaction may leave reusable causal authorization/execution evidence.

Behaviorally verify finalization without a current exercise cannot succeed.

### Custody

Under protocol flows:

- StandbyHook protected-output balance == 0,
- ExerciseRouter protected-output balance == 0,

unless the invariant campaign deliberately introduces unrelated external donations, in which case donations must be separately ghost-accounted.

## 18.6 Generalized invariant fixtures

Run at least:

1. canonical zeroForOne MockUSTB/MockUSDC fixture,
2. generalized oneForZero/different token ordering fixture.

The invariant suite must not prove only the demo identity/direction.

## 18.7 Campaign quality

Action weighting should produce meaningful multi-step sequences rather than trivial registry churn.

Useful sequences include:

- O1 -> ordinary swap -> O2,
- O1 -> eligibility loss -> O3,
- O1 -> time advance -> expiry -> new O1,
- multiple O1 -> partial exercise -> ordinary swap,
- O1 -> liquidity removal attempt.

Track action counters for diagnostic coverage. A green campaign with no successful O2 should not be treated as strong fulfillment evidence.

## 18.8 GI gate

GI passes when arbitrary successful and rejected authoritative sequences preserve:

1. reference S == production S,
2. reference O == production O,
3. S >= O,
4. Remaining <= Original,
5. immutable commitment facts,
6. Remaining monotonicity,
7. `Original - Remaining == independent successful fulfillment`,
8. expiry is not fulfillment,
9. eligibility change is not fulfillment or obligation release,
10. ordinary swaps never fulfill,
11. liquidity actions never fulfill,
12. direct transfers never fulfill,
13. successful O2 fulfills exactly one commitment by exactly q,
14. successful O2 delivers exact q to authoritative Beneficiary in canonical mock semantics,
15. failed O2 produces no fulfillment,
16. no protocol protected-output custody in Hook/Router,
17. refs <= 16,
18. refs unique/non-dangling,
19. history survives reuse,
20. only frozen permanent non-binding causes permit reclamation,
21. no reusable cross-transaction O2 context,
22. canonical + generalized direction campaigns pass,
23. campaign counters demonstrate meaningful O1/O2/O3/lifecycle activity.

---

# 19. F9 — Canonical Acceptance

## 19.1 Objective

From a completely fresh deterministic environment, reproduce the exact frozen A1 -> A2 -> A3 -> A4 Standby story through production deployment/bootstrap/behavioral paths with no privileged economic fixture state.

## 19.2 Acceptance footprint

```text
test/acceptance/
├── BootstrapFidelity.t.sol
└── CanonicalStandbyFlow.t.sol
```

`CanonicalStandbyFlow.t.sol` must not inherit `BaseBackedStandbyTest` or any fixture that pre-creates backed economic state.

## 19.3 Fresh construction path

```text
HelperConfig
-> real PoolManager
-> DeployStandbyHook.s.sol
-> fixture contracts
-> BootstrapStandby.s.sol
-> A1
-> A2
-> A3
-> A4
```

### 19.3.1 Foundry script/test orchestration reuse

Acceptance must reuse the same deployment/bootstrap implementation without attempting to shell out to `forge script` from a test and without making broadcast-only `run()` functions the reusable logic.

Use thin script wrappers around callable deterministic orchestration functions:

- `DeployStandbyHook.s.sol` exposes a callable deployment function used by tests and by its CLI/broadcast `run()` wrapper. Hook permission mining/deployment logic exists only there.
- `DeployDemoEnvironment.s.sol` exposes callable environment composition that invokes the canonical Hook deployer; its `run()` wrapper only supplies/broadcasts environment-specific actors.
- `BootstrapStandby.s.sol` exposes callable bootstrap logic over explicit deployed-address/actor inputs; its `run()` wrapper only handles broadcast concerns.

`CanonicalStandbyFlow.t.sol` imports/instantiates these callable orchestration paths directly inside the Foundry VM. It does not duplicate deployment/bootstrap logic, invoke an external shell command, or rely on persisted broadcast artifacts as economic state.

> **Script/Test Reuse Rule:** reusable deployment and bootstrap semantics live in deterministic callable functions; `run()`/broadcast behavior is a thin operational wrapper, not a second implementation path.

## 19.4 GB — bootstrap fidelity

Fresh deployment/bootstrap must end exactly:

```text
currency0 = MockUSTB
currency1 = MockUSDC
protected direction = zeroForOne
initial tick = 0
L = 6,707,079,990,254
S = 80,000 MockUSDC
O = 0
no commitment
```

Also verify Hook permission bits and immutable PoolManager are correct.

Before A1:

- StandbyHook protected-output balance = 0,
- ExerciseRouter protected-output balance = 0.

## 19.5 A1 — Admit

Real O1 q = 50,000 MockUSDC.

Expected:

```text
S = 80k
O = 50k
Original = 50k
Remaining = 50k
Beneficiary balance unchanged
Pool state unchanged by O1
Hook/Router protected-output custody = 0
```

Capture the returned commitmentId for later A4.

## 19.6 A2 — Compatible ordinary swap

Real ordinary protected exact-output swap = 15k MockUSDC.

Expected:

```text
PASS
S = 65k
O = 50k
Remaining = 50k
```

This proves admitted commitment did not reserve the same shared capacity from compatible ordinary use.

## 19.7 A3 — Destructive attempt

From S=65k/O=50k, attempt ordinary protected exact-output 20k.

Expected prospective:

```text
S′ = 45k
45k < 50k
```

Must revert with the specific Standby insufficient-supporting-capacity error.

After revert:

```text
S = 65k
O = 50k
Remaining = 50k
```

The prospective 45k state never becomes authoritative.

## 19.8 A4 — Full exercise

Using the same commitment and q=50k, invoke actual ExerciseRouter path with sufficiently generous `maxInput`.

The transaction must traverse F8A-D completely.

Expected:

- actual PoolManager input debt settled,
- PoolManager directly delivers 50k MockUSDC to authoritative Beneficiary,
- Beneficiary balance increases exactly 50k,
- ExerciseRouter/Hook retain zero protected output,
- Remaining becomes 0 only after finalization,
- final S = 15k,
- final O = 0.

## 19.9 One uninterrupted acceptance test

Primary test should be one sequential function such as:

```solidity
test_CanonicalStandbyFlow()
```

The acceptance claim is sequential and must use the same live pool and commitment.

Focused tests already cover isolated actions.

## 19.10 G9 — canonical acceptance gate

G9 passes when a fresh deterministic environment using production deployment/bootstrap paths reproduces exactly:

| Stage                  |                  S |      O | Remaining | Result    |
| ---------------------- | -----------------: | -----: | --------: | --------- |
| Bootstrap              |             80,000 |      0 |         — | Ready     |
| A1 Admit               |             80,000 | 50,000 |    50,000 | PASS      |
| A2 Compatible Swap     |             65,000 | 50,000 |    50,000 | PASS      |
| A3 Destructive Attempt | prospective 45,000 | 50,000 |    50,000 | REJECT    |
| After A3 revert        |             65,000 | 50,000 |    50,000 | unchanged |
| A4 Exercise            |             15,000 |      0 |         0 | PASS      |

No test-only economic setter, harness seed, direct storage mutation, or mocked fulfillment contributes to evidence.

---

# 20. F10 — Demo Instrumentation

## 20.1 Objective

Expose the G9 canonical sequence through minimal deterministic scripts and a lightweight frontend without introducing new protocol semantics or independent economic truth.

## 20.2 RangeGuard-aligned frontend structure

Use the familiar lightweight React/Vite/Tailwind organization:

```text
frontend/
├── public/
├── src/
│   ├── components/
│   │   ├── StandbyStatePanel.jsx
│   │   ├── CommitmentPanel.jsx
│   │   ├── ActionPanel.jsx
│   │   └── ActionResult.jsx
│   ├── hooks/
│   │   ├── useStandbyState.js
│   │   ├── useCommitment.js
│   │   └── useDemoActions.js
│   ├── lib/
│   │   ├── contracts.js
│   │   ├── rpc.js
│   │   ├── format.js
│   │   └── errors.js
│   ├── App.jsx
│   ├── index.css
│   └── main.jsx
├── index.html
├── package.json
├── package-lock.json
├── tailwind.config.js
├── postcss.config.js
├── vite.config.js
└── README.md
```

Prefer viem for continuity with RangeGuard unless a concrete blocker appears.

Do not reuse a simulated `demoData` economic lifecycle. The deterministic Anvil chain is the demo state.

## 20.3 Authoritative displayed state

Display only the frozen baseline fields:

- Supporting Capacity S,
- Aggregate Capacity Obligation O,
- Remaining Entitlement,
- Beneficiary MockUSDC balance,
- current pool tick/price as secondary evidence,
- latest action result/reason,
- prominent `S >= O` comparison.

Sources:

- S from Hook authoritative read,
- O from Hook authoritative read,
- Remaining from commitment record,
- Beneficiary balance from MockUSDC,
- pool tick/price from PoolManager,
- latest result from receipt/custom-error/post-state reads.

The frontend must not independently calculate S or O.

## 20.4 Read/re-render rule

After every transaction:

```text
submit
-> wait for receipt/revert
-> re-read authoritative on-chain state
-> render
```

Do not optimistically mutate economic state.

Page reload must reconstruct current economic state from chain alone.

## 20.5 Four canonical actions

Main judged view exposes only:

1. Admit Commitment
2. Compatible Swap
3. Attempt Destructive Swap
4. Exercise

Bootstrap, registry administration, liquidity provisioning, and reset are script/environment operations, not main demo buttons.

UI may guide canonical order, but contracts remain the only authority for action validity. A3 is demo choreography, not a protocol lifecycle prerequisite for A4.

## 20.6 Demo scripts

### `DeployDemoEnvironment.s.sol`

Compose in dependency-safe order:

1. select/deploy v4 infrastructure,
2. deploy deterministic ordered mock currencies,
3. deploy EligibilityRegistry,
4. deploy ActorAwareTestRouter,
5. deploy the Hook through canonical `DeployStandbyHook.s.sol`,
6. deploy ExerciseRouter bound to the deployed Hook/PoolManager as required by its constructor,
7. return the complete address manifest used by bootstrap.

Do not duplicate Hook mining/deployment logic. ExerciseRouter is deployed before service activation so its address can be fixed as part of the one-shot PES configuration.

### `BootstrapStandby.s.sol`

Perform:

1. pool initialization,
2. `configureAndActivate` with the already-deployed registry, ordinary-swap periphery, liquidity periphery, designated ExerciseRouter, direction/domain, and establishment authority,
3. seed mutable demo eligibility predicates in EligibilityRegistry,
4. actor funding/approvals,
5. canonical controlled liquidity addition,
6. final authoritative checks.

Stop at:

```text
S = 80k
O = 0
no commitment
```

### `DemoActions.s.sol`

Provide real production calls for A1–A4 only.

It is the fallback/debugging path if browser presentation fails.

## 20.7 A3 prospective presentation

A3 must clearly separate:

- current authoritative S = 65k,
- proposed ordinary swap = 20k,
- prospective S′ = 45k,
- required O = 50k,
- rejected result,
- current S remains 65k after revert.

If the UI displays prospective S′, obtain it from a production read-only preview that reuses the same F5/H3 derivation used by enforcement.

The preview is diagnostic, not authorization and not a reservation/guarantee.

Do not calculate prospective S′ independently in TypeScript.

## 20.8 A4 presentation

After successful exercise re-read and display:

```text
S = 15k
O = 0
Remaining = 0
Beneficiary +50k MockUSDC
```

The UI may state that the exercise fulfilled 50k only from successful transaction result plus authoritative post-state/balance evidence.

## 20.9 Demo reset

Reset by fresh environment:

```text
restart/reset Anvil
-> redeploy
-> bootstrap
```

Do not introduce production `resetStandby`, `clearCommitments`, `restoreCapacity`, or equivalent demo-only functions.

## 20.10 G10 — demo fidelity gate

G10 passes when:

1. demo uses canonical Hook deployment path,
2. bootstrap starts exact canonical pre-A1 state,
3. main UI exposes four canonical actions,
4. S/O/Remaining/balance/tick are authoritative reads,
5. UI does not independently derive/persist S or O,
6. A1 shows 80k/50k/50k,
7. A2 shows 65k/50k/50k,
8. A3 preview uses production derivation,
9. A3 distinguishes prospective 45k from current 65k,
10. A3 decodes specific backing rejection,
11. after A3 authoritative state remains 65k/50k/50k,
12. A4 uses real ExerciseRouter path,
13. A4 shows exact +50k Beneficiary delivery,
14. final state 15k/0/0,
15. reload reconstructs truth from chain,
16. reset is environmental,
17. DemoActions reproduces same transitions without frontend,
18. no UI/demo-only production economic backdoor exists.

---

# 21. F9T — Public Testnet / Production-Periphery Evidence

## 21.1 Role

F9T is supplementary credibility evidence and production-periphery integration evidence.

It is not a dependency of canonical G9 acceptance or G10 judged demo.

## 21.2 Timing

Attempt only after canonical protocol behavior is stable enough that public infrastructure risk cannot jeopardize the critical path.

## 21.3 Objectives

On a currently supported public testnet/L2 selected from up-to-date official Uniswap deployments, prove as feasible:

- Hook deployment against official PoolManager,
- pool initialization,
- actual production-compatible periphery interaction,
- actor attribution through real trusted periphery,
- permissioned liquidity/swap behavior,
- O3 backing enforcement,
- O2 exercise path where environment permits,
- explorer-visible contracts/transactions.

Do not assume Sepolia or any particular chain remains the correct choice; verify deployment landscape at implementation time.

Failure of F9T does not invalidate canonical Anvil acceptance.

---

# 22. Test Architecture and Evidence Boundaries

## 22.1 Candidate layout

```text
test/
├── harness/
│   └── StandbyHookHarness.sol
├── shared/
│   ├── BaseV4Test.t.sol
│   ├── BaseStandbyTest.t.sol
│   ├── BaseActivatedStandbyTest.t.sol
│   ├── BaseBackedStandbyTest.t.sol
│   ├── BaseActorAwareStandbyTest.t.sol
│   ├── BaseInvariantStandbyTest.t.sol
│   └── ReferenceCalculations.sol
├── unit/
│   ├── EligibilityRegistry.t.sol
│   ├── ServiceConfig.t.sol
│   ├── CommitmentStorage.t.sol
│   ├── CommitmentRefs.t.sol
│   ├── SupportingCapacity.t.sol
│   ├── AggregateObligation.t.sol
│   ├── CommitmentDerivation.t.sol
│   ├── ServiceDomain.t.sol
│   ├── O2Authorization.t.sol
│   └── O2Finalization.t.sol
├── fuzz/
│   ├── EligibilityRegistryFuzz.t.sol
│   ├── ServiceConfigFuzz.t.sol
│   ├── CommitmentStorageFuzz.t.sol
│   ├── CommitmentRefsFuzz.t.sol
│   ├── SupportingCapacityFuzz.t.sol
│   ├── AggregateObligationFuzz.t.sol
│   ├── CommitmentDerivationFuzz.t.sol
│   ├── ServiceDomainFuzz.t.sol
│   ├── O1AdmissionFuzz.t.sol
│   ├── O3SwapFuzz.t.sol
│   ├── O3LiquidityFuzz.t.sol
│   ├── O2AuthorizationFuzz.t.sol
│   ├── O2ExecutionFuzz.t.sol
│   └── O2FinalizationFuzz.t.sol
├── integration/
│   ├── V4Infrastructure.t.sol
│   ├── O1Admission.t.sol
│   ├── O3SwapEnforcement.t.sol
│   ├── O3LiquidityEnforcement.t.sol
│   ├── O2AuthorizationIntegration.t.sol
│   └── O2Execution.t.sol
├── periphery/
│   ├── ActorAttribution.t.sol
│   └── ProductionPeriphery.t.sol
├── invariant/
│   ├── StandbyHandler.sol
│   ├── BackingInvariant.t.sol
│   ├── CommitmentInvariant.t.sol
│   ├── FulfillmentInvariant.t.sol
│   └── ReferenceInvariant.t.sol
└── acceptance/
    ├── BootstrapFidelity.t.sol
    └── CanonicalStandbyFlow.t.sol
```

## 22.2 Evidence table

| Evidence type                        | Harness allowed | Seed authoritative inputs | Real production transitions required |
| ------------------------------------ | --------------: | ------------------------: | -----------------------------------: |
| Unit                                 |             Yes |              Narrowly yes |                                   No |
| Fuzz (isolated derivation/predicate) |             Yes |              Narrowly yes |                                   No |
| Fuzz (behavioral transition)         |              No |         No economic state |                                  Yes |
| Integration                          |              No |                        No |                                  Yes |
| Periphery / actor attribution        |              No |                        No |                                  Yes |
| Invariant                            |              No |                        No |                                  Yes |
| Acceptance                           |              No |                        No |         Yes, from fresh construction |

Cheatcodes such as `vm.warp`, actor impersonation, and mock funding are permitted for external environment facts. They may not manufacture Standby-owned authoritative economic state.

---

# 23. Deployment and Bootstrap Separation

## 23.1 Production-reusable deployment

Protocol component deployment logic remains independent from fixture orchestration.

`DeployStandbyHook.s.sol` deploys only the Hook against a selected PoolManager.

EligibilityRegistry and ExerciseRouter may have independent deployment paths as the implementation matures.

## 23.2 Environment orchestration

`DeployDemoEnvironment.s.sol` composes protocol components and test/demo periphery around the canonical Hook deployer.

`BootstrapStandby.s.sol` creates the configured economic service and liquidity state but does not deploy the Hook itself.

## 23.3 Bootstrap boundary

Canonical bootstrap sequence:

```text
Deploy infrastructure/components
-> Initialize Pool
-> Configure/Activate PES with immutable trusted periphery + ExerciseRouter addresses
-> Seed mutable eligibility predicates
-> Fund actors / approvals
-> Add canonical controlled liquidity
-> Verify tick=0, L canonical, S=80k, O=0
```

No commitment is admitted during bootstrap.

---

# 24. Canonical Demo Actors

Use distinct logical roles even if the demo collapses some identities for convenience:

- deployment/configuration authority,
- registry admin,
- commitment-establishment authority,
- DemoLP,
- ordinary trader,
- Beneficiary,
- authorized exerciser.

Prefer ordinary trader != exercise authority so A2/A3 and A4 visibly exercise different authority paths.

Beneficiary eligibility, trader eligibility, and liquidity-action eligibility remain independent predicates.

---

# 25. Explicit Forbidden Shortcuts

The following are forbidden across the implementation plan unless an upstream frozen artifact is deliberately reopened and revalidated.

## Economic state

Do not persist:

- S,
- O,
- validity,
- exercisability,
- fulfilled/expired flags,
- available capacity,
- backing health,
- O2 lifecycle state.

## Commitment lifecycle

Do not add:

- admin cancellation,
- generic invalidation/release,
- pause-and-release,
- entitlement rewrite,
- expiry-driven Remaining zeroing,
- eligibility-driven obligation release.

## O1

Do not:

- check only q <= S while ignoring existing O,
- delay obligation until exercisableFrom,
- mutate PoolManager or reserve protected output,
- persist before all derivations pass.

## O3

Do not:

- classify economic effect solely by router/function name,
- let ordinary swaps reduce O,
- ignore domain/topology when O=0,
- require continuing LP eligibility merely to exit.

## O2

Do not:

- classify O2 by ExerciseRouter identity,
- pre-reduce Remaining,
- trust router-supplied Beneficiary/authority/S/O/Remaining,
- mark execution in beforeSwap,
- use exact-input for the commitment-denominated protected output right,
- settle estimated input,
- treat input settlement as fulfillment,
- take protected output into ExerciseRouter custody,
- finalize from router assertion rather than Hook-owned causal evidence,
- permit replay/batching/netting/split delivery/nested O2 in MVP.

## Testing

Do not:

- use harness-seeded state as integration/invariant/acceptance evidence,
- use `vm.store` to create economic state for behavioral gates,
- let production and reference derivations share the Standby-specific implementation under test,
- run only canonical zeroForOne fixture and claim no hard-coding,
- accept generic A3 revert.

## Demo

Do not:

- simulate canonical Standby economics in frontend `demoData`,
- calculate authoritative S/O in TypeScript,
- optimistically mutate economic state,
- show prospective A3 S′ as current state,
- add production reset functions for demo convenience,
- rely on browser history to reconstruct current protocol truth.

---

# 26. Gate Completion Checklist

A slice is complete only after its gate evidence is green.

```text
G0   real deterministic v4 infrastructure
G1   canonical ordered/economic fixture
G2   eligibility authority + predicate independence
G3-H Hook deployment fidelity
G3-C service configuration + callback trust
G4   minimal persistent commitment/reference state
G5   authoritative derivation + prospective-state equivalence
G6A  structural O3 enforcement at O=0
G7   authentic O1 admission
G6B  authentic O3 backing protection with O>0
G8A  O2 authorization
G8B  exact execution evidence
G8C  actual settlement + direct delivery
G8D  economic finality
GI   arbitrary-sequence invariants
GB   bootstrap fidelity
G9   canonical A1-A4 acceptance
G10  demo fidelity
F9T  supplementary production-periphery/testnet evidence
```

Implementation progress should be measured by closed gates, not by number of completed source files.

---

# 27. Hackathon Execution Priority

Recommended practical order:

```text
1. F0 + G0
2. F1 + G1
3. F2 / F3 / F4 foundations
4. G2 / G3 / G4
5. F5 + G5
6. F6A + G6A
7. F7 + G7
8. F6B + G6B
9. F8A-D + G8A-D
10. GI
11. GB + G9
12. F10 + G10
13. F9T if time remains
14. presentation polish / explorer evidence / submission packaging
```

Do not spend disproportionate early time on frontend polish, production testnet deployment, or generalized UX before F5/F6/F8 are closed.

## 27.1 Claude Code slice-handoff protocol

Once the ETHGlobal coding period begins, implementation should proceed one gated slice at a time. Claude Code should receive a bounded handoff packet for the current slice rather than the entire roadmap as an invitation to implement ahead.

Each slice handoff should contain:

1. the current F-slice objective and its upstream frozen semantic references,
2. the production files permitted/expected to change,
3. the tests/evidence required by that slice's gate,
4. authoritative interfaces/state it may depend upon only because their prior gates are already closed,
5. explicit forbidden shortcuts relevant to the slice,
6. the exact gate-closing command/test set,
7. a requirement to stop at the gate and report any contradiction instead of silently redesigning upstream semantics.

After the gate passes, record the checkpoint (tests, notable implementation decisions, and any pinned dependency/API assumptions) before handing off the next slice. If a gate fails, repair the current slice or surface a genuine upstream contradiction; do not build downstream code on top of the failure.

Claude Code may refactor within the slice when behavior is preserved, but it must not introduce speculative production features or move normative economic truth outside the ownership boundaries defined in this plan.

> **Implementation Handoff Rule:** one slice, one bounded file/evidence scope, one gate closure before downstream work.

---

# 28. Definition of Implementation Completion

The Standby reference implementation is implementation-complete for the canonical ETHGlobal realization when:

1. F0-F8D gates are closed,
2. GI passes across canonical and generalized configurations,
3. GB and G9 deterministically reproduce the frozen A1-A4 scenario from a fresh environment,
4. F10/G10 expose the same canonical path without independent economic truth,
5. all required frozen acceptance properties are satisfied,
6. no implementation-only shortcut contradicts the canonical package.

Public testnet evidence strengthens credibility but is not required for canonical implementation completion.

---

# 29. Final Canonical Acceptance Story

The implemented system must make the following exact story executable and observable:

### Bootstrap

```text
S = 80,000
O = 0
```

### A1 — Admit 50,000

```text
S = 80,000
O = 50,000
Remaining = 50,000
PASS
```

No protected output is reserved or moved.

### A2 — Compatible ordinary use of 15,000

```text
S = 65,000
O = 50,000
Remaining = 50,000
PASS
```

The same shared AMM capacity remains ordinarily usable while backing is preserved.

### A3 — Attempt destructive ordinary use of 20,000

```text
prospective S′ = 45,000
O = 50,000
45,000 < 50,000
REJECT — insufficient supporting capacity
```

After revert:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

### A4 — Exercise full 50,000 commitment

One exact-output protected AMM execution occurs, the authenticated exerciser settles the actual input debt, PoolManager delivers exactly 50,000 MockUSDC directly to the authoritative Beneficiary, the Hook rederives actual post-execution backing, causal evidence is consumed, and Remaining Entitlement decreases exactly once.

Final state:

```text
S = 15,000
O = 0
Remaining = 0
Beneficiary received +50,000 MockUSDC
```

This is the executable reference realization of the statement:

> **Standby doesn't reserve liquidity. It protects capacity.**

---

## 30. Artifact Status

`implementation-plan.md` is **FINAL PASS / FROZEN** as of September 4, 2026.

The complete artifact passed:

1. **internal consistency / dependency gate** — PASS after correcting one-shot activation/periphery ordering and making ExerciseRouter trust explicit;
2. **upstream semantic-fidelity gate** — PASS; no frozen Standby economic, lifecycle, authority, state, or demo semantics were redefined;
3. **implementation completeness / missing-responsibility gate** — PASS after resolving Foundry script/test reuse, R1-R5 ExerciseRouter decomposition/originator attribution, Claude Code slice handoff, and dependency pinning/API-drift discipline;
4. **verification-evidence completeness gate** — PASS; every critical implementation slice has gate-owned unit/fuzz/integration/invariant/acceptance evidence as applicable;
5. **artifact-fidelity / no-unvalidated-strengthening gate** — PASS; implementation choices remain downstream realization decisions and do not introduce new protocol-economic rights, obligations, lifecycle transitions, or release paths;
6. **final post-correction gate** — PASS; the corrected artifact is internally consistent, dependency ordered, acceptance-fixture independent, and aligned with the frozen canonical A1-A4 demo.

This document is now the authoritative Step 11 engineering execution handoff for Step 12. Any later implementation convenience that conflicts with it or an upstream frozen artifact must yield to the frozen semantics unless a genuine contradiction is discovered and explicitly revalidated.
