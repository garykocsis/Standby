# Standby — Session 21: F9T Public Testnet Deployment

## 1. Working Model

Use the established division of responsibility.

### ChatGPT

ChatGPT is the normative derivation and independent-review partner.

Before Claude implementation, ChatGPT has:

1. reconstructed the exact F9T responsibility from the frozen Standby artifacts and completed F0–F10 implementation;
2. distinguished F9T public-testnet evidence from the canonical deterministic Anvil acceptance environment;
3. verified the current official Base Sepolia Uniswap v4 deployment topology;
4. reconciled conflicting Universal Router deployment-address sources;
5. verified the required PoolManager / Universal Router / PositionManager / Permit2 compatibility relationships;
6. verified the required actor-attribution surfaces for the official public periphery;
7. preserved the accepted Standby O1/O2/O3 semantics;
8. preserved the accepted F8C settlement/delivery semantics;
9. preserved the canonical Hook deployment path and permission mask;
10. derived the public-testnet bootstrap sequence;
11. derived the preferred full public A1–A4 acceptance path;
12. performed the F9T responsibility-leakage review;
13. derived and frozen G9T.

After Claude implementation, ChatGPT will independently review:

14. the actual changed production/support code;
15. deployment/configuration scripts;
16. public-periphery integration;
17. Base Sepolia deployed addresses;
18. transaction evidence;
19. source-verification evidence where practical;
20. bootstrap state;
21. A1–A4 execution evidence;
22. final authoritative Standby state;
23. preservation of canonical Anvil acceptance;
24. G9T evidence;
25. and determine G9T PASS or FAIL.

### Claude

Claude is the bounded implementation assistant.

Claude must:

- inspect the repository and accepted implementation before editing;
- implement only the F9T responsibility defined by this prompt;
- reuse existing canonical paths wherever they exist;
- minimize implementation discretion;
- preserve all accepted economic semantics;
- collect the required evidence;
- maintain the Session 21 implementation log;
- produce a completion report;
- stop at the F9T completion boundary.

Claude does not redefine F9T.

---

# 2. Clean Rule

The existing clean rule remains authoritative:

**CLAUDE.md owns permanent operating behavior.**

**.claude/rules/\* owns permanent Solidity/testing conventions.**

**Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Do not move Session 21-specific F9T requirements into CLAUDE.md or `.claude/rules/*`.

---

# 3. Branch Safety

Before making any repository modification, determine the current Git branch.

F9T work must occur on an appropriate non-main session branch.

If the repository is currently on `main`:

**STOP before modifying any repository file and tell the user that a Session 21 branch is required.**

Do not autonomously:

- create a branch;
- switch branches;
- merge branches;
- delete branches;
- push a merge.

The user owns branch lifecycle decisions.

If already on an appropriate non-main F9T branch, continue.

Do not modify CLAUDE.md merely to implement this session-specific branch check.

---

# 4. Current Project State

Standby has already been submitted to ETHGlobal.

The judged project and its canonical acceptance evidence are frozen.

F0 through F10 are COMPLETE and their gates are PASS.

The accepted implementation has already demonstrated the complete Standby lifecycle using the deterministic Anvil environment and real Uniswap v4 stack.

F9T occurs **after submission**.

F9T is:

> supplementary public-network realization and integration evidence.

It is not:

- a retroactive prerequisite for F9;
- a retroactive prerequisite for F10;
- a replacement for canonical Anvil acceptance;
- a production-readiness claim;
- a mainnet deployment;
- a new economic design slice.

Failure to complete F9T must not invalidate the already accepted F9/F10 result.

---

# 5. F9T Objective

Deploy the already accepted Standby implementation to **Base Sepolia** using the current mutually compatible official Uniswap v4 infrastructure and demonstrate, preferably end-to-end, that the accepted Standby mechanism can be realized on a public network without changing its economic semantics.

Target network:

```text
Base Sepolia
chainId = 84532
```

The strongest F9T result is a complete public reproduction of the canonical A1–A4 lifecycle.

---

# 6. Canonical Semantics Are Frozen

F9T must not redefine:

- Supporting Capacity S;
- Obligation O;
- Remaining Entitlement;
- O1 commitment admission;
- O2 protected exercise;
- O3 ordinary-operation enforcement;
- prospective backing checks;
- commitment identity;
- beneficiary authority;
- exercise authority;
- eligibility semantics;
- PES configuration semantics;
- service interval semantics;
- protected direction;
- settlement semantics;
- causal finalization;
- Hook permission requirements.

The core invariant remains:

```text
For each participant j:

Supporting Capacity S_j(t) >= Obligation O_j(t)
```

F9T realizes the accepted mechanism on a public testnet.

It does not redesign it.

---

# 7. Canonical F9T Economic Fixture

Preserve the accepted canonical fixture:

