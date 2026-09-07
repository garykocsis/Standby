# Session 07 — Material Prompt Log

Initiating prompt: `docs/prompts/session-07-f5-authoritative-deriviation-kernal.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

_None. The session was executed from the initiating prompt with no material follow-up instructions._

---

# Required Task Completion Report — F5 Authoritative Derivation Kernel

## Files Inspected

**Operating and governing artifacts**

- `CLAUDE.md`
- `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/implementation-plan.md` §10 (F5), §9.4–9.6 (F4/F5 boundary), §11 (F6A boundary)
- `docs/uniswap-v4-realization.md` §5 (service domain / topology), §6 (RR-SC-1, RR-SC-2, RR-SC-4),
  §7 (RR-SC-7 – RR-SC-10), §8 (RR-PERM-2), §9 (persistent vs derived state), §17 (O3 classification)
- `docs/spec.md` §2.3 (E1–E7), §2.4–2.8
- `docs/invariants.md` INV-05
- `docs/testing-strategy.md` (derivation-equivalence requirements)
- `docs/prompts/session-06-log.md` (log format)

**Repository source**

- `src/StandbyHook.sol`, `src/libraries/CommitmentRefs.sol`, `src/EligibilityRegistry.sol`,
  `src/interfaces/IEligibilityRegistry.sol`, `src/mocks/MockFixtureCurrency.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/StandbyFixtureConfig.sol`,
  `script/helpers/DeterministicFixtureDeployer.sol`
- `test/shared/ReferenceCalculations.sol`, `test/shared/BaseStandbyServiceTest.t.sol`,
  `test/shared/BaseCommitmentStorageTest.t.sol`, `test/shared/BaseV4Test.t.sol`
- `test/harness/StandbyHookHarness.sol`, `test/harness/LiquidityPermissiveStandbyHookHarness.sol`
- `test/unit/CommitmentStorage.t.sol`, `test/integration/DeterministicEconomicFixture.t.sol`

**Pinned dependency source**

- `v4-core/libraries/SqrtPriceMath.sol` — exact `getAmount0Delta` / `getAmount1Delta` semantics and rounding
- `v4-core/libraries/SwapMath.sol` — `computeSwapStep`, `getSqrtPriceTarget`
- `v4-core/libraries/Pool.sol` — the authoritative `swap` loop and the `modifyLiquidity` active-range rule
- `v4-core/libraries/TickBitmap.sol` — `compress`, `position`, `nextInitializedTickWithinOneWord`
- `v4-core/libraries/StateLibrary.sol` — `getSlot0`, `getLiquidity`, `getTickBitmap`, `getTickLiquidity`
- `v4-core/libraries/ProtocolFeeLibrary.sol`, `LiquidityMath.sol`, `BitMath.sol`, `SafeCast.sol`
- `v4-hooks-public/src/base/BaseHook.sol` — callback override signatures

## Files Changed

**Production (created)**

- `src/libraries/StandbyMath.sol` — the pure Standby derivation kernel: temporal validity, temporal
  exercise qualification, permanent non-binding classification, per-commitment Capacity Obligation, the
  Supporting Capacity formula, the v4 active-range predicate, the post-removal liquidity derivation, and
  the pure half of the v4 swap-step traversal.
- `src/libraries/ServiceDomain.sol` — pure service-domain geometry and topology: direction-consistent
  boundary ordering, numeric and square-root bounds, closed-domain containment, and the
  interior-liquidity-boundary classification.

**Production (modified)**

- `src/StandbyHook.sol` — composition of the derivation kernel and the frozen minimum read surface.
  Added: the three authoritative reads (`supportingCapacity`, `aggregateObligation`,
  `commitmentObligation`), two read-only prospective previews, the internal derivation composition
  (`_currentPoolState`, `_supportingCapacity`, `_prospectiveSupportingCapacity`,
  `_supportingCapacityFromState`, `_commitmentObligation`, `_aggregateObligation`,
  `_prospectiveSwapState` with `_beginSwapDerivation` / `_advanceSwapDerivation`,
  `_prospectiveLiquidityRemovalState`, `_nextSwapTargetTick`, `_requireSupportedSwapPriceLimit`,
  `_serviceId`), four new errors, and the `MAX_PROSPECTIVE_SWAP_STEPS` bounded-execution constant.
  Refactored: `_validateServiceDomain` now consumes `ServiceDomain` instead of restating the geometry,
  and `serviceId()` consumes the new internal `_serviceId`. No new storage.

**Verification (created)**

- `test/harness/StandbyDerivationHarness.sol` — exposes the internal prospective derivations and admits
  the four enabled callbacks so real v4 execution can occur against a Hook-bound pool.
- `test/shared/BaseDerivationTest.t.sol` — parameterized real-path fixture that builds arbitrary Standby
  service configurations through real deployment, real `initialize`, the production
  `configureAndActivate`, and the official pinned liquidity/swap routers; plus a test currency with a
  configurable decimal precision.
- `test/unit/SupportingCapacity.t.sol`, `test/unit/AggregateObligation.t.sol`,
  `test/unit/CommitmentDerivation.t.sol`, `test/unit/ServiceDomain.t.sol`
- `test/fuzz/SupportingCapacityFuzz.t.sol`, `test/fuzz/AggregateObligationFuzz.t.sol`,
  `test/fuzz/CommitmentDerivationFuzz.t.sol`, `test/fuzz/ServiceDomainFuzz.t.sol`
- `test/integration/ProspectiveStateEquivalence.t.sol` — G5-B differential evidence against real v4.
- `test/integration/DerivationGeneralization.t.sol` — G5-C fixture, direction, and decimal
  generalization, plus canonical fixture economics.

**Verification (modified)**

- `test/shared/ReferenceCalculations.sol` — extended into a full independent oracle: validity, temporal
  qualification, permanent release, per-commitment obligation, aggregate obligation, both directional
  capacity derivations, a round-up counterpart used to show the rounding convention is load-bearing, and
  the two domain classifications. Nothing here calls `StandbyMath` or `ServiceDomain`.
- `test/unit/CommitmentStorage.t.sol` — the F4 assertion that *no* derived economic read exists is
  superseded by F5's frozen minimum read surface. Narrowed to the commitment lifecycle projection that
  remains forbidden (`isValid`, `isExercisable`, `isBinding`, `isReclaimable`, `isLive`, `status`,
  `availableCapacity`) and renamed accordingly. No other assertion was weakened or removed.

**Documentation**

- `docs/prompts/session-07-log.md` — this artifact.
- `docs/project-status.md` — status-bearing fields only, recording F5 as in progress and G5 as open.
  It does not claim F5 complete and does not close G5.

## Requirements Implemented

- Temporal validity `t < validUntil`; temporal exercise qualification `exercisableFrom <= t < validUntil`
  (implementation-plan §10.3, spec E2/E3).
- Permanent non-binding classification `R == 0 || t >= validUntil`, as the single shared predicate behind
  both zero obligation and the reclaimability basis F7 will consume (§12 of the session prompt,
  implementation-plan §9.4).
- Per-commitment Capacity Obligation and Aggregate Capacity Obligation over the bounded enforcement
  index (implementation-plan §10.3, spec E5/E6, INV-05).
- Current Supporting Capacity from exact Slot0 `sqrtPriceX96` and current active liquidity
  (RR-SC-1, RR-SC-4, spec E7), in raw protected-output units with round-down convention.
- Service-domain and topology classification (RR-SC-3, RR-SC-5, RR-SC-6), now singly owned.
- Prospective v4 state and prospective Supporting Capacity for swaps and liquidity removals
  (RR-SC-7, RR-SC-8, RR-SC-9), derived by reproducing the supported v4 transition and then reusing the
  same capacity kernel.
- The frozen minimum production read surface, plus read-only prospective previews that expose the
  authoritative derivations without introducing semantics of their own (implementation-plan §10.7).
- No new economically authoritative persistent state (implementation-plan §10.1, RR-STATE minimality).

## Tests Added or Changed

**Unit**

- `ServiceDomain.t.sol` (14) — direction-consistent ordering in both directions and its rejection of a
  degenerate domain; numeric and square-root bounds; closed containment including one-unit exclusion just
  outside each boundary; interior-boundary classification including endpoints exactly on the boundaries;
  equality with the independent reference.
- `CommitmentDerivation.t.sol` (14) — the complete frozen temporal/entitlement matrix at
  `t < exercisableFrom`, `t == exercisableFrom`, mid-window, `t == validUntil - 1`, `t == validUntil`,
  `t > validUntil`, each for positive and zero remainder; binding before the window opens; expiry
  zeroing obligation without rewriting Remaining Entitlement; exhaustion before expiry; Beneficiary
  eligibility toggles and caller identity leaving obligation unchanged; rejection of an unallocated
  identity; and the reads answering on the production Hook.
- `AggregateObligation.t.sol` (12) — empty index; one and several binding commitments; future-window
  commitments contributing; expired and exhausted stale references contributing zero with no expiry
  transaction; a mixed index; a fully occupied index; slot-order independence across two independent
  Hooks; an occupied high slot with empty low slots; derived-not-cached behavior; eligibility
  independence.
- `SupportingCapacity.t.sol` (12) — interior equivalence with the independent reference in both
  directions; that the two directions measure different currencies away from parity and the parity
  coincidence; monotonic decrease toward `P_Q`; exactly zero at `P_Q`; positive at `P_O`; zero without
  liquidity; the round-down convention where the conventions differ by one; refusal beyond `P_Q`; and
  refusal to manufacture capacity by reversing the square-root arguments.

**Fuzz** (1,000 runs default / 10,000 CI, deterministic seed `0x1`)

- `CommitmentDerivationFuzz.t.sol` (10) — unconstrained equivalence with the reference for all four
  commitment derivations; obligation is all-or-nothing; positive obligation implies validity and a
  positive remainder; release coincides with zero obligation and is monotone in time; qualification
  implies validity; binding and temporal qualification are distinct in the region where they disagree.
- `SupportingCapacityFuzz.t.sol` (6) — equivalence with the reference in both directions across domains
  up to 400,000 ticks wide, prices generated in square-root space rather than on tick boundaries, and
  liquidity up to `2^100`; zero at `P_Q` for any liquidity; zero without liquidity; monotonicity in
  liquidity; and a check that the generator itself only produces valid, direction-consistent bases.
- `AggregateObligationFuzz.t.sol` (4) — equivalence with the reference over fuzzer-scattered slots;
  unreferenced commitments never contributing; the aggregate never exceeding the referenced remainders;
  full release after the last expiry.
- `ServiceDomainFuzz.t.sol` (6) — containment and interior classification equivalence over the full tick
  and square-root ranges; closedness; exactly one direction accepting an ordered pair; order-independent
  bounds; enclosing positions never flagged.

**Integration**

- `ProspectiveStateEquivalence.t.sol` (17) — for exact-input, exact-output, opposite-direction, and
  word-edge-crossing swaps: predict, execute against the real pinned PoolManager, and require the
  predicted price, predicted active liquidity, and predicted `S'` to equal what the pool actually
  produced. Plus: a swap stopping exactly at `P_Q` with capacity exactly zero; a zero-amount swap; the
  derivation mutating nothing; active, inactive, and full active liquidity removals; refusal of a
  predicted state outside the domain; refusal of a price limit v4 itself rejects; refusal of a non-
  removal; and the bounded-traversal behavior on a spacing-1 service wide enough to exceed the step
  bound.
