# Session 12 — F8B Documentation Correction

## 1. Working Model

Use the established repository ownership model.

- `CLAUDE.md` owns permanent operating behavior.
- `.claude/rules/*` owns permanent Solidity/testing conventions.
- This prompt owns only this bounded F8B correction, its scope, prohibitions, required evidence, and completion boundary.

This is **not a new implementation slice**.

F8B production behavior has already undergone independent review and is substantively accepted.

The only open issue before G8B closure is stale F8A-era documentation that became factually incorrect after F8B introduced the protected PoolManager execution.

Maintain the existing Session 12 implementation record:

```text
docs/prompts/session-12-log.md
```

Record this correction as a material follow-up prompt and document exactly what changed.

---

# 2. Objective

Correct stale comments, NatSpec, or test documentation that still state or imply that:

```text
no swap executes at this slice
```

or equivalent wording.

That statement was valid during F8A but is no longer valid after F8B.

F8B now performs the protected exact-output PoolManager execution.

However:

- F8B does not settle the resulting input debt;
- F8B does not enforce `actualInput <= maxInput`;
- F8B does not deliver protected output to the Beneficiary;
- those responsibilities remain assigned to F8C.

The documentation must describe that boundary accurately.

---

# 3. Required Semantic Correction

The corrected documentation must preserve this distinction:

```text
F8B:
    protected exact-output swap executes
    authoritative PoolManager execution evidence is established
    actual input debt therefore exists

F8C:
    derive authoritative actual input debt for settlement
    enforce actualInput <= maxInput
    settle that debt
    deliver protected output directly to the authoritative Beneficiary
```

Therefore, `maxInput` remains semantically inert **for F8B authorization/execution classification and evidence**, not because no swap occurs, but because enforcement of the resulting actual input debt belongs to F8C.

A suitable formulation is:

> `maxInput` remains semantically inert through F8B. The protected exact-output swap now executes and produces authoritative PoolManager input debt, but enforcement of `actualInput <= maxInput` belongs to F8C together with authoritative settlement. F8B therefore does not consume or enforce `maxInput`.

Use wording appropriate to each local comment or test description; do not mechanically copy this text if a shorter formulation is clearer.

---

# 4. Known Locations to Inspect

At minimum inspect the stale F8A-era wording in:

```text
src/ExerciseRouter.sol
```

particularly the `exercise(...)` NatSpec / `maxInput` explanation.

Also inspect:

```text
test/fuzz/ExerciseAuthorizationFuzz.t.sol
```

particularly documentation around:

```text
testFuzz_maxInput_changesNoAuthorizationOutcome
```

where F8A-era wording may still state that no swap executes.

Search the changed F8A/F8B files for materially equivalent stale claims so the correction is complete.

Do not alter text merely because it predates F8B; change only statements that became factually false or misleading because F8B now executes R3.

---

# 5. Scope

This correction is documentation-only.

Permitted changes:

```text
comments
NatSpec
test comments
test explanatory documentation
docs/prompts/session-12-log.md
```

No production behavior should change.

No test behavior should change.

No assertion should change.

No contract interface should change.

No storage should change.

No test fixture behavior should change.

---

# 6. Prohibitions

Do not:

```text
modify F8B execution semantics
modify O2/O3 classification
modify the causal lifecycle
modify EXECUTING or EXECUTED behavior
change ExerciseRouter execution flow
implement or partially implement F8C
enforce maxInput
settle PoolManager input debt
deliver output to the Beneficiary
modify Remaining
modify authoritative O
perform fulfillment or finalization
begin GI
begin F9
update docs/project-status.md
```

This correction must not reopen an already accepted implementation decision.

---

# 7. Verification

After the documentation correction, run the repository-standard verification required by the existing permanent instructions.

At minimum confirm:

```text
forge fmt --check
forge build
forge test
FOUNDRY_PROFILE=ci forge test
```

If the permanent repository rules require additional commands, follow those rules.

The expected result is behavioral equivalence with the already reviewed F8B implementation.

---

# 8. Required Completion Report

Return a concise report containing:

1. files inspected;
2. files changed;
3. each stale statement corrected;
4. confirmation that changes were documentation-only;
5. commands run;
6. verification results;
7. confirmation that no F8C/F8D behavior was introduced;
8. confirmation that `docs/project-status.md` was not changed;
9. updated `docs/prompts/session-12-log.md` entry for this material follow-up.

Do not propose new F8B architecture or redesign unless the documentation correction unexpectedly exposes an actual contradiction in production behavior.

---

# 9. Completion Boundary

This task ends when:

```text
stale F8A-era documentation corrected
+
Session 12 log updated
+
verification remains green
```

**Stop at the F8B documentation-correction boundary.**
