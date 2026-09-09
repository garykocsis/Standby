# Standby — Session 16 Log

Implementation-process record for:

> **F9 — Canonical Acceptance**

Initiating prompt: `docs/prompts/session-16-f9-canonical-acceptance.md`.

This log is a non-normative audit artifact. It records material follow-up instructions, design decisions,
counterexamples, verification commands, and results. It defines no protocol semantics.

---

## Material Prompts

### Prompt 1 — Session authorization

**Instruction:**

> Read root CLAUDE.md, then execute docs/prompts/session-16-f9-canonical-acceptance.md as the authorized
> Session 16 task. Stop at the completion boundary defined by that prompt.

**Consequence:** F9 implementation proceeded under the Session 16 prompt scope: callable deterministic
deployment/bootstrap orchestration reusable by tests and operational wrappers, GB bootstrap-fidelity
evidence, one uninterrupted canonical Bootstrap → A1 → A2 → A3 rejection → A4 acceptance history through
production paths, deterministic reproduction evidence, and an advisory G9 assessment.

### Prompt 2 — Status-only project-status synchronization

**Instruction:**

> Update **status only** in `docs/project-status.md` to reflect the independently reviewed F9 result: F9 —
> Canonical Acceptance: COMPLETE; G9: PASS; F10 — Demo / Submission Readiness: next authorized
> implementation slice / current blocker; F9T — Public Testnet Deployment: remains optional / off the
> critical path. Do not add implementation details, design commentary, test summaries, gate reasoning,
> retrospective observations, acceptance evidence, or any other new descriptive content to
> `docs/project-status.md`. Only make the minimum edits necessary to bring existing status fields,
> roadmap/ladder entries, current-blocker/next-action fields, last-closed-gate fields, and any now-stale
> status statements into consistency with that status. Also record this instruction in
> `docs/prompts/session-16-log.md` as the next material follow-up prompt and record the resulting
> status-only action, as audit chronology only. Do not modify any other files.

**Consequence:** `docs/project-status.md` was synchronized with the externally reviewed and closed G9, as a
status-only edit: the header slice/gate/status fields, the Current Objective slice and last-closed-gate
statements, the implementation-ladder rows for F9 and F10, the Current Blocker section, the Next Action
section, and the Handoff Summary. No implementation detail, evidence, or gate reasoning was added, and no
other file was modified. This synchronization records already-authorized state; it closes no gate and
authorizes no downstream slice beyond F10.

---

## Deployment / Bootstrap Architecture Inspected

Existing construction surfaces inspected before creating any F9 orchestration:

- `script/DeployStandbyHook.s.sol` — the canonical Hook mining/deployment procedure, already split into a
  callable `deployStandbyHook(...)` and a thin broadcasting `run()`;
- `script/helpers/HelperConfig.s.sol` / `script/helpers/NetworkConfig.sol` — infrastructure resolution,
  deploying the real pinned `PoolManager` on the deterministic local environment;
- `script/helpers/DeterministicFixtureDeployer.sol` — ordered `MockUSTB` / `MockUSDC` CREATE2 deployment;
- `script/helpers/StandbyFixtureConfig.sol` — the frozen canonical fixture constants;
- the F3–F8D shared test fixtures (`test/shared/Base*`), which build the same environment inline in
  `setUp()` rather than through a reusable deployment/bootstrap implementation.

**Finding:** every component the canonical construction path needs already had a production deployment
path, but no callable *composition* of them existed. `DeployDemoEnvironment.s.sol` and
`BootstrapStandby.s.sol` (implementation-plan §19.3, §20.6, §23.2) had not yet been written, so F9's fresh
construction path could not be exercised without them.

---

## Script / Test Reuse Decisions

### Decision 1 — Callable orchestration, thin `run()` wrappers

Both new scripts follow the established `DeployStandbyHook` shape: the deterministic orchestration is a
callable `public` function over explicit inputs, and `run()` only resolves environment-supplied addresses
and logs. Acceptance tests call the callable functions directly inside the Foundry VM. No test shells out
to `forge script`, reads a broadcast artifact, or restates deployment/bootstrap semantics.

### Decision 2 — Actor-scoped steps expressed as broadcasts, not pranks

