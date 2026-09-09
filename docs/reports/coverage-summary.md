# Standby — Coverage Summary

## Status

> **Status: Non-normative engineering evidence. This report does not define protocol semantics or independently establish a verification gate.**

Coverage is a measure of what the test suite executed. It is not a measure of semantic correctness, and it
is not invariant proof. An uncovered line is not, on its own, a protocol defect. Nothing in this report
establishes, closes, or reopens G-I.

---

## Checkpoint

```text
Post-GI
```

The F0–F8D production path is complete, G8D is PASS / CLOSED, and GI — Full Stateful Invariant Verification
has passed independent review. This is a diagnostic refresh of the post-F8D baseline recorded in the
previous revision of this report; that baseline is preserved below for comparison.

---

## Environment

| Item                   | Value                                                             |
| ---------------------- | ----------------------------------------------------------------- |
| Measurement date       | 2026-09-08                                                        |
| Git branch             | `feat/gi-stateful-invariant-verification`                         |
| Git commit (`HEAD`)    | `e698c22fb6396585cd7bd57cbe120be53b7724cc`                        |
| Working tree           | **Not clean — the measured state is uncommitted.** See below.     |
| Foundry                | `1.3.5-stable`, commit `9979a41b5daa5da1572d973d7ac5a3dd2afc0221` |
| Solidity / EVM         | `0.8.26` / `cancun`                                               |
| Active Foundry profile | `default` (fuzz `runs = 1000`, `seed = 0x1`)                      |
| Local Forge gas limit  | `gas_limit = 10000000000`                                         |
| Compilation            | **Optimizer and `via_ir` disabled by `forge coverage` itself**    |

### Working-tree state

`HEAD` is the F8D merge commit. **The Session 15 GI work was uncommitted when this measurement was taken,
so this report does not describe the state of commit `e698c22`.** It describes that commit plus the
following working-tree additions, all of which were staged at measurement time:

```text
test/invariant/StandbyInvariantHandler.sol
test/invariant/BaseStandbyInvariantTest.t.sol
test/invariant/StandbySequenceEvidence.t.sol
test/invariant/StandbyInvariant.t.sol
docs/prompts/session-15-gi-full-stateful-invariant-verification.md
docs/prompts/session-15-log.md
```

No production source, script, harness, existing test, frozen artifact, or configuration file differs from
`e698c22`. When the Session 15 work is committed, this measurement should be understood as belonging to that
commit.

---

## Command and Result

The post-F8D methodology was reconstructed from `docs/prompts/session-14-post-f8d-engineering-baseline.md`
§5, `docs/prompts/session-14-log.md`, and the previous revision of this report, and was preserved exactly:

```bash
forge coverage
```

Default profile, default summary report. No filtering, no exclusion, no `--match` option, no
`--ir-minimum`, and no change to `foundry.toml`.

Completed successfully (exit 0): 60 suites, **579 tests passed, 0 failed, 0 skipped**, under coverage
instrumentation, in 110.85 s.

A second, read-only invocation was used to locate the individual uncovered items reported below:

```bash
forge coverage --report debug
```

It produced no repository artifact.

### Compilation obstacle encountered, and what was done about it

The first `forge coverage` invocation **failed to compile**:

```text
Error: Compiler error (…/LValue.cpp:55): Stack too deep …
   --> test/invariant/StandbyInvariantHandler.sol:941:82
```

`forge coverage` disables the optimizer, and the GI handler's ordinary-swap generator held enough locals in
one frame to exceed the unoptimized stack limit. The optimized build the gates were verified against
compiles that frame without difficulty, so the failure was visible only under coverage instrumentation.

Two resolutions were possible, and the methodology decided between them. Adding `--ir-minimum` would have
changed the reconstructed coverage procedure, which this refresh is required to preserve. Splitting the
generator's amount and price-limit selection into two helper functions changes no behavior and restores the
established procedure, so that was done:

