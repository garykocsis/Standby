# Session 06 — Material Prompt Log

Initiating prompt: `docs/prompts/session-06-f4-commitment-storage-bounded-enforcement.md`

This file is an implementation-process audit artifact. It is not a normative
specification and does not define protocol semantics.

---

## Material Follow-Up Prompts

### 1 — Restrict the `project-status.md` change to status only

> I just need the status updated in project-status.md, do not add additional commentary. so continue

Rejected a proposed approach. While synchronizing `docs/project-status.md` for the authorized F4 slice,
an edit was proposed that would also have added descriptive sections to §7 "Current Repository
Implementation" covering the new `StandbyHook` commitment-storage responsibility and
`src/libraries/CommitmentRefs.sol`.

**Consequence:** that edit was not applied. The `docs/project-status.md` change is limited to
status-bearing fields: the header status line, §2 current-objective status, the §3 implementation-ladder
row for F4, §10 Current Blocker, §18 Next Action, and §19 Handoff Summary. No implementation description
was added to the document.

---

## Task Completion Report — F4 Commitment Storage + Bounded Enforcement References

### Files Inspected

Repository:

- `CLAUDE.md`, `.claude/rules/solidity-style.md`, `.claude/rules/testing.md`
- `docs/project-status.md`
- `docs/prompts/session-06-f4-commitment-storage-bounded-enforcement.md`, `docs/prompts/session-05-log.md`
- `docs/implementation-plan.md` (§8.2 Hook region decomposition H1–H7, §9 F4 / §9.1 objective / §9.2
  persistent commitment facts / §9.3 IDs / §9.4 bounded enforcement references / §9.5 `CommitmentRefs`
  responsibility / §9.6 harness use / §9.7 G4 persistence-minimality gate, §10.2 F5 production footprint,
  §12 F7 O1 admission surface, §22 canonical test tree)
- `docs/uniswap-v4-realization.md` (§9.8–9.9 RR-STATE-7/8, §10 commitment state and bounded enforcement
  references / §10.1 commitment basis / RR-O1-2 through RR-O1-9, §11 temporal semantics, §12.3 RR-O1-9
  bounded admissibility)
- `docs/state-machine.md` (§4 SM-1 persistent commitment authoritative basis, §4.3 identity, §4.4
  admission-time semantic basis, §4.7 admitted entitlement extent, §4.8–4.9 validity/exercisability terms,
  §4.10 authoritative fulfillment basis, §4.11 irreversible consequence basis, §4.12 commitment-state
  minimality, §5.9 no duplicated membership state, §12.9 bounded commitment realization)
- `docs/architecture.md` (§ derived-aggregate reproducibility, bounded potentially-live commitment set)
- `docs/invariants.md` (INV-01, INV-02, INV-05, INV-07, INV-08 scope boundaries)
- `docs/testing-strategy.md` (§13.3 reference-realization proof obligations: bounded live-commitment
  representation, slot/history reuse)
- `src/StandbyHook.sol`, `src/EligibilityRegistry.sol`, `src/interfaces/IEligibilityRegistry.sol`
- `script/DeployStandbyHook.s.sol`, `script/helpers/StandbyFixtureConfig.sol`
- `test/shared/BaseStandbyServiceTest.t.sol`, `test/harness/LiquidityPermissiveStandbyHookHarness.sol`,
  `test/unit/StandbyServiceLiquidityPrecondition.t.sol`,
  `test/integration/StandbyServiceConfiguration.t.sol`, `test/fuzz/EligibilityRegistryFuzz.t.sol`

Pinned Uniswap v4 dependency source:

- `lib/v4-hooks-public/src/base/BaseHook.sol` — `HookNotImplemented`, callback dispatch
- `lib/v4-hooks-public/src/utils/HookMiner.sol` — salt mining for the harness address
- `lib/v4-hooks-public/lib/v4-core/src/types/PoolId.sol`, `.../types/BalanceDelta.sol`,
  `.../types/PoolOperation.sol`

### Files Changed

Modified:

- `src/StandbyHook.sol` — added the H2 responsibility. New: the `Commitment` fact record type; the
  `MAX_LIVE_COMMITMENTS` public constant; three storage variables (`_nextCommitmentId`, `_commitments`,
  `_enforcementRefs`); three errors (`StandbyHook__CommitmentDoesNotExist`,
  `StandbyHook__InvalidEnforcementReferenceSlot`, `StandbyHook__DuplicateEnforcementReference`);
  constructor initialization of the identity counter to 1; three fact-only reads (`commitment`,
  `nextCommitmentId`, `enforcementReferences`); and four internal mechanics (`_recordCommitment`,
  `_writeRemainingEntitlement`, `_writeEnforcementReference`, `_commitmentExists`). The F3 trust basis,
  `configureAndActivate`, its validation sequence, the PES read surface, and the callback permission
  surface are untouched.
