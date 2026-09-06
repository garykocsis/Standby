# Session 05 — Material Prompt Log

Initiating prompt: `docs/prompts/session-05-f3-hook-trust-pes-configuration.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

_No material follow-up prompts recorded yet._

---

## Task Completion Report — F3 StandbyHook Trust + PES Configuration

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/prompts/session-05-f3-hook-trust-pes-configuration.md`, `docs/prompts/session-04-log.md`
- `docs/implementation-plan.md` (§5.3 `NetworkConfig` candidate fields, §5.4 canonical deployment path,
  §8 F3 / §8.2 Hook decomposition / §8.3 deployment-time facts / §8.4 one-shot activation / §8.5
  activation validation / §8.6 callback trust / §8.7 G3-H / §8.8 G3-C, §11.2 actor attribution, §11.3
  actor-aware Anvil periphery, §20.6 demo deployment composition, §24 canonical demo actors)
- `docs/uniswap-v4-realization.md` (§2 component overview, §3 pool setup / RR-SETUP-1..5, §4 service
  configuration / RR-CONFIG-1..6, §5 service domain / RR-SC-3/5/6 / RR-TOPO-1/2, §6.4 RR-SC-4, §8
  permission domains / RR-PERM-1..11, §9 persistent vs derived state / RR-STATE-1..8, §18 pool
  enforcement surface, §19 control boundaries / RR-CTRL-1..6, §20.1 RR-PATH-1, §24 currency/fee/pool
  compatibility)
- `docs/architecture.md` and `docs/state-machine.md` (authority boundaries, PES semantic basis,
  persistence criteria)
- `src/StandbyHook.sol`, `src/EligibilityRegistry.sol`, `src/interfaces/IEligibilityRegistry.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/HelperConfig.s.sol`,
  `script/helpers/NetworkConfig.sol`, `script/helpers/StandbyFixtureConfig.sol`,
  `script/helpers/DeterministicFixtureDeployer.sol`
- `test/shared/BaseV4Test.t.sol`, `test/integration/StandbyHookDeployment.t.sol`,
  `test/integration/DeterministicEconomicFixture.t.sol`
- `foundry.toml`, `remappings.txt`, `.github/workflows/ci.yml`, `docs/setup.md`

Pinned Uniswap v4 dependency source (inspected rather than assumed from memory):

- `lib/v4-hooks-public/src/base/BaseHook.sol` — callback dispatch, `onlyPoolManager`,
  `validateHookAddress`