```text
test/invariant/StandbyInvariantHandler.sol — _ordinarySwap split into
    _ordinarySwap / _generatedSwapAmount / _generatedSwapLimitTick
```

This is a compile-time frame-size change, not a response to a coverage percentage and not a change to what
the campaigns generate or assert. It was verified as behavior-preserving before this measurement was taken:
the deterministic diagnostic campaigns reproduce **identical counters** in both configurations, and both
profiles still pass in full.

| Check after the change | Result |
| ---------------------- | ------ |
| `forge fmt --check` | clean |
| `forge build --sizes` | successful |
| `forge test` | 579 passed, 0 failed |
| `FOUNDRY_PROFILE=ci forge test` | 579 passed, 0 failed |
| GI diagnostic campaign counters | byte-for-byte identical to the pre-change run, both configurations |

### Material limitations affecting interpretation

1. **Instrumented build differs from the verified build.** Foundry reports:
   `Warning: optimizer settings and 'viaIR' have been disabled for accurate coverage reports.` The measured
   binary is therefore not the optimizer-enabled binary the gates were verified against. This affects which
   binary executed, not which source constructs the suite reached.

2. **Foundry's `Total` row is not a production figure.** It aggregates `src/`, `script/`, *and* `test/`
   files, so test and fixture code is counted alongside protocol code. Both are reported separately below,
   and the production aggregates are computed from the per-file rows rather than reported by Foundry.

3. **The repository-level row is not comparable across these two checkpoints.** GI added four instrumented
   test files, so the denominators moved (1361 → 1769 lines). Only the per-file and computed production
   figures below are like-for-like.

4. **`src/mocks/MockUSDC.sol` and `src/mocks/MockUSTB.sol` still report 0.00%.** The uncovered items are
   their `name()` and `symbol()` overrides, which nothing in the suite calls. They are deterministic fixture
   currencies, not protocol code.

5. **Coverage counts execution, not intent.** A covered branch is one the suite reached; it is not evidence
   that what the branch does is correct, and it is not evidence about any invariant. In particular, the
   stateful invariant campaigns contribute coverage exactly like any other test, and none of the figures
   below is evidence for or against G-I.

---

## Repository-Level Coverage

Reported by Foundry across all instrumented files (`src/`, `script/`, `test/`). The four dimensions are
distinct and are deliberately not collapsed into one number. See limitation 3: the denominators changed, so
the post-F8D column is context rather than a comparison.

| Dimension    | Post-F8D             | Post-GI              |
| ------------ | -------------------- | -------------------- |
| Lines        | 95.52% (1300 / 1361) | 96.21% (1702 / 1769) |
| Statements   | 94.72% (1239 / 1308) | 95.92% (1694 / 1766) |
| Branches     | 79.47% (120 / 151)   | 86.94% (193 / 222)   |
| Functions    | 97.03% (294 / 303)   | 97.01% (357 / 368)   |

---

## Production Coverage

### Per file, as reported

| File                                 | Lines            | Statements       | Branches       | Functions       |
| ------------------------------------ | ---------------- | ---------------- | -------------- | --------------- |
| `src/StandbyHook.sol`                | 99.73% (366/367) | 98.77% (401/406) | 93.98% (78/83) | 100.00% (66/66) |
| `src/ExerciseRouter.sol`             | 97.14% (68/70)   | 95.31% (61/64)   | 72.73% (8/11)  | 100.00% (16/16) |
| `src/EligibilityRegistry.sol`        | 100.00% (20/20)  | 100.00% (14/14)  | 100.00% (2/2)  | 100.00% (8/8)   |
| `src/libraries/StandbyMath.sol`      | 100.00% (34/34)  | 100.00% (28/28)  | 100.00% (7/7)  | 100.00% (9/9)   |
| `src/libraries/ServiceDomain.sol`    | 100.00% (19/19)  | 100.00% (19/19)  | 100.00% (1/1)  | 100.00% (6/6)   |
| `src/libraries/CommitmentRefs.sol`   | 100.00% (7/7)    | 100.00% (9/9)    | 100.00% (0/0)  | 100.00% (2/2)   |
| `src/demo/ActorAwareTestRouter.sol`  | 100.00% (50/50)  | 95.83% (46/48)   | 71.43% (5/7)   | 100.00% (12/12) |
| `src/mocks/MockFixtureCurrency.sol`  | 96.30% (26/27)   | 95.45% (21/22)   | 100.00% (3/3)  | 100.00% (6/6)   |
| `src/mocks/MockUSDC.sol`             | 0.00% (0/4)      | 0.00% (0/2)      | 100.00% (0/0)  | 0.00% (0/2)     |
| `src/mocks/MockUSTB.sol`             | 0.00% (0/4)      | 0.00% (0/2)      | 100.00% (0/0)  | 0.00% (0/2)     |

