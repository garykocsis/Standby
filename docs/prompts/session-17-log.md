# Session 17 — F10 Demo / Submission Readiness — Implementation Log

Claude implementation chronology for the F10 slice. Audit artifact only; it defines no protocol
semantics and closes no gate.

---

## Repository state entering F10

Branch: `feat/f10-demo-submission-readiness`, clean except the untracked session prompt.

Last commit: `ab67d5e test: complete F9 canonical acceptance (#18)`.

`docs/project-status.md` records F0–F9 and GI complete with every gate closed, G9 closed, and F10 as the
next authorized, unstarted slice.

What F10 already had, inherited from F9 and earlier slices:

- `script/DeployStandbyHook.s.sol` — the single canonical Hook mining/deployment procedure;
- `script/DeployDemoEnvironment.s.sol` — the canonical environment composition (currencies, registry, both
  perimeters, Hook, ExerciseRouter) with `resolveAndDeployEnvironment` / `deployEnvironment` and an
  operational `run()` reading `STANDBY_*` deployment roles;
- `script/BootstrapStandby.s.sol` — pool initialization, PES activation, eligibility seeding, funding and
  approvals, canonical controlled liquidity, and the closing canonical pre-A1 fidelity checks;
- `script/helpers/StandbyEnvironment.sol`, `StandbyFixtureConfig.sol`, `HelperConfig.s.sol`;
- `test/acceptance/CanonicalStandbyFlow.t.sol` — the G9-accepted A1→A2→A3→A4 history, which is the exact
  production call sequence F10 must expose;
- no `frontend/` directory, no root `README.md`, and no `script/DemoActions.s.sol`.

So F10's missing pieces were: the non-browser A1–A4 fallback script, the deterministic demo run/manifest
plumbing, the frontend, and the judge-facing README/setup documentation.

---

## Authoritative read map decided before implementation

Every economic fact the demo displays was mapped to a production read before any UI was written:

| Displayed fact              | Authoritative source                                              |
| --------------------------- | ----------------------------------------------------------------- |
| Supporting Capacity `S`     | `StandbyHook.supportingCapacity()`                                 |
| Aggregate Obligation `O`    | `StandbyHook.aggregateObligation()`                                |
| Remaining Entitlement       | `StandbyHook.commitment(id).remainingEntitlement`                  |
| Commitment facts            | `StandbyHook.commitment(id)`                                       |
| Which commitments exist     | `StandbyHook.enforcementReferences()` / `nextCommitmentId()`       |
| Beneficiary balance         | `MockUSDC.balanceOf(commitment.beneficiary)`                       |
| Service basis / PoolKey     | `StandbyHook.protectedExecutionService()`, `StandbyHook.serviceId()` |
| Pool price / tick           | `PoolManager.extsload(pools[poolId].slot0)`                        |
| A2/A3 prospective `S′`      | `StandbyHook.prospectiveSupportingCapacityAfterSwap(params)`       |
| Action outcome / reason     | actual receipt, or decoded revert data from the attempted call     |

Nothing in that table is computed in JavaScript, and nothing is cached across a reload.

---

## Implementation decisions

Recorded as the session progressed; consequences noted where known.

### D1 — Reuse the F9 deployment and bootstrap scripts unchanged

`DeployDemoEnvironment.s.sol` and `BootstrapStandby.s.sol` are G9-accepted and already reach exactly the
canonical pre-A1 state. F10 therefore added no second deployment or bootstrap path and modified neither
file. The demo runner invokes those two scripts and nothing else.

### D2 — `DemoActions.s.sol` owns A1–A4 only

One new script, four production transitions, no environment construction. It reads the deployed manifest
and role accounts from `STANDBY_*` environment variables — the same convention `BootstrapStandby` already
uses — and calls exactly the production surfaces the G9 acceptance history calls.

### D3 — A3 in a script is a caught rejection, not a broadcast transaction

A3 must fail. A broadcasting script cannot usefully broadcast a transaction that reverts, so the script
performs the attempt inside `try/catch`, decodes the returned reason, requires it to be the specific
Standby backing-capacity error carrying the prospective and obligation quantities, and then re-reads
authoritative state to show it unchanged. The frontend performs the same attempt as a real submission and
decodes the revert data the node returns.

### D4 — The frontend proposes transactions; it never derives economics

Swap parameters, requested quantities, and the commitment window are proposed transaction facts built in
the client. Every economic quantity — including the prospective `S′` shown for A2 and A3 — comes from a
production read. The exercise extent A4 sends is the commitment's own authoritative Remaining Entitlement
rather than a hardcoded quantity.

### D5 — The canonical ordinary-swap price limit comes from pinned Solidity, not from JavaScript

