# Session 17 --- ChatGPT Reasoning Record

**Slice:** F10 --- Demo / Submission Readiness\
**Gate:** G10 --- Demo / Submission Readiness Gate\
**Final independent determination:** **F10 COMPLETE --- G10 PASS /
CLOSED**\
**Status:** Non-normative curated retrospective evidence\
**Purpose:** Preserve the substantive user ↔ ChatGPT reasoning
associated with F10 for the later Standby / Protocol Discovery
Methodology retrospective.

------------------------------------------------------------------------

## 1. Retrospective Scope

This record is not a protocol specification, implementation plan, gate
definition, or replacement for Claude's Session 17 implementation log.

It preserves the reasoning that materially shaped F10:

-   the user's questions, challenges, concerns, and proposed decisions;
-   ChatGPT's derivations, recommendations, and independent-review
    conclusions;
-   the F10 responsibility boundary;
-   the distinction between demo readiness, submission readiness, F9
    acceptance, and optional F9T;
-   authoritative-instrumentation and interaction boundaries;
-   deterministic demo and reproduction decisions;
-   judge-facing presentation decisions;
-   G10 derivation and independent review;
-   corrections discovered after implementation;
-   gas, coverage, README, diagram, and repository-hygiene reasoning;
-   process and methodology observations that should survive beyond the
    hackathon.

The complementary implementation chronology, commands, changed files,
and execution evidence remain in `docs/prompts/session-17-log.md`.

------------------------------------------------------------------------

## 2. Entering F10

F10 began only after the implementation and verification ladder through
F9 had been completed and independently gate-closed.

The relevant entering state was:

-   F0 through F8D complete;
-   GI --- Full Stateful Invariant Verification complete and G-I closed;
-   F9 --- Canonical Acceptance complete and G9 closed;
-   production protocol behavior already accepted;
-   deterministic deployment/bootstrap already accepted;
-   the canonical A1 → A2 → A3 → A4 economic history already accepted;
-   no production-semantic work was expected from F10;
-   F9T --- Public Testnet Deployment remained optional and off the
    critical path.

This entering state was important because F10 was not allowed to become
another protocol-design or acceptance slice merely because it needed to
expose the protocol to a judge.

------------------------------------------------------------------------

## 3. Exact F10 Responsibility

The central derivation was:

> **F10 owns deterministic judge-facing exposure of the
> already-G9-accepted realization, plus the minimum
> documentation/evidence necessary for another person to reproduce,
> understand, execute, and verify it.**

That responsibility was decomposed into four areas:

1.  **Demo execution** --- expose the already accepted canonical actions
    through usable judge-facing paths.
2.  **Authoritative instrumentation** --- show protocol state without
    creating a second economic source of truth.
3.  **Judge comprehension** --- make the economic meaning of A1--A4
    legible.
4.  **Submission/reproduction handoff** --- make the repository runnable
    and understandable by someone other than the implementer.

The key negative boundary was equally important:

> **F10 should require zero production-semantic changes.**

If F10 appeared to require a production semantic change, the issue had
to be classified rather than silently repaired:

-   legitimate F10 instrumentation;
-   an F9 deployment/bootstrap problem;
-   or a defect in an earlier production responsibility requiring
    explicit reopening.

This preserved the verification-gated dependency structure instead of
allowing the demo layer to mutate already-accepted protocol semantics.

------------------------------------------------------------------------

## 4. F10 Versus F9 and F9T

A recurring concern was whether F10 was proving the protocol again.

The conclusion was no.

F9 owned canonical acceptance of the realization. F10 consumed that
accepted behavior and made it reproducible and legible. The canonical
demo therefore needed to execute the same production paths and economic
sequence, not create an alternative "demo implementation."

F9T was kept deliberately separate.

F9T --- Public Testnet Deployment --- was classified as:

> **OPTIONAL / OFF CRITICAL PATH**

It was not:

-   a dependency of F10;
-   a predicate of G10;
-   the next required implementation slice;
-   a submission prerequisite;
-   or a reason to delay deterministic local completion.

Late in the session, after F10 was closed, the user asked what remained
and whether F9T could still be completed after the demo/video and
submission package were prepared. The recommended order was:

> **Retrospective → merge F10 → GitHub QA → demo/video + submission
> package → F9T if time remains → final submission QA**

The important strategic conclusion was that F9T can add public
credibility evidence, but the accepted deterministic Anvil realization
remains canonical. Optional public-network infrastructure should not be
allowed to destabilize a completed submission.

------------------------------------------------------------------------

## 5. Canonical Judge-Facing Economic Story

The demo was bounded to the already accepted four-action history.

### Bootstrap

-   `S = 80,000 MockUSDC`
-   `O = 0`
-   no commitment

### A1 --- Admit commitment

Admit `q = 50,000`.

Result:

-   `S = 80,000`
-   `O = 50,000`
-   `Remaining = 50,000`

The important judge-facing fact is that the obligation is created
without segregating a dedicated 50,000-unit reserve.

### A2 --- Compatible ordinary use

Execute a protected-direction ordinary exact-output swap for `15,000`.

Result:

-   `S = 65,000`
-   `O = 50,000`
-   `Remaining = 50,000`

This is the core "shared liquidity remains usable" demonstration.

### A3 --- Capacity-destroying ordinary use

Attempt another ordinary exact-output swap for `20,000`.

Production prospective derivation gives:

-   current `S = 65,000`
-   `O = 50,000`
-   prospective `S′ = 45,000`
-   therefore `S′ < O`

The transition must be rejected specifically by the Standby backing
requirement.

After revert:

-   `S = 65,000`
-   `O = 50,000`
-   `Remaining = 50,000`

The prospective state must never be presented as authoritative state.

### A4 --- Fulfill the commitment

Exercise the same 50,000 commitment through the real O2 path.

Observed result:

-   Beneficiary receives exactly `50,000 MockUSDC`;
-   `Remaining = 0`;
-   `O = 0`;
-   final `S = 15,000`.

No fifth live action was required.

This four-step sequence became both the implementation target and the
judge-facing narrative.

------------------------------------------------------------------------

## 6. Authoritative Instrumentation Boundary

The UI was explicitly treated as **instrumentation**, not as a dApp
maintaining economic truth.

The baseline authoritative fields were:

-   Supporting Capacity `S`;
-   Aggregate Obligation `O`;
-   Remaining Entitlement;
-   Beneficiary protected-output balance;
-   latest action result/reason;
-   the backing relation `S ≥ O`;
-   current tick/price as secondary evidence.

The crucial distinction derived during F10 was between four evidence
classes:

1.  **authoritative economic state**;
2.  **proposed transaction facts**;
3.  **prospective production-derived state**;
4.  **transaction/revert evidence**.

This distinction later became important during independent review.

Authoritative economic state had to come from the chain.

Proposed transaction facts --- such as the requested A3 output or A4
input bound --- could come from canonical demo configuration, but had to
be presented as proposals rather than state.

Prospective `S′` had to come from the production read-only preview
reusing the F5/H3 derivation. It could not be independently recomputed
in JavaScript.

After every transaction, the interface had to re-read authoritative
state.

A browser reload had to reconstruct authoritative economic truth from
chain state rather than client persistence.

No optimistic economic mutation was permitted.

------------------------------------------------------------------------

## 7. Interaction Boundary

The main judge-facing interface was deliberately restricted to exactly
four protocol actions:

1.  Admit Commitment;
2.  Compatible Swap;
3.  Attempt Capacity-Destroying Ordinary Swap;
4.  Exercise.

Deployment, configuration, eligibility, funding, liquidity provision,
and reset were environment/bootstrap operations rather than main judge
actions.

Reset was kept strictly environmental:

> stop Anvil → restart Anvil → redeploy → bootstrap.

No production reset, restoration, or demo-seeding backdoor was
permitted.

A command-line `DemoActions.s.sol` path was retained as a
fallback/debug/reproduction path, but it had to reproduce the same
A1--A4 production transitions rather than create a second economic
realization.

------------------------------------------------------------------------

## 8. Browser Access and Verification Decision

During implementation, interactive browser automation from Claude was
proposed as a possible verification mechanism.

The user declined making personal-browser access part of the
implementation responsibility.

