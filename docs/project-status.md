# Standby — Project Status

**Last Updated:** September 4, 2026
**Project Phase:** Solidity / Reference Implementation
**Current Implementation Slice:** F0 — v4 Infrastructure
**Current Gate:** G0 — Vanilla v4 Infrastructure
**Status:** IN PROGRESS

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

> **F0 — v4 Infrastructure**

The current gate is:

> **G0 — Vanilla v4 Infrastructure**

No Standby economic behavior is authorized until the required upstream infrastructure foundation has been established and verified.

---

## 3. Canonical Implementation Ladder

Current implementation sequence:

| Slice | Responsibility                                    | Status                       |
| ----- | ------------------------------------------------- | ---------------------------- |
| F0    | v4 Infrastructure                                 | **IN PROGRESS**              |
| F1    | Deterministic Economic Fixture                    | NOT STARTED                  |
| F2    | EligibilityRegistry                               | NOT STARTED                  |
| F3    | StandbyHook Trust + PES Configuration             | NOT STARTED                  |
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

## 4. Current F0 Objective

F0 establishes the deterministic real Uniswap v4 execution foundation required by all later Standby implementation slices.

Complete G0 must prove:

1. a real Uniswap v4 `PoolManager` is deployed or resolved;
2. a vanilla v4 pool can be initialized;
3. liquidity can be added through the real v4 execution and accounting path;
4. vanilla swaps can execute through the real v4 execution and accounting path;
5. the canonical StandbyHook deployment procedure produces a Hook address whose permission bits match the declared Hook permissions.

Items 1–4 have initial passing implementation evidence.

Item 5 has not yet been implemented.

Therefore:

> **G0 remains OPEN.**

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

These requirements should receive a final focused review before G0 is closed.

---

## 9. G0 Status

### G0 — Vanilla v4 Infrastructure

**Status: OPEN / PARTIAL PASS**

Current assessment:

| Requirement                                | Status          |
| ------------------------------------------ | --------------- |
| Real PoolManager deployed/resolved         | PASS            |
| Vanilla pool initialization                | PASS            |
| Vanilla liquidity addition                 | PASS            |
| Vanilla swap execution                     | PASS            |
| Direction-neutral infrastructure evidence  | PASS            |
| Canonical StandbyHook deployment procedure | NOT IMPLEMENTED |
| Hook address permission validation         | NOT IMPLEMENTED |

G0 cannot close until the canonical StandbyHook deployment responsibility has been implemented and verified.

---

## 10. Current Blocker

The next unresolved F0 responsibility is:

> **Canonical StandbyHook deployment with deterministic Hook-address permission validation.**

The implementation must establish the canonical deployment procedure used across:

- tests;
- local Anvil deployment;
- public deployment where applicable;
- production-compatible deployment.

The procedure must:

1. resolve the intended `PoolManager`;
2. derive the required Hook permission mask;
3. mine/find an address or salt satisfying the Uniswap v4 Hook-address permission encoding;
4. deploy `StandbyHook`;
5. verify that the deployed address permissions match the Hook's declared permissions;
6. bind the Hook immutably to the intended `PoolManager`;
7. report the deployed Hook address.

The deployment mechanism must remain fixture-agnostic.

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

It is not part of the current F0 infrastructure implementation.

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

Before further Solidity implementation:

1. establish the root `CLAUDE.md`;
2. verify Claude Code can correctly orient itself using the repository documentation and current status;
3. review the current F0 vanilla infrastructure through that workflow;
4. resolve any review findings;
5. continue with the remaining F0 StandbyHook deployment responsibility.

Claude Code should not begin F1 or any Standby economic implementation until G0 has been reviewed and closed.

---

## 19. Current Handoff Summary

**Validated State**

- Standby implementation phase has begun.
- F0 is active.
- Toolchain/dependency baseline is validated.
- Real vanilla v4 pool initialization works.
- Real vanilla v4 liquidity addition works.
- Real vanilla v4 swaps work.
- Both swap directions have passing infrastructure evidence.
- Generic F0 infrastructure remains direction-neutral.
- No Standby economic behavior has been introduced.

**Current Gate**

- G0 — OPEN / PARTIAL PASS.

**Next Blocker**

- Canonical StandbyHook deployment and Hook-address permission validation.

**Immediate Next Step**

- Establish `CLAUDE.md` and Claude Code repository operating protocol before further implementation.
