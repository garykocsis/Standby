# Standby — Session 04

## F2 — EligibilityRegistry

Follow the permanent repository operating rules in:

- root `CLAUDE.md`
- `.claude/rules/solidity-style.md`
- `.claude/rules/testing.md`

This prompt contains only the F2-specific implementation boundary and G2 verification requirements.

## Validated Implementation Frontier

- F0 — v4 Infrastructure / Hook Deployment → G0 PASS
- F1 — Deterministic Economic Fixture → G1 PASS
- F2 — EligibilityRegistry → CURRENT
- F3+ → NOT YET AUTHORIZED

## Objective

Implement the dedicated external on-chain `EligibilityRegistry` required by the frozen Standby architecture and reference realization.

F2 establishes the authoritative source of eligibility predicates only.

It must NOT yet make eligibility economically consequential inside `StandbyHook`.

## Primary F2 Sources

Use the repository's established documentation authority rules.

The primary sources for this slice are:

- `docs/architecture.md`
- `docs/state-machine.md`
- `docs/uniswap-v4-realization.md`
- `docs/implementation-plan.md`
- `docs/testing-strategy.md`

Consult upstream canonical documents when necessary to resolve an F2 requirement.

## Required F2 Semantics

`EligibilityRegistry` is a dedicated external authority.

`StandbyHook` queries eligibility later; `StandbyHook` does not own eligibility administration.

The registry must preserve three logically distinct predicates:

1. Beneficiary eligibility
2. Trader eligibility
3. Liquidity-action eligibility

These predicates must remain independently controllable even if the same administrator and same account are used across all three in the demo.

Do NOT collapse them into one generic `eligible[address]` flag.

A minimal single-owner / single-admin registry is acceptable for the reference realization.

The registry should expose read functions semantically equivalent to:

- `isBeneficiaryEligible(address)`
- `isTraderEligible(address)`
- `isLiquidityActorEligible(address)`

Exact mutation function names are implementation details, but the authorized administrator must be able to independently set and revoke each predicate.

Default eligibility should be false unless the authoritative documentation requires otherwise.

## State Boundary

Persist only authoritative eligibility facts necessary to answer the three predicates.

Do NOT add:

- PoolManager state
- PoolId economic state
- Standby configuration
- Supporting Capacity
- Aggregate Capacity Obligation
- commitment state
- Remaining Entitlement
- exercise state
- validity state
- fulfillment state
- service ticks or domains
- currency assumptions
- canonical fixture numbers

Do not introduce derived downstream economic consequences into the registry.

## Enforcement Boundary

F2 must NOT modify `StandbyHook` to consume the registry.

F2 must NOT implement:

- Beneficiary enforcement
- Trader enforcement
- liquidity-action enforcement
- O1
- O2
- O3
- PES configuration or activation
- commitment admission
- exercise authorization
- liquidity protection
- Supporting Capacity derivation

Those belong to later slices.

At F2, the registry answers only:

“Is this account eligible under this particular predicate?”

It does not decide what Standby should do with that answer.

## Expected Production File Boundary

Prefer the minimum necessary production surface, likely:

- `src/interfaces/IEligibilityRegistry.sol`
- `src/EligibilityRegistry.sol`

Additional production files require clear F2-specific justification.

No modification to `src/StandbyHook.sol` is expected or authorized for F2.

## G2 — EligibilityRegistry Gate

### G2-A — Predicate Independence

Prove Beneficiary, Trader, and Liquidity-action eligibility are independently controllable.

The same account must be able to hold materially different combinations, for example:

- Beneficiary = true
- Trader = false
- Liquidity actor = false

Changing one predicate must not mutate either of the other predicates.

A single generic eligibility state shared by all three predicates fails G2.

### G2-B — Authorization

Prove:

- the authorized administrator can update all three eligibility categories;
- an unauthorized account cannot update any category;
- a failed unauthorized mutation leaves prior state unchanged.

### G2-C — Read Fidelity

For every eligibility category, prove both transitions:

- false → true
- true → false

The corresponding public read predicate must return the resulting authoritative fact.

Revocation is required evidence, not merely initial admission.

### G2-D — Cross-Domain Isolation

Explicitly prove that updating each eligibility category leaves the other two unchanged.

This must be demonstrated for:

- Beneficiary updates
- Trader updates
- Liquidity-action updates

### G2-E — Architectural Isolation

The completed F2 diff must demonstrate that the slice introduces no F3+ behavior.

In particular, F2 must not introduce:

- Hook consumption of eligibility
- commitment semantics
- PoolManager coupling
- Supporting Capacity calculation
- O1/O2/O3 enforcement
- PES configuration
- fixture-specific token identities
- fixture-specific direction assumptions
- fixture-specific decimal assumptions

Do not introduce PoolId-scoped eligibility unless an authoritative F2 source explicitly requires it.

## Testing Boundary

Add focused tests under the existing hierarchy, expected primarily at:

- `test/unit/EligibilityRegistry.t.sol`

The unit suite should provide direct evidence for G2-A through G2-D.

Useful coverage includes:

- all predicates default false;
- admin enables and revokes Beneficiary eligibility;
- admin enables and revokes Trader eligibility;
- admin enables and revokes Liquidity-action eligibility;
- the same account can hold different eligibility combinations;
- each category update leaves the other categories unchanged;
- unauthorized mutation of every category reverts;
- unauthorized mutation leaves previously established state unchanged.

Additional fuzz coverage is permitted only if it provides useful F2 evidence without expanding the implementation boundary.

F2 does not require Hook integration, invariant, periphery, or acceptance tests.

Do not claim integration evidence based on Hook consumption of the registry; that behavior belongs downstream.

## Required G2 Evidence

Run the F2-focused verification required by the repository rules, including at minimum:

- formatting
- build / size verification
- lint
- focused `EligibilityRegistry` unit suite
- complete test suite
- CI-profile complete test suite
- diff hygiene

The completion report must provide the exact commands and results necessary for G2 adjudication.

## F2 Documentation Boundary

No `docs/setup.md` update is expected unless F2 introduces a setup-affecting change.

No frozen normative document should require modification merely to implement F2.

## Completion Boundary

Stop after F2 implementation and F2 verification evidence.

Do NOT begin F3.

Return the F2 completion report required by the repository operating rules so that the implementation and G2 evidence can be independently reviewed before the gate is closed.