- `DerivationGeneralization.t.sol` (13) — the canonical fixture deriving exactly 80,000.000000 raw
  protected-output units against an independently restated constant and the independent oracle; the
  authoritative activated service basis; equivalence with the reference across three independently
  configured services; proof the three configurations genuinely differ; capacity denominated in the
  currency the protected direction selects; exact Slot0 price sourcing shown to differ from a
  tick-reconstructed price; the read and the kernel being one derivation; refusal of a present state
  outside the domain; positive capacity at `P_O`; refusal before a service exists; and a matched pair of
  services differing only in decimal precision deriving identical raw answers.

## Commands Run

```bash
git status
forge fmt
forge fmt --check
forge build
forge build --sizes
forge test --match-path <each new suite> -vv
forge test
FOUNDRY_PROFILE=ci forge test
grep -rn "getAmount0Delta\|getAmount1Delta" src/
grep -rn "validUntil\|remainingEntitlement" src/
grep -rn "containsPrice\|isDirectionConsistent\|sqrtBounds\|introducesInteriorBoundary" src/
grep -rn "ReferenceCalculations" src/ script/
grep -rn "decimals" src/ script/
```

## Results

- `forge fmt --check` — clean.
- `forge build` — successful, no warnings.
- `forge build --sizes` — `StandbyHook` runtime 14,863 bytes, 9,713 bytes of margin.
- `forge test` — **248 passed, 0 failed, 0 skipped** across 24 suites.
- `FOUNDRY_PROFILE=ci forge test` — **248 passed, 0 failed, 0 skipped** at 10,000 fuzz runs.
- Structural greps — the capacity primitives appear in production exactly twice, both inside
  `StandbyMath.supportingCapacity`; the commitment temporal and entitlement comparisons appear only
  inside `StandbyMath`; the Hook's two obligation paths both call `StandbyMath.commitmentObligation`;
  every domain classification resolves through `ServiceDomain`; `ReferenceCalculations` is not imported
  by any production or script source; and no production or script source consults `decimals()`.

