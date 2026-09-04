# Standby — Project Setup

## Overview

This document captures the initial setup and foundational engineering decisions for the Standby project, including repository creation, development environment configuration, dependency discipline, project structure, and the transition into implementation.

It serves as both:

- a record of how the project was initialized; and
- a reference point for how the development environment and repository structure evolve during implementation.

The goal is to establish a clean, reproducible, production-grade foundation suitable for building and verifying a Uniswap v4 protocol.

---

## Project Intent

Standby is an execution-layer liquidity-assurance protocol built on Uniswap v4.

**Tagline:**

> **Execution capacity when you need it.**

**Technical descriptor:**

> **Protocol-enforced future execution capacity from shared AMM liquidity.**

Standby allows future execution commitments to be backed by qualifying executable capacity from mutable shared AMM liquidity without requiring the committed output asset to be fully pre-positioned or placed into a dedicated Standby reserve.

The central economic relationship is:

> **Supporting Capacity S ≥ Aggregate Capacity Obligation O**

Standby does not reserve liquidity. It protects capacity.

The project is being developed as an ETHGlobal 2026 submission and as a portfolio-grade protocol-engineering reference implementation.

Development emphasizes:

- economic specification before implementation;
- explicit protocol architecture and authority boundaries;
- Uniswap v4 integration;
- unit, fuzz, invariant, integration, and acceptance testing;
- deterministic deployment and demo infrastructure;
- verification-gated implementation;
- security and auditability;
- clear traceability from protocol semantics to implementation.

---

# Repository Creation

The repository is created using the GitHub CLI to maintain a terminal-first development workflow:

```bash
gh repo create Standby --public --clone
cd Standby
```

## Rationale

Using the CLI:

- mirrors normal engineering workflows;
- establishes immediate local-to-remote synchronization;
- avoids unnecessary repository boilerplate;
- provides a clean starting point for the implementation history.

The repository is created without a generated README, license, or application boilerplate.

---

# Git and GitHub Configuration

The project uses SSH-based authentication for GitHub repository access.

The expected repository remote is:

```text
git@github.com:garykocsis/Standby.git
```

The GitHub CLI is configured to prefer SSH:

```bash
gh config set git_protocol ssh
```

Verify with:

```bash
gh config get git_protocol
git remote -v
```

## Why SSH

SSH authentication is preferred to:

- avoid repeated credential prompts;
- provide a seamless terminal-first workflow;
- support normal Git tooling;
- align with the development workflow used for other protocol projects.

When multiple GitHub identities or SSH keys exist on the development machine, verify that the intended identity is being used before beginning implementation.

---

# Foundry Initialization

Foundry is the primary Solidity development framework.

Initialize the project with:

```bash
forge init --no-git --force
```

The `--no-git` option prevents Foundry from creating another Git repository inside the existing Standby repository.

The default Foundry example files are removed:

```text
src/Counter.sol
test/Counter.t.sol
script/Counter.s.sol
```

The generated generic Foundry README is also removed so that the eventual repository README can describe Standby specifically.

macOS `.DS_Store` files should not be committed.

---

# Development Framework

Standby uses Foundry for Solidity development, testing, scripting, deployment, and local execution.

## Why Foundry

Foundry provides:

- fast Solidity compilation;
- unit testing;
- fuzz testing;
- invariant testing;
- integration testing;
- Solidity-native deployment scripts;
- Anvil for deterministic local execution;
- strong support for protocol-level development.

The canonical local development, integration, acceptance, and judged-demo environment for Standby is:

> **Anvil / Foundry**

The canonical implementation uses the real Uniswap v4 execution stack. Only the economic currencies used by the deterministic demo fixture are mocks.

---

# Initial Clean Baseline

Before any Standby-specific implementation is introduced, the repository establishes a clean Foundry baseline.

The baseline contains:

```text
.gitignore
foundry.toml
lib/forge-std
```

The generated Counter implementation, test, and script are removed.

No Standby protocol contracts or economic behavior are introduced in this baseline.

---

# First Commit

The first repository commit intentionally represents the clean Foundry development baseline.

Commit:

```text
chore: initialize Standby Foundry project
```

This establishes a clear historical boundary between:

```text
generic development environment
        ↓
Standby repository foundation
        ↓
Standby implementation
```

The first commit includes:

- Foundry initialization;
- `forge-std`;
- `foundry.toml`;
- `.gitignore`;
- removal of generated Foundry example code.

It does not contain Standby economic or protocol implementation.

---

# `.gitignore`

The project `.gitignore` should initially include:

