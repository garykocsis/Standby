# Standby — Session 17

## F10 — Demo / Submission Readiness

We are continuing implementation of **Standby**, the ETHGlobal 2026 Uniswap v4 project.

This session corresponds to:

> **F10 — Demo / Submission Readiness**

F0 through F9 and GI are complete and independently gate-closed.

F10 is the final critical-path implementation slice.

The protocol realization itself is already complete.

Do **not** redesign or extend Standby economics.

Do **not** reopen prior implementation responsibilities merely to improve presentation.

The responsibility of F10 is to expose the already-G9-accepted realization as a deterministic, judge-comprehensible, reproducible demonstration and submission package without introducing new protocol semantics or independent economic truth.

---

# 1. Working Model

Use the established division of responsibility.

## ChatGPT

ChatGPT has already performed the normative F10 derivation and responsibility-boundary review.

The agreed F10 responsibility is:

> **F10 owns the deterministic, judge-facing exposure of the already-G9-accepted Standby realization, together with the minimum documentation and evidence necessary for another person to reproduce, understand, execute, and verify that demonstration.**

The agreed high-level G10 formulation is:

> **G10 = G9-Accepted Protocol + Deterministic Judge Execution + Authoritative Instrumentation + Canonical Economic Legibility + Reproducible Submission Package**

After implementation, ChatGPT will independently inspect the actual production code, scripts, frontend, documentation, tests, and evidence and determine whether G10 passes.

Claude does **not** close G10.

## Claude

Claude is the implementation agent.

Implement only the bounded F10 responsibility described in this prompt.

Do not independently redefine:

- F10;
- the canonical demo;
- protocol economics;
- O1/O2/O3 semantics;
- Supporting Capacity;
- Capacity Obligation;
- commitment semantics;
- eligibility semantics;
- exercise semantics;
- settlement/delivery semantics;
- the canonical fixture;
- G10.

If implementation reveals what appears to be a defect in previously accepted production semantics, **stop and report/classify it rather than silently repairing it under F10**.

---

# 2. Clean Rule

Preserve the repository ownership rule:

> **`CLAUDE.md` owns permanent operating behavior.**

> **`.claude/rules/*` owns permanent Solidity/testing conventions.**

> **This session prompt owns only F10-specific objective, scope, requirements, prohibitions, evidence, and completion boundaries.**

Do not duplicate permanent repository instructions into new documentation unless F10 genuinely requires new slice-specific information.

The goal remains:

> **bounded implementation discretion and implementation convergence.**

---

# 3. Authoritative Artifacts

Before editing, inspect the repository and reconstruct F10 against the actual current files.

At minimum read:

```text
CLAUDE.md
docs/implementation-plan.md
docs/demo-spec.md
docs/project-status.md
docs/uniswap-v4-realization.md
docs/testing-strategy.md
README.md
```

Also inspect the existing:

```text
src/
script/
test/
frontend/
docs/prompts/
```

as applicable.

Treat the frozen canonical artifacts as authoritative.

In particular:

- `demo-spec.md` defines the canonical demonstration;
- `implementation-plan.md` §20 defines the F10 realization;
- G9 acceptance evidence defines the protocol sequence that F10 must expose;
- `project-status.md` records current implementation state but does not redefine semantics.

Do not modify frozen canonical artifacts merely to make implementation easier.

---

# 4. State Entering F10

The implementation roadmap entering this session is:

```text
F0   — Foundation                                      COMPLETE
F1   — Deterministic Economic Fixture                  COMPLETE
F2   — Eligibility Registry                            COMPLETE
F3   — Hook Trust + PES Configuration                  COMPLETE
F4   — Commitment Storage / Bounded References         COMPLETE
F5   — Authoritative Derivation Kernel                 COMPLETE
F6A  — Preliminary O3 Enforcement                      COMPLETE
F7   — O1 Commitment Admission                         COMPLETE
F6B  — O3 Enforcement with Authentic O > 0             COMPLETE
F8A  — O2 Authorization / Hook-Owned Causal Context    COMPLETE
F8B  — O2 Exact-Output Execution / Execution Evidence  COMPLETE
F8C  — O2 Input Settlement / Beneficiary Delivery      COMPLETE
F8D  — O2 Causal Finalization                          COMPLETE

GI   — Full Stateful Invariant Verification            COMPLETE
G-I  — PASS / CLOSED

F9   — Canonical Acceptance                            COMPLETE
G9   — PASS / CLOSED

F10  — Demo / Submission Readiness                     CURRENT
F9T  — Public Testnet Deployment                       OPTIONAL / OFF CRITICAL PATH
```

