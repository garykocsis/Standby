# Standby — Claude Code Session 01

## F0 Bootstrap / Repository Orientation

**Session:** 01
**Phase:** Solidity / Reference Implementation
**Target Slice:** F0 — v4 Infrastructure
**Target Gate:** G0 — Vanilla v4 Infrastructure
**Session Type:** Read-Only Orientation and Audit

---

# Objective

Independently establish the current Standby repository implementation state, assess the existing evidence for F0/G0, investigate the pinned Uniswap v4 Hook deployment mechanics required for the remaining F0 work, and identify the next legitimate implementation blocker.

This session is intentionally read-only with respect to implementation.

Do not implement the identified blocker.

The purpose of this first session is also to verify that the repository itself provides sufficient context for safe specification-driven implementation without requiring protocol semantics to be restated conversationally.

---

# Required Reading

Follow the Session Startup Protocol defined in root `CLAUDE.md`.

For this session, ensure that you inspect:

- `docs/project-status.md`
- the F0 / G0 sections of `docs/implementation-plan.md`
- relevant sections of `docs/uniswap-v4-realization.md`
- relevant sections of `docs/testing-strategy.md`
- relevant sections of `docs/architecture.md`
- the existing F0 implementation and tests
- the relevant pinned Uniswap v4 dependency source
- the current Git working state

Use the document authority model defined in `CLAUDE.md`.

Do not assume Uniswap v4 APIs or deployment patterns from memory, RangeGuard, tutorials, or another dependency revision. Inspect the actual pinned source.

---

# Session Audit

This is a version-controlled implementation session.

Follow the Session Prompt Discipline and Material Prompt Logging requirements defined in `CLAUDE.md`.

The only repository file this session is authorized to create or modify is the corresponding session log.

---

# Required Investigation

Independently determine:

1. the actual current F0/G0 implementation state;
2. which G0 requirements currently have valid implementation and verification evidence;
3. whether the existing F0 infrastructure exercises the real pinned Uniswap v4 execution stack;
4. whether the shared v4 infrastructure remains direction-neutral rather than embedding later Standby economic assumptions;
5. exactly what remains before G0 can close;
6. how the pinned Uniswap v4 version encodes Hook permissions into Hook addresses;
7. how those permissions are validated by the pinned implementation;
8. what pinned utilities or deployment patterns are available for deterministic permission-valid Hook deployment;
9. what minimal deployment structure is appropriate for the future StandbyHook F0 implementation;
10. what the smallest coherent next implementation task should be.

Derive these findings from repository and pinned-dependency evidence rather than from assumptions in this prompt.

---

# G0 Assessment

Assess every G0 requirement defined by the authoritative implementation plan.

For each requirement, classify its current state as:

- **PASS**
- **PARTIAL**
- **NOT IMPLEMENTED**
- **FAIL**

Provide the repository evidence supporting each assessment.

At minimum, the assessment should make clear the status of:

- real PoolManager infrastructure;
- vanilla pool initialization;
- vanilla liquidity addition;
- vanilla swap execution;
- direction-neutral shared infrastructure;
- canonical StandbyHook deployment;
- Hook permission validation.

Do not mark G0 PASS unless all required implementation and verification evidence exists.

---

# Hook Deployment Investigation

For the remaining F0 deployment work, inspect the pinned dependency source and determine:

- the Hook permission representation used by the pinned version;
- the required Standby Hook permission surface according to the governing Standby artifacts;
- how the permission mask maps to a deployed Hook address;
- the pinned utility or mechanism suitable for finding a permission-valid deployment address;
- how deployment-time permission correctness should be verified;
- the minimal constructor/deployment requirements necessary at F0;
- how one canonical deployment approach can support tests and later deployment scripts without introducing fixture-specific economic assumptions.

Do not implement this deployment path during Session 01.

If the pinned dependency behavior conflicts with a Standby realization assumption, stop and report the exact conflict according to `CLAUDE.md`.

---

# Dependency and Toolchain Check

Verify the effective repository dependency and toolchain state relevant to F0.

Check the actual:

- Solidity compiler version;
- EVM version;
- optimizer configuration;
- checked-out Uniswap dependency revisions;
- relevant nested dependency revisions;
- effective Foundry configuration.

If repository metadata, lockfiles, gitlinks, or checked-out dependency state disagree, report the discrepancy.

Do not change dependency revisions or normalize dependency metadata during this session.

---

# Verification

You may run read-only inspection, Git, formatting-check, build, and test commands.

At minimum, verify that the repository builds and run the focused existing F0 integration tests.

Use the actual repository paths and test names you discover.

If verification fails, investigate sufficiently to classify the failure, but do not modify implementation to make it pass.

Report actual commands and actual results.

---

# Documentation Check

Determine whether:

- `docs/project-status.md` accurately reflects repository reality;
- `docs/implementation-plan.md` provides sufficient definition of the current F0/G0 boundary;
- `docs/setup.md` reflects the currently validated toolchain and dependency baseline;
- any documentation/repository discrepancy should be resolved before implementation continues.

Do not modify these documents during this session.

---

# Authorized Scope

This session is an orientation and implementation audit.

Implementation changes are not authorized.

The session log required by `CLAUDE.md` is the only authorized repository modification.

---

# Non-Goals

Do not:

- implement the remaining F0 work;
- create or modify Standby production Solidity;
- modify existing tests;
- introduce Standby economic behavior or economic state;
- change dependencies;
- modify frozen canonical artifacts;
- begin F1 or any downstream implementation slice;
- add frontend functionality;
- perform public deployment work.

Report discovered work rather than implementing it.

---

# Required Next-Task Recommendation

Identify exactly one smallest coherent next implementation responsibility based on the audit.

For that recommendation, report:

- objective;
- governing requirements;
- likely files to create or modify;
- relevant pinned dependency APIs or utilities;
- required verification evidence;
- important prohibited shortcuts.

Do not implement the recommendation.

---

# Completion

Produce the Required Task Completion Report defined in `CLAUDE.md`.

Also complete the Prompt Audit required by `CLAUDE.md`.

Because this is a read-only audit session, it is valid for the report to state that no implementation requirements or tests were changed.

The session is complete when:

1. repository orientation is complete;
2. F0/G0 has been independently assessed;
3. relevant pinned Hook deployment mechanics have been investigated;
4. documentation/toolchain discrepancies have been identified;
5. exactly one next implementation responsibility has been recommended;
6. the session audit log is current;
7. the required completion report has been produced.

Stop after returning the report.

Do not begin the recommended implementation task.
