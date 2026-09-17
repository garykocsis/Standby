# Session 21 — F9T Public Testnet Deployment (Base Sepolia) — Implementation Log

Claude implementation chronology for the Session 21 F9T task, initiated from
`docs/prompts/session-21-f9t-base-sepolia-deployment.md`. Audit artifact only; it defines no protocol semantics, no
permanent operating behavior, and no permanent Solidity/testing conventions. It closes no gate. F9T is
post-submission supplementary public-network evidence; the canonical judged acceptance environment remains
deterministic local Anvil.

No secret is recorded in this log. Public addresses and transaction hashes are evidence, not secrets.

---

## Repository state entering Session 21

Branch: `feat/f9t-base-sepolia-deployment` (non-main). Branch-safety check (session prompt §3) passed; no branch
was created, switched, merged, or deleted by Claude.

Working tree clean except the untracked session prompt `docs/prompts/session-21-f9t-base-sepolia-deployment.md`.

Last commit: `4673b02 docs: finalize ETHOnline submission readiness (#23)`.

`docs/project-status.md` records F0–F10 COMPLETE with every gate closed (last closed gate: G10). F9T is recorded as
`OPTIONAL / OFF CRITICAL PATH`.

Toolchain: `forge 1.3.5-stable`, `cast 1.3.5-stable`.

---

## Files inspected (pre-implementation)

```text
CLAUDE.md, .claude/rules/solidity-style.md, .claude/rules/testing.md
docs/prompts/session-21-f9t-base-sepolia-deployment.md
docs/project-status.md
docs/prompts/session-20-log.md                      (log convention)
docs/implementation-plan.md §21 (F9T)
docs/uniswap-v4-realization.md §2.4, §8.5–8.12, §9
docs/setup.md                                       (implementation sequence, demo environment sections)
foundry.toml, remappings.txt, .gitignore, `forge remappings`
script/DeployStandbyHook.s.sol
script/DeployDemoEnvironment.s.sol
script/BootstrapStandby.s.sol
script/DemoActions.s.sol
script/demo/run-demo-environment.sh
script/helpers/HelperConfig.s.sol, NetworkConfig.sol, StandbyEnvironment.sol,
               StandbyFixtureConfig.sol, DeterministicFixtureDeployer.sol
src/StandbyHook.sol          (constructor, configureAndActivate, O3 swap/liquidity enforcement, actor
                              attribution, prospective swap derivation, price-limit reproduction, capacity
                              derivation, commitment-term validation)
src/ExerciseRouter.sol
src/interfaces/IActorAwarePeriphery.sol
src/EligibilityRegistry.sol, src/mocks/*
test/integration/StandbyHookDeployment.t.sol, test/shared/BaseCanonicalAcceptanceTest.t.sol (consumers)
lib/v4-hooks-public/lib/v4-periphery/src/V4Router.sol
lib/v4-hooks-public/lib/v4-periphery/src/PositionManager.sol (msgSender, action dispatch)
lib/v4-hooks-public/lib/v4-periphery/src/interfaces/IV4Router.sol
lib/v4-hooks-public/lib/v4-periphery/src/libraries/Actions.sol, CalldataDecoder.sol
lib/v4-hooks-public/lib/v4-periphery/lib/permit2/src/interfaces/IAllowanceTransfer.sol
```

---

## Accepted-architecture facts established from source (repository is authoritative)

1. The trusted ordinary-swap and liquidity perimeters are **StandbyHook constructor arguments** (immutable,
   participating in the mined init code), not `configureAndActivate` arguments. The official Universal Router
   and PositionManager are therefore bound at Hook deployment; `configureAndActivate` validates they are nonzero.
2. `ExerciseRouter(StandbyHook)` resolves its PoolManager from the Hook, so the ExerciseRouter is deployed after
   the Hook (session prompt §12 defers to actual constructor dependencies).
3. The canonical Hook deployment procedure is `StandbyHookDeployment.deployStandbyHook(IPoolManager,
   create2Deployer, configurationAuthority, trustedUniversalRouter, trustedPositionManager)`, mined with the
   pinned `HookMiner` against Foundry's `CREATE2_FACTORY` under broadcast.
4. Currency ordering is guaranteed by `DeterministicFixtureDeployer` (CREATE2 salt search + asserted ordering).
5. The Hook authenticates `sender == i_trustedUniversalRouter` / `i_trustedPositionManager` before calling
   `IActorAwarePeriphery(sender).msgSender()`; `hookData` is ignored.
6. The Hook reproduces v4 price-limit entry conditions (`limit > MIN_SQRT_PRICE` for zeroForOne). The official
   V4Router passes `MIN_SQRT_PRICE + 1` for zeroForOne, which satisfies it.

---

## External infrastructure preflight (read-only, before any Standby state)

RPC endpoint supplied from the git-ignored `.env`. `.env` confirmed git-ignored (`git check-ignore .env`).

