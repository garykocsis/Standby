# Standby — Session 11 Implementation Prompt

## F8A — O2 Authorization / Hook-Owned Causal Context

You are implementing the next authorized slice of the Standby ETHGlobal 2026 Uniswap v4 reference implementation:

**F8A — O2 Authorization / Hook-Owned Causal Context**

Do not implement beyond F8A.

Permanent operating behavior is owned by `CLAUDE.md`.

Permanent Solidity and testing conventions are owned by `.claude/rules/*`.

This session prompt owns only the F8A-specific objective, scope, requirements, prohibitions, relevant file/dependency boundaries, gate evidence, stop conditions, and completion boundary.

The frozen canonical package and frozen implementation plan remain authoritative. Do not alter their semantics for implementation convenience.

---

## 1. Current implementation state

Completed and closed:

- F0 / G0
- F1 / G1
- F2 / G2
- F3 / G3
- F4 / G4
- F5 / G5
- F6A / G6A
- F7 / G7
- F6B / G6B

Current authorized slice:

- **F8A — O2 Authorization / Hook-Owned Causal Context**

Not yet authorized:

- F8B — Exact-Output Execution / Execution Evidence
- F8C — Authoritative Settlement / Direct Beneficiary Delivery
- F8D — Causal Finalization / Remaining Reduction
- GI
- F9
- F10

F8A must preserve all previously closed gates.

---

## 2. F8A objective

F8A must establish transaction-scoped O2 authorization such that exactly one:

- authentic commitment;
- authenticated exercise actor;
- authoritative Beneficiary;
- configured service/pool;
- configured ExerciseRouter; and
- requested quantity `q`

are causally bound by the `StandbyHook` before any protected exercise swap occurs.

The resulting authorization is a **Hook-owned transaction-scoped causal capability**.

F8A authorization is not:

- qualifying execution;
- execution evidence;
- input settlement;
- Beneficiary delivery;
- fulfillment;
- Remaining Entitlement reduction; or
- authoritative obligation reduction.

F8A owns only authorization and creation of the causal basis required by later O2 stages.

---

## 3. Existing responsibility boundaries

F8A must consume existing authoritative owners rather than recreate their responsibilities.

### F4 — Commitment Storage / Bounded References

Use the existing authoritative commitment identity, storage, and bounded-reference system.

F8A must not introduce:

- alternate commitment storage;
- an exercise-side commitment registry;
- duplicate commitment identity; or
- another authoritative source of commitment facts.

### F5 — Authoritative Derivations

Reuse the existing authoritative derivations applicable to:

- Validity;
- Exercisability and temporal conditions;
- Remaining Entitlement;
- current aggregate `O`;
- prospective protected exact-output Supporting Capacity `S′`;
- applicable binding/backing semantics.

Do not create an F8A-specific competing derivation of these quantities or predicates.

Preserve the real-PoolManager traversal semantics established by F5.

### F6A — Trust / Attribution Boundary

Preserve the existing attribution rule:

> Authentication of the trusted router precedes trust in its transaction-local originating-caller attribution.

The configured ExerciseRouter must first be authenticated.

Only then may the Hook obtain the actual originating exerciser through the router's authenticated transaction-local originator mechanism, such as the existing `msgSender()` mechanism or its repository-equivalent.

An arbitrary exerciser address supplied through calldata or `hookData` is not authoritative.

### F7 — Production O1 Admission

F8A consumes production-created commitments and their existing admitted authoritative facts.

F8A must not:

- redefine commitment admission;
- alter admitted terms;
- create a second exercise-specific commitment representation; or
- mutate the admitted semantic basis.

### F6B — O3 Backing Enforcement

F8A must not alter the existing O3 backing-enforcement behavior established by F6B.

In particular, F8A must not disturb ordinary-swap or liquidity-transition classification or enforcement.

---

## 4. ExerciseRouter trust and authority boundary

The configured ExerciseRouter is a trusted O2 coordination/perimeter component.

It is not authoritative for:

- commitment existence;
- commitment terms;
- Beneficiary identity;
- exercise authority;
- Validity;
- Exercisability;
- Remaining Entitlement;
- `S`;
- `O`;
- fulfillment; or
- entitlement reduction.

The router address itself never satisfies commitment-specific exercise authority.

F8A must establish:

```text
authenticated originating exerciser
==
commitment.exerciseAuthority
```

The originating exerciser becomes trusted only through the authenticated configured ExerciseRouter's transaction-local attribution mechanism.

Router-supplied calldata or `hookData` must not be capable of substituting another exercise actor.

---

## 5. F8A router boundary

The eventual conceptual O2 request is:

```solidity
exercise(uint256 commitmentId, uint256 q, uint256 maxInput)
```