The Standby production realization is complete.

GI established stateful safety properties.

F9 established fresh deterministic construction, production-path fidelity, sequential reproduction, authoritative observation, and deterministic reproducibility.

F10 must **consume** that accepted realization.

It must not recreate F9 as a new protocol acceptance slice.

---

# 5. F10 Objective

Implement the minimum deterministic judge-facing realization necessary to expose the already-accepted Standby economic proof.

F10 should produce:

```text
accepted protocol
        +
deterministic local demo environment
        +
minimal authoritative frontend instrumentation
        +
A1–A4 judge interaction
        +
non-browser DemoActions fallback
        +
judge-facing README/setup documentation
        +
final reproducibility/evidence checks
```

without introducing:

```text
new economics
new protocol authorities
new lifecycle behavior
new protocol state
new fixture semantics
new production economic derivations
new demo-only economic contracts
new economic backdoors
```

The implementation should converge rather than expand.

---

# 6. Canonical Economic Story

Do not invent a new demo scenario.

Expose the already-G9-accepted sequence over one live pool and the same A1-created commitment.

## Bootstrap

Canonical pre-state:

```text
S = 80,000 MockUSDC
O = 0
no commitment
```

The economic interpretation is:

> shared executable capacity exists before any Standby obligation is admitted.

## A1 — Admit Commitment

Use the real production O1 path.

```text
q = 50,000 MockUSDC
```

Expected authoritative result:

```text
S = 80,000
O = 50,000
Remaining = 50,000
PASS / ADMITTED
```

Admission must not consume or segregate the corresponding MockUSDC backing resource.

## A2 — Compatible Ordinary Swap

Execute the canonical ordinary protected exact-output swap:

```text
15,000 MockUSDC
```

Expected authoritative result:

```text
S = 65,000
O = 50,000
Remaining = 50,000
PASS
```

This is the central positive-permissiveness / non-reservation proof.

The same shared capacity remains available for compatible ordinary use.

## A3 — Attempt Destructive Ordinary Swap

From:

```text
current S = 65,000
O = 50,000
Remaining = 50,000
```

attempt:

```text
ordinary protected exact-output = 20,000 MockUSDC
```

Expected prospective derivation:

```text
S′ = 45,000
O  = 50,000

45,000 < 50,000
```

Expected result:

```text
REJECT
```

After revert, authoritative state must remain:

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

The prospective `45,000` state must never be presented as authoritative state.

## A4 — Full Exercise

Using the **same A1-created commitment**, exercise:

```text
q = 50,000 MockUSDC
```

through the actual ExerciseRouter / O2 path.

Expected authoritative result:

```text
S = 15,000
O = 0
Remaining = 0
Beneficiary receives exactly +50,000 MockUSDC
PASS / FULFILLED
```

Do not add another required live action.

Optional post-fulfillment activity is supplementary and is not necessary for G10.

---

# 7. Demo Execution Environment

The canonical judged environment remains deterministic local **Anvil**.

It must use the actual:

```text
PoolManager
StandbyHook
EligibilityRegistry
ExerciseRouter
trusted ordinary-swap perimeter
MockUSTB
MockUSDC
```

Only the demo economic currencies are mocks.

Do not replace Uniswap v4 execution with a mock AMM.

Do not make F10 depend on a public testnet.

F9T remains:

```text
OPTIONAL
OFF CRITICAL PATH
NOT A G10 DEPENDENCY
```

---

# 8. Frontend Responsibility

Use the lightweight React/Vite/Tailwind organization already assigned in the implementation plan.

The intended structure is approximately:

```text
frontend/
├── public/
├── src/
│   ├── components/
│   │   ├── StandbyStatePanel.jsx
│   │   ├── CommitmentPanel.jsx
│   │   ├── ActionPanel.jsx
│   │   └── ActionResult.jsx
│   ├── hooks/
│   │   ├── useStandbyState.js
│   │   ├── useCommitment.js
│   │   └── useDemoActions.js
│   ├── lib/
│   │   ├── contracts.js
│   │   ├── rpc.js
│   │   ├── format.js
│   │   └── errors.js
│   ├── App.jsx
│   ├── index.css
│   └── main.jsx
├── index.html
├── package.json
├── package-lock.json
├── tailwind.config.js
├── postcss.config.js
├── vite.config.js
└── README.md
```

This layout is guidance, not permission to invent unnecessary abstractions.

Prefer **viem** for continuity with the established frontend direction unless the actual repository or dependency state exposes a concrete reason not to.

Do not create a full production dApp.

Do not recreate RangeGuard economic semantics.

Do not implement simulated economic lifecycle data such as `demoData`.

> **The deterministic Anvil chain is the demo state.**

---

# 9. Authoritative Observation Boundary

The UI is instrumentation, not a second state machine.

Prominently expose the proof-minimal state:

```text
Supporting Capacity S
Aggregate Capacity Obligation O
Remaining Entitlement
Beneficiary MockUSDC balance
latest transaction outcome / reason
S >= O
```

Current pool tick/price may appear as secondary explanatory evidence.

Relevant transaction quantity should be shown where required to understand the action being demonstrated.

Authoritative provenance must remain:

```text
S
→ Hook authoritative read / Hook-owned production derivation

O
→ Hook authoritative read

Remaining
→ authoritative commitment record

Beneficiary balance
→ MockUSDC balanceOf

tick / pool price
→ PoolManager authoritative state

transaction result
→ actual receipt / revert / decoded custom error

A3 prospective S′
→ production read-only preview reusing the same authoritative
   derivation used by enforcement
```

The frontend must **not** independently calculate:

```text
S
O
Remaining
prospective S′
backing validity
fulfillment
authorization
```

The frontend may format authoritative values and display relationships such as:

```text
S >= O
```

but the values and protocol decision remain authoritative elsewhere.

---

# 10. Read / Render Rule

After every transaction:

```text
submit
→ wait for receipt or revert
→ re-read authoritative on-chain state
→ render
```

Do not optimistically mutate economic state.

Do not preserve stale frontend economic state as truth.

A full browser reload must reconstruct current economic state from chain alone.

This should be explicitly verified.

---

# 11. Main Judged Interaction

The main judged UI exposes exactly four canonical actions:

```text
1. Admit Commitment
2. Compatible Ordinary Swap
3. Attempt Capacity-Destroying Ordinary Swap
4. Exercise Commitment
```

Bootstrap/configuration operations are **not** main judged buttons.

Keep these as script/environment responsibilities:

```text
deployment
pool initialization
PES configuration/activation
eligibility administration
actor funding
approvals
controlled liquidity provisioning
environment reset
```

The interface may guide the canonical A1 → A2 → A3 → A4 order for presentation.

Do not encode that order as protocol authority.

In particular:

> A3 is demo choreography, not a prerequisite for A4.

---

# 12. Demo Scripts

Inspect existing scripts first and reuse/refine accepted F9 infrastructure rather than creating parallel deployment or bootstrap systems.

## `DeployDemoEnvironment.s.sol`

The canonical environment composition should reuse the existing canonical deployment responsibilities and perform the required dependency-safe construction.

Conceptually:

```text
1. resolve/deploy v4 infrastructure
2. deploy deterministic ordered mock currencies
3. deploy EligibilityRegistry
4. deploy ActorAwareTestRouter / trusted demo swap periphery
5. deploy StandbyHook through canonical DeployStandbyHook path
6. deploy ExerciseRouter with required Hook/PoolManager binding
7. expose/return the address manifest required by bootstrap/frontend
```

Do not duplicate Hook mining or deployment logic.

## `BootstrapStandby.s.sol`

Bootstrap through real accepted paths:

```text
1. initialize pool
2. configure and activate PES
3. seed mutable demo eligibility
4. establish funding and approvals
5. add canonical controlled liquidity
6. perform final authoritative checks
```

Stop at exactly:

```text
S = 80,000
O = 0
no commitment
```

Do **not** pre-create the demo commitment.

A1 is part of the live proof.