`src/StandbyHook.sol` is the only production file whose figures moved: statements 400 → 401 and branches
77 → 78, out of unchanged denominators. Every other production file is identical to the post-F8D baseline.

Deployment and configuration sources, for completeness — all unchanged from the baseline:

| File                                              | Lines           | Statements      | Branches      | Functions      |
| ------------------------------------------------- | --------------- | --------------- | ------------- | -------------- |
| `script/DeployStandbyHook.s.sol`                  | 47.62% (20/42)  | 46.81% (22/47)  | 0.00% (0/6)   | 66.67% (2/3)   |
| `script/helpers/DeterministicFixtureDeployer.sol` | 81.82% (18/22)  | 85.19% (23/27)  | 25.00% (1/4)  | 100.00% (3/3)  |
| `script/helpers/HelperConfig.s.sol`               | 100.00% (8/8)   | 100.00% (8/8)   | 100.00% (1/1) | 100.00% (2/2)  |

### Computed aggregates — post-F8D baseline, post-GI, delta

Summed from the per-file rows. These are computed here, not reported by Foundry.

Standby protocol core — the Hook, the ExerciseRouter, the EligibilityRegistry, and the three libraries:

| Dimension  | Post-F8D baseline   | Post-GI             | Delta                |
| ---------- | ------------------- | ------------------- | -------------------- |
| Lines      | 99.42% (514 / 517)  | 99.42% (514 / 517)  | unchanged            |
| Statements | 98.33% (531 / 540)  | 98.52% (532 / 540)  | +0.19 pp (+1 stmt)   |
| Branches   | 91.35% (95 / 104)   | 92.31% (96 / 104)   | +0.96 pp (+1 branch) |
| Functions  | 100.00% (107 / 107) | 100.00% (107 / 107) | unchanged            |

All of `src/`, including the demo router and the fixture currencies:

| Dimension  | Post-F8D baseline   | Post-GI             | Delta                |
| ---------- | ------------------- | ------------------- | -------------------- |
| Lines      | 98.01% (590 / 602)  | 98.01% (590 / 602)  | unchanged            |
| Statements | 97.39% (598 / 614)  | 97.56% (599 / 614)  | +0.17 pp (+1 stmt)   |
| Branches   | 90.35% (103 / 114)  | 91.23% (104 / 114)  | +0.88 pp (+1 branch) |
| Functions  | 96.90% (125 / 129)  | 96.90% (125 / 129)  | unchanged            |

---

## Newly Covered Production Surfaces Attributable to GI

Exactly one production surface moved from uncovered to covered:

### `src/StandbyHook.sol` L1668 — `_beforeRemoveLiquidity` → `StandbyHook__UntrustedLiquidityPerimeter`

The refusal of a **liquidity removal** proposed by a callback sender that is not the trusted liquidity
perimeter. It was **potential GI input #1** in the post-F8D report — the one uncovered item there identified
as intersecting an O3 authority boundary on a backing-affecting transition most directly.