The canonical ordinary protected swap uses `sqrtPriceLimitX96 = TickMath.getSqrtPriceAtTick(tickQ)`, which
keeps a refusal attributable to backing rather than to a service-domain violation. Rather than port
Uniswap tick math into JavaScript, `DemoActions.s.sol` exposes the value through the pinned `TickMath`, the
demo runner captures it, and it reaches the frontend as configuration in the generated manifest.

### D6 — ABIs are read from the compiled Foundry artifacts

The frontend imports `out/**/*.json` artifacts rather than carrying hand-copied ABI fragments, so the
interface it calls cannot drift from the deployed bytecode. `forge build` is therefore a documented
prerequisite of the frontend build. The artifacts are imported with the `with { type: 'json' }` attribute
so that the same modules load in both Vite and plain Node, which is what makes D9 possible.

### D6a — Protocol calls live in `lib/standby.js`, not in the React hook

The four canonical actions and the authoritative reads were moved out of `hooks/useDemoActions.js` into a
plain module with no React dependency. The hook became state management around it. This was done so the
interface and the headless verification command drive the same code rather than two implementations of the
same calls.

### D7a — A3 is submitted, and its reason recovered by replay

An early probe established that Anvil accepts and mines a transaction that reverts rather than refusing it
at the RPC boundary, so the browser path submits A3 for real and reads back a reverted receipt. A receipt
carries no revert data, so the same call is replayed with `eth_call` against the block before it, and the
returned data is unwrapped through the ERC-7751 wrappers to the Standby error. The demonstration therefore
shows a real on-chain refusal *and* names the reason.

### D7 — Anvil unlocked role accounts, no wallet

The judged demo runs against deterministic local Anvil and sends each action from the account authorized
to perform it (establishment authority, trader, exercise authority) through `eth_sendTransaction` on
unlocked accounts. This keeps the demo deterministic and keeps role separation visible, and it avoids
building a production dApp wallet flow that F10 explicitly does not want.

### D8 — Reset stays environmental

No production reset, restore, or seed function was added or considered. Reset is: stop Anvil, start Anvil,
redeploy, bootstrap.

### D9 — Frontend verification without a browser

Interactive browser automation was proposed and explicitly declined by the user: F10's responsibility is to
implement and verify repository artifacts using the normal development environment, and a browser-facing
frontend does not imply access to a personal browser session. Frontend verification was therefore built
into the repository instead, as `npm run verify:demo` — a Node command that imports the interface's own
`src/lib` modules and drives all four canonical actions against the running chain. Two further checks ran
in this session without a browser: a server-side render of every component with representative props, and a
dev-server fetch of every module and of an `out/` artifact through `/@fs` to confirm the configured file
access resolves.

The interactive browser session that Claude could not perform was subsequently performed by the user against
the same running environment. It is recorded below under **Human interactive browser verification**, and it
supersedes every statement in this log that described that run as outstanding.

### D10 — Vite 7 rather than Vite 5 or Vite 8

The frontend was first built on Vite 5, which `npm audit` reported with two advisories (the esbuild
dev-server issue, dev-only). Vite 8 cleared them but is rolldown-based and stopped tree-shaking the
artifact JSON, tripling the bundle by pulling compiled bytecode into it. Vite 7.3.6 clears the advisories
and keeps the rollup tree-shaking, so it was chosen: `npm audit` reports 0 vulnerabilities and the bundle
stays at ~500 kB. The engine floor this implies (`^20.19 || >=22.12`) is recorded in `package.json` and in
both READMEs.

---

## Files added

- `script/DemoActions.s.sol` — production A1–A4 fallback path.
- `script/demo/run-demo-environment.sh` — deterministic runner: deploy, bootstrap, write the frontend
  manifest. Invokes the canonical scripts; constructs nothing itself.
- `frontend/**` — the authoritative instrumentation described above.
- `README.md` — judge-facing entry point.

## Files changed

- `docs/setup.md` — demo environment, frontend setup, and reproducible run workflow.
- `docs/reports/gas-snapshot.md`, `.gas-snapshot` — refreshed engineering evidence.
- `docs/reports/coverage-summary.md` — refreshed engineering evidence.
- `.gitignore` — the two generated manifest files.
- `docs/prompts/session-17-log.md` — this log.

---

## Deterministic runs performed

Every run below used a freshly restarted Anvil and the canonical runner.

**Run 1 — `DemoActions.run()`, whole sequence in one script invocation.**

```text
bootstrap  S = 80,000        O = 0
A1         S = 80,000        O = 50,000   Remaining 50,000   id 1
A2         S = 65,000        O = 50,000   trader received 15,000   preview S′ 65,000
A3         preview S′ 45,000 vs O 50,000  -> refused by the Standby backing requirement
post-A3    S = 65,000        O = 50,000
A4         S = 15,000        O = 0        Remaining 0   Beneficiary +50,000   exerciser paid 50,627.787984 MockUSTB
```