```text
currency0 = MockUSTB
currency1 = MockUSDC

MockUSTB decimals = 6
MockUSDC decimals = 6

protected direction = zeroForOne

initial tick = 0

tickQ = -240
tickO = +240

LP range = [-300, +300]

tickSpacing = 10
fee = 500

canonical liquidity =
6,707,079,990,254

bootstrap Supporting Capacity S =
80,000 MockUSDC

bootstrap Obligation O =
0

commitment =
50,000 MockUSDC

compatible ordinary output =
15,000 MockUSDC

destructive ordinary output =
20,000 MockUSDC
```

Do not silently alter these values to make public deployment easier.

If public-network behavior exposes a genuine incompatibility, stop and report it.

---

# 8. Frozen Base Sepolia External Topology

Use the following current Base Sepolia Uniswap v4 topology.

```text
chainId
84532

PoolManager
0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408

Universal Router
0x492e6456d9528771018deb9e87ef7750ef184104

PositionManager
0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80

Permit2
0x000000000022D473030F116dDEE9F6B43aC78BA3

StateView
0x571291b572ed32ce6751a2cb2486ebee8defb9b4

V4 Quoter
0x4a6513c898fe1b2d0e78d3b0e0a4a151589b1cba
```

These are chain-specific public infrastructure facts.

Prefer representing them through the repository's existing chain/network configuration architecture rather than treating them as secrets.

Do not require them to be supplied through `.env` merely because they are network-specific.

---

# 9. Universal Router Address Resolution Is Frozen

There are multiple historical/current Universal Router deployments on Base Sepolia.

For F9T use:

```text
0x492e6456d9528771018deb9e87ef7750ef184104
```

Do **not** substitute:

```text
0x95273d871c8156636e114b63797d78D7E1720d81
```

That deployment is associated with an older Base Sepolia v4 stack whose PoolManager/PositionManager bindings do not match the current F9T PoolManager.

Also do not introduce:

```text
0x8B844f885672f333Bc0042cB669255f93a4C1E6b
```

merely because a newer Universal Router version exists.

The F9T topology intentionally freezes the current Universal Router identified by the current official Uniswap v4 Base Sepolia deployment mapping and verified against the current PoolManager.

Do not turn F9T into a Universal Router version-upgrade exercise.

---

# 10. External Infrastructure Preflight

Before creating Standby state on Base Sepolia, implement or execute sufficient preflight validation to establish that the external infrastructure is the expected mutually compatible stack.

At minimum verify:

```text
chainId == 84532
```

and deployed bytecode exists at the required external addresses.

Validate the important bindings exposed by the external contracts.

The expected relationships are:

```text
Universal Router
    PoolManager =
    0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408

Universal Router
    v4 PositionManager =
    0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80

PositionManager
    PoolManager =
    0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408

PositionManager
    Permit2 =
    0x000000000022D473030F116dDEE9F6B43aC78BA3
```

Also establish that the trusted periphery exposes the authenticated actor surfaces required by Standby.

Expected relevant surfaces include:

```text
Universal Router:
msgSender()

PositionManager:
msgSender()
```

If any required external binding contradicts the frozen topology:

**STOP.**

Do not repair the mismatch by changing Standby semantics, trusting a different arbitrary router, weakening attribution, or upgrading dependencies.

Report the exact incompatibility.

---

# 11. Pinned Dependency Baseline

Preserve the accepted pinned Uniswap dependency baseline.

Current accepted dependency evidence includes:

```text
v4-hooks-public
0f731d5de0f4fd60b506b55754d5e6ff086eab7d

v4-core
d153b048868a60c2403a3ef5b2301bb247884d46

v4-periphery
07336f2144f522874e2c3c85e04d1d3f8d5fa471
```

Do not casually:

- update v4-core;
- update v4-periphery;
- update v4-hooks-public;
- update Permit2;
- replace pinned interfaces;
- vendor newer protocol source merely to make a script convenient.

The current external compatibility review has not identified a reason to upgrade the accepted dependency baseline.

If a real dependency incompatibility is discovered, stop and report it rather than silently upgrading.

---

# 12. Standby-Owned Public Deployment

F9T should deploy the Standby-owned components required by the accepted implementation.

Expected components include:

```text
MockUSTB
MockUSDC
EligibilityRegistry
ExerciseRouter
StandbyHook
```

Inspect the actual repository first.

Respect the real constructor and deployment dependencies found in the accepted source.

Do not infer constructor order from this prompt when the repository is authoritative about a concrete implementation dependency.

---

# 13. Mock Token Ordering

The canonical fixture requires:

```text
MockUSTB = currency0
MockUSDC = currency1
```

Therefore the deployed addresses must satisfy the ordering required by the v4 `Currency` / `PoolKey` construction.

Inspect and reuse the existing deterministic fixture/deployment mechanism wherever possible.