```text
chainId                                   84532
block at preflight                        46835306

PoolManager       0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408   code 24009 bytes
Universal Router  0x492e6456d9528771018deb9e87ef7750ef184104   code 19540 bytes
PositionManager   0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80   code 23877 bytes
Permit2           0x000000000022D473030F116dDEE9F6B43aC78BA3   code  9152 bytes
StateView         0x571291b572ed32ce6751a2cb2486ebee8defb9b4   code  3531 bytes
V4 Quoter         0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba   code  5820 bytes
CREATE2 factory   0x4e59b44847b379578588920cA78FbF26c0B4956C   code    69 bytes

UniversalRouter.poolManager()          0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408   matches
UniversalRouter.V4_POSITION_MANAGER()  0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80   matches
UniversalRouter.msgSender() (idle)     0x0000000000000000000000000000000000000000   surface present
PositionManager.poolManager()          0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408   matches
PositionManager.permit2()              0x000000000022D473030F116dDEE9F6B43aC78BA3   matches
PositionManager.msgSender() (idle)     0x0000000000000000000000000000000000000000   surface present

Rejected historical Universal Router 0x95273d871c8156636e114b63797d78D7E1720d81
  poolManager()          0x7Da1D65F8B249183667cdE74C5CBD46dD38AA829   != frozen PoolManager
  V4_POSITION_MANAGER()  0xcDbe7b1ed817eF0005ECe6a3e576fbAE2EA5EAFE   != frozen PositionManager
Not introduced: Universal Router 0x8B844f885672f333Bc0042cB669255f93a4C1E6b
  poolManager()          0xf7F5aB3DcA35e17dE187b459159BC643853B3c67   != frozen PoolManager

Deployer 0x193D1F3E085efc80e1027891FaA770E81ECC4A1d   balance 0.5 ETH   nonce 0
```

### Finding — deployed Universal Router V4 swap-parameter ABI predates pinned v4-periphery

Pinned v4-periphery `07336f2` `IV4Router.ExactOutputSingleParams` carries `uint256 minHopPriceX36` (added by
v4-periphery PR #516). The deployed Universal Router bytecode contains the selectors of `execute(bytes,bytes[],
uint256)`, `msgSender()`, `poolManager()`, `V4TooMuchRequested`, `V4TooLittleReceived`, `SliceOutOfBounds`, but
**none** of the error selectors introduced alongside `minHopPriceX36` (`V4TooMuchRequestedPerHopSingle`,
`V4TooLittleReceivedPerHopSingle`, `InvalidHopPriceLength`) nor `V4ExactOutputUnfilled`. The deployed V4Router
therefore decodes the earlier five-field `ExactOutputSingleParams {poolKey, zeroForOne, amountOut,
amountInMaximum, hookData}`.

Consequence: the pinned `IV4Router` struct cannot be used to encode calldata for the frozen deployed Router. The
Universal Router is not a pinned dependency at all, so invoking it already requires a narrow script-side
interface (session prompt §24 authorizes one). The adapter encodes the deployed Router's own ABI; it upgrades no
dependency and changes no Standby semantics. Compatibility is to be proven empirically against the real deployed
bytecode on a Base Sepolia fork before any live broadcast.

### Operational incident — RPC credential echoed into session tool output

During the read-only preflight a mis-split shell argument caused `cast` to echo the full RPC URL, including its
provider API key, into Claude's session tool output. It was not written to any repository file, log, or
evidence artifact. All subsequent RPC access supplies the endpoint through the `ETH_RPC_URL` environment variable
so it does not appear in command arguments. Recommendation reported to the user: rotate the provider key.

---

## Implementation decisions

1. **Base Sepolia configuration lives in the existing resolver.** `HelperConfig.getNetworkConfig()` gains a Base
   Sepolia branch returning the frozen PoolManager only after `validateBaseSepoliaInfrastructure()` passes. A new
   `getPublicPeripheryConfig()` returns the frozen official periphery (Base Sepolia only; the local environment
   is rejected). `NetworkConfig` is unchanged; a separate `PublicPeripheryConfig` struct is added beside it. The
   Anvil branch is behaviorally unchanged.
2. **Preflight** (G9T-1..5): chain id; code at PoolManager, Universal Router, PositionManager, Permit2, StateView,
   Quoter; UR→PoolManager, UR→PositionManager, PositionManager→PoolManager, PositionManager→Permit2 bindings; a
   readable `msgSender()` on both perimeters. Unreadable bindings are reported as mismatches against zero.
3. **Narrow periphery adapter** (`script/helpers/PublicPeriphery.sol`): local `IPublicPeripheryBindings`
   (`V4_POSITION_MANAGER()`, `permit2()` — not declared on any pinned interface), `IDeployedUniversalRouter`
   (`execute`), `IPermit2Allowance` (`approve`, the pinned Permit2 signature), and two calldata libraries. The
   Universal Router library encodes the deployed router's five-field `ExactOutputSingleParams` (see the ABI
   finding above) with pinned `Actions` constants `SWAP_EXACT_OUT_SINGLE / SETTLE_ALL / TAKE_ALL`. The
   PositionManager library encodes pinned `MINT_POSITION / SETTLE_PAIR`. No dependency changed.
4. **Canonical procedures reused by inheritance, canonical files untouched.**
   `DeployBaseSepoliaEnvironment is StandbyHookDeployment` (canonical HookMiner/CREATE2 procedure and validation;
   ordered fixture deployer; no `ActorAwareTestRouter`). `BootstrapBaseSepolia is BootstrapStandby` reuses
   `canonicalPoolKey`, `_initializeCanonicalPool`, `_activateCanonicalService`, `_seedCanonicalEligibility`,
   `_requireCanonicalBootstrapState`; only funding/approvals (Permit2) and the liquidity mint (official
   PositionManager) are public-periphery-specific. `BaseSepoliaActions is DemoActions` reuses
   `_a1AdmitCommitment`, `_a4ExerciseCommitment`, `_requireStandbyBackingRejection`, and the reporters; only A2/A3
   are sent to the official Universal Router. `DeployDemoEnvironment`, `BootstrapStandby`, `DemoActions`,
   `DeployStandbyHook`, and every `src/` file are unmodified.
5. **Manifest reuse.** The public scripts use the canonical `StandbyEnvironment` so the inherited procedures apply
   unchanged; its two `ActorAwareTestRouter` fields are set to `address(0)` (none is deployed, none is reachable).
6. **Distinct role accounts from one funded key.** The canonical fixture requires seven distinct role accounts.
   One funded key was supplied, so each role key is derived in-script as
   `keccak256(abi.encode(keccak256("standby.f9t.base-sepolia.role"), rootKey, roleName)) mod (n-1) + 1` and
   registered with `vm.rememberKey`; the Beneficiary never signs. Nothing derived is logged or persisted.
   Bootstrap tops each signing role up to 0.002 ETH for gas.
7. **A3 is a simulated attempt against live state** (identical to canonical `DemoActions` A3). The official router
   hands the PoolManager `MIN_SQRT_PRICE + 1`; the prospective check uses exactly that proposal.
8. **Stage-by-stage runner** `script/testnet/run-base-sepolia.sh` (`preflight|deploy|bootstrap|a1|a2|a3|a4|verify
   S O R`), modeled on `script/demo/run-demo-environment.sh`; `--slow` so multi-sender transactions are mined in
   order. Its output filter removes URLs and every execution-trace line, because a failing script prints its trace
   at default verbosity and cheatcode traces can carry the root key. Generated manifest `base-sepolia.env` is
   git-ignored alongside `demo.env`.
9. **Evidence artifact** in the existing `docs/reports/` convention.

---

## Local verification before live broadcast

```text
forge fmt --check                                              clean
forge build                                                    Compiler run successful
forge test --match-path test/unit/BaseSepoliaInfrastructure.t.sol     13 passed, 0 failed, 0 skipped
forge test --match-path test/integration/StandbyHookDeployment.t.sol  15 passed, 0 failed, 0 skipped
                                                               (proves HelperConfig growth keeps DeployStandbyHook
                                                                within the init-code limit)