- `docs/project-status.md` — status-only synchronization recording the authorized F4 slice as implemented
  with G4 open (see material prompt 1).

Created:

- `src/libraries/CommitmentRefs.sol` — bounded structural scan mechanics over the fixed-size index
  (`slotOf`, `firstEmptySlot`) plus the single definition of `MAX_LIVE_COMMITMENTS` and the
  `EMPTY_REFERENCE` sentinel. No economic interpretation.
- `test/harness/StandbyHookHarness.sol` — pass-through exposure of the four internal F4 mechanics.
- `test/shared/BaseCommitmentStorageTest.t.sol` — shared F4 fixture: mined `StandbyHookHarness` over the
  real unconfigured environment, a seeded commitment-record builder, and a field-by-field record
  comparison helper.
- `test/unit/CommitmentStorage.t.sol` — 23 tests, G4-A/B/C/D/E.
- `test/unit/CommitmentRefs.t.sol` — 6 tests, library scan mechanics.
- `test/fuzz/CommitmentStorageFuzz.t.sol` — 9 fuzz tests.
- `test/fuzz/CommitmentRefsFuzz.t.sol` — 4 fuzz tests.
- `docs/prompts/session-06-log.md` — this audit artifact.

Deleted: none. `docs/setup.md` was deliberately not modified: F4 introduced no dependency, remapping,
compiler, environment-variable, or deployment-prerequisite change.

### Requirements Implemented

Commitment fact record (prompt §3, RR-O1-2/3, `state-machine.md` §4): exactly the seven frozen semantic
facts — `serviceId`, `beneficiary`, `exerciseAuthority`, `originalEntitlement`, `remainingEntitlement`,
`exercisableFrom`, `validUntil`. Immutable PES semantics are referenced through `serviceId`, never
snapshotted per commitment.

Remaining Entitlement (prompt §3.2): authoritative persistent state with its own storage mechanic. Not
derived from `originalEntitlement`, expiry, eligibility, reference membership, or time. No path exists by
which expiry or eligibility could alter it.

Commitment identity (prompt §5, RR-O1-5): `_nextCommitmentId` starts at 1, is consumed before each record
write, and only increases. `0` is the reserved nonexistent sentinel. Existence is judged from the counter
(`[1, nextCommitmentId)`) rather than from record contents, so a record whose facts are zero-valued is
still unambiguously an existing commitment.

Bounded enforcement references (prompt §6, RR-O1-4/6/7/8/9): a fixed `uint256[16]` index where `0` is
empty and a nonzero entry is a commitment identity. `_writeEnforcementReference` enforces the two
structural properties — every nonzero reference resolves to an existing historical commitment, and no
identity occupies two slots — and nothing else. Replacing an occupied slot leaves the displaced
commitment's historical record untouched.

Reclaimability boundary (prompt §7): no `isReclaimable`, `isBinding`, `isLive`, or equivalent exists in
production or in the harness. The index write makes no judgement about whether an occupied slot may be
taken over; that judgement is F5's.

Production API boundary (prompt §9): no `establishCommitment` or equivalent. The production surface is
storage representation, internal mechanics, and three fact-only reads. No derived economic read exists.

F3 preservation (prompt §10): one-shot PES configuration, the four fail-closed callbacks, the trust
semantics, and the service-domain semantics are unchanged; all 15 F3 integration tests, 31 configuration
tests, 5 geometry fuzz tests, and 2 liquidity-precondition tests still pass unmodified.

### Interpretation Decisions

Four points required deliberate reading; each is recorded so a reviewer can disagree explicitly.

1. **`Commitment` field order differs from the frozen listing.** The prompt permits deliberate width
   adjustment provided semantic content does not change; field order is likewise not semantic content.
   Fields are ordered `serviceId | beneficiary + exercisableFrom | exerciseAuthority + validUntil |
   originalEntitlement + remainingEntitlement`, which packs the record into 4 storage slots instead of 5
   (verified: 128 bytes). This matters because a later bounded enforcement scan reads up to 16 records
   inside an ordinary pool transaction, so the saved slot is ~2,100 cold-SLOAD gas per record scanned and
   ~20,000 gas per admission. The seven facts and their meanings are exactly the frozen set.