The resulting reasoning was that F10 should be verifiable from
repository artifacts and the normal development environment. This led to
a headless frontend verification path using the frontend's own protocol
modules.

That was a useful boundary decision:

-   Claude could implement and mechanically verify the frontend
    integration;
-   the user could perform the actual human browser click-through;
-   neither needed to pretend the other had performed evidence they had
    not actually observed.

The later human browser verification therefore became complementary
evidence rather than a reconstructed claim.

------------------------------------------------------------------------

## 9. Human Browser Verification

The user performed the complete judge-facing sequence against the
running deterministic environment.

### Pre-A1

Observed:

-   `S = 80,000`
-   `O = 0`
-   no outstanding Remaining Entitlement
-   Beneficiary balance at the expected baseline
-   backing relation passing

### A1

Observed:

-   `S = 80,000`
-   `O = 50,000`
-   `Remaining = 50,000`

### A2

Observed:

-   `S = 65,000`
-   `O = 50,000`
-   `Remaining = 50,000`

### Reload after A2

This was an especially important test.

After browser reload, the interface reconstructed:

-   authoritative post-A2 state;
-   Commitment #1;
-   original entitlement;
-   remaining entitlement;
-   Beneficiary;
-   Exercise Authority;
-   `Exercisable From`;
-   `Valid Until`.

The action panel correctly had no session-local action result after
reload while the authoritative state remained visible.

This demonstrated the intended separation between chain truth and
transient UI session state.

### A3

The browser displayed:

-   the real rejected transaction;
-   before-state `S = 65,000`, `O = 50,000`;
-   proposed output `20,000`;
-   production preview `S′ = 45,000`;
-   comparison `45,000 < 50,000`;
-   exact error:
    `StandbyHook__InsufficientProspectiveBacking(45000000000, 50000000000)`;
-   post-revert authoritative state still `65,000 / 50,000 / 50,000`.

The display also made clear that prospective `S′` was not authoritative
state.

### A4

Observed:

-   Beneficiary MockUSDC balance before: `0`;
-   after: `50,000`;
-   delivered: exactly `50,000`;
-   final `S = 15,000`;
-   final `O = 0`;
-   final `Remaining = 0`.

This completed the assembled browser evidence for the same accepted
economic history.

------------------------------------------------------------------------

## 10. Validity-Window Question

During browser review, the user noticed the commitment displayed:

-   `EXERCISABLE FROM 2026-09-10 04:25:01`
-   `VALID UNTIL 2026-10-10 04:25:01`

and initially suspected both times might already be past.

The issue was resolved by carefully reading the dates: the lower bound
was September 10 and the upper bound October 10.

The current demo execution was therefore inside the valid interval.

Existing temporal tests also established the intended boundary behavior,
including opening at `exercisableFrom` and closing at `validUntil`.

No protocol defect or demo correction was required.

This was a useful example of not turning an observation into a code
change before first checking whether the apparent inconsistency actually
existed.

------------------------------------------------------------------------

## 11. G10 Derivation

G10 was derived as:

> **G10 = G9-Accepted Protocol + Deterministic Judge Execution +
> Authoritative Instrumentation + Canonical Economic Legibility +
> Reproducible Submission Package**

The gate required, in substance:

-   fresh deterministic local deployment/bootstrap through accepted
    production paths;
-   exact canonical pre-A1 state;
-   judge execution/observation of A1--A4;
-   authoritative economic values sourced from authoritative state;
-   proposed transaction facts clearly distinguished;
-   A3 production prospective preview and specific backing rejection;
-   unchanged authoritative state after A3;
-   A4 through the real ExerciseRouter/O2 path;
-   exact +50,000 protected output delivered to the Beneficiary;
-   final `15,000 / 0 / 0` state;
-   reload reconstruction from chain truth;
-   command-line A1--A4 fallback;
-   environmental reset;
-   reproducible README/setup instructions;
-   no new protocol semantics;
-   no independent economic source of truth;
-   no demo-only backdoor;
-   no reopening of a prior gate.

Gas and coverage were engineering/submission evidence, not semantic gate
predicates.

------------------------------------------------------------------------

