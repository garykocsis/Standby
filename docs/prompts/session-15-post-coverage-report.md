Re-run the repository's established coverage workflow now that GI — Full Stateful Invariant Verification has passed independent review.

This is a **diagnostic-only post-GI refresh**.

Do not modify production code, invariant tests, frozen artifacts, or `docs/project-status.md` in response to coverage percentages alone.

Before running coverage, inspect:

```text
docs/reports/coverage-summary.md
docs/prompts/session-15-log.md
```

and the relevant prior session log, repository configuration, scripts, or commands referenced by the existing coverage report as necessary to reconstruct the exact coverage workflow that produced the current post-F8D baseline.

Do not assume knowledge from a previous Claude session.

Use the existing repository evidence to determine:

- the coverage command(s);
- profile/configuration used;
- source/test inclusion or exclusion rules;
- any report-generation or parsing procedure;
- the existing `docs/reports/coverage-summary.md` structure and reporting conventions.

Preserve that methodology for the post-GI run rather than introducing a new coverage procedure.

If the exact prior methodology cannot be reconstructed from repository artifacts, stop and report the ambiguity rather than silently choosing a different methodology.

Update:

```text
docs/reports/coverage-summary.md
```

to reflect the post-GI repository state.

Preserve comparison against the existing post-F8D baseline:

```text
Lines       99.42%
Statements  98.33%
Branches    91.35%
Functions   100%
```

The report should distinguish:

- post-F8D baseline;
- post-GI coverage result;
- delta;
- any newly covered production surfaces attributable to the GI stateful invariant suite;
- any remaining uncovered or partially covered production surfaces that appear semantically relevant;
- any remaining gaps that are merely diagnostic or structurally unreachable through the supported production domain.

Do not treat coverage as proof of semantic correctness, invariant preservation, or G-I closure.

Do not introduce new tests solely to improve coverage during this follow-up unless a coverage observation exposes an actual previously unrecognized frozen verification obligation. If such an issue appears, report it rather than expanding scope automatically.

Also record the coverage command(s), methodology reconstructed from repository evidence, and result in:

```text
docs/prompts/session-15-log.md
```

as a post-GI diagnostic follow-up.

Stop after refreshing the coverage report and Session 15 log.