For F8A, implement only the portion required to establish:

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

F8A must not yet implement:

- `PoolManager.swap`;
- protected exact-output execution;
- authoritative execution evidence;
- input settlement;
- actual `maxInput` enforcement against PoolManager debt;
- output delivery;
- `PoolManager.take(... Beneficiary ...)`;
- fulfillment finalization;
- Remaining Entitlement reduction.

`maxInput` is exercise-local cost protection for the later execution/settlement path.

It is not an F8A economic authorization fact.

F8A must not use `maxInput` to redefine commitment validity, entitlement, obligation, service semantics, or prospective backing.

---

## 6. F8A authorization predicates

Before an AUTHORIZED causal context may exist, the Hook must establish all applicable F8A predicates from authoritative existing facts and derivations.

### 6.1 Exercise perimeter

Require the exact configured ExerciseRouter for the commitment's configured service.

### 6.2 Originating exerciser

Recover the originating exerciser only after ExerciseRouter authentication through the router's transaction-local attribution mechanism.

### 6.3 Commitment identity

Require that the targeted `commitmentId` resolves to exactly one authentic Hook-owned commitment.

### 6.4 Service binding

Require that the commitment belongs to the applicable configured Protected Execution Service / pool.

### 6.5 Exercise authority

Require:

```text
authenticatedExerciser == commitment.exerciseAuthority
```

### 6.6 Current Validity

Require the existing authoritative Validity predicate.

### 6.7 Current Exercisability

Require the existing authoritative Exercisability predicate, including the applicable temporal boundary:

```text
exercisableFrom <= block.timestamp < validUntil
```

Do not strengthen this with an invented additional validity condition.

### 6.8 Beneficiary eligibility

Resolve the Beneficiary from authoritative commitment state.

Require current:

```text
canReceiveProtectedService(authoritativeBeneficiary)
```

Current Beneficiary ineligibility prevents exercise authorization but does not by itself reduce Remaining Entitlement, release a still-binding obligation, or modify commitment terms.

### 6.9 Exercise extent

Require:

```text
0 < q <= Remaining
```

Full Remaining exercise is permitted when all other predicates hold.

### 6.10 Prospective protected execution

Use the existing F5 authoritative prospective derivation to determine `S′` for the canonical protected exact-output exercise of exactly `q`.

### 6.11 Current obligation

Use the existing authoritative derivation of current aggregate `O`.

### 6.12 Prospective successful backing

Require:

```text
S′ >= O - q
```

Equality must pass.

`O - q` represents the prospective post-fulfillment obligation of the complete successful O2.

F8A does **not** authoritatively reduce `O` during authorization.

Remaining Entitlement likewise remains unchanged.

Only after all required predicates succeed may the Hook create the AUTHORIZED causal context.

---

## 7. Hook-owned transaction-scoped causal context

The F8A authorization context must bind at least the causal identity required by the frozen reference realization:

```text
state
service / PoolId
commitmentId
authenticated ExerciseRouter
authenticated exerciser
authoritative Beneficiary
q
protected execution identity/context
```

The representation should contain only the minimum authoritative causal bindings necessary for later O2 stages to prove that execution belongs to this exact authorized attempt.

Do not add snapshots of derived economic state such as:

- `S`;
- `S′`;
- `O`;
- Remaining Entitlement;
- Validity;
- Exercisability;
- eligibility flags.

Do not duplicate immutable service facts merely to create another source of truth where the bound service/PoolId already provides an authoritative reconstruction basis.

The context must remain sufficient for F8B later to verify that the actual protected execution corresponds exactly to this authorization.

F8A must not implement that F8B execution matching yet.

---

## 8. F8 causal lifecycle boundary

The eventual O2 causal lifecycle is:

```text
EMPTY
  → AUTHORIZED
  → EXECUTED
  → consumed / EMPTY
```

F8A owns only:

```text
EMPTY → AUTHORIZED
```

F8A must not implement:

```text
AUTHORIZED → EXECUTED
```

or successful fulfillment consumption/finalization.

Authorization context creation is a consequence of successful authorization, not an input used to manufacture authorization.

A failed authorization must leave no usable authorization context.

---

## 9. Transaction-scoped context requirement

F8A requires transaction-scoped causal evidence rather than persistent O2 lifecycle state.

For this slice, inspect the existing compiler/EVM configuration only as necessary to determine whether the repository can directly support the required transaction-scoped context.

Transient storage is the preferred realization if it is supported by the existing repository/toolchain.

Do not introduce persistent O2 lifecycle state merely to emulate transaction-local authorization.

If the current environment cannot realize the required transaction-scoped context without introducing persistent lifecycle semantics or changing frozen protocol meaning, stop and report that as an F8A blocker.

