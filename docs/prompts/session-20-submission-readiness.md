# Session 20 — Submission Readiness: Demo Link + AI Attribution

## 1. Objective

Make the minimum documentation-only changes required to bring the Standby repository to final ETHOnline 2026 submission readiness.

This session has exactly two repository responsibilities:

1. add the validated official Standby demo recording link to the README;
2. add explicit AI-assisted development attribution to the README.

Do not reopen protocol semantics, implementation, testing, frontend behavior, branding, presentation framing, or previously accepted README content.

## 2. Clean Rule

Follow the established repository ownership rule:

**CLAUDE.md owns permanent operating behavior.**

**.claude/rules/* owns permanent Solidity/testing conventions.**

**Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

This prompt is intentionally limited to those slice-specific concerns. It does not establish new permanent operating behavior or permanent Solidity/testing conventions.

No changes to `CLAUDE.md` or `.claude/rules/*` are authorized.

## 3. Validated State

The Standby implementation is complete. The canonical Solidity implementation, frontend, verification evidence, README presentation framing, branding, presentation deck, and demo sequence have already been independently reviewed and accepted.

The final Standby demo recording has been completed and validated:

```text
Official demo duration: 3:55
Loom: https://www.loom.com/share/4a40fa663c9d425da94f9ee9726d0fb9
```

The downloaded MP4 is the submission/archive copy and must not be added to the Git repository. The README should link to the public Loom recording.

The demo reproduces the accepted canonical sequence:

```text
PROMISE → SHARE → PROTECT → FULFILL
```

The existing README must otherwise remain substantively unchanged.

## 4. Required Change A — Official Demo Link

Add a prominent link to the validated official demo near the top of `README.md`, after the project identity/introductory branding and before the substantive protocol explanation.

Use wording equivalent to:

```markdown
**Demo:** [Standby — Execution Capacity When You Need It (3:55)](https://www.loom.com/share/4a40fa663c9d425da94f9ee9726d0fb9)
```

Minor formatting adjustments are acceptable only if required to fit the existing README presentation cleanly.

Requirements:

- use the exact Loom URL above;
- display the validated duration as `3:55`;
- add only one official demo link;
- do not add or commit the downloaded MP4;
- do not alter existing branding assets.

## 5. Required Change B — AI-Assisted Development & Attribution

Add a section near the end of `README.md`, before License or equivalent repository-meta content:

```markdown
## AI-Assisted Development & Attribution

Standby was developed with AI-assisted engineering tools.

**ChatGPT (OpenAI)** was used as a protocol-derivation, specification, planning, and independent-review partner. It assisted with reasoning about economic semantics, responsibility boundaries, implementation slices, verification gates, presentation, and review of implementation evidence.

**Claude Code (Anthropic)** was used as the bounded repository implementation assistant for Solidity, tests, frontend, documentation, and related repository changes. Implementation work was directed through scoped session prompts derived from the project's canonical specifications and implementation plan.

The developer remained responsible for the protocol design, economic model, architectural and engineering decisions, implementation boundaries, testing strategy, review of generated changes and verification evidence, acceptance of completed work, and final submission.

For transparency, the repository preserves the project's canonical specifications, implementation plan, session prompts, Claude implementation logs, and contemporaneous ChatGPT reasoning and independent-review records.
```

Preserve this meaning. Only minor copy-editing changes are permitted if required for consistency with the existing README.

Do not make the attribution broader or narrower than the actual development process described above.

## 6. Scope and File Boundaries

Authorized files for this slice:

```text
README.md
docs/prompts/session-20-submission-readiness.md
docs/prompts/session-20-log.md
```

If `docs/prompts/session-20-submission-readiness.md` already contains this supplied prompt, do not unnecessarily rewrite it.

Create or update `docs/prompts/session-20-log.md` according to the repository's established session-log pattern.

No other files are authorized.

## 7. Requirements

The completed slice must satisfy all of the following:

1. the official 3:55 Loom demo is readily discoverable from the README;
2. the README explicitly discloses use of ChatGPT/OpenAI;
3. the README explicitly discloses use of Claude Code/Anthropic;
4. the respective roles of ChatGPT and Claude Code are accurately distinguished;
5. developer responsibility for protocol design, engineering decisions, review, verification acceptance, and final submission is explicit;
6. the repository's preserved specification/prompt/log/reasoning evidence trail is identified;
7. the existing README remains substantively unchanged apart from these additions;
8. no implementation, test, frontend, branding, configuration, or protocol changes are made;
9. the downloaded demo MP4 is not added to the repository.

## 8. Prohibitions

Do not:

- modify Solidity, tests, frontend code, deployment scripts, Foundry configuration, or package configuration;
- modify branding assets or regenerate images;
- add the downloaded demo MP4 or any other video binary;
- modify Mermaid diagrams;
- change verification evidence, test counts, or coverage figures;
- change protocol terminology or the canonical invariant;
- rewrite substantive README sections or reorganize the README;
- alter the institutional framing or canonical A1–A4 demo sequence;
- add production-readiness, institutional-customer, or capacity-pricing claims;
- imply fixed-price execution or absence of price impact;
- imply custody, escrow, segregated liquidity, or reserved assets;
- imply integration with Uniswap Permissioned Pools;
- change `CLAUDE.md` or `.claude/rules/*`;
- perform unrelated cleanup.

## 9. Existing README Content That Must Be Preserved

The following README elements are already accepted and must remain intact:

- Standby branding and approved visual identity;
- project title and tagline;
- institutional coordination-problem framing;
- tokenized Treasury / USDC example;
- bounded quantity/time framing;
- explanation of why Uniswap v4 hooks matter;
- `Supporting Capacity S ≥ Capacity Obligation O`;
- economics and exclusions;
- permissioning explanation;
- architecture and both existing Mermaid diagrams;
- canonical execution sequence and canonical demo evidence;
- setup/demo instructions and verification evidence;
- protocol/frontend status;
- non-claims;
- path-to-production framing.

This is an additive documentation task only.

## 10. Gate Evidence / Verification

After making the authorized changes, collect the minimum evidence required to establish that this documentation-only slice is correct and bounded.

Run:

```bash
git diff --check
git status --short
git diff -- README.md
```

Verify from the resulting evidence that:

1. the official Loom URL is exact;
2. the displayed demo duration is `3:55`;
3. ChatGPT/OpenAI is explicitly named and its role is accurately described;
4. Claude Code/Anthropic is explicitly named and its role is accurately described;
5. developer responsibility is explicitly preserved;
6. the repository evidence trail is explicitly described;
7. no substantive existing README content was changed;
8. no unauthorized files were modified;
9. no video binary was added to the repository.

No Solidity, Foundry, frontend, or other implementation test execution is required for this documentation-only slice unless an existing repository requirement independently mandates it.

Do not create new permanent verification conventions as part of this session.

## 11. Session Log

Create or update:

```text
docs/prompts/session-20-log.md
```

Use the established repository session-log structure.

Record only evidence relevant to this slice, including:

- session objective;
- files inspected;
- files changed;
- exact README additions;
- verification commands executed and results;
- confirmation that no implementation, frontend, test, configuration, or branding changes were made;
- confirmation that no demo MP4/video binary was added;
- any deviations from this prompt, if any;
- final completion report.

Do not use the session log to introduce new normative protocol behavior, permanent operating behavior, or permanent Solidity/testing conventions.

## 12. Completion Boundary

The Session 20 submission-readiness completion boundary is:

```text
official 3:55 Loom demo link added to README

downloaded demo MP4 not added to repository

AI-Assisted Development & Attribution section added to README

ChatGPT/OpenAI contribution accurately described

Claude Code/Anthropic contribution accurately described

developer responsibility explicitly preserved

repository evidence trail explicitly described

existing README substantive content preserved

existing branding preserved

existing Mermaid diagrams preserved

verification evidence preserved

no unauthorized files changed

git diff --check clean

session-20-log.md updated

completion report produced
```

Stop at this completion boundary.

Do not begin any additional repository work.