2. **A Remaining Entitlement write mechanic is included.** Prompt §3.2 assigns F4 "its persistent
   representation and the internal storage mechanics necessary for that later transition", and G4-B asks
   for evidence that Remaining Entitlement is represented independently of expiry and eligibility, which
   presupposes a storage primitive that changes it. `_writeRemainingEntitlement` therefore exists, and it
   applies no economic rule whatsoever: it does not require the value to decrease, does not bound it by
   the admitted extent, and does not ask why. F8 owns the decision of what to write.

3. **No slot-clearing mechanic.** Prompt §7 enumerates the permitted structural mechanics as scan, detect
   empty, detect duplicate, write, and replace — clearing a slot back to `0` is not among them, and
   reclamation in the frozen realization is replacement of a reclaimed slot by a new reference, not
   freeing. None was added. If a later slice genuinely needs to zero a slot, that slice should add it with
   its own justification.

4. **`MAX_LIVE_COMMITMENTS` is defined at file level in `CommitmentRefs.sol`.** Solidity accepts neither a
   library-qualified constant nor a contract's own constant as an array length in this position, so the
   single definition lives at file scope in the library file. `StandbyHook` imports it under an alias and
   republishes it as `MAX_LIVE_COMMITMENTS` public constant, so there is one value with the frozen public
   name and no shadowing.

Two further notes. F4 emits no event: the authoritative observable transition is commitment admission,
which F7 owns, and an event on a storage primitive that no production path reaches would record nothing.
`CommitmentRefs.firstEmptySlot` currently has no production caller — it is an F4-owned mechanic under
prompt §7 that F7 will consume, and it is verified directly.

### Tests Added or Changed

No existing test was changed, weakened, or removed.

`test/unit/CommitmentRefs.t.sol` (6 tests) — the library over an index of the production shape:

- the index is exactly sixteen slots wide;
- an empty index reports slot 0 as the first empty slot and references nothing;
- the sentinel is never reported as an occupant, in an empty index or a full one — the distinction that
  keeps "empty slot" and "reference to identity 0" from being the same observation;
- an identity is located at exactly its own slot, and a neighbouring value is not it;
- the reported empty slot is the lowest empty one, and follows the index rather than the write order;
- a full index reports no empty slot, and the scan reaches the final slot.

`test/unit/CommitmentStorage.t.sol` (23 tests):

- **G4-A** — allocation starts at 1 and `0` is reserved on both the harness and the production Hook;
  allocated identities are nonzero, unique, and strictly increasing with the counter advancing by exactly
  one; an identity beyond the allocated range does not exist and cannot be read; and the central test,
  which fills all sixteen slots, then displaces every one of them with a second generation, and shows that
  every displaced identity still exists, still reads back exactly as recorded, and that 32 identities were
  consumed exactly once.
- **G4-B** — exact round-trip of all seven facts; records are independent; the Remaining Entitlement write
  changes that field and provably leaves all six admission-fixed facts intact; a write to an unallocated
  identity is rejected and allocates nothing; warping a year past `validUntil` changes no stored fact;
  granting and then revoking Beneficiary eligibility in the real F2 registry changes no stored fact;
  reference writes — taking an empty slot, being displaced from an occupied one, and never being
  referenced — rewrite no fact.
- **G4-C** — sixteen slots, all empty at construction; a write occupies exactly the addressed slot; all
  sixteen slots fill and a seventeenth slot index is rejected; an out-of-range slot is rejected; identity
  `0` and an unallocated identity are both rejected and leave the slot empty; a duplicate is rejected with
  the occupied slot reported and neither slot disturbed; rewriting a slot with its own commitment is
  accepted; and membership carries no classification — an expired, zero-entitlement commitment is
  referenced exactly as readily as a large one with a distant expiry is left out.
- **G4-D / G4-E** — ten commitment creation and mutation signatures are absent from the production Hook,
  which has allocated no identity and holds an empty index; nine derived economic reads (`isValid`,
  `isExercisable`, `isBinding`, `isReclaimable`, `isLive`, `commitmentObligation`, `aggregateObligation`,
  `supportingCapacity`, `availableCapacity`) are absent from both the production Hook and the harness; all
  four enabled callbacks still revert `HookNotImplemented` when called as the PoolManager; and the F3
  boundary is intact — the service still activates, still refuses a second activation, and activation
  allocates no commitment identity while records can be written with no service configured.

