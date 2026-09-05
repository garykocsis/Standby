# Standby — Session 03

## Objective

Implement **F1 — Deterministic Economic Fixture** and produce the evidence required for **G1 — Deterministic Fixture Gate**.

F0 / G0 is already complete and authoritative. Reuse the existing validated real-Uniswap-v4 infrastructure and Hook deployment path.

Do not advance into F2 or later implementation responsibilities.

The purpose of this slice is to construct the canonical deterministic economic starting state through the real v4 execution path and independently verify its expected geometry **without implementing Standby production economic derivations**.

## Normative sources

Follow the frozen repository documentation, especially:

- `docs/implementation-plan.md` — F1 / G1
- `docs/demo-spec.md`
- `docs/uniswap-v4-realization.md`
- applicable frozen canonical engineering artifacts
- existing `CLAUDE.md`
- `.claude/rules/*`

Do not reinterpret frozen protocol semantics.

Before implementation, inspect the actual pinned v4 source and existing F0 test infrastructure rather than assuming APIs from examples or older Uniswap versions.

## Authorized scope

Implement only the minimal F1 footprint necessary for:

1. canonical mock currencies;
2. deterministic currency ordering;
3. fixture constants/configuration;
4. real canonical v4 pool construction;
5. real canonical liquidity establishment;
6. independent reference calculation of initial protected capacity;
7. focused G1 verification.

Likely files include, subject to the existing repository structure:

```text
src/mocks/
├── MockUSTB.sol
└── MockUSDC.sol

script/helpers/
├── StandbyFixtureConfig.sol
└── DeterministicFixtureDeployer.sol   # or equivalently narrow fixture helper

test/shared/
└── ReferenceCalculations.sol

test/integration/
└── DeterministicEconomicFixture.t.sol
```

Modify existing F0 shared test infrastructure only where genuinely necessary for clean reuse.

Do not introduce speculative shared abstractions solely because they appear in the candidate future repository hierarchy.

## Canonical currencies

Implement:

- `MockUSTB`
- `MockUSDC`

Requirements:

- both use exactly 6 decimals;
- simple deterministic mint/funding capability for fixture construction;
- no fee-on-transfer behavior;
- no rebasing;
- no Standby economic semantics;
- no protocol-specific assumptions beyond being fixture ERC-20s.

## Deterministic address ordering

The canonical identities must satisfy:

```text
address(MockUSTB) < address(MockUSDC)

currency0 = MockUSTB
currency1 = MockUSDC
protected fixture direction = zeroForOne
```

Do not:

- rely on ordinary CREATE deployment order;
- deploy arbitrary tokens and dynamically rename/relabel them according to address ordering;
- embed Standby economics into token contracts.

Use deterministic CREATE2-based fixture deployment.

The deployment mechanism must account for the actual CREATE2 deployer address and mock init-code hashes and deterministically select salts that guarantee:

```text
predictedAddress(MockUSTB) < predictedAddress(MockUSDC)
```

Deploy using those salts and assert the actual deployed addresses match the predicted relationship.

Keep this machinery explicitly fixture-scoped.

## Canonical fixture constants

`StandbyFixtureConfig.sol` may own the non-production fixture constants.

Establish:

```text
initial tick               = 0
tickQ                      = -240
tickO                      = +240
LP tickLower               = -300
LP tickUpper               = +300
tick spacing               = 10
static fee                 = 500 pips / 0.05%
liquidity L                = 6,707,079,990,254

expected initial S         = 80,000.000000 MockUSDC

canonical commitment q     = 50,000.000000 MockUSDC
compatible ordinary swap  = 15,000.000000 MockUSDC
destructive attempt        = 20,000.000000 MockUSDC
```

These are fixture/test/demo constants only.

`EXPECTED_INITIAL_S` must never become authoritative production economic state or a production derivation.

## Real v4 fixture construction

Reuse the validated F0 infrastructure.

Construct the canonical pool through the real pinned v4 stack:

```text
currency0 = MockUSTB
currency1 = MockUSDC
fee = 500
tickSpacing = 10
hook = the real F0-deployed StandbyHook
```

