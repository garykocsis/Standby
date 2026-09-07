# Session 08 — Material Prompt Log

Initiating prompt: `docs/prompts/session-08-f6a-preliminary-o3-enforcement.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

_None. The session was executed from the initiating prompt with no material follow-up instructions._

---

# Required Task Completion Report — F6A Preliminary O3 Enforcement with O = 0

## Files Inspected

**Operating and governing artifacts**

- `CLAUDE.md`
- `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/implementation-plan.md` §11 (F6A / G6A), §10.12–10.15 (F5 boundary), §12 (F7 boundary)
- `docs/uniswap-v4-realization.md` §5 (RR-SC-6, RR-TOPO-1, RR-TOPO-2), §8 (RR-PERM-4, RR-PERM-4A,
  RR-PERM-5 – RR-PERM-8R), §17 (O3), §18 (enforcement surface), §19–20 (RR-CTRL-\*, RR-PATH-1, RR-PATH-6),
  §22 (failure atomicity), §23 (positive permissiveness), §26.2–26.3 (O3 and permission verification)
- `docs/spec.md` §3.3 (O3), §4.3 (SPEC-B10), §6.1 (SPEC-A)
- `docs/testing-strategy.md` §4.3 (O3-V1 – O3-V8)
- `docs/prompts/session-07-log.md` (log format)

**Repository source**

- `src/StandbyHook.sol`, `src/EligibilityRegistry.sol`, `src/interfaces/IEligibilityRegistry.sol`
- `src/libraries/StandbyMath.sol`, `src/libraries/ServiceDomain.sol`, `src/libraries/CommitmentRefs.sol`
- `src/mocks/MockFixtureCurrency.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/StandbyFixtureConfig.sol`,
  `script/helpers/DeterministicFixtureDeployer.sol`
- `test/shared/BaseStandbyServiceTest.t.sol`, `test/shared/BaseDerivationTest.t.sol`,
  `test/shared/BaseV4Test.t.sol`
- `test/harness/StandbyHookHarness.sol`, `test/harness/StandbyDerivationHarness.sol`,
  `test/harness/LiquidityPermissiveStandbyHookHarness.sol`
- `test/unit/StandbyServiceLiquidityPrecondition.t.sol`, `test/unit/CommitmentStorage.t.sol`,
  `test/integration/StandbyHookDeployment.t.sol`, `test/integration/DeterministicEconomicFixture.t.sol`

**Pinned dependency source**

- `v4-hooks-public/src/base/BaseHook.sol` — callback override signatures and `onlyPoolManager`
- `v4-periphery/src/base/ImmutableState.sol` — the immutable PoolManager binding and `NotPoolManager`
- `v4-core/PoolManager.sol` — `unlock`, `swap`, `modifyLiquidity`, delta accounting to the locker
- `v4-core/libraries/Hooks.sol` — `beforeModifyLiquidity` dispatch (`liquidityDelta <= 0` routes to
  `beforeRemoveLiquidity`), `callHook` failure wrapping
- `v4-core/libraries/CustomRevert.sol` — `WrappedError` bubbling used by every rejection assertion
- `v4-core/libraries/Position.sol` — zero-delta ("poke") semantics on an existing position
- `v4-core/test/PoolSwapTest.sol`, `v4-core/test/PoolModifyLiquidityTest.sol` — settlement pattern
- `v4-core/test/utils/CurrencySettler.sol` — `sync` / `transferFrom` / `settle` and `take` sequence
- `v4-core/interfaces/callback/IUnlockCallback.sol`, `v4-core/interfaces/external/IERC20Minimal.sol`

## Files Changed

**Production (created)**

- `src/interfaces/IActorAwarePeriphery.sol` — the minimal actor-attribution surface. One function,
  `msgSender()`, carrying provenance and transport responsibility only. It attests no eligibility, no pool
  identity, no capacity, no obligation, no classification, and no transition safety.
- `src/demo/ActorAwareTestRouter.sol` — the deterministic-local / demo execution perimeter that preserves
  originating-user identity across the v4 unlock boundary. It binds the direct caller of its routed entry
  point in transient storage for the duration of one routed action, rejects a nested routed action, fails
  closed when no action is in flight, performs the pool operation through the real PoolManager, and settles
  the resulting deltas against the originating actor.

**Production (modified)**

- `src/StandbyHook.sol` — ordinary O3 enforcement across the four enabled callbacks, seven new custom
  errors, and updated contract documentation. No new storage variable, no new economic derivation, no new
  external function.

**Tests / evidence (created)**

- `test/shared/BaseActorAwareStandbyTest.t.sol` — the shared F6A fixture.
- `test/periphery/ActorAttribution.t.sol` — trusted-perimeter attribution evidence.
- `test/integration/O3SwapEnforcement.t.sol` — ordinary swap enforcement evidence.
- `test/integration/O3LiquidityEnforcement.t.sol` — liquidity add/remove enforcement evidence.
- `test/fuzz/O3SwapFuzz.t.sol`, `test/fuzz/O3LiquidityFuzz.t.sol` — behavioral transition fuzz.

**Tests (modified — consequence of F6A, outside the prompt's listed test scope)**

Three existing tests asserted that the enabled callbacks fail closed with `BaseHook.HookNotImplemented`.
That assertion is exactly what F6A replaces, and the F0 test's own documentation anticipated that "the
later enforcement slices are expected to replace this `HookNotImplemented` revert with authoritative
behavior and to retire this test". Each was updated to assert the requirement it was actually protecting
rather than deleted or weakened:

- `test/integration/StandbyHookDeployment.t.sol` — now proves a deployed but unconfigured Hook admits no
  pool transition (`StandbyHook__ServiceNotConfigured`), still called as the PoolManager.
- `test/unit/CommitmentStorage.t.sol` — now proves commitment storage created no transition path into an
  unconfigured Hook, across all three admission callbacks. `afterSwap` was removed from that list, because
  it is F6A-owned inert completion plumbing and its inertness is evidenced in the F6A suites.
- `test/integration/DeterministicEconomicFixture.t.sol` — the F1 pre-activation liquidity refusal now
  expects `StandbyHook__ServiceNotConfigured` inside the same `WrappedError`; the stale contract-level
  comment was corrected.

**Documentation**

- `docs/prompts/session-08-log.md` — created (this file).
- `docs/project-status.md` — synchronized to record F6A as the authorized, in-progress slice with G6A open
  and awaiting review. It does **not** record F6A complete or G6A closed. `docs/setup.md` needed no change:
  no dependency, remapping, compiler, EVM, environment, or fresh-clone setup behavior changed, and both
  `src/demo/` and `test/periphery/` are already in its planned tree.

## Requirements Implemented

- **RR-PATH-1** — only the immutable PoolManager may invoke an enabled callback (inherited from
  `BaseHook.onlyPoolManager`, now actually reachable and tested).
- **RR-PERM-4 / RR-PERM-4A** — the economic participant is never inferred from the raw callback sender or
  from hook data. The callback sender must be the configured perimeter for that transition family, and only
  then is its authenticated originator consulted.
- **RR-PERM-6** — trader and liquidity-action eligibility remain distinct permission domains, checked on
  their own transitions.
- **RR-PERM-7 / RR-PERM-8R** — liquidity-action eligibility gates the authenticated actor who introduces or
  increases liquidity. Reduction, full withdrawal, and neutral zero-delta fee collection require no
  continuing eligibility.
- **RR-SC-6 / RR-TOPO-2** — the closed service domain and the interior-boundary prohibition are enforced on
  every ordinary transition, independently of the current obligation.
- **RR-SC-7 / RR-O3-1 / RR-O3-2** — backing is evaluated from deterministically derived prospective state
  before the transition becomes authoritative; ordinary swaps keep caller-selected price limits, but their
  reachable path must stay inside the configured domain.
- **SPEC-B10** — an O3 transition may become authoritative only when its resulting condition preserves the
  backing relationship whose Supporting Capacity that transition can change.
- **RR-CONFIG-6 / RR-SETUP-3** — enforcement is live from activation, and an unconfigured Hook admits
  nothing.
- **RR-18.2 / §17.6** — a zero liquidity delta is classified by its actual effect (`L' = L`, `S' = S`), not
  by which callback Uniswap dispatched it to.
- **G6A-1 through G6A-12** — see Gate Evidence.

## Implementation Decisions

**1. The backing comparison is applied to every ordinary swap, not only to the protected direction.**

Session prompt §9.2 says not to "manufacture redundant backing arithmetic merely for symmetry" for the
opposite direction, and lists domain validity rather than `S' >= O` for it. The implementation applies one
derivation and one comparison to both directions, for a reason that is upstream of the prompt:

