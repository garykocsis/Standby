# Standby — Session 16

## F9 — Canonical Acceptance

You are implementing the next authorized Standby acceptance slice:

> **F9 — Canonical Acceptance**

The preceding implementation and verification slices are complete and independently gate-closed:

```text
F0   — Foundation                                      COMPLETE
F1   — Deterministic Economic Fixture                  COMPLETE
F2   — Eligibility Registry                            COMPLETE
F3   — StandbyHook Trust + PES Configuration           COMPLETE
F4   — Commitment Storage / Bounded References         COMPLETE
F5   — Authoritative Derivation Kernel                 COMPLETE
F6A  — Preliminary O3 Enforcement                      COMPLETE
F7   — O1 Commitment Admission                         COMPLETE
F6B  — O3 Bounded Enforcement                          COMPLETE
F8A  — Exercise Authorization                          COMPLETE
F8B  — Protected PoolManager Execution                 COMPLETE
F8C  — Authoritative Settlement / Direct Delivery      COMPLETE
F8D  — O2 Causal Finalization / Remaining Reduction    COMPLETE
GI   — Full Stateful Invariant Verification            COMPLETE

F9   — Canonical Acceptance                            CURRENT
F10  — Demo / Submission Readiness                     NOT AUTHORIZED
F9T  — Public Testnet Deployment                       OFF CRITICAL PATH
```

The last closed gate is:

> **G-I — PASS / CLOSED**

F9 is the only authorized current slice.

No production semantic slice is intentionally incomplete before F9.

---

# 1. Clean Rule / Authority Boundary

Apply the established ownership rule:

> **`CLAUDE.md` owns permanent operating behavior.**

> **`.claude/rules/*` owns permanent Solidity/testing conventions.**

> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Where permanent operating, Solidity, testing, formatting, or repository-verification behavior is already defined in those artifacts, follow it rather than restating or modifying it here.

This session prompt owns only the F9-specific requirements below.

---

# 2. Authoritative Sources

Before changing acceptance tests, deployment/bootstrap orchestration, or production code, inspect the relevant frozen artifacts:

```text
docs/context.md
docs/economic-agreement.md
docs/mechanism.md
docs/spec.md
docs/architecture.md
docs/state-machine.md
docs/invariants.md
docs/testing-strategy.md
docs/uniswap-v4-realization.md
docs/demo-spec.md
docs/implementation-plan.md
```

Inspect:

```text
docs/project-status.md
```

for current status only.

Also inspect the current production implementation, deployment/bootstrap infrastructure, and completed F0–GI test suite.

At minimum inspect the existing implementation surfaces relevant to:

```text
HelperConfig
PoolManager deployment
DeployStandbyHook.s.sol
StandbyHook
EligibilityRegistry
ExerciseRouter
fixture-token deployment
pool initialization
PES configuration
liquidity bootstrap
O1 commitment admission
ordinary protected exact-output swaps
O3 backing enforcement
O2 exercise
Supporting Capacity derivation
Capacity Obligation derivation
commitment Remaining
Beneficiary delivery
```

Inspect existing deployment and fixture infrastructure before creating F9-specific orchestration.

If a material discrepancy exists between the frozen artifacts and current implementation, surface it rather than silently redefining Standby semantics.

---

# 3. F9 Objective

Implement the exact accepted F9 responsibility:

> **F9 proves that the completed and GI-verified Standby production realization can be constructed from a completely fresh deterministic environment and reproduce the exact frozen Bootstrap → A1 → A2 → A3 rejection → A4 economic history through real deployment, bootstrap, PoolManager, StandbyHook, ordinary-swap, O1, and ExerciseRouter production paths without privileged economic fixture state.**

F9 owns:

```text
fresh construction
+
production-path composition
+
canonical acceptance evidence
```

F9 does not define new Standby protocol behavior.

---

# 4. F9 Acceptance Boundary

F9 must answer:

> **Can the completed Standby realization, starting from a completely fresh deterministic environment, reproduce the exact frozen canonical economic history through production deployment, bootstrap, O1, ordinary swap, O3 rejection, and O2 exercise paths?**