Do not solve an ordering problem by reversing the accepted protected direction or changing the canonical economic fixture.

If public CREATE address behavior requires an operational deployment technique to preserve the accepted ordering, use the smallest semantically neutral solution compatible with the existing deployment architecture.

If canonical ordering cannot be safely guaranteed without semantic changes, stop and report the blocker.

---

# 14. Canonical Hook Deployment Path

Do not create a second Hook deployment implementation for Base Sepolia.

Reuse the existing canonical Hook deployment path.

The accepted architecture includes the equivalent of:

```text
deployStandbyHook(
    IPoolManager poolManager,
    address create2Deployer
)
```

and uses the pinned HookMiner / CREATE2 process.

Required Standby Hook permissions remain:

```text
beforeAddLiquidity = true
beforeRemoveLiquidity = true
beforeSwap = true
afterSwap = true

all other Hook permissions = false

all return-delta permissions = false
```

The accepted permission mask is:

```text
0x0AC0
decimal 2752
```

The deployed Hook must:

- have the required permission bits encoded in its address;
- pass the existing Hook permission validation;
- be bound immutably to the Base Sepolia PoolManager;
- use the canonical mining/deployment path.

Inspect the repository's existing CREATE2-deployer assumptions.

If the canonical public deployment requires a CREATE2 deployer that is unavailable or incompatible on Base Sepolia:

**STOP and report the blocker.**

Do not introduce an unrelated Hook deployment mechanism merely to obtain a successful deployment.

---

# 15. Public Periphery Topology

For F9T the PES trusted periphery is:

```text
trusted ordinary-swap periphery =
official Universal Router
0x492e6456d9528771018deb9e87ef7750ef184104

trusted liquidity periphery =
official PositionManager
0x4b2c77d209d3405f41a037ec6c77f7f5b8e2ca80

O2 coordinator =
Standby ExerciseRouter
```

The public-testnet realization must not use `ActorAwareTestRouter` as the ordinary swap or liquidity path.

`ActorAwareTestRouter` remains an Anvil/demo testing periphery.

It is not F9T public-periphery evidence.

---

# 16. Actor Attribution

Preserve the accepted actor-attribution model:

```text
Hook msg.sender
    =
PoolManager

callback sender
    =
trusted periphery / locker

economic actor
    =
authenticated originator exposed by trusted periphery
```

The Hook must authenticate the configured trusted periphery before trusting the originator returned by the periphery.

`hookData` must not become authoritative actor identity.

For F9T:

- ordinary swaps use the official Universal Router actor surface;
- liquidity operations use the official PositionManager actor surface.

Do not weaken this architecture to accommodate public deployment.

---

# 17. Pool Construction

After the required Standby-owned contracts are deployed, construct the canonical PoolKey using:

```text
currency0 = deployed MockUSTB
currency1 = deployed MockUSDC

fee = 500
tickSpacing = 10

hooks = deployed StandbyHook
```

Initialize the pool at:

```text
tick = 0
```

Preserve the accepted sequencing rule:

The Hook-bound canonical pool may exist at the initial price with zero Standby liquidity before service activation.

Do not add the canonical protected liquidity before the required Standby service configuration/enforcement is active.

---

# 18. PES Configuration and Activation

Configure and activate the accepted PES exactly once using the accepted implementation.

Required semantic configuration includes:

```text
PoolKey = canonical F9T pool

EligibilityRegistry =
deployed Standby registry

tickQ = -240

tickO = +240

protected direction =
zeroForOne

trusted ordinary-swap periphery =
official Universal Router

trusted liquidity periphery =
official PositionManager

O2 coordinator =
deployed ExerciseRouter

commitment establishment authority =
accepted canonical authority
```

Use the actual repository API.

Do not create parallel configuration semantics.

Preserve the accepted one-shot/immutable-after-activation behavior.

---

# 19. Eligibility

Configure the canonical F9T actors using the accepted EligibilityRegistry predicates.

Preserve the distinction between:

- beneficiary service eligibility;
- ordinary swap eligibility;
- liquidity-provider eligibility.

Do not collapse these predicates.

Configure only what is necessary to reproduce the canonical acceptance lifecycle.

---

# 20. Public Periphery Payment / Approval Model

## Universal Router

For canonical A2/A3 ordinary swaps, use the official Universal Router.

The expected public payment path is Permit2-based.

The ordinary trader should have the necessary MockUSTB funding and approvals:

```text
MockUSTB
    -> ERC20 approval to Permit2

Permit2
    -> allowance/permission for Universal Router
```

Use the smallest deterministic public-testnet approval path compatible with the pinned/current interfaces.

Persistent testnet Permit2 allowances are acceptable and preferable to unnecessary signature complexity if they preserve the same semantics.

## PositionManager

For canonical liquidity provision:

```text
MockUSTB / MockUSDC
    -> ERC20 approval to Permit2

Permit2
    -> allowance/permission for PositionManager
```

Add canonical liquidity using the official PositionManager.

Do not deploy a custom public liquidity router merely for convenience.

## ExerciseRouter

Do not force the O2 exercise path onto Permit2 merely because Universal Router and PositionManager use Permit2.

Preserve the already accepted ExerciseRouter settlement/payment mechanism.

The accepted F8C semantics allow the authenticated exerciser to fund the exact actual input through the existing ERC20 allowance/`transferFrom` mechanism.

Use the existing implementation.

---

# 21. F8C Settlement / Delivery Semantics Remain Frozen

The authenticated exerciser is the economic payer.

The actual input required by the protected exact-output swap must be settled to PoolManager.

The accepted conceptual settlement remains equivalent to:

```text
sync(inputCurrency)

transfer exact actualInput to PoolManager

settle()

verify input delta cleared
```

The protected output must be delivered directly by PoolManager to the authoritative beneficiary.

Conceptually:

```text
PoolManager.take(
    outputCurrency,
    authoritativeBeneficiary,
    q
)
```

Do not introduce:

```text
PoolManager
    -> ExerciseRouter
    -> Beneficiary
```

as the protected-output delivery path.

After successful fulfillment:

```text
ExerciseRouter protected-output balance = 0

StandbyHook protected-output balance = 0
```

subject to the accepted implementation's exact observable balance semantics.

---

# 22. Canonical Bootstrap Sequence

The intended F9T sequence is:

```text
1. Validate Base Sepolia chain and external infrastructure.

2. Deploy MockUSTB and MockUSDC while preserving canonical ordering.

3. Deploy the Standby-owned authorities/components required before
   service activation, including EligibilityRegistry and ExerciseRouter,
   respecting actual constructor dependencies.

4. Deploy StandbyHook through the canonical HookMiner / CREATE2 path.

5. Validate Hook permission bits and immutable PoolManager binding.

6. Construct canonical PoolKey.

7. Initialize the Hook-bound pool at tick 0 with zero protected liquidity.

8. configureAndActivate the PES with:
   - registry
   - tickQ
   - tickO
   - protected direction
   - official Universal Router
   - official PositionManager
   - ExerciseRouter
   - commitment authority

9. Configure required actor eligibility.

10. Fund actors and establish required approvals:
    - Universal Router via Permit2
    - PositionManager via Permit2
    - ExerciseRouter using accepted existing payment mechanics

11. Add canonical liquidity through official PositionManager:
    range [-300,+300]
    L = 6,707,079,990,254

12. Verify bootstrap authoritative state.
```

Required bootstrap result:

```text
S = 80,000

O = 0

no active canonical commitment
```

Do not proceed to A1–A4 if bootstrap state is not correct.

---

# 23. Preferred Public A1–A4 Acceptance Path

If the external infrastructure behaves as derived, execute the full canonical lifecycle on Base Sepolia.

## A1 — PROMISE

Establish the canonical commitment:

```text
commitment output =
50,000 MockUSDC
```

Expected authoritative result:

```text
S = 80,000

O = 50,000

Remaining Entitlement = 50,000
```

Record the relevant transaction evidence.

---

## A2 — SHARE

Use the **official Universal Router** for an unrelated eligible trader's canonical ordinary exact-output swap:

```text
output =
15,000 MockUSDC
```

Expected authoritative result:

```text
S = 65,000

O = 50,000

Remaining Entitlement = 50,000
```

This transaction must be evidence that the accepted O3 logic works through the official public swap periphery.

---

## A3 — PROTECT

Use the official Universal Router to attempt another ordinary exact-output swap:

```text
requested output =
20,000 MockUSDC
```

The prospective supporting capacity would be:

```text
S' = 65,000 - 20,000
   = 45,000
```

while:

```text
O = 50,000
```

Therefore:

```text
S' < O
```

The transaction must be rejected by the accepted Standby backing enforcement.

After rejection the authoritative state must remain:

```text
S = 65,000

O = 50,000

Remaining Entitlement = 50,000
```

Capture evidence sufficient to distinguish the Standby-specific rejection from an unrelated router, allowance, slippage, liquidity, or gas failure.

---

## A4 — FULFILL

Exercise the canonical commitment through the accepted ExerciseRouter.

Protected exact output:

```text
50,000 MockUSDC
```

Required behavior:

- the authenticated exerciser initiates the exercise;
- the exerciser pays the actual required MockUSTB input;
- the real v4 pool executes the exact-output swap;
- PoolManager directly delivers the protected MockUSDC output to the authoritative beneficiary;
- the beneficiary receives 50,000 MockUSDC;
- fulfillment causally reduces Remaining Entitlement;
- O falls to zero.