On-chain state read back afterwards with `cast`: `S = 15000000000`, `O = 0`,
`MockUSDC.balanceOf(beneficiary) = 50000000000`.

**Run 2 — the four stage entrypoints, invoked one at a time**, exactly as `docs/setup.md` documents them.
Same figures, stage for stage. This run exists because those per-stage commands are documented, and a
documented command that has not been executed is not evidence.

**Run 3 — `npm run verify:demo`**, driving the interface's own modules. All 36 checks passed, including:
the production preview predicted `S′ = 45,000`; the refusal decoded as
`StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)`; authoritative state after the
refusal remained 65,000 / 50,000 / 50,000; the Beneficiary received exactly 50,000; the commitment A4
exercised was the one A1 created; and Standby held no protected output at any stage.

**Run 4 — a second `npm run verify:demo`** after the final dependency set was settled, from another fresh
environment. Identical result.

## Failures encountered and corrections

1. **A3 did not throw on submission.** The first probe assumed `writeContract` would reject; Anvil mined
   the transaction and returned a reverted receipt instead. Corrected by reading the receipt status and
   replaying the call to recover the reason (D7a).
2. **`ActionResult` labelled the exerciser's cost bound in the wrong currency** — `maxInput` is MockUSTB
   and was being formatted with the MockUSDC unit. Found by the server-side render check, fixed, and the
   check now asserts the unit.
3. **ESLint could not parse the import attributes** used for the artifacts. Corrected by moving the
   config to `ecmaVersion: 'latest'` and giving `scripts/**` Node globals.

## Regression, gas and coverage evidence

| Command                         | Result                                                       |
| ------------------------------- | ------------------------------------------------------------ |
| `forge fmt --check`             | clean                                                        |
| `forge build --sizes`           | successful; `StandbyHook` 21,996 runtime, 2,580 bytes margin |
| `forge test`                    | 62 suites, 590 passed, 0 failed, 0 skipped                   |
| `FOUNDRY_PROFILE=ci forge test` | 62 suites, 590 passed, 0 failed, 0 skipped                   |
| `forge snapshot`                | 590 entries written to `.gas-snapshot`                       |
| `forge coverage`                | 590 passed under instrumentation                             |
| `npm ci` / `npm run lint` / `npm run build` | clean; 0 npm advisories; bundle 504.63 kB    |

**Gas.** Comparing the refreshed `.gas-snapshot` against the committed post-F8D baseline entry by entry:
**0 of the 454 carried-over deterministic per-test values changed**, and no deployed contract size changed.
Seven fuzz medians moved — six by 1–8 gas, one by 1.1% — alongside a run-count change of 1008 → 1000, which
is sampling rather than gas. The artifact grew from 539 to 590 entries; the 51 additions are the GI and F9
suites, which the committed baseline predated. F10 contributes no entry, because it added no test.

**Coverage.** The Standby protocol core reproduces the entering-F10 baseline exactly: Lines 99.42%
(514/517), Statements 98.52% (532/540), Branches 92.31% (96/104), Functions 100% (107/107). Every `src/`
file is identical to the post-GI measurement except the two mock currencies, which rose from 0% to 50%
because F9's bootstrap-fidelity suite reads their `symbol()` overrides. The repository-level row fell
(96.21% → 90.70% lines) because `script/DemoActions.s.sol` enters the denominators at zero hits: it is an
operational script with no `forge test` caller, verified by execution against a deterministic Anvil
environment instead. Excluding that one file the row is 95.15% lines, in line with previous checkpoints.
Nothing was changed in response to a percentage.

Both reports were refreshed in place with their established methodology: `docs/reports/gas-snapshot.md` and
`docs/reports/coverage-summary.md`.

---

# Required Task Completion Report — Session 17 (F10)

## Files Inspected

Repository: `CLAUDE.md`; `.claude/rules/solidity-style.md`; `.claude/rules/testing.md`;
`docs/project-status.md`; `docs/implementation-plan.md` §20 and §29; `docs/demo-spec.md`;
`docs/context.md`; `docs/economic-agreement.md`; `docs/setup.md`; `docs/reports/gas-snapshot.md`;
`docs/reports/coverage-summary.md`; `docs/prompts/session-14-post-f8d-engineering-baseline.md`;
`docs/prompts/session-15-post-coverage-report.md`; `src/StandbyHook.sol` (read surfaces, service and
commitment types, O2 lifecycle, prospective derivation, error set); `src/ExerciseRouter.sol`;
`src/demo/ActorAwareTestRouter.sol`; `src/mocks/MockFixtureCurrency.sol`; `script/DeployStandbyHook.s.sol`;
`script/DeployDemoEnvironment.s.sol`; `script/BootstrapStandby.s.sol`; `script/helpers/*`;
`test/acceptance/CanonicalStandbyFlow.t.sol`; `test/shared/BaseCanonicalAcceptanceTest.t.sol`;
`foundry.toml`; `remappings.txt`; `.gitignore`; `.github/workflows/ci.yml`.