## Gate Evidence

**Implemented and verified**

- **G5-A — normative derivation equivalence.** Validity, temporal exercise qualification, permanent
  non-binding classification, per-commitment obligation, Aggregate O, current Supporting Capacity, and
  service-domain/topology classification each equal an independently composed reference, under both
  deterministic unit cases and fuzzed inputs. The oracle never calls the production helper it verifies.
- **G5-B — prospective-state equivalence against real v4.** For every supported prospective transition
  the predicted `sqrtPriceX96`, predicted active liquidity, and predicted `S'` equal what the real pinned
  PoolManager produced for the same transition. The word-edge test additionally shows that a single-step
  model is measurably inexact on exactly the state where the production derivation is exact, so the
  faithful step traversal is demonstrated to be load-bearing rather than assumed.
- **G5-C — fixture and decimal generalization.** Three independently configured real services covering
  both protected directions, three decimal pairings (6/6, 18/8, 8/18), two tick spacings, three fees,
  three tick layouts, two liquidity magnitudes, and both enclosing and boundary-aligned liquidity
  positions. A matched pair differing only in decimal precision derives identical raw answers.
- **G5-D — production derivation singularity.** Each F5 quantity has exactly one production expression,
  confirmed by inspection and by the greps above. The F5 refactor also removed a pre-existing duplicate:
  `configureAndActivate`'s domain geometry now resolves through `ServiceDomain` rather than restating
  ordering and containment inline.