## `DemoActions.s.sol`

Provide real production calls for:

```text
A1
A2
A3
A4
```

only.

This is the deterministic fallback/debugging path if browser presentation fails.

It must reproduce the same real protocol transitions rather than simulate UI results.

---

# 13. A3 Presentation Requirement

A3 is the most important presentation boundary.

Clearly distinguish three evidence classes:

### Authoritative current state

```text
S = 65,000
O = 50,000
Remaining = 50,000
```

### Proposed transaction

```text
ordinary protected exact-output request = 20,000 MockUSDC
```

### Prospective derived state

```text
S′ = 45,000
O = 50,000
45,000 < 50,000
```

Then show the actual result:

```text
REJECTED BY STANDBY BACKING REQUIREMENT
```

and after the revert re-read:

```text
authoritative S = 65,000
O = 50,000
Remaining = 50,000
```

Decode the specific Standby backing-capacity custom error.

The rejection must not appear to be caused by:

```text
eligibility failure
insufficient balance
allowance failure
slippage
service-domain violation
unrelated v4 failure
```

If prospective `S′` is displayed, obtain it only through an existing or already-authorized production read-only preview that reuses the canonical F5/H3 derivation.

Do not independently derive `S′` in JavaScript/TypeScript.

Do not add new production economic logic merely to decorate the frontend.

If the required production observation surface is unexpectedly absent, report the issue before changing production semantics.

---

# 14. A4 Presentation Requirement

Before exercise, capture/display the authoritative Beneficiary MockUSDC balance.

Execute A4 through the real ExerciseRouter/O2 production path.

After successful execution, re-read and show:

```text
S = 15,000
O = 0
Remaining = 0
Beneficiary balance increase = exactly 50,000 MockUSDC
```

Do not infer fulfillment merely because a button returned success.

A claim that the commitment was fulfilled must be supported by:

```text
successful transaction
+
authoritative post-state
+
authoritative Beneficiary token balance evidence
```

The demo must not suggest ExerciseRouter custody of the protected output.

---

# 15. Reset Boundary

Canonical reset is environmental:

```text
restart/reset Anvil
→ redeploy
→ bootstrap
```

Do not introduce any production function resembling:

```text
resetStandby()
clearCommitments()
restoreCapacity()
setSupportingCapacity()
forceFulfillment()
demoReset()
```

or any equivalent test/demo economic backdoor.

The ability to reset a demonstration must never become protocol authority.

---

# 16. Production-Code Boundary

Presume:

> **F10 requires no production-semantic changes.**

Do not change the semantics of:

```text
StandbyHook
ExerciseRouter
EligibilityRegistry
O1
O2
O3
Supporting Capacity
Capacity Obligation
commitment lifecycle
eligibility
settlement
Beneficiary delivery
causal finalization
```

for presentation convenience.

If implementation appears to require a semantic production change:

1. stop that change;
2. identify exactly why the demo cannot proceed;
3. classify the issue as:
   - F10 presentation/instrumentation,
   - F9 deployment/bootstrap,
   - or a defect belonging to an earlier production slice;

4. report it explicitly.

Do not silently reopen or repair a previously closed gate.

Ordinary compilation/interface plumbing that does not alter protocol semantics must still be justified against this boundary.

---

# 17. Responsibility-Leakage Prohibitions

F10 must not introduce:

```text
a second canonical economic fixture
a second Hook deployment procedure
a second bootstrap path
frontend-owned S
frontend-owned O
frontend-owned Remaining
independent frontend S′ math
mock fulfillment
mock AMM execution
simplified demo versions of O1/O2/O3
a demo-specific Standby economic contract
production reset/backdoor functions
new protocol guarantees
new lifecycle stages
new authority relationships
public-testnet dependency
```

Every F10 change should satisfy this test:

> **Does this change expose, execute, explain, reproduce, or package already-accepted Standby behavior?**

If not, it probably does not belong in F10.

---

# 18. README / Submission Documentation

F10 owns the judge-facing README synthesis.

The root README should become the public entry point into Standby and answer, concisely:

```text
What problem does Standby solve?
What is the core economic idea?
What does “protect capacity, not reserve liquidity” mean?
What components make up the realization?
What does the canonical demo prove?
What are A1–A4?
How do I run the deterministic demo?
What state should I expect at each stage?
What does Standby not claim?
Where are the deeper canonical documents?
```

Preserve prominently:

> **Standby doesn't reserve liquidity. It protects capacity.**

And the project descriptor:

> **Protocol-enforced future execution capacity from shared AMM liquidity.**

The README should explain the economic coordination problem and solution sufficiently for a judge without reproducing the entire frozen derivation.

Link/navigate into the deeper canonical documentation rather than duplicating it.

Include accurate deterministic setup/run instructions based on the implementation that actually exists.

Do not document commands or workflows that have not been verified.

If useful, maintain a focused `frontend/README.md` for frontend-specific setup, but avoid needless duplication with the root README.

---

# 19. Claim Boundary

The demo may establish that, for the demonstrated Standby configuration:

- a future exact-output execution commitment can be admitted against qualifying shared AMM capacity;
- commitment admission does not require segregating the committed output;
- compatible ordinary use remains possible while the commitment is outstanding;
- a transition that would make the admitted obligation insufficiently backed cannot become authoritative;
- the commitment can later be exercised through actual AMM execution;
- the authoritative Beneficiary receives the exact protected output;
- fulfillment reduces Remaining Entitlement and releases the corresponding obligation.

Do not imply the demonstration proves that Standby:

- guarantees arbitrary future execution under all conditions;
- guarantees fixed input price;
- eliminates AMM price impact/slippage;
- protects every liquidity transition;
- operates independently of eligibility, validity, authority, or service-domain requirements;
- supports every token;
- integrates with or is endorsed by a specific Treasury-token issuer;
- is already production-ready institutional settlement infrastructure.

Keep README and UI language inside this claim boundary.

---

# 20. Required Verification

Run and preserve evidence appropriate to every changed surface.

At minimum, verify:

## Solidity / repository regression

