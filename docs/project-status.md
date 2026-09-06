# Standby — Project Status

**Last Updated:** September 5, 2026
**Project Phase:** Solidity / Reference Implementation
**Current Implementation Slice:** F3 — StandbyHook Trust + PES Configuration
**Last Closed Gate:** G2 — EligibilityRegistry (CLOSED / PASS)
**Status:** F0 COMPLETE — F1 COMPLETE — F2 COMPLETE — F3 NOT STARTED

---

## 1. Purpose

This document records the current implementation and verification state of Standby.

It is a **live implementation-status artifact**, not a normative protocol specification.

It exists to answer:

- What implementation slice is currently active?
- What has already been implemented?
- What has already been verified?
- What gate is currently open?
- What is the next unresolved blocker?
- What work is explicitly not yet authorized?

This document must not redefine protocol semantics.

When this document conflicts with a frozen upstream artifact, the frozen upstream artifact is authoritative.

---

## 2. Current Objective

Standby is currently in:

> **Phase 12 — Solidity / Reference Implementation**

The immediate objective is to implement the frozen Standby design as a deterministic Uniswap v4 reference realization while preserving the previously derived economic, architectural, state, invariant, and verification requirements.

Implementation proceeds through the verification-gated F0–F10 ladder defined in `implementation-plan.md`.

The current slice is:

> **F3 — StandbyHook Trust + PES Configuration**

The last closed gate is:

> **G2 — EligibilityRegistry — CLOSED / PASS**

F0, F1, and F2 have been implemented, verified, and explicitly gate-closed. F3 is the next authorized implementation slice and has not yet started.

---

## 3. Canonical Implementation Ladder

Current implementation sequence:

| Slice | Responsibility                                    | Status                       |
| ----- | ------------------------------------------------- | ---------------------------- |
| F0    | v4 Infrastructure                                 | **COMPLETE — G0 CLOSED**     |
| F1    | Deterministic Economic Fixture                    | **COMPLETE — G1 CLOSED**     |
| F2    | EligibilityRegistry                               | **COMPLETE — G2 CLOSED**     |
| F3    | StandbyHook Trust + PES Configuration             | **NEXT / NOT STARTED**       |
| F4    | Commitment Storage + Bounded References           | NOT STARTED                  |
| F5    | Authoritative Derivation Kernel                   | NOT STARTED                  |
| F6A   | Preliminary O3 Enforcement with O = 0             | NOT STARTED                  |
| F7    | O1 Commitment Establishment                       | NOT STARTED                  |
| F6B   | O3 Enforcement with Authentic O > 0               | NOT STARTED                  |
| F8A   | O2 Authorization                                  | NOT STARTED                  |
| F8B   | O2 Exact-Output Execution + Causal Evidence       | NOT STARTED                  |
| F8C   | O2 Input Settlement + Direct Beneficiary Delivery | NOT STARTED                  |
| F8D   | O2 Causal Finalization                            | NOT STARTED                  |
| GI    | Full Stateful Invariant Verification              | NOT STARTED                  |
| F9    | Canonical Acceptance                              | NOT STARTED                  |
| F10   | Demo Instrumentation                              | NOT STARTED                  |
| F9T   | Public Testnet Evidence                           | OPTIONAL / OFF CRITICAL PATH |

Downstream slices must not be started merely because upstream code compiles.

Advancement requires the implementation and verification evidence required by the corresponding gate.

---

## 4. F0 Objective — Complete

F0 established the deterministic real Uniswap v4 execution foundation required by all later Standby implementation slices.

Complete G0 required proof that:

1. a real Uniswap v4 `PoolManager` is deployed or resolved;
2. a vanilla v4 pool can be initialized;
3. liquidity can be added through the real v4 execution and accounting path;
4. vanilla swaps can execute through the real v4 execution and accounting path;
5. the canonical StandbyHook deployment procedure produces a Hook address whose permission bits match the declared Hook permissions.

Items 1–5 all have passing implementation and verification evidence.

That evidence has been architecturally reviewed and the gate has been explicitly closed.