- **G5-E — semantic minimality.** No commitment establishment, no exercise authorization, no causal
  context, no execution, no settlement, no delivery, no Remaining Entitlement mutation, no callback
  authorization or rejection, no participant authentication, no eligibility mutation, no administrative
  release, and no pause. The four enabled production callbacks still fail closed with
  `HookNotImplemented`, proved by the existing deployment and storage suites. No new storage variable
  was introduced and no derived economic quantity is persisted.
- **G5-F — invalid-basis and boundary correctness.** A valid state with `S == 0` at `P_Q` and a state
  outside the realization domain are distinguished by different outcomes: the first is an ordinary zero,
  the second refuses through a named error. Reversed square-root argument order is shown to be capable of
  manufacturing a positive number, and production refuses instead. Price limits v4 itself rejects, a
  non-removal handed to the removal derivation, and a traversal exceeding the bounded step count are all
  refused.

**Still unverified**

- Nothing in F5 is consumed by an enforcement transition yet, because none exists. The derivations are
  verified as derivations; that enforcement will consume them correctly is F6/F7/F8 evidence.
- No stateful invariant evidence is claimed. GI depends on transitions that do not exist yet.

## Known Limitations / Blockers

1. **Bounded swap-step traversal.** `MAX_PROSPECTIVE_SWAP_STEPS = 16` bounds the reproduction of the v4
   swap loop. A supported transition inside the canonical topology needs very few steps, but a service
   with a tick spacing of one and a domain spanning more than sixteen tick-bitmap words can exceed it,
   and the derivation then refuses rather than truncating. This is a realization bound, not a protocol
   semantic; it is tested on both sides. If a future configuration needs a wider traversal, the constant
   is the single place to change and the differential suite is the evidence that would need rerunning.
2. **`ServiceDomain.introducesInteriorBoundary` has no production consumer yet.** It is the topology
   classification F5 is required to own (session prompt §7.3, implementation-plan §10.6) and is fully
   unit- and fuzz-verified, but the transition that acts on it belongs to F6. It is deliberately a
   classification with no rejection attached.
3. **Real-v4 differential evidence runs against a callback-admitting harness.** Production callbacks fail
   closed until their enforcement slice exists, so no liquidity can enter a production Hook-bound pool and
   no swap can execute against one. `StandbyDerivationHarness` admits the four callbacks and decides
   nothing; every price, tick, liquidity, and bitmap value the derivations read is written by the real
   PoolManager. This is the same reasoning under which `LiquidityPermissiveStandbyHookHarness` was
   accepted at G3.