- `lib/v4-hooks-public/lib/v4-periphery/src/base/ImmutableState.sol` — `poolManager`, `NotPoolManager`
- `lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol` — `initialize` preconditions
- `lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol` — `isValidHookAddress`, flag constants
- `lib/v4-hooks-public/lib/v4-core/src/libraries/LPFeeLibrary.sol` — `DYNAMIC_FEE_FLAG`, `isDynamicFee`,
  `getInitialLPFee`, `MAX_LP_FEE`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/StateLibrary.sol` — `getSlot0`, `getLiquidity`
- `lib/v4-hooks-public/lib/v4-core/src/libraries/TickMath.sol` — `MIN_TICK`, `MAX_TICK`,
  `getSqrtPriceAtTick`
- `lib/v4-hooks-public/lib/v4-core/src/types/PoolKey.sol`, `.../types/PoolId.sol`

### Files Changed

Modified:

- `src/StandbyHook.sol` — added the H1 responsibility: three additional realization-wide immutable trust
  dependencies (`i_configurationAuthority`, `i_trustedUniversalRouter`, `i_trustedPositionManager`), the
  `ProtectedExecutionService` basis, the one-shot `configureAndActivate` transition with its full
  validation sequence, the `ProtectedExecutionServiceActivated` event, and the
  `protectedExecutionService()` / `serviceId()` read surface. The callback permission surface is
  unchanged and the four enabled callbacks still fail closed.
- `script/DeployStandbyHook.s.sol` — the canonical deployment procedure now binds the F3 trust basis.
  `deployStandbyHook(...)` takes the three trust addresses, they participate in the mined init code, and
  `_validateDeployedHook` proves each bound role equals its intended value under its own error. `run()`
  reads the three values from required environment variables.
- `test/integration/StandbyHookDeployment.t.sol` — extended for G3-H: exact immutable trust fidelity,
  perimeter-role distinctness, trust participation in Hook identity, and non-PoolManager rejection for
  all four enabled callbacks.
- `test/integration/DeterministicEconomicFixture.t.sol` — deployment call site updated for the new
  procedure signature. No F1 assertion changed.
- `docs/setup.md` — new "Environment Variables" section documenting the three deployment variables the
  script entrypoint now requires, and that build/test require none.

Created:

- `test/shared/BaseStandbyServiceTest.t.sol` — the shared real-path F3 fixture: real `PoolManager`,
  canonical Hook deployment, F2 registry, F1 ordered fixture currencies, canonical Hook-bound pool
  initialized at tick 0 with zero liquidity, and the `_assertNoServiceConfigured` helper used to prove
  atomic rejection. Every role gets a distinct address.
- `test/integration/StandbyServiceConfiguration.t.sol` — the main G3-C evidence (31 tests).
- `test/fuzz/StandbyServiceGeometryFuzz.t.sol` — G3-C service-geometry fuzz evidence (5 tests).
- `test/harness/LiquidityPermissiveStandbyHookHarness.sol` — a `StandbyHook` subclass overriding only the
  F6A-owned `_beforeAddLiquidity`, so the zero-liquidity activation guard is reachable at all.
- `test/unit/StandbyServiceLiquidityPrecondition.t.sol` — the zero-liquidity guard evidence (2 tests).
- `docs/prompts/session-05-log.md` — this audit artifact.

Deleted: none.

`docs/project-status.md` was deliberately not modified: G3 has not been reviewed or closed, and the
document already records F3 as the current slice.

### Requirements Implemented

Hook-wide immutable trust (prompt §1, RR-STATE-2):

- PoolManager (preserved), configuration authority, trusted Universal Router, and trusted PositionManager
  are Hook constructor-bound immutables. None is duplicated into per-PES state. The two perimeters are
  distinct roles in distinct immutables, and the deployment path validates each separately.

One-shot lifecycle (prompt §2, RR-CONFIG-3, RR-SETUP-5, RR-STATE-7):

- Exactly one transition, `configureAndActivate`. No partial setter, no separate configured/active
  lifecycle, no generic active flag, no pause, deactivate, reconfigure, replace, migrate, cancel, or
  post-activation setter. A single `configured` boolean is the service-existence fact.

Authoritative PES basis (prompt §3, RR-STATE-1/3/4/5/6):

- Persisted: `configured`, complete `PoolKey`, `protectedZeroForOne`, `tickQ`, `tickO`, `exerciseRouter`,
  `registry`, `establishmentAuthority`.

Derived, not persisted (prompt §4, RR-SC-3, RR-STATE-6/8):

- PoolId (derived by `serviceId()` from the persisted key), `sqrtQ` / `sqrtO`, numeric domain
  minimum/maximum, promised-result currency, and every dynamic economic quantity. No fee mirror.

Activation authority (prompt §5, RR-CTRL-1):

- Only `i_configurationAuthority` can activate. Configuration authority is not conferred by registry
  administration, establishment authority, exercise designation, or either trusted perimeter.

Activation environmental validation (prompt §6, RR-SETUP-4, §4.1 of the realization) — implemented in the
frozen order: authority, PoolId derivation, Hook binding, pool initialized, PES does not exist, zero
liquidity, supported fee model, authoritative current price, direction and boundary validation, closed
domain containment, ExerciseRouter, registry, establishment authority, trusted realization dependencies,
then a single atomic persistence.

Supported pool/accounting model (prompt §7, RR-STATE-8, §24.1):

- The dynamic-fee sentinel is rejected. Every other fee value that reaches activation is already
  constrained by the PoolManager: initialization rejects any `fee > MAX_LP_FEE`, so an unsupported static
  fee cannot present an initialized pool. Custom accounting is excluded structurally, because the key
  must bind this exact Hook and this Hook declares no return-delta permission.

Service-domain validation (prompt §8, RR-SC-3/5/6):

- Direction-relative ordering, valid tick range, tick-spacing alignment, and closed-domain containment
  evaluated in square-root price space against authoritative Slot0.

Trusted perimeter ownership (prompt §9) and registry binding (prompt §10) as described above. No registry
membership consumption, no eligibility enforcement.

Callback trust boundary (prompt §11, RR-PATH-1): the four enabled callbacks are unchanged, every other
callback and every return-delta permission remains disabled, and all four reject non-PoolManager callers.

### Interpretation Decisions

Two points required a deliberate reading; both are recorded here because a reviewer should be able to
disagree with them explicitly.

1. **Where the trusted-dependency check lives (validation step 15).** `implementation-plan.md` §8.3 says
   not to constructor-bind trusted periphery "unless required by the frozen architecture"; RR-STATE-2 and
   the session prompt §1 do require it. The prompt §9 then says `configureAndActivate` "must validate
   that the service is being established against the Hook's already-fixed trusted realization
   dependencies", and the frozen sequence places that at step 15 of activation. It is therefore
   implemented as an activation check, not a constructor check, so that it is a single authoritative
   check, sits where the frozen sequence puts it, and is reachable and provable. A Hook deployed without
   a complete trust basis is inert: it can never host a service, so it can never reach any Standby
   economic transition. Configuration authority is excluded from that step because step 1 already
   authenticates it and `address(0)` can never be `msg.sender`.

2. **Trust configuration is not `NetworkConfig` infrastructure.** `HelperConfig` and `NetworkConfig` were
   left as infrastructure resolution only. The three trust addresses are deployment decisions, so the
   script entrypoint requires them in the environment and the reusable procedure takes them as explicit
   arguments. The alternative — defaulting them for the local environment — would have deployed a Hook
   against a guessed or fake trust basis.

### Tests Added or Changed

`test/integration/StandbyHookDeployment.t.sol` (15 tests; 4 added or rewritten):

- `test_deployedHook_bindsEveryIntendedTrustDependency` — G3-H 1–4: PoolManager, configuration authority,
  ordinary-swap perimeter, and liquidity perimeter are each exactly the intended address.
- `test_deployedHook_keepsTheTwoTrustedPerimeterRolesDistinct` — the two perimeters are distinct roles: a
  Hook deployed with the two arguments swapped reports them swapped, and is a different Hook.
- `test_deployedHook_addressDependsOnTheConfiguredTrustBasis` — the trust basis is part of the mined init
  code, so a Hook with a different configuration authority is a different, still permission-valid Hook.
- `test_deployedHook_rejectsEveryEnabledCallbackFromNonPoolManager` — G3-H 9, extended from `beforeSwap`
  alone to all four enabled callbacks.
- `test_canonicalDeployment_producesTheDeterministicMinedAddress` — updated to recompute the CREATE2
  address over the full constructor argument set.
- The existing G0-H1/H2 permission tests (exactly four callbacks enabled, every other callback and every
  return-delta permission disabled, address bits equal to `0x0AC0`, pinned validator agreement) are
  unchanged and still pass: G3-H 5–8.

`test/integration/StandbyServiceConfiguration.t.sol` (31 tests) — G3-C:

- Positive activation, event emission, complete read fidelity, derived service identity, and proof that
  activation does not mutate authoritative pool state (RR-CONFIG-5).
- Authority: rejection of an unrelated account, and of every other Standby role individually.
- One-shot: activation succeeds exactly once; a second activation with a different registry, direction,
  domain, ExerciseRouter, establishment authority, and pool is rejected and changes nothing; ten
  plausible setter / pause / deactivate / migrate selectors are all absent from the deployed contract.
- Environment: no-Hook key rejected, different-StandbyHook key rejected, uninitialized pool rejected,
  real dynamic-fee pool rejected.
- Geometry: inverted domain rejected for each direction, the mirrored `oneForZero` configuration accepted,
  equal boundaries rejected, out-of-range tick rejected, misaligned tick rejected, price above and below
  the domain rejected, boundary equality at `tickQ` and at `tickO` accepted, and a price one unit above
  the `tickO` price rejected even though the pool still reports tick `tickO` — the case that separates
  price-space containment from tick-space containment.
- Participants: unset registry, unset ExerciseRouter, and unset establishment authority each rejected.
- Trusted dependencies: a Hook with no ordinary-swap perimeter and a Hook with no liquidity perimeter each
  refuse activation, separately.
- Separation: every trust and authority role of the activated service is pairwise distinct; the registry
  keeps its own administrator, the Hook exposes no membership-management function, and registry
  membership remains externally mutable while the bound reference is unchanged.
- Every rejection asserts, through `_assertNoServiceConfigured`, that no field of the PES became
  authoritative and that the Hook reports no service identity.

`test/fuzz/StandbyServiceGeometryFuzz.t.sol` (5 tests, 1000 runs default / 10000 in CI) — G3-C geometry
across the input domain rather than at the canonical point. Each run builds a real pool through
`PoolManager.initialize`:

- any spacing-aligned direction-relative domain anywhere in the usable tick range, with the current price
  anywhere inside the closed domain, activates and reads back exactly — both protected directions;
- boundaries ordered against the protected direction are always rejected;
- a boundary offset off the tick spacing is always rejected;
- a boundary outside `[MIN_TICK, MAX_TICK]` is always rejected;
- a current price strictly outside the closed domain, above or below, is always rejected.

`test/unit/StandbyServiceLiquidityPrecondition.t.sol` (2 tests) — G3-C 5, the zero-liquidity guard:

- with real canonical liquidity in the pool, added through the official `PoolModifyLiquidityTest` router
  and the real PoolManager, activation reverts with the authoritative liquidity value and persists
  nothing;
- the identical Hook, pool, and arguments activate before that liquidity exists, so the rejection is
  caused by real PoolManager state and not by the harness.

### Commands Run

```bash
git status
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test --match-path test/integration/StandbyHookDeployment.t.sol
forge test --match-path "test/integration/*"
forge test --match-path test/unit/StandbyServiceLiquidityPrecondition.t.sol -vv
forge test --match-path test/fuzz/StandbyServiceGeometryFuzz.t.sol
forge test
FOUNDRY_PROFILE=ci forge test
STANDBY_CONFIGURATION_AUTHORITY=0x…A1 \
STANDBY_TRUSTED_UNIVERSAL_ROUTER=0x…B2 \
STANDBY_TRUSTED_POSITION_MANAGER=0x…C3 \
forge script script/DeployStandbyHook.s.sol
```

### Results

- `forge fmt --check` — clean.
- `forge build --sizes` — successful. `StandbyHook` deployed size 7,472 bytes, well inside the limit.
- `forge test` — 98 passed, 0 failed, 0 skipped across 8 suites.
- `FOUNDRY_PROFILE=ci forge test` — 98 passed, 0 failed, 0 skipped, with 10,001 fuzz runs per fuzz test.
- `forge script script/DeployStandbyHook.s.sol` — resolved a real PoolManager, mined a salt, and deployed
  a Hook at `0x7250039a0387bc9b9caf9efd7C541FF20c328ac0`, whose masked address bits are `0x0AC0`, bound to
  the three supplied trust addresses.

One intermediate failure occurred and was fixed rather than suppressed: under the CI fuzz budget the
out-of-domain price generator could request a tick above `MAX_TICK - 1` when the fuzzed domain reached the
top of the usable range. The bounding helper now reserves an initializable tick on each side of the
domain. No assertion was weakened.

### Gate Evidence

**Implemented and verified**

- G3-H 1–4 — immutable PoolManager, configuration authority, ordinary-swap perimeter, and liquidity
  perimeter are exact, proved on the Hook produced by the canonical deployment procedure.
- G3-H 5–8 — exactly four callbacks enabled, every other callback disabled, all return-delta permissions
  false, deployed address bits match the declared permissions and satisfy the pinned validator.
- G3-H 9 — every enabled callback rejects a non-PoolManager caller.
- G3-C — positive activation; each of the fifteen listed admission boundaries proved independently;
  no partial PES after any rejection; complete read fidelity; registry, direction/domain, ExerciseRouter
  and establishment authority all unreplaceable; perimeter roles distinct; ExerciseRouter trust distinct
  from ordinary periphery trust; establishment authority distinct from configuration, exercise, and
  eligibility authority; no post-activation reinterpretation path.
- Geometry evidence is fuzzed across tick spacing, direction-relative ordering, tick validity, alignment,
  and domain containment rather than only at the canonical fixture values.
- Initialized-state, current-liquidity, and current-price conditions are judged against real pinned
  PoolManager state throughout.

**Verified with declared isolation**

- G3-C 5 (nonzero liquidity rejected) uses `LiquidityPermissiveStandbyHookHarness`. No production path can
  place liquidity in a StandbyHook-bound pool at F3, because `beforeAddLiquidity` is fail-closed until
  F6A; the condition would otherwise be unreachable. The harness overrides only that F6A-owned callback,
  inherits `configureAndActivate` unchanged, seeds no state, and the liquidity the guard reads is real
  PoolManager liquidity added through the official router. The paired test shows the same Hook and pool
  activating before that liquidity exists. This is reported as isolated evidence rather than integration
  evidence, and the reviewer should decide whether it satisfies G3-C 5.

**Still unverified**

- The broadcasting `run()` path is verified in Foundry script simulation, not against a live Anvil node
  with `--broadcast` — a limitation carried forward from F0, now also covering the new environment
  variables.
- No stateful invariant evidence exists for the service configuration. None is required by G3; GI owns it.

### Known Limitations / Blockers

- No production trusted-perimeter contracts exist yet. `ActorAwareTestRouter` (implementation plan §11.3)
  arrives with F6A, and `HelperConfig` still resolves no Universal Router or PositionManager address, so a
  local deployment must supply perimeter addresses explicitly. F3 binds the roles only; nothing consumes
  them yet.
- `HelperConfig` still resolves infrastructure only for chain id `31337`.
- The four enabled Hook callbacks still fail closed with `HookNotImplemented`. An activated service does
  not yet enforce anything, so `StandbyHook` must still not be attached to a live pool.
- `test/shared/BaseV4Test.t.sol` imports its v4 dependencies through filesystem-relative `lib/` traversal
  rather than the canonical remappings, contrary to `.claude/rules/solidity-style.md`. Pre-existing, not
  touched here to avoid unrelated churn; worth a separate cleanup.

### Scope Check

Work stayed within the authorized F3 slice. No commitment storage, commitment identity, Supporting
Capacity, Aggregate Capacity Obligation, prospective derivation, O3 enforcement, liquidity admission,
O1, O2, ExerciseRouter behavior, eligibility consumption, invariant handler, acceptance test, or frontend
work was introduced. `src/ExerciseRouter.sol`, `src/libraries/StandbyMath.sol`, and
`src/libraries/CommitmentRefs.sol` were not created.

Two changes touch files outside `src/StandbyHook.sol`, both explicitly permitted by the prompt's file
boundary: the canonical deployment path and its tests were updated to bind the new Hook-wide trust
dependencies, and `docs/setup.md` records the deployment environment variables that change introduced,
as `CLAUDE.md` requires for setup changes.

The F1 two-pool sequencing model is unchanged, and no production code reads `StandbyFixtureConfig`.

### Proposed Gate Assessment

**PASS (proposed).**

G3-H is fully satisfied by integration evidence on the Hook produced by the canonical deployment
procedure, with no harness involvement.

G3-C is satisfied for every listed boundary. Fourteen of the fifteen admission boundaries, the positive
activation, the read fidelity, the immutability, and the authority-separation requirements are proved by
integration and fuzz evidence against real Uniswap v4 state. The fifteenth, the zero-liquidity guard, is
proved with the declared harness isolation described above, because F3 has no production path that can
put liquidity into a StandbyHook-bound pool. If the reviewer judges that G3-C 5 requires evidence with no
harness at all, that condition cannot be satisfied before F6A implements liquidity admission, and the
assessment becomes PARTIAL on that single item.

This is a proposed assessment only. G3 is not closed.

### Recommended Next Step

Submit F3 for gate review. If G3 closes, the smallest coherent next responsibility is F4 — commitment
storage and the bounded enforcement-reference structure — and `docs/project-status.md` should be
synchronized to record G3 closed and F4 authorized at that point. F4 is not started and is not
authorized by this session.

### Prompt Audit

All material follow-up instructions were recorded in this log. **0 material follow-up prompts** were
recorded: the session ran end to end from the initiating prompt with no follow-up instruction that
changed scope, made an implementation decision, selected between alternatives, changed a verification
requirement, resolved a blocker, authorized deferred work, or rejected a proposed approach.