Pinned dependency source: `v4-core/libraries/StateLibrary.sol` (the `pools[poolId].slot0` layout the
frontend reads), `v4-core/libraries/CustomRevert.sol` (`WrappedError`), `v4-core/libraries/Hooks.sol`
(`HookCallFailed`), `v4-core/libraries/TickMath.sol`.

## Files Changed

**Added**

| File | F10 responsibility |
| ---- | ------------------ |
| `README.md` | Judge-facing entry point: problem, core idea, realization, what the demo proves, how to run it, claim boundary, documentation map. |
| `script/DemoActions.s.sol` | The four canonical judged actions as real production transitions; the non-browser fallback path. |
| `script/demo/run-demo-environment.sh` | Deterministic runner: invokes the canonical deployment and bootstrap scripts, then writes the manifest. Constructs nothing itself. |
| `frontend/` (26 files) | The authoritative instrumentation: 4 components, 3 hooks, 6 lib modules, the verification command, config, and its own README. |

**Modified**

| File | Why |
| ---- | --- |
| `docs/setup.md` | Demo environment, per-stage commands, reset boundary, frontend setup — all executed before being written. |
| `docs/reports/gas-snapshot.md`, `.gas-snapshot` | Final gas evidence refreshed with the established methodology. |
| `docs/reports/coverage-summary.md` | Final coverage evidence refreshed with the established methodology. |
| `.gitignore` | `demo.env` and `frontend/public/standby-demo.json` are generated. |
| `docs/prompts/session-17-log.md` | This log. |

**No file under `src/` was changed, added, or deleted. No existing script and no test was modified.**

## Requirements Implemented

`implementation-plan.md` §20.2–§20.9 (frontend organization, authoritative displayed state, read/re-render
rule, four canonical actions, the three demo scripts, A3 prospective presentation, A4 presentation, demo
reset) and the session prompt's §5–§19. `demo-spec.md` DEMO-OBS-1 through DEMO-OBS-7, DEMO-AC-7,
DEMO-GATE-1 through DEMO-GATE-3, §14 interface boundary, §15 claim boundaries, and §19 submission
documentation handoff.

## Tests Added or Changed

**No Solidity test was added, changed, weakened, or removed.** F10 exposes the already-accepted realization;
recreating F9's acceptance evidence as a new suite is exactly what the slice must not do.

One repository verification command was added, `frontend`'s `npm run verify:demo`
(`frontend/scripts/verify-demo.mjs`). It proves that the interface's own modules reach the intended
production paths: it imports `src/lib/standby.js`, `src/lib/rpc.js`, `src/lib/errors.js` and
`src/lib/contracts.js` unchanged and drives A1–A4 against a running deterministic environment, checking the
canonical history in 36 assertions — including that A3's refusal decodes to
`StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)` and that authoritative state after
it is unchanged. It is a check on frontend code, not protocol evidence.

## Commands Run

```bash
# Solidity regression
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test

# Final engineering evidence
forge snapshot
forge coverage
forge coverage --report debug

# Deterministic demo, four times from a fresh Anvil
anvil
./script/demo/run-demo-environment.sh
source demo.env
forge script script/DemoActions.s.sol --rpc-url $RPC_URL --broadcast --unlocked --sender $STANDBY_DEPLOYER
forge script script/DemoActions.s.sol --sig 'admitCommitment()'                --rpc-url $RPC_URL --broadcast --unlocked --sender $STANDBY_DEPLOYER
forge script script/DemoActions.s.sol --sig 'compatibleOrdinarySwap()'         --rpc-url $RPC_URL --broadcast --unlocked --sender $STANDBY_DEPLOYER
forge script script/DemoActions.s.sol --sig 'attemptDestructiveOrdinarySwap()' --rpc-url $RPC_URL
forge script script/DemoActions.s.sol --sig 'exerciseCommitment(uint256)' 1    --rpc-url $RPC_URL --broadcast --unlocked --sender $STANDBY_DEPLOYER
cast call <hook> 'supportingCapacity()(uint256)' / 'aggregateObligation()(uint256)' / 'commitment(uint256)(...)'

# Frontend
cd frontend && npm ci && npm run lint && npm run build && npm audit && npm run dev && npm run verify:demo
```

## Results

