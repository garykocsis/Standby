# Standby — Gas Snapshot

## Status

> **Status: Non-normative engineering evidence. This report does not define protocol semantics or independently establish a verification gate.**

It records measured values at one repository checkpoint so that later measurements have something to be
compared against. It creates no optimization requirement.

---

## Checkpoint

```text
Post-F8D / Pre-GI
```

The F0–F8D production path is complete and G8D is PASS / CLOSED. GI has not been started.

---

## Environment

| Item                  | Value                                                                   |
| --------------------- | ----------------------------------------------------------------------- |
| Measurement date      | 2026-09-08                                                              |
| Git branch            | `feat/f8d-o2-causal-finalization`                                       |
| Git commit (`HEAD`)   | `8938a85bb8036424c02c7cae57fc994371573933`                              |
| Working tree          | **Not clean — the measured state is uncommitted.** See below.           |
| Foundry               | `1.3.5-stable`, commit `9979a41b5daa5da1572d973d7ac5a3dd2afc0221`       |
| Solidity / EVM        | `0.8.26` / `cancun`                                                     |
| Optimizer             | enabled, `optimizer_runs = 800`, `via_ir = false`, `bytecode_hash=none` |
| Active Foundry profile | `default` (fuzz `runs = 1000`, `seed = 0x1`)                           |
| Local Forge gas limit | `gas_limit = 10000000000`                                               |

### Working-tree state

`HEAD` is the F8C merge commit. **The Session 14 F8D work was uncommitted when this measurement was
taken, so this snapshot does not describe the state of commit `8938a85`.** It describes that commit plus
the following working-tree changes:

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

### Primary measurement

```bash
forge snapshot
```

Completed successfully: 58 suites, **539 tests passed, 0 failed, 0 skipped**.

It wrote the machine-readable artifact:

```text
.gas-snapshot
```

which holds one entry per test — 539 entries, of which 85 are fuzz entries reported as
`(runs, μ, ~)` rather than a single value. `.gas-snapshot` is the detailed comparison source and is
committed, per the repository's existing `.gitignore` convention.

### Supplementary measurement — attempted, did not complete

```bash
forge test --gas-report
```

**Failed: 68 of 538 tests failed under `--gas-report`.** The per-function gas tables it produced are
therefore *not* used in this baseline.

The cause was isolated and is a measurement artefact, not a defect:

- `--gas-report` runs each top-level call in isolation, which makes every call its own transaction;
- `forge test --isolate` alone reproduces the same failures on the same suites, confirming the mechanism;
- Standby's O2 causal context and the ExerciseRouter's originating-exerciser attribution are deliberately
  held in EIP-1153 transient storage, because the frozen realization requires that evidence to be
  transaction-scoped (`uniswap-v4-realization.md` §16);
- isolated execution therefore discards that evidence between the calls that make up one exercise, and the
  affected tests fail with causal-position errors such as
  `StandbyHook__ExerciseExecutionNotAuthorized(0)`.

No action was taken on this. Per-function gas attribution for the O2 path is simply not obtainable from
`--gas-report` while the causal proof is transaction-scoped.

### Non-gas supporting measurement

```bash
forge build --sizes
```

Used only for the deployed-size figures below.

---

## Measurements

### Deployed contract size

Runtime size, initcode size, and remaining margin against the 24,576-byte limit:

| Contract                   | Runtime | Initcode | Margin |
| -------------------------- | ------: | -------: | -----: |
| `StandbyHook`              |  21,996 |   23,022 |  2,580 |
| `ExerciseRouter`           |   4,284 |    4,635 | 20,292 |
| `EligibilityRegistry`      |   1,024 |    1,208 | 23,552 |
| `ActorAwareTestRouter`     |   4,752 |    4,940 | 19,824 |
| `MockUSTB` / `MockUSDC`    |   1,528 |    1,556 | 23,048 |

### Per-test gas — canonical production transitions

These are whole-test figures from `.gas-snapshot`. Each includes its own fixture construction, so a value
is a stable comparison point rather than the cost of a single protocol transition in isolation.

**O2 — complete production exercise** (authorize → execute → settle → deliver → finalize, production
`ExerciseRouter`, real PoolManager):