Bootstrap performs authority-scoped transitions (`configureAndActivate` as the configuration authority,
registry seeding as the registry administrator, approvals as each actor, canonical liquidity as the
liquidity provider). Those steps are written with `vm.startBroadcast(actor)` / `vm.stopBroadcast()` rather
than `vm.prank`, so that exactly one implementation serves both consumers: under `forge test` the broadcast
cheatcode sets the sender of the call (verified empirically before adopting it), and under
`forge script --broadcast` on the deterministic local environment each step is a real transaction from the
actor that is authorized to send it. A prank-based implementation would have been simulation-only and would
have made the operational wrapper a second, silently divergent path.

`HelperConfig._deployLocalInfrastructure` already owns its own broadcast, so the new callable functions own
theirs too; `run()` therefore opens no outer broadcast and no nesting occurs.

### Decision 3 — Hook deployment inside the composed script

`DeployDemoEnvironment` inherits the canonical Hook deployment procedure and runs it in its own context,
mining against the deterministic CREATE2 factory because that is what performs the creation whenever a
broadcast is open. Hook mining, salted creation, and deployment validation exist in exactly one place and
are not restated.

Both halves of this decision replaced an earlier design and are recorded under *Corrections Made During
Implementation* below: the first version created a `DeployStandbyHook` instance and mined against it,
which passes under `forge test` and cannot work on a real chain.

---

## Acceptance Fixture Decisions

`test/shared/BaseCanonicalAcceptanceTest.t.sol` provides one operation — construct a complete Standby
system from nothing — by calling `HelperConfig` → `DeployDemoEnvironment` → `BootstrapStandby`. It contains
no economic seeding, no harness, no `vm.store`, and no test-only setter, and it inherits nothing from the
F3–F8D fixture chain, so no prepared backed economic state can reach acceptance evidence.

It is a function rather than only a `setUp()` body, because the determinism claim requires a second
completely independent construction inside a test body.

---

## Corrections Made During Implementation

Both were found by running the operational path rather than by reasoning about it, and both are recorded
because the first design passed `forge test` while being wrong.

### Correction 1 — a composed script cannot deploy the canonical Hook deployer

The first `DeployDemoEnvironment` composed by creating a `DeployStandbyHook` instance and calling it. That
passed under `forge test`, and failed the moment it was broadcast to a real node:

```text
Error: `DeployStandbyHook` is above the contract size limit (48955 > 24576).
```

A contract that creates `StandbyHook` must carry the Hook's creation code, which puts it far above the
deployed-contract size limit — so the canonical procedure can only ever be run by a script contract, which
is never itself deployed. `DeployStandbyHook.s.sol` was therefore split, without any semantic change, into

- `abstract contract StandbyHookDeployment` — the mask, the errors, `deployStandbyHook(...)`, and
  `_validateDeployedHook(...)`, unchanged; and
- `contract DeployStandbyHook is StandbyHookDeployment` — the same `run()`, moved verbatim,

so a composed script inherits the one procedure and runs it in its own context. Nothing about mining,
salted creation, or deployment validation changed, and `hookDeployer.REQUIRED_HOOK_PERMISSION_MASK()`
still resolves for every existing fixture.

An intermediate attempt replaced the salted creation with an assembly `CREATE2` over the mined init code,
on the theory that the high-level `new StandbyHook{salt: salt}(...)` was embedding the Hook's creation
code a second time. Measurement disproved it — the creation code appears exactly once, and the script's
remaining size is the `HelperConfig` creation code it carries, which contains the PoolManager's — so the
change was reverted and the canonical procedure is byte-for-byte the G0-verified one.

Size is the reason `resolveAndDeployEnvironment` creates `HelperConfig` from its compiled artifact rather
than with `new`: carrying the local-infrastructure creation code alongside the Hook's exceeds the init-code
limit outright. It is the same compiled `HelperConfig`, resolving infrastructure identically.

### Correction 2 — salted creation is routed through the CREATE2 factory whenever a broadcast is open

With the composition fixed, the acceptance fixture still failed: the Hook address was mined against the
script contract, while the actual creation was routed through the deterministic CREATE2 factory. That
routing is not a property of `forge script` — it happens whenever a broadcast is open, including under
`forge test`. Since `deployEnvironment` owns its broadcast, the factory is the deployer in both contexts,
so the composed script now mines against `CREATE2_FACTORY` unconditionally and the `_create2Deployer`
parameter was removed from the environment script's surface.

This makes the acceptance path and the operational path deploy the Hook through identical routing, which
is a stronger position than the two agreeing by parameterization.

---

## GB — Bootstrap Fidelity Evidence

