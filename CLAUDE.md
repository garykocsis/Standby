# CLAUDE.md

This file defines the operating rules for Claude Code when working in the Standby repository.

Read this file completely at the beginning of every implementation session.

Standby is a specification-driven protocol implementation. The protocol's economic semantics, architectural responsibilities, state model, invariants, and verification obligations were derived before implementation began.

Your responsibility is to implement that design faithfully.

Do not redesign the protocol while implementing it.

Solidity style, structure, and testing-architecture rules now live in path-scoped files under `.claude/rules/` and load automatically when you touch matching files:

- `.claude/rules/solidity-style.md` — loads for `src/**/*.sol`, `script/**/*.sol`, `test/**/*.sol`
- `.claude/rules/testing.md` — loads for `test/**/*.sol`

---

# Project Overview

**Standby** is a Uniswap v4 protocol for protocol-enforced future execution capacity from shared AMM liquidity.

**Tagline:**

> Execution capacity when you need it.

**Technical descriptor:**

> Protocol-enforced future execution capacity from shared AMM liquidity.

Standby's central economic invariant is:

> Supporting Capacity must remain greater than or equal to Aggregate Capacity Obligation.

Implementation details and mathematical definitions are owned by the authoritative engineering artifacts described below.

Do not infer protocol semantics from this summary.

The primary docs live under `docs/`: `context.md`, `economic-agreement.md`, `mechanism.md`, `spec.md`, `architecture.md`, `state-machine.md`, `invariants.md`, `testing-strategy.md`, `uniswap-v4-realization.md`, `demo-spec.md`, `implementation-plan.md`, `project-status.md`, `setup.md`. Some directories referenced below may not exist until their implementation phase begins — do not create empty directories or placeholder files merely to match this document.

---

# Document Authority Model

The documents in `docs/` do not all have the same semantic role or authority.

Directory placement does not determine normative authority.

Use the following hierarchy when resolving implementation questions.

## 1. Protocol / Economic Derivation

These documents define the upstream economic and mechanism basis:

- `docs/context.md`
- `docs/economic-agreement.md`
- `docs/mechanism.md`

They answer questions such as:

- What coordination problem is Standby solving?
- What economic rights and obligations exist?
- Why does a capability exist?
- What mechanism-level behavior is required?

Implementation must not weaken or reinterpret these requirements.

---

## 2. Canonical Engineering Specification

These documents define the authoritative engineering requirements:

- `docs/spec.md`
- `docs/architecture.md`
- `docs/state-machine.md`
- `docs/invariants.md`
- `docs/testing-strategy.md`

They answer questions such as:

- What behavior is required or forbidden?
- Which component owns a responsibility?
- What state may persist?
- What state must be derived?
- What transitions are authoritative?
- What invariants must always hold?
- What evidence is required to verify correctness?

When implementing Solidity, these documents are the primary semantic authority.

---

## 3. Reference Realization / Implementation Handoff

These documents define how the canonical design is realized for the current Uniswap v4 reference implementation:

- `docs/uniswap-v4-realization.md`
- `docs/demo-spec.md`
- `docs/implementation-plan.md`

They answer questions such as:

- How are canonical responsibilities mapped onto Uniswap v4?
- What implementation sequence should be followed?
- What does each implementation gate require?
- What deterministic demo behavior must eventually be proven?

These documents may specialize upstream requirements for the reference implementation but must not redefine or weaken them.

---

## 4. Live Implementation State

`docs/project-status.md` records current implementation progress.

It answers:

- What slice is active?
- What has already been implemented?
- What has been verified?
- What gate is open?
- What is the current blocker?
- What work is not yet authorized?

`project-status.md` is a live status artifact.

It is **not** a source of new protocol semantics.

---

## 5. Developer Environment

`docs/setup.md` records repository setup, toolchain, dependency, and reproducibility instructions.

It does not define protocol behavior.

---

# Conflict Resolution

If two sources appear inconsistent, do not silently choose whichever interpretation makes implementation easier.

Use this order:

1. identify the exact conflicting requirements;
2. determine whether the conflict is semantic, realization-specific, or merely stale implementation/status information;
3. prefer upstream normative authority over downstream implementation convenience;
4. stop implementation if resolving the conflict would require changing frozen protocol semantics;
5. report the contradiction clearly before proceeding.

Existing Solidity code is never automatically authoritative over the canonical documents.

Passing tests are not automatically authoritative over the canonical documents.

`project-status.md` is not authoritative over frozen specification semantics.

Do not modify frozen documents merely to make current code pass.

---

# Session Startup Protocol

At the beginning of every implementation session:

1. Read `CLAUDE.md` completely.
2. Read `docs/project-status.md`.
3. Read the relevant current slice and gate in `docs/implementation-plan.md`.
4. Read the authoritative upstream sections necessary to understand that slice.
5. Inspect the actual source and tests involved.
6. Inspect pinned dependency source whenever implementation depends on an external API or behavior.
7. Run:

```bash
git status
```

8. Before modifying code, establish:

- current implementation slice;
- current verification gate;
- governing requirements;
- files likely to change;
- required tests/evidence;
- prohibited shortcuts;
- unresolved blockers.

Do not begin implementation until the current slice is understood.

Do not assume an external API from memory when the pinned dependency source can be inspected.

---

# Implementation Discipline

Standby uses a verification-gated implementation workflow.

The governing cadence is:

> Validated State → Next Blocker → Implementation → Verification Gate → Next Slice

Implement the smallest coherent responsibility that resolves the current blocker.

Do not implement downstream functionality merely because it is convenient while editing nearby code.

Do not prematurely generalize beyond the current requirements.

Do not introduce speculative extensibility.

Do not introduce abstractions without a concrete current responsibility.

Do not create protocol state merely because it simplifies implementation.

Do not duplicate authoritative logic across components.

Prefer the simplest implementation that faithfully realizes the frozen requirements and can be independently verified.

---

# Verification-Gated Dependency Rule

Downstream implementation may depend on an upstream responsibility only after the required verification evidence for that responsibility exists.

Conceptually:

> Dependency Readiness = Implementation + Required Verification Evidence

Compilation is not verification.

A passing unit test is not necessarily sufficient verification.

A passing integration test is not necessarily sufficient for a stateful invariant requirement.

Use `docs/testing-strategy.md` and `docs/implementation-plan.md` to determine the required evidence.

Do not advance a gate based solely on your own assertion that implementation appears correct.

---

# Gate Authority

Claude Code may:

- implement the current authorized slice;
- run tests;
- inspect evidence;
- identify whether requirements appear satisfied;
- report a proposed gate assessment.

Claude Code must not independently redefine the implementation roadmap or silently authorize a downstream slice.

At the end of a task, report the evidence and proposed gate status.

Do not begin the next slice unless explicitly instructed.

---

# Frozen Semantic Boundary

Implementation is downstream of the frozen Standby design.

Do not invent missing economic semantics.

Do not infer economic semantics from implementation convenience.

Do not change a frozen canonical requirement because it is difficult to implement.

If implementation reveals what appears to be a genuine contradiction or unrealizable frozen requirement:

1. stop;
2. isolate the contradiction;
3. identify the affected canonical requirements;
4. explain the implementation consequence;
5. do not resolve it by silently changing behavior.

A genuine implementation-discovered contradiction must be reviewed explicitly.

---

# Authoritative State Discipline

Persist only state permitted by the canonical state model.

Do not persist a derived value merely to avoid recomputation unless the canonical design explicitly authorizes that persistence.

Do not introduce redundant lifecycle flags when lifecycle status is canonically derived.

Do not create synchronization invariants unnecessarily.

When an economically meaningful classification or aggregate is deterministically reproducible from authoritative facts, prefer the authoritative facts unless the canonical design says otherwise.

---

# Authoritative Derivation Discipline

Whenever Standby depends on an economically meaningful derived quantity, production behavior must consume the authoritative production derivation.

Do not maintain multiple production implementations of the same economic derivation.

Examples include later derivations of:

- Supporting Capacity;
- Aggregate Capacity Obligation;
- commitment obligation;
- validity;
- exercisability;
- prospective post-transition capacity.

Independent duplicate calculations are appropriate only as verification oracles where required.

A verification oracle must not simply call the production derivation it is supposed to verify.

Invariant preservation alone does not prove derivation correctness.

---

# Economic Atomicity

When a transition is economically atomic, do not persist intermediate transition facts that are meaningful only during one transaction.

Use transaction-scoped evidence where appropriate.

Persist only economically final state after all required effects have occurred.

Do not turn transaction-scoped execution evidence into unnecessary persistent lifecycle state.

---

# Authority and Trust Boundaries

Respect the ownership and trust boundaries defined by the architecture.

Do not move authoritative Standby economic truth into routers, periphery contracts, test helpers, frontend state, or caller-supplied data.

Do not treat arbitrary `hookData` as authenticated authority.

Do not infer an economic actor solely from a callback caller when the architecture requires authenticated originating-user attribution.

The Hook owns Standby economic truth where defined by the canonical architecture.

Periphery may coordinate execution without becoming authoritative for Standby economics.

---

# Uniswap v4 Dependency Discipline

Standby is implemented against pinned Uniswap v4 dependencies.