forge test                                                     603 passed, 0 failed, 0 skipped (63 suites)
                                                               (accepted baseline 590 + 13 new F9T unit tests)
```

## Pre-broadcast rehearsal on a local fork of live Base Sepolia

`anvil --fork-url <Base Sepolia> --port 8546` (chain id 84532; the real deployed PoolManager, Universal Router,
PositionManager, Permit2 bytecode), then the runner stage by stage, with rehearsal broadcast records and manifest
redirected to the session scratchpad so no rehearsal record enters `broadcast/`.

First attempt: `forge script` did not take the endpoint from `ETH_RPC_URL` and executed on a plain local EVM
(chain id 31337), where `HelperConfig` correctly refused with `HelperConfig__UnsupportedNetwork(31337)`. That
failure printed a call trace containing cheatcode lines; the scratch log was checked by count only and deleted,
and the runner was changed to pass `--rpc-url` explicitly and to strip trace lines. A second harness issue (zsh
not word-splitting a `verify S O R` stage string) produced a usage exit, not a script failure.

Rehearsal result (all stages exit 0):

```text
deploy     MockUSTB 0x6334956A63F676eFc4f44cC330AA0F0546d4F6c8 < MockUSDC 0xeC64E378231542Fdd2Eedf2a1763a041C2Dda523
           Hook 0x92E89Da9FE8A103f4864914b268Ec364f6458AC0 (low bits 0x0AC0)
bootstrap  S = 80,000,000,000   O = 0   nextCommitmentId = 1
A1         commitment 1         S = 80,000,000,000   O = 50,000,000,000   Remaining = 50,000,000,000
verify     passed
A2         official Universal Router; prospective S' = 65,000,000,000; trader received 15,000,000,000
           S = 65,000,000,000   O = 50,000,000,000
verify     passed
A3         official Universal Router; current S 65,000,000,000; prospective S' 45,000,000,000; O 50,000,000,000
           rejected with exactly WrappedError(hook, beforeSwap, InsufficientProspectiveBacking(45e9, 50e9), HookCallFailed)
           — the deployed router bubbles the Hook revert unwrapped
verify     passed (S 65,000,000,000 / O 50,000,000,000 / Remaining 50,000,000,000)
A4         Beneficiary delivered 50,000,000,000; exerciser paid 50,627,787,984 MockUSTB
           S = 15,000,000,000   O = 0   Remaining = 0