Therefore:

> **G0 is CLOSED / PASS.**

---

## 5. Validated Toolchain Baseline

The current validated local toolchain baseline is:

| Component                     | Pinned / Validated Value                   |
| ----------------------------- | ------------------------------------------ |
| Foundry                       | `1.3.5-stable`                             |
| Solidity                      | `0.8.26`                                   |
| EVM                           | Cancun                                     |
| `v4-hooks-public`             | `0f731d5de0f4fd60b506b55754d5e6ff086eab7d` |
| direct `v4-core` gitlink      | `d153b048868a60c2403a3ef5b2301bb247884d46` |
| direct `v4-periphery` gitlink | `07336f2144f522874e2c3c85e04d1d3f8d5fa471` |

The pinned parent Git tree and its actual gitlinks are the authoritative dependency baseline.

Do not replace these revisions based solely on a stale or inconsistent nested lockfile.

Dependency upgrades require deliberate review and rerunning all dependent verification gates.

---

## 6. Foundry Configuration Baseline

The validated Standby Foundry configuration currently uses:

- Solidity `0.8.26`;
- Cancun EVM;
- `via_ir = false`;
- optimizer enabled;
- `optimizer_runs = 800`;
- `bytecode_hash = "none"`;
- `ffi = false`.

Default fuzz configuration:

- runs: `1000`;
- deterministic seed: `0x1`.

Default invariant configuration:

- runs: `500`;
- depth: `100`;
- deterministic seed: `0x1`.

CI configuration:

- fuzz runs: `10000`;
- invariant runs: `1000`;
- invariant depth: `500`;
- deterministic seed: `0x1`.

The dependency/toolchain configuration sub-gate has passed.

---

## 7. Current Repository Implementation

The initial F0 vanilla v4 infrastructure currently includes:

### `test/shared/BaseV4Test.t.sol`

Provides reusable vanilla v4 test infrastructure including:

- real `PoolManager` deployment;
- official `PoolModifyLiquidityTest`;
- official `PoolSwapTest`;
- deterministic test ERC20 deployment and ordering;
- token funding and router approvals;
- vanilla no-Hook `PoolKey`;
- pool initialization helper;
- liquidity-addition helper;
- direction-neutral exact-input swap helper.

The shared swap infrastructure supports both:

- `zeroForOne = true`;
- `zeroForOne = false`.

This is intentional.

The shared v4 infrastructure must remain direction-neutral. The canonical Standby protected direction is introduced by the later deterministic economic fixture and must not become an accidental assumption of the generic infrastructure layer.

### `test/integration/V4Infrastructure.t.sol`

Contains independent vanilla infrastructure tests for:

- zero-for-one execution;
- one-for-zero execution.

Each directional test begins from its own deterministic initialized pool state.

The tests verify token balance effects showing that the actual swap occurred in the requested direction.

### `src/StandbyHook.sol`

The minimum production Standby Uniswap v4 Hook.

At F0 it carries only infrastructure-level behavior:

- immutable PoolManager binding through the pinned `BaseHook` / `ImmutableState`;
- the required Standby callback-permission surface returned by `getHookPermissions()`.

The Hook owns its permission declaration only. The Hook-address mining requirement belongs to the
deployment procedure, not to the production Hook source.

No Standby economic state or enforcement logic exists yet. The four enabled callbacks fail closed with
`HookNotImplemented` until their owning implementation slices supply authoritative behavior.

### `script/DeployStandbyHook.s.sol`

The single canonical StandbyHook deployment procedure, reused by tests, deterministic local Anvil
deployment, and later public/production deployment.

It owns `REQUIRED_HOOK_PERMISSION_MASK`, derived from the pinned Uniswap v4 `Hooks` flag constants.
This is a separate representation from the Hook's own permission declaration; their equivalence is
established by verification rather than by construction.

`deployStandbyHook(IPoolManager, address create2Deployer)` mines the Hook address/salt with the pinned
`HookMiner`, performs the salted deployment, and then validates the deployed address permission bits,
the pinned `Hooks.validateHookPermissions` agreement between address and declared struct, and the
PoolManager binding.