```gitignore
# Foundry
cache/
out/

# Ignores development broadcast logs
!/broadcast
/broadcast/*/31337/
/broadcast/**/dry-run/

# Environment
.env

# Coverage reports (HTML report too large to commit; .gas-snapshot IS committed)
coverage/
lcov.info

# macOS
.DS_Store

# Editors
.vscode/


# Frontend
frontend/node_modules/
frontend/dist/
```

Additional generated files may be added as tooling is introduced.

---

# Project Structure

Standby uses a modular repository structure derived from the frozen implementation plan.

The planned repository organization is:

```text
Standby/
├── docs/
│
├── frontend/                       # introduced during F10
│
├── src/
│   ├── StandbyHook.sol
│   ├── EligibilityRegistry.sol
│   ├── ExerciseRouter.sol
│   │
│   ├── interfaces/
│   │
│   ├── libraries/
│   │
│   ├── types/
│   │
│   ├── demo/
│   │
│   └── mocks/
│
├── script/
│   ├── DeployStandbyHook.s.sol
│   ├── DeployDemoEnvironment.s.sol
│   ├── BootstrapStandby.s.sol
│   ├── DemoActions.s.sol
│   │
│   └── helpers/
│
├── test/
│   ├── harness/
│   ├── shared/
│   ├── unit/
│   ├── fuzz/
│   ├── integration/
│   ├── periphery/
│   ├── invariant/
│   └── acceptance/
│
├── lib/
│
├── .gitignore
├── foundry.toml
└── README.md                        # Standby README added later
```

## Progressive Materialization

The tree above represents the planned project architecture.

It does **not** mean that every directory or file must be created immediately.

Directories and files are introduced progressively when their corresponding implementation responsibilities become active.

For example:

- `docs/` is introduced during repository setup;
- Solidity source directories appear as implementation slices require them;
- test directories appear as their corresponding evidence classes are introduced;
- `frontend/` is introduced during F10 — Demo Instrumentation;
- `.github/workflows/` may be introduced later when CI is deliberately established.

Git does not track empty directories, so there is no need to add `.gitkeep` files simply to reproduce the eventual directory tree.

Repository structure should grow naturally with implementation.

---

# Documentation

Project documentation is stored under:

```text
docs/
```

The initial setup record is:

```text
docs/setup.md
```

The frozen Standby canonical and implementation-handoff artifacts may also be maintained in the repository as the authoritative implementation inputs.

Their organization should preserve the distinction between:

- canonical protocol semantics;
- Uniswap v4 realization;
- demo specification;
- implementation planning;
- implementation records.

Implementation must not silently redefine frozen semantics contained in those artifacts.

---

# Dependency Management

Foundry dependencies are managed through:

```text
lib/
```

The clean initial baseline contains:

```text
lib/forge-std
```

## Uniswap v4 Dependencies

Standby uses the real Uniswap v4 execution stack.

The implementation will require pinned, mutually compatible versions or commits of the relevant dependencies, including:

- Uniswap `v4-core`;
- Uniswap `v4-periphery` where required;
- Permit2 where required by the selected periphery or settlement path;
- compatible Solidity compiler configuration;
- compatible Foundry/EVM configuration.

The exact versions and installation commands are deliberately **not copied from RangeGuard**.

They are selected and pinned during:

> **F0 — v4 Infrastructure / Deployment Foundation**

This ensures Standby is implemented against the actual APIs exposed by its pinned dependency baseline rather than assumptions inherited from an older project.

## API-Drift Discipline

Do not copy API signatures from RangeGuard or older Uniswap v4 examples when the pinned Standby dependencies expose different interfaces.

PoolManager settlement, hook callbacks, liquidity modification, routing, PositionManager behavior, and periphery assumptions must be verified against the source actually compiled by Standby.

Dependency upgrades after a verification gate has closed are not considered routine refactors.

If a dependency changes, every verification gate whose evidence depends upon that dependency or API behavior must be rerun.

---

# Compiler and EVM Configuration

