# Session 02 — F0 Canonical StandbyHook Deployment

## Objective

Complete the remaining F0 / G0 responsibility by implementing the minimum production `StandbyHook` and canonical deterministic deployment path required to prove that Standby can be deployed as a valid Uniswap v4 hook with the exact callback-permission surface required by the frozen reference realization.

This session closes only the infrastructure-level Hook deployment responsibility.

Do not implement Standby economics in this session.

---

## Current Validated State

The repository has completed the initial F0 infrastructure foundation.

Validated infrastructure already includes:

- real Uniswap v4 `PoolManager`;
- official v4 test execution infrastructure;
- vanilla pool initialization;
- vanilla liquidity addition;
- vanilla swaps;
- direction-neutral infrastructure coverage;
- pinned Uniswap v4 dependency revisions;
- Foundry `1.3.5-stable`;
- Solidity `0.8.26`;
- GitHub Actions CI for formatting, build, and tests;
- repository Claude operating rules and prompt-audit structure.

G0 remains open only because the canonical Standby Hook deployment path and Hook permission validation have not yet been implemented.

---

## Authorized Scope

Implement only the minimum files and behavior necessary to complete the remaining G0 responsibility.

Expected implementation footprint:

- `src/StandbyHook.sol`
- `script/DeployStandbyHook.s.sol`
- `script/helpers/HelperConfig.s.sol`
- `script/helpers/NetworkConfig.sol`
- appropriate integration tests under `test/integration/`
- shared test utilities only if genuinely necessary

Existing F0 infrastructure may be updated where required to integrate the canonical Hook deployment path.

Do not expand beyond this responsibility without a genuine implementation blocker.

---

## StandbyHook — F0 Responsibilities

Implement the minimum production `StandbyHook`.

At F0 it must contain only infrastructure-level behavior required for valid Hook deployment.

Required properties:

1. Bind immutably to the authoritative Uniswap v4 `PoolManager`.

2. Expose exactly the Hook permissions required by the frozen Standby realization:
   - `beforeAddLiquidity = true`
   - `beforeRemoveLiquidity = true`
   - `beforeSwap = true`
   - `afterSwap = true`

3. All other Hook callbacks must be disabled.

4. All return-delta permission flags must be disabled.

5. The resulting permission mask must correspond to:

   `0x0AC0`

   Decimal:

   `2752`

6. The deployed Hook address must itself encode the required permission bits according to the actual pinned Uniswap v4 `Hooks` implementation.

7. The contract must not introduce Standby economic state or logic yet.

---

## Explicitly Prohibited in Session 02

Do not implement:

- PES/service configuration;
- commitment storage;
- commitment identifiers;
- Supporting Capacity `S`;
- Aggregate Capacity Obligation `O`;
- Remaining Entitlement;
- O1 commitment establishment;
- O2 exercise;
- O3 backing enforcement;
- Eligibility Registry integration;
- Beneficiary eligibility;
- trader eligibility;
- liquidity-provider eligibility;
- service-domain calculations;
- `P_Q` / `P_O` enforcement;
- liquidity-topology enforcement;
- exercise evidence;
- routers;
- settlement;
- token delivery;
- lifecycle semantics;
- harness-seeded economic state;
- frontend behavior.

If any of these appear necessary to complete F0, stop and report the blocker before introducing them.

---

## Canonical Deployment Requirement

There must be one canonical deployment procedure usable as the basis for:

- tests;
- local Anvil deployment;
- later public deployment;
- production-compatible deployment.

The deployment path must:

1. resolve the target `PoolManager`;
2. derive or use the exact required Hook permission mask;
3. deterministically find a valid Hook deployment address/salt using the pinned v4 Hook-address rules;
4. deploy `StandbyHook`;
5. prove that the deployed address contains the required Hook permission bits;
6. prove that no unauthorized Hook permission bits are present;
7. prove that the Hook is immutably bound to the intended `PoolManager`;
8. remain independent of the later canonical MockUSTB / MockUSDC economic fixture.

