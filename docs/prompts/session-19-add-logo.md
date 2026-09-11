# Session 18 — Repository Branding Integration

You are working in the Standby repository.

This is a **bounded presentation/branding integration task** after F10 and after the README presentation work has already been completed, independently reviewed, committed, and merged.

The protocol implementation is complete.

Do not reopen protocol semantics, README narrative, accepted verification evidence, frozen diagrams, or any completed implementation gate.

---

# 1. Objective

Integrate the approved Standby visual identity into the live repository with the **minimum possible repository change**.

The approved visual direction is already decided.

Your task is implementation only.

Do not redesign the logo, change messaging, rewrite README content, or introduce additional branding concepts.

---

# 2. Permanent Repository Instruction Ownership

Preserve the established clean rule:

> **CLAUDE.md owns permanent operating behavior.**
>
> **.claude/rules/\* owns permanent Solidity/testing conventions.**
>
> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Do not modify `CLAUDE.md` or `.claude/rules/*` for this task.

---

# 3. Approved Public Identity

Project:

**Standby**

Tagline:

> **Execution capacity when you need it.**

Technical descriptor:

> **Protocol-enforced future execution capacity from shared AMM liquidity.**

Judge-facing synthesis:

> **Standby doesn't reserve liquidity. It protects capacity.**

Approved visual personality:

```text
ASSURED · FLUID · PRECISE
```

Approved palette direction:

```text
Deep Blue
Cyan
Violet
Dark navy background
Light primary text
Muted secondary text
```

Approved mark:

- ribbon-style `S`;
- blue / cyan / violet treatment;
- conventional/readable `STANDBY` wordmark;
- complete conventional `A`;
- no shield;
- no lock;
- no vault;
- no custody/reserve motif;
- no power-button motif.

The design work is already complete for this task.

Do not regenerate, redraw, reinterpret, or redesign the mark.

---

# 4. Files I Will Provide

I will provide the approved branding assets separately.

Use the provided approved files exactly.

Expected assets:

```text
standby-mark.png
standby-title-reference.png
```

The exact file names may be preserved unless there is a strong repository hygiene reason to normalize them.

Do not manufacture replacement assets.

---

# 5. Repository Changes Authorized

Create:

```text
assets/
└── brand/
    ├── standby-mark.png
    ├── standby-title-reference.png
    └── README.md
```

If `assets/` does not currently exist, create it.

Do not create additional branding directories unless necessary.

Do not add generated intermediate artifacts.

Do not add a branding-session note at repository root.

---

# 6. assets/brand/README.md

Create a short documentation file for the brand assets.

It should identify:

```text
Standby visual concept:
    Protected Flow

Visual personality:
    Assured · Fluid · Precise

Primary tagline:
    Execution capacity when you need it.

Technical descriptor:
    Protocol-enforced future execution capacity from shared AMM liquidity.
```

Document the intended palette direction:

```text
Deep Blue
Cyan
Violet
Dark navy ground
Light primary text
Muted secondary text
```

Explain the files:

```text
standby-mark.png
    approved ribbon-S project identity mark

standby-title-reference.png
    approved ETHOnline 2026 title-slide visual reference
```

Important:

These are approved **raster presentation assets**.

Do not claim they are canonical vector artwork or final SVG geometry.

Also record that the mark should not be reinterpreted as:

```text
shield
lock
vault
power / standby button
coin
custody / escrow
dedicated reserve
literal arrow
```

Keep this file concise.

---

# 7. README Integration

The current root README presentation work is already accepted.

Make **one branding addition only**.

Insert the Standby mark above the existing:

```md
# Standby
```

using centered HTML similar to:

```html
<p align="center">
  <img src="assets/brand/standby-mark.png" alt="Standby" width="150" />
</p>
```

You may make a very small adjustment to `width` only if required for reasonable GitHub rendering.

Do not add another title.

Do not add another tagline.

Do not add another descriptor.

The existing README already contains those.

---

# 8. README Preservation Boundary

Do not modify any existing README prose except for the minimal logo insertion.

In particular, preserve:

```text
# Standby

Execution capacity when you need it.

Protocol-enforced future execution capacity from shared AMM liquidity.

Standby doesn't reserve liquidity. It protects capacity.
```

Preserve all existing sections, including:

```text
The problem
Who Standby is for
institutional example
time-bounded commitment semantics
Why Uniswap v4?
The core idea
Protocol economics
Permissioned institutional markets
The realization
How Standby Executes
What the canonical demo proves
Running the demo
What Standby does not claim
Path to production
Verification
Documentation
```

Do not rewrite, reorder, shorten, expand, or stylistically edit those sections.

