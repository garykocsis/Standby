# Standby — Coverage Summary

## Status

> **Status: Non-normative engineering evidence. This report does not define protocol semantics or independently establish a verification gate.**

Coverage is a measure of what the test suite executed. It is not a measure of semantic correctness, and it
is not invariant proof. An uncovered line is not, on its own, a protocol defect.

---

## Checkpoint

```text
Post-F8D / Pre-GI
```

The F0–F8D production path is complete and G8D is PASS / CLOSED. GI has not been started.

---

## Environment

| Item                   | Value                                                             |
| ---------------------- | ----------------------------------------------------------------- |
| Measurement date       | 2026-09-08                                                        |
| Git branch             | `feat/f8d-o2-causal-finalization`                                 |
| Git commit (`HEAD`)    | `8938a85bb8036424c02c7cae57fc994371573933`                        |
| Working tree           | **Not clean — the measured state is uncommitted.** See below.     |
| Foundry                | `1.3.5-stable`, commit `9979a41b5daa5da1572d973d7ac5a3dd2afc0221` |
| Solidity / EVM         | `0.8.26` / `cancun`                                               |
| Active Foundry profile | `default` (fuzz `runs = 1000`, `seed = 0x1`)                      |
| Local Forge gas limit  | `gas_limit = 10000000000`                                         |
| Compilation            | **Optimizer and `via_ir` disabled by `forge coverage` itself**    |

### Working-tree state

`HEAD` is the F8C merge commit. **The Session 14 F8D work was uncommitted when this measurement was taken,
so this report does not describe the state of commit `8938a85`.** It describes that commit plus the
following working-tree changes:

Modified:

```text
foundry.toml
docs/setup.md
src/ExerciseRouter.sol
src/StandbyHook.sol
test/harness/UnfinalizedExerciseRouter.sol
test/integration/ExerciseSettlement.t.sol
```

Added:

```text
docs/prompts/session-14-f8d-02-causal-finalization.md
docs/prompts/session-14-log.md
test/harness/MisdirectedFinalizationRouter.sol
test/harness/NonFinalizingExerciseRouter.sol
test/shared/BaseExerciseFinalizationTest.t.sol
test/unit/ExerciseFinalization.t.sol
test/integration/ExerciseFinalization.t.sol
test/fuzz/ExerciseFinalizationFuzz.t.sol
```

When the Session 14 work is committed, this baseline should be understood as belonging to that commit.

---

## Command and Result

```bash
forge coverage
```

Completed successfully (exit 0): 58 suites, **539 tests passed, 0 failed, 0 skipped**, under coverage
instrumentation. The default summary report was used; no filtering, exclusion, or `--match` option was
applied.

A second, read-only invocation was used to locate the individual uncovered items reported below:

```bash
forge coverage --report debug
```

It produced no repository artifact.

### Material limitations affecting interpretation

1. **Instrumented build differs from the verified build.** Foundry reports:
   `Warning: optimizer settings and 'viaIR' have been disabled for accurate coverage reports.` The measured
   binary is therefore not the optimizer-enabled binary the gates were verified against. This affects which
   binary executed, not which source constructs the suite reached.

2. **Foundry's `Total` row is not a production figure.** It aggregates `src/`, `script/`, *and* `test/`
   files, so test and fixture code is counted alongside protocol code. Both are reported separately below,
   and the production aggregates are computed from the per-file rows rather than reported by Foundry.

3. **`src/mocks/MockUSDC.sol` and `src/mocks/MockUSTB.sol` report 0.00%.** The uncovered items are their
   `name()` and `symbol()` overrides, which nothing in the suite calls. They are deterministic fixture
   currencies, not protocol code.

4. **Coverage counts execution, not intent.** A covered branch is one the suite reached; it is not evidence
   that what the branch does is correct, and it is not evidence about any invariant.

---

## Repository-Level Coverage

Reported by Foundry across all instrumented files (`src/`, `script/`, `test/`). The four dimensions are
distinct and are deliberately not collapsed into one number.

| Dimension    | Coverage             |
| ------------ | -------------------- |
| Lines        | 95.52% (1300 / 1361) |
| Statements   | 94.72% (1239 / 1308) |
| Branches     | 79.47% (120 / 151)   |
| Functions    | 97.03% (294 / 303)   |

