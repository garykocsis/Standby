# Standby — Session 11 F8A Corrective Prompt

## F8A — `maxInput` Request-Surface Fidelity Correction

Independent ChatGPT review of the completed F8A implementation found the substantive F8A authorization semantics and all fifteen G8A conditions conforming.

**G8A is currently CONDITIONAL PASS / NOT YET CLOSED** because one bounded implementation-plan fidelity correction remains.

This prompt authorizes **only that correction and its directly necessary verification**.

Do not reopen F8A design.

Do not begin F8B, F8C, or F8D.

Permanent operating behavior remains owned by `CLAUDE.md`.

Permanent Solidity/testing conventions remain owned by `.claude/rules/*`.

---

## 1. Independent-review finding

The implemented F8A `ExerciseRouter.exercise` currently accepts:

```solidity
exercise(uint256 commitmentId, uint256 q)
```

The frozen implementation plan assigns F8A R1 request intake the request surface:

```solidity
exercise(
    uint256 commitmentId,
    uint256 q,
    uint256 maxInput
)
```

Although `maxInput` has no F8A economic authorization semantics, the frozen implementation plan already places it on the F8A request surface.

Its omission is therefore a **request-surface fidelity issue**, not an authorization-semantics failure.

The correction is to restore `maxInput` to the F8A ExerciseRouter request surface while preserving the existing F8A responsibility boundary.

---

## 2. Required correction

Change the F8A ExerciseRouter request surface from:

```solidity
exercise(uint256 commitmentId, uint256 q)
```

to:

```solidity
exercise(
    uint256 commitmentId,
    uint256 q,
    uint256 maxInput
)
```

Update only directly affected F8A callers/tests/fixtures as required by that signature change.

The existing F8A authorization path must remain semantically unchanged:

```text
external exerciser
    ↓
configured ExerciseRouter
    ↓
authenticated transaction-local originator
    ↓
StandbyHook authorization
    ↓
AUTHORIZED causal context
```

---

## 3. `maxInput` ownership boundary

For F8A, `maxInput` is **request-surface data only**.

F8A must not:

- validate `maxInput`;
- compare `maxInput` against any value;
- use `maxInput` to decide authorization;
- pass `maxInput` into `StandbyHook.authorizeExercise`;
- store `maxInput` in the Hook-owned AUTHORIZED causal context;
- persist `maxInput` as Standby economic state;
- interpret `maxInput` as commitment semantics;
- interpret `maxInput` as service semantics;
- interpret `maxInput` as Remaining Entitlement;
- interpret `maxInput` as `S`, `S′`, or `O`;
- derive PoolManager debt;
- enforce an input-cost bound;
- implement input settlement.

Actual enforcement of the exerciser's input-cost protection requires authoritative execution/debt evidence and belongs to its later owning O2 stage.

This correction establishes the frozen request shape only.

---

## 4. Existing F8A authorization must remain unchanged

Do not change the independently reviewed authorization predicates:

1. exact configured ExerciseRouter;
2. authenticated transaction-local originating exerciser;
3. authentic commitment;
4. service binding;
5. originating exerciser equals commitment exercise authority;
6. current Validity;
7. current Exercisability and temporal boundaries;
8. current authoritative Beneficiary eligibility;
9. `0 < q <= Remaining`;
10. authoritative F5 prospective `S′`;
11. authoritative current aggregate `O`;
12. `S′ >= O - q`, with equality accepted.

Do not change the existing Hook-owned causal-context contents.

In particular, `maxInput` must **not** be added to:

```text
state
serviceId
commitmentId
authenticated ExerciseRouter
authenticated exerciser
authoritative Beneficiary
q
```

The causal context continues to represent the economic operation authorized by F8A, not later exercise-local settlement constraints.

---

## 5. Preserve the independently reviewed implementation

The independent review accepted the following existing F8A decisions.

Do not alter them as part of this correction unless the signature change makes a strictly mechanical adjustment necessary:

- EIP-1153 transient realization of the transaction-scoped causal context;
- `AUTHORIZING` as a transaction-local in-flight guard rather than an economic lifecycle position;
- `EMPTY -> AUTHORIZED` as the only F8A causal lifecycle transition;
- configured-router authentication before originator recovery;
- Hook-owned resolution of commitment facts and economic predicates;
- existing F5 prospective derivation reuse;
- the `S′ >= O - q` authorization predicate;
- no authoritative reduction of `O`;
- no Remaining Entitlement reduction;
- no F8A fulfillment consequence;
- no execution evidence;
- no settlement;
- no Beneficiary delivery;
- no `AUTHORIZED -> EXECUTED`.

Do not use this correction as an opportunity for unrelated cleanup or redesign.

---

## 6. Verification requirement

Update the F8A invocation sites as required by the restored three-argument request surface.

Verification must establish that adding `maxInput` to the request does **not** alter F8A authorization semantics.

At minimum, demonstrate that otherwise identical valid F8A requests with materially different `maxInput` values produce the same authorization result and the same Hook-owned causal bindings.

For example, values at substantially different points in the `uint256` domain may be used as appropriate under the repository's permanent testing conventions.

The evidence must show that F8A does not:

```text
authorize because of maxInput
reject because of maxInput
store maxInput in causal context
change q because of maxInput
change commitment identity because of maxInput
change Beneficiary because of maxInput
change actor attribution because of maxInput
change S′ or O derivation because of maxInput
```

All existing F8A authorization, perimeter, integration, unit, fuzz, transaction-scope, and prior-gate regression behavior must remain intact.

---

## 7. Scope prohibition

This correction does **not** authorize:

- `PoolManager.swap`;
- protected exact-output execution;
- `AUTHORIZED -> EXECUTED`;
- execution evidence;
- actual input-debt derivation;
- `maxInput` enforcement;
- input settlement;
- `PoolManager.take`;
- Beneficiary delivery;
- fulfillment determination;
- Remaining Entitlement reduction;
- authoritative obligation reduction;
- F8B;
- F8C;
- F8D.

If restoring the request parameter unexpectedly requires any of those responsibilities, stop and report the conflict rather than implementing them.

---

## 8. Session 11 evidence

For this correction, the Session 11 evidence record remains:

```text
docs/prompts/session-11-log.md
```

Capture the following correction-specific evidence:

- the independent-review finding;
- the bounded request-surface correction;
- files changed;
- verification added or adjusted;
- test/build results;
- confirmation that `maxInput` remains semantically inert in F8A;
- confirmation that no F8B/F8C/F8D responsibility was introduced.

## 9. Completion report

When the bounded correction is complete, report:

1. exact files changed;
2. exact request-surface change;
3. any F8A invocation/test changes required by the new parameter;
4. evidence that differing `maxInput` values do not affect F8A authorization or causal context;
5. build/test/regression results;
6. confirmation that no existing F8A authorization semantics changed;
7. confirmation that `maxInput` is not stored or interpreted by the Hook;
8. confirmation that no F8B/F8C/F8D responsibility was implemented;
9. any unexpected issue encountered.

Do not begin F8B.
