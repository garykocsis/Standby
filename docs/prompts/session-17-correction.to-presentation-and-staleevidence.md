The independent F10/G10 review found one narrow presentation-fidelity issue and one stale evidence-record item.

Make only the minimum F10 corrections described below.

## 1. Correct the authoritative-state wording

The current frontend header says:

`every value below is read from this chain`

That statement is too broad because the page also displays proposed transaction/configuration facts such as requested swap quantities and the exercise max-input bound.

The implementation correctly distinguishes:

- authoritative economic state;
- proposed transaction facts;
- prospective production-derived state;
- transaction/revert evidence.

Preserve that distinction in the UI wording.

Change the header to wording equivalent to:

`authoritative economic state below is read from this chain`

Do not change economic behavior, transaction construction, protocol reads, state handling, or layout beyond what is necessary for this wording correction.

Also correct the corresponding overstatement in the root `README.md`:

`The interface displays no economic value it did not read from the chain.`

Replace it with wording that accurately states that the frontend derives no authoritative economic truth itself, authoritative economic state comes from deployed protocol/PoolManager/token reads, and proposed transaction facts are separately presented from canonical demo configuration.

Do not broaden or rewrite the README beyond the minimum necessary correction.

## 2. Update the Session 17 evidence record

Update `docs/prompts/session-17-log.md` to record the human interactive browser verification that occurred after Claude's original completion report.

Record as additional contemporaneous evidence that the user manually performed:

```text
canonical pre-A1 state observed in the browser

A1 executed successfully:
S = 80,000
O = 50,000
Remaining = 50,000

A2 executed successfully:
S = 65,000
O = 50,000
Remaining = 50,000

browser page reloaded after A2

authoritative post-A2 state reconstructed correctly from chain

Commitment #1 reconstructed from chain with:
Original Entitlement = 50,000
Remaining Entitlement = 50,000
Beneficiary
Exercise Authority
Exercisable From
Valid Until

A3 submitted through the browser

specific Standby backing rejection displayed:
StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)

prospective S' = 45,000 explicitly distinguished from authoritative state

post-revert authoritative state remained:
S = 65,000
O = 50,000
Remaining = 50,000

A4 executed successfully through the browser

Beneficiary MockUSDC balance:
before = 0
after = 50,000
delivered = 50,000

final authoritative state:
S = 15,000
O = 0
Remaining = 0
Backing = 15,000 >= 0
```

The browser also displayed the configured commitment validity window and the bounded demo claim footer.

Remove or supersede statements that say the interactive browser run remains unverified.

Do **not** state that G10 has passed. Gate closure remains the responsibility of the independent reviewer.

## 3. Verification

After the wording changes:

```bash
cd frontend
npm run lint
npm run build
```

No Solidity regression rerun is required unless something outside the two presentation/documentation files and the session log changes.

Do not modify:

- `src/**`;
- existing Solidity tests;
- protocol semantics;
- demo transaction semantics;
- deployment/bootstrap semantics;
- `docs/project-status.md`.

Before displaying the correction completion report, append the complete correction report and verification results to docs/prompts/session-17-log.md. The persisted report and displayed report must contain the same substantive evidence.

## 4. Completion Boundary

Stop when:

```text
frontend authoritative-state wording corrected

README authoritative/proposed-state wording corrected

human browser verification persisted in session-17-log.md

stale browser-unverified statements corrected

frontend lint passes

frontend build passes

correction report produced
```

Do not begin F9T.

Do not mark F10 complete or G10 PASS.

Return the exact files changed and verification results for independent re-review.