| Check | Result |
| ----- | ------ |
| `forge fmt --check` | clean |
| `forge build --sizes` | successful; `StandbyHook` 21,996 runtime / 23,022 initcode / 2,580 margin |
| `forge test` | 62 suites, **590 passed, 0 failed, 0 skipped** |
| `FOUNDRY_PROFILE=ci forge test` | 62 suites, **590 passed, 0 failed, 0 skipped** |
| `forge coverage` | 590 passed under instrumentation |
| `npm ci` | 333 packages, **0 vulnerabilities** |
| `npm run lint` | clean |
| `npm run build` | successful, 504.63 kB |
| `npm run dev` | serves; every module and an `out/` artifact resolve through the configured file access |
| `npm run verify:demo` | **36 of 36 canonical checks passed** |
| Deterministic demo runs | four fresh runs, identical canonical history |

## Gate Evidence

**Implemented and verified by execution:** the deterministic environment and its exact canonical pre-A1
state; the non-browser A1–A4 path, whole-sequence and stage-by-stage; the A3 rejection carrying both
compared quantities and the unchanged post-revert state; the A4 exercise with exactly +50,000 MockUSDC to
the authoritative Beneficiary and the 15,000 / 0 / 0 terminal state; the frontend's own protocol modules
driving all four actions against the real chain; the frontend install, lint, build and dev-server paths;
every command written into `README.md` and `docs/setup.md`; the full Solidity suite under both profiles; and
refreshed gas and coverage evidence.

**Implemented and verified without a browser:** the four components and the App shell render correctly with
representative props under `react-dom/server`, including the A3 evidence separation (authoritative 65,000,
proposed 20,000, prospective 45,000 labelled as never-authoritative, the decoded reason, and the unchanged
re-read) and the A4 delivery block.

**Verified interactively by the user, after this report was first written:** the complete judged browser
workflow — canonical pre-A1 state, A1, A2, a page reload, A3 with its decoded backing rejection, and A4 with
exact Beneficiary delivery. Recorded in full under **Human interactive browser verification** below. This
supersedes the "still unverified" statement that stood here in the original report.

## Known Limitations / Blockers

1. **`script/DemoActions.s.sol` has no `forge test` coverage** and is verified by execution instead. This is
   deliberate and is recorded in `docs/reports/coverage-summary.md`.
2. **Carried forward from F0, unchanged:** `HelperConfig` resolves infrastructure only for chain id `31337`.
   F10 depends on no public network, so this blocks nothing here.
3. The demo runner assumes the deterministic default Anvil accounts and an auto-mining node.

## Scope Check

Work remained inside the authorized F10 slice. No production semantics were touched: `src/` is byte-identical
to `ab67d5e`, and so are all pre-existing scripts and tests. No downstream slice was started; F9T was not
begun. Nothing in `docs/project-status.md` was changed.

Two changes deserve to be named explicitly against the boundary, since neither is literally in the §12 list
of three scripts:

- `script/demo/run-demo-environment.sh` — environment plumbing that invokes the canonical scripts and
  records their output. It deploys nothing, configures nothing, and decides no economic fact.
- `frontend/scripts/verify-demo.mjs` — a verification command for frontend code, not a second demo path.

## Proposed Gate Assessment

**PENDING — independent G10 review.**

Every G10 implementation and verification requirement now has evidence, including the subsequently completed
interactive browser session. The protocol evidence, deterministic reproduction, fallback path, documentation,
engineering evidence, and assembled browser workflow have been executed rather than merely asserted. This
remains an implementation-side evidence assessment only; G10 is not closed here.

### G10 evidence matrix