`test/fuzz/CommitmentRefsFuzz.t.sol` (4 fuzz tests, 1000 runs default / 10000 in CI) — driven by a 16-bit
occupancy mask, so all `2 ** 16` index arrangements are reachable and expectations are computed from the
mask rather than from the library: any identity is found at its own slot and an unwritten one is never
found; the sentinel is never an occupant at any occupancy; the reported empty slot is the lowest empty one
with no lower slot empty, and a full index reports none; and occupied and empty slots partition the index.

`test/fuzz/CommitmentStorageFuzz.t.sol` (9 fuzz tests):

- arbitrary commitment facts — including economically nonsensical ones, which storage must still preserve
  because rejecting them is admission's job — round-trip exactly;
- any allocation history of up to 32 commitments produces identities in strict sequence from 1, all of
  which remain readable and unchanged, with the counter reflecting exactly the history;
- any Remaining Entitlement value is writable and never disturbs an admission-fixed fact;
- warping to any future timestamp past any `validUntil` alters no stored fact;
- any unallocated identity is uniformly rejected by the read, the entitlement write, and the reference
  write;
- a reference write occupies only the addressed slot, for every slot;
- every out-of-range slot index is rejected and leaves the index empty;
- any pair of distinct slots rejects a duplicate;
- and, under up to 48 writes across pseudo-randomly chosen slots, occupancy never exceeds sixteen, every
  nonzero reference resolves to an existing commitment, no identity occupies two slots, no identity is
  ever reused, and every commitment ever recorded — including every displaced one — still reads back
  exactly as recorded.

### Commands Run

```bash
git status
forge build
forge fmt
forge fmt --check
forge build --sizes
forge inspect src/StandbyHook.sol:StandbyHook storage
forge test --match-path "test/unit/Commitment*.t.sol"
forge test --match-path "test/fuzz/Commitment*.t.sol"
forge test
FOUNDRY_PROFILE=ci forge test
```

A temporary `src/LayoutProbe.sol` was created solely to read the `Commitment` struct storage layout, and
deleted immediately. It is not in the working tree.

### Results

- `forge fmt --check` — clean.
- `forge build --sizes` — successful, no warnings. `StandbyHook` deployed size 8,183 bytes (7,472 at F3;
  +711 bytes), 16,393 bytes of margin. `StandbyHookHarness` 9,178 bytes.
- `forge inspect ... storage` — `StandbyHook` gained exactly three storage variables: `_nextCommitmentId`
  (slot 6), `_commitments` (slot 7), `_enforcementRefs` (slots 8–23). The `Commitment` struct occupies
  128 bytes, i.e. 4 slots.
- `forge test --match-path "test/unit/Commitment*.t.sol"` — 29 passed, 0 failed.
- `forge test --match-path "test/fuzz/Commitment*.t.sol"` — 13 passed, 0 failed, 1000+ runs each.
- `forge test` — 140 passed, 0 failed, 0 skipped across 12 suites (98 before F4; 42 added).
- `FOUNDRY_PROFILE=ci forge test` — 140 passed, 0 failed, 0 skipped, 10,000+ runs per fuzz test.

One intermediate failure occurred and was fixed rather than suppressed: a fact-fidelity test wrote the
same commitment into two slots, which the duplicate guard correctly rejected. The test was wrong, not the
guard; it was rewritten to cover displacement and non-reference instead. No assertion was weakened.

### Gate Evidence

**Implemented and verified**

- **G4-A 1–6** — nonzero, unique, monotonic, non-recycled identities; slot reuse changes no historical
  identity; historical records stay readable after reuse. Proved at fixed shapes and across arbitrary
  allocation histories and slot-reuse sequences.
- **G4-B** — exact round-trip of all seven facts across arbitrary values; F4 mechanics never rewrite
  admission-fixed facts; Remaining Entitlement is represented independently of expiry and eligibility,
  demonstrated against real elapsed time and the real F2 registry. No O2 semantics are simulated: the
  entitlement write applies no economic rule.
- **G4-C 1–7** — sixteen slots exist; `0` is unambiguously empty and never an occupant; no seventeenth
  reference can exist; every nonzero reference resolves to an existing commitment; duplicates are
  impossible; replacement erases no history; membership carries no classification in either direction.
- **G4-D** — the storage layout shows exactly three new variables and no derived economic accounting; the
  record holds only the seven frozen facts; and no derived economic read exists on the production Hook or
  the harness.
- **G4-E** — no production commitment-establishment transition, no O1, no O2, no O3, no eligibility
  enforcement, and no economic reclaimability derivation exists; the four enabled callbacks remain fail
  closed; the F0–F3 suites pass unmodified.

**Verified with declared isolation**