- `spec.md` SPEC-B10 requires preservation for every backing relationship "whose Supporting Capacity **can
  be changed** by that transition", and O3-V7 requires effect-complete rather than expected-path
  enforcement.
- An opposite-direction swap normally increases capacity, but not always: the closed-domain topology
  permits a liquidity endpoint exactly on a service boundary, and a swap reaching that boundary crosses the
  tick and leaves less active liquidity behind. That is a capacity-reducing opposite-direction path.

No second formula was introduced — the same `_prospectiveSwapState` → `_prospectiveSupportingCapacity` →
`_aggregateObligation` path serves both directions — so the prohibition on redundant arithmetic is
respected. At F6A the comparison can never reject anything, since the derived obligation is zero, so this
choice removes no permitted behavior. Recorded here as an interpretation decision for gate review.

**2. Actor-scoped position custody in the demo perimeter.**

Uniswap credits a position to the account calling `modifyLiquidity`, which for a routed action is the
perimeter, not the user. Sharing one perimeter across actors would therefore let any actor withdraw
another's liquidity. The perimeter derives the PoolManager position salt as
`keccak256(actor, callerSuppliedSalt)`. This is position custody only: Standby never reads the salt, and no
Standby economic decision changes because of it. It is noted because it is the one respect in which the
parameters the pool sees differ from the parameters the user submitted.

