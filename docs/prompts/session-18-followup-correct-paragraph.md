Make one narrow semantic correction to the Session 18 `README.md` update.

In the time-bounded commitment lifecycle section, the current text states:

> “An expired commitment was never exercised and the Beneficiary received nothing...”

That statement is too strong because a commitment may be partially fulfilled before `validUntil` and then expire with remaining unfulfilled entitlement.

Preserve:

> **Expiry releases an obligation. Expiry is not fulfillment.**

Replace the explanation immediately following it with wording equivalent to:

> When a commitment reaches `validUntil`, any remaining unfulfilled entitlement ceases contributing to Capacity Obligation. Expiration does not represent that remaining entitlement as fulfilled or imply additional Beneficiary delivery. The practical consequence is that Standby protects a bounded quantity of future execution capacity for a bounded period, rather than imposing an open-ended constraint on shared liquidity.

The required semantic distinction is:

```text
successful fulfillment
    → fulfilled quantity reduces Remaining Entitlement and O
    → actual attributable Beneficiary delivery occurred

expiration
    → any remaining unfulfilled entitlement ceases contributing to O
    → expiration is not fulfillment
    → no additional Beneficiary delivery is implied
```

Do not make any other README editorial changes unless strictly necessary to accommodate this correction.

Do not modify production code, tests, canonical artifacts, frozen Mermaid diagrams, project status, or any other substantive repository content.

Record this material follow-up in the existing Session 18 log as required by the repository's permanent session-logging instructions.

After the correction, run the same lightweight README/documentation verification appropriate to this session and report the resulting diff.

Stop after this correction and verification.

Do not begin F9T or any other task.
