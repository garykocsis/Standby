# Session 22 --- Corrective Prompt: Retrospective → v1.1 Provenance Link

## 1. Objective

Resolve the single remaining Session 22 verification blocker by adding
the already-approved reciprocal provenance notice to:

`docs/methodology/retrospectives/standby-methodology-retrospective.md`

Then verify that the retrospective's relative link to the normative v1.1
methodology resolves, update the existing Session 22 log with the
correction and final evidence, and stop.

This is a bounded correction to Session 22. It is not a new
methodology-design task and does not reopen R0--R7.

## 2. Validated Starting State

Session 22 already integrated:

-   `docs/methodology/README.md`
-   `docs/methodology/protocol-discovery-methodology-v1.1.md`
-   `docs/methodology/retrospectives/standby-methodology-retrospective.md`
-   `docs/prompts/session-22-log.md`

Independent review accepts the integration evidence except for one
blocker:

Session prompt §10.3 required the retrospective to contain and resolve
the relative link:

`../protocol-discovery-methodology-v1.1.md`

The supplied retrospective source lacked that already-approved
provenance notice, so Claude correctly did not invent or silently add
it.

The user/ChatGPT review now explicitly authorizes the exact correction
below.

## 3. Branch and Working-Tree Safety

Expected branch:

`docs/methodology-retrospective-v1.1`

Before editing:

1.  confirm the current branch is exactly the expected branch;
2.  inspect `git status --short`;
3.  preserve all existing Session 22 additions;
4.  do not discard, overwrite, stage, or alter unrelated user changes;
5.  if the branch is not the expected branch, stop and report.

## 4. Authorized Content Change

Modify only:

`docs/methodology/retrospectives/standby-methodology-retrospective.md`

Add the following already-approved provenance notice near the top of the
document, immediately after the title and existing introductory
metadata/status material and before the substantive retrospective body.

Use this text exactly:

> **Artifact status: Non-normative / evidentiary**
>
> This retrospective records the R0--R7 empirical evaluation of Protocol
> Discovery Methodology v1.0 through the Standby project. It preserves
> the evidence, analysis, limitations, candidate improvements,
> validation decisions, and successor reasoning that led to Protocol
> Discovery Methodology v1.1.
>
> This document explains **why** methodology changes were made; it does
> not itself serve as the normative definition of those changes. The
> authoritative successor methodology is
> [`../protocol-discovery-methodology-v1.1.md`](../protocol-discovery-methodology-v1.1.md).
>
> Historical Standby artifacts are evidence of the methodology and
> project decisions in force when they were created. This retrospective
> does not retroactively redefine their normative meaning or status.

Do not change the wording.

Do not make any other editorial, formatting, whitespace-cleanup,
terminology, heading, or substantive change to the retrospective.

## 5. Session Log Update

Modify the existing:

`docs/prompts/session-22-log.md`

Append a clearly identified corrective-review section recording:

-   the independent-review determination that Session 22 was CONDITIONAL
    / NOT YET CLOSED because §10.3 was unsatisfied;
-   the user/ChatGPT authorization of the exact provenance notice;
-   the retrospective file modified;
-   the exact purpose of the change;
-   verification that the relative link now resolves;
-   confirmation that no methodology determination was reopened or
    changed;
-   final diff/status evidence;
-   the resulting Session 22 completion assessment.

Do not rewrite or erase the original chronology or the original
deviation report. Preserve it as historical evidence and append the
correction.

## 6. File Boundary

This corrective task authorizes modifications to exactly two existing
Session 22 files:

1.  `docs/methodology/retrospectives/standby-methodology-retrospective.md`
2.  `docs/prompts/session-22-log.md`

Do not modify:

-   `docs/methodology/README.md`
-   `docs/methodology/protocol-discovery-methodology-v1.1.md`
-   any historical Standby canonical artifact;
-   any earlier prompt, log, or ChatGPT retrospective record;
-   `docs/project-status.md`;
-   root `README.md`;
-   `CLAUDE.md`;
-   `.claude/rules/*`;
-   contracts;
-   tests;
-   scripts;
-   frontend files;
-   reports.

Do not create any additional file or directory.

## 7. Authority Boundary

Preserve these already-decided roles:

-   `protocol-discovery-methodology-v1.1.md` --- **normative / current
    FROZEN methodology**
-   `standby-methodology-retrospective.md` --- **non-normative /
    evidentiary retrospective**
-   historical Standby artifacts --- historical authority according to
    the ownership and status in force when created

The provenance notice makes this existing authority relationship
explicit. It does not create a new methodology rule.

Do not reopen, reinterpret, promote, demote, or otherwise alter any
R0--R7 determination.

## 8. Verification Requirements

After the correction, verify:

1.  the provenance notice appears once in the retrospective;
2.  its wording matches the authorized text;
3.  the relative Markdown link is exactly:
    `../protocol-discovery-methodology-v1.1.md`
4.  resolving that link from `docs/methodology/retrospectives/` reaches:
    `docs/methodology/protocol-discovery-methodology-v1.1.md`
5.  the v1.1 destination still exists and remains unchanged;
6.  `docs/methodology/README.md` remains unchanged;
7.  no historical Standby artifact was modified;
8.  no new file was created;
9.  inspect `git diff --stat`;
10. inspect `git diff`;
11. inspect `git status --short`;
12. run `git diff --check` and report its result.

Because the retrospective source previously preserved trailing
whitespace intentionally, do not perform unrelated whitespace cleanup.
If `git diff --check` reports pre-existing/preserved whitespace in the
newly tracked retrospective, distinguish that from whitespace introduced
by this correction rather than silently normalizing the document.

No Solidity tests are required for this documentation-only correction
unless permanent repository instructions explicitly require them.

## 9. Completion Report

Report:

-   branch;
-   exact files modified;
-   exact provenance correction made;
-   link-resolution result;
-   confirmation that v1.1 and methodology README were unchanged;
-   confirmation that no historical Standby artifacts changed;
-   `git diff --stat`;
-   `git status --short`;
-   `git diff --check` result;
-   deviations, if any;
-   final Session 22 completion assessment.

Do not commit, push, create a PR, merge, or delete branches.

## 10. Completion Boundary

The corrective completion boundary is:

``` text
expected branch confirmed

working-tree safety confirmed

approved provenance notice added exactly once

retrospective → v1.1 relative link resolves

no other retrospective content changed

v1.1 artifact unchanged

methodology README unchanged

historical Standby artifacts unchanged

no new files created

session-22-log.md appended with corrective chronology and evidence

documentation diff reviewed

git diff --check reviewed

git status reviewed

Session 22 final completion assessment produced
```

Stop at this boundary.

Do not begin any subsequent methodology revision, root README update,
repository cleanup, commit/PR work, or protocol work.