**3. Transient storage for actor attribution.**

Cancun is the validated EVM baseline, so the originator is held in transient storage via `tstore`/`tload`
and cleared at the end of each routed action. No reusable identity survives the transaction.

**4. Production callbacks are `virtual`.**

`StandbyDerivationHarness` and `LiquidityPermissiveStandbyHookHarness` override these callbacks for F5 and
F3 evidence that cannot otherwise be reached (a Hook-bound pool with liquidity added *before* activation,
and generalized non-canonical services). Marking the production callbacks `virtual override` keeps that
evidence intact. Deployment mines and deploys `type(StandbyHook).creationCode`, so nothing deployed is
affected.

**5. `beforeRemoveLiquidity` recovers no originating user.**

No eligibility predicate consumes one there. Recovering an actor anyway would imply an authorization
question that does not exist. The trusted liquidity perimeter is still authenticated.

## Tests Added or Changed

**`test/shared/BaseActorAwareStandbyTest.t.sol`** — the shared F6A fixture. Real pinned `PoolManager`, two
separately deployed `ActorAwareTestRouter` instances of identical bytecode as the two distinct trusted
perimeters, the canonical `DeployStandbyHook` procedure, the F1 deterministic ordered currencies, the F2
registry under its own administrator, a real `initialize`, the production `configureAndActivate`, and the
canonical liquidity added through the production `beforeAddLiquidity` enforcement path by an eligible
provider. Nothing is seeded: no capacity, no obligation, no commitment, no reference, no Hook storage, no
manufactured pool state, no faked actor context. No harness is used anywhere in the F6A evidence.