verify     passed (includes Hook and ExerciseRouter MockUSDC balance = 0)
secret scan of rehearsal log: hex key 0, decimal key 0, URLs 0, cheatcode trace lines 0
```

The rehearsal empirically confirms the deployed Universal Router ABI finding: the five-field encoding executes
the canonical exact-output swap exactly.

---

## Live Base Sepolia execution

Full address, transaction, and state tables are recorded in `docs/reports/f9t-base-sepolia-deployment.md`; the
contemporaneous essentials follow.

Pre-broadcast: deployer `0x193D1F3E085efc80e1027891FaA770E81ECC4A1d`, nonce 0, 0.5 ETH, chain id 84532. Every live
forge log was scanned by count for the hex root key, the decimal root key, and URLs: all zero at every stage. The
broadcast JSON records contain no URL or key.

### Deploy (blocks 46836418–46836422, all receipts `0x1`)

```text
DeterministicFixtureDeployer 0xc0e6b70c8ff75962541183fdc247e7b07ad6b70b  tx 0x9750b0942f66b0cbeaf546a840e070d1cf8831da8974307f4b6a118ed34083c8
MockUSTB (currency0)         0x6334956A63F676eFc4f44cC330AA0F0546d4F6c8  tx 0x263a8d0e2632ea8e057ff05385254ee45e46cd3656ae462d7b856a9c9e9c8abd
MockUSDC (currency1)         0xeC64E378231542Fdd2Eedf2a1763a041C2Dda523  (same tx)
EligibilityRegistry          0x0BffBD010510e7551581F94bF67A621F1Af2fcB6  tx 0x1b8f789cceb24262550d755c62ae45f160a84c88faa62037385f3918c502066c
StandbyHook (CREATE2)        0x92E89Da9FE8A103f4864914b268Ec364f6458AC0  tx 0x89c3d2014ce874c3ac69320d6521f167aca038f6491aaa62430ec1f8c26f9361
ExerciseRouter               0x17C3Ff4a5DD943359699d44BF14058cE4f31C187  tx 0x844f113130efb7c2b888ade2bddeddd6533caddf517aafedef7a9a7f2c433c14
```

Addresses identical to the fork rehearsal. On-chain: decimals 6/6; USTB < USDC; Hook `& 0x3FFF = 0x0AC0`; Hook →
frozen PoolManager, official Universal Router, official PositionManager, derived configuration authority;
ExerciseRouter → Hook, PoolManager; registry `i_admin` = derived registry admin; `nextCommitmentId` = 1.

### Source verification

`forge verify-contract --chain 84532 --watch`: MockUSTB, MockUSDC, EligibilityRegistry, StandbyHook,
ExerciseRouter — `Pass - Verified`. DeterministicFixtureDeployer: first attempt failed locally with
`error: invalid value` (a harness `jq` query returned two lines for one address); retried with the single address —
`Pass - Verified`. The API key was redacted from the verification logs.

### Bootstrap (24 transactions, blocks 46836492–46836510, all `0x1`)

Key hashes: initialize `0x657e7616…a5fc`; configureAndActivate `0x13238606…205c`; eligibility `0x706d65ff…529f`,
`0x9ecd8e12…61cbd`, `0xcc674d08…07ab`; liquidity `0xaab76a80…5bea` (full hashes in the report).

Mined-chain verification: `verify 80000000000 0 0` passed; PoolId `0x8b6033124249c0b22872e95746f9526d7c722dddedbc7209424923879ca9d271`
= `hook.serviceId()`; StateView tick 0, sqrtPriceX96 `2^96`, lpFee 500, protocolFee 0, liquidity 6,707,079,990,254;
decoded PES tuple = canonical PoolKey / registry / zeroForOne / −240 / +240 / configured / ExerciseRouter /
establishment authority; eligibility predicates separated per role; Permit2 allowances LP→PositionManager (both
currencies) and trader→Universal Router set; exerciser MockUSTB→ExerciseRouter ERC20 allowance set; position token id
28027 owned by the liquidity provider.

### A1

Tx `0x40d7b3de0fb4e153c7afbe4d8b8fb04b5021091b75a3492f9a6868885a038c50` (block 46836587, `0x1`); commitment 1;
decoded record canonical (validity 30 days). Mined verify: S 80,000,000,000 / O 50,000,000,000 / Remaining
50,000,000,000.

### A2 — official Universal Router

Tx `0x01007a48033697bcaa59e0b841fb81ea2f9f5bb6a81c430d949f7a26e7f3488e` (block 46836637, `0x1`), from the trader to
the Universal Router. Receipt: PoolManager `Swap` sender = Universal Router; MockUSTB trader→PoolManager
15,041,142,406; MockUSDC PoolManager→trader 15,000,000,000. Mined verify: S 65,000,000,000 / O 50,000,000,000 /
Remaining 50,000,000,000.

### A3 — official Universal Router, refused

Simulated attempt against live state passed its exact revert-data check (prospective S′ 45,000,000,000 < O
50,000,000,000). Post-A3 mined verify: unchanged. Independent `eth_call` of the exact router calldata from the trader
at pinned block 46836645 returned revert data byte-identical to the independently `cast`-encoded
`WrappedError(hook, 0x575e24b4, InsufficientProspectiveBacking(45000000000, 50000000000), 0xa9e35b2f)`. No reverted
transaction was broadcast (consistent with canonical `DemoActions` A3).

### A4 — ExerciseRouter

Tx `0x983b351e22b784f32b2749546c6fa50cde7e8de8e53f95c7c2e44d75da2483ce` (block 46836674, `0x1`), from the exercise
authority. Receipt: PoolManager `Swap` sender = ExerciseRouter; MockUSTB exercise authority→PoolManager
50,627,787,984; MockUSDC PoolManager→beneficiary 50,000,000,000 (direct); Hook `ExerciseFinalized`. Beneficiary
MockUSDC 0 (block 46836673) → 50,000,000,000 (block 46836674). Hook and ExerciseRouter: 0 MockUSDC, 0 MockUSTB.
Exercise authorization state EMPTY. Final mined verify: S 15,000,000,000 / O 0 / Remaining 0.

Deployer ETH remaining after the whole run: 0.487949 ETH.

---

## Final local verification

```text
forge fmt --check                              exit 0
forge build                                    exit 0
forge lint <all new/changed Solidity>          no findings printed
forge test                                     603 passed, 0 failed, 0 skipped (63 suites)
FOUNDRY_PROFILE=ci forge test                  603 passed, 0 failed, 0 skipped (63 suites)
forge test --match-path "test/acceptance/*"    11 passed (BootstrapFidelity 9, CanonicalStandbyFlow 2)
git submodule status / gitlinks                v4-hooks-public 0f731d5, v4-core d153b04, v4-periphery 07336f2 — unchanged
git diff --stat (tracked)                      .gitignore, script/helpers/HelperConfig.s.sol, script/helpers/NetworkConfig.sol only
```

---

## Material follow-up prompts

During the initial Session 21 implementation no follow-up instruction was received. The following was received after
that completion report and is recorded here; the chronology and completion report above are unchanged.

### 1 — Add a tracked reproduction environment template (`.env.example`)

**Instruction.** Supplied as `docs/prompts/session-21-f9t-create-example-env.md`: add a tracked repository-root
`.env.example` documenting only the user-supplied inputs required by the F9T Base Sepolia reproduction path, using the
environment-variable names actually consumed by the implementation (conceptually `BASE_RPC_URL`, `PRIVATE_KEY`,
optional `BASESCAN_API_KEY`), with no real credential and no deployed address. Do not create any `base-sepolia.env`
sample — `base-sepolia.env` is generated deployment output and must stay generated and git-ignored. Minimally update
`docs/setup.md` so a reproducer copies `.env.example` to `.env`, supplies the RPC URL, uses a dedicated funded Base
Sepolia test key, optionally supplies the explorer key, never commits `.env`, and lets the scripts generate
`base-sepolia.env`. Verify `.env` and `base-sepolia.env` are ignored and `.env.example` is not. Do not redeploy, broadcast,
or change implementation, periphery adapters, dependencies, `README.md`, `docs/project-status.md`, or the deployment
report. Allowed files: `.env.example`, `docs/setup.md`, this log (`.gitignore` only if strictly necessary). The
previously exposed RPC provider key has been rotated; record neither the old nor the replacement key.

**Why.** The F9T reproduction instructions named the required inputs but gave a new reproducer no tracked template, so
the local `.env` shape had to be inferred from documentation. A placeholder-only template makes the user-supplied input
surface explicit (G9T-40) without moving any secret or deployment state into tracked files (G9T-41).

**Names confirmed from the implementation.** `script/testnet/run-base-sepolia.sh` reads `BASE_RPC_URL`,
`PRIVATE_KEY`, and `BASESCAN_API_KEY` (plus per-invocation overrides `RPC_URL`, `COMMITMENT_ID`, `STANDBY_MANIFEST`,
`VERIFY`, which are not local secrets and were not added). The F9T Solidity scripts read only `PRIVATE_KEY` from user
input, plus `STANDBY_USTB`, `STANDBY_USDC`, `STANDBY_REGISTRY`, `STANDBY_HOOK`, and `STANDBY_EXERCISE_ROUTER`, which the
runner's `deploy` stage writes into the generated `base-sepolia.env`. The names match the conceptual example exactly.
The local `.env` also contains `ANVIL_RPC_URL`, which no F9T path consumes, so it was not templated.

**Consequence.**

- Created `.env.example`: three empty assignments (`BASE_RPC_URL=`, `PRIVATE_KEY=`, `BASESCAN_API_KEY=`) with
  explanatory comments only — copy instruction, never-commit warning, dedicated-test-key guidance, optional explorer
  key, and a note that deployed addresses belong in the generated `base-sepolia.env`, not here.
- Modified `docs/setup.md`, F9T "Inputs" subsection only: a `cp .env.example .env` instruction and never-commit
  warning; `PRIVATE_KEY` described as a dedicated, funded Base Sepolia deployment/test key; `BASESCAN_API_KEY` marked
  optional; one sentence that `base-sepolia.env` is generated by the `deploy` stage and must not be created by hand.
  The stage-by-stage procedure was not duplicated. Canonical Anvil and judged-acceptance instructions are untouched.
- `.gitignore` not modified: `.env.example` is already not ignored.
- `base-sepolia.env` responsibility unchanged: generated by `run-base-sepolia.sh deploy`, git-ignored; no sample of it
  was created.
- No other file was touched. The untracked `claude_changes.diff` present in the working tree was not created or
  modified by this follow-up.

**Security checks.**

```text
git check-ignore .env               ignored   (.gitignore:11 .env)
git check-ignore base-sepolia.env   ignored   (.gitignore:36 base-sepolia.env)
git check-ignore .env.example       NOT ignored
.env.example non-comment lines      BASE_RPC_URL=  PRIVATE_KEY=  BASESCAN_API_KEY=   (all empty)
.env.example URLs / long hex        0 / 0
secret scan of .env.example and the docs/setup.md diff, by count only, against every value in the local .env
  (root key hex, root key decimal, Base Sepolia RPC URL, Anvil RPC URL, explorer API key)        0 hits