4. **Static-fee assumption.** The prospective swap derivation reads the effective LP fee from
   authoritative Slot0 and composes the protocol fee exactly as the pool does. This is correct under the
   realization's static-fee model and this Hook's absence of any fee override; a dynamic-fee pool is
   already rejected at configuration.
5. **Test name carried forward.** `test_enabledCallbacks_remainFailClosedAtTheF4Frontier` still names F4.
   Its assertion is unchanged and still correct; only the label is now historical.

## Scope Check

Work remained within the authorized F5 slice. Two changes are worth calling out explicitly because they
touch code outside the new files:

- `StandbyHook._validateServiceDomain` was refactored to consume `ServiceDomain`. This is in scope: F5
  owns service-domain classification, and leaving the inline restatement would have created exactly the
  production duplication G5-D forbids. Behavior, errors, and error arguments are unchanged, and the F3
  configuration suites pass untouched.
- One F4 assertion in `test/unit/CommitmentStorage.t.sol` was narrowed, because F5 is the slice that is
  authorized to introduce the three reads it forbade. The lifecycle-projection prohibition it also
  carried was preserved and is still asserted.

No F6A, F7, F6B, F8A–F8D, GI, F9, or F10 behavior was implemented. No callback was made live. No
dependency, remapping, compiler, or EVM configuration changed, so `docs/setup.md` needed no update.

## Proposed Gate Assessment

**G5 overall: PASS PROPOSED.**

Every sub-gate has evidence. The derivations equal independently composed references under deterministic
and fuzzed inputs; the prospective derivations equal what real Uniswap v4 execution produces for the same
transitions, including the word-edge case that distinguishes a faithful reproduction from a plausible
approximation; the results generalize across direction, tick layout, fee, spacing, liquidity, and
heterogeneous decimals; each quantity has exactly one production expression; no downstream transition
semantics were introduced; and invalid derivation bases fail closed with named errors rather than
producing plausible capacity.

This is a proposed assessment only. G5 is not closed, and F6A is not authorized.

## Recommended Next Step

Independent G5 review. If it closes, the smallest coherent next responsibility is **F6A — preliminary O3
enforcement with `O = 0`**, which is where the enforcement perimeter, actor attribution, and the first
consumption of these derivations belong.

## Prompt Audit

All material follow-up instructions were recorded in `docs/prompts/session-07-log.md`.

**Material prompts recorded: 0.** The session was executed from the initiating prompt
`docs/prompts/session-07-f5-authoritative-deriviation-kernal.md` with no material follow-up instructions.

---

# Session 07 Correction — Admission-Time Prospective Traversal Derivability

Initiated from `docs/prompts/session-07-correction-prospective-traversal-derivability.md`.

This is a targeted correction and revalidation pass on F5, not a new implementation slice.

## What independent review found

The F5 prospective swap derivation correctly reproduced multi-step Uniswap v4 traversal — the original
session established, against real PoolManager execution, that a single `computeSwapStep` is not exact,
because `nextInitializedTickWithinOneWord` returns a word edge whenever the searched word holds no
initialized tick, so v4 splits a swap at uninitialized tick-bitmap word boundaries.

What the original session did not establish is that an *activated service* can always be derived. The
implementation bounded the traversal at `MAX_PROSPECTIVE_SWAP_STEPS = 16` and refused beyond it, but
nothing prevented a service from being configured with an immutable domain that demands more steps than
that. Such a service would activate normally and only discover, during ordinary supported operation, that
its own domain could not be authoritatively evaluated — and because the service basis is immutable,
nothing could repair it afterwards. The original session's own step-bound test built exactly such a
service in order to reach the runtime revert, which in hindsight is the defect stated as a fixture.

## Why the runtime refusal was insufficient on its own

Refusing at runtime is correct as protection and wrong as discovery. A bounded traversal that refuses
rather than truncates never produces a wrong prospective state, so backing is never decided against a
state the pool would not reach. But an activated Standby service whose ordinary in-domain swaps cannot be
evaluated is not a service with a runtime error; it is a service that should never have become
authoritative. The correction moves the decision to the only place that can still make it.

## Upstream correction