## 12. Independent Review: First G10 Hold

The first independent G10 review did **not** immediately pass the gate.

The implementation itself was correct, but two judge-facing statements
were too broad.

The frontend header said, in substance:

> `every value below is read from this chain`

The root README similarly said:

> `The interface displays no economic value it did not read from the chain.`

Those claims were false as written because the page also displayed
economic **proposals/configuration**, including requested A3 output and
A4 input bounds.

The implementation already separated these correctly. The defect was in
the claim boundary, not the economic behavior.

The independent determination was therefore:

> **G10 HOLD --- one minor F10 presentation correction required.**

This was intentionally classified as an F10-owned representation
correction. It did not reopen F9, GI, or production semantics.

------------------------------------------------------------------------

## 13. Presentation Correction

The correction narrowed the claims to what the implementation actually
guaranteed.

The frontend wording became equivalent to:

> `authoritative economic state below is read from this chain`

The README was changed to explain that:

-   the frontend derives no authoritative economic truth itself;
-   authoritative state comes from deployed protocol/PoolManager/token
    reads;
-   proposed transaction facts are presented separately from canonical
    demo configuration.

Frontend lint/build were rerun because JSX wording changed.

No Solidity regression was rerun because no Solidity or protocol
configuration changed.

The correction preserved the more important semantic distinction:

> **authoritative state ≠ proposed transaction facts ≠ prospective state
> ≠ transaction evidence**

------------------------------------------------------------------------

## 14. Completion-Report Persistence Issue

After the presentation correction, the user questioned whether the
completion report had actually been produced/persisted as intended.

Review showed that the completion report did exist, but the inspection
exposed a stale **Proposed Gate Assessment** paragraph that still
reflected the earlier state of browser verification.

That stale paragraph was corrected with a tiny documentation-only
follow-up to:

> **PENDING --- independent G10 review.**

The important process observation was not merely the wording fix.

A stronger rule emerged for future slice prompts:

> **Before displaying the Required Completion Report, append the
> complete report to the session log. The persisted report and displayed
> report must contain the same substantive evidence.**

This reduces ambiguity about whether evidence was merely shown in chat
or actually preserved in the contemporaneous repository record.

For correction prompts, the prompt should also say explicitly whether to
append a correction report or create a new completion report.

------------------------------------------------------------------------

## 15. Final G10 Determination

After:

-   deterministic implementation verification;
-   human browser verification;
-   presentation-fidelity correction;
-   stale evidence correction;
-   responsibility-leakage review;
-   prior-gate assessment;

the independent determination became:

> **F10 --- Demo / Submission Readiness: COMPLETE**\
> **G10: PASS / CLOSED**

No prior gate required reopening.

No production semantic defect was discovered.

------------------------------------------------------------------------

## 16. Gas and Coverage Review

Before final status recording, the user asked whether the refreshed gas
snapshot, coverage report, and setup documentation should be committed.

The conclusion was yes.

### Gas

The refreshed evidence showed:

-   zero changes among the 454 carried-over deterministic per-test gas
    values;
-   only small fuzz-median sampling movement;
-   no deployed-contract size change attributable to F10.

This supported the conclusion that F10 had not silently changed
production behavior.

### Coverage

The protocol-core coverage remained exactly at the entering baseline:

-   Lines: **99.42%**
-   Statements: **98.52%**
-   Branches: **92.31%**
-   Functions: **100%**

Repository-level coverage fell because operational `DemoActions.s.sol`
entered the denominator without a Forge test caller.

That was not treated as a reason to manufacture tests merely to restore
a percentage. The script had direct deterministic execution evidence.

This reinforced the earlier rule:

> coverage and gas are engineering evidence; they should not drive
> semantic implementation changes merely to improve a metric.

### Setup documentation

`docs/setup.md` was considered part of F10's reproducibility
responsibility rather than incidental documentation, because another
person must be able to reproduce the accepted environment and demo.

------------------------------------------------------------------------

## 17. Root README Review

The root README became the judge-facing repository entry point.

Its job was not to reproduce all canonical architecture documentation.
It needed to answer quickly:

-   What is Standby?
-   What problem does it solve?
-   What is novel?
-   What does the canonical demo prove?
-   How do I run it?
-   What does Standby **not** claim?
-   Where are the deeper artifacts?

The established public identity remained:

**Standby**

> **Execution capacity when you need it.**

> **Protocol-enforced future execution capacity from shared AMM
> liquidity.**

and the judge-facing synthesis:

> **Standby doesn't reserve liquidity. It protects capacity.**

The README review also confirmed that the root README already was the
repository README; a second repository README should not be created.

------------------------------------------------------------------------

## 18. Diagram Decision

The user asked whether the README would benefit from diagrams.

The recommendation was yes, but only two.

A conventional detailed architecture diagram was rejected as unnecessary
for the root README because the canonical architecture artifacts already
own that level of detail.

The two chosen diagrams had distinct jobs:

1.  **Diagram 1 --- how Standby executes**
2.  **Diagram 2 --- what the canonical economic lifecycle proves**

This division avoided making one diagram carry both control flow and
economic-state evolution.

------------------------------------------------------------------------

## 19. Diagram 1 Derivation and User Challenges

Diagram 1 required several rounds of careful reasoning.

The user correctly challenged early versions when the causal placement
implied that Standby called the ExerciseRouter.

That was wrong.

The Exercise Authority initiates through the ExerciseRouter; the Hook
and Router form the trusted O2 control boundary.

Another revision initially failed to show Hook involvement in ordinary
swaps. The user correctly questioned this because ordinary swaps execute
through PoolManager hook callbacks and StandbyHook performs the
prospective backing check.

The label "O2 execution" was also judged too vague.

The user then questioned whether commitment admission should flow
through the Exercise Authority → ExerciseRouter → Standby path.

The conclusion was that Diagram 1 should **not** depict commitment
admission at all. Admission and later exercise are distinct lifecycle
events.

Diagram 1 therefore begins after a commitment already exists.

Diagram 2 owns A1 and explicitly shows creation of the obligation.

------------------------------------------------------------------------

## 20. Verifying Diagram 1 Against F8A--F8D

Before freezing Diagram 1, the user asked whether the completed F8
implementation should be consulted to make sure the sequence was exact.

The answer was yes.

The resulting cross-check established:

### F8A

-   Hook-owned transaction-scoped causal context;
-   `authorizeExercise`;
-   failed authorization occurs before PoolManager unlock;
-   exact context binds service/pool, commitment, router, exerciser,
    Beneficiary, `q`, and lifecycle;
-   `EMPTY → AUTHORIZED`.

### F8B

-   ExerciseRouter unlocks PoolManager;
-   exactly one protected execution is performed;
-   Hook `beforeSwap` classifies/matches O2;
-   `AUTHORIZED → EXECUTING`;
-   Hook `afterSwap` consumes authoritative `BalanceDelta`;
-   exact protected output `q` is proven;
-   `EXECUTING → EXECUTED`.

### F8C

-   ExerciseRouter owns settlement mechanics;
-   actual input debt comes from PoolManager delta;
-   authenticated exerciser is the economic payer;
-   protected output is delivered directly: `PoolManager → Beneficiary`;
-   output does not route through ExerciseRouter.

### F8D

-   Hook owns `finalizeExercise`;
-   finalization occurs after settlement/delivery and inside the same
    unlock;
-   final backing is verified;
-   Remaining Entitlement is reduced exactly by `q`;
-   causal context is consumed;
-   failed finalization unwinds atomically.

This implementation verification materially changed the confidence level
of the diagram. It was no longer merely a conceptual sketch; it was a
judge-facing abstraction checked against the completed realization.

------------------------------------------------------------------------

## 21. Final Frozen Diagram 1

The user then noticed that an internal note had disappeared during
refinement:

> **Commitment already exists with outstanding obligation O**

The note was restored.

The user explicitly responded that this was much better and instructed
that Diagram 1 and Diagram 2 be frozen.

The frozen Diagram 1 was therefore preceded by:

> **The sequence below begins after a Standby commitment has already
> been admitted and an outstanding obligation `O` exists. It compares
> ordinary use of the shared AMM liquidity with later authorized
> exercise of that commitment.**

Its causal structure was:

-   Ordinary Trader → Trusted Swap Periphery → PoolManager;
-   PoolManager invokes StandbyHook;
-   Hook derives prospective `S′`;
-   compatible ordinary transition permitted when `S′ ≥ O`;
-   incompatible ordinary transition rejected when `S′ < O`;
-   Exercise Authority → ExerciseRouter;
-   ExerciseRouter requests Hook authorization;
-   Router unlocks PoolManager and performs exact-output execution;
-   Hook observes/matches execution through `beforeSwap` / `afterSwap`;
-   Router coordinates settlement of actual input debt;
-   PoolManager directly delivers protected output to Beneficiary;
-   Router requests finalization;
-   Hook verifies final backing, reduces Remaining, and consumes causal
    context;
-   unlock completes.

One intentional abstraction remained: the diagram arrow says the Router
settles actual input debt, while the prose clarifies that the
authenticated exerciser is the economic payer. The Router coordinates
the settlement mechanics.

------------------------------------------------------------------------

## 22. Frozen Diagram 2

Diagram 2 begins before admission and shows the economic lifecycle:

> Bootstrap `80k / 0`\
> → A1 `80k / 50k / 50k`\
> → A2 `65k / 50k / 50k`\
> → A3 prospective `45k < 50k`, rejected, authoritative state unchanged\
> → A4 Beneficiary +50k, final `15k / 0 / 0`.

This makes the division explicit:

-   **Diagram 1:** how the protocol executes;
-   **Diagram 2:** what the economic history proves.

------------------------------------------------------------------------

## 23. Two-Stage Diagram Verification Process

Because of prior experience with diagram-generation drift, the user
asked whether Claude should first display the diagrams before inserting
them into the README.

The answer was yes.

A hard two-stage process was established:

### Stage 1 --- visual verification only

Claude received the exact frozen Mermaid source and was instructed to:

-   render/display both diagrams;
-   modify no repository file;
-   perform no redesign;
-   preserve every participant, node, arrow, label, quantity, and
    ordering;
-   add no style/theme/class/color/icon/subgraph/init directive;
-   report a rendering problem rather than "fixing" the source.

The user visually reviewed the rendered artifact and explicitly approved
it.

### Stage 2 --- integration only

The subsequent README prompt was revised after the user correctly
pointed out that Claude should **not regenerate** diagrams that had
already been derived, frozen, rendered, and approved.

The integration instruction therefore required exact reuse of the frozen
Mermaid source.

This was an important process improvement:

> **Derivation → freeze → render-only verification → human approval →
> exact integration**

rather than allowing a documentation implementation agent to reinterpret
an already-approved diagram.

------------------------------------------------------------------------

## 24. README Diagram Integration

The final README placement was independently reviewed.

Diagram 1 was placed under:

> `## How Standby Executes`

after the realization/components were introduced.

Diagram 2 was placed within:

> `## What the canonical demo proves`

after the canonical state table.

The Mermaid sources were preserved as Mermaid fenced blocks.

The user asked whether GitHub would actually show diagrams or merely
source text.

The clarification was:

-   repository representation: Mermaid source in Markdown;
-   GitHub README presentation: GitHub renders the Mermaid visually.

PNG/SVG replacement was therefore unnecessary.

------------------------------------------------------------------------

## 25. GitHub Repository Presentation

The user clarified that by "repository README/description" they also
meant the GitHub repository presentation on their profile/repository
page.

The recommended GitHub About description was the already established
descriptor:

> **Protocol-enforced future execution capacity from shared AMM
> liquidity.**

Recommended topics included:

-   `defi`
-   `uniswap-v4`
-   `uniswap-v4-hooks`
-   `smart-contracts`
-   `solidity`
-   `amm`
-   `protocol-engineering`

The website field could remain blank unless a deployed demo/site became
genuinely useful.

The reasoning was to preserve one public vocabulary rather than invent
hackathon-specific positioning at the repository metadata layer.

A final GitHub rendering/presentation QA pass was recommended after the
branch is pushed/merged so that the actual judge-facing repository ---
not merely local Markdown --- can be inspected.

------------------------------------------------------------------------

## 26. MIT License Decision