```text
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

Existing closed gates must remain passing.

F10 does not need to recreate GI or G9 from scratch as new gates, but no F10 change may regress their accepted behavior.

## Demo script verification

Prove from a fresh deterministic Anvil environment:

```text
deploy
→ bootstrap
→ exact pre-A1 state
→ A1
→ A2
→ A3 rejection
→ unchanged authoritative post-A3 state
→ A4
→ exact final state
```

`DemoActions.s.sol` must reproduce A1–A4 without relying on the frontend.

## Frontend verification

Run the actual frontend dependency/build/lint/test commands supported by the repository.

At minimum verify:

- clean install from lockfile where appropriate;
- production frontend build succeeds;
- configured RPC/contract references resolve correctly;
- authoritative state can be read;
- all four actions reach the intended production paths;
- custom A3 backing rejection is decoded;
- post-action state is re-read;
- reload reconstructs truth from chain;
- no simulated economic store is required.

Do not invent a frontend command in documentation without executing it.

## Deterministic judged-demo verification

Perform at least one complete human/demo-facing run from a fresh environment using the intended judged workflow.

Verify exact sequence:

```text
Bootstrap   80k / 0
A1          80k / 50k / 50k
A2          65k / 50k / 50k
A3 preview  45k / 50k → REJECT
Post-A3     65k / 50k / 50k
A4          15k / 0 / 0
Beneficiary +50k MockUSDC
```

Use the same pool and same A1 commitment through A4.

---

# 21. Final Gas and Coverage Evidence

After F10 implementation is stable and the full suite passes, refresh final engineering evidence unless the repository's actual tooling makes the commands materially inappropriate.

### Gas

Produce/refesh the repository's established gas snapshot/report.

Treat it as final engineering/submission evidence.

Do not optimize production code merely to improve the number.

If the result materially regresses from the accepted post-F8D baseline, investigate and report why.

### Coverage

Produce/refesh the repository's established coverage report.

The current entering-F10 baseline is:

```text
Lines       99.42%
Statements  98.52%
Branches    92.31%
Functions   100%
```

Coverage is diagnostic evidence, not protocol semantics.

Do not change production logic merely to chase percentage improvements.

If coverage materially regresses, identify whether F10 introduced untested code or whether the difference is tooling/report-scope related.

Record the final actual results in the session log.

Do **not** redefine G10 so that a particular coverage percentage or gas number becomes a normative protocol gate.

---

# 22. G10 — Demo / Submission Readiness Gate

Implementation is ready for independent review only when evidence supports all of the following.

## G10-A — Canonical environment

1. demo uses the canonical Hook deployment path;
2. deterministic Anvil environment uses actual PoolManager and actual Standby contracts;
3. bootstrap reaches exactly the canonical pre-A1 state;
4. no privileged demo economic state is injected.

## G10-B — Authoritative instrumentation

5. main UI exposes the four canonical actions;
6. S/O/Remaining/Beneficiary balance/tick or price are authoritative reads;
7. UI does not independently derive or persist S or O;
8. browser reload reconstructs current economic truth from chain;
9. post-transaction display occurs from authoritative rereads rather than optimistic economic mutation.

## G10-C — A1 / A2 proof

10. A1 displays:

```text
80k / 50k / 50k
```

11. A2 displays:

```text
65k / 50k / 50k
```

12. the presentation makes clear that compatible shared use remained possible while the obligation was outstanding.

## G10-D — A3 rejection proof

13. A3 production preview yields prospective `S′ = 45k`;
14. prospective 45k is clearly distinguished from current authoritative 65k;
15. `45k < 50k` is legible;
16. the actual transaction rejects with the specific Standby backing-capacity reason;
17. rejection is not attributable to an unrelated failure;
18. post-revert authoritative state remains:

```text
65k / 50k / 50k
```

## G10-E — A4 fulfillment proof

19. A4 uses the real ExerciseRouter/O2 path;
20. the same commitment created in A1 is exercised;
21. Beneficiary MockUSDC balance increases exactly 50,000;
22. final state is:

```text
S = 15k
O = 0
Remaining = 0
```

23. fulfillment claims come from actual transaction + authoritative state/balance evidence.

## G10-F — Reproducibility / fallback

24. reset is environmental;
25. no production demo-reset/backdoor exists;
26. `DemoActions.s.sol` reproduces the same A1–A4 protocol behavior without the frontend;
27. a fresh deterministic run reproduces the complete sequence;
28. README/setup instructions accurately reproduce the implemented workflow.

## G10-G — Submission fidelity

29. README clearly communicates the problem, solution, architecture, demo flow, claim boundary, and canonical documentation;
30. judge-facing wording remains within frozen Standby claims;
31. gas/coverage evidence, if refreshed, is reported as engineering evidence rather than semantics;
32. no public-testnet deployment is required for G10.

## G10-H — Responsibility leakage

33. no new protocol semantics are introduced;
34. no second economic source of truth exists;
35. no demo-only production economic backdoor exists;
36. no F0–F9/GI responsibility has been silently reimplemented or altered;
37. no prior gate requires reopening.

The high-level completion criterion is:

> **A judge can reproduce and directly observe the G9-accepted Standby economic proof through a deterministic human-readable interface while every demonstrated economic fact remains attributable to authoritative production state, production derivation, token state, or actual transaction evidence.**

Do not declare G10 PASS yourself.

Report completion evidence for independent review.

---

# 23. Implementation Discipline

Work from the repository as it actually exists.

Before editing:

1. inspect existing F9 scripts and acceptance paths;
2. inspect current frontend state, if any;
3. inspect actual production read interfaces and ABIs;
4. identify what F10 already has versus what is missing;
5. prefer composition/reuse over duplication.

Keep changes minimal.

Do not refactor accepted production code for aesthetic reasons.

Do not perform unrelated cleanup.

Do not add speculative extensibility.

Do not expand this into a production-grade frontend.

Do not make F9T part of this session.

If an implementation detail has multiple equivalent realizations, choose the simplest solution consistent with the frozen artifacts and existing repository conventions.

---

# 24. Session Log

Maintain:

```text
docs/prompts/session-17-log.md
```

as the Claude implementation chronology.

Record materially relevant:

- repository state entering F10;
- implementation decisions;
- files added/changed;
- commands executed;
- frontend setup decisions;
- deployment/bootstrap reuse decisions;
- authoritative read mappings;
- A3 error/preview handling;
- A4 Beneficiary evidence handling;
- README/documentation work;
- deterministic demo runs;
- failures encountered and corrections;
- regression evidence;
- gas evidence;
- coverage evidence;
- any suspected prior-slice issue;
- final evidence supplied for independent review.

Do not use the log to redefine canonical semantics.

---

# 25. Project Status Boundary

Do **not** independently mark F10 complete or G10 closed in `docs/project-status.md`.

ChatGPT will independently review the implementation and evidence first.

After an explicit independent PASS determination, a separate bounded status-only update will be authorized.

Until then, preserve F10 as the active/unclosed slice.

---

# 26. Retrospective Evidence

Do **not** generate the ChatGPT retrospective yourself.

After implementation and independent review, ChatGPT will generate:

```text
docs/prompts/retrospective/session-17-chatgpt-record.md
```

That record will preserve the substantive user ↔ ChatGPT reasoning for F10.

Your complementary implementation chronology remains:

```text
docs/prompts/session-17-log.md
```

Keep these responsibilities distinct.

---

# 27. Required Completion Report

When implementation is complete, do not merely say that F10 is done.

Return a structured implementation report containing:

## A. Changed Files

List every materially changed/added file and its F10 responsibility.

## B. Demo Architecture

Explain how:

```text
Anvil
deployment
bootstrap
frontend
DemoActions
production contracts
```

compose without creating a second economic truth.

## C. Authoritative Read Map

For every displayed economic fact identify the exact production/on-chain source.

## D. A1–A4 Evidence

Report actual observed results for:

```text
Bootstrap
A1
A2
A3 prospective
A3 rejection
post-A3 authoritative state
A4
Beneficiary balance delta
```

## E. Deterministic Reproduction

Give the exact verified command/run sequence from fresh environment to completed demo.

## F. Frontend Evidence

Report install/build/test/lint/runtime results actually executed.

## G. Solidity Regression Evidence

Report:

```text
forge fmt --check
forge build --sizes
forge test
FOUNDRY_PROFILE=ci forge test
```

with actual outcomes.

## H. Gas / Coverage Evidence

Report the final refreshed values and compare materially against the entering-F10 baselines.

## I. README / Submission Documentation

Summarize exactly what judge-facing documentation changed.

## J. Responsibility-Leakage Review

Explicitly state whether F10 introduced:

```text
production semantic changes
new economic derivations
new authoritative state
demo-only economic backdoors
duplicate deployment/bootstrap paths
public-testnet dependencies
```

## K. Prior-Gate Assessment

State whether anything discovered during F10 appears to require reopening F0–F9 or GI.

## L. G10 Evidence Matrix

Map the implementation evidence against every G10 requirement above.

Do not self-certify PASS.

End by presenting the implementation and evidence as:

> **READY FOR INDEPENDENT G10 REVIEW**

only if all required implementation work and verification have completed successfully.

---

# 28. Completion Boundary

The F10 completion boundary is:

```text
canonical deterministic demo environment implemented