Initialize through the real PoolManager at canonical tick `0`, using the correct pinned v4 initialization API/math.

Fund the LP appropriately and establish the canonical liquidity position through the existing real v4 liquidity-modification path:

```text
tickLower = -300
tickUpper = +300
liquidity = 6,707,079,990,254
```

Do not directly mutate PoolManager state.

After construction, read authoritative PoolManager state and prove at minimum:

- current tick is `0`;
- canonical liquidity is actually present/active as expected;
- the PoolKey has the required currencies, fee, tick spacing, and Hook.

Do not treat requested fixture inputs as proof of resulting authoritative state.

## Independent reference calculation

Implement or extend `test/shared/ReferenceCalculations.sol` as an independent verification oracle.

For the canonical protected `zeroForOne` direction, independently calculate initial protected capacity from the canonical actual v4 state and fixture domain:

```text
S = getAmount1Delta(sqrtQ, sqrtP, L, false)
```

where:

- `sqrtP` corresponds to the actual initial pool state at tick `0`;
- `sqrtQ` corresponds to `tickQ = -240`;
- `L` is the actual canonical active liquidity.

Expected result:

```text
80,000,000,000 raw MockUSDC units
= 80,000.000000 MockUSDC
```

The reference oracle may use appropriate authoritative Uniswap math primitives from the pinned dependencies.

It must not import, call, or reuse any Standby production Supporting Capacity implementation for the property under verification.

There should be no production Supporting Capacity implementation in F1.

## Explicit prohibitions

Do not implement or introduce:

- `EligibilityRegistry`;
- F2 behavior;
- Standby PES activation/configuration;
- authoritative Hook-owned `tickQ` / `tickO` configuration;
- production protected-direction configuration;
- commitment storage;
- enforcement references;
- Remaining Entitlement;
- Aggregate Capacity Obligation;
- production Supporting Capacity;
- `StandbyMath` economic derivation;
- O1;
- O2;
- O3;
- `ExerciseRouter`;
- backing enforcement;
- eligibility logic;
- production assumptions about MockUSTB or MockUSDC;
- production assumptions that currency0 is always protected input;
- production assumptions that zeroForOne is always protected;
- production assumptions that Standby currencies always use six decimals.

The canonical fixture is deterministic evidence, not production semantics.

## G1 evidence

### G1-A — deterministic currency identity and real fixture

Prove in a fresh fixture:

1. `MockUSTB.decimals() == 6`;
2. `MockUSDC.decimals() == 6`;
3. `address(MockUSTB) < address(MockUSDC)`;
4. deterministic deployment construction guarantees that relation;
5. PoolKey `currency0 == MockUSTB`;
6. PoolKey `currency1 == MockUSDC`;
7. canonical protected fixture direction is zeroForOne;
8. pool was initialized through real PoolManager;
9. actual initial tick is exactly `0`;
10. fee is exactly `500`;
11. tick spacing is exactly `10`;
12. canonical LP position was established through the real v4 liquidity path over `[-300,+300]`;
13. actual canonical active liquidity is exactly `6,707,079,990,254`.

### G1-B — independent economics

From actual canonical v4 state, independently establish:

```text
S_reference = 80,000,000,000 raw MockUSDC units
            = 80,000.000000 MockUSDC
```

The derivation must remain independent of future production Standby S logic.

### Structural boundary

Confirm that F1 introduced no authoritative production:

- S;
- O;
- PES economic configuration;
- commitment state;
- O1/O2/O3 behavior;
- eligibility behavior.

## Completion report

Return:

1. concise description of the implementation;
2. files created/modified and their responsibilities;
3. deterministic deployment strategy used;
4. how real v4 fixture construction reuses F0;
5. how actual PoolManager state is verified;
6. how the independent 80,000 capacity reference is calculated;
7. G1-A evidence;
8. G1-B evidence;
9. test/build results required by existing repository rules;
10. any deviations from this task and why;
11. any possible frozen-semantic contradiction discovered;
12. confirmation that F2 and later responsibilities were not implemented.

Stop after F1/G1 evidence. Do not commit unless separately authorized after ChatGPT review.