The user asked whether a root MIT license should be added before
submission.

The recommendation was yes.

Standby-owned Solidity files already used:

> `SPDX-License-Identifier: MIT`

Therefore a root-level standard MIT `LICENSE` was consistent and
straightforward.

The bounded change was:

-   root `LICENSE`;
-   standard MIT text;
-   `Copyright (c) 2026 Gary Kocsis`;
-   no Solidity SPDX changes.

This was classified as repository/submission hygiene, not protocol
semantics, and therefore did not reopen F10/G10.

The resulting license and audit-log entry were independently reviewed
and accepted without correction.

------------------------------------------------------------------------

## 27. Final Status Recording

Only after:

-   G10 independent PASS/CLOSED;
-   post-G10 README/diagram follow-up;
-   visual diagram approval;
-   README integration review;
-   MIT licensing review;

was `docs/project-status.md` authorized for its final status-only
update.

The user explicitly preferred the compact status-update prompt pattern
that had worked in prior sessions rather than an over-specified prompt
full of prohibitions.

That was a useful correction to ChatGPT's first draft.

The final status instruction recorded:

-   **F10 --- Demo / Submission Readiness: COMPLETE**
-   **G10: PASS / CLOSED**
-   **F9T --- Public Testnet Deployment: OPTIONAL / OFF CRITICAL PATH**

The user then correctly asked that the Session 17 audit chronology
explicitly preserve:

-   post-G10 documentation follow-up independently reviewed and
    accepted;
-   both frozen Mermaid diagrams confirmed in the root README;
-   MIT licensing follow-up independently reviewed and accepted;
-   independent F10/G10 result authorized for status recording;
-   project status updated status-only;
-   F9T optional/off critical path;
-   Claude did not independently assess or close the gate.

The resulting diffs were independently reviewed.

`docs/project-status.md` correctly ended with:

-   no current critical-path implementation slice;
-   G10 as the last closed gate;
-   F10 complete;
-   no current blocker;
-   F0--F10 critical-path ladder complete;
-   F9T still optional/off critical path.

No correction was required.

------------------------------------------------------------------------

## 28. Responsibility-Leakage Review

F10 remained within its responsibility.

It did not:

-   modify protocol semantics;
-   add a second source of economic truth;
-   reimplement F9 acceptance;
-   add a demo-only economic backdoor;
-   turn reset into a protocol function;
-   make public testnet deployment mandatory;
-   silently repair an earlier slice;
-   weaken tests to support the demo;
-   change protocol behavior to improve gas or coverage;
-   allow frontend convenience to own economic derivation.

The post-G10 changes were representation and repository hygiene only.

No prior gate required reopening.

------------------------------------------------------------------------

## 29. Alternatives Considered and Rejected

Several alternatives were materially considered during F10.

### Recompute prospective capacity in JavaScript

Rejected.

Prospective `S′` must come from the production derivation surface so the
UI does not become a second economic implementation.

### Maintain economic UI state optimistically

Rejected.

Authoritative state must be re-read from chain after actions and
reconstructed after reload.

### Add a production reset function

Rejected.

Reset is an environment concern.

### Build a full wallet-based dApp flow

Rejected for the canonical judged demo.

Deterministic unlocked Anvil role accounts preserve role separation
without expanding F10 into production-wallet UX.

### Treat F10 as another acceptance suite

Rejected.

F9 already owns canonical acceptance.

### Force operational DemoActions into Forge coverage

Rejected.

Direct deterministic execution is appropriate evidence; a percentage
alone should not drive artificial tests.

### Add a detailed architecture diagram to the root README

Rejected.

The canonical architecture artifacts already own that detail. Two
judge-facing diagrams were enough.

### Let Claude design/redesign the diagrams during README insertion

Rejected.

The diagrams were derived, implementation-checked, frozen, visually
verified, and then integrated exactly.

### Make F9T the next required slice

Rejected.

Public testnet deployment is optional credibility evidence and should be
attempted only after submission-critical work is safe.

------------------------------------------------------------------------

## 30. Methodology Observations

### 30.1 Implementation convergence held through the presentation layer

The same convergence principle that reduced Solidity design discretion
also proved useful for F10.