GI reaches it because the invariant handler routes a fraction of its generated liquidity actions through the
ordinary-swap perimeter rather than the liquidity perimeter, and because the scripted liquidity-perimeter
sequence performs a removal through the wrong perimeter against an authentic positive obligation. The
addition-side refusal was already covered before GI; both sides of the liquidity perimeter boundary are now
covered.

That this branch is now executed says only that the suite reached it. What it is evidence *for* is recorded
in the GI evidence itself, not here.

---

## Material Uncovered Production Areas

Every uncovered production item is listed, as reported by `forge coverage --report debug`. Each is a
rejection path, a defensive clamp, or fixture metadata; none is an untested economic transition, and none is
classified here as a defect.

### `src/StandbyHook.sol` — 1 line, 5 statements, 5 branches (was 1 / 6 / 6)

| Location | Construct | Note |
| -------- | --------- | ---- |
| L1062 | `authorizeExercise` → `StandbyHook__ServiceNotConfigured` | O2 authorization against a Hook with no service. Every fixture, GI included, activates a service first. |
| L1218–1220 | `authorizedProtectedExecution` → `StandbyHook__ExerciseExecutionNotAuthorized` | The read surface consulted while the causal context is not `AUTHORIZED`. The equivalent refusal on the authoritative callback path *is* covered. |
| L2217 | `_beginSwapDerivation` → `StandbyHook__ServiceNotConfigured` | Prospective swap derivation before activation. |
| L2343 | `_nextSwapTargetTick` → `tickNext <= TickMath.MIN_TICK` clamp | Mirrors the pinned v4 swap loop's own clamping; reachable only at the extreme tick bound. |
| L2344 | `_nextSwapTargetTick` → `tickNext >= TickMath.MAX_TICK` clamp | As above, at the opposite bound. |

`L1668` — previously in this table — is now covered.

### `src/ExerciseRouter.sol` — 2 lines, 3 statements, 3 branches (unchanged)

| Location | Construct | Note |
| -------- | --------- | ---- |
| L395–396 | `ExerciseRouter__InputTransferFailed` | Reached only when `transferFrom` returns `false` without reverting. The fixture currencies revert with typed errors instead, and those failure modes *are* covered. |
| L441–443 | `ExerciseRouter__UnresolvedExerciseDelta` | The fail-closed guard for an exercise leaving an open PoolManager delta. Settlement and delivery close each side exactly, so no reachable path leaves one open. |
| L475 | `ExerciseRouter__ExerciseContextAlreadyActive` | A nested `exercise()` while one is already in flight. |

### `src/demo/ActorAwareTestRouter.sol` — 2 statements, 2 branches (unchanged)

`ActorAwareTestRouter__NotPoolManager` (L195) and `ActorAwareTestRouter__SettlementTransferFailed` (L244).
This contract is demo and test-perimeter instrumentation, not protocol.

### `src/mocks/` — fixture metadata (unchanged)

`MockUSDC.name/symbol` and `MockUSTB.name/symbol` are never called; `MockFixtureCurrency` L118 is the
allowance-decrement path taken only when the allowance is not `type(uint256).max`.

### `script/DeployStandbyHook.s.sol` — 22 lines, 25 statements, 6 branches (unchanged)

The mining and validation procedure is exercised by every fixture, but the broadcasting `run()` entrypoint
and its validation failure branches are not reached by `forge test` — consistent with the limitation already
recorded in `docs/project-status.md`, that `run()` is verified in script simulation rather than against a
live node.

---

## Classification of What Remains

### Semantically relevant, and still uncovered

- **`ExerciseRouter.sol` L475 — nested `exercise()` refusal.** This was **potential GI input #2** in the
  post-F8D report and GI did not reach it. GI generates top-level actions, so it cannot nest one exercise
  inside another; the Session 15 record states this as a known reachability gap rather than as covered. The
  adjacent Hook-side restriction — a second authorization while one is unresolved — is covered, and the
  router's one-originator-per-request discipline has its own periphery evidence
  (`test/periphery/ActorAttribution.t.sol` covers the equivalent restriction on the shared perimeter). This
  is the one remaining uncovered item that is a genuine authority-boundary rejection rather than a
  defensive guard.

