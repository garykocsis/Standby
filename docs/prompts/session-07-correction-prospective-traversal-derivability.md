# Standby — Session 07 Correction Prompt

## 1. Session Purpose

This is a **targeted correction and revalidation pass for F5 — Authoritative Derivation Kernel**.

Do not treat this as a new implementation slice.

The objective is to resolve one realization-level defect discovered during independent G5 review:

> The current Uniswap v4 prospective swap derivation correctly reproduces multi-step v4 traversal, but the realization permits PES configurations whose immutable service domain may require more prospective swap steps than the implementation supports.

The required correction is:

> **Every activated PES must be provably within the supported bounded prospective-swap derivation domain.**

This correction must preserve all previously frozen Standby economic semantics.

---

# 2. Permanent Operating Rules

Read and follow root `CLAUDE.md` and `.claude/rules/*`.

Permanent operating behavior, Git discipline, documentation discipline, testing conventions, completion reporting, prompt auditing, dependency discipline, and gate authority remain owned there.

Do not restate or redefine those rules in implementation.

This prompt owns only the correction-specific:

- objective;
- scope;
- requirements;
- prohibitions;
- file boundaries;
- verification evidence;
- completion boundary.

---

# 3. Authoritative Source Order

Use the following source hierarchy:

1. frozen canonical Standby package;
2. amended `docs/uniswap-v4-realization.md`;
3. amended `docs/implementation-plan.md`;
4. existing F0–F5 implementation;
5. this correction prompt.

The canonical package remains authoritative for Standby protocol meaning.

The amended Uniswap v4 realization owns the corrected realization semantics.

Do not modify protocol economics to make implementation convenient.

---

# 4. Correction Classification

This correction does **not** reopen:

- `context.md`;
- `economic-agreement.md`;
- `mechanism.md`;
- `spec.md`;
- `architecture.md`;
- `state-machine.md`;
- `invariants.md`;
- `testing-strategy.md`.

The discovery is a **Uniswap v4 realization correction**.

The previously frozen no-interior-initialized-liquidity-boundary restriction remains valid.

The corrected distinction is:

```text
no initialized liquidity boundary strictly inside service domain
→ stable active-liquidity region

but

stable active-liquidity region
≠
single SwapMath.computeSwapStep execution
```

Uninitialized tick-bitmap word boundaries may divide the v4 swap path into multiple arithmetic steps without changing active liquidity.

---

# 5. Corrected Realization Rule

The production prospective swap derivation must continue to reproduce the economically relevant Uniswap v4 swap-loop semantics required to determine exact prospective state.

Do **not** revert to a single-step approximation.

The production derivation must preserve the already implemented exact bounded traversal behavior, including the v4 semantics relevant to:

- current exact `sqrtPriceX96`;
- current active liquidity;
- authoritative `SwapParams`;
- effective LP/protocol fee treatment;
- `SwapMath.computeSwapStep`;
- tick-bitmap traversal;
- relevant initialized-boundary handling;
- tick transitions;
- caller price limit;
- configured service-domain confinement.

After prospective state is derived, Supporting Capacity must continue to be recomputed through the same authoritative production Supporting Capacity derivation used for current state.

Do not introduce a second capacity formula.

---

# 6. Bounded Traversal Requirement

The MVP reference realization intentionally keeps prospective swap derivation bounded.

Retain the existing production traversal limit unless implementation evidence shows a correctness defect in the constant itself:

```text
MAX_PROSPECTIVE_SWAP_STEPS = 16
```

Do not solve this task by:

- deleting the traversal bound;
- silently increasing the bound;
- truncating traversal;
- approximating the post-state;
- allowing unsupported configurations and relying only on runtime refusal.

The runtime bound remains defensive fail-closed protection.

The correction required in this session is **admission-time derivability**.

---

# 7. Admission-Time Prospective Derivability

Define conceptually:

```text
D = maximum prospective traversal demand implied by
    the proposed immutable service domain
    + PoolKey tick spacing
    + supported v4 traversal semantics

M = supported maximum prospective swap-step count
```

PES activation requires:

```text
D <= M
```