---

## 10. Replay and substitution requirements

F8A must prevent authorization-context reuse or substitution across:

- transactions;
- commitments;
- exercise actors;
- Beneficiaries;
- services/pools;
- quantities;
- ExerciseRouters.

Only one active O2 authorization may exist for the applicable causal transaction.

A second or nested authorization must not overwrite, coexist with, or substitute the active authorization.

Successful authorization of one commitment must not create a capability usable for another commitment.

Successful authorization of one `q` must not authorize another quantity.

Successful authorization for one Beneficiary must not authorize delivery for another Beneficiary.

Successful authorization through one authenticated service/router context must not authorize another service/router context.

F8A prevents **authorization replay**.

Execution replay prevention belongs to F8B and later causal stages.

---

## 11. F8A economic-reentrancy requirement

While the O2 causal context is unresolved, another authoritative Standby operation must not interleave in a way that creates, observes, overwrites, or mutates a conflicting economically intermediate O2 state.

For F8A specifically:

```text
EMPTY
    → authorization may begin

AUTHORIZED
    → another authorization may not become active
```

As part of F8A implementation, determine whether any F8A-specific external interaction before AUTHORIZED context creation permits an overlapping valid authorization to arise.

If the existing call topology does permit such an F8A reentrancy path, the F8A implementation must prevent it without broadening into F8B/F8C/F8D responsibility.

The exact Solidity mechanism remains implementation discretion subject to existing repository conventions.

---

## 12. Required F8A verification evidence

G8A requires evidence for the following F8A-specific behaviors.

### 12.1 Positive authorization

Using a production-created authentic commitment, demonstrate successful authorization when:

```text
configured ExerciseRouter
+
authenticated correct exercise authority
+
current Validity
+
current Exercisability
+
eligible authoritative Beneficiary
+
0 < q <= Remaining
+
S′ >= O - q
```

all hold.

Verify the resulting exact causal bindings.

### 12.2 Exercise perimeter / authority

Demonstrate rejection of relevant cases including:

- direct/untrusted authorization caller;
- non-configured ExerciseRouter;
- wrong originating exerciser;
- ExerciseRouter address attempting to substitute for commitment exercise authority;
- forged exerciser data through calldata or `hookData`, if an applicable surface exists.

### 12.3 Commitment identity

Demonstrate rejection for:

- nonexistent commitment;
- commitment/service mismatch where representable;
- commitment substitution.

### 12.4 Temporal boundaries

Demonstrate the canonical boundaries:

```text
before exercisableFrom  → reject
at exercisableFrom      → permit when otherwise valid
before validUntil       → permit when otherwise valid
at validUntil           → reject
```

Also verify applicable existing release/invalidity behavior without inventing stronger requirements.

### 12.5 Beneficiary eligibility

Demonstrate:

```text
eligible Beneficiary   → may authorize
ineligible Beneficiary → reject
```

and show that failed authorization due to ineligibility does not itself alter Remaining Entitlement or the existing binding obligation.

### 12.6 Exercise extent

Demonstrate:

```text
q == 0             → reject
0 < q < Remaining  → permit when otherwise safe
q == Remaining     → permit when otherwise safe
q > Remaining      → reject
```

### 12.7 Prospective backing

Using authentic production-created `O > 0`, demonstrate:

```text
S′ > O - q  → permit
S′ = O - q  → permit
S′ < O - q  → reject
```

The evidence must remain consistent with the existing F5 authoritative derivation.

### 12.8 Causal binding

Demonstrate that successful authorization binds the exact:

- service/pool;
- commitment;
- configured authenticated ExerciseRouter;
- authenticated exerciser;
- authoritative Beneficiary;
- `q`;
- applicable protected execution identity.

Demonstrate that substitution cannot create or overwrite another valid authorization context.

### 12.9 Replay / nesting

Demonstrate:

- second authorization while AUTHORIZED cannot create another active authorization;
- nested authorization cannot create overlapping causal context;
- authorization cannot be reused across transactions;
- failed authorization leaves no usable context.

### 12.10 Authorization is not fulfillment

After successful F8A authorization, demonstrate that authorization alone causes:

```text
Remaining Entitlement  → unchanged
authoritative O        → unchanged
fulfillment            → none
Beneficiary delivery   → none
execution evidence     → none
```

and that no:

```text
AUTHORIZED → EXECUTED
```

transition has yet been implemented.

### 12.11 F8A fuzz evidence

Provide F8A-specific fuzz evidence where appropriate for:

- `q` extent boundaries;
- prospective `S′` versus `O - q` boundary behavior;
- identity/actor substitution where useful.

---