---

# 9. Frozen README Diagrams

The root README contains two previously accepted Mermaid diagrams:

```text
How Standby Executes
What the canonical demo proves
```

Do not modify them.

Do not reformat them.

Do not change labels, structure, arrows, participants, quantities, styling, or Mermaid directives.

They must remain byte-identical unless line-ending normalization occurs automatically and unavoidably.

If Git reports a change to either Mermaid block, investigate before proceeding.

---

# 10. Verification Evidence Preservation

Do not alter accepted evidence currently recorded in the README, including:

```text
590 passed
0 failed
0 skipped

FOUNDRY_PROFILE=ci forge test
    passed

frontend deterministic verification
    36 / 36

canonical demo
    reproduced

coverage:
    lines       99.42%
    statements  98.52%
    branches    92.31%
    functions   100%
```

Do not rerun tests merely because branding assets were added.

This is a non-executable change.

---

# 11. Presentation Deck Boundary

Do not add the PowerPoint presentation to the repository in this task.

The current approved deck remains an external rehearsal / submission artifact.

Do not create:

```text
docs/presentation/
slides/
presentation/
```

unless explicitly authorized later.

---

# 12. Production-Code Boundary

Do not modify:

```text
src/
test/
script/
frontend/
lib/
foundry.toml
package files
deployment files
demo fixture files
docs/project-status.md
canonical protocol specification artifacts
```

This task is branding-only.

---

# 13. Required Review

After making the changes:

1. inspect `git status --short`;
2. inspect the full diff;
3. confirm that only the expected branding files and README logo insertion changed;
4. confirm no existing README prose changed;
5. confirm both frozen Mermaid diagrams remain unchanged;
6. confirm no executable files changed;
7. confirm no tests were required or run.

If any unrelated repository change is already present, do not modify or delete it. Report it separately.

---

# 14. Required Output

Provide a concise completion report containing:

## Files added

Expected:

```text
assets/brand/standby-mark.png
assets/brand/standby-title-reference.png
assets/brand/README.md
```

## File modified

Expected:

```text
README.md
```

## README change

State exactly where the mark was inserted.

## Preservation check

Confirm:

```text
existing README prose unchanged
frozen Mermaid diagrams unchanged
verification evidence unchanged
protocol semantics unchanged
production code unchanged
frontend unchanged
project-status unchanged
```

## Verification

State that this is a non-executable branding change and that no test rerun was required.

## Diff summary

Include the final `git diff --stat`.

---

# 15. Session Evidence / Post-Project Retrospective

Preserve the Claude implementation record for this session as:

`docs/prompts/session-19-log.md`

This is the contemporaneous implementation log for the Session 19 repository branding integration.

Record, where materially relevant:

- the initial repository state relevant to this task;
- the branding assets provided for integration;
- files created and modified;
- the exact README branding change;
- confirmation that existing README prose was preserved;
- confirmation that the frozen Mermaid diagrams were preserved;
- confirmation that accepted verification evidence was preserved;
- confirmation that no protocol, production-code, frontend, or project-status changes were made;
- any issue encountered while integrating the supplied assets;
- any implementation judgment required by the prompt;
- final `git status --short`;
- final `git diff --stat`;
- completion-boundary evidence.

Keep the log factual and contemporaneous.

Do not use the log to introduce new protocol semantics, branding decisions, README narrative, or permanent operating instructions.

The log is **non-normative implementation evidence**.

Update the log before producing the final completion report.

## Final Completion Report

At the end of `docs/prompts/session-19-log.md`, include the final completion report for this session.

The report must contain:

- files added;
- files modified;
- exact README branding change;
- preservation checks;
- confirmation that the supplied approved assets were used without redesign;
- confirmation that no executable or protocol files changed;
- confirmation that no tests were required or run;
- final `git status --short`;
- final `git diff --stat`;
- completion-boundary determination.

The final completion report written to the log must be the authoritative session completion report.

After updating the log, provide the same completion result in the Claude response so it can be independently reviewed by ChatGPT.

---

# 16. Completion Boundary

The repository branding integration completion boundary is:

```text
approved brand assets added under assets/brand/

assets/brand/README.md added

Standby mark inserted above existing README title

no existing README prose changed

frozen Mermaid diagrams unchanged

verification evidence unchanged

no executable files changed

session-19-log.md updated with contemporaneous implementation evidence

final completion report recorded in session-19-log.md

git diff reviewed

completion report returned for independent review
```

Stop at this boundary.

Do not commit.

Do not open a PR.

Do not modify project status.

Do not begin presentation rehearsal work.

Do not begin F9T.