F9 proves:

```text
canonical realizability
```

from:

```text
fresh deterministic construction
```

It does not re-prove arbitrary-sequence invariant safety.

GI owns that responsibility.

It does not build presentation or frontend instrumentation.

F10 owns that responsibility.

It does not require public-network deployment.

F9T owns that optional credibility evidence.

---

# 5. Required F9 Acceptance Architecture

The expected primary acceptance footprint is:

```text
test/acceptance/
├── BootstrapFidelity.t.sol
└── CanonicalStandbyFlow.t.sol
```

Exact additional helper filenames are not normative.

The required property is:

> **acceptance evidence constructed through real production deployment/bootstrap/behavioral paths**

rather than a prepared economic fixture that merely begins at the expected state.

`CanonicalStandbyFlow.t.sol` must not inherit:

```text
BaseBackedStandbyTest
```

or any equivalent fixture that pre-creates backed economic state.

---

# 6. Fresh Production Construction Path

The canonical F9 construction path is:

```text
HelperConfig
→ real PoolManager
→ DeployStandbyHook.s.sol
→ fixture contracts
→ BootstrapStandby.s.sol
→ A1
→ A2
→ A3
→ A4
```

Preserve this construction boundary.

Acceptance must establish the canonical system from fresh deployment and bootstrap operations.

Do not reconstruct the final bootstrap state directly inside the acceptance test.

---

# 7. Script / Test Reuse Boundary

Acceptance must reuse the same deterministic deployment/bootstrap implementation intended for operational and demo use.

The required architecture is:

```text
deterministic callable deployment/bootstrap functions
                    ↓
          reusable by Foundry tests
                    +
          reusable by operational wrappers
```

`run()` / broadcast concerns remain thin operational wrappers.

Do not:

```text
shell out to forge script from tests
use persisted broadcast artifacts as economic state
duplicate deployment semantics inside acceptance tests
duplicate bootstrap semantics inside acceptance tests
```

Where existing script structure does not expose the already-authorized deterministic deployment/bootstrap path to tests, narrowly refactor orchestration so the same implementation can be called directly.

Do not move Standby economic semantics into deployment scripts.

---

# 8. Production-Path Acceptance Environment

F9 evidence must exercise the production realization.

Use the real components required by the canonical architecture, including as applicable:

```text
PoolManager
StandbyHook
EligibilityRegistry
ExerciseRouter
production O1 path
production ordinary-swap path
production O2 path
canonical mock currencies
canonical deployment/configuration path
canonical liquidity bootstrap
```

Do not use a Hook harness as authoritative F9 evidence.

Do not directly seed or mutate economically authoritative state such as:

```text
Supporting Capacity
Capacity Obligation
Original Entitlement
Remaining Entitlement
commitment identity
bounded references
fulfillment state
O2 causal state
```

The fresh system may be initialized only through legitimate production deployment, configuration, bootstrap, and behavioral paths.

The governing frozen rule is:

> **Acceptance Fidelity = Real Construction Path + No Privileged Economic State**

---

# 9. GB — Bootstrap Fidelity

Fresh deployment/bootstrap must reach exactly the canonical pre-A1 state.

Canonical fixture:

```text
MockUSTB = currency0
MockUSDC = currency1

protected direction = zeroForOne

initial tick = 0

tickQ = -240
tickO = +240

LP tickLower = -300
LP tickUpper = +300

tick spacing = 10
fee = 500 pips

L = 6,707,079,990,254

S = 80,000.000000 MockUSDC
O = 0

no commitment
```

Also verify before A1:

```text
StandbyHook permission bits are correct
StandbyHook immutable PoolManager binding is correct
StandbyHook protected-output balance = 0
ExerciseRouter protected-output balance = 0
```

Invalid GB evidence includes:

```text
direct Hook storage mutation
vm.store
harness seeding
test-only economic setters
pre-created commitments
inherited prepared economic state
```

---

# 10. One Uninterrupted Canonical History

The primary F9 acceptance claim must execute:

```text
Bootstrap
→ A1
→ A2
→ A3 rejection
→ A4
```

as one uninterrupted sequential history.

A suitable primary test shape is:

```solidity
test_CanonicalStandbyFlow()
```

The sequence must use:

```text
the same deployed system
the same live pool
the same canonical configuration
the same A1-created commitment through A4
```

Do not replace the primary acceptance claim with independent tests that reconstruct fresh state separately for A1, A2, A3, and A4.

Focused supporting tests are permitted where useful.

They do not substitute for the uninterrupted canonical acceptance history.

---

# 11. A1 — Admit

Through the real production O1 path, establish:

```text
q = 50,000.000000 MockUSDC
```

Capture the actual returned:

```text
commitmentId
```

That identity must be used later by A4.

After successful A1, verify:

```text
S = 80,000
O = 50,000

Original = 50,000
Remaining = 50,000
```

Also verify:

```text
Beneficiary protected-output balance unchanged
pool state unchanged by O1
StandbyHook protected-output custody = 0
ExerciseRouter protected-output custody = 0
```

Do not synthesize or pre-create the commitment identity.

---

# 12. A2 — Compatible Ordinary Swap

Execute a real ordinary protected-direction exact-output swap for:

```text
15,000.000000 MockUSDC
```

Expected result:

```text
PASS

S = 65,000
O = 50,000
Remaining = 50,000
```

The ordinary swap must not fulfill or reduce the admitted commitment.

This stage demonstrates:

> **The admitted Standby obligation protects capacity without reserving that same shared liquidity from compatible ordinary use.**

Do not simulate this transition through direct pool-state mutation.

---

# 13. A3 — Destructive Attempt

Starting from:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

attempt a real ordinary protected-direction exact-output swap for:

```text
20,000.000000 MockUSDC
```

The authoritative prospective transition should imply:

```text
prospective S = 45,000

45,000 < 50,000
```

The operation must reject with the specific production Standby insufficient-supporting-capacity error.

A generic `expectRevert()` is insufficient evidence where the specific production error can be asserted.

After rejection, verify:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

The prospective:

```text
S = 45,000
```

must never become authoritative.

Verify the relevant state required to demonstrate rejection atomicity.

Do not create a test-owned alternative O3 derivation that becomes protocol truth.

An independent calculation may be used only as a verification oracle.

---

# 14. A4 — Full Exercise

Using the exact commitment established during A1, exercise:

```text
50,000.000000 MockUSDC
```

through the real production:

```text
ExerciseRouter
```

path with sufficiently generous `maxInput`.

The operation must traverse the completed:

```text
F8A
→ F8B
→ F8C
→ F8D
```

realization.

Verify:

```text
actual PoolManager input debt settled

PoolManager directly delivers
50,000 MockUSDC
to the authoritative Beneficiary

Beneficiary protected-output balance
increases exactly 50,000

Remaining = 0

O = 0

S = 15,000

StandbyHook protected-output custody = 0

ExerciseRouter protected-output custody = 0
```

Remaining must become zero only through successful causal finalization of the actual exercise.

Do not mock:

```text
execution
settlement
delivery
fulfillment
finalization
```

---

# 15. Authoritative Observation Boundary

Treat the production realization as authoritative.

Relevant F9 observations include, as applicable:

## PoolManager

```text
pool state
price / tick
liquidity
actual swap effects
actual exercise effects
```

## StandbyHook

```text
configured PES facts
Supporting Capacity
Capacity Obligation
commitment facts
Original Entitlement
Remaining Entitlement
```

## ExerciseRouter / O2

```text
actual exercise success
actual input settlement
actual delivery path
```

## Token State

```text
Beneficiary balances
StandbyHook balances
ExerciseRouter balances
```

Expected canonical constants such as:

```text
80,000
65,000
50,000
45,000 prospective
15,000
```

are test assertions.

They must not become a parallel authoritative Standby state machine.

Independent calculations may be used only as verification oracles.

Do not create test-owned authoritative substitutes for production truth.

---

# 16. F9 vs Existing Verification Layers

Preserve the following responsibility distinctions.