Expected final authoritative state:

```text
S = 15,000

O = 0

Remaining Entitlement = 0
```

Expected beneficiary delta:

```text
+50,000 MockUSDC
```

Expected protected-output custody:

```text
StandbyHook = 0

ExerciseRouter = 0
```

according to the accepted observable balance model.

---

# 24. Scripts and Implementation Architecture

Inspect the repository before deciding which files require changes.

Existing relevant architecture may include files equivalent to:

```text
HelperConfig.s.sol
NetworkConfig.sol
DeployStandbyHook.s.sol
DeployDemoEnvironment.s.sol
BootstrapStandby.s.sol
DemoActions.s.sol
```

Use the actual repository names and structure.

Prefer thin public-testnet orchestration around already accepted reusable components.

Do not duplicate:

- economic derivation;
- Hook deployment logic;
- bootstrap semantics;
- commitment logic;
- O3 derivation;
- exercise logic.

There must remain one economic implementation path.

If a narrow interface or adapter is needed solely to invoke the official Universal Router or PositionManager, keep it minimal and compatible with the pinned/current ABI.

Do not vendor large external implementations.

Do not upgrade dependencies merely to obtain convenience interfaces.

---

# 25. Environment Variables and Secrets

The user has prepared the local environment for Base Sepolia deployment.

Expected environment inputs may include:

```text
BASE_SEPOLIA_RPC_URL

PRIVATE_KEY

BASESCAN_API_KEY
```

Use existing repository naming conventions where they already exist.

Never:

- print the private key;
- echo the private key;
- log the private key;
- write it into a session log;
- write it into deployment evidence;
- commit it;
- persist it into generated configuration;
- include it in command output intentionally.

Treat RPC credentials/API keys as secrets where applicable.

Ensure `.env` remains ignored by Git.

Do not add secrets to tracked files.

Public deployed addresses and transaction hashes are evidence, not secrets.

---

# 26. Funding

The deployment wallet has been prepared with Base Sepolia ETH.

Before live broadcast, verify:

- the expected deployer address;
- RPC connectivity;
- chain ID;
- deployer ETH balance.

Do not expose the private key while doing so.

If funding becomes insufficient during F9T, stop and report the balance/funding blocker rather than changing the deployment semantics to reduce gas.

---

# 27. Source Verification

Where practical, verify the deployed Standby-owned contracts on the appropriate Base Sepolia explorer.

Use the repository's existing Foundry workflow if available.

Examples may involve Foundry broadcast verification or `forge verify-contract`, but inspect the repository/toolchain before choosing the exact mechanism.

Source verification is evidence.

Do not alter accepted source merely to make explorer verification easier.

If explorer verification fails for an external/tooling reason while the deployment itself is valid:

- record the exact failure;
- preserve deployment evidence;
- do not misrepresent the contract as verified.

---

# 28. Deployment Evidence

Create or update the smallest appropriate repository evidence artifact consistent with existing project conventions.

Record at minimum:

```text
network
chainId

external Uniswap addresses used

MockUSTB address
MockUSDC address
EligibilityRegistry address
ExerciseRouter address
StandbyHook address

PoolId / canonical PoolKey facts

deployer address

relevant deployment transaction hashes

pool initialization transaction

PES configuration/activation transaction

eligibility transactions where relevant

liquidity transaction

A1 transaction

A2 transaction

A3 attempted transaction / revert evidence

A4 transaction

source-verification status

bootstrap authoritative state

A1 authoritative state

A2 authoritative state

A3 unchanged authoritative state

A4 final authoritative state

beneficiary balance delta

Hook / ExerciseRouter protected-output custody result
```

Do not record secrets.

If the repository already has a deployment-evidence convention, use it rather than inventing an unnecessary parallel documentation hierarchy.

---

# 29. Reproducibility

The F9T result must not be merely a sequence of undocumented manual commands.

The repository should contain sufficient bounded scripts/configuration/instructions to reproduce the deployment and acceptance path, subject to:

- RPC access;
- a funded Base Sepolia deployer;
- testnet availability;
- public external infrastructure remaining deployed.

Avoid embedding one-time transaction state into production source.

Deployment-address evidence may of course record the actual resulting public deployment.

---

# 30. Local Verification Must Remain Clean

After F9T implementation, rerun the repository verification appropriate to the accepted project.

At minimum preserve the previously accepted local build/test behavior.

Use the repository's established verification commands and CI-equivalent profile.

Do not weaken tests to make F9T pass.

The canonical deterministic Anvil acceptance must remain valid.

F9T must be additive.

---

# 31. No Retroactive Canonical Rewrite

Do not change F9/F10 or canonical demo evidence merely because Base Sepolia introduces operational differences.

Do not rewrite the judged submission to imply that Base Sepolia was part of the judged canonical environment.

The distinction must remain explicit:

```text
Canonical judged acceptance:
deterministic Anvil

Supplementary post-submission evidence:
Base Sepolia
```

---

# 32. F9T Nonclaims

A successful F9T deployment demonstrates:

> The accepted Standby mechanism can be realized against a current public Uniswap v4 testnet stack and reproduce the protected-capacity lifecycle outside the deterministic local environment.

It does not establish:

- arbitrary execution guarantees;
- fixed-price execution;
- zero price impact;
- custody;
- escrow;
- segregated liquidity;
- production readiness;
- mainnet readiness;
- customer adoption;
- institutional deployment;
- capacity pricing;
- economic viability of a production fee model;
- production permissioning policy;
- audited status.

Do not introduce these claims into documentation.

---

# 33. External-Constraint Rule

If Base Sepolia exposes a real external constraint that contradicts a frozen F9T assumption:

**STOP and report it.**

Examples include:

- incompatible external contract bindings;
- missing required actor attribution;
- incompatible current PoolManager;
- unusable canonical CREATE2 deployment path;
- pinned ABI incompatibility;
- official periphery behavior incompatible with accepted Standby trust assumptions.

Do not solve an external incompatibility by:

- weakening authorization;
- trusting hookData;
- replacing authenticated actor identity;
- changing O1/O2/O3 semantics;
- changing S/O derivation;
- changing the protected direction;
- changing the canonical economic fixture;
- introducing a custom public actor-aware router;
- upgrading dependencies without review;
- bypassing official public periphery.

A blocker is a legitimate F9T result.

A semantically altered deployment is not.

---

# 34. Responsibility-Leakage Boundary

F9T may add or modify only what is required for public-testnet realization and evidence.

Expected legitimate surfaces include:

- Base Sepolia network configuration;
- external-address validation;
- public deployment scripts;
- public bootstrap scripts;
- official Universal Router invocation support;
- official PositionManager invocation support;
- narrow external interfaces/adapters if required;
- public acceptance-action scripts;
- deployment/evidence documentation;
- tests for new orchestration/configuration;
- Session 21 log.

F9T must not leak into redesign of:

- Standby economics;
- commitment semantics;
- derivation kernel;
- O3 backing enforcement;
- O1 admission;
- O2 authorization;
- O2 exact-output semantics;
- settlement delivery;
- causal finalization;
- Hook permissions;
- eligibility semantics;
- canonical service-domain semantics.

---

# 35. G9T — Public Testnet Deployment Gate

G9T is already derived and frozen.

Do not redefine the gate merely because implementation begins.

## Environment

**G9T-1**
The deployment targets Base Sepolia chain ID 84532.

**G9T-2**
The external Uniswap addresses match the frozen current Base Sepolia v4 topology.

**G9T-3**
Required external addresses contain deployed bytecode.

**G9T-4**
Universal Router, PositionManager, PoolManager, and Permit2 bindings are mutually compatible.

**G9T-5**
Known historical/incompatible deployments are rejected rather than silently accepted.

## Deployment

**G9T-6**
MockUSTB and MockUSDC preserve the canonical 6-decimal fixture and required currency ordering.

**G9T-7**
EligibilityRegistry is deployed.

**G9T-8**
ExerciseRouter is deployed.

**G9T-9**
StandbyHook is deployed through the canonical HookMiner / CREATE2 path.

**G9T-10**
The deployed Hook address satisfies the accepted Hook permission bits.

**G9T-11**
The Hook is immutably bound to the frozen Base Sepolia PoolManager.

**G9T-12**
Standby-owned contract source is explorer-verified where practical, with failures accurately recorded if verification is externally unavailable.

## Public Periphery

**G9T-13**
The official Universal Router is the PES trusted ordinary-swap periphery.

**G9T-14**
The official PositionManager is the PES trusted liquidity periphery.

**G9T-15**
Universal Router actor attribution uses its authenticated `msgSender()`-style surface.

**G9T-16**
PositionManager actor attribution uses its authenticated `msgSender()`-style surface.

**G9T-17**
ActorAwareTestRouter is not used as public-production-periphery evidence.

## Bootstrap

**G9T-18**
The canonical PoolKey, fee, spacing, Hook, and token ordering are preserved.

**G9T-19**
The canonical initial price/tick is preserved.

**G9T-20**
PES is activated with the accepted direction/domain and official public periphery.

**G9T-21**
Eligibility is configured through the accepted registry.

**G9T-22**
Required Universal Router and PositionManager Permit2 approvals are configured correctly.

**G9T-23**
Canonical liquidity is added through the official PositionManager.

**G9T-24**
Bootstrap state is verified as S=80,000, O=0, with no canonical commitment.

## Public Execution

**G9T-25**
A1 establishes the canonical 50,000 commitment.

**G9T-26**
A1 produces S=80,000, O=50,000, Remaining=50,000.