- Every commitment record and reference in this evidence was written through `StandbyHookHarness`. F4
  deliberately introduces no production path that creates a commitment, so the mechanics could not
  otherwise be exercised at all. The harness declares no state, adds and removes no check, and
  re-implements nothing: allocation, the record write, the entitlement write, the existence predicate, and
  the reference write are the production implementations over production storage. What the harness
  supplies is authority. Nothing recorded here is an authentic Standby commitment, and none of it is
  offered as integration, invariant, periphery, or acceptance evidence.
- `CommitmentRefs` is exercised against an index of the production type owned by the test contract rather
  than by the Hook. The library code and the storage shape are the production ones; only the owner
  differs. The Hook's own use of the library — duplicate detection inside `_writeEnforcementReference` —
  is separately proved against Hook storage.

**Still unverified**

- No stateful invariant evidence exists for commitment storage. None is required by G4; GI owns it.
- No integration evidence exists for F4, and none is required: F4 introduces no authentic economic
  transition, and manufacturing one to satisfy a test-category hierarchy is explicitly forbidden by the
  prompt.
- The `firstEmptySlot` mechanic is verified but has no production caller until F7 consumes it.

### Known Limitations / Blockers

No blockers. Carried-forward limitations, none of which F4 affects:

- `HelperConfig` still resolves infrastructure only for chain id `31337`.
- The broadcasting `run()` path is verified in Foundry script simulation, not against a live Anvil node
  with `--broadcast`.
- The four enabled Hook callbacks still fail closed with `HookNotImplemented`. `StandbyHook` must still
  not be attached to a live pool.
- `test/shared/BaseV4Test.t.sol` still imports its v4 dependencies through filesystem-relative `lib/`
  traversal rather than the canonical remappings, contrary to `.claude/rules/solidity-style.md`.
  Pre-existing; not touched here to avoid unrelated churn.

New to F4, and by design rather than by omission: there is no mechanic that returns an occupied slot to
empty, and there is no rule constraining what Remaining Entitlement may be written. Both belong to
downstream slices.

### Scope Check

Work stayed within the authorized F4 slice. No economic derivation, no Supporting Capacity, no Aggregate
Capacity Obligation, no per-commitment obligation, no validity, exercisability, or reclaimability
predicate, no commitment admission, no exercise, no O3 enforcement, no eligibility consumption, no
ExerciseRouter behavior, no invariant handler, no acceptance test, and no frontend work was introduced.
`src/ExerciseRouter.sol` and `src/libraries/StandbyMath.sol` were not created.

Two changes touch files outside `src/StandbyHook.sol` and the F4 test locations, both within the prompt's
stated boundaries: `src/libraries/CommitmentRefs.sol` (prompt §8, §12) and the status-only
`docs/project-status.md` synchronization, which `CLAUDE.md` requires after a slice is explicitly
authorized and which material prompt 1 narrowed to status fields alone.

`docs/setup.md` was not modified, consistent with prompt §13.

### Proposed Gate Assessment

**PASS (proposed).**

All five G4 families have passing evidence. G4-A, G4-B, and G4-C are proved both at chosen boundary shapes
and across fuzzed input domains, with library-level expectations computed independently of the library.
G4-D is supported by the actual storage layout rather than by assertion alone. G4-E is proved against the
real production Hook with no harness involvement, which is the right instrument for a claim about the
production surface.

The one judgement a reviewer should make deliberately is the harness dependency. Every positive
commitment-storage result rests on `StandbyHookHarness`, because F4 is defined so that no production path
can create a commitment; harness-free evidence for these mechanics is not obtainable before F7 exists. The
harness is a pure pass-through and the negative evidence — that no such production path exists — is
harness-free. If the reviewer judges that G4 requires production-path evidence for the positive cases, that
condition cannot be satisfied within the F4 boundary, and the assessment becomes PARTIAL on those items.

Three interpretation decisions are also open to explicit disagreement: the packing-motivated field order,
the inclusion of `_writeRemainingEntitlement`, and the omission of a slot-clearing mechanic. Each is
argued in **Interpretation Decisions** above.

This is a proposed assessment only. G4 is not closed.

### Recommended Next Step

Submit F4 for G4 review. If G4 closes, the smallest coherent next responsibility is F5 — the authoritative
derivation kernel — which is the highest-risk slice and the first consumer of both the commitment records
and the bounded index. F5 is not started and is not authorized by this session.

### Prompt Audit

All material follow-up instructions were recorded in this log. **1 material follow-up prompt** was
recorded: prompt 1, which rejected the proposed addition of implementation description to
`docs/project-status.md` and narrowed that change to status fields only.