## Integration tests

Answer:

> Do individual production interactions compose correctly?

## GI

Answers:

> Does adversarial stateful composition preserve frozen safety and derivation properties across the required reachable state space?

## F9

Answers:

> Can a completely fresh deterministic production realization reproduce the exact frozen canonical Standby economic history?

## F10

Will answer:

> Can the accepted canonical history be presented clearly and reliably through the final judged demo/submission instrumentation?

## F9T

Provides optional:

```text
public/testnet credibility evidence
```

F9 must consume prior integration and GI evidence rather than reproduce those verification campaigns.

---

# 17. Production-Code Boundary

F9 is presumed to require no new Standby protocol semantics.

Do not proactively modify:

```text
StandbyHook economic semantics
ExerciseRouter economic semantics
EligibilityRegistry semantics
O1 semantics
O2 semantics
O3 semantics
Supporting Capacity derivation
Capacity Obligation derivation
commitment lifecycle semantics
fulfillment semantics
causal finalization semantics
bounded-reference semantics
```

merely to make F9 acceptance pass.

A narrow deployment/bootstrap orchestration change is permitted only where necessary to expose or reuse already-authorized construction semantics.

If F9 exposes a genuine production defect:

1. preserve the failing acceptance sequence;
2. identify the violated frozen requirement;
3. trace the defect to its existing normative implementation owner;
4. record the finding in the Session 16 log;
5. report the affected previous slice/gate;
6. do not invent an F9-owned semantic repair.

If a production correction affects behavior previously verified by GI, explicitly identify the resulting GI revalidation requirement.

Do not silently patch production semantics while constructing acceptance evidence.

---

# 18. Responsibility Leakage / Out of Scope

F9 owns:

```text
fresh construction
production-path composition
canonical acceptance evidence
deterministic canonical reproduction
```

It does not absorb prior responsibilities.

## F4 remains owner of

```text
commitment identity
bounded-reference representation
historical commitment persistence
```

## F5 remains owner of

```text
authoritative derivation kernel
Supporting Capacity derivation
Capacity Obligation derivation
prospective derivation
```

## F6B remains owner of

```text
O3 backing enforcement with authentic O > 0
```

## F7 remains owner of

```text
O1 commitment admission
```

## F8A remains owner of

```text
O2 authorization
exercise authority
Hook-owned causal authorization context
```

## F8B remains owner of

```text
protected exact-output PoolManager execution
execution evidence
```

## F8C remains owner of

```text
actual input settlement
authenticated exerciser payment
direct Beneficiary delivery
PoolManager delta closure
```

## F8D remains owner of

```text
actual final backing
exact Remaining reduction
causal finalization
durable fulfillment
```

## GI remains owner of

```text
full stateful invariant verification
adversarial temporal/compositional safety
verification-domain closure
```

Also out of scope:

```text
F10 demo/submission readiness
frontend work
F9T public testnet deployment
gas optimization
coverage maximization
unrelated refactoring
new protocol features
new generalized verification campaigns
```

---

# 19. Deterministic Fresh-System Boundary

F9 acceptance must be reproducible from a clean deterministic Foundry environment.

The acceptance result must not depend on:

```text
test execution order
state persisted by another test
persisted broadcast artifacts
manually deployed local contracts
previously created commitments
privileged Hook state
prepared backed fixture state
external environmental state outside the explicit construction path
```

Repeated clean execution must reproduce the same canonical economic result.

Determinism is part of G9 evidence.

---

# 20. G9 — Canonical Acceptance Gate

Claude may provide an advisory assessment but does not close G9.

G9 requires the fresh deterministic production realization to reproduce exactly:

```text
Bootstrap

S = 80,000
O = 0
Remaining = —
Result = READY
```

then:

```text
A1 — Admit

S = 80,000
O = 50,000
Remaining = 50,000
Result = PASS
```

then:

```text
A2 — Compatible Ordinary Swap

S = 65,000
O = 50,000
Remaining = 50,000
Result = PASS
```

then:

```text
A3 — Destructive Attempt

prospective S = 45,000
O = 50,000
Remaining = 50,000
Result = REJECT
```