| # | Requirement | Evidence |
| - | ----------- | -------- |
| 1 | Canonical Hook deployment path | `DeployDemoEnvironment` inherits `StandbyHookDeployment`, unmodified; runner invokes it |
| 2 | Real PoolManager and Standby contracts on deterministic Anvil | four live runs; addresses in the generated manifest |
| 3 | Bootstrap reaches exact canonical pre-A1 state | `S = 80,000`, `O = 0`, `nextCommitmentId = 1`, checked by bootstrap itself and read back |
| 4 | No privileged demo economic state | no `vm.store`, no setter, no `src/` change; every step an ordinary external call |
| 5 | UI exposes the four canonical actions | `ActionPanel`; render-verified, and all four performed in the browser by the user |
| 6 | S/O/Remaining/balance/tick are authoritative reads | read map in `frontend/README.md`; exercised by `verify:demo` |
| 7 | UI does not derive or persist S or O | no economic computation and no storage in `frontend/src` |
| 8 | Reload reconstructs truth from chain | no persistence exists to reconstruct from; reload after A2 performed in the browser and the authoritative state and commitment record redrew correctly |
| 9 | Post-transaction display from authoritative rereads | `lib/standby.js` re-reads after every action; `refreshKey` re-runs both read hooks |
| 10 | A1 shows 80k / 50k / 50k | observed in three script runs and in the browser |
| 11 | A2 shows 65k / 50k / 50k | observed in three script runs and in the browser |
| 12 | Compatible shared use made clear | A2 copy, `ActionResult`, README |
| 13 | A3 preview yields prospective 45k | production preview, observed in three runs |
| 14 | Prospective distinguished from authoritative 65k | separate labelled blocks; render-verified and observed in the browser |
| 15 | `45k < 50k` legible | rendered comparison; render-verified |
| 16 | Specific Standby backing rejection | `StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)`, decoded and displayed in the browser |
| 17 | Not an unrelated failure | script asserts the exact wrapped encoding; UI reports anything else as not the backing rejection |
| 18 | Post-revert state 65k / 50k / 50k | re-read in every run |
| 19 | A4 uses the real ExerciseRouter/O2 path | `ExerciseRouter.exercise` in both paths |
| 20 | Same commitment A1 created | id carried in memory by the script; read from the enforcement index by the UI; asserted |
| 21 | Beneficiary +50,000 exactly | balance delta measured before and after; shown in the browser as 0 -> 50,000, delivered 50,000 |
| 22 | Final 15k / 0 / 0 | read back with `cast` and by `verify:demo` |
| 23 | Fulfillment claims from transaction + state + balance | receipt, authoritative re-read, and balance delta together |
| 24 | Reset is environmental | documented; performed four times |
| 25 | No production demo-reset/backdoor | none added; `src/` unchanged |
| 26 | `DemoActions.s.sol` reproduces A1–A4 without the frontend | verified whole-sequence and stage-by-stage |
| 27 | Fresh deterministic run reproduces the sequence | four fresh runs |
| 28 | README/setup instructions accurate | every documented command executed before being documented |
| 29 | README communicates problem, solution, architecture, flow, claims, docs | `README.md` |
| 30 | Wording inside frozen claims | README "What Standby does not claim" and the UI footer mirror `demo-spec.md` §15.2 |
| 31 | Gas/coverage as engineering evidence | both reports carry the non-normative status header |
| 32 | No public testnet required | none used |
| 33 | No new protocol semantics | `src/` unchanged |
| 34 | No second economic source of truth | every economic value read from a production surface |
| 35 | No demo-only economic backdoor | none |
| 36 | No F0–F9/GI responsibility reimplemented | deployment, bootstrap and every test untouched |
| 37 | No prior gate requires reopening | nothing discovered |

## Recommended Next Step

The interactive browser click-through recommended here was performed by the user and is recorded below, so
no F10 implementation work remains outstanding. The implementation and its evidence are presented for
independent G10 review. Not performed unless instructed: anything beyond that review, and F9T in particular.

## Prompt Audit

The session prompt `docs/prompts/session-17-f10-demo-submission-readiness.md` was the initiating artifact.
**One material follow-up instruction** was received and is recorded as **D9** above: browser access was
declined, with the direction that F10 be implemented and verified through the normal development environment
rather than through an interactive browser session. Its implementation consequence was the repository
verification command `npm run verify:demo`, the server-side render checks, and the recording of the browser
click-through as outstanding at that time — since superseded by the user's own interactive run, recorded
below.

**Material prompts recorded: 1** at the time of the original report; **2** including the correction prompt
recorded below.

---

# Human interactive browser verification

Performed by the user against the running deterministic environment after Claude's original completion
report, and recorded here as contemporaneous evidence. This is the one item Claude could not execute, and it
supersedes every earlier statement in this log describing it as outstanding.

Observed in the browser, in order, over one live pool and one commitment:

```text
canonical pre-A1 state observed in the browser

A1 executed successfully:
S = 80,000
O = 50,000
Remaining = 50,000

A2 executed successfully:
S = 65,000
O = 50,000
Remaining = 50,000

browser page reloaded after A2

authoritative post-A2 state reconstructed correctly from chain

Commitment #1 reconstructed from chain with:
Original Entitlement = 50,000
Remaining Entitlement = 50,000
Beneficiary
Exercise Authority
Exercisable From
Valid Until

A3 submitted through the browser

specific Standby backing rejection displayed:
StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)

prospective S' = 45,000 explicitly distinguished from authoritative state

post-revert authoritative state remained:
S = 65,000
O = 50,000
Remaining = 50,000

A4 executed successfully through the browser
Beneficiary MockUSDC balance:
before = 0
after = 50,000
delivered = 50,000

final authoritative state:
S = 15,000
O = 0
Remaining = 0
Backing = 15,000 >= 0
```

The browser additionally displayed the configured commitment validity window and the bounded demo claim
footer.