- **`StandbyHook.sol` L1218–1220 — causal-position refusal on `authorizedProtectedExecution`.** A read
  surface, whose equivalent refusal on the authoritative callback path is covered. §28 of the GI session
  prompt deliberately declined to make this a GI obligation, and this refresh does not reopen that.

### Diagnostic, defensive, or structurally unreachable through the supported production domain

- **`StandbyHook.sol` L1062 and L2217 — `ServiceNotConfigured`.** Unreachable once a service exists, which
  every fixture and every campaign establishes first. Their equivalents elsewhere in the Hook are covered.
- **`StandbyHook.sol` L2343–2344 — tick-bound clamps.** Reachable only outside the configured service
  domain, which enforcement prevents any authoritative transition from entering. They mirror the pinned v4
  swap loop's own clamping and remain principally an F5 derivation concern.
- **`ExerciseRouter.sol` L395–396 — `InputTransferFailed`.** Requires a currency that returns `false`
  instead of reverting; the supported fixture currencies revert.
- **`ExerciseRouter.sol` L441–443 — `UnresolvedExerciseDelta`.** Structurally unreachable on the production
  path: settlement and delivery close each side exactly, and the guard exists to fail closed if they ever
  did not.
- **`ActorAwareTestRouter` and `src/mocks/`.** Demo perimeter and fixture instrumentation, not protocol.
- **`script/DeployStandbyHook.s.sol` `run()`.** Broadcast entrypoint, already recorded as verified in script
  simulation only.

### Test-side instrumentation notes

Two GI handler functions, `scriptedSetTraderEligibility` and `scriptedSetLiquidityEligibility`, are reported
as 0-hit *functions* while every statement inside them is covered. Both are called only internally by the
generated-action entry points, never through an external call, and the campaign counters record 25 and 52
accepted mutations respectively — so this is a function-entry attribution artifact of the instrumentation,
not dead code. The remaining uncovered GI test statements are the `assertTrue(false, …)` arms that exist
precisely so that they never execute: the orphan-authorization and orphan-finalization success branches, the
"an admitted commitment must occupy a bounded enforcement reference" guard, and the ordered-currency
deployment fallback.

---

## Disposition of the Post-F8D "Potential GI Inputs"

The previous revision recorded five uncovered items as **potential** GI inputs. GI has since been derived,
implemented, and independently reviewed. Their disposition, recorded here for continuity only:

| # | Item | Disposition |
| - | ---- | ----------- |
| 1 | Untrusted-perimeter liquidity removal (`StandbyHook.sol` L1668) | **Taken up by GI and now covered** — generated wrong-perimeter liquidity actions plus a scripted liquidity-perimeter sequence. |
| 2 | Nested exercise attribution (`ExerciseRouter.sol` L475) | **Considered, not reachable by GI.** GI acts at top level; recorded as a known reachability gap in `docs/prompts/session-15-log.md`. Still uncovered. |
| 3 | Causal-position refusal on the read surface (`StandbyHook.sol` L1218–1220) | **Deliberately excluded** by §28 of the GI session prompt. Still uncovered. |
| 4 | Tick-bound clamping (`StandbyHook.sol` L2343–2344) | **Deliberately excluded** by §28 unless GI exposed a reachable compositional counterexample; it did not. Still uncovered. |
| 5 | Unresolved-delta guard (`ExerciseRouter.sol` L441–443) | **Structurally unreachable** on the production path; GI's completed exercises resolve both sides exactly. Still uncovered. |

No coverage observation in this refresh exposed a previously unrecognized frozen verification obligation. No
test was added, removed, weakened, or suppressed to affect coverage, and no production code was excluded
from measurement or changed in any way.
