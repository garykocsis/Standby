# Standby — Post-F10 README Institutional / Economic Framing

## 1. Objective

Improve the root `README.md` so that an ETHGlobal / Uniswap judge can quickly understand:

1. **who Standby is for;**
2. **what institutional problem it addresses;**
3. **what economic primitive Standby creates;**
4. **why Uniswap v4 hooks are necessary to enforce that primitive;**
5. **how a time-bounded Standby commitment behaves;**
6. **why LPs might economically participate;**
7. **how Standby relates to permissioned institutional markets;**
8. **what remains before a production deployment.**

This is a **documentation / repository-presentation task only**.

The Standby implementation is complete.

F10 is COMPLETE.

G10 is CLOSED / PASS.

Do not reopen F10, G10, or any earlier implementation gate.

Do not begin F9T.

The purpose of this task is to make the already-proven protocol easier for judges, Uniswap reviewers, and technically sophisticated institutional readers to understand.

---

# 2. Session Responsibility Boundary

The normative derivation for this README update has already been completed.

For this session, implement only the authorized README presentation changes defined below.

The derived institutional framing, economic boundaries, temporal commitment interpretation, Uniswap v4 rationale, permissioned-market distinction, production-path boundary, and non-claim boundaries are requirements for this README task.

Do not independently redesign Standby's economics, protocol semantics, architecture, implementation, or accepted verification model.

If the requested README presentation cannot be reconciled with the canonical repository artifacts, stop and report the conflict rather than resolving it by changing protocol semantics.

---

# 3. Repository Instruction Ownership

Follow the existing `CLAUDE.md` and applicable `.claude/rules/*`.

This session prompt does not modify or supersede permanent repository operating behavior or Solidity/testing conventions.

Do not modify:

```text
CLAUDE.md
.claude/rules/*
```

as part of this task.

# 4. Authoritative Semantic Sources

The README must remain subordinate to the canonical Standby artifacts.

Use the existing repository documentation, especially where necessary:

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
docs/project-status.md
docs/setup.md
```

Do not modify frozen canonical artifacts.

If README wording conflicts with a canonical artifact, the canonical artifact wins.

If a proposed presentation statement cannot be supported by the repository's accepted semantics, do not invent supporting semantics.

---

# 5. Preserve the Existing Standby Identity

Preserve:

**Name**

> Standby

**Tagline**

> Execution capacity when you need it.

**Technical descriptor**

> Protocol-enforced future execution capacity from shared AMM liquidity.

**Judge-facing synthesis**

> Standby doesn't reserve liquidity. It protects capacity.

Do not replace these with new branding.

---

# 6. Core Judge-Facing Narrative

The revised README should make the following causal story easy to understand:

```text
institution has a possible future settlement need
                    ↓
does not want to pre-position the settlement asset
                    ↓
acquires bounded future execution capacity
                    ↓
Standby admits a time-bounded commitment
                    ↓
shared AMM liquidity remains available for compatible use
                    ↓
Standby rejects transitions that would destroy promised capacity
                    ↓
authorized exercise becomes possible during its exercise window
              ↙                         ↘
        exercised                   unexercised
            ↓                            ↓
     actual AMM execution            validUntil
            ↓                            ↓
    Beneficiary delivery              expiry
            ↓                            ↓
      obligation released       obligation released
```

The README does not have to reproduce this exact ASCII diagram.

Use it as the conceptual narrative.

---

# 7. Target Actors — “Who Standby Is For”

Add concise judge-facing explanation of the types of actors for whom this primitive may be useful.

Appropriate illustrative categories include:

- tokenized-asset issuers and asset managers;
- institutional treasury and settlement operators;
- permissioned onchain markets;
- institutional holders of productive/yield-bearing onchain assets that may later require a bounded quantity of another asset for settlement, redemption, collateral, treasury, or similar operational purposes.

Do not claim that any specific institution currently uses Standby.

Do not present these actors as customers.

Use language such as:

- “intended for”;
- “potential users include”;
- “illustrative use case”;
- “a production deployment could”.

Avoid unsupported commercial claims.

---

# 8. Institutional Example

Include one concrete, clearly illustrative example.

The intended scenario is approximately:

```text
An institution holds $5 million of tokenized Treasury assets.