| Test                                                              |     Gas |
| ----------------------------------------------------------------- | ------: |
| `ExerciseFinalizationTest:test_minimalExercise_fulfilsExactlyOneRawUnit`          | 475,146 |
| `ExerciseFinalizationTest:test_completedExercise_reducesRemainingByExactlyQ`      | 479,065 |
| `ExerciseFinalizationTest:test_exhaustingExercise_leavesZeroRemainingAndZeroObligation` | 498,249 |
| `ExerciseFinalizationTest:test_canonicalSequence_reachesTheFrozenTerminalState`   | 580,700 |
| `ExerciseFinalizationTest:test_sequentialPartialExercises_produceTheExactRemainder` (three exercises) | 677,504 |
| `MisdirectedFinalizationTest:test_correctlyDirectedFinalization_commitsTheSameExercise` | 635,024 |
| `MisdirectedFinalizationTest:test_refusedFinalization_unwindsTheCompleteExercise` | 625,612 |

**O2 — settlement and delivery without finalization** (F8C fixture, `UnfinalizedExerciseRouter`):

| Test                                                              |     Gas |
| ----------------------------------------------------------------- | ------: |
| `ExerciseSettlementTest:test_authorizedExercise_settlesExactlyAndDeliversDirectly` | 587,776 |

**O1 — commitment admission:**

| Test                                                              |     Gas |
| ----------------------------------------------------------------- | ------: |
| `CommitmentAdmissionTest:test_establishCommitment_byEstablishmentAuthority_isAdmitted` | 207,914 |
| `CommitmentAdmissionTest:test_establishCommitment_withAFutureWindow_isAdmitted`        | 204,464 |
| `CommitmentAdmissionTest:test_establishCommitment_forAnIneligibleBeneficiary_isRejected` (refusal) | 148,368 |

**O3 — ordinary backing-affecting transitions against an authentic obligation:**

| Test                                                              |     Gas |
| ----------------------------------------------------------------- | ------: |
| `O3AuthenticBackingEnforcementTest:test_canonicalA2_compatibleOrdinarySwap_succeedsAgainstAuthenticObligation` | 509,574 |
| `O3AuthenticBackingEnforcementTest:test_canonicalA3_destructiveOrdinarySwap_isRejectedForInsufficientBacking`  | 605,189 |
| `O3LiquidityEnforcementTest:test_liquidityAddition_byEligibleProvider_becomesAuthoritative` | 234,341 |
| `O3LiquidityEnforcementTest:test_activeLiquidityRemoval_matchesTheProspectiveDerivation`    | 203,827 |

**Bounded aggregate-obligation derivation** (the scan whose cost the bounded index exists to cap):

| Test                                                              |       Gas |
| ----------------------------------------------------------------- | --------: |
| `AggregateObligationTest:test_aggregateObligation_isZeroWhenEverySlotIsEmpty`   |    50,506 |
| `AggregateObligationTest:test_aggregateObligation_countsOneBindingCommitment`   |   167,451 |
| `AggregateObligationTest:test_aggregateObligation_derivesAcrossAFullyOccupiedIndex` | 1,957,147 |

`.gas-snapshot` remains the authoritative detailed source; the entries above are a readable extract.

---

## Baseline Purpose

This report establishes the **post-F8D / pre-GI gas baseline** against which later measurements may be
compared. `.gas-snapshot` is the machine-comparable artifact; a subsequent `forge snapshot --diff` or
`forge snapshot --check` against it will show what changed and by how much.

It is a reference point only. It does not create a gas budget, a regression threshold, or an optimization
requirement, and no measurement in it has been acted upon.

---

## Observations

Four observations are materially noteworthy for interpreting the numbers. None of them is a defect and none
creates a requirement.

1. **The largest snapshot entries measure Hook address mining, not Standby execution.** The five highest
   entries range from ~209M to ~428M gas (for example
   `StandbyServiceConfigurationTest:test_configureAndActivate_rejectsAHookWithNoTrustedPositionManager` at
   427,994,963, and the `ProspectiveTraversalBoundTest` suite at ~209M each). These suites deploy Hooks
   in-test through the canonical procedure, and the cost is the pinned `HookMiner.find` search, which
   rehashes the whole Hook creation code per candidate salt. This is the same characteristic recorded in
   `docs/setup.md` for the local Forge gas limit.

2. **Per-test gas is not per-transition gas.** Every figure includes the fixture the test builds — pool
   initialization, canonical liquidity, service activation, and commitment admission — so comparisons
   between different suites are not comparisons between protocol operations.

3. **Per-function gas attribution is unavailable for the O2 path** under `forge test --gas-report`, for the
   transient-storage reason recorded under Command and Result. Anyone wanting per-function figures for
   Standby's non-O2 surface would need to obtain them without isolated execution.

4. **`StandbyHook` has 2,580 bytes of runtime margin** against the 24,576-byte limit at this checkpoint.
   Recorded as a fact to compare against, not as a limit being approached in a way that requires action.