Do not copy API assumptions from another repository, tutorial, branch, release, or memory when the pinned source is available.

Before relying on a v4 API:

1. inspect the pinned source;
2. verify the exact signature;
3. verify relevant callback/accounting semantics;
4. implement against that version.

Do not casually introduce another copy of `v4-core`, `v4-periphery`, Permit2, or related dependencies.

Do not change dependency revisions without explicit authorization.

A dependency upgrade requires rerunning all dependent verification gates.

---

# Real Execution Path Requirement

Where a verification gate requires real Uniswap v4 behavior, use the real pinned execution stack.

Do not replace required PoolManager behavior with Standby-owned mocks.

Test helpers may coordinate real PoolManager operations when appropriate, but the authoritative execution/accounting path must remain real.

The canonical integration and acceptance environment is deterministic local Foundry/Anvil using the real Uniswap v4 execution stack.

Economic currencies may be mocks where specified.

---

# Git Discipline

Inspect repository state before implementation:

```bash
git status
```

Do not discard or overwrite existing user changes.

Do not use destructive Git operations unless explicitly authorized.

Do not create commits unless explicitly instructed.

Do not amend, squash, reset, force-push, or rebase without explicit authorization.

Keep changes scoped to the current implementation responsibility.

At task completion, report modified and newly created files.

---

# Documentation Discipline

Do not update frozen canonical documents merely because implementation changed.

If implementation exposes a genuine contradiction, report it instead.

Update live implementation documentation only when appropriate and explicitly within task scope.

`docs/project-status.md` should reflect validated implementation state, not aspirational state.

## Project Status Synchronization

`docs/project-status.md` must be synchronized after an implementation gate is explicitly closed or a new slice is explicitly authorized.

Claude must not infer, self-declare, or record a gate as closed merely because implementation is complete or verification commands pass.

During an implementation session, report the proposed gate assessment and stop at the task completion boundary as required by Gate Authority.

After external gate review explicitly closes the gate, a subsequent instruction may authorize Claude to synchronize `docs/project-status.md` with that validated state.

When synchronizing the status document, update all affected current-state sections consistently rather than changing only the header or implementation ladder.

A project-status synchronization records already-authorized state. It does not itself close a gate or authorize a downstream implementation slice.

When a new implementation session explicitly authorizes a downstream slice, Claude may synchronize `docs/project-status.md` to record that slice as current or in progress. Receiving implementation authorization does not close that slice's gate or authorize any further downstream slice.

`docs/setup.md` should be updated when reproducible developer setup changes, including material changes to:

- dependencies;
- pinned revisions;
- remappings;
- compiler or EVM configuration;
- required environment variables;
- deployment prerequisites;
- fresh-clone setup procedure.

Do not use `project-status.md` as a substitute for tests or gate evidence.

---

# Current Implementation Roadmap

The authoritative implementation roadmap, slice definitions, dependencies, and gates live in `docs/implementation-plan.md`. Read that file — and `docs/project-status.md` for where things currently stand — rather than relying on any slice list here, so this file cannot drift out of sync with the live plan.

---

# High-Risk Implementation Areas

The highest-risk implementation responsibilities are currently expected to include:

- F5 — authoritative economic derivation;
- F8 — O2 exercise execution and causal fulfillment;
- F6 — prospective backing enforcement.

Do not compensate for risk by adding speculative state or weakening verification.

Do not overinvest in frontend polish, public testnet deployment, broad generalization, or optional abstractions before the critical protocol responsibilities and gates are closed.

---

# Frontend Boundary

The frontend is demo instrumentation, not an independent source of economic truth.

When F10 begins, frontend state must come from:

- authoritative on-chain state;
- PoolManager state;
- token state;
- transaction results.

Do not create frontend-maintained economic truth.

Do not introduce the frontend before the implementation plan authorizes F10 unless explicitly instructed.

---

# Security Mindset

For every economically meaningful transition, consider:

- who is authorized;
- what facts are authoritative;
- what facts are caller supplied;
- what state changes;
- what external interactions occur;
- whether failure is atomic;
- whether the transition can be replayed;
- whether evidence can be reused;
- whether derived values can become stale;
- whether authority crosses a component boundary;
- whether ordinary Uniswap behavior can violate Standby backing;
- whether a malicious actor can create false fulfillment.

Do not assume honest callers.

Do not assume trusted periphery unless the architecture explicitly establishes that trust.

Do not assume frontend behavior provides security.

---

# Scope Control

When given a task:

1. identify the exact current responsibility;
2. inspect governing documents and code;
3. make the minimum coherent implementation change;
4. add the verification evidence required for that responsibility;
5. run relevant checks;
6. stop.

