# Session 02 — Material Prompt Log

Initiating prompt: `docs/prompts/session-02-f0-hook-deployment.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### Prompt 1 — G0 gate closure authorized; F1 designated next slice

**Instruction**

> G0 architectural/gate review is complete: G0 PASS is explicitly approved.
>
> Update `docs/project-status.md` only as necessary to record G0 as CLOSED / PASS and F1 —
> Deterministic Economic Fixture as the next implementation slice.
>
> Do not make any Solidity, test, deployment, setup, canonical semantic-document, or other
> implementation changes.
>
> Record this material follow-up in the current Session 02 prompt log in accordance with `CLAUDE.md`,
> then report the files changed.

**Why material**

It exercises gate authority that Claude Code does not hold: it converts the proposed G0 assessment into
an explicit closure and authorizes F1 as the next slice.

**Implementation consequence**

`docs/project-status.md` updated to record G0 as CLOSED / PASS and F1 — Deterministic Economic Fixture
as the current/next implementation slice (header, §2 current objective, §3 ladder, §4 F0 objective, §9
G0 status, §10 current blocker, §13 fixture status, §18 next action, §19 handoff summary).

No Solidity, test, deployment script, setup, or canonical semantic-document changes were made. F1 was
not started: the status document records it as authorized-but-not-started, pending an explicit task.

### Prompt 2 — F0 source review corrections

**Instruction**

Corrective follow-up from the architectural/source review of the F0 Hook deployment implementation.
Correct the implementation so it follows Standby's dependency-import discipline, source ownership
boundaries, naming conventions, and F0-accurate documentation without changing intended G0-H behavior.
Do not begin F1 or expand scope. Specifically:

1. Replace filesystem-relative imports into external `lib/` dependencies with canonical remapped
   imports (`v4-core/...`, `v4-hooks-public/...`, `v4-periphery/...`) across the Session 02 footprint,
   giving one canonical source identity per external dependency type. Standby-owned files may keep
   relative imports. Do not touch `NetworkConfig.sol` for churn.
2. Add two permanent conventions to `.claude/rules/solidity-style.md`: leading-underscore parameter
   naming (not trailing, and no `s_` state-variable prefix), and external-dependency import discipline.
3. Remove the file-level `REQUIRED_HOOK_PERMISSION_MASK` from `src/StandbyHook.sol`; the Hook owns its
   permission declaration through `getHookPermissions()` only, not deployment/mining configuration.
4. `DeployStandbyHook.s.sol` owns the mining requirement and derives its mask from the pinned `Hooks`
   flag constants. Do not claim the mask is "taken from the Hook itself" or that drift is structurally
   impossible; the two are separate representations whose equivalence is verified by tests. Preserve
   the layered deployment validation.
5. Retain `FROZEN_PERMISSION_MASK = 0x0AC0` as an independent oracle and preserve an independent test
   derivation, establishing equivalence across the declared struct, the independently derived mask, the
   deployment mask, the frozen value, and the deployed address bits.
6. Apply leading-underscore parameter naming where differentiation is required.
7. Correct NatSpec that overstates current F0 implementation, including the `StandbyHook` claim that it
   owns Standby economic truth.
8. Remove redundant generic `FUNCTIONS` section headers immediately followed by more meaningful ones.
9. Preserve current F0 behavior and G0-H coverage. The fail-closed callback test is an F0
   implementation-state regression test, not a permanent Standby economic invariant.

Update `docs/project-status.md` only if a correction changes the truth of the recorded G0 status; no
`docs/setup.md` update for import-style cleanup alone. Do not commit or push.

**Why material**

It rejects several implementation choices from the reviewed F0 work (permission-mask ownership,
import style, parameter naming, NatSpec claims), establishes two permanent repository conventions, and
narrows the correction scope explicitly.

**Implementation consequence**

Applied in full. `REQUIRED_HOOK_PERMISSION_MASK` moved out of `src/StandbyHook.sol` and is now a public
constant owned by `DeployStandbyHook`, derived from the pinned `Hooks` flags; the misleading
"taken from the Hook itself" comment was removed. Session 02 imports converted to the canonical
remapped forms. Parameters renamed to `_poolManager` / `_create2Deployer` / `_hook`.
`.claude/rules/solidity-style.md` gained Naming and External Dependency Imports sections. The mask
equivalence test was rewritten as
`test_permissionMask_isEquivalentAcrossDeclarationDeploymentAndAddress`, asserting the full chain. The
fail-closed test's NatSpec was reframed as an F0 implementation-state regression test.

No remappings were added: the required `v4-core/`, `v4-periphery/`, and `v4-hooks-public/` prefixes
already exist as Foundry auto-generated remappings, so `docs/setup.md` needed no change. G0 status was
unchanged; `docs/project-status.md` §7 was corrected only where the mask relocation made it false.

One item was reported rather than actioned: `test/shared/BaseV4Test.t.sol` (Session 01, outside the
Session 02 footprint) still uses relative `lib/` traversal and now violates the new import rule.

---

# Required Task Completion Report — Session 02

## Files Inspected

Repository:

- `CLAUDE.md`
- `.claude/rules/solidity-style.md`
- `.claude/rules/testing.md`
- `docs/prompts/session-02-f0-hook-deployment.md`
- `docs/project-status.md`
- `docs/implementation-plan.md` (§4.1, §5 F0 / G0)
- `docs/uniswap-v4-realization.md` (§18 pool enforcement surface)
- `docs/setup.md`
- `foundry.toml`
- `test/shared/BaseV4Test.t.sol`
- `test/integration/V4Infrastructure.t.sol`

Pinned dependency source:

- `lib/v4-hooks-public/lib/v4-core/src/libraries/Hooks.sol`
- `lib/v4-hooks-public/lib/v4-core/src/PoolManager.sol` (constructor signature)
- `lib/v4-hooks-public/lib/v4-periphery/src/base/ImmutableState.sol`
- `lib/v4-hooks-public/src/base/BaseHook.sol`
- `lib/v4-hooks-public/src/utils/HookMiner.sol`
- `lib/v4-hooks-public/lib/v4-periphery/test/shared/HookMiner.sol` (compared)
- `lib/forge-std/src/Base.sol` (`CREATE2_FACTORY`)

## Files Changed

Created:

- `src/StandbyHook.sol` — the minimum production Standby Hook: immutable PoolManager binding plus the
  required callback-permission surface. (Per Prompt 2 the mining mask no longer lives here.)
- `script/helpers/NetworkConfig.sol` — infrastructure-only configuration type (chain id, PoolManager).
- `script/helpers/HelperConfig.s.sol` — infrastructure resolution for the active chain.
- `script/DeployStandbyHook.s.sol` — the single canonical deterministic Hook deployment procedure.
- `test/integration/StandbyHookDeployment.t.sol` — G0-H1..G0-H5 integration evidence.
- `docs/prompts/session-02-log.md` — this session log.

Modified:

- `docs/project-status.md` — records the implemented F0 Hook deployment responsibility and the G0
  verification evidence; G0 recorded as OPEN with a proposed PASS awaiting review.

Deleted: none.

## Requirements Implemented

- Implementation plan §5.4 — canonical `DeployStandbyHook` procedure (resolve PoolManager, derive
  permission mask, mine address/salt, deploy, validate address permissions, verify binding, report).
- Implementation plan §5.3 — `HelperConfig` / `NetworkConfig` infrastructure-only boundary.
- Implementation plan §5.5 / G0 requirement 5 — permission-valid deterministic Hook address.
- `uniswap-v4-realization.md` §18.1 — frozen Hook permission surface (`0x0AC0`), all other callbacks and
  all return-delta permissions disabled; callbacks authenticated against the immutable PoolManager.

No Standby economic semantics were implemented.

## Tests Added or Changed

Added `test/integration/StandbyHookDeployment.t.sol` (12 tests):

- `test_standbyHook_declaresExactlyTheAuthorizedCallbackPermissions` — G0-H1 callback surface.
- `test_standbyHook_declaresNoReturnDeltaPermissions` — G0-H1 return-delta surface.
- `test_requiredPermissionMask_reproducesDeclaredPermissions` — G0-H1; independently reconstructs the
  mask from the declared struct and the pinned `Hooks` flag constants, then checks it against the
  production mining mask and against the frozen `0x0AC0` / `2752`.
- `test_deployedHookAddress_encodesExactlyTheRequiredPermissionBits` — G0-H2; flag-by-flag address check
  through the pinned `Hooks.hasPermission`, proving required bits present and unauthorized bits absent.
- `test_deployedHookAddress_satisfiesPinnedHookValidator` — G0-H2; the pinned
  `Hooks.validateHookPermissions` accepts the deployed address against the declared struct.
- `test_deployedHook_isBoundToTheIntendedPoolManager` — G0-H3.
- `test_deployedHook_rejectsCallbacksFromNonPoolManager` — G0-H3; binding is enforced (`NotPoolManager`).
- `test_enabledCallbacks_failClosedUntilEnforcementIsImplemented` — proves F0 introduces no economics:
  an authenticated PoolManager callback reverts `HookNotImplemented` rather than silently permitting.
- `test_canonicalDeployment_producesTheDeterministicMinedAddress` — G0-H4; the deployed address equals
  `HookMiner.computeAddress` for the mined salt.
- `test_canonicalDeployment_usesHelperConfigResolvedPoolManager` — G0-H4; the composition `run()` performs.
- `test_helperConfig_rejectsUnsupportedNetwork` — infrastructure resolution rejects unvalidated chains.
- `test_hookDeployment_requiresNoEconomicFixture` — G0-H5; a second Hook deploys against a second real
  PoolManager with no currencies, pool, ordering, protected direction, or service configuration present.

Existing tests were not changed.

## Commands Run

```bash
git status
forge build
forge fmt
forge fmt --check
forge lint src script test
forge build --sizes
forge test --match-path test/integration/StandbyHookDeployment.t.sol -vv
forge test -vv
FOUNDRY_PROFILE=ci forge test
forge script script/DeployStandbyHook.s.sol
```

## Results

- `forge fmt --check` — clean.
- `forge lint src script test` — no findings.
- `forge build --sizes` — successful; `StandbyHook` runtime size 2,756 bytes.
- `forge test --match-path test/integration/StandbyHookDeployment.t.sol -vv` — 12 passed, 0 failed.
- `forge test -vv` — 14 passed, 0 failed, 0 skipped (2 suites).
- `FOUNDRY_PROFILE=ci forge test` — 14 passed, 0 failed, 0 skipped.
- `forge script script/DeployStandbyHook.s.sol` — ran successfully in simulation; resolved PoolManager
  `0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496`, mined salt `0x…1c5d`, deployed Hook
  `0xEBeC656238fD11B395CAE99f431F314cB5DcCac0` (low 14 bits = `0x0AC0`) through the CREATE2 factory path.

## Gate Evidence

Implemented and verified:

- G0-H1 exact Hook permissions — verified.
- G0-H2 deployed-address permission validity against the pinned `Hooks` implementation — verified.
- G0-H3 immutable PoolManager binding, including runtime rejection of non-PoolManager callers — verified.
- G0-H4 deterministic deployment path (mined salt reproduces the deployed CREATE2 address; the
  procedure composes with `HelperConfig`; the script entrypoint executes in script simulation) — verified.
- G0-H5 fixture independence — verified.
- Existing G0 infrastructure evidence (real PoolManager, initialization, liquidity, both swap
  directions) — re-run and still passing; not regressed.

Still unverified:

- The broadcasting `run()` path against a live Anvil node with `--broadcast` (verified in Foundry
  script simulation only).
- Public-chain infrastructure resolution (deliberately rejected rather than guessed).
- All Standby economic behavior — out of scope for F0.

## Known Limitations / Blockers

- `HelperConfig` supports only chain id `31337`. Public-chain PoolManager addresses were not added
  because no validated address baseline exists yet; `HelperConfig__UnsupportedNetwork` is raised instead
  of guessing. This must be resolved before any public deployment.
- The four enabled Hook callbacks fail closed with `HookNotImplemented`. This is deliberate: F0 deploys
  the frozen permission surface without weakening it, and enforcement belongs to later slices.
  Consequently `StandbyHook` must not be attached to a live pool until those slices exist.
- ~~`REQUIRED_HOOK_PERMISSION_MASK` is a file-level constant in `src/StandbyHook.sol`.~~ Superseded by
  Prompt 2: the mask is now a public constant owned by `DeployStandbyHook`, derived from the pinned
  `Hooks` flag constants, and its equivalence with the Hook's declared permissions is established by
  test rather than by shared construction.

No stop condition was triggered. No frozen-document contradiction was found.

## Scope Check

Work remained within the authorized Session 02 slice. Only the expected implementation footprint was
created (`src/StandbyHook.sol`, `script/DeployStandbyHook.s.sol`, `script/helpers/*`, one integration
test) plus the authorized `docs/project-status.md` update and this session log. No shared test utility
was added; `BaseV4Test` was not modified. No prohibited economic behavior, registry, router,
settlement, fixture, or frontend work was introduced. No dependency revision was changed and no
remapping was added.

## Proposed Gate Assessment

**PASS (proposed).**

All five G0 requirements now have implementation plus verification evidence, including the five G0-H
requirements defined by the session prompt, and the previously validated infrastructure evidence is not
regressed. This is a proposed assessment only; G0 is recorded as OPEN pending explicit review closure.

## Recommended Next Step

Review the recorded G0 evidence and explicitly close G0. Do not begin F1 — Deterministic Economic
Fixture — before that decision.

## Prompt Audit

All material follow-up instructions were recorded in `docs/prompts/session-02-log.md`.

**Material prompts recorded: 2** (Prompt 1 — G0 gate closure authorized; F1 designated next slice.
Prompt 2 — F0 source review corrections).

---

## Gate Outcome

The proposed G0 assessment above was subsequently reviewed and explicitly approved (see Prompt 1).

**G0 — Vanilla v4 Infrastructure: CLOSED / PASS.** Next slice: F1 — Deterministic Economic Fixture
(authorized, not started).

---

# Task Completion Report — Session 02 Corrections (Prompt 2)

## Files Inspected

- `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`, `CLAUDE.md`
- `docs/project-status.md`, `docs/setup.md` (Remappings section)
- `src/StandbyHook.sol`, `script/DeployStandbyHook.s.sol`, `script/helpers/HelperConfig.s.sol`,
  `script/helpers/NetworkConfig.sol`, `test/integration/StandbyHookDeployment.t.sol`,
  `test/shared/BaseV4Test.t.sol`
- Effective dependency resolution via `forge remappings`
- Build source-unit manifest via `out/build-info/*.json`

## Files Changed

- `src/StandbyHook.sol` — removed the file-level `REQUIRED_HOOK_PERMISSION_MASK`; canonical remapped
  imports; constructor parameter renamed `_poolManager`; F0-accurate title/NatSpec (no longer claims to
  own Standby economic truth); removed the redundant `FUNCTIONS` header.
- `script/DeployStandbyHook.s.sol` — now owns `REQUIRED_HOOK_PERMISSION_MASK` as a public constant
  derived from the pinned `Hooks` flag constants; removed the misleading "taken from the Hook itself"
  comment and replaced it with an accurate separate-representation note; canonical remapped imports;
  parameters renamed `_poolManager` / `_create2Deployer` / `_hook`; removed the redundant `FUNCTIONS`
  header. Layered deployment validation preserved unchanged.
- `script/helpers/HelperConfig.s.sol` — canonical remapped import; removed the redundant `FUNCTIONS`
  header.
- `test/integration/StandbyHookDeployment.t.sol` — canonical remapped imports; mask-equivalence test
  rewritten as `test_permissionMask_isEquivalentAcrossDeclarationDeploymentAndAddress`; fail-closed
  test NatSpec reframed as an F0 implementation-state regression test; redundant `FUNCTIONS` header
  replaced with `SETUP`.
- `.claude/rules/solidity-style.md` — added `# Naming` (leading-underscore parameters, no trailing
  underscore, no `s_` prefix) and `# External Dependency Imports` (remapped external prefixes,
  prohibition on relative `lib/` traversal, one canonical source identity per dependency type,
  remapping changes recorded in `docs/setup.md`).
- `docs/project-status.md` — §7 corrected where the mask relocation made it false. G0 status unchanged.

Not changed: `script/helpers/NetworkConfig.sol` (no correction required), `docs/setup.md` (no remapping
or environment change), `test/shared/BaseV4Test.t.sol` (outside the Session 02 footprint).

## Commands Run

```bash
forge remappings
forge fmt
forge fmt --check
forge clean && forge build
forge build --force
forge lint src script test
forge test --match-path test/integration/StandbyHookDeployment.t.sol -vv
forge test -vv
FOUNDRY_PROFILE=ci forge test
forge script script/DeployStandbyHook.s.sol
```

## Results

- `forge fmt --check` clean; `forge lint` no findings.
- Clean `forge build` from `forge clean`: successful, 82 source units.
- Focused Hook deployment suite: 12 passed, 0 failed.
- Full suite: 14 passed, 0 failed, 0 skipped — identical under the `ci` profile.
- Script simulation reproduced the pre-correction deployment exactly: salt
  `0x…1c5d`, Hook `0xEBeC656238fD11B395CAE99f431F314cB5DcCac0`.

## Verification Evidence

- **No duplicate dependency-type identities.** The build manifest contains exactly one source unit each
  for `IPoolManager.sol`, `IHooks.sol`, `Hooks.sol`, `PoolKey.sol`, `PoolOperation.sol`,
  `PoolManager.sol`, `BaseHook.sol`, `HookMiner.sol`, and `ImmutableState.sol`. Total source-unit count
  is unchanged at 82.
- **Mask equivalence.** `test_permissionMask_isEquivalentAcrossDeclarationDeploymentAndAddress` proves
  the independently reconstructed mask equals `FROZEN_PERMISSION_MASK` (`0x0AC0` / `2752`), equals
  `DeployStandbyHook.REQUIRED_HOOK_PERMISSION_MASK()`, and equals the deployed address bits.
- **Address bits.** `test_deployedHookAddress_encodesExactlyTheRequiredPermissionBits` checks all
  fourteen flags individually through the pinned `Hooks.hasPermission`.
- **Pinned validator.** `test_deployedHookAddress_satisfiesPinnedHookValidator` passes.
- **PoolManager binding.** Binding and non-PoolManager rejection tests pass.
- **Behavior unchanged.** Identical mined salt and Hook address before and after the corrections, which
  is direct evidence that `StandbyHook` creation code and the deployment derivation are unchanged.

## Known Limitations / Blockers

- `test/shared/BaseV4Test.t.sol` still imports through relative `lib/` traversal and now violates the
  newly added import rule. It is outside the authorized Session 02 footprint, so it was reported rather
  than changed. Its imports resolve to the same source units, so no duplicate identity exists.
- The Solidity IDE language server reports the remapped imports as unresolved because no
  `remappings.txt` is checked in; Foundry resolves them from auto-generated remappings and the build,
  tests, and script simulation all pass. Making them explicit would be a setup change requiring a
  `docs/setup.md` update, which this prompt did not authorize.

No pinned-dependency incompatibility was found and no G0 assumption was invalidated.

## Scope Check

Within the authorized correction scope. No Standby economics introduced, no ladder advancement, no
commit or push, `NetworkConfig.sol` and `docs/setup.md` untouched.

## Proposed Gate Assessment

**PASS (unchanged).** G0 remains CLOSED / PASS; the corrections preserved all G0-H behavioral coverage
and the deterministic deployment result is byte-identical.

## Recommended Next Step

Review the corrected source. Then either authorize the `BaseV4Test.t.sol` import cleanup as a small
follow-up, or begin F1 — Deterministic Economic Fixture when explicitly tasked.