The frozen RR-SC-8 single-step assumption was corrected upstream before this session, by amendment to
`docs/uniswap-v4-realization.md` (RR-SC-8 restated as exact bounded traversal; RR-SC-8A added for
admission-time derivability; RR-SETUP-4 and §4.1 step 12 updated) and `docs/implementation-plan.md`
(§8.5, §8.8, §10.5, §10.6, §10.10, §10.14, §10.15). This session implements those amended requirements.
No frozen canonical economic artifact was reopened, and no Standby economic semantics changed.

## Production files changed

- `src/libraries/ServiceDomain.sol` — added `prospectiveTraversalDemand(tickQ, tickO, tickSpacing)`, the
  single production derivation of the realization-topology fact. Pure: it reads no PoolManager state, no
  Hook storage, and no registry, holds no bound, and makes no activation decision.
- `src/StandbyHook.sol` — added `_validateProspectiveDerivability`, called from `configureAndActivate`
  immediately after service-domain validation and before every authoritative write, plus the
  `StandbyHook__ProspectiveTraversalDemandExceedsBound(demand, bound)` error. The Hook owns the supported
  bound `MAX_PROSPECTIVE_SWAP_STEPS` and the consequence; the constant is unchanged at 16 and is now the
  single `M` shared by both admission and the runtime loop.

No new storage. Traversal demand is derived from immutable PES facts on demand and is never cached.

## Traversal-demand derivation and its ownership

Derived from the pinned v4 semantics actually compiled by Standby, not from a tick-width approximation.
`nextInitializedTickWithinOneWord` advances one tick-bitmap word per step whenever the searched word holds
no initialized tick in range, so demand is a function of how many words the *numeric* domain occupies
under `TickBitmap.compress` and `TickBitmap.position` — boundary ticks and tick spacing together:

```text
D = (words the numeric domain spans) + (numeric top is not on a word edge ? 1 : 0)
```

The conditional step is the downward worst case the closed-domain topology permits: RR-SC-6 allows a
liquidity endpoint exactly on a configured boundary, so if the numeric top is initialized and the price
starts there, v4 spends one step crossing that tick without moving and then another on the same word. A
top that compresses onto a word edge cannot cost that, because the crossing step already leaves the word,
so the step is charged only when it can actually be spent. Upward traversal is never binding: its search
skips the tick it starts from, so it can neither spend the crossing step nor visit more words.

The classifier is therefore conservative but tight — the exactly-bounded fixture below spends all sixteen
steps — and it is direction-independent, because ordinary swaps run in both directions on any service.

## Activation behavior added

`configureAndActivate` now derives the demand implied by the proposed immutable domain and tick spacing
and refuses when it exceeds the bound, before any PES field is written. Ordering is unchanged for every
prior check, so an over-bound configuration that is also misaligned, inverted, or out-of-domain still
fails for its original reason. The failure is named as a realization-admissibility failure and is never
reported as insufficient backing, zero Supporting Capacity, or invalid commitment state.

## Verification files changed

- `test/shared/ReferenceCalculations.sol` — added `referenceProspectiveTraversalDemand`, composed
  independently through explicit flooring division rather than through `TickBitmap`'s compression and
  arithmetic shift, so a disagreement about negative tick regions surfaces instead of being shared.
- `test/unit/ServiceDomain.t.sol` — seven new traversal-demand tests: canonical geometry, direction
  independence, spacing sensitivity, word-aligned versus non-aligned tops, negative-region flooring,
  positive/negative symmetry, and equivalence with the independent reference.
- `test/fuzz/ServiceDomainFuzz.t.sol` — four new traversal-demand properties: reference equivalence across
  the full tick range and all spacings, boundary-role independence, monotonicity in domain width, and
  bounds on a minimal domain.
- `test/integration/StandbyServiceConfiguration.t.sol` — five new targeted G3 tests: canonical margin,
  exactly-bounded acceptance, one-step-beyond rejection, over-bound rejection in either protected
  direction, and proof that a rejected attempt leaves the one-shot activation right intact.
- `test/fuzz/StandbyServiceGeometryFuzz.t.sol` — the acceptance generator now proposes only derivable
  domains, because an over-bound domain is no longer an admissible configuration; a new fuzz test covers
  the rejection side of the same boundary across both directions and all spacings.
- `test/integration/ProspectiveStateEquivalence.t.sol` — the former `ProspectiveSwapStepBoundTest` is
  replaced by `ProspectiveTraversalBoundTest`, which no longer activates an unsupported service.