**G9T-27**
A2 executes the canonical 15,000 ordinary output through the official Universal Router.

**G9T-28**
A2 produces S=65,000, O=50,000, Remaining=50,000.

**G9T-29**
A3 establishes that the requested 20,000 ordinary output would produce prospective S'=45,000.

**G9T-30**
A3 is rejected because S'=45,000 < O=50,000.

**G9T-31**
A3 rejection leaves authoritative state unchanged at S=65,000, O=50,000, Remaining=50,000.

**G9T-32**
A4 executes through the accepted ExerciseRouter.

**G9T-33**
The authenticated exerciser pays the actual required input.

**G9T-34**
PoolManager directly delivers 50,000 protected MockUSDC to the authoritative beneficiary.

**G9T-35**
StandbyHook and ExerciseRouter do not retain protected-output custody.

**G9T-36**
A4 final state is S=15,000, O=0, Remaining=0.

## Reproducibility / Security

**G9T-37**
Deployed Standby addresses and PoolId are recorded.

**G9T-38**
Relevant public transaction hashes are recorded.

**G9T-39**
External infrastructure provenance is recorded.

**G9T-40**
The public deployment and acceptance flow is reproducible from repository scripts/instructions.

**G9T-41**
No secrets are committed or written into deployment evidence.

**G9T-42**
The frozen dependency baseline remains unchanged unless a separately reviewed revalidation explicitly authorizes an upgrade.

**G9T-43**
Full local repository verification remains clean.

**G9T-44**
Base Sepolia is explicitly identified as post-submission supplementary evidence.

**G9T-45**
Canonical Anvil F9/F10 acceptance remains unchanged.

## Evidence / Review

**G9T-46**
The Session 21 Claude implementation log is complete.

**G9T-47**
The Session 21 ChatGPT retrospective record can be produced from contemporaneous evidence.

**G9T-48**
ChatGPT independently reviews the implementation, deployment addresses, transaction evidence, and final authoritative state.

**G9T-49**
G9T closes only after the required evidence has been independently reviewed.

---

# 36. Gate Ownership

Claude may gather and organize evidence against G9T.

Claude must not claim that ChatGPT has independently reviewed anything.

Claude may report:

```text
implementation complete
evidence collected
G9T evidence ready for independent review
```

but the final independent G9T PASS/FAIL determination remains with ChatGPT after reviewing the actual implementation and evidence.

---

# 37. Session Log

Maintain the established Session 21 Claude log using the repository's existing prompt/log naming convention.

If the established pattern corresponds to:

```text
docs/prompts/logs/session-21-log.md
```

use that path.

If the repository's actual existing convention differs, follow the existing convention rather than creating a duplicate hierarchy.

The log should preserve materially relevant contemporaneous evidence, including:

- repository state before implementation;
- branch check;
- files inspected;
- implementation decisions;
- external preflight results;
- deployed addresses;
- deployment transaction hashes;
- PoolId;
- source-verification results;
- bootstrap results;
- A1 results;
- A2 results;
- A3 rejection evidence;
- A4 results;
- final authoritative state;
- beneficiary balance evidence;
- protected-output custody evidence;
- local verification commands/results;
- blockers or deviations;
- completion report.

Do not include secrets.

The final completion report should be included in the session log.

---

# 38. ChatGPT Retrospective Evidence

After Claude implementation and ChatGPT independent review, ChatGPT will produce:

```text
docs/prompts/retrospective/session-21-chatgpt-record.md
```

This is a non-normative curated record of the substantive user ↔ ChatGPT reasoning associated with F9T.

Claude does not need to create this ChatGPT reasoning record.

Claude's responsibility is to preserve sufficient contemporaneous implementation evidence in the Session 21 log for the later retrospective.

---

# 39. Required Implementation Approach

Proceed in bounded phases.

First inspect the accepted repository and determine the minimum change set.

Then:

```text
A. Verify branch safety.

B. Inspect existing deployment/configuration/bootstrap/action architecture.

C. Implement Base Sepolia chain configuration.

D. Implement external infrastructure preflight.

E. Implement only the minimum public-periphery interfaces/orchestration required.

F. Add/adjust tests for the new configuration/orchestration.

G. Run local verification before live broadcast.

H. Verify RPC/deployer/funding without exposing secrets.

I. Execute public deployment.

J. Verify deployed contracts where practical.

K. Initialize/configure/bootstrap Standby.

L. Verify bootstrap S=80k/O=0.

M. Execute A1.

N. Verify A1.

O. Execute A2 through official Universal Router.

P. Verify A2.

Q. Execute A3 through official Universal Router and capture the expected Standby rejection.

R. Verify A3 state remains unchanged.

S. Execute A4 through ExerciseRouter.

T. Verify final authoritative state and beneficiary delivery.

U. Record public evidence.

V. Rerun local repository verification.

W. Update Session 21 log and completion report.

X. Stop at F9T completion boundary.
```