It may need $500,000 USDC tomorrow during a defined settlement window.

Without Standby it could:

- pre-position the USDC;
- arrange dedicated liquidity;
- rely on a counterparty;
- or accept uncertainty about future executable AMM capacity.

With Standby it could instead acquire a bounded future execution commitment
backed by qualifying shared AMM liquidity.
```

Explain that:

- the $5M / $500K numbers are illustrative;
- they are not the canonical demo fixture;
- the liquidity is not segregated;
- compatible eligible use can continue;
- Standby protects the admitted capacity boundary;
- authorized exercise uses actual AMM execution;
- the Beneficiary receives the protected output on successful fulfillment.

Do not imply guaranteed price.

Do not imply zero slippage.

Do not imply unconditional execution.

Do not imply production readiness.

---

# 9. Time-Bounded Commitment Lifecycle

Make the temporal nature of a Standby commitment understandable.

The accepted semantics include:

```text
exercisableFrom
validUntil
```

A valid future commitment contributes to Capacity Obligation before it becomes exercisable.

This is intentional:

the capacity must already be protected before the exercise window opens.

Authorized exercise requires the commitment to be within its exercise window.

Conceptually:

```text
exercisableFrom <= t < validUntil
```

If successful exercise and causal fulfillment occur, Remaining Entitlement and the corresponding Capacity Obligation are reduced by the fulfilled quantity.

If:

```text
t >= validUntil
```

the expired commitment ceases contributing to Capacity Obligation.

Important distinction:

> **Expiry releases an obligation; expiry is not fulfillment.**

Do not say that an expired commitment was exercised or satisfied.

Do not imply that Remaining Entitlement must be rewritten to zero merely because the commitment expired.

The README does not need implementation-level lifecycle detail, but the reader should understand:

> Standby protects a bounded quantity of future execution capacity for a bounded period rather than imposing an indefinite liquidity constraint.

---

# 10. Why Uniswap v4?

Add a concise, prominent explanation of why Standby is specifically a Uniswap v4 hook.

The key reasoning is:

> A future execution commitment is credible only if it can be enforced where the resource backing the commitment changes.

For Standby, that backing resource is executable AMM capacity.

Swaps and liquidity actions change that capacity.

An external promise ledger alone would not be sufficient if the backing AMM state could subsequently transition into a state that violates the admitted obligation.

Uniswap v4 hooks provide the enforcement boundary at the relevant pool lifecycle transitions.

Standby therefore evaluates backing-affecting transitions where the pool state changes.

Preserve this distinction:

```text
compatible transition
    → allowed

capacity-destroying transition
    → rejected

authorized protected exercise
    → recognized through the actual AMM execution path
```

A useful concise conclusion is:

> **The economic agreement is enforced where the backing state changes.**

Do not turn this section into a generic explanation of Uniswap v4.

Explain why **Standby's particular economic agreement requires the hook boundary**.

---

# 11. Preserve the Core Invariant

Continue to make the canonical relationship prominent:

```text
Supporting Capacity S >= Capacity Obligation O
```

Do not redefine `S`.

Do not redefine `O`.

Do not introduce a second economic model for explaining the README.

Preserve the existing distinction between:

- supporting capacity;
- capacity obligation;
- remaining entitlement;
- prospective supporting capacity;
- authoritative current state.

---

# 12. Preserve Non-Reservation

The README must continue to make clear that Standby does **not** reserve the protected output.

A commitment does not require:

- segregating the committed output;
- transferring the protected asset into Standby custody;
- dedicating the backing liquidity exclusively to the Beneficiary.

Compatible ordinary AMM activity can continue while a commitment is outstanding.

Do not weaken the existing A2 non-reservation proof.

When discussing LP constraints, use wording such as:

> supporting liquidity gives up unconstrained use of capacity whose removal would violate an outstanding commitment.

Do **not** imply:

> LPs lose use of their liquidity.

That would contradict the demonstrated compatible-use behavior.

---

# 13. Protocol Economics

Add a concise section explaining the economic roles without inventing production tokenomics.

The key framing is:

> **Standby turns shared AMM liquidity into two potentially distinct economic services: immediate execution and committed future availability.**

The economic roles are:

### Capacity purchaser / Beneficiary

Receives something economically valuable:

a bounded commitment that qualifying future AMM execution capacity will remain available under the configured conditions.

### Supporting LPs

Continue participating in compatible AMM activity but, while an obligation is live, cannot perform or support a transition that would leave the admitted commitment insufficiently backed.

The constraint is:

- quantity bounded;
- time bounded;
- compatible with continued ordinary use.

### Potential production compensation

A production market would likely require compensation for providing this additional service.

A plausible conceptual direction is:

```text
capacity purchaser
        ↓
 capacity premium
        ↓