A proposed service configuration for which:

```text
D > M
```

must fail during `configureAndActivate(...)` before any authoritative PES persistence occurs.

Required realization property:

```text
ACTIVATED PES
⇒
every supported in-domain prospective swap path is derivable
within the implementation's supported traversal bound
```

Runtime `ProspectiveSwapStepBoundExceeded` remains defensive fail-closed protection and must not be the ordinary mechanism by which an activated service discovers that its immutable service domain is unsupported.

---

# 8. Responsibility Ownership

Preserve existing production ownership.

## `ServiceDomain.sol`

May own a **pure derivation/classification** of prospective traversal demand from:

- service-domain ticks;
- tick spacing;
- protected direction if materially required by the derivation;
- pinned v4 tick-compression / bitmap-word semantics.

It must remain pure.

It must not:

- read PoolManager;
- read Hook storage;
- read Registry;
- inspect commitments;
- derive O;
- decide transition authority;
- persist state;
- own the final activation revert policy.

Its responsibility is:

> **derive the realization-topology fact.**

## `StandbyHook.sol`

Owns:

- authoritative service configuration;
- the supported production traversal bound;
- application of the admission rule during `configureAndActivate(...)`;
- atomic rejection before PES persistence.

Its responsibility is:

> **decide whether the proposed immutable service basis lies within the supported realization domain.**

Do not add redundant persistent state for traversal demand if it remains deterministically derivable from immutable PES facts.

---

# 9. F3 Boundary

This correction touches `configureAndActivate(...)`, but it does **not** reopen the broader F3 design.

Preserve all existing F3 semantics:

- one-shot configuration;
- UNCONFIGURED → ACTIVATED;
- exact PoolKey / PoolId basis;
- zero-liquidity bootstrap;
- static supported fee model;
- current price inside closed service domain;
- immutable `tickQ`;
- immutable `tickO`;
- immutable protected direction;
- immutable Registry reference;
- immutable trusted perimeters;
- immutable ExerciseRouter;
- immutable establishment authority;
- no pause;
- no deactivation;
- no reinterpretation;
- no migration.

The only authorized F3 correction is:

> add the realization-admissibility check required to ensure the immutable service domain is prospectively derivable within the supported F5 traversal bound.

All configuration validation must still precede authoritative PES persistence.

---

# 10. Exact Traversal-Demand Derivation

Do not guess the traversal-demand formula.

Inspect the pinned v4 implementation actually compiled by Standby, especially the exact logic governing:

- tick compression;
- bitmap-word indexing;
- `nextInitializedTickWithinOneWord`;
- direction-sensitive word traversal;
- negative tick behavior;
- word-edge behavior.

The admission classifier must be conservative enough that:

```text
accepted configuration
⇒
no supported in-domain path can require more than M traversal steps
```

but it must not be unnecessarily stronger than required.

Do not reject a valid domain merely because a naïve absolute-tick-width approximation overestimates the true maximum traversal count if the exact pinned v4 bitmap semantics permit a less restrictive correct derivation.

The implementation should derive the bound from the same immutable facts that determine the supported traversal complexity.

---

# 11. Required Positive/Negative Boundary Evidence

Add deterministic tests proving at minimum:

```text
maximum traversal demand == M
→ configuration succeeds

maximum traversal demand == M + 1
→ configuration rejects
```

The evidence must cover:

- protected `zeroForOne`;
- protected `oneForZero`;
- positive tick regions;
- negative tick regions;
- a range crossing zero if valid and useful;
- bitmap-word-aligned service boundaries;
- boundaries immediately adjacent to word transitions;
- different valid tick spacings;
- canonical fixture unchanged.

Negative-tick handling is especially important because Uniswap tick compression and integer division behavior can be subtle.

Do not infer correctness only from positive ticks.

---

# 12. Atomic Configuration Rejection

For an over-bound configuration, prove:

```text
configureAndActivate(...)
→ reverts with the specific traversal-admissibility failure
```

and leaves unchanged:

- PES existence / activation state;
- PoolKey basis;
- Registry reference;
- ExerciseRouter;
- establishment authority;
- service ticks;
- protected direction;
- trusted perimeters;
- any other persisted PES field.