The initial generated `foundry.toml` is intentionally minimal:

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
```

The final Solidity compiler and EVM configuration should be selected together with the pinned Uniswap v4 dependency baseline during F0.

Do not prematurely select compiler settings based only on RangeGuard or an older Uniswap v4 configuration.

The resulting configuration should be explicit and reproducible once the F0 dependency baseline has been established.

---

# Implementation Discipline

Standby implementation follows the frozen implementation plan rather than evolving opportunistically from the repository structure.

The working cadence is:

> **Validated State → Next Blocker → Implementation → Verification Gate → Next Slice**

A downstream implementation responsibility may rely on an upstream responsibility only after the upstream responsibility has produced the verification evidence required to establish its semantic contract.

Therefore:

> **Dependency Readiness = Implementation + Required Verification Evidence**

Compilation alone does not close an implementation slice.

Implementation convenience must not redefine frozen Standby:

- economics;
- specification semantics;
- architecture;
- state semantics;
- invariants;
- testing obligations.

If implementation exposes a problem, first classify it as:

1. an ordinary implementation problem;
2. a dependency/API problem;
3. an implementation-plan omission; or
4. a genuine contradiction in frozen semantics.

Only the fourth category justifies reopening a frozen semantic decision.

---

# Implementation Sequence

The frozen implementation ladder is:

```text
F0   v4 Infrastructure / Deployment Foundation
F1   Deterministic Economic Fixture
F2   EligibilityRegistry
F3   StandbyHook Trust + PES Configuration
F4   Commitment Storage / Bounded Enforcement References
F5   Authoritative Derivation Kernel
F6A  Preliminary O3 Enforcement with O = 0
F7   O1 Commitment Admission
F6B  O3 Enforcement with Authentic O > 0
F8A  O2 Authorization / Hook-Owned Causal Context
F8B  O2 Exact-Output Execution / Execution Evidence
F8C  O2 Authoritative Settlement / Direct Beneficiary Delivery
F8D  O2 Causal Finalization / Remaining Reduction
GI   Full Stateful Invariant Gate
F9   Canonical Acceptance
F10  Demo Instrumentation
F9T  Public Testnet / Production-Periphery Evidence
```

F9T is supplementary and is not part of the canonical critical path.

---

# F0 — v4 Infrastructure / Deployment Foundation

The first implementation slice is:

> **F0 — v4 Infrastructure / Deployment Foundation**

F0 establishes the reproducible Uniswap v4 execution foundation before Standby economic behavior is introduced.

Its responsibilities include:

- repository and Foundry configuration;
- pinned Uniswap v4 dependencies;
- infrastructure/network configuration;
- real Uniswap v4 `PoolManager`;
- official v4-core test infrastructure required for local execution;
- canonical StandbyHook deployment foundation;
- `BaseV4Test`;
- `V4Infrastructure.t.sol`.

F0 does **not** implement:

- Supporting Capacity;
- Aggregate Capacity Obligation;
- commitments;
- O1;
- O2;
- O3 backing enforcement;
- demo UI;
- public testnet deployment.

---

# G0 — Vanilla v4 Infrastructure Gate

Before Standby economic behavior is introduced, a fresh deterministic local environment must prove:

1. a real Uniswap v4 `PoolManager` can be deployed or resolved;
2. a vanilla v4 pool can be initialized;
3. vanilla liquidity can be added;
4. a vanilla swap can execute successfully; and
5. the canonical StandbyHook deployment path can produce a permission-valid Hook address.

G0 must close before F1 depends upon F0.

---

# Repository Checkpoints

The early repository history is intentionally divided into clear checkpoints.

## Commit 1 — Clean Foundry Baseline

**Complete.**

Establishes:

- repository creation;
- Foundry initialization;
- `forge-std`;
- `.gitignore`;
- `foundry.toml`;
- removal of generated example code.

No Standby implementation exists at this checkpoint.

## Commit 2 — Standby Repository Foundation

Establishes the Standby-specific repository foundation before F0 implementation.

Expected contents include:

- `docs/setup.md`;
- justified repository organization;
- completed Git/SSH housekeeping;
- other non-economic repository setup deliberately required before implementation.

Commit 2 should still contain **no Standby economic implementation**.

## F0 and Later Commits

Subsequent commits should correspond as clearly as practical to implementation slices and verification milestones.

The goal is not necessarily one commit per file, test, or implementation slice.

The goal is a repository history in which important implementation and verification boundaries remain understandable.

---

# Setup Progress

The repository setup sequence is:

1. **Create and clone the Standby repository — COMPLETE**
2. **Initialize the clean Foundry project — COMPLETE**
3. **Remove default Foundry example contracts and tests — COMPLETE**
4. **Establish initial Standby repository structure and documentation — IN PROGRESS**
5. Verify final Git and SSH configuration.
6. Inspect, select, and pin the required Uniswap v4 dependency baseline.
7. Begin F0 — v4 Infrastructure / Deployment Foundation.
8. Close G0 — Vanilla v4 Infrastructure before proceeding to F1.

---

# Next Immediate Action

The current repository is at the clean post-Commit-1 baseline.

The next action is to establish the Standby repository foundation:

1. create `docs/`;
2. add this document as `docs/setup.md`;
3. establish only the currently justified repository directories;
4. verify Git and SSH configuration;
5. inspect the resulting repository state;
6. create **Commit 2 — Standby Repository Foundation**.

After Commit 2, generic repository setup is complete.

The next work begins the actual implementation plan with:

> **F0 — v4 Infrastructure / Deployment Foundation**

The first F0 technical decision is to inspect, select, and pin the mutually compatible Uniswap v4 dependency baseline before implementing Standby-specific protocol behavior.