---

## Production Coverage

### Per file, as reported

| File                                 | Lines            | Statements       | Branches       | Functions      |
| ------------------------------------ | ---------------- | ---------------- | -------------- | -------------- |
| `src/StandbyHook.sol`                | 99.73% (366/367) | 98.52% (400/406) | 92.77% (77/83) | 100.00% (66/66) |
| `src/ExerciseRouter.sol`             | 97.14% (68/70)   | 95.31% (61/64)   | 72.73% (8/11)  | 100.00% (16/16) |
| `src/EligibilityRegistry.sol`        | 100.00% (20/20)  | 100.00% (14/14)  | 100.00% (2/2)  | 100.00% (8/8)   |
| `src/libraries/StandbyMath.sol`      | 100.00% (34/34)  | 100.00% (28/28)  | 100.00% (7/7)  | 100.00% (9/9)   |
| `src/libraries/ServiceDomain.sol`    | 100.00% (19/19)  | 100.00% (19/19)  | 100.00% (1/1)  | 100.00% (6/6)   |
| `src/libraries/CommitmentRefs.sol`   | 100.00% (7/7)    | 100.00% (9/9)    | 100.00% (0/0)  | 100.00% (2/2)   |
| `src/demo/ActorAwareTestRouter.sol`  | 100.00% (50/50)  | 95.83% (46/48)   | 71.43% (5/7)   | 100.00% (12/12) |
| `src/mocks/MockFixtureCurrency.sol`  | 96.30% (26/27)   | 95.45% (21/22)   | 100.00% (3/3)  | 100.00% (6/6)   |
| `src/mocks/MockUSDC.sol`             | 0.00% (0/4)      | 0.00% (0/2)      | 100.00% (0/0)  | 0.00% (0/2)     |
| `src/mocks/MockUSTB.sol`             | 0.00% (0/4)      | 0.00% (0/2)      | 100.00% (0/0)  | 0.00% (0/2)     |

Deployment and configuration sources, for completeness:

| File                                              | Lines           | Statements      | Branches      | Functions      |
| ------------------------------------------------- | --------------- | --------------- | ------------- | -------------- |
| `script/DeployStandbyHook.s.sol`                  | 47.62% (20/42)  | 46.81% (22/47)  | 0.00% (0/6)   | 66.67% (2/3)   |
| `script/helpers/DeterministicFixtureDeployer.sol` | 81.82% (18/22)  | 85.19% (23/27)  | 25.00% (1/4)  | 100.00% (3/3)  |
| `script/helpers/HelperConfig.s.sol`               | 100.00% (8/8)   | 100.00% (8/8)   | 100.00% (1/1) | 100.00% (2/2)  |

### Computed aggregates

Summed from the per-file rows above. These are computed here, not reported by Foundry.

Standby protocol core — the Hook, the ExerciseRouter, the EligibilityRegistry, and the three libraries:

| Dimension  | Coverage           |
| ---------- | ------------------ |
| Lines      | 99.42% (514 / 517) |
| Statements | 98.33% (531 / 540) |
| Branches   | 91.35% (95 / 104)  |
| Functions  | 100.00% (107 / 107) |

All of `src/`, including the demo router and the fixture currencies:

| Dimension  | Coverage           |
| ---------- | ------------------ |
| Lines      | 98.01% (590 / 602) |
| Statements | 97.39% (598 / 614) |
| Branches   | 90.35% (103 / 114) |
| Functions  | 96.90% (125 / 129) |

---

## Material Uncovered Production Areas

Every uncovered production item is listed. Each is a rejection path or a defensive clamp; none is an
untested economic transition, and none is classified here as a defect.

### `src/StandbyHook.sol` — 1 line, 6 statements, 6 branches