Do not broadcast live transactions before the relevant local implementation/configuration checks are clean.

---

# 40. Stop Conditions

Stop and report rather than improvising if any of the following occurs:

```text
repository is on main before modifications

unexpected dirty working tree materially conflicts with F9T work

Base Sepolia chain mismatch

external Uniswap bytecode missing

external Uniswap bindings mismatch

Universal Router actor attribution incompatible

PositionManager actor attribution incompatible

canonical CREATE2 Hook path unavailable

Hook permission address cannot be obtained through accepted mechanism

canonical token ordering cannot be preserved safely

pinned interfaces incompatible with required external behavior

PES cannot be activated with frozen topology

canonical liquidity cannot be established without semantic change

bootstrap S != 80,000 or O != 0

A1 does not produce canonical state

A2 cannot execute through official Universal Router

A3 failure cannot be attributed to Standby backing enforcement

A4 cannot preserve accepted direct-beneficiary delivery semantics

a dependency upgrade appears necessary

a production-semantic change appears necessary

wallet funding becomes insufficient

a secret would need to be committed or exposed
```

A cleanly identified external blocker is preferable to a semantically compromised deployment.

---

# 41. Prohibitions

Do not:

- redesign Standby;
- change accepted economic semantics;
- change the canonical fixture;
- change the protected direction;
- weaken actor attribution;
- trust hookData as actor identity;
- use ActorAwareTestRouter as F9T public-periphery evidence;
- replace official Universal Router with an arbitrary router;
- replace official PositionManager with a custom liquidity router;
- use the incompatible historical Universal Router;
- casually substitute a different Universal Router version;
- upgrade pinned Uniswap dependencies without review;
- create a second Hook deployment implementation;
- bypass HookMiner/CREATE2 requirements;
- change Hook permissions;
- add pre-activation canonical liquidity;
- route protected output through ExerciseRouter custody;
- change ExerciseRouter settlement semantics merely to use Permit2;
- modify F9/F10 acceptance semantics;
- rewrite the judged submission as though Base Sepolia was canonical;
- expose private keys;
- commit `.env`;
- record secrets in logs;
- claim production readiness;
- begin mainnet deployment;
- begin unrelated production hardening.

---

# 42. Completion Boundary

The F9T completion boundary is:

```text
appropriate non-main Session 21 branch confirmed

Base Sepolia configuration implemented

external infrastructure preflight implemented and passing

frozen current Uniswap v4 topology validated

canonical pinned dependency baseline preserved

canonical Hook deployment path reused

MockUSTB deployed with canonical semantics

MockUSDC deployed with canonical semantics

canonical token ordering preserved

EligibilityRegistry deployed

ExerciseRouter deployed

StandbyHook deployed through canonical HookMiner / CREATE2 path

Hook permission mask validated

Hook PoolManager binding validated

Standby-owned sources verified where practical

canonical PoolKey constructed

canonical pool initialized at tick 0

PES configured and activated with official Universal Router and PositionManager

eligibility configured

Universal Router Permit2 approvals configured

PositionManager Permit2 approvals configured

ExerciseRouter accepted payment approvals configured

canonical liquidity added through official PositionManager

bootstrap S=80,000 / O=0 verified

A1 canonical commitment executed

A1 S=80,000 / O=50,000 / Remaining=50,000 verified

A2 canonical ordinary swap executed through official Universal Router

A2 S=65,000 / O=50,000 / Remaining=50,000 verified

A3 canonical destructive ordinary swap attempted through official Universal Router

A3 Standby backing-specific rejection verified

A3 authoritative state unchanged at S=65,000 / O=50,000 / Remaining=50,000 verified

A4 canonical exercise executed through ExerciseRouter

authenticated exerciser payment verified

direct PoolManager-to-beneficiary delivery verified

beneficiary +50,000 MockUSDC verified

StandbyHook protected-output custody = 0 verified

ExerciseRouter protected-output custody = 0 verified

final S=15,000 / O=0 / Remaining=0 verified

deployment addresses recorded

PoolId recorded

relevant transaction hashes recorded

external infrastructure provenance recorded

source-verification status recorded

no secrets committed

reproducible public deployment/acceptance path preserved

full local repository verification clean

canonical Anvil acceptance unchanged

Session 21 Claude log updated

completion report produced

G9T evidence ready for ChatGPT independent review
```

Stop at the F9T completion boundary.

Do not begin:

```text
mainnet deployment

production hardening

new economic functionality

capacity pricing

production permissioning redesign

new Standby implementation slices
```

Do not mark G9T independently reviewed or finally PASS on ChatGPT's behalf.

Return the implementation, deployment, verification, and evidence package for independent review.