supporting liquidity
```

LPs could potentially receive value from two services:

```text
immediate AMM execution
    → ordinary swap fees

committed future availability
    → capacity premiums
```

A capacity premium might depend on factors such as:

- commitment quantity;
- commitment duration;
- capacity utilization/scarcity;
- market conditions.

This is conceptual production-path reasoning only.

The current reference implementation does **not** implement:

- capacity pricing;
- LP premium distribution;
- capacity auctions;
- a utilization pricing curve;
- LP attribution economics;
- a capacity marketplace.

Do not imply otherwise.

Also preserve the distinction between:

1. payment for the future capacity right; and
2. actual input settlement required when exercise occurs.

These are conceptually distinct economic quantities.

Do not prescribe a final production pricing mechanism.

---

# 14. Permissioned Institutional Markets

Add a concise explanation of the reference realization's permissioning model.

Standby uses an external onchain:

```text
EligibilityRegistry
```

The registry provides logically distinct eligibility predicates for relevant actor/action classes, including:

- Beneficiary protected-service eligibility;
- trader eligibility;
- liquidity-action eligibility.

Standby queries this authority rather than owning membership administration as protocol economic state.

Explain why this is relevant to institutional/tokenized-asset markets.

However, preserve this boundary prominently:

> **The Standby reference implementation is not an integration with Uniswap Permissioned Pools.**

Do not claim otherwise.

A useful conceptual distinction is:

> **Permissioning asks:** Who may participate?

> **Standby asks:** Given authorized participants, what future execution capacity may be promised, and which subsequent uses of shared liquidity remain compatible with that promise?

The mechanisms can therefore be described as conceptually complementary without claiming technical integration.

Do not claim endorsement, partnership, adoption, or integration by:

- Uniswap;
- Superstate;
- Securitize;
- Dowgo;
- or any other institution.

Do not add institutional names merely to borrow credibility.

If linking to Uniswap Permissioned Pools for background context, use official Uniswap documentation only and clearly separate that external system from the Standby reference implementation.

---

# 15. Existing Realization and Demo Evidence

Preserve the existing technical realization section unless a minimal transition edit is needed for readability.

Preserve the canonical A1–A4 proof.

The canonical deterministic fixture remains:

```text
bootstrap:
S = 80,000 MockUSDC
O = 0

A1:
commitment q = 50,000
S = 80,000
O = 50,000
Remaining = 50,000

A2:
compatible ordinary exact-output = 15,000
S = 65,000
O = 50,000
Remaining = 50,000
PASS

A3:
attempt ordinary exact-output = 20,000
prospective S' = 45,000
O = 50,000
45,000 < 50,000
REJECT

authoritative state remains:
S = 65,000
O = 50,000
Remaining = 50,000

A4:
protected exercise q = 50,000
Beneficiary receives exactly 50,000 MockUSDC
Remaining = 0
O = 0
```

Do not change these values.

Do not substitute the illustrative $5M / $500K institutional example for the canonical fixture.

The illustrative example explains potential use.

The canonical fixture proves actual implemented behavior.

Keep those evidence classes distinct.

---

# 16. Frozen README Diagrams

The two existing README Mermaid diagrams are frozen presentation artifacts from F10.

Do not alter them.

Do not reinterpret them.

Do not replace them.

Do not add a third diagram unless an actual presentation problem makes one necessary and that change is separately authorized.

For this task, prefer concise prose for the temporal lifecycle.

---

# 17. What Standby Does Not Claim

Preserve the existing non-claim section.

At minimum, do not weaken boundaries around:

- arbitrary future execution;
- fixed input price;
- elimination of price impact;
- elimination of slippage;
- universal asset support;
- unconditional execution;
- production readiness;
- integration with a particular tokenized-asset issuer.

The improved institutional framing must not turn potential use cases into implemented production claims.

---

# 18. Path to Production

Add a concise:

```text
## Path to production
```

section.

Recommended placement:

```text
What Standby does not claim
        ↓
