# Session 03 — Material Prompt Log

Initiating prompt: `docs/prompts/session-03-f1-deterministic-economic-fixture.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

_No material follow-up prompts recorded yet._

---

## Task Completion Report — F1 Deterministic Economic Fixture

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/implementation-plan.md` (§6 F1 / §6.5 G1, §8 F3, §11 F6A, §12 F7, repository footprint)
- `docs/demo-spec.md` (§4 demo asset model, §5 canonical pool/service configuration, §6 Supporting Capacity)
- `docs/uniswap-v4-realization.md` (§4 configuration/activation, RR-CONFIG-1..6, §6 Supporting Capacity)
- `src/StandbyHook.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/HelperConfig.s.sol`
- `test/shared/BaseV4Test.t.sol`, `test/integration/StandbyHookDeployment.t.sol`
- `foundry.toml`, `remappings.txt`, `.github/workflows/ci.yml`

Pinned dependency source:

- `lib/v4-hooks-public/src/base/BaseHook.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/CustomRevert.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/StateLibrary.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/SqrtPriceMath.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/FullMath.sol`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/TickMath.sol`
- `lib/v4-hooks-public/lib/v4-core/src/types/PoolId.sol`
- `lib/v4-hooks-public/lib/v4-core/src/test/PoolModifyLiquidityTest.sol`
- `lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol`

### Files Changed

Created:

- `src/mocks/MockFixtureCurrency.sol` — minimal six-decimal ERC-20 shared by the two fixture
  currencies, so the boring transfer/allowance accounting is written once. No fee-on-transfer, no
  rebase, no Standby semantics; unpermissioned `mint` for fixture funding.
- `src/mocks/MockUSTB.sol` — canonical fixture currency, name/symbol only.
- `src/mocks/MockUSDC.sol` — canonical fixture currency, name/symbol only.
- `script/helpers/StandbyFixtureConfig.sol` — frozen non-production fixture constants (ticks, LP range,
  spacing, fee, canonical liquidity, protected direction, expected S, canonical q, canonical swap
  amounts). Documented as never-production state; no production contract reads it.
- `script/helpers/DeterministicFixtureDeployer.sol` — deterministic CREATE2 currency deployment that
  makes `address(MockUSTB) < address(MockUSDC)` a property of the deployment procedure.
- `test/shared/ReferenceCalculations.sol` — independent verification oracle for protected capacity.
- `test/integration/DeterministicEconomicFixture.t.sol` — G1-A / G1-B integration evidence.

No existing file was modified. `BaseV4Test.t.sol`, `StandbyHook.sol`, `DeployStandbyHook.s.sol`,
`HelperConfig.s.sol`, and `NetworkConfig.sol` were left untouched.

### Requirements Implemented

- Implementation plan §6.2 canonical currencies, required ordering, canonical economic constants.
- Implementation plan §6.3 boring six-decimal mocks.
- Implementation plan §6.4 independent fixture proof through `ReferenceCalculations.sol`.
- `demo-spec.md` §4.1–§4.3 currency model, ordering, protected direction; §5 canonical pool
  configuration; §6.2 `S = getAmount1Delta(sqrtQ, sqrtP, L, false)` geometry; §6.3 `S₀ = 80,000.000000`.

### Tests Added or Changed

All in `test/integration/DeterministicEconomicFixture.t.sol` (15 tests):

- `test_fixtureCurrencies_useExactlySixDecimals` — G1-A(1,2).
- `test_fixtureCurrencies_satisfyRequiredAddressOrdering` — G1-A(3).
- `test_deterministicDeployment_predictsTheOrderedAddressesBeforeDeploying` — G1-A(4): both addresses
  are predicted before deployment, the deployed addresses equal those predictions, salt selection is
  reproducible.
- `test_deterministicDeployment_guaranteesOrderingFromAnyDeployerAddress` — G1-A(4): a second deployer
  at a different address independently reproduces the ordering, so the relation is a guarantee of the
  mechanism, not of one lucky deployment.
- `test_canonicalPoolKey_bindsOrderedCurrenciesFeeSpacingAndStandbyHook` — G1-A(5,6,10,11) plus Hook
  binding.
- `test_canonicalProtectedDirection_isZeroForOneFromMockUSTBToMockUSDC` — G1-A(7).
- `test_canonicalPool_isInitializedThroughRealPoolManagerAtTickZero` — G1-A(8,9,10) read back from
  authoritative `slot0`.
- `test_geometryPool_isInitializedAtTickZeroWithCanonicalFeeAndSpacing` — G1-A(8,9,10,11).
- `test_canonicalLiquidityPosition_isEstablishedOverTheCanonicalRange` — G1-A(12) from authoritative
  position state.
- `test_canonicalActiveLiquidity_isExactlyTheCanonicalAmount` — G1-A(13) from authoritative pool state.
- `test_canonicalLiquidityRange_enclosesTheServiceDomain` — one constant active-liquidity interval.
- `test_independentReference_derivesEightyThousandMockUSDCFromActualPoolState` — G1-B.
- `test_independentReference_dependsOnActualLiquidity` — proves the oracle consumes its inputs rather
  than returning a constant.
- `test_canonicalHookBoundPool_holdsNoLiquidityAtF1` — structural boundary.
- `test_canonicalHookBoundPool_rejectsLiquidityAdditionUntilEnforcementIsImplemented` — structural
  boundary and the concrete evidence for the blocker recorded below.

### Commands Run

```bash
git status
forge build
forge fmt
forge fmt --check
forge build --sizes
forge test --match-path test/integration/DeterministicEconomicFixture.t.sol -vv
forge test
FOUNDRY_PROFILE=ci forge test
forge lint
```

### Results

- `forge fmt --check` — clean.
- `forge build --sizes` — successful.
- `forge lint` — no findings.
- `forge test --match-path test/integration/DeterministicEconomicFixture.t.sol -vv` — 15 passed,
  0 failed.
- `forge test` — 29 passed, 0 failed, 0 skipped across 3 suites.
- `FOUNDRY_PROFILE=ci forge test` — 29 passed, 0 failed, 0 skipped.

The independent oracle produced exactly `80,000,000,000` raw MockUSDC units from authoritative
PoolManager state.

### Gate Evidence

Implemented and verified:

- G1-A(1,2) six decimals on both currencies.
- G1-A(3) `address(MockUSTB) < address(MockUSDC)`.
- G1-A(4) the relation is guaranteed by deterministic CREATE2 construction, proven by pre-deployment
  prediction and by a second independent deployer.
- G1-A(5,6) canonical PoolKey `currency0 = MockUSTB`, `currency1 = MockUSDC`.
- G1-A(7) canonical protected fixture direction is zeroForOne, protected output currency MockUSDC.
- G1-A(8,9) real PoolManager initialization at actual tick `0` for both fixture pools, read back from
  authoritative `slot0`.
- G1-A(10,11) authoritative LP fee `500` and tick spacing `10`.
- G1-A(12,13) canonical LP position over `[-300, +300]` and actual active liquidity exactly
  `6,707,079,990,254`, established through the official pinned `PoolModifyLiquidityTest` path and read
  back from authoritative position and pool state.
- G1-B initial protected capacity `80,000,000,000` raw MockUSDC units derived independently from actual
  pool state.

Implemented but scoped differently from the session prompt:

- G1-A(12,13) evidence is produced on `geometryPoolKey` (no Hook), not on the Hook-bound
  `canonicalPoolKey`. See the blocker below. G1-A(5,6,8,9,10,11) evidence is produced on the Hook-bound
  canonical pool.

Structural boundary confirmed:

- No production Supporting Capacity, Aggregate Capacity Obligation, PES economic configuration,
  commitment state, eligibility behavior, `StandbyMath`, `EligibilityRegistry`, `ExerciseRouter`, or
  O1/O2/O3 behavior was introduced. `src/StandbyHook.sol` is byte-for-byte unchanged from F0.

### Known Limitations / Blockers

**Conflict between the session prompt and frozen realization requirements.** The session prompt
requires the canonical liquidity position to be established in a pool whose `hooks` is the real
F0-deployed `StandbyHook`. That cannot be done at F1, for two independent reasons:

1. `StandbyHook` enables `beforeAddLiquidity` and inherits the pinned `BaseHook._beforeAddLiquidity`,
   which reverts with `HookNotImplemented`. Any liquidity addition to a Hook-bound pool therefore
   reverts. Making it succeed would require implementing the F6A liquidity-admission callback, which
   the session prompt and `CLAUDE.md` both prohibit at F1.
2. `docs/uniswap-v4-realization.md` §4.1 step 6 requires `configureAndActivate` to verify that current
   pool liquidity is **zero**, and RR-CONFIG-1 states that pool initialization binds the Hook and that
   Standby configuration is established "before liquidity or O1". A Hook-bound canonical pool that
   already holds the canonical liquidity at F1 could never be configured at F3.

`docs/implementation-plan.md` §6, which is the authoritative F1 definition, does not require a Hook-bound
pool or any pool construction; it requires the currencies, the ordering, the constants, and the
independent fixture proof. The prompt's pool-construction requirement is additional verification work,
which is permitted, but its Hook-attachment clause is not satisfiable without crossing into F6A.

Resolution taken, pending review: the Hook-bound `canonicalPoolKey` is initialized through the real
PoolManager at tick 0 and carries the canonical identity evidence with zero liquidity, exactly as
RR-CONFIG-1 describes; a second real pool with identical currencies, fee, and tick spacing and no Hook
carries the canonical liquidity and supplies the authoritative `sqrtP` and `L` for the capacity
reference. The Hook does not participate in the AMM arithmetic that determines capacity, so the
geometry evidence is unaffected. Two tests record the constraint explicitly rather than hiding it.

Other observations:

- An external, concurrent modification to `docs/implementation-plan.md` appeared in the working tree
  during this session (a G5-C amendment requiring heterogeneous currency-decimal generalization). It was
  not made by this session and was left untouched. It appears to contain markdown artifacts: the H1
  title was demoted to `##` and two headings gained literal `\*\*` escapes.