No partial service configuration may remain.

---

# 13. G3 Targeted Revalidation

Because the correction changes configuration admission, rerun targeted G3 evidence.

At minimum verify:

- authorized valid activation still succeeds;
- unauthorized activation still fails;
- activation remains one-shot;
- existing valid domain/direction cases still succeed;
- invalid existing domain cases still fail for their original reason where applicable;
- zero-liquidity bootstrap remains required;
- static-fee restrictions remain unchanged;
- exact Pool identity remains unchanged;
- canonical fixture activates;
- over-bound domain rejects before persistence;
- exactly-bound domain activates;
- no post-activation reinterpretation is introduced.

This is **targeted G3 regression/revalidation**, not a new G3 redesign.

Do not independently reopen or rewrite prior F3 semantics.

---

# 14. G5-B Revalidation

Re-run and strengthen prospective-state equivalence evidence.

For supported accepted configurations:

```text
predicted prospective state
==
actual real PoolManager post-state
```

and:

```text
predicted S'
==
authoritative S derived after real transition
```

Continue comparing, as relevant:

- prospective `sqrtPriceX96`;
- prospective active liquidity;
- prospective `S'`.

Required new evidence:

- at least one real-v4 swap path crossing an uninitialized bitmap-word boundary;
- an accepted configuration at or near the maximum supported traversal demand;
- a domain-extreme supported path demonstrating that an accepted PES does not encounter the traversal-bound revert under the maximum in-domain traversal case.

Do not use production derivation as its own reference oracle.

---

# 15. G5-F Revalidation

Retain all existing invalid-basis evidence.

Additionally prove:

```text
unsupported immutable prospective traversal demand
```

is rejected at activation rather than becoming an activated service whose otherwise-supported operation later fails only because the derivation implementation cannot evaluate it.

Preserve the distinction:

```text
valid state with S == 0
```

versus:

```text
authoritative derivation basis unsupported / invalid
```

Traversal-bound admission failure is a realization-admissibility failure.

It must not be mislabeled as:

- insufficient backing;
- zero Supporting Capacity;
- invalid commitment state;
- runtime economic failure.

---

# 16. Production Derivation Singularity

Re-run the G5-D structural review after the correction.

Confirm there remains exactly one production path for:

- validity;
- temporal exercise qualification;
- permanent non-binding classification;
- commitment obligation;
- Aggregate Capacity Obligation;
- Supporting Capacity;
- prospective swap state/capacity;
- prospective liquidity-removal state/capacity;
- service-domain geometry;
- prospective traversal-demand classification.

`configureAndActivate(...)` should consume the `ServiceDomain` traversal classification rather than hand-writing a second equivalent formula.

Independent test/reference duplication remains permitted only in verification code.

---

# 17. Semantic Minimality

This correction must not introduce:

- O1 establishment;
- O2 authority decisions;
- O2 causal context;
- O2 execution;
- O2 settlement;
- O2 Beneficiary delivery;
- Remaining Entitlement reduction;
- O3 runtime transition authorization;
- participant authentication;
- Registry mutation;
- administrative release;
- pause/deactivation;
- lifecycle persistence;
- derived Supporting Capacity storage;
- derived Aggregate Obligation storage;
- cached traversal-demand state unless demonstrated strictly necessary.

Production callbacks remain at the existing F5 frontier.

Do not implement F6A early.

---

# 18. Harness Boundary

`StandbyDerivationHarness` may continue to admit callbacks only for real-PoolManager differential evidence where production callbacks remain intentionally fail-closed.

The harness must not:

- calculate authoritative traversal demand differently from production;
- manufacture economic outcomes;
- replace PoolManager post-state;
- authorize production transitions;
- become evidence for F6/F7/F8 semantics.

Real PoolManager remains authoritative for actual swap state in G5-B differential tests.

---

# 19. Independent Verification Oracle

Any independent reference used to verify traversal demand must remain genuinely independent.

Do not verify:

```text
production ServiceDomain traversalDemand(...)
==
another wrapper that calls production ServiceDomain traversalDemand(...)
```