Once the following were assigned clearly:

-   authoritative state owner;
-   prospective derivation owner;
-   transaction proposal boundary;
-   UI responsibility;
-   demo choreography;
-   reproduction responsibility;
-   gate evidence;

the implementation agent had comparatively little legitimate semantic
discretion.

This is a broader application of:

> **Implementation Convergence = Semantic Completeness + Responsibility
> Clarity + Bounded Implementation Discretion + Verification-Gated
> Dependencies.**

### 30.2 Judge-facing representation is itself a semantic boundary

The first G10 HOLD did not expose a protocol bug. It exposed an
**overclaim** in presentation.

That matters.

A correct implementation can still be misrepresented by an overly broad
sentence.

Future methodology should explicitly treat public claims and
instrumentation labels as requiring fidelity to the underlying authority
model.

### 30.3 Proposed, prospective, authoritative, and evidentiary facts should remain separate

F10 made this distinction unusually concrete.

A useful reusable classification is:

-   **authoritative fact** --- current protocol/token/PoolManager state;
-   **proposed fact** --- parameters the user intends to submit;
-   **prospective fact** --- production-derived result if a transition
    were applied;
-   **execution evidence** --- receipt/revert/balance delta proving what
    actually happened.

Conflating these categories creates both UI and reasoning errors.

### 30.4 Verification-gated dependencies prevented demo pressure from contaminating production semantics

Because F9 and GI were already closed, F10 had a strong presumption
against production changes.

That made it much easier to distinguish:

-   presentation problem;
-   instrumentation problem;
-   actual protocol defect.

This is a strong argument for completing semantic verification before
building the judged presentation layer.

### 30.5 Human verification and automated verification are complementary

The headless verifier established repeatability through the frontend's
own modules.

The user's browser click-through established actual assembled
human-facing behavior and legibility.

Neither should be represented as the other.

### 30.6 Diagram generation benefits from a freeze-and-render protocol

The diagram workflow produced a reusable process:

> **derive → implementation-check → freeze → render without mutation →
> human inspect → integrate exact source**

This sharply reduces representational drift when an implementation agent
is asked to handle visual documentation.

### 30.7 Completion evidence should be persisted before it is displayed

The completion-report concern produced a concrete process improvement:

> **Persist the complete report in the session log before displaying
> it.**

That makes the repository evidence record authoritative for
retrospective purposes and avoids reconstructing what happened from chat
history.

### 30.8 Small prompts can be safer after conventions are established

The final status-update prompt initially became too elaborate.

The user correctly pointed back to the compact status-only pattern used
successfully in earlier sessions.

Once repository conventions and agent responsibilities are stable,
repeating a proven compact instruction can produce less ambiguity than
restating every prohibition.

This is another form of bounded implementation discretion: establish the
convention once, then invoke it precisely.

------------------------------------------------------------------------

## 31. Final F10 Determination

The final independent conclusion for Session 17 is:

> **F10 --- Demo / Submission Readiness: COMPLETE**

> **G10 --- Demo / Submission Readiness Gate: PASS / CLOSED**

The F0--F10 critical-path implementation ladder is complete.

F9T --- Public Testnet Deployment --- remains:

> **OPTIONAL / OFF CRITICAL PATH**

No F10 responsibility remains open.

No prior gate requires reopening.

------------------------------------------------------------------------

## 32. Immediate Post-F10 Plan

The agreed post-F10 sequence is:

1.  preserve this Session 17 retrospective;
2.  commit the F10 package;
3.  open the F10 PR and allow CI to run;
4.  merge F10 to `main`;
5.  inspect the actual GitHub-rendered repository presentation;
6.  prepare the ETHGlobal submission package;
7.  rehearse and record the 2--4 minute demo/video;
8.  if submission-critical work is safe and time remains, optionally
    open a dedicated F9T session;
9.  perform final submission QA and submit;
10. after ETHGlobal submission, use the contemporaneous per-slice
    evidence for the broader Standby / Protocol Discovery Methodology
    retrospective.

The project has therefore transitioned from **building and verifying
Standby** to **packaging, presenting, and submitting the accepted
realization**.