Use the actual pinned v4 implementation and APIs.

Do not copy older RangeGuard deployment code or assume API compatibility.

---

## Hook Address Mining

Use the actual pinned Uniswap v4 `HookMiner` / Hook permission implementation to derive the deterministic deployment address and salt.

The expected permission mask is `0x0AC0`, but the implementation and tests must validate it against the pinned dependency rather than treating the expected value as sufficient evidence.

---

## HelperConfig / NetworkConfig Boundary

`HelperConfig` and `NetworkConfig` are infrastructure configuration only.

They may represent information such as:

- chain/network identity;
- PoolManager address;
- deployment environment;
- infrastructure addresses needed for Hook deployment.

They must not contain Standby economic fixture or service semantics.

Do not place in these files:

- MockUSTB / MockUSDC economic configuration;
- service boundaries;
- capacity values;
- commitments;
- eligibility;
- protected direction;
- Standby economic constants.

Those belong to later implementation slices.

---

## Test Requirements

Add integration-level evidence for the canonical deployment procedure.

At minimum verify:

### G0-H1 — Exact Hook Permissions

The production `StandbyHook` reports exactly:

- beforeAddLiquidity;
- beforeRemoveLiquidity;
- beforeSwap;
- afterSwap.

All other Hook callback permissions are false.

All return-delta permissions are false.

### G0-H2 — Address Permission Validity

The actual deployed Hook address encodes the exact required permission mask expected by the pinned v4 `Hooks` implementation.

The test must validate the deployed address, not merely the returned permission struct.

### G0-H3 — PoolManager Binding

The deployed `StandbyHook` is immutably bound to the intended real `PoolManager`.

### G0-H4 — Deterministic Deployment Path

The canonical deployment procedure can derive a valid deterministic address/salt and deploy the Hook successfully.

### G0-H5 — Fixture Independence

Hook deployment must not depend on:

- MockUSTB;
- MockUSDC;
- pool token ordering;
- protected direction;
- commitment state;
- service-domain configuration.

---

## Existing G0 Evidence

Do not regress the already validated G0 infrastructure evidence:

- real PoolManager deployment/resolution;
- vanilla pool initialization;
- vanilla liquidity addition;
- vanilla swaps;
- both swap directions supported by shared infrastructure.

Existing integration tests must continue to pass.

---

## Verification Evidence

In addition to the repository-standard verification required by `CLAUDE.md` and the testing rules, run the focused F0 / Hook deployment integration tests separately and report their results.

## The completion report must provide evidence for each G0-H requirement defined in this prompt.

## Gate

G0 may close only if all of the following are demonstrated:

- real PoolManager deployed or resolved;
- vanilla pool initializes;
- vanilla liquidity can be added;
- vanilla swaps execute;
- shared infrastructure works in both directions;
- production `StandbyHook` deploys through the canonical deterministic procedure;
- deployed Hook address satisfies the exact permission-bit requirements;
- Hook reports only the authorized callback permissions;
- Hook is immutably bound to the intended PoolManager;
- deployment remains fixture-agnostic;
- formatting, build, and relevant tests pass.

A passing build alone is not sufficient.

A passing CI run alone is not sufficient.

Gate closure requires the required implementation plus verification evidence.

---

## Documentation Authorization

If the implementation and verification evidence justify a change in F0/G0 status, update `docs/project-status.md` accordingly.

No other documentation changes are expected for this session unless required by a newly discovered reproducibility prerequisite.

---

## Completion Boundary

Stop when:

1. the minimum production `StandbyHook` exists;
2. the canonical deterministic Hook deployment path exists;
3. exact Hook permissions and deployed-address validity are tested;
4. PoolManager binding is verified;
5. existing G0 infrastructure tests still pass;
6. the full relevant test suite passes;
7. documentation changes, if any, are limited to justified implementation-state or reproducibility updates;

Do not begin F1.

Do not implement Standby economic semantics.

Stop and wait for architectural/gate review.