**`test/periphery/ActorAttribution.t.sol`** (11 tests) — proves the Hook queries eligibility for the exact
originating user (`vm.expectCall` on the registry) on both the swap and the liquidity path; that attribution
distinguishes users rather than authorizing the perimeter (making the perimeter itself eligible changes
nothing); that an untrusted contract implementing the same interface and naming a genuinely eligible actor
is refused on perimeter identity, with its attribution function never called; that forged `hookData` cannot
displace the authenticated actor; that each perimeter authorizes only its own transition family; that a
trusted perimeter exposes no actor outside a routed action and none afterwards; and that a nested routed
action is rejected.

**`test/integration/O3SwapEnforcement.t.sol`** (14 tests) — positive: eligible protected-direction and
opposite-direction swaps become authoritative, post-state capacity equals the pre-transition F5 prediction,
and a swap that lands exactly on `P_Q` with `S = 0` is permitted. Negative: ineligible trader, revoked
trader, untrusted perimeter, fabricated direct callback, forged `hookData`, a pool that is not the
configured service, and both directions leaving the service domain while the obligation is zero. Each
rejection is matched to its specific Standby reason and followed by a proof that authoritative PoolManager
state is unchanged. `afterSwap` is shown to complete with a zero delta and to leave no commitment, no
reference, no obligation.

**`test/integration/O3LiquidityEnforcement.t.sol`** (16 tests) — positive: eligible topology-valid addition,
a position whose endpoints sit exactly on the service boundaries, a harmless position entirely outside the
domain, a valid removal, an exit after eligibility revocation, and a zero-delta operation after revocation.
Negative: ineligible provider, an eligible *trader* without liquidity eligibility, interior lower and upper
boundaries, an untrusted perimeter, fabricated direct callbacks, and a non-service pool. Prediction/actual
agreement is proven for both an active and an inactive removal.

**`test/fuzz/O3SwapFuzz.t.sol`** (4 properties) — over both directions, both exact-input and exact-output
forms, amounts from dust to more than the domain can absorb, and arbitrary hook payloads: an ineligible
trader never produces an authoritative swap; an untrusted perimeter never does; an accepted swap leaves
exactly the predicted capacity and a price inside the closed domain; a domain-leaving swap never becomes
authoritative while the obligation is zero.

**`test/fuzz/O3LiquidityFuzz.t.sol`** (2 properties) — an addition becomes authoritative exactly when the
actor is eligible and the position introduces no interior boundary, judged against a topology oracle
restated independently of the production classifier, with the resulting active liquidity checked against
the v4 active-range convention; and a removal executes and matches the prospective derivation regardless of
whether eligibility was revoked between contribution and exit.

**Modified tests** — as described under Files Changed. No assertion was removed without replacing it with
the requirement it was protecting.

## Commands Run

```bash
git status
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test --match-path test/integration/O3SwapEnforcement.t.sol
forge test --match-path test/integration/O3LiquidityEnforcement.t.sol
forge test --match-path test/periphery/ActorAttribution.t.sol
forge test --match-path test/fuzz/O3SwapFuzz.t.sol
forge test --match-path test/fuzz/O3LiquidityFuzz.t.sol
forge test
FOUNDRY_PROFILE=ci forge test
```

## Results

- `forge fmt --check` — clean.
- `forge build --sizes` — compiles with no warnings and no lint findings.
- `forge test` — **317 passed, 0 failed, 0 skipped** across 29 suites (270 before this session; 47 new
  tests).
- `FOUNDRY_PROFILE=ci forge test` — **317 passed, 0 failed, 0 skipped** at 10,000 fuzz runs.

Focused F6A suites: `ActorAttribution` 11/11, `O3SwapEnforcement` 14/14, `O3LiquidityEnforcement` 16/16,
`O3SwapFuzz` 4/4, `O3LiquidityFuzz` 2/2.

## Gate Evidence

