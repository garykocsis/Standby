---
globs: ["src/**/*.sol", "script/**/*.sol", "test/**/*.sol"]
---

# Solidity Development Standards

Use Solidity `0.8.26` unless the validated toolchain baseline is explicitly changed.

Use Solidity 0.8.x safety guarantees.

Prefer custom errors over revert strings.

Use explicit visibility on all functions and state variables.

Use CEI — Checks, Effects, Interactions — where applicable.

Use storage pointers carefully and explicitly.

Minimize storage writes whenever possible.

Avoid unnecessary memory allocation.

Prefer `uint256` unless smaller packing provides meaningful storage or protocol benefit.

Use NatSpec comments for all external and public functions.

Keep functions focused and single-responsibility.

Avoid duplicated accounting logic.

Prefix immutable variables with `i_`.

Constants must use uppercase names.

Correctness and invariant preservation take priority over gas optimization.

Optimize only after correctness is established and only when the optimization does not obscure authoritative semantics.

---

# Solidity Source Ordering

Use the following top-level source order:

1. pragma statements;
2. import statements;
3. events;
4. errors;
5. interfaces;
6. libraries;
7. contracts.

Inside each contract, library, or interface use:

1. type declarations;
2. state variables;
3. events;
4. errors;
5. modifiers;
6. functions.

Place functions in this order:

1. constructor;
2. fallback;
3. receive;
4. external;
5. public;
6. internal;
7. private.

Do not add empty sections merely to satisfy the ordering convention.

---

# Solidity Section Headers

Use the following section-header style:

```solidity
/*//////////////////////////////////////////////////////////////
                             EVENTS
//////////////////////////////////////////////////////////////*/
```

Within contracts, indent the header consistently with the surrounding source:

```solidity
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
```

Use meaningful section names.

---

# Function Design

Prefer focused functions with a single authoritative responsibility.

Avoid large functions that combine unrelated:

- authorization;
- derivation;
- persistence;
- settlement;
- external interaction;
- verification.

However, do not split functions merely to reduce line count.

Function boundaries should clarify economic or architectural responsibilities.

Avoid duplicated checks when one authoritative check can safely serve the required transition.

---

# Storage Design

Storage must follow the canonical state model.

Before adding a new storage variable, determine:

1. what authoritative fact it represents;
2. why that fact must persist across transactions;
3. whether it is already derivable from existing authoritative facts;
4. what synchronization invariant the new storage would create;
5. whether the canonical state model authorizes it.

If those questions cannot be answered, do not add the storage variable.

---

# Bounded Execution

Avoid unbounded iteration in production paths.

Where the canonical design defines bounded reference sets or bounded scans, preserve those bounds.

Do not replace bounded authoritative structures with unbounded convenience structures.

Do not assume a test-sized collection will remain small in production unless the protocol explicitly bounds it.

---

# Error Handling

Use custom errors for Standby-owned semantic rejection conditions.

Errors should communicate the actual violated requirement rather than implementation trivia.

Do not use revert strings in new Standby production contracts unless required by an external inherited interface or dependency.

Do not convert dependency behavior merely to normalize error style.

---

# Events

Events are observational evidence, not authoritative economic state.

Emit events where they materially support:

- transition reconstruction;
- debugging;
- integration;
- demo instrumentation;
- external observation.

Do not rely on an event as the only authoritative record of a fact that the protocol must later enforce on-chain.

Do not emit redundant events solely for verbosity.

---

# Formatting and Linting

Run:

```bash
forge fmt
```

when modifying Solidity.

Before reporting completion, verify formatting with:

```bash
forge fmt --check
```

Respect the repository lint configuration.

Do not perform unrelated formatting churn across untouched files.