What this establishes that the headless evidence did not: the assembled browser session itself. The four
canonical actions were exercised through the interface rather than through its modules; the reload after A2
reconstructed both the authoritative state and the commitment record from the chain alone, with no
client-side persistence to fall back on; and the A3 evidence separation — authoritative, proposed,
prospective, result — was legible as rendered rather than only as asserted in a render check.

---

# Correction Report — Session 17 presentation and stale-evidence corrections

Initiated by `docs/prompts/session-17-correction.to-presentation-and-staleevidence.md` following the
independent F10/G10 review, which found one presentation-fidelity issue and one stale evidence-record item.

## Files Changed

| File | Change |
| ---- | ------ |
| `frontend/src/App.jsx` | Header wording: `every value below is read from this chain` → `authoritative economic state below is read from this chain`. One string in the header line; no other change. |
| `README.md` | Replaced the sentence `The interface displays no economic value it did not read from the chain.` with wording that states the frontend derives no authoritative economic truth of its own, that every authoritative economic value comes from a deployed-contract read, and that proposed transaction facts are canonical demo configuration presented separately as proposals rather than as state. |
| `docs/prompts/session-17-log.md` | Recorded the human interactive browser verification; superseded the stale "still unverified" statements in D9, the Gate Evidence section, Known Limitations, the G10 matrix rows 5, 8, 10, 11, 14, 16 and 21, the Recommended Next Step, and the Prompt Audit. |

Nothing else changed. `src/**`, every Solidity test, every script, protocol semantics, demo transaction
semantics, deployment and bootstrap semantics, and `docs/project-status.md` are all untouched.

## Why the original wording was wrong

The header claim was broader than the implementation. The page displays four distinct evidence classes, and
the implementation already separates them — authoritative economic state, proposed transaction facts,
prospective production-derived state, and transaction or revert evidence. Requested swap quantities, the
commitment window, and the exerciser's `maxInput` cost bound are proposed transaction facts drawn from the
canonical demo configuration in the generated manifest; they are not read from chain state and were never
presented as state. The wording overstated a property the page correctly implements, so the correction is to
the sentence, not to the behavior. The README sentence carried the same overstatement and is corrected the
same way.

## Verification

```bash
cd frontend
npm run lint     # clean
npm run build    # successful — 504.64 kB, built in 1.48s
```

No Solidity regression was rerun, and none is required: no Solidity file, configuration file, or test
changed. The corrections touch one JSX string, one README paragraph, and this log.

## Scope Check

Within the correction prompt's boundary. No economic behavior, transaction construction, protocol read,
state handling, or layout was changed beyond the wording itself. The README was not broadened. G10 is not
declared passed, and `docs/project-status.md` was not modified.

## Gate Status

Unchanged and not self-assessed here. Gate closure remains with the independent reviewer. With the human
browser verification now recorded, no F10 implementation or verification item is outstanding.

## Prompt Audit — correction

Material follow-up instruction recorded: the correction prompt itself, narrowing scope to the two wording
corrections and the evidence-record update.

A final documentation-only follow-up
(`docs/prompts/session-17-small-documentation-change.md`) then corrected the stale original **Proposed Gate
Assessment**, which still described the interactive browser session as not performed after that session had
been completed and recorded. That paragraph now reads **PENDING — independent G10 review**. Nothing else was
changed: no production code, frontend code, script, test, README, setup documentation, gas or coverage
report, `docs/project-status.md`, the Human Interactive Browser Verification section, or any other G10
evidence. No verification was rerun, none being applicable to a wording correction inside this log.

**Material prompts recorded across Session 17 at that point: 3.**

---

# Post-G10 judge-facing documentation follow-up

Recorded as audit chronology only. This entry adds to the Session 17 record; it rewrites nothing above it.

Independent review of the judge-facing README artifacts — carried out after G10 had already been
independently determined — concluded that the root README would communicate the accepted behavior better
with two diagrams, and identified two claim-boundary statements in `frontend/README.md` that were broader
than the implementation warrants.

**Diagram provenance.** Both diagrams were derived outside this session and supplied to Claude as frozen
Mermaid source. Claude was not asked to design either one, and did not. Diagram 1 — *Standby Execution
Paths* — was iteratively derived and then verified against the completed F8A–F8D execution responsibilities
before being frozen: Hook-owned authorization, the exact-output protected execution and its evidence, input
settlement with direct Beneficiary delivery, and causal finalization. Diagram 2 — *Canonical Demo Sequence*
— reflects the already accepted canonical A1–A4 economic sequence and introduces no quantity or transition
that the accepted evidence does not already carry.

Before insertion, a separate visual-verification instruction
(`docs/prompts/session-17-diagram-render-display.md`) had both frozen sources rendered for inspection
without modifying any repository file. Both parsed and rendered — Diagram 1 as `sequence`, Diagram 2 as
`flowchart-v2` — and the rendered output carried every participant, node, label and quantity of the supplied
source, including the `45k < 50k` label whose `<` was the one character at risk of being read as markup.

