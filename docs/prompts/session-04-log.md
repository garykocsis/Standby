# Session 04 — Material Prompt Log

Initiating prompt: `docs/prompts/session-04-f2-eligibility-registry.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

_No material follow-up prompts recorded yet._

---

## Task Completion Report — F2 EligibilityRegistry

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/prompts/session-04-f2-eligibility-registry.md`
- `docs/implementation-plan.md` (§7 F2 / §7.3 required predicates / §7.5 tests / §7.6 G2, §8 F3
  configuration consumption, §17 invariant registry actions, §22 repository footprint, gate ladder)
- `docs/uniswap-v4-realization.md` (§2.3 `EligibilityRegistry`, §4.1 configuration validation, §8
  permission domains, RR-PERM-1..4)
- `docs/state-machine.md` (§8.5 external authoritative facts, §8.6 institutional Beneficiary
  eligibility, §8.7 pool access versus service eligibility)
- `docs/architecture.md` (hook enforcement surface and authority boundaries)
- `docs/testing-strategy.md`, `docs/demo-spec.md` (registry usage references)
- `src/StandbyHook.sol`, `src/mocks/MockFixtureCurrency.sol`, `src/mocks/MockUSTB.sol`
- `script/helpers/HelperConfig.s.sol`
- `docs/prompts/session-03-log.md`, `foundry.toml`, `.github/workflows/ci.yml`

No pinned Uniswap v4 dependency source was consulted, because F2 introduces no dependency on a v4 API.

### Files Changed

Created:

- `src/interfaces/IEligibilityRegistry.sol` — the read surface Standby consumes: exactly the three
  predicates `canReceiveProtectedService`, `canSwap`, `canProvideLiquidity`. Mutation functions are
  deliberately absent from the consumed surface, per `uniswap-v4-realization.md` §2.3 ("the hook reads
  the registry but does not expose registry-membership management functions").
- `src/EligibilityRegistry.sol` — the dedicated external eligibility authority. Three separate storage
  mappings, three separate administrator entry points, three separate events, one immutable
  administrator, fail-closed defaults.
- `test/unit/EligibilityRegistry.t.sol` — G2-A through G2-D unit evidence (21 tests).
- `test/fuzz/EligibilityRegistryFuzz.t.sol` — parameterized G2-A/B/C/D evidence (7 tests), required by
  `implementation-plan.md` §7.5/§7.6.
- `docs/prompts/session-04-log.md` — this audit artifact.

Modified: none. `git diff --stat` is empty; `src/StandbyHook.sol` is byte-for-byte unchanged, so no
Hook consumption of eligibility was introduced.

### Requirements Implemented

- `implementation-plan.md` §7.1 — dedicated external mutable eligibility authority that owns no Standby
  economics.
- `implementation-plan.md` §7.2 — production footprint exactly `src/EligibilityRegistry.sol` and
  `src/interfaces/IEligibilityRegistry.sol`.
- `implementation-plan.md` §7.3 — the three required independent predicates under their canonical names,
  logically independent even when one account holds several.
- `implementation-plan.md` §7.3 — minimal single-admin registry; default behavior fails closed.
- `implementation-plan.md` §7.4 — registry exclusions: the contract references no PoolId, PoolManager,
  Supporting Capacity, Aggregate Obligation, Remaining Entitlement, exercise authority, validity,
  lifecycle time, or O1/O2/O3 state. It imports nothing but its own interface.
- `uniswap-v4-realization.md` §2.3 — dedicated on-chain registry, single-owner sufficient, predicates
  semantically distinct under one administrator.
- `uniswap-v4-realization.md` §8.1 — registry administration authority is preserved as its own
  permission domain, distinct from configuration, establishment, and exercise authority.
- `uniswap-v4-realization.md` RR-PERM-3 — the predicate semantic role is fixed; membership is mutable.

Deliberately not implemented (F3+ boundary): Hook consumption of the registry, Beneficiary/trader/
liquidity enforcement, PES configuration, O1/O2/O3, Supporting Capacity, commitment semantics,
PoolManager coupling.

### Tests Added or Changed

`test/unit/EligibilityRegistry.t.sol` (21 tests):

- `test_allPredicates_defaultToIneligible` — fail-closed default for five distinct accounts plus
  `address(0)`.
- `test_beneficiaryEligibility_isAdmittedAndRevokedByTheAdmin`,
  `test_traderEligibility_isAdmittedAndRevokedByTheAdmin`,
  `test_liquidityEligibility_isAdmittedAndRevokedByTheAdmin` — G2-C, both transitions
  (false → true and true → false) in every category.
- `test_repeatedWrites_reflectTheLatestAuthorizedWrite` — plan §7.5 latest-authorized-write fidelity.
- `test_eligibilityWrites_areScopedToTheNamedAccount` — per-account scoping.
- `test_oneAccount_holdsBeneficiaryEligibilityAlone`, `..._holdsTraderEligibilityAlone`,
  `..._holdsLiquidityEligibilityAlone` — G2-A; the exact `(true, false, false)` shape named by the
  session prompt and its two rotations. A single shared flag cannot produce these states.
- `test_oneAccount_holdsEveryCombinationOfTheThreePredicates` — G2-A; all eight combinations for one
  account, each reached by authorized writes.
- `test_beneficiaryUpdates_leaveTraderAndLiquidityEligibilityUnchanged`,
  `test_traderUpdates_leaveBeneficiaryAndLiquidityEligibilityUnchanged`,
  `test_liquidityUpdates_leaveBeneficiaryAndTraderEligibilityUnchanged` — G2-D; each category is
  granted and revoked from both an all-ineligible and an all-eligible baseline, and the other two
  domains are asserted unchanged after every write.
- `test_registryAdmin_isTheConstructorAdministrator`,
  `test_construction_rejectsAZeroAdministrator`,
  `test_admin_updatesAllThreeEligibilityCategories`,
  `test_unauthorizedGrant_revertsInEveryCategoryAndChangesNothing`,
  `test_unauthorizedRevocation_revertsAndLeavesEstablishedEligibilityUnchanged`,
  `test_administratorAuthority_isScopedToItsOwnRegistry` — G2-B; the administrator can write all three
  categories, an unauthorized caller can write none of them, and a rejected write leaves both the
  fail-closed default and previously established eligibility unchanged.
- `test_eligibilityWrites_emitDomainSpecificEvents` — each domain emits its own event, so an observer
  never infers one domain's change from another's.
- `test_registry_answersThroughTheConsumedReadInterface` — the concrete registry answers through
  `IEligibilityRegistry`, and that consumed surface carries reads only.

`test/fuzz/EligibilityRegistryFuzz.t.sol` (7 tests):

- `testFuzz_anyAccount_defaultsToIneligibleUnderEveryPredicate` — fail-closed default over arbitrary
  accounts.
- `testFuzz_anyEligibilityCombination_isReflectedExactly` — G2-A/G2-C over arbitrary accounts and all
  predicate combinations.
- `testFuzz_singleDomainUpdate_leavesTheOtherDomainsUnchanged` — G2-D from an arbitrary baseline, for
  an arbitrarily selected domain and written value.
- `testFuzz_latestAuthorizedWrite_isAuthoritative` — plan §7.5 write fidelity.
- `testFuzz_writes_areScopedToTheNamedAccount` — per-account scoping over arbitrary distinct accounts.
- `testFuzz_unauthorizedCaller_cannotWriteAnyDomain` — G2-B over arbitrary non-administrator callers,
  asserting all three domains are preserved after the rejected writes.
- `testFuzz_administratorAuthority_isScopedToItsOwnRegistry` — administration authority does not cross
  registry instances.

Fuzz inputs are unconstrained except for two semantic exclusions: the unauthorized-caller test excludes
the administrator, and the account-scoping test requires two distinct accounts.

### Commands Run

```bash
git status
forge fmt
forge fmt --check
forge build --sizes
forge lint
forge test --match-path test/unit/EligibilityRegistry.t.sol -vv
forge test --match-path test/fuzz/EligibilityRegistryFuzz.t.sol -vv
forge test
FOUNDRY_PROFILE=ci forge test
git diff --stat
git status --short
```

### Results

- `forge fmt --check` — clean.
- `forge build --sizes` — successful. `EligibilityRegistry` runtime size 1,024 bytes.
- `forge lint` — no findings.
- `forge test --match-path test/unit/EligibilityRegistry.t.sol -vv` — 21 passed, 0 failed, 0 skipped.
- `forge test --match-path test/fuzz/EligibilityRegistryFuzz.t.sol -vv` — 7 passed, 0 failed, 0 skipped,
  1,000 runs per property (default profile).
- `forge test` — 57 passed, 0 failed, 0 skipped across 5 suites.
- `FOUNDRY_PROFILE=ci forge test` — 57 passed, 0 failed, 0 skipped, 10,000 fuzz runs per property.
- `git diff --stat` — empty. Every change is a new file; no tracked file was modified.

### Gate Evidence

Implemented and verified:

- **G2-A predicate independence** — three separate storage mappings, three separate entry points. Unit
  evidence includes the `(Beneficiary = true, Trader = false, Liquidity = false)` state named by the
  prompt, its two rotations, and all eight combinations for one account; fuzz evidence covers arbitrary
  accounts and combinations at 10,000 runs. A shared generic flag would fail every one of these.
- **G2-B authorization** — the administrator writes all three categories; an unauthorized caller is
  rejected in all three with `EligibilityRegistry__NotAdmin(caller)`; state is asserted unchanged after
  every rejected write, both from the fail-closed default and from established eligibility. Fuzz
  evidence covers arbitrary non-administrator callers. Administration authority does not cross registry
  instances, and a zero administrator is rejected at construction.
- **G2-C read fidelity** — both directions proven per category: false → true and true → false, with the
  public predicate asserted after each transition. Revocation evidence exists for all three categories.
- **G2-D cross-domain isolation** — for each category, granting and revoking is proven to leave the
  other two unchanged, from both an all-ineligible and an all-eligible baseline; fuzz evidence proves
  the same from arbitrary baselines.
- **G2-E architectural isolation** — the F2 diff adds only the two production files and two test files.
  `src/StandbyHook.sol` is unchanged, so there is no Hook consumption of eligibility. The registry
  imports only its own interface: no PoolManager, no PoolId, no PoolKey, no currency, no fixture
  constant, no direction, no decimals, no commitment, no capacity, no O1/O2/O3. Eligibility is not
  PoolId-scoped, because no authoritative F2 source requires it.

Still unverified at F2 (correctly, by slice boundary):

- that `StandbyHook` reads this registry;
- that Beneficiary eligibility is checked at O1 and rechecked at O2 (RR-PERM-1);
- that eligibility loss leaves Validity, Remaining Entitlement, and Capacity Obligation unchanged
  (RR-PERM-2) — this requires commitment state that does not exist yet;
- registry mutation inside arbitrary stateful protocol sequences (GI, `implementation-plan.md` §17).

### Known Limitations / Blockers

No blocker. Three notes:

1. **Read-predicate naming.** The session prompt describes the reads as "semantically equivalent to"
   `isBeneficiaryEligible` / `isTraderEligible` / `isLiquidityActorEligible`. The canonical names in
   `uniswap-v4-realization.md` §2.3 and `implementation-plan.md` §7.3 are
   `canReceiveProtectedService` / `canSwap` / `canProvideLiquidity`. Upstream normative authority was
   preserved, so the canonical names are implemented. Mutation names follow the registry actions named
   in `implementation-plan.md` §17.2 (`setBeneficiaryEligibility`, `setTraderEligibility`,
   `setLiquidityEligibility`).
2. **Fuzz suite included.** The session prompt treats fuzz coverage as optional; `implementation-plan.md`
   §7.5 lists `test/fuzz/EligibilityRegistryFuzz.t.sol` and §7.6 states that F2 closes when authority and
   predicate independence are proven by "unit + fuzz evidence". The upstream requirement governs, and the
   fuzz suite expands evidence only — it introduces no production surface.
3. **Stale status document.** `docs/project-status.md` still records F1 as NOT STARTED and G0 as the last
   closed gate, although F1 was merged in `7cd2827` and the session prompt records G1 as PASS. Gate and
   status changes are not this session's to make, so the file was left untouched.

The administrator is immutable, with no transfer path. That is the minimal design the reference
realization calls for; no authoritative F2 source requires administrator rotation. If a later slice or
the demo requires it, it is an additive change with its own evidence.

### Scope Check

Work remained within F2. No production contract other than the two new registry files was created or
modified. No Hook, script, deployment, fixture, or shared-test file was touched. No dependency,
remapping, compiler, or Foundry configuration changed, so `docs/setup.md` required no update. No frozen
normative document was modified. No F3+ behavior was introduced.

### Proposed Gate Assessment

**PASS (proposed).**

G2-A, G2-B, G2-C, G2-D, and G2-E each have passing unit and — where parameterization is meaningful —
fuzz evidence at both the default and CI profiles, and the full repository suite passes under both
profiles. `implementation-plan.md` §7.6 requires exactly unit + fuzz evidence of authority and predicate
independence, which is present. This remains a proposed assessment; G2 is not closed by this session.

### Recommended Next Step

Review the F2 diff and close G2. Then the smallest coherent next responsibility is **F3 — StandbyHook
Trust + PES Configuration (Hook region H1)**, which is where the Hook first binds this registry as its
authoritative eligibility source through `configureAndActivate`. Do not begin it until explicitly
tasked.

### Prompt Audit

Material follow-up prompts recorded in this log: **0**. The session was executed from
`docs/prompts/session-04-f2-eligibility-registry.md` with no material follow-up instructions.

---
