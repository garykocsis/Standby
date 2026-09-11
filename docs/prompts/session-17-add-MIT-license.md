Add the standard MIT License to the Standby repository.

## Scope

Create exactly one new root-level file:

`LICENSE`

Use the standard MIT License text with:

`Copyright (c) 2026 Gary Kocsis`

The Standby-owned Solidity source files already use:

`// SPDX-License-Identifier: MIT`

The root license therefore makes the repository-level licensing explicit and consistent with the existing source licensing.

## Boundaries

This is repository licensing / submission hygiene only.

Do not:

- modify any Solidity source file or SPDX identifier;
- modify any test;
- modify any script;
- modify the frontend;
- modify either README;
- modify canonical specification or design documentation;
- modify `docs/project-status.md`;
- begin F9T;
- change protocol semantics;
- rerun Solidity, frontend, gas, coverage, invariant, or demo verification.

Do not add additional licensing commentary or notices elsewhere in the repository.

## Session Log

Update `docs/prompts/session-17-log.md` for audit chronology only.

Record that:

- a root-level standard MIT `LICENSE` was added as final repository/submission hygiene;
- it is consistent with the existing `SPDX-License-Identifier: MIT` declarations in the Standby-owned Solidity sources;
- no source licensing semantics were changed;
- no executable or protocol artifact changed;
- no verification suite was rerun because the change is non-executable;
- F10 COMPLETE / G10 PASS / CLOSED was not reopened;
- F9T was not begun.

Update the Session 17 material prompt count accordingly.

Do not rewrite existing Session 17 evidence or reports.

## Completion

Before displaying your completion report, persist the same substantive evidence in `docs/prompts/session-17-log.md`.

Then report:

1. the exact file added;
2. the copyright line used;
3. the audit-only Session 17 log update;
4. confirmation that no other repository file changed except the session log;
5. confirmation that no verification was rerun;
6. confirmation that F10/G10 was not reopened and F9T was not begun.

Stop after this bounded licensing change.
