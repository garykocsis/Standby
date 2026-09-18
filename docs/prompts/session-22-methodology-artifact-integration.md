# Session 22 — Methodology Artifact Integration

## 1. Objective

Integrate the already-derived Standby methodology artifacts into the repository without changing their substantive methodology content and without modifying any existing repository file.

This is a documentation/provenance integration session only. The methodology derivation and retrospective evaluation are already complete. Do not reopen R0–R7, reinterpret the methodology, or redesign Standby's protocol semantics.

## 2. Working Model

Use the established division of responsibility.

### ChatGPT

ChatGPT has already completed the normative derivation, retrospective evaluation, successor determination, authority boundaries, and exact artifact content for this integration.

### Claude

Claude is the bounded repository-integration agent. Claude may inspect the repository, confirm branch/path state, create required directories, copy the supplied artifacts to their exact destinations, verify links/formatting/diff, create the required session log, and report completion evidence.

Claude must not make methodology-design decisions.

### User

The user retains repository authority, reviews the final diff, accepts or rejects completion, and performs commit/PR/merge actions unless separately requested.

## 3. Clean Rule

**CLAUDE.md owns permanent operating behavior.**

**.claude/rules/\* owns permanent Solidity/testing conventions.**

**Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Do not duplicate permanent operating behavior or permanent Solidity/testing conventions here or in new artifacts.

## 4. Validated Starting State

Standby protocol implementation, canonical acceptance, submission readiness, and Base Sepolia F9T public realization are complete.

The formal methodology retrospective R0–R7 is complete.

It determined:

- Protocol Discovery Methodology v1.0 was validated by Standby with refinements;
- Protocol Discovery Methodology v1.1 is the frozen successor;
- v2.0 is not justified;
- the Protocol Implementation Method remains emergent/provisional.

This session does not revisit those determinations.

## 5. Branch

Expected working branch:

`docs/methodology-retrospective-v1.1`

Before modifying files:

1. confirm the current branch;
2. confirm the working-tree state;
3. if the branch is not the expected branch, stop and report rather than silently switching or creating another branch;
4. do not discard or overwrite unrelated user changes.

## 6. Supplied Source Artifacts

The user will provide these three source artifacts:

1. `methodology-README.md`
2. `protocol-discovery-methodology-v1.1-repo.md`
3. `standby-methodology-retrospective.md`

Treat their substantive contents as already approved. Do not rewrite, improve, shorten, expand, reinterpret, normalize terminology, or editorialize them.

Destination mapping:

- `methodology-README.md` → `docs/methodology/README.md`
- `protocol-discovery-methodology-v1.1-repo.md` → `docs/methodology/protocol-discovery-methodology-v1.1.md`
- `standby-methodology-retrospective.md` → `docs/methodology/retrospectives/standby-methodology-retrospective.md`

If any source artifact is unavailable, stop and report the missing input. Do not reconstruct it from memory or repository history.

## 7. Authorized Repository Changes

Create only:

- `docs/methodology/`
- `docs/methodology/retrospectives/`

Add:

- `docs/methodology/README.md`
- `docs/methodology/protocol-discovery-methodology-v1.1.md`
- `docs/methodology/retrospectives/standby-methodology-retrospective.md`
- `docs/prompts/session-22-log.md`

No other repository change is authorized.

## 8. Historical Evidence Boundary

Do not modify any pre-existing Standby artifact, including root README/CLAUDE files, canonical docs, implementation/realization docs, project status, existing prompts/logs/retrospective records, reports, production contracts, tests, scripts, or frontend files.

Historical artifacts must not be retroactively rewritten to conform to v1.1.

## 9. Prohibitions

Do not:

- modify Standby protocol semantics or implementation;
- modify `docs/project-status.md` or root `README.md`;
- create or reconstruct `protocol-discovery-methodology-v1.0.md`;
- claim v1.0 is reproduced in this repository;
- change v1.1 status from FROZEN;
- promote provisional findings to frozen status;
- create a Protocol Implementation Method document;
- promote Realization Dependency Validation beyond provisional;
- rewrite the formal retrospective;
- alter the normative-v1.1 / evidentiary-retrospective authority distinction;
- perform unrelated cleanup;
- begin another project slice.

If an apparent issue requires changing approved methodology content, stop and report it for user/ChatGPT review.

## 10. Verification Requirements

Verify:

1. all three methodology destination artifacts exist at exact paths;
2. README links resolve to v1.1 and retrospective;
3. retrospective link `../protocol-discovery-methodology-v1.1.md` resolves;
4. destination files preserve supplied source contents;
5. v1.1 identifies itself as normative and FROZEN;
6. retrospective identifies itself as non-normative/evidentiary;
7. README preserves authority distinction and provenance;
8. no v1.0 artifact was created;
9. no pre-existing repository file was modified;
10. no unrelated files were added;
11. inspect `git diff --stat`;
12. inspect `git diff`;
13. inspect `git status --short`.

Do not run the full Solidity test suite merely for documentation-only additions unless permanent repository instructions explicitly require it. If an existing lightweight Markdown/link check exists, it may be run. Do not introduce new tooling.

## 11. Session Evidence Log

Create `docs/prompts/session-22-log.md`.

Record:

- objective;
- starting branch and working-tree state;
- source artifacts received;
- directories/files created;
- exact destination mapping;
- verification performed;
- diff/status evidence;
- deviations/blockers;
- final completion report.

The log is implementation chronology/evidence, not a new methodology artifact. Do not reinterpret R0–R7 in it.

## 12. Completion Report

Report:

- branch;
- files added;
- confirmation no unauthorized existing files were modified;
- link/path verification;
- authority/provenance verification;
- `git diff --stat` summary;
- `git status --short` summary;
- deviations, if any;
- whether the completion boundary was reached.

Do not commit, push, create a PR, merge, or delete branches unless separately requested.

## 13. Completion Boundary

```text
expected branch confirmed
working tree safety confirmed
docs/methodology/ created
docs/methodology/retrospectives/ created
docs/methodology/README.md integrated from supplied source
docs/methodology/protocol-discovery-methodology-v1.1.md integrated from supplied source
docs/methodology/retrospectives/standby-methodology-retrospective.md integrated from supplied source
normative vs evidentiary authority boundary verified
relative links verified
historical Standby artifacts left unchanged
no v1.0 artifact reconstructed
docs/prompts/session-22-log.md created
documentation diff reviewed
git status reviewed
completion report produced
```

Stop at this completion boundary.

Do not begin any subsequent methodology revision, README update, protocol work, or repository cleanup.