## 13. Regression boundary

F8A must preserve all behavior established by previously closed implementation gates, particularly the relevant:

- F4;
- F5;
- F6A;
- F7;
- F6B

behavior.

The required completion evidence must include the repository's normal build/test results and relevant regression results required by the permanent project operating/testing rules.

---

## 14. G8A — Authorization / Hook-Owned Causal Context Gate

F8A may be presented for independent review only when implementation evidence establishes all of the following:

1. The exact configured ExerciseRouter is required for the supported O2 authorization path.

2. ExerciseRouter identity itself never satisfies commitment-specific exercise authority.

3. The originating exerciser is recovered only after ExerciseRouter authentication through its transaction-local attribution mechanism and cannot be forged through calldata or `hookData`.

4. `commitmentId` resolves exactly one authentic Hook-owned commitment associated with the applicable configured service.

5. The authenticated originating exerciser equals the commitment's authoritative exercise authority.

6. Existing authoritative Validity, Exercisability, temporal, and current Beneficiary-eligibility predicates are enforced.

7. Exercise extent is accepted exactly for:

```text
0 < q <= Remaining
```

including full Remaining exercise when otherwise permitted.

8. Prospective protected execution uses the existing authoritative F5 derivation and requires:

```text
S′ >= O - q
```

with equality accepted.

9. Successful authorization creates exactly one Hook-owned AUTHORIZED causal context containing only the minimum required causal bindings.

10. The causal context prevents ExerciseRouter, commitment, actor, Beneficiary, service/pool, and quantity substitution.

11. A second or nested active authorization cannot overwrite or coexist with the active authorization.

12. Failed authorization leaves no usable causal context, and successful authorization cannot be reused across transactions.

13. Successful F8A authorization alone leaves Remaining Entitlement and authoritative `O` unchanged and produces no fulfillment, protected-execution evidence, settlement, or Beneficiary delivery.

14. F8B/F8C/F8D responsibilities remain unimplemented:
    - no `AUTHORIZED → EXECUTED`;
    - no protected exact-output execution evidence;
    - no authoritative settlement/delivery;
    - no fulfillment finalization;
    - no Remaining Entitlement reduction.

15. Relevant previously closed implementation gates remain green.

Claude's G8A assessment is implementation evidence only.

ChatGPT will independently review the actual implementation and tests and make the independent G8A determination.

---

## 15. F8A-specific file/dependency boundary

The F8A implementation may touch only files genuinely required to realize:

- ExerciseRouter transaction-local originating-exerciser attribution;
- StandbyHook O2 authorization;
- Hook-owned transaction-scoped causal context;
- F8A-specific test/harness support where required;
- Session 11 implementation evidence.

Do not modify frozen canonical semantic artifacts.

Do not modify F4/F5/F6A/F7/F6B semantics to make F8A easier to implement.

Do not introduce F8B/F8C/F8D implementation.

---

## 16. Session 11 implementation record

For this session, the implementation evidence record is:

```text
docs/prompts/session-11-log.md
```

Capture F8A-specific evidence materially necessary to reconstruct this implementation slice, including any substantive:

- F8A responsibility interpretation;
- transaction-scoped context decision;
- ExerciseRouter originator-attribution decision;
- F8A economic-reentrancy finding;
- implementation deviation or unexpected constraint;
- test/gate evidence;
- semantic issue encountered.

Do not create or modify:

```text
docs/prompts/retrospective/session-11-chatgpt-record.md
```

ChatGPT owns that separate retrospective record after independent review.

---

## 17. Stop conditions

Stop F8A implementation and report the issue rather than inventing a workaround if implementation exposes any of the following:

- conflict with a frozen canonical artifact;
- F8A cannot be implemented without redefining F4, F5, F6A, F7, or F6B semantics;
- correct transaction-scoped causal context cannot be realized under the current implementation environment without introducing persistent O2 lifecycle semantics;
- the configured ExerciseRouter attribution path cannot securely establish the originating exerciser;
- satisfying F8A necessarily requires implementing F8B, F8C, or F8D economic responsibility;
- the existing authoritative derivations cannot support the required F8A predicates;
- another genuine unresolved protocol-semantic ambiguity.

Such a finding is a blocker requiring normative review, not implementation discretion.

---

## 18. F8A completion boundary

When F8A implementation and verification are complete, report the evidence needed for independent review:

1. implementation summary;
2. files changed;
3. F8A tests/evidence added;
4. build and test results;
5. evidence against each G8A condition;
6. F8A-specific implementation discretion exercised;
7. any remaining concern, ambiguity, or deviation.

Do not begin F8B.

F8A remains provisional until ChatGPT independently reviews the implementation and tests and determines whether G8A passes.