`run()` composes infrastructure resolution, broadcast, and that procedure.

The deployer is fixture-agnostic.

### `script/helpers/HelperConfig.s.sol` and `script/helpers/NetworkConfig.sol`

Infrastructure configuration only: chain identity and the authoritative PoolManager address.

On the deterministic local environment a real pinned `PoolManager` is deployed. Chains without a
validated Uniswap v4 infrastructure configuration are rejected with `HelperConfig__UnsupportedNetwork`.

These files contain no Standby economic fixture or service semantics.

### `test/integration/StandbyHookDeployment.t.sol`

Integration evidence for the canonical Hook deployment procedure (G0-H1 through G0-H5).

The suite deliberately does not inherit `BaseV4Test` and deploys no currencies, no pool, and no Standby
economic fixture.

---

## 8. Current Verification Evidence

The current vanilla v4 infrastructure test has been run successfully:

```text
forge test --match-path test/integration/V4Infrastructure.t.sol -vvv
```

The current implementation successfully demonstrates:

- real `PoolManager` construction;
- pool initialization;
- liquidity addition;
- real swap execution;
- settlement through the official v4 test execution helpers;
- zero-for-one execution;
- one-for-zero execution.

The official pinned v4-core test helpers are used rather than replacing PoolManager behavior with Standby-owned mocks.

This constitutes initial evidence for G0 requirements 1–4.

The canonical StandbyHook deployment test has been run successfully:

```text
forge test --match-path test/integration/StandbyHookDeployment.t.sol -vv
```

12 tests pass, providing evidence for G0 requirement 5:

- the production Hook declares exactly `beforeAddLiquidity`, `beforeRemoveLiquidity`, `beforeSwap`, and
  `afterSwap`, with every other callback and every return-delta permission disabled (G0-H1);
- an independent reconstruction of the permission mask from the declared struct and the pinned `Hooks`
  flag constants reproduces the production mining mask and the frozen value `0x0AC0` / `2752` (G0-H1);
- the deployed Hook address encodes exactly those permission bits, checked flag-by-flag against the
  pinned `Hooks` implementation and accepted by the pinned `Hooks.validateHookPermissions` (G0-H2);
- the deployed Hook is bound to the intended real PoolManager, and an enabled callback rejects a
  non-PoolManager caller with `NotPoolManager` (G0-H3);
- the deployed address equals the deterministic CREATE2 address computed by the pinned `HookMiner` for
  the mined salt, and the procedure composes with `HelperConfig` infrastructure resolution (G0-H4);
- a second independent Hook deploys against a second real PoolManager with no currencies, pool,
  ordering, protected direction, or service configuration in existence (G0-H5).

The canonical script entrypoint has additionally been executed in Foundry script simulation:

```text
forge script script/DeployStandbyHook.s.sol
```

It resolved a real PoolManager, mined a salt, and deployed a Hook whose address encodes `0x0AC0`
through the deterministic CREATE2 factory path used by broadcasting deployments.

The full repository suite passes under both the default and `ci` profiles:

```text
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

These requirements should receive a final focused review before G0 is closed.

---

## 9. G0 Status

### G0 — Vanilla v4 Infrastructure

**Status: CLOSED / PASS**

Reviewed and explicitly closed on September 5, 2026.

Final assessment:

| Requirement                                | Status |
| ------------------------------------------ | ------ |
| Real PoolManager deployed/resolved         | PASS   |
| Vanilla pool initialization                | PASS   |
| Vanilla liquidity addition                 | PASS   |
| Vanilla swap execution                     | PASS   |
| Direction-neutral infrastructure evidence  | PASS   |
| Canonical StandbyHook deployment procedure | PASS   |
| Hook address permission validation         | PASS   |
| Hook PoolManager binding                   | PASS   |
| Deployment fixture independence            | PASS   |

Every G0 requirement has passing implementation and verification evidence.

F1 may now depend on the F0 infrastructure and the canonical StandbyHook deployment procedure.

---

## 9A. F1 and F2 Gate Status

### F1 — Deterministic Economic Fixture

**Status: CLOSED / PASS (G1)**

F1 established the deterministic MockUSTB / MockUSDC fixture, canonical currency ordering and protected direction, the Hook-bound canonical pool at zero pre-activation liquidity, and a separate real-v4 geometry pool used to verify the canonical liquidity geometry and independent initial Supporting Capacity reference.

The accepted F1 sequencing interpretation is that F1 establishes canonical economic geometry, not yet an activated Standby service. Hook-bound liquidity admission remains downstream of configuration and enforcement.

### F2 — EligibilityRegistry

**Status: CLOSED / PASS (G2)**

F2 established the dedicated external eligibility authority with three independently mutable, fail-closed predicates: Beneficiary eligibility, Trader eligibility, and Liquidity-action eligibility. The registry owns no Standby economic state, and `StandbyHook` does not yet consume or enforce registry results.

G2 verified predicate independence, administrator authority, read fidelity, cross-domain isolation, and architectural isolation through unit and fuzz evidence.

---

## 10. Current Blocker

There is no unresolved F0, F1, or F2 implementation responsibility and no open gate.

The next unstarted responsibility is:

> **F3 — StandbyHook Trust + PES Configuration.**

F3 is authorized as the next implementation slice but has not been started.

Known limitations carried forward from F0, none of which blocked G0:

- `HelperConfig` currently resolves infrastructure only for the deterministic local environment
  (chain id `31337`). Public-chain PoolManager resolution is rejected rather than guessed, and must be
  added with validated addresses before any public deployment;
- the broadcasting `run()` path is verified in Foundry script simulation, not against a live Anvil
  node with `--broadcast`;
- the four enabled Hook callbacks intentionally fail closed with `HookNotImplemented`. `StandbyHook`
  must not be attached to a live pool until its enforcement slices are implemented.

---

## 11. Required StandbyHook Permissions

The F0 deployment path must support the frozen Hook permission surface from the beginning.

Required permissions:

- `beforeAddLiquidity = true`;
- `beforeRemoveLiquidity = true`;
- `beforeSwap = true`;
- `afterSwap = true`.

All other Hook callback permissions are false.

All return-delta permissions are false.

The implementation must not temporarily deploy StandbyHook with a weaker permission surface merely because later economic behavior has not yet been implemented.

The address permission bits must correspond to the Hook's declared permission structure.

---

## 12. F0 Scope Boundary

F0 is infrastructure.

The following Standby economic behavior is **not yet authorized**:

- Supporting Capacity `S`;
- Aggregate Capacity Obligation `O`;
- commitment establishment;
- commitment storage;
- Remaining Entitlement;
- Beneficiary eligibility;
- trader eligibility;
- liquidity-provider eligibility;
- service-domain economic enforcement;
- O1;
- O2;
- O3 economic backing enforcement;
- exercise settlement;
- fulfillment;
- authoritative entitlement reduction.

F0 must not introduce these merely to prepare for later slices.

---

## 13. Canonical Economic Fixture Status

The canonical Standby economic fixture belongs to:

> **F1 — Deterministic Economic Fixture**

It is not part of the completed F0 infrastructure implementation. F1 has now been implemented and G1 explicitly closed.

The frozen fixture will later use:

- `MockUSTB`;
- `MockUSDC`;
- both with 6 decimals;
- `MockUSTB = currency0`;
- `MockUSDC = currency1`;
- protected direction `zeroForOne = true`;
- initial tick `0`;
- `tickQ = -240`;
- `tickO = +240`;
- LP range `[-300, +300]`;
- tick spacing `10`;
- fee `500` pips;
- deterministic active liquidity;
- deterministic initial Supporting Capacity.

Do not introduce this fixture into generic F0 infrastructure.

---

## 14. Verification Boundaries

Implementation evidence must respect the following rules.

### Real execution paths

Where a gate requires real Uniswap v4 execution, tests must use the real PoolManager execution/accounting path.

### Harness isolation

Harnesses may expose otherwise inaccessible logic or seed isolated facts for unit/fuzz testing only.

Harness-only state is not valid evidence for:

- integration;
- invariant;
- periphery;
- acceptance;
- production transition correctness.

### Acceptance fixture independence

Canonical acceptance tests must construct economic state through real deployment, configuration, and behavioral paths.

Privileged seeded economic state is invalid acceptance evidence.

### Independent derivation verification

Later economic derivations must be checked against independent verification calculations.

Invariant preservation alone does not prove authoritative derivation correctness.

---

## 15. Solidity Development Standards

Standby-owned Solidity follows these baseline standards:

- use Solidity `0.8.26`;
- prefer custom errors over revert strings;
- use explicit visibility;
- follow CEI where applicable;
- use storage pointers carefully and explicitly;
- minimize storage writes;
- avoid unnecessary memory allocation;
- prefer `uint256` unless smaller packing has meaningful benefit;
- use NatSpec for all external/public functions;
- keep functions focused and single-responsibility;
- avoid duplicated accounting logic;
- prefix immutable variables with `i_`;
- use uppercase names for constants.

Detailed Claude operating and source-ordering instructions belong in the root `CLAUDE.md`.

---

## 16. Git / Repository State

The repository foundation has already established:

- Foundry project initialization;
- repository directory structure;
- `docs/`;
- `src/`;
- `script/`;
- categorized `test/` directories;
- pinned Uniswap v4 dependencies;
- deterministic Foundry configuration.

Existing repository checkpoints include:

1. `chore: initialize Standby Foundry project`
2. `docs: establish Standby repository foundation`

The current F0 dependency and vanilla infrastructure work has not yet been designated as the next completed implementation checkpoint.

Do not create a checkpoint merely because files compile.

The next commit should occur only after the current repository-preparation/F0 boundary has been reviewed and explicitly approved.

---

## 17. Documentation State

The Standby engineering documentation is located in `docs/`.

Current artifacts include:

- `context.md`;
- `economic-agreement.md`;
- `mechanism.md`;
- `spec.md`;
- `architecture.md`;
- `state-machine.md`;
- `invariants.md`;
- `testing-strategy.md`;
- `uniswap-v4-realization.md`;
- `demo-spec.md`;
- `implementation-plan.md`;
- `project-status.md`;
- `setup.md`.

These documents do not all have the same semantic role or authority.

Directory placement does not determine normative authority.

The root `CLAUDE.md` will define the repository operating rules and document authority hierarchy.

---

## 18. Next Action

G2 has been reviewed and closed, so the next action is:

> **F3 — StandbyHook Trust + PES Configuration.**

F3 may begin when explicitly tasked. Its own verification gates govern advancement beyond the F3 boundary.

---

## 19. Current Handoff Summary

**Validated State**

- Standby implementation phase has begun.
- F0 is complete and G0 is closed.
- F1 deterministic economic fixture is complete and G1 is closed.
- F2 EligibilityRegistry is complete and G2 is closed.
- Toolchain/dependency baseline is validated.
- Real vanilla v4 pool initialization works.
- Real vanilla v4 liquidity addition works.
- Real vanilla v4 swaps work.
- Both swap directions have passing infrastructure evidence.
- Generic F0 infrastructure remains direction-neutral.
- The minimum production `StandbyHook` exists and deploys through the canonical deterministic path.
- The deployed Hook address encodes exactly `0x0AC0` and is immutably bound to the intended PoolManager.
- Hook deployment is fixture-agnostic.
- The deterministic economic fixture is established without production hard-coding to fixture identities or values.
- The external EligibilityRegistry exists with independent Beneficiary, Trader, and Liquidity-action predicates.
- No F3+ Hook consumption of eligibility, PES configuration, commitment, capacity derivation, or economic enforcement has been introduced.

**Current Gate**

- G2 — CLOSED / PASS. No gate is currently open.

**Next Blocker**

- F3 — StandbyHook Trust + PES Configuration has not been started.

**Immediate Next Step**

- Begin F3 — StandbyHook Trust + PES Configuration when explicitly tasked.