| Location | Construct | Note |
| -------- | --------- | ---- |
| L1062 | `authorizeExercise` → `StandbyHook__ServiceNotConfigured` | O2 authorization against a Hook with no service. Every exercise fixture activates a service first. |
| L1218–1219 | `authorizedProtectedExecution` → `StandbyHook__ExerciseExecutionNotAuthorized` | The read surface consulted while the causal context is not `AUTHORIZED`. The equivalent refusal on the authoritative callback path *is* covered. |
| L1668 | `_beforeRemoveLiquidity` → `StandbyHook__UntrustedLiquidityPerimeter` | Liquidity **removal** proposed by an untrusted sender. The same refusal on **addition** is covered. |
| L2217 | `_beginSwapDerivation` → `StandbyHook__ServiceNotConfigured` | Prospective swap derivation before activation. |
| L2343 | `_nextSwapTargetTick` → `tickNext <= TickMath.MIN_TICK` clamp | Mirrors the pinned v4 swap loop's own clamping; reachable only at the extreme tick bound. |
| L2344 | `_nextSwapTargetTick` → `tickNext >= TickMath.MAX_TICK` clamp | As above, at the opposite bound. |

### `src/ExerciseRouter.sol` — 2 lines, 3 statements, 3 branches

| Location | Construct | Note |
| -------- | --------- | ---- |
| L395–396 | `ExerciseRouter__InputTransferFailed` | Reached only when `transferFrom` returns `false` without reverting. The fixture currency reverts with its own typed errors instead, and those failure modes *are* covered. |
| L441–443 | `ExerciseRouter__UnresolvedExerciseDelta` | The fail-closed guard for an exercise leaving an open PoolManager delta. Settlement and delivery close each side exactly, so no reachable path leaves one open. |
| L475 | `ExerciseRouter__ExerciseContextAlreadyActive` | A nested `exercise()` while one is already in flight. |

### `src/demo/ActorAwareTestRouter.sol` — 2 statements, 2 branches

`ActorAwareTestRouter__NotPoolManager` (L195) and `ActorAwareTestRouter__SettlementTransferFailed` (L244).
This contract is demo and test-perimeter instrumentation, not protocol.

### `src/mocks/` — fixture metadata

`MockUSDC.name/symbol` and `MockUSTB.name/symbol` are never called; `MockFixtureCurrency` L118 is the
allowance-decrement path taken only when the allowance is not `type(uint256).max`.

### `script/DeployStandbyHook.s.sol` — 22 lines, 25 statements, 6 branches

The lowest production-adjacent figure in the repository. The mining and validation procedure is exercised
by every fixture, but the broadcasting `run()` entrypoint and its validation failure branches are not
reached by `forge test` — consistent with the limitation already recorded in `docs/project-status.md`, that
`run()` is verified in script simulation rather than against a live node.

---

## Potential GI Inputs

Recorded as **potential inputs to GI derivation, not as established GI requirements.** GI has not been
started and no derivation was performed here. Whether any of these belongs in GI is for GI's own derivation
to decide against `docs/invariants.md` and `docs/testing-strategy.md`.

1. **Untrusted-perimeter liquidity removal** (`StandbyHook.sol` L1668). An O3 authority boundary on a
   backing-affecting transition. A GI handler that generates liquidity actions from arbitrary senders would
   intersect this path directly.

2. **Nested exercise attribution** (`ExerciseRouter.sol` L475). The router's one-originator-per-request
   discipline. It sits beside the Hook's own overlapping-authorization restriction, which is covered, and
   the economic-reentrancy restriction of `uniswap-v4-realization.md` §16.3 is an invariant-relevant
   property.

3. **The causal-position refusal on the read surface** (`StandbyHook.sol` L1218–1219). A sequence-dependent
   guard on a surface an adversarial handler could consult at any causal position.

4. **Tick-bound clamping in the prospective swap derivation** (`StandbyHook.sol` L2343–2344). Reachable only
   outside the configured service domain. A GI swap handler with deliberately extreme inputs is the kind of
   generator that would reach it, and the prospective derivation is the authoritative input to backing
   enforcement.

5. **The unresolved-delta guard** (`ExerciseRouter.sol` L441–443). Structurally unreachable on the current
   production path. Noted because it is the router's own fail-closed statement about exercise-local delta
   isolation (RR-O2-15), and adversarial sequencing is what GI generates.

Items 1 and 2 are the two that intersect an authority or state-transition boundary most directly. Items 3–5
are noted for completeness.

The two `ServiceNotConfigured` refusals and the fixture-currency metadata are **not** proposed as GI inputs:
GI operates against an activated service, and the mocks carry no protocol behavior.