then after rejection:

```text
S = 65,000
O = 50,000
Remaining = 50,000
Result = UNCHANGED
```

then:

```text
A4 — Exercise

S = 15,000
O = 0
Remaining = 0
Result = PASS
```

G9 additionally requires evidence that:

```text
fresh deterministic construction was used
real deployment/bootstrap paths were used
the same live pool was used throughout
the A1-created commitment was used through A4
production interfaces performed all authoritative actions
production state/effects supplied authoritative observations
A3 rejected for the specific backing reason
A3 rejection was atomic
Beneficiary received exactly 50,000 protected output
Remaining reached zero through causal finalization
StandbyHook retained zero protected-output custody
ExerciseRouter retained zero protected-output custody
no privileged economic state contributed to acceptance
no mocked fulfillment contributed to acceptance
deployment/bootstrap implementation was reused rather than duplicated
the canonical sequence is deterministically reproducible
```

---

# 21. F9-Specific Verification Evidence

Use the repository-standard verification already required by:

```text
CLAUDE.md
.claude/rules/*
```

Do not duplicate or reinterpret those permanent verification requirements here.

For F9 specifically, execute the acceptance evidence required to establish:

```text
GB — Bootstrap Fidelity
G9 — Canonical Acceptance
```

Report the actual F9 acceptance commands and results.

The F9 evidence must include:

```text
fresh bootstrap fidelity
one uninterrupted A1 → A2 → A3 rejection → A4 canonical flow
specific A3 rejection evidence
authoritative post-state observations
exact A4 Beneficiary delivery
final custody observations
deterministic reproduction
```

Do not claim G9 evidence solely because the repository-standard suite passes.

Do not rerun gas or coverage merely because F9 begins.

The post-F8D gas snapshot remains the current production gas baseline unless production changes.

The post-GI coverage report remains the current coverage baseline unless production changes.

If F9 exposes a production correction, report the impact on those baselines and any required revalidation.

---

# 22. F9 File Boundary

Expected F9 changes should primarily involve:

```text
test/acceptance/*
```

and narrowly necessary deployment/bootstrap orchestration files required to expose the already-authorized production construction path.

Expected acceptance files include:

```text
test/acceptance/BootstrapFidelity.t.sol
test/acceptance/CanonicalStandbyFlow.t.sol
```

Existing deployment/bootstrap files may be modified only where narrowly necessary for script/test reuse.

Maintain:

```text
docs/prompts/session-16-log.md
```

Do not update:

```text
docs/project-status.md
```

during F9 implementation.

Do not modify frozen canonical artifacts.

Do not create or modify:

```text
docs/prompts/retrospective/session-16-chatgpt-record.md
```

during Claude implementation.

Production protocol files should remain unchanged unless F9 exposes a genuine implementation defect already governed by frozen semantics.

---

# 23. Acceptance Failure / Counterexample Reporting

If the canonical flow fails, preserve the failing evidence.

Report:

```text
failing stage
authoritative pre-state
attempted production action
expected result
actual result
revert/error where applicable
authoritative post-state
suspected normative owner
```

First classify the failure where possible as:

```text
acceptance-test defect
fixture/bootstrap defect
deployment-path defect
canonical-story mismatch
production implementation defect
frozen-artifact discrepancy
non-deterministic environmental assumption
```

Preserve the distinction between:

> **the canonical Standby story failing**

and:

> **the F9 acceptance implementation encoding that story incorrectly.**

Do not weaken canonical expected values or acceptance assertions merely to match current implementation behavior.

If unresolved, report G9 as not yet proven.

---

# 24. Session Evidence / Post-Project Retrospective

Maintain:

```text
docs/prompts/session-16-log.md
```

as the Claude implementation-process record for F9.

Preserve materially relevant:

```text
deployment/bootstrap architecture inspected
script/test reuse decisions
acceptance fixture decisions
files changed
GB implementation evidence
A1 implementation evidence
A2 implementation evidence
A3 implementation/rejection evidence
A4 implementation evidence
authoritative observation decisions
determinism decisions
test failures and corrections
canonical-story discrepancies
production defects discovered
production changes, if any
verification commands and results
advisory G9 assessment
```