`test/acceptance/BootstrapFidelity.t.sol`, 9 tests, all passing. From an empty chain, through
`HelperConfig` → `DeployDemoEnvironment` → `BootstrapStandby` only:

- `MockUSTB` is `currency0` and `MockUSDC` is `currency1`, both at six decimals, ordering proven on the
  deployed addresses;
- the activated service is the canonical one: protected `zeroForOne`, `tickQ` -240, `tickO` +240, fee 500,
  spacing 10, the deployed registry, the deployed ExerciseRouter, the bootstrap establishment authority,
  and a service identity equal to the bootstrapped pool;
- the pool sits at the exact price of tick 0 with active liquidity `6,707,079,990,254`;
- `S = 80,000.000000 MockUSDC` and `O = 0`, each equal to its independent reconstruction, with
  `nextCommitmentId == 1` and every bounded reference slot empty;
- the Hook address encodes exactly `beforeAddLiquidity | beforeRemoveLiquidity | beforeSwap | afterSwap`,
  reconstructed independently from the pinned `Hooks` flags and accepted by
  `Hooks.validateHookPermissions` against the Hook's own declared permissions;
- the Hook is bound to the resolved PoolManager, to the intended configuration authority, and to the two
  distinct perimeters; the coordinator resolves the same PoolManager and the deployed Hook;
- the Hook and the ExerciseRouter hold zero of both currencies;
- exactly the three canonical eligibility predicates are granted, in their own domains, with the exercise
  authority holding none;
- the Beneficiary holds nothing at all, and the exerciser holds input currency only.

## G9 — Canonical History Evidence

`test/acceptance/CanonicalStandbyFlow.t.sol::test_CanonicalStandbyFlow`, one uninterrupted sequential
history over one live pool, using the identity the production admission transition returned:

| stage     |                  S |      O | Remaining | result    |
| --------- | -----------------: | -----: | --------: | --------- |
| bootstrap |             80,000 |      0 |         — | ready     |
| A1        |             80,000 | 50,000 |    50,000 | pass      |
| A2        |             65,000 | 50,000 |    50,000 | pass      |
| A3        | prospective 45,000 | 50,000 |    50,000 | reject    |
| after A3  |             65,000 | 50,000 |    50,000 | unchanged |
| A4        |             15,000 |      0 |         0 | pass      |

Stage detail:

- **A1** — `hook.establishCommitment` as the establishment authority returned commitment identity `1`;
  Original and Remaining Entitlement both `50,000.000000`; the pool price, tick, and active liquidity were
  unchanged by admission; the Beneficiary received nothing; one enforcement reference was occupied.
- **A2** — an exact-output protected swap through the trusted perimeter as the eligible trader. Production
  predicted `S' = 65,000.000000`; the trader received exactly `15,000.000000 MockUSDC` and paid
  `15,041.142406 MockUSTB`; the commitment's admitted extent and remainder were untouched.
- **A3** — the same trader, the same perimeter, funded, approved, in-domain, requesting
  `20,000.000000 MockUSDC`. Production predicted `S' = 45,000.000000 < 50,000.000000`, and the swap
  reverted with the wrapped `StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)` — the
  specific backing rejection, naming both compared quantities. Post-revert, capacity, obligation,
  remainder, identity counter, reference index, pool price, tick, liquidity, the trader's two balances,
  and the Beneficiary's balance were all exactly as before.
- **A4** — `ExerciseRouter.exercise(1, 50,000.000000, maxInput = 100,000.000000)` as the commitment's own
  exercise authority. The exerciser paid `50,627.787984 MockUSTB`, which is exactly what reached the
  PoolManager; the PoolManager delivered exactly `50,000.000000 MockUSDC` directly to the Beneficiary, and
  exactly that quantity left the PoolManager; the exerciser received no protected output; Remaining
  Entitlement and the obligation both reached zero; `S = 15,000.000000`; the admitted extent was not
  rewritten; the reference was retained; and the causal context was left `EMPTY`.

Both derivations were checked against independent reconstructions at every stage.

## Determinism Evidence

- `test_canonicalStandbyFlow_reproducesIdenticallyFromASecondFreshConstruction` builds a second, fully
  independent system — its own PoolManager, currencies, Hook, registry, perimeters, coordinator, and seven
  accounts — and reproduces the identical history, including the commitment identity, the delivered
  quantity, and the exact input the exercise cost.
- Two clean command-line runs (`forge clean` between them) produced byte-identical results, gas included.

## Operational Path Evidence (supplementary)

