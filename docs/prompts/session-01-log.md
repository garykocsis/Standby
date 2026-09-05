# Session 01 — Material Prompt Log

**Session:** 01
**Preserved prompt:** `docs/prompts/session-01-f0-bootstrap.md`
**Slice / Gate:** F0 — v4 Infrastructure / G0 — Vanilla v4 Infrastructure
**Session type:** Read-only orientation and audit (no implementation authorized)

This log is an audit artifact, not a normative specification. It records only
material follow-up instructions per the Material Prompt Logging rule in `CLAUDE.md`.

---

## Initiating instruction

> Read root CLAUDE.md, then execute docs/prompts/session-01-f0-bootstrap.md as the
> authorized Session 01 task. Stop at the completion boundary defined by that prompt.

Consequence: executed the Session 01 read-only F0/G0 orientation and audit as
defined by the preserved session prompt. No production Solidity, tests, docs, or
dependencies were modified. The only repository modification is this session log.

---

## Material follow-up instructions

None recorded.

(Routine local-scratch actions issued before the session began — creating and
deleting a throwaway `src/Placeholder.sol` — were not part of this session's
authorized task and are not material to the F0/G0 audit.)

**Count of material follow-up prompts recorded: 0.**

Session 01 — F0 Bootstrap / Orientation Audit — Completion Report

Files Inspected

Repository

- CLAUDE.md, docs/prompts/session-01-f0-bootstrap.md, docs/project-status.md
- docs/implementation-plan.md (§5 F0 / §5.5 G0 read in full; downstream slices skimmed)
- docs/uniswap-v4-realization.md (§8, §18.1 permission surface), docs/architecture.md (hook-permission completeness/minimality)
- test/shared/BaseV4Test.t.sol, test/integration/V4Infrastructure.t.sol
- foundry.toml, .gitmodules, foundry.lock

Pinned dependency

- lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol (permission flags, validateHookPermissions, isValidHookAddress, hasPermission)
- lib/v4-hooks-public/src/utils/HookMiner.sol (find/computeAddress)

Files Changed

- Created docs/prompts/session-01-log.md — the session's matnly modification authorized by the prompt). No productionSolidity, tests, docs, or dependencies were touched.

Requirements Implemented

None. This was a read-only orientation/audit session; implementation was explicitly not authorized.

Tests Added or Changed

None.

Commands Run

- git status, git submodule status --recursive, git -C lib/vus
- forge --version, forge remappings, forge build
- forge test --match-path "test/integration/V4Infrastructure.t.sol" -vv

Results

- Build: compiles clean (cached; no errors).
- forge --version: 1.3.5-stable (matches baseline).
- F0 integration test: 2 passed, 0 failed — test_vanillaV4Inest_vanillaV4Infrastructure_oneForZero, exercising the realPoolManager + official PoolModifyLiquidityTest/PoolSwapTest execution path.

---

Independent F0 / G0 Assessment

Per implementation-plan §5.5, verified against actual repository evidence:

┌───────────────────────────────────┬───────────────┬───────────────────────────────────────────────────────────────┐
│ G0 requirement │ Status │ Evidence │
├───────────────────────────────────┼───────────────┼───────────────────────────────────────────────────────────────┤
│ Real PoolManager │ PASS │ BaseV4Test.setUp deploys real PoolManager; no Standby mock substitutes core behavior │
│ deployed/resolved │ │ │
├───────────────────────────────────┼───────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Vanilla pool initialization │ PASS │ \_initializePool → poolManager.initialize; both tests pass │
├───────────────────────────────────┼───────────────┼───────────────────────────────────────────────────────────────┤
│ Vanilla liquidity addition │ PASS │ \_addLiquidity via official PoolModifyLiquidityTest │
├───────────────────────────────────┼───────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Vanilla swap execution │ PASS │ \_swapExactInput via official PoolSwapTest; balance deltas asserted │
├───────────────────────────────────┼───────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Direction-neutral shared │ PASS │ Both zno protected-direction assumption baked in; generic │
│ infrastructure │ │ 18-dec tokens, not the F1 6-dec fixture │
├───────────────────────────────────┼───────────────┼───────────────────────────────────────────────────────────────┤
│ Canonical StandbyHook deployment │ NOT │ No src/StandbyHook.sol, no script/ directory, no DeployStandbyHook.s.sol │
│ procedure │ IMPLEMENTED │ │
├───────────────────────────────────┼───────────────┼────────────────────────────────────────────────────────────────────────────────────────────┤
│ Hook address permission │ NOT │ No hook, no deployment, no permission-bit assertion │
│ validation │ IMPLEMENTED │ │
└───────────────────────────────────┴───────────────┴────────────────────────────────────────────────────────────────────────────────────────────┘

src/ contains only .DS_Store — no production Solidity exists. G0 remains OPEN / PARTIAL PASS, exactly as project-status §9 records. Project-status
accurately reflects repository reality.

Hook Deployment Investigation (pinned source)