```

No private key, RPC URL, or API key was printed during this follow-up; the local `.env` was inspected only with values
redacted.

**Verification.**

```text
forge fmt --check                              clean
forge build                                    No files changed, compilation skipped
bash -n script/testnet/run-base-sepolia.sh     syntax ok (runner unchanged)
```

No Solidity, script, test, dependency, or configuration file changed, so no test suite was rerun. No transaction was
broadcast, nothing was redeployed, and the live lifecycle was not rerun.

**Gate impact.** Strengthens reproducibility/security evidence for G9T-40 and G9T-41. No G9T requirement changed; G9T is
not closed by this follow-up.

**Follow-up completion report.**

- Files inspected: `docs/prompts/session-21-f9t-create-example-env.md`, `script/testnet/run-base-sepolia.sh`,
  `script/testnet/BaseSepoliaScript.sol` and `script/helpers/*` (environment reads), `docs/setup.md` (F9T section),
  `.gitignore` rules via `git check-ignore`, local `.env` (names only, values redacted), this log.
- Files changed: `.env.example` (created), `docs/setup.md` (F9T Inputs subsection), `docs/prompts/session-21-log.md`
  (this entry).
- Requirements implemented: follow-up prompt "Required Change" §1 and the `docs/setup.md` items 1–6; §2 honored (no
  `base-sepolia.env` sample).
- Tests added or changed: none (documentation/template change only).
- Results / gate evidence: as recorded above; every completion-boundary item is satisfied.
- Known limitations / blockers: none.
- Scope check: within the allowed files; no out-of-scope change.
- Proposed assessment for this follow-up: PASS (proposed); G9T closure remains with independent review.
- Recommended next step: independent review of this follow-up alongside the Session 21 evidence; nothing further is
  implemented without instruction.

**Prompt audit.** Material follow-up prompts recorded in this log: **1**.

---

# Final Completion Report — Session 21

## Files Inspected

Repository: `CLAUDE.md`, `.claude/rules/*`, the Session 21 prompt, `docs/project-status.md`,
`docs/prompts/session-20-log.md`, `docs/implementation-plan.md` §21, `docs/uniswap-v4-realization.md` §2.4/§8/§9,
`docs/setup.md`, `foundry.toml`, `remappings.txt`, `.gitignore`, every file under `script/`, `src/StandbyHook.sol`
(constructor, activation, O3 swap/liquidity enforcement, actor attribution, prospective derivation, price-limit
reproduction, capacity derivation, commitment terms, structs, events), `src/ExerciseRouter.sol`,
`src/interfaces/IActorAwarePeriphery.sol`, `src/EligibilityRegistry.sol`, `src/mocks/*`,
`test/integration/StandbyHookDeployment.t.sol`, `test/shared/BaseCanonicalAcceptanceTest.t.sol`,
`test/acceptance/CanonicalStandbyFlow.t.sol` (expectations), `test/unit/EligibilityRegistry.t.sol` (style).

Pinned dependencies: v4-periphery `V4Router.sol`, `PositionManager.sol`, `interfaces/IV4Router.sol`,
`IPositionManager.sol`, `IImmutableState.sol`, `IMsgSender.sol`, `IPermit2Forwarder.sol`, `libraries/Actions.sol`,
`CalldataDecoder.sol`, `test/shared/Planner.sol`; Permit2 `IAllowanceTransfer.sol`; forge-std `Vm.sol`.

External: live Base Sepolia bytecode and bindings of the frozen PoolManager, Universal Router, PositionManager,
Permit2, StateView, Quoter, CREATE2 factory, and the two non-frozen Universal Routers.

## Files Changed

Modified:

```text
script/helpers/HelperConfig.s.sol   Base Sepolia resolution + infrastructure preflight; Anvil branch unchanged in behavior
script/helpers/NetworkConfig.sol    added PublicPeripheryConfig struct (NetworkConfig unchanged)
.gitignore                          ignore generated base-sepolia.env manifest
docs/setup.md                       supplementary F9T Base Sepolia setup/reproduction section
```

Created:

```text
script/helpers/PublicPeriphery.sol               narrow official-periphery interfaces + calldata adapters
script/testnet/BaseSepoliaScript.sol             shared F9T context: infra resolution, manifest, role keys, gas top-up
script/testnet/DeployBaseSepoliaEnvironment.s.sol  composition on the official stack (inherits canonical Hook procedure)
script/testnet/BootstrapBaseSepolia.s.sol        canonical bootstrap reused; Permit2 approvals + PositionManager mint
script/testnet/BaseSepoliaActions.s.sol          canonical A1/A4 reused; A2/A3 via official Universal Router; mined verify
script/testnet/run-base-sepolia.sh               stage-by-stage reproducible runner with output redaction
test/harness/PublicPeripheryStubs.sol            binding-getter stubs for preflight unit tests
test/unit/BaseSepoliaInfrastructure.t.sol        13 unit tests (preflight, resolution, role derivation)
docs/reports/f9t-base-sepolia-deployment.md      public deployment evidence artifact
docs/prompts/session-21-log.md                   this log
```

Generated by Foundry (untracked, public transaction records, no secrets): `broadcast/DeployBaseSepoliaEnvironment.s.sol/84532/*`,
`broadcast/BootstrapBaseSepolia.s.sol/84532/*`, `broadcast/BaseSepoliaActions.s.sol/84532/*`. Generated manifest
`base-sepolia.env` (git-ignored). No file under `src/`, no canonical script, no existing test, no dependency, no
`foundry.toml`/`remappings.txt`, no `README.md`, no `docs/project-status.md`, no `CLAUDE.md`/`.claude/rules/*` was
modified. The session prompt was supplied externally and not modified.

## Requirements Implemented

Session 21 prompt §§8–30 for F9T: Base Sepolia configuration; external preflight; frozen topology; canonical Hook
deployment path reuse; canonical fixture currencies and ordering; EligibilityRegistry, StandbyHook, ExerciseRouter
deployment; source verification; canonical PoolKey and tick-0 initialization with zero pre-activation liquidity;
one-shot PES activation; eligibility; Permit2 approvals for the official perimeters; accepted ERC20 approval for
the ExerciseRouter; canonical liquidity through the official PositionManager; bootstrap verification; public A1–A4;
evidence recording; reproducible scripts; local verification. No protocol requirement was changed.

## Tests Added or Changed

`test/unit/BaseSepoliaInfrastructure.t.sol` (13, all passing):

- `test_baseSepolia_resolvesFrozenPoolManager`, `test_baseSepolia_resolvesFrozenPublicPeriphery` — frozen topology
  resolves exactly (G9T-2), checked against independent literals.
- `test_baseSepolia_rejectsMissingInfrastructureCode` — each of six addresses must hold code (G9T-3).
- `test_baseSepolia_rejectsHistoricalUniversalRouterBinding` — the historical router's real bindings are refused
  (G9T-5).
- `…rejectsUniversalRouterPositionManagerMismatch`, `…rejectsPositionManagerPoolManagerMismatch`,
  `…rejectsPositionManagerPermit2Mismatch`, `…rejectsUnreadableUniversalRouterBinding` — mutual compatibility
  (G9T-4).
- `…rejectsUniversalRouterWithoutActorSurface`, `…rejectsPositionManagerWithoutActorSurface` — authenticated
  originator surface required (G9T-15/16 preflight).
- `test_publicPeriphery_isRejectedOnLocalEnvironment`, `test_baseSepolia_otherPublicChainIsRejected` — chain
  selection (G9T-1).
- `test_roleDerivation_isDeterministicAndKeepsRolesDistinct` — seven distinct, deterministic role accounts, none the
  root.

No existing test was changed. Live behavior was evidenced on Base Sepolia (and a fork rehearsal), not by stubs.

## Commands Run

`git status`; read-only `cast` preflight (chain id, code, bindings, bytecode selector scan, deployer balance/nonce);
`forge fmt`, `forge fmt --check`, `forge build`, `forge lint`; `forge test` (targeted, full default, full `ci`,
acceptance); `anvil --fork-url` rehearsal with `script/testnet/run-base-sepolia.sh deploy|bootstrap|a1|a2|a3|a4|verify`;
live `run-base-sepolia.sh deploy|bootstrap|a1|a2|a3|a4|verify`; `forge verify-contract` ×6; `cast call` / `cast
receipt` / StateView / Permit2 / balance reads; pinned-block `eth_call` for A3; `git submodule status`, `git diff
--stat`, `git check-ignore`.

## Results

All results are as recorded above: preflight passed; rehearsal passed; live deploy, bootstrap, A1, A2, A4
committed with status `0x1`; A3 refused with the exact Standby backing error; every mined-chain verification passed;
six contracts source-verified; 603/603 tests pass under default and `ci` profiles; canonical acceptance 11/11.

## Gate Evidence

Implemented and verified by Claude against G9T:

- **Environment G9T-1–5:** chain 84532; frozen addresses; code present; bindings mutually compatible; historical
  router rejected (live read + unit test).
- **Deployment G9T-6–12:** 6-decimal mocks, USTB < USDC; registry; ExerciseRouter; Hook via canonical HookMiner /
  CREATE2 procedure; address bits `0x0AC0`; Hook bound to frozen PoolManager; all Standby-owned contracts
  `Pass - Verified`.
- **Public periphery G9T-13–17:** Hook immutably trusts the official Universal Router and PositionManager; the Hook
  admitted the canonical liquidity through PositionManager (LP-only eligibility) and A2 through the Universal Router
  (trader-only eligibility), which is possible only via their authenticated `msgSender()`; no ActorAwareTestRouter
  deployed or used.
- **Bootstrap G9T-18–24:** canonical PoolKey/fee/spacing/Hook/ordering; tick 0; PES activation tuple; eligibility via
  registry; Permit2 allowances; liquidity via official PositionManager; S = 80,000, O = 0, no commitment.
- **Public execution G9T-25–36:** A1/A2/A3/A4 exactly as recorded above, including direct PoolManager→beneficiary
  delivery, exerciser payment, zero Standby custody, final S = 15,000 / O = 0 / Remaining = 0.
- **Reproducibility/security G9T-37–45:** addresses, PoolId, hashes, provenance recorded; runner + scripts + setup
  section reproduce the flow; no secret in any repository file or evidence; dependency baseline unchanged; full
  local verification clean; Base Sepolia explicitly labeled supplementary; canonical Anvil acceptance unchanged and
  passing.
- **Evidence/review G9T-46:** this log is complete.

Still unverified / not Claude's to verify: G9T-47 (ChatGPT retrospective), G9T-48 (independent review), G9T-49
(gate closure).

## Known Limitations / Blockers

1. **RPC credential exposure in session output.** During read-only preflight a mis-split shell argument caused
   `cast` to echo the Base Sepolia RPC URL, including its provider API key, into the Claude session transcript. It is
   in no repository file or evidence artifact. Recommendation: rotate that provider key.
2. **Deployed Universal Router ABI differs from pinned v4-periphery.** Handled by a narrow calldata adapter, proven
   live; the reviewer should confirm this is acceptable under session prompt §24 rather than a §40 "pinned interfaces
   incompatible" stop condition. No dependency was changed.
3. **Role keys are derived from the single funded key** (operational decision to preserve canonical role separation).
   Anyone holding `PRIVATE_KEY` controls all role accounts, including the configuration and establishment
   authorities of this testnet deployment.
4. **Trusted perimeters are bound at Hook construction**, not passed to `configureAndActivate` as session prompt §18
   / §22 step 8 phrase it; the repository is authoritative (§12) and this is the accepted F3 realization, not a
   semantic change.
5. **A3 has no broadcast reverted transaction.** Evidence is the simulated exact-revert check plus a reproducible
   pinned-block `eth_call`, consistent with canonical `DemoActions`.
6. The official router supplies `MIN_SQRT_PRICE + 1` as the PoolManager price limit, not the service's `P_Q`; for the
   canonical quantities the resulting state and refusal are identical to the canonical Anvil path.
7. `README.md` still states the accepted `590 passed` count; the suite is now 603 with the F9T unit tests. The judged
   submission README was intentionally not edited.
8. `docs/project-status.md` was not synchronized; G9T is not closed.

## Scope Check

Work stayed within the F9T responsibility-leakage boundary (§34): network configuration, external preflight, narrow
periphery adapter, public deployment/bootstrap/action scripts, tests for new configuration, evidence documentation,
setup instructions, and this log. No Standby economics, commitment semantics, derivation kernel, O1/O2/O3 logic,
settlement, finalization, Hook permissions, eligibility semantics, canonical scripts, or canonical acceptance were
modified. No mainnet deployment, production hardening, or new slice was begun.

## Proposed Gate Assessment

**PASS (proposed) for the Claude-verifiable G9T criteria G9T-1 through G9T-46.** Every environment, deployment,
public-periphery, bootstrap, public-execution, reproducibility/security, and log criterion has recorded on-chain or
local evidence above. **G9T-47, G9T-48, and G9T-49 are NOT EVALUATED** — they belong to independent ChatGPT review. G9T
is therefore not closed; the evidence is ready for independent review.

## Recommended Next Step

Independent ChatGPT review of the implementation diff, `docs/reports/f9t-base-sepolia-deployment.md`, the Foundry
`broadcast/*/84532` records, and the limitations above (especially items 2 and 3). Rotate the exposed RPC provider key.
After review, the user decides whether to commit the F9T files and broadcast records and whether to authorize a
`docs/project-status.md` synchronization.

## Prompt Audit

Session initiated from `docs/prompts/session-21-f9t-base-sepolia-deployment.md`. Material follow-up prompts recorded
in this log: **0** (none were received).

---

# Final Follow-up — Session 21 Administrative Closure (F9T COMPLETE / G9T PASS)

Appended after all preceding Session 21 content, which is preserved unchanged as historical evidence. The counts and
statements in the earlier completion report and in the `.env.example` follow-up are not revised by this record.

Instructions recorded here: `docs/prompts/session-21-final-project-status-update.md` (status-only update of
`docs/project-status.md`) and `docs/prompts/session-21-final log-update.md` (this log-only closure record).

## Retrospective

ChatGPT completed the Session 21 retrospective:

```text
docs/prompts/retrospective/session-21-chatgpt-record.md
```

## Independent review and gate closure

Following independent review:

- **G9T-47: PASS** — contemporaneous ChatGPT reasoning retrospective preserved;
- **G9T-48: PASS** — independent implementation/evidence review completed;
- **G9T-49: PASS** — final independent gate closure;
- therefore **G9T: PASS**;
- therefore **F9T — Base Sepolia Public Testnet Deployment: COMPLETE**.

## Status-only project-status update

`docs/project-status.md` was subsequently updated **status only** to record:

- **F9T — Base Sepolia Public Testnet Deployment: COMPLETE**;
- **G9T: PASS**;
- F9T remains **supplementary / post-submission / off critical path**;
- F0–F10 and all previously closed gates remain unchanged;
- deterministic local Anvil remains the canonical judged acceptance environment.

The status-only update:

- introduced no implementation change;
- introduced no protocol-semantic change;
- did not reopen any implementation slice or gate;
- did not make F9T a retroactive prerequisite for F9, F10, the ETHGlobal submission, or any previously closed gate.

## Closure

**Session 21 / F9T is administratively closed.** No further F9T implementation work remains.

The remaining repository actions are outside implementation:

- final repository/diff review;
- staging of the intended Session 21 artifacts;
- commit;
- PR / CI;
- merge and synchronization of `main`.

---

# Final Follow-up — README Base Sepolia Deployment Presentation

Appended after all preceding Session 21 content, which is preserved unchanged as historical evidence. No earlier
section — the original completion report and its counts, the `.env.example` follow-up, or the administrative-closure
record — is revised by this entry.

Instruction: `docs/prompts/session-21-update-readme-with-basesepolia-address.md`. After F9T/G9T closure the user
authorized one final README presentation follow-up, so that the completed public deployment is discoverable from the
repository front page.

Recorded facts:

1. `README.md` now carries a concise `## Base Sepolia deployment` section, placed after `## Running the demo` and
   before `## What Standby does not claim`.
