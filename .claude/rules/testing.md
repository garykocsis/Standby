---
globs: ["test/**/*.sol"]
---

# Testing Architecture

Use the repository test hierarchy:

```text
test/
├── harness/
├── shared/
├── unit/
├── fuzz/
├── invariant/
├── integration/
├── periphery/
└── acceptance/
```

Tests belong in the narrowest correct category.

Do not place an integration test in `unit/` merely because it is easier to run.

Do not use a harness in integration, invariant, periphery, or acceptance tests as a shortcut around production behavior.

---

# Harness Isolation

Harnesses are permitted when they expose otherwise inaccessible production logic or facts for isolated testing.

Harnesses are intended for:

- unit tests;
- fuzz tests where isolated internal behavior must be exercised.

Harness-only state or privileged seeded state is not valid evidence for:

- production transitions;
- integration tests;
- invariant tests;
- periphery tests;
- canonical acceptance tests.

Do not allow test convenience to become production authority.

---

# Acceptance Fixture Independence

Canonical acceptance tests must construct economic state through real deployment, configuration, and behavioral paths.

Do not seed authoritative economic state directly.

Do not use harness-only state to satisfy acceptance preconditions.

The acceptance fixture must demonstrate that the production system itself can reach the required state.

---

# Unit Tests

Unit tests should prove focused local behavior.

Use them for:

- validation rules;
- authorization predicates;
- local state transitions;
- custom errors;
- boundary cases;
- isolated deterministic calculations.

Use harnesses only where justified by the harness-isolation rule.

---

# Fuzz Tests

Use fuzz testing for parameterized behavior and boundary exploration.

Bound fuzz inputs intentionally based on semantic domains.

Do not constrain fuzz inputs so aggressively that meaningful failure regions disappear.

Where appropriate, compare production derivations against independent reference calculations.

Use the deterministic local seed defined by `foundry.toml` unless explicitly testing seed variation.

---

# Invariant Tests

Stateful invariant testing is a first-class verification requirement.

Invariant handlers must interact through real production interfaces for the behavior being verified.

Do not seed economic truth through harness-only shortcuts.

Invariant tests should verify both preservation and authoritative derivation correctness where required.

Use `docs/invariants.md` and `docs/testing-strategy.md` as the authoritative source for invariant families and required actions.

---

# Integration Tests

Integration tests should prove component interaction through realistic execution paths.

Where Uniswap v4 behavior matters, exercise the real pinned PoolManager stack.

Do not replace integration behavior with isolated mocks merely to make tests simpler.

---

# Periphery Tests

Periphery tests must prove that coordination contracts preserve architectural authority boundaries.

A router coordinating a transition must not silently become the owner of Standby economic truth.

Where originating-user attribution matters, test the authenticated production-compatible attribution mechanism.

---

# Acceptance Tests

Acceptance tests prove the canonical externally observable Standby behavior.

They must use:

- real deployment paths;
- real configuration paths;
- real production transitions;
- real Uniswap v4 execution where specified;
- authoritative on-chain state.

Do not use privileged economic-state seeding.

Acceptance tests must prove both successful required behavior and required rejection behavior.

---

# Test Naming

Test names should communicate:

- behavior under test;
- relevant condition;
- expected result where useful.

Prefer names that make failures understandable from test output.

Avoid meaningless numbering or generic names such as `testWorks`.

Follow existing repository naming conventions once established.

---

# Test Execution

During implementation, run the narrowest relevant test set first.

Typical progression:

```bash
forge fmt --check
forge build
forge test --match-path <relevant-test-file> -vvv
```

Then expand verification according to the gate.

Before declaring a gate implementation-ready, run all tests required by that gate.

Do not suppress failing tests.

Do not weaken a test merely to make the suite pass.

Do not remove an assertion without understanding what requirement it was proving.