**Changes made.**

| File | Change |
| ---- | ------ |
| `README.md` | New `## How Standby Executes` section carrying Diagram 1 and its two supplied paragraphs, placed after `## The realization` so the participants it names are already introduced, and before the canonical demo and all run material. Diagram 2 added inside the existing `## What the canonical demo proves` section, immediately after the canonical state table, with no duplicate heading. |
| `frontend/README.md` | The reload claim now states that a reload reconstructs authoritative economic state from the chain while proposed demo transaction facts are loaded separately from the generated canonical demo manifest. The ABI claim now states that the interface uses ABI definitions from the same Foundry build artifacts as the canonical deployment, avoiding a separately maintained ABI that could drift, rather than asserting that it can never call a different interface. |
| `docs/prompts/session-17-log.md` | This entry. |

Both Mermaid sources were extracted programmatically from the instruction rather than retyped, and the
embedded blocks were checked byte-for-byte against them. No participant, node, arrow, label, quantity,
ordering or state transition differs from the frozen source, and no Mermaid styling, theme, class, color,
icon, subgraph or initialization directive was added.

**What did not change.** No production code, test, script, frontend source, frontend package or
configuration file, deployment or bootstrap artifact, `docs/setup.md`, `.gas-snapshot`, gas or coverage
evidence, canonical specification artifact, or `docs/project-status.md`. No implementation defect was
identified in the course of this work — the review concerned judge-facing representation, not behavior.

**Verification.** None was rerun, and none was required: this follow-up is documentation-only and changes
no executable surface. The verification performed was inspection of the resulting diff against the frozen
diagram fidelity requirements and the claim-boundary requirements.

**Gate boundary.** The independently determined result — F10 COMPLETE, G10 PASS / CLOSED — was neither
reopened nor reassessed here, and nothing in this entry constitutes a gate judgment. F9T was not begun.

**Material prompts recorded across Session 17: 5.** In order, and excluding the initiating F10 session
prompt itself:

1. the browser-access direction recorded as D9;
2. `session-17-correction.to-presentation-and-staleevidence.md`;
3. `session-17-small-documentation-change.md`;
4. `session-17-diagram-render-display.md` — added a visual-verification requirement before insertion;
5. `session-17-add-diagram-to-readme.md` — this documentation follow-up.

---

# Repository licensing hygiene

Recorded as audit chronology only. This entry adds to the Session 17 record; it rewrites nothing above it.

A root-level standard MIT `LICENSE` was added as final repository / submission hygiene, carrying
`Copyright (c) 2026 Gary Kocsis`. It makes repository-level licensing explicit and is consistent with the
`// SPDX-License-Identifier: MIT` declarations the Standby-owned Solidity sources already carry.

No source licensing semantics changed: no SPDX identifier was touched, and no Solidity file, test, script,
frontend file, README, canonical specification or design document, or `docs/project-status.md` was modified.
The only files affected are the new `LICENSE` and this log entry.

No verification suite was rerun. The change is non-executable — a text file at the repository root that no
build, test, script, or runtime path reads — so there is nothing for the Solidity, frontend, gas, coverage,
invariant, or demo verification to re-establish.

F10 COMPLETE / G10 PASS / CLOSED was not reopened or reassessed, and F9T was not begun.

**Material prompts recorded across Session 17: 6.** Added to the list above:

6. `session-17-add-MIT-license.md` — this licensing-hygiene follow-up.

---

# Status recording authorized

Recorded as audit chronology only. This entry adds to the Session 17 record; it rewrites nothing above it.

The post-G10 judge-facing documentation follow-up was independently reviewed and accepted. Both frozen
Mermaid diagrams were confirmed present in the root `README.md` in their intended locations — Diagram 1
under `## How Standby Executes`, Diagram 2 within `## What the canonical demo proves`. The subsequent MIT
repository-licensing follow-up was also independently reviewed and accepted.

The independently reviewed result — **F10 COMPLETE / G10 PASS / CLOSED** — was then authorized for status
recording, and `docs/project-status.md` was updated status-only: header fields, the §2 current-objective
statements, the §3 implementation-ladder F10 row, the §10 current blocker, the §18 next action, and the §19
handoff summary. No implementation detail, design commentary, test summary, gate reasoning, or retrospective
observation was added to that document.

F9T — Public Testnet Deployment — remains **OPTIONAL / OFF CRITICAL PATH**. It was not made the next
required slice, current blocker, gate, or submission prerequisite, and it was not begun.

No gate was independently assessed or closed by Claude. This entry records an already-authorized result.

**Material prompts recorded across Session 17: 7.** Added to the list above:

7. `session-17-project-status-update.md` — this status-only recording instruction.