The same callable orchestration was broadcast to a local Anvil node to confirm the wrappers are not
test-shaped:

```bash
anvil
forge script script/DeployDemoEnvironment.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <acct0>
forge script script/BootstrapStandby.s.sol      --rpc-url http://127.0.0.1:8545 --broadcast --unlocked --sender <acct0>
```

Both completed on-chain. The Hook was deployed by CREATE2 at an address ending `0AC0`; the bootstrap sent
each step from the account authorized for it — `configureAndActivate` from the configuration authority,
the three eligibility grants from the registry administrator, each approval from its own actor, and
`modifyLiquidity` from the liquidity provider. The deployed system reported `S = 80000000000`, `O = 0`,
`nextCommitmentId = 1`.

This is supplementary evidence about the operational wrappers. It is not G9 evidence, which is discharged
entirely by the deterministic Foundry acceptance suites.

## Verification Commands and Results

```text
forge fmt --check                     clean
forge build                           successful
forge test --match-path test/acceptance/*   11 passed, 0 failed
forge test                            590 passed, 0 failed, 0 skipped (62 suites)
FOUNDRY_PROFILE=ci forge test         590 passed, 0 failed, 0 skipped (62 suites)
```

No gas snapshot or coverage run was performed: no production source changed.

## Advisory G9 Assessment

**PASS (advisory).** A completely fresh deterministic construction reproduced the frozen canonical
economic history exactly, through production deployment, bootstrap, admission, ordinary-swap, rejection,
and exercise paths, with no privileged economic state and no mocked fulfillment. Claude does not close G9.

---

## Required Task Completion Report

### Files Inspected

`CLAUDE.md`; `.claude/rules/solidity-style.md`; `.claude/rules/testing.md`;
`docs/prompts/session-16-f9-canonical-acceptance.md`; `docs/project-status.md`;
`docs/implementation-plan.md` §19 (F9), §20.6, §23; `docs/demo-spec.md` §5–§8;
`script/DeployStandbyHook.s.sol`; `script/helpers/HelperConfig.s.sol`;
`script/helpers/NetworkConfig.sol`; `script/helpers/DeterministicFixtureDeployer.sol`;
`script/helpers/StandbyFixtureConfig.sol`; `src/StandbyHook.sol` (external surface, `configureAndActivate`,
`establishCommitment`, `_validateCommitmentTerms`); `src/ExerciseRouter.sol`; `src/EligibilityRegistry.sol`
and `src/interfaces/IEligibilityRegistry.sol`; `src/demo/ActorAwareTestRouter.sol`;
`src/mocks/MockFixtureCurrency.sol`, `MockUSDC.sol`, `MockUSTB.sol`; the F3–F8D shared fixtures
(`BaseStandbyServiceTest`, `BaseActorAwareStandbyTest`, `BaseCommitmentAdmissionTest`,
`BaseAuthenticBackingTest`, `BaseExerciseAuthorizationTest`, `BaseExerciseSettlementTest`,
`BaseExerciseFinalizationTest`, `BaseDerivationTest`, `ReferenceCalculations`);
`test/integration/O3AuthenticBackingEnforcement.t.sol`; `test/integration/ExerciseFinalization.t.sol`;
`test/integration/StandbyHookDeployment.t.sol`; pinned `HookMiner.sol` and `Hooks.sol`; `foundry.toml`;
`.gitignore`; `docs/setup.md`.

### Files Changed

**Created**

- `script/helpers/StandbyEnvironment.sol` — the deployed-address manifest and the role assignment types the
  composed deployment and bootstrap pass between them.
- `script/DeployDemoEnvironment.s.sol` — callable deterministic composition of the complete environment,
  plus a thin `run()`.
- `script/BootstrapStandby.s.sol` — callable deterministic bootstrap to the canonical pre-A1 state, plus a
  thin `run()`.
- `test/shared/BaseCanonicalAcceptanceTest.t.sol` — fresh-construction acceptance fixture and the
  independent verification oracles.
- `test/acceptance/BootstrapFidelity.t.sol` — GB evidence.
- `test/acceptance/CanonicalStandbyFlow.t.sol` — G9 evidence.
- `docs/prompts/session-16-log.md` — this log.

**Modified**

- `script/DeployStandbyHook.s.sol` — split into `abstract contract StandbyHookDeployment` (the unchanged
  canonical procedure) and `contract DeployStandbyHook is StandbyHookDeployment` (the same `run()`, moved
  verbatim), so a composed script can inherit the procedure instead of deploying a copy of it that no real
  chain would accept. No mining, creation, validation, or error semantics changed.