Path to production
        ↓
Verification
        ↓
Documentation
```

Open with the distinction:

> The reference implementation proves the protocol-enforced capacity primitive; it is not presented as production-ready institutional settlement infrastructure.

Then summarize the remaining production responsibilities under approximately these categories.

### Capacity economics

Examples:

- commitment pricing;
- LP attribution;
- LP compensation;
- premium distribution;
- duration/utilization/scarcity economics;
- capacity-market mechanism.

### Production permissioning and asset integration

Examples:

- appropriate production compliance model;
- authorization model;
- supported production assets;
- token-transfer restrictions;
- institutional operational requirements;
- potential interoperability with permissioned infrastructure where appropriate.

Do not claim an integration that does not exist.

### Production periphery and deployment

Examples:

- supported-chain infrastructure;
- production PoolManager/periphery assumptions;
- routers and settlement paths;
- configuration/deployment administration;
- production token behavior;
- public-chain operational validation.

Canonical deterministic Anvil remains the accepted hackathon environment.

Do not imply that optional F9T is required to validate F10.

### Security and operational hardening

Examples:

- independent audit;
- adversarial review;
- economic stress testing;
- dependency review;
- key/admin security;
- monitoring;
- incident response;
- upgrade/migration policy.

Do not imply that current testing is equivalent to a production audit.

### Market validation

Explain that production viability also requires validating:

- willingness of institutions to pay for protected future capacity;
- whether capacity premiums sufficiently compensate supporting liquidity;
- whether supply and demand produce a viable capacity market.

Keep this section concise.

It is a production boundary, not a new implementation roadmap.

---

# 19. Verification Evidence

Preserve the accepted verification evidence already in the README.

Do not reduce or exaggerate it.

Accepted final evidence includes:

```text
forge fmt clean

forge build success

590 tests passed
0 failed
0 skipped

CI profile passed

frontend lint clean

frontend build clean

frontend deterministic verification 36/36

canonical demo reproduced in fresh deterministic environments
```

Accepted coverage baseline:

```text
Lines       99.42%
Statements  98.52%
Branches    92.31%
Functions   100%
```

Do not characterize these results as a production security audit.

---

# 20. README Editorial Guidance

The final README should remain a judge-facing repository landing page.

Do not turn it into another specification.

Prefer:

- concise paragraphs;
- short explanatory subsections;
- meaningful emphasis;
- one concrete institutional example;
- existing diagrams;
- existing proof evidence;
- links to deeper canonical documentation.

Avoid:

- excessive prose;
- duplicated explanations;
- marketing superlatives;
- unsupported institutional claims;
- speculative tokenomics;
- unnecessary new diagrams;
- implementation details better left in canonical docs.

The first portion of the README should make the project understandable before the reader reaches detailed implementation material.

A technically sophisticated reader should be able to answer quickly:

```text
What problem does Standby solve?

Who might need it?

What exactly is being promised?

Why doesn't this require reserved liquidity?

When can the commitment be exercised?

What happens if it is never exercised?

Why would LPs participate?

Why does this require Uniswap v4?

How does permissioning fit?

What has actually been proven?

What remains before production?
```

---

# 21. Desired High-Level README Flow

Use this as the preferred narrative structure, adapting minimally to the existing README rather than mechanically rebuilding it:

```text
Standby
tagline / descriptor / key claim

The problem

Who Standby is for
  - target actors
  - institutional example
  - bounded commitment lifecycle

Why Uniswap v4?

The core idea
  - S >= O
  - non-reservation

Protocol economics

Permissioned institutional markets

The realization