| G6A requirement                                            | Evidence                                                                                                                                                                                                        | Status   |
| ---------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| 1. Only immutable PoolManager callbacks are authoritative  | `test_directCallbackInvocation_isRejected`, `test_directLiquidityCallbackInvocation_isRejected`, `test_enabledCallbacks_failClosedWithoutAConfiguredService`                                                       | VERIFIED |
| 2. Only trusted periphery can supply an authenticated actor | `test_untrustedAttestor_cannotEstablishAnEconomicActor`, `test_ordinarySwap_throughAnUntrustedPerimeter_cannotAuthorize`, `test_liquidityAddition_throughAnUntrustedPerimeter_cannotAuthorize`, both fuzz suites | VERIFIED |
| 3. Forged `hookData` cannot establish an actor             | `test_forgedHookData_cannotDisplaceTheAuthenticatedActor`, `test_forgedHookData_cannotEstablishTheActor`, arbitrary payloads in `O3SwapFuzz`                                                                       | VERIFIED |
| 4. Ordinary swap requires `canSwap`                        | `test_protectedDirectionSwap_byIneligibleTrader_isRejected` plus its same-actor-once-eligible counterpart, revocation test, `testFuzz_ineligibleTrader_neverProducesAnAuthoritativeSwap`                            | VERIFIED |
| 5. Liquidity addition requires `canProvideLiquidity`       | `test_liquidityAddition_byIneligibleProvider_isRejected`, same-actor-once-eligible counterpart, trader-is-not-a-provider test, `testFuzz_liquidityAddition_isAdmittedExactlyWhenEligibleAndTopologyValid`           | VERIFIED |
| 6. Removal does not require continuing eligibility         | `test_liquidityRemoval_afterEligibilityIsRevoked_stillExecutes`, `test_zeroDeltaLiquidityOperation_afterEligibilityIsRevoked_isPermitted`, `testFuzz_liquidityRemoval_isIndependentOfCurrentEligibility`           | VERIFIED |
| 7. Direction classification is correct                     | protected and opposite swaps produce opposite price movement and opposite capacity effects; the capacity boundary is direction-relative; both directions fuzzed                                                    | VERIFIED |
| 8. Opposite-direction domain enforcement at `O = 0`        | `test_oppositeDirectionSwap_leavingTheServiceDomain_isRejectedWhileObligationIsZero` (obligation asserted zero in the same test), `testFuzz_domainLeavingSwap_neverBecomesAuthoritative`                            | VERIFIED |
| 9. Topology enforcement at `O = 0`                         | interior lower/upper boundary rejections with the obligation asserted zero, boundary-endpoint and outside-domain positions positively permitted, liquidity fuzz                                                    | VERIFIED |
| 10. F5 prospective derivations are consumed                | structural review below, plus pre-transition prediction equalling authoritative post-transition capacity for swaps, active removals, and inactive removals, in both integration and fuzz                           | VERIFIED |
| 11. Valid transitions are positively permitted             | both swap directions, the exact-boundary `S = 0` swap, four distinct valid liquidity topologies, valid removal, post-revocation exit, zero-delta collection                                                        | VERIFIED |
| 12. Integration and fuzz evidence passes                   | 317/317 under both the default and `ci` profiles                                                                                                                                                                  | VERIFIED |

**Production-derivation singularity review (prompt §35).** The F6A production diff introduces no formula
for Supporting Capacity, prospective Supporting Capacity, Aggregate Capacity Obligation, prospective swap
state, or prospective liquidity-removal state. `beforeSwap` consumes `_prospectiveSwapState`;
`beforeRemoveLiquidity` consumes `_prospectiveLiquidityRemovalState` (and `_currentPoolState` for a
zero delta, whose prospective state *is* the present state); the backing decision consumes
`_prospectiveSupportingCapacity` and `_aggregateObligation`. A repository-wide scan for
`SqrtPriceMath`/`getAmountXDelta`/`computeSwapStep`/capacity/obligation identifiers outside
`StandbyHook.sol` and `StandbyMath.sol` returns only `ServiceDomain`'s traversal-demand topology helper and
its documentation. The one duplicated rule is the topology oracle in `O3LiquidityFuzz.t.sol`, which is a
verification-only restatement on the test side, as required.