- Permission representation — Hooks.sol encodes 14 permissio the hook address (ALL_HOOK_MASK = (1<<14)-1). RequiredStandby flags and bit positions:
  - BEFORE_ADD_LIQUIDITY_FLAG = 1<<11, BEFORE_REMOVE_LIQUIDITY_FLAG = 1<<9, BEFORE_SWAP_FLAG = 1<<7, AFTER_SWAP_FLAG = 1<<6.
  - Required mask = 0xAC0 (2752). All other callback and all
- Required surface confirmed upstream — uniswap-v4-realization.md §18.1 independently lists exactly these four callbacks with all return-delta permissions disabled; architecture.md leaves the concrete config to realization (complete-but-minimal). No authority-hierarchy conflict.
- Validation — validateHookPermissions(self, Permissions) reverts unless declared permissions exactly match address bits; isValidHookAddress
  additionally forbids return-delta flags without their parent to expose getHookPermissions() returning the Permissionsstruct that must match its deployed address.
- Deterministic deployment — pinned HookMiner.find(deployer,ctorArgs) brute-forces a CREATE2 salt whose resulting address has the low-14-bits == flags & 0xAC0 and no existing code. In forge script the deployer must be the CREATE2 proxy
  0x4e59b44847b379578588920cA78FbF26c0B4956C; in tests it is a
- Minimal F0 constructor — StandbyHook needs only an immutable IPoolManager binding at F0 (no service/fixture facts — those belong to F3). Deployment
  must then assert Hooks.validateHookPermissions (or equivalen declared permissions.
- No conflict found between pinned dependency behavior and Standby realization assumptions.

Dependency & Toolchain Check

- Foundry 1.3.5-stable; solc 0.8.26; EVM cancun; via_ir=false; optimizer on, runs=800; bytecode_hash=none; ffi=false. Matches project-status §5–6.
- Checked-out gitlinks match the validated baseline exactly: v4-hooks-public 0f731d5…, v4-core d153b048… (v4.0.0-19), v4-periphery 07336f21….
  foundry.lock pins v4-hooks-public to the same rev. No discreckfile, and checked-out state.
- Remappings are auto-generated (no remappings.txt); @uniswap/v4-core/ → lib/v4-hooks-public/lib/v4-core/ resolves, so HookMiner's import will compile
  in this project without adding a remapping.

Documentation Check

- project-status.md accurately reflects reality (G0 OPEN, items 1–4 pass, item 5 unimplemented).
- implementation-plan.md §5.4/§5.5 sufficiently defines the
- setup.md was not read this session (not required to complete the audit; toolchain values were cross-checked against live forge --version and gitlinks, which agree). Minor note only — no discrepancy surfaced.

Known Limitations / Blockers

- G0 cannot close until canonical StandbyHook deployment + permission-bit validation exists (project-status §10 blocker).
- test/ and docs/ remain untracked and foundry.toml is modifrking state); no commit is authorized.

Scope Check

Stayed within the authorized read-only audit. Only docs/promated, as the prompt permits. No production code, tests,frozen docs, or dependencies changed.

Proposed Gate Assessment

G0 — PARTIAL. Requirements 1–4 (real PoolManager, init, liquidity, swap) have valid passing evidence through the real v4 stack and are
direction-neutral. Requirement 5 (permission-valid StandbyHoed. This is a proposed assessment only; I do not haveauthority to close G0.

Recommended Next Step (one slice — do not implement without instruction)

Implement the canonical StandbyHook F0 deployment path with rmission validation.

- Objective: deploy a StandbyHook whose address bits equal 0xAC0 and whose declared permissions match, via one reusable fixture-agnostic path.
- Governing requirements: implementation-plan §5.4/§5.5; uniswap-v4-realization §18.1; project-status §10–11.
- Likely files: src/StandbyHook.sol (immutable i_poolManager, getHookPermissions() returning the four flags), script/DeployStandbyHook.s.sol, script/helpers/HelperConfig.s.sol + NetworkConfig.sol, and a G0 hook-deployment test under test/integration/.
- Pinned APIs: HookMiner.find/computeAddress, Hooks.validatedress, Hooks.\*\_FLAG constants; CREATE2 proxy 0x4e59b448… forscripts.
- Required evidence: deployed address low-14-bits == 0xAC0; abled, all others + all return-delta flags false; immutablePoolManager binding correct. Must be proven on the real deployed hook, not a harness.
- Prohibited shortcuts: no weaker temporary permission surfa (S/O/commitments — F1+ territory); no vm.store/harnessseeding for this gate; do not add a redundant @uniswap/v4-core remapping (already auto-resolved); keep the deployer fixture-agnostic (no MockUSTB/MockUSDC/ticks/PoolKey).

Prompt Audit

All material follow-up instructions were recorded in docs/prompts/session-01-log.md. Material follow-up prompts recorded: 0 (the initiating instruction defined the entire authorized task; no scope-changing follow-ups were issued).