- `test/shared/BaseV4Test.t.sol` still uses filesystem-relative `lib/` imports rather than the canonical
  remapped prefixes. Pre-existing, out of scope, not touched.
- `docs/project-status.md` still records F1 as NOT STARTED. Gate status is not this session's to change.

### Scope Check

Work remained within F1. No F2+ responsibility was implemented. No production contract was modified. No
dependency, remapping, compiler, or Foundry configuration was changed, so `docs/setup.md` needed no
update. The only deviation from the session prompt is the Hook attachment on the liquidity-bearing
fixture pool, described above.

### Proposed Gate Assessment

**PARTIAL.**

Every G1 requirement in `docs/implementation-plan.md` §6.5 has passing evidence, and every numbered
G1-A item and the G1-B derivation in the session prompt has passing evidence. The single deviation is
that G1-A items 12–13 are proven on the no-Hook canonical-geometry pool rather than on the Hook-bound
canonical pool, because the frozen realization requirements and the F0 fail-closed Hook make the latter
impossible at F1. That deviation requires explicit review before G1 is closed.

### Recommended Next Step

Review the Hook-attachment conflict and decide one of:

1. confirm that F1's canonical liquidity evidence belongs on the no-Hook geometry pool and that the
   Hook-bound canonical pool is established with zero liquidity, then close G1 as PASS; or
2. relocate the canonical liquidity evidence to a later slice (F6A or later), where liquidity can be
   admitted through the enforced Hook path, and narrow G1 to currency identity, pool identity, and the
   independent capacity reference.

Do not begin F2 until G1 is explicitly closed.

### Prompt Audit

Material follow-up prompts recorded in this log: **0**. The session was executed from
`docs/prompts/session-03-f1-deterministic-economic-fixture.md` with no material follow-up instructions.

---