This log is non-normative.

Do not update:

```text
docs/project-status.md
```

during F9 implementation.

The status-only update occurs only after independent review and explicit G9 closure.

A separate retrospective record will later be produced:

```text
docs/prompts/retrospective/session-16-chatgpt-record.md
```

Do not create or modify that file during F9 implementation.

---

# 25. Completion Report

When F9 implementation is complete, report:

1. files inspected;
2. files changed;
3. fresh deployment/bootstrap architecture used;
4. any script/test reuse refactoring;
5. production components exercised;
6. GB bootstrap evidence;
7. A1 evidence;
8. captured commitment identity;
9. A2 evidence;
10. A3 prospective derivation and exact rejection evidence;
11. A3 post-revert atomicity evidence;
12. A4 execution evidence;
13. exact Beneficiary delivery evidence;
14. final `S`, `O`, and `Remaining`;
15. final Hook/Router custody evidence;
16. deterministic reproduction evidence;
17. F9-specific acceptance commands and results;
18. repository verification results required by permanent instructions;
19. any production defect discovered;
20. any production code changed;
21. any previous gate requiring reopening/revalidation;
22. advisory G9 assessment;
23. known limitations, deviations, or discrepancies;
24. scope check;
25. recommended next step;
26. prompt audit.

For G9 use:

```text
PASS
FAIL
NOT YET PROVEN
```

with concise supporting evidence.

Do not infer G9 PASS merely because:

```text
forge test succeeds
```

The actual canonical acceptance evidence must discharge G9.

Do not declare G9 closed.

---

# 26. Prompt Audit

Before completion, confirm that implementation remained within this session prompt's ownership boundary.

Report whether F9 introduced any:

```text
new protocol semantics
new permanent operating rules
new permanent Solidity conventions
new permanent testing conventions
F10 work
F9T work
unrelated refactoring
gas optimization
coverage-driven semantic changes
```

The expected answer is:

```text
none
```

If not, identify each deviation explicitly.

---

# 27. Accepted F9 Semantic Statement

Before editing, preserve this accepted responsibility:

> **F9 does not introduce new Standby semantics. It proves that the GI-verified completed production realization can be constructed from a fresh deterministic environment and can reproduce the exact frozen Bootstrap → A1 → A2 → A3 rejection → A4 economic history through production deployment, bootstrap, execution, observation, and finalization paths without privileged economic fixture state.**

The intended acceptance shape is:

```text
Fresh Production Construction
        +
Production-Path Fidelity
        +
One Uninterrupted Canonical History
        +
Authoritative Economic Observation
        +
Deterministic Reproduction
```

Equivalently:

> **Canonical Acceptance = Fresh Construction + Production-Path Fidelity + Sequential Economic Reproduction + Authoritative Observation + Deterministic Reproducibility**

subject to:

> **Acceptance Fidelity = Real Construction Path + No Privileged Economic State**

Implement that responsibility and nothing broader.

---

# 28. Completion Boundary

The F9 completion boundary is:

```text
fresh deterministic production construction implemented
GB bootstrap fidelity implemented and evidenced
one uninterrupted canonical flow implemented
A1 real commitment admission evidenced
A2 compatible ordinary swap evidenced
A3 destructive attempt specifically rejected
A3 rejection atomicity evidenced
A4 same-commitment full exercise evidenced
exact Beneficiary delivery evidenced
final S = 15,000 evidenced
final O = 0 evidenced
final Remaining = 0 evidenced
Hook / ExerciseRouter custody integrity evidenced
authoritative observation boundary preserved
no privileged economic state contributed to evidence
deterministic reproduction established
F9-specific acceptance evidence collected
repository verification complete
session-16-log.md updated
completion report produced
```

Stop at the F9 completion boundary.

Do not begin F10.

Do not begin F9T.

Do not update `docs/project-status.md`.

Do not declare G9 closed.

Return the implementation and evidence for independent review.