2. It exposes the five deployed Standby Base Sepolia contract addresses — MockUSTB, MockUSDC, EligibilityRegistry,
   StandbyHook, ExerciseRouter — and the Standby `PoolId`
   `0x8b6033124249c0b22872e95746f9526d7c722dddedbc7209424923879ca9d271`. Every value was checked character-for-character
   against `docs/reports/f9t-base-sepolia-deployment.md` before being written; none was altered.
3. Each contract address links to its Base Sepolia BaseScan address page
   (`https://sepolia.basescan.org/address/<address>`); the `PoolId` is labelled as a pool identifier and is
   deliberately not linked as an address.
4. Detailed deployment provenance, transaction hashes, official Uniswap v4 infrastructure details, source-verification
   evidence, A1–A4 execution evidence and reproduction details remain owned by
   `docs/reports/f9t-base-sepolia-deployment.md`, which the README links to rather than duplicating.
5. The section states that the deterministic local Anvil environment remains the canonical ETHGlobal judged
   acceptance environment and that the Base Sepolia deployment is supplementary post-submission public-network
   evidence that does not replace it. It makes no production, production-ready, mainnet-ready, or audited claim.
6. This follow-up was documentation/presentation only.
7. No implementation, protocol semantics, dependency, deployment state, test, script, configuration, or gate result
   changed. The README's existing accepted test count and every other existing section were left untouched.
8. No transaction was broadcast and nothing was redeployed.
9. F9T remains COMPLETE, G9T remains PASS, and Session 21 remains administratively closed.

Files modified by this follow-up: `README.md` and this log.

Follow-up accounting: this is the fourth instruction received after the original Session 21 completion report — the
`.env.example` reproduction template, the status-only `docs/project-status.md` update, the administrative-closure
record, and this README presentation follow-up. The historical counts stated inside the earlier completion-report
sections are unchanged and remain accurate as of the time they were written.