**Semantic minimality review (prompt §36).** No new production storage variable (verified by diff), no
commitment creation, no admission path, no positive obligation, no O2 authorization, causal context,
execution evidence, settlement, delivery, fulfillment, or Remaining Entitlement mutation, no administrative
release, no pause or deactivation, and no derived economic storage. `afterSwap` returns its selector and a
zero delta and touches nothing. `hook.nextCommitmentId()` is still 1 and every enforcement-reference slot is
still empty after a completed ordinary swap.

**Still unverified at F6A (by design).** Backing enforcement under a positive obligation is not exercised,
because no authentic commitment can exist. `StandbyHook__InsufficientProspectiveBacking` is implemented and
structurally reachable but cannot fire in any currently reachable state; it is F6B's evidence, and
fabricating an obligation to reach it is explicitly forbidden. Stateful invariant campaigns (GI) and
canonical acceptance (F9) remain out of scope.

## Known Limitations / Blockers

- No blockers. No frozen-document contradiction was found.
- `StandbyHook__InsufficientProspectiveBacking` is unreachable while `O = 0`, so the rejection side of the
  backing comparison has no behavioral evidence yet. This is the expected F6A/F6B boundary.
- `ActorAwareTestRouter` supports exact-transfer ERC-20 currencies only. Native currency is not supported
  and fails rather than being approximated. It is demo/deterministic-local periphery, not a production
  Universal Router or PositionManager; the production perimeters are addresses configured at deployment.
- The demo perimeter scopes position custody by actor (see Implementation Decisions 2). A real
  PositionManager provides custody through position NFTs instead.
- Carried forward from F0: `HelperConfig` resolves infrastructure only for chain id `31337`, and the
  broadcasting `run()` path is verified in script simulation rather than against a live node.

## Scope Check

Work remained within the authorized F6A slice. The authorized production files
(`src/StandbyHook.sol`, `src/demo/ActorAwareTestRouter.sol`, plus the explicitly permitted
`src/interfaces/IActorAwarePeriphery.sol`) and the six authorized test files were the intended footprint.

Out of the prompt's listed test scope, required by the change and reported explicitly:

- three existing tests that asserted the now-replaced `HookNotImplemented` fail-closed behavior were updated
  to assert the requirement they were actually protecting (see Files Changed). Leaving them failing, or
  deleting them, were both worse options;
- the four production callbacks were marked `virtual` so the existing F3 and F5 harnesses continue to
  compile and their gate evidence survives;
- `docs/project-status.md` was synchronized to record F6A as authorized and in progress with G6A open, as
  `CLAUDE.md` requires when a new slice is explicitly authorized. It does not claim F6A complete or G6A
  closed.

No F7, F6B, F8A, F8B, F8C, F8D, GI, F9, or F10 behavior was implemented, and no placeholder tests for those
slices were created.

## Proposed Gate Assessment

**G6A: PASS PROPOSED.**

All twelve G6A obligations have implementation and passing verification evidence produced through real
deployment, real configuration, real production transitions, and the real pinned Uniswap v4 execution stack,
with no harness anywhere in the F6A evidence path. Both boundary sides are covered: valid transitions are
positively permitted, including the permissiveness cases the frozen semantics require, and forbidden
transitions are rejected with attributable Standby reasons and no authoritative residue.

This is a proposed assessment only. G6A is not closed, and F7, F6B, and the F8 slices remain unauthorized.

## Recommended Next Step

External G6A review of the F6A ordinary-transition enforcement perimeter.

If G6A closes, the smallest coherent next responsibility is **F7 — O1 Commitment Admission**, which creates
the first authentic binding obligation and is the precondition for F6B proving the backing rule under a
positive `O`. Not started, and not to be started without explicit authorization.

## Prompt Audit

The session was initiated from `docs/prompts/session-08-f6a-preliminary-o3-enforcement.md`. **Zero material
follow-up instructions** were issued, and zero are recorded above.