How Standby Executes
  [existing frozen diagram]

What the Canonical Demo Proves
  [existing A1-A4]
  [existing frozen diagram]

Running the Demo

Without a Browser

What Standby Does Not Claim

Path to Production

Verification

Documentation
```

Do not follow this mechanically if doing so would unnecessarily damage good existing README composition.

The objective is narrative clarity, not heading compliance.

---

# 22. Scope Boundary

Authorized modification:

```text
README.md
```

Do not modify:

```text
src/
test/
script/
frontend/
docs/
CLAUDE.md
.claude/rules/
foundry.toml
foundry.lock
.gitmodules
.github/
LICENSE
.gas-snapshot
```

Do not modify protocol code.

Do not modify tests.

Do not modify canonical artifacts.

Do not modify frozen diagrams.

Do not begin F9T.

Do not update `docs/project-status.md`.

This task does not change project completion status.

---

# 23. GitHub Topic Typo

There is a separate repository metadata typo:

```text
protcol-engineering
```

should be:

```text
protocol-engineering
```

Do not attempt to solve this by modifying README content.

If repository metadata cannot be changed through the current environment, simply report it as a remaining manual metadata correction.

Do not use browser automation for this README task.

---

# 24. Required Review After Editing

After editing `README.md`, review the complete rendered narrative logically from top to bottom.

Specifically verify:

### Semantic consistency

- `S >= O` remains canonical;
- non-reservation remains clear;
- future commitments protect capacity before exercisability;
- exercise is time bounded;
- expiry releases O without being called fulfillment;
- Beneficiary delivery remains tied to actual successful O2 fulfillment;
- illustrative institutional numbers are not confused with canonical fixture numbers.

### Economic consistency

- LPs retain compatible use;
- no claim that LPs are already paid capacity premiums;
- pricing remains future mechanism design;
- capacity premium and exercise settlement remain conceptually distinct.

### Permissioning consistency

- Standby `EligibilityRegistry` remains the implemented mechanism;
- no claim of current Uniswap Permissioned Pools integration;
- no institutional endorsement claim.

### Production boundary

- current reference implementation is not described as production ready;
- production work is clearly separated from completed hackathon proof;
- optional F9T is not presented as a missing F10 requirement.

### Presentation consistency

- no unnecessary repetition;
- headings flow naturally;
- existing Mermaid diagrams remain unchanged;
- internal relative links still resolve;
- Markdown renders cleanly;
- first-screen identity remains strong.

---

# 25. Verification Boundary

Because this is README-only documentation work, do not run the entire expensive protocol verification suite unless the repository's permanent instructions explicitly require it for documentation-only changes.

At minimum perform appropriate documentation/repository checks available locally, including:

```text
git diff --check
```

and inspect:

```text
git diff -- README.md
```

Confirm that only the authorized file changed.

If a lightweight Markdown/link check already exists in the repository, it may be used.

Do not add new tooling merely for this task.

---

# 26. Completion Report

When finished, report:

1. files changed;
2. sections added;
3. existing sections materially edited, if any;
4. confirmation that both frozen Mermaid diagrams are unchanged;
5. confirmation that canonical A1–A4 values are unchanged;
6. confirmation that no production code/tests/canonical docs changed;
7. documentation verification performed;
8. any unresolved presentation issue;
9. whether the GitHub topic typo still requires manual correction.

Do not claim F10 or G10 completion again.

They are already closed.

---

# 27. Completion Boundary

The README presentation completion boundary is:

```text
current README inspected

institutional audience framing integrated

illustrative institutional use case integrated

time-bounded commitment lifecycle explained

Why Uniswap v4 rationale integrated

protocol economics boundary integrated

permissioned-market relationship integrated

Path to Production integrated

existing non-claim boundaries preserved

canonical A1-A4 evidence preserved

both frozen Mermaid diagrams preserved unchanged

README reviewed end-to-end for semantic consistency

README reviewed for economic and permissioning overclaiming

relative documentation links checked

documentation verification complete

only README.md modified

completion report produced
```

Stop at this completion boundary.

Do not begin F9T.

Do not modify project status.

Do not begin another documentation or implementation task.