- `docs/setup.md` — documented the environment variables and local broadcast invocation of the two new
  script wrappers, and the inherited-procedure structure.

**Unchanged:** every file under `src/`, every frozen canonical artifact, and `docs/project-status.md`.

### Requirements Implemented

F9 — Canonical Acceptance: fresh deterministic construction, production-path composition, GB bootstrap
fidelity, one uninterrupted canonical Bootstrap → A1 → A2 → A3 rejection → A4 history, authoritative
observation, and deterministic reproduction (`implementation-plan.md` §19.1–§19.10, §20.6, §23.2–§23.3).
No new Standby protocol semantics.

### Tests Added or Changed

Added, none changed:

- `BootstrapFidelity.t.sol` (9 tests) — proves fresh construction reaches exactly the canonical pre-A1
  state: currency identity and order, service configuration, pool geometry, `S = 80,000` / `O = 0` /
  no commitment, Hook permission bits and trust bindings, zero Standby custody, exact eligibility, and
  actor funding that cannot pre-empt the delivery.
- `CanonicalStandbyFlow.t.sol` (2 tests) — `test_CanonicalStandbyFlow` proves the uninterrupted canonical
  history including the specific A3 backing rejection, its atomicity, and the exact A4 delivery;
  `test_canonicalStandbyFlow_reproducesIdenticallyFromASecondFreshConstruction` proves deterministic
  reproduction from an independent second construction.

### Commands Run

```text
forge fmt / forge fmt --check
forge build / forge build --sizes
forge test --match-path test/acceptance/BootstrapFidelity.t.sol -vv
forge test --match-path test/acceptance/CanonicalStandbyFlow.t.sol -vv
forge test --match-path "test/acceptance/*" -vv   (twice, with forge clean between)
forge test
FOUNDRY_PROFILE=ci forge test
forge script script/DeployDemoEnvironment.s.sol            (simulation, then --broadcast against Anvil)
forge script script/BootstrapStandby.s.sol                 (--broadcast against Anvil)
```

### Results

`forge fmt --check` clean; `forge build` successful; acceptance suites 11/11 passing; full suite 590
passed / 0 failed under both the default and `ci` profiles; two clean acceptance runs byte-identical;
both broadcast scripts completed on-chain against a local Anvil node, reaching `S = 80000000000`, `O = 0`,
`nextCommitmentId = 1`.

### Gate Evidence

Implemented and verified: fresh deterministic construction through real deployment and bootstrap; GB
bootstrap fidelity; the uninterrupted canonical history; the specific A3 rejection and its atomicity; the
exact 50,000 Beneficiary delivery with the exerciser paying the actual input debt; terminal
`S = 15,000` / `O = 0` / `Remaining = 0`; zero Hook and coordinator custody throughout; deterministic
reproduction. Still unverified: nothing within the F9 boundary. Public-network behaviour remains out of
scope (F9T).

### Known Limitations / Blockers

- `HelperConfig` still resolves infrastructure only for chain id `31337`; public-chain PoolManager
  resolution remains unimplemented, as recorded since F0.
- `BootstrapStandby.run()` broadcasts each step from the account authorized for it, so a broadcast run
  needs a node that will send from those accounts (`--unlocked` on Anvil). Under `forge test` the same
  functions are called directly.
- The pre-existing unused-import lint note in `test/shared/BaseExerciseFinalizationTest.t.sol` was left
  untouched.

### Scope Check

Within the authorized F9 slice. The one modification outside `test/acceptance/*` and the new script files
is the `DeployStandbyHook.s.sol` split, which the session prompt permits as a narrow orchestration
refactor and which was necessary to expose the already-authorized deployment procedure to a composed
script. No `src/` change, no frozen artifact change, no `docs/project-status.md` change, no F10 or F9T
work.

### Proposed Gate Assessment

**G9 — PASS (advisory).** Claude does not close G9.

### Recommended Next Step

Independent review of the F9 evidence and an explicit G9 decision. Do not begin F10 before that.

### Prompt Audit

One material prompt recorded in this log (Prompt 1 — session authorization). F9 introduced no new protocol
semantics, no new permanent operating rules, no new permanent Solidity or testing conventions, no F10 or
F9T work, no unrelated refactoring, no gas optimization, and no coverage-driven change.