Do not continue into the next roadmap slice automatically.

If additional work is discovered, report it as a blocker or recommended next step rather than silently expanding scope.

---

# Required Task Completion Report

At the end of every implementation task, provide the following report.
At task completion, append the complete Required Task Completion Report, including the Prompt Audit, to the current docs/prompts/session-NN-log.md before returning the same report to the user.

## Files Inspected

List the important repository and dependency files inspected.

## Files Changed

List every file created, modified, or deleted and briefly explain why.

## Requirements Implemented

Identify the requirements addressed by the task.

## Tests Added or Changed

List tests and explain what requirement each proves.

## Commands Run

List relevant formatting, build, test, and verification commands.

## Results

Report the actual results.

Do not say tests passed if they were not run.

## Gate Evidence

Explain what evidence the implementation provides toward the current gate.

Distinguish:

- implemented;
- verified;
- still unverified.

## Known Limitations / Blockers

Report unresolved issues explicitly.

## Scope Check

Confirm whether work remained within the authorized slice.

Explicitly identify any out-of-scope changes if they occurred.

## Proposed Gate Assessment

Use one of:

- PASS;
- PARTIAL;
- FAIL;
- NOT EVALUATED.

Explain the assessment.

This is a proposed assessment only unless explicit authority to close the gate has been given.

## Recommended Next Step

Identify the smallest coherent next responsibility.

Do not implement it unless instructed.

If the current session was initiated from a `docs/prompts/` session prompt, also confirm that all material follow-up prompts were captured in the session log (see Session Prompt Discipline below).

---

# Stop Conditions

Stop implementation and report before proceeding if:

- frozen documents appear contradictory;
- implementation would require weakening a canonical invariant;
- required authority cannot be established;
- required authoritative state cannot be reconstructed;
- an external dependency behaves differently from the realization assumptions;
- satisfying the task would require unauthorized persistent state;
- a required real execution path can only be made to pass through a mock or harness shortcut;
- a gate requires evidence that the current test architecture cannot legitimately provide;
- implementation scope would cross into a downstream slice without authorization.

Stopping with a precise blocker is preferable to silently inventing protocol behavior.

---

# Current Status

Do not rely on this file for current implementation progress.

At session startup, read:

> `docs/project-status.md`

That file records the current active slice, open gate, validated evidence, and next blocker.

This separation is intentional:

- `CLAUDE.md` defines **how to work**;
- `project-status.md` defines **where the work currently stands**;
- canonical engineering artifacts define **what the system must mean and do**;
- `implementation-plan.md` defines **how implementation progresses**.

---

# Session Prompt Discipline

Implementation sessions may be initiated from a version-controlled prompt under `docs/prompts/`.

When a session prompt is supplied:

1. read `CLAUDE.md` first;
2. read `docs/project-status.md`;
3. read the supplied session prompt;
4. read the governing implementation-plan slice and any upstream authoritative artifacts referenced by that prompt;
5. inspect the actual repository state before modifying code.

The session prompt defines the authorized task for that session. It may narrow scope, identify required files, or add verification work — but it must not override frozen canonical semantics, the document authority hierarchy, the current gate, architectural authority boundaries, or verification requirements. If a session prompt conflicts with an authoritative upstream artifact, stop and report the conflict rather than following it.

Prompts under `docs/prompts/` are implementation-process and audit artifacts, not normative protocol specifications. Preserve the initiating prompt in version control so the session can be reconstructed and reviewed.

## Material Prompt Logging

For each version-controlled session, maintain `docs/prompts/session-NN-log.md` alongside the preserved prompt `docs/prompts/session-NN-<description>.md`. Create the log file before making implementation changes if it doesn't already exist.

Log a follow-up instruction only when it's material — it changes/narrows scope, makes an architectural or implementation decision, selects between meaningful alternatives, changes a verification or test requirement, resolves a blocker, authorizes previously-deferred work, or rejects a proposed approach. Skip routine mechanics (rerun a test, show a diff, continue, fix formatting).

For each material follow-up, append: a sequential prompt number, a concise title, the instruction itself (preserved verbatim in substance, not reinterpreted), and the resulting implementation consequence once known.

The session log is an audit artifact, not a normative spec.

## Prompt Audit

Confirm that all material follow-up instructions were recorded in the current `docs/prompts/session-NN-log.md`, and state the number of material prompts recorded.

---

# Final Operating Rule

Standby was derived specification-first.

Implementation exists to realize and verify that specification.

When convenience, existing code, or implementation intuition conflicts with an authoritative requirement:

> **preserve the requirement, expose the conflict, and stop rather than silently changing the protocol.**