A verification oracle may independently implement the pinned v4 compression/word-index semantics required to calculate expected traversal demand.

Production code must not import or consume verification-only reference calculations.

---

# 20. Required Test Organization

Use the existing test organization where practical.

Likely affected/additional evidence belongs in:

```text
test/unit/ServiceDomain.t.sol
test/fuzz/ServiceDomainFuzz.t.sol
test/integration/ProspectiveStateEquivalence.t.sol
test/integration/DerivationGeneralization.t.sol
```

and the existing F3 configuration suites.

Add a new narrowly named test file only if doing so materially improves responsibility clarity.

Do not create unnecessary parallel test hierarchies.

---

# 21. Required Commands and Evidence

Run the permanent formatting/build/test commands defined by `CLAUDE.md` and `.claude/rules/*`.

The completion report must include at minimum:

```text
forge fmt --check
forge build
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

Also perform structural searches sufficient to establish:

- traversal-demand classification has one production owner;
- Hook configuration consumes that owner;
- runtime prospective derivation retains one bound;
- no production `ReferenceCalculations` dependency;
- no F6+ behavior introduced.

---

# 22. Documentation Mutation Boundary

The amended canonical realization and implementation plan are the authoritative instructions for this correction.

Do not rewrite frozen canonical economic artifacts.

Do not change documentation merely to match whatever implementation is easiest.

If implementation reveals another genuine contradiction in the amended realization, stop that design change and report it explicitly rather than silently redefining semantics in code.

You may update:

```text
docs/prompts/session-07-log.md
```

with the correction implementation and verification evidence required by permanent logging rules.

Do not update `docs/project-status.md` to claim F5 complete or G5 closed.

Independent review owns final gate closure.

---

# 23. Session Log Correction Record

Update the existing Session 07 implementation log rather than creating a competing F5 completion log.

The added correction record should make clear:

- what independent review found;
- why the original 16-step runtime refusal was insufficient alone;
- that the frozen RR-SC-8 single-step assumption was corrected upstream;
- what production files changed;
- exact traversal-demand derivation ownership;
- exact activation behavior added;
- G3 targeted regression results;
- G5-B revalidation results;
- G5-F revalidation results;
- full regression results;
- remaining limitations, if any.

Do not claim that the correction itself closes G5.

---

# 24. Gate Evidence Required for Independent Review

At completion, provide explicit evidence for:

## Targeted G3 Revalidation

```text
valid admitted service
+ exact-bound service
+ over-bound rejection
+ atomic failure
+ no change to prior trust/config semantics
```

## G5-B

```text
accepted configuration
→ predicted prospective state
== real PoolManager state

predicted S'
== authoritative post-transition S
```

including bitmap-word-boundary traversal and maximum-supported-domain evidence.

## G5-D

```text
single production traversal-demand classification
+ single runtime traversal bound
+ Hook consumption of the classification
```

## G5-E

```text
no downstream semantic contamination
```

## G5-F

```text
unsupported immutable traversal demand
→ rejected before activation

runtime bound
→ retained only as defensive fail-closed protection
```

---

# 25. Completion Boundary

This session ends when:

1. the admission-time traversal-derivability correction is implemented;
2. its unit/fuzz/integration evidence passes;
3. targeted G3 configuration regression/revalidation passes;
4. G5-B and G5-F correction evidence passes;
5. G5-D/E structural checks remain satisfied;
6. the full repository regression suite passes;
7. `session-07-log.md` records the correction and evidence.

The completion report may state:

> **F5 correction implementation complete; targeted G3 and G5 correction evidence ready for independent review.**

It may **not** state:

```text
G5 CLOSED
F6A AUTHORIZED
```

Those decisions remain outside this implementation session.

---

# 26. Final Instruction

Implement the smallest correct change that establishes:

> **An immutable service configuration may become authoritative only if every supported in-domain prospective swap path is derivable within the reference realization's bounded exact-v4 traversal model.**

Preserve all previously validated Standby economic semantics, production derivation singularity, and downstream slice boundaries.

Stop at the completion boundary above.