canonical deployment/bootstrap path verified

exact pre-A1 state reproduced

lightweight authoritative frontend implemented

four canonical judged actions implemented

authoritative economic observation implemented

A3 prospective-state presentation and specific backing rejection verified

post-A3 authoritative state verified unchanged

real ExerciseRouter A4 path exposed

exact Beneficiary +50k MockUSDC delivery observed

final 15k / 0 / 0 authoritative state observed

browser reload reconstructs economic truth from chain

environmental reset workflow verified

DemoActions A1–A4 fallback path verified

judge-facing README / setup / demo documentation completed

deterministic fresh-environment end-to-end demo executed

frontend verification complete

Solidity repository regression verification complete

final gas evidence refreshed and reviewed

final coverage evidence refreshed and reviewed

G10 evidence collected

responsibility-leakage review complete

prior-gate assessment complete

session-17-log.md updated

completion report produced
```

Stop at the F10 completion boundary.

Do not begin F9T.

Do not mark F10 complete or G10 PASS in `docs/project-status.md`.

Do not modify previously accepted production semantics to satisfy demo or presentation needs.

Present the completed implementation and evidence for independent G10 review.

---

# 29. Begin

Inspect the actual repository state against the bounded F10 responsibility, then implement the minimum changes required to reach the F10 completion boundary.

Do not broaden the slice or close G10.