- `test/integration/DerivationGeneralization.t.sol` — added proof that every activated configuration lies
  within the bound and that the production classifier agrees with the reference for each.
- `test/shared/BaseDerivationTest.t.sol` — split `_deployService` into `_prepareService` / `_activateService`
  so a rejection test reaches the real activation transition; added a per-service CREATE2 deployer so hook
  mining does not re-walk occupied salt space, which had put the multi-service fixture at the memory limit.

## Targeted G3 regression results

`test/integration/StandbyServiceConfiguration.t.sol` — 36 passed. All 31 pre-existing G3-C tests still
pass unchanged: authority, one-shot activation, atomic completeness, exact pool identity, fixed registry,
fixed domain and direction, distinct perimeter roles, zero-liquidity bootstrap, static-fee restriction,
closed-domain boundary equality at both `P_Q` and `P_O`, and no post-activation mutation surface.

`test/fuzz/StandbyServiceGeometryFuzz.t.sol` — 6 passed. The three pre-existing rejection fuzz tests
(direction ordering, misalignment, out-of-range ticks, current price outside the domain) still fail for
their original reasons.

## G5-B revalidation results

`test/integration/ProspectiveStateEquivalence.t.sol` — 21 passed, in two fixtures.

The pre-existing 14 differential tests are unchanged and still pass, including the word-boundary crossing
and the demonstration that a single-step model diverges from real execution exactly where the production
derivation matches it.

New evidence on an accepted configuration sitting exactly on the bound (`tickQ = -3484`, `tickO = 100`,
tick spacing 1 — fifteen bitmap words plus the conditional step):

- the worst in-domain downward path, run in the worst topology the closed domain permits (a liquidity
  endpoint exactly on the numeric top, so the conditional crossing step is actually spent), from `P_O` to
  `P_Q`: predicted `sqrtPriceX96`, predicted active liquidity, and predicted `S'` each equal what real
  PoolManager execution produced, and the derivation does not encounter the runtime bound;
- the worst upward in-domain path on the same service: predicted price and liquidity equal actual.

If the classifier under-counted by even one step, the first of these would revert rather than match.

## G5-F revalidation results

All pre-existing invalid-basis evidence is retained and passing. Added:

- a domain demanding exactly `M + 1` is refused at activation, atomically, with no PES field persisted and
  no service identity reported;
- a far-over-bound domain is likewise refused before any persistence;
- the runtime bound is now reachable on an activated service only via a price limit outside the configured
  domain, and both the state derivation and the capacity preview refuse rather than truncate.

The distinction between a valid state with `S == 0` and an unsupported derivation basis is preserved, and
traversal-bound admission failure carries its own error rather than any economic one.

## G5-D / G5-E structural results

One production traversal-demand classifier (`ServiceDomain.prospectiveTraversalDemand`), one consumer
(`StandbyHook._validateProspectiveDerivability`), one bound constant shared by admission and the runtime
loop, no `ReferenceCalculations` dependency in production or script source, no new storage, and no
production callback override — the four enabled callbacks remain fail-closed at the F5 frontier.

## Full regression results

```text
forge fmt --check                 clean
forge build                       successful, no warnings
forge build --sizes               StandbyHook runtime 15,104 bytes (9,472 bytes margin)
forge test                        270 passed, 0 failed, 0 skipped (24 suites)
FOUNDRY_PROFILE=ci forge test     270 passed, 0 failed, 0 skipped (10,000 fuzz runs)
```

## Remaining limitations

1. The supported bound remains `MAX_PROSPECTIVE_SWAP_STEPS = 16`, so a service needing a domain wider than
   roughly fifteen tick-bitmap words at its tick spacing is unsupported by this reference realization and
   is now refused at activation rather than at runtime. Raising it is a one-constant change; the
   exactly-bounded differential fixture is the evidence that would need re-running.
2. `ServiceDomain.introducesInteriorBoundary` still has no production consumer. It is the topology
   classification F5 owns and is fully unit- and fuzz-verified; the transition that acts on it is F6's.
3. Real-v4 differential evidence still runs against the callback-admitting `StandbyDerivationHarness`,
   for the same structural reason as before: production callbacks are fail-closed until their enforcement
   slice exists. The harness decides nothing and computes no traversal demand of its own.

This correction does not close G5.
