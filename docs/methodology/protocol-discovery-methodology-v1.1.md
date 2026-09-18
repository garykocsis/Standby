# Protocol Discovery Methodology v1.1

**Status:** FROZEN\
**Version:** 1.1\
**Successor to:** Protocol Discovery Methodology v1.0\
**Empirical validation basis:** Standby protocol retrospective, R0--R7\
**Scope:** Protocol discovery and the controlled transition from
discovered protocol semantics toward conforming implementation

------------------------------------------------------------------------

## 1. Purpose

Protocol Discovery Methodology is a derivation-first method for
designing protocols whose implementation must preserve an economically
meaningful agreement.

Its purpose is to prevent implementation structure, component
convenience, framework behavior, or local engineering decisions from
becoming the accidental source of protocol meaning.

The methodology therefore derives protocol semantics before
implementation and assigns authoritative ownership for the economic
relationships, behavioral distinctions, state, derivations,
responsibilities, and verification obligations that a conforming
realization must preserve.

Protocol Discovery Methodology v1.1 retains the economic-discovery model
of v1.0 and incorporates implementation-transition refinements validated
through the Standby project.

v1.1 does **not** assert that complete economic semantics eliminate
implementation discovery.

Instead:

> **The methodology seeks to bound implementation discovery so that
> necessary realization work does not routinely acquire authority to
> redefine the protocol's economic meaning.**

------------------------------------------------------------------------

# 2. Canonical Derivation Chain

The canonical derivation chain remains:

> **Economic Reality → Coordination Problem → Coordination Analysis →
> Economic Agreement → Capability Requirements → Mechanism →
> Specification → Implementation**

Each stage consumes the validated output of the preceding stage.

A downstream stage may realize, constrain, or verify upstream semantics,
but it may not silently redefine them.

------------------------------------------------------------------------

# 3. Derivation Stages

## 3.1 Economic Reality

Identify the externally grounded economic facts that remain true
independently of the proposed protocol.

This includes relevant actors, resources, incentives, constraints,
environmental conditions, and existing alternatives.

Do not introduce protocol-created rights, obligations, mechanisms,
state, or enforcement behavior as premises of the problem.

## 3.2 Coordination Problem

Derive the coordination failure that exists within the validated
Economic Reality.

The problem should identify what actors cannot reliably coordinate or
obtain under the existing environment and why existing arrangements are
insufficient for the intended scope.

## 3.3 Coordination Analysis

Analyze the actors, incentives, conflicts, dependencies, credible
alternatives, and minimum relationships necessary to address the
Coordination Problem.

The analysis should narrow the solution space without prematurely
choosing implementation mechanisms.

## 3.4 Economic Agreement

Define the minimum normative economic relationships that must hold.

The Economic Agreement owns rights, obligations, conditions,
establishment semantics, persistence semantics, fulfillment semantics,
release semantics, and other economically meaningful relationships.

It answers:

> **What must economically be true?**

It does not prescribe the implementation mechanism used to make those
relationships reliable.

## 3.5 Capability Requirements

Derive the minimum protocol capabilities necessary to make the Economic
Agreement enforceable.

A capability requirement states what the protocol must be capable of
establishing, preserving, determining, preventing, or proving without
yet selecting the concrete mechanism.

## 3.6 Mechanism

Derive the minimum causal behavior required to realize the capability
requirements.

The Mechanism explains how the required economic relationship can be
preserved through authoritative protocol behavior while remaining
independent of unnecessary realization detail.

## 3.7 Specification

Define the normative protocol semantics required by the Mechanism.

The Specification owns authoritative operations, economically meaningful
definitions and derivations, authority boundaries, attribution
semantics, failure semantics, composition requirements, and
information-continuity requirements.

It answers:

> **What must every conforming realization preserve?**

## 3.8 Implementation

Translate the validated specification and its downstream correctness
responsibilities into a concrete realization.

Implementation may exercise bounded engineering discretion.

Implementation does not acquire authority to redefine the upstream
economic agreement merely because a realization choice is convenient,
necessary, or difficult.

------------------------------------------------------------------------

# 4. Core Principles

## 4.1 Canonical Context

The protocol's upstream context must contain every externally grounded
premise required to derive the Economic Agreement while excluding
downstream protocol-created requirements.

> **Context Completeness = Upstream Derivational Sufficiency +
> Downstream Non-Contamination**

A fact belongs in canonical context only when it remains meaningful
independently of the protocol's existence.

------------------------------------------------------------------------

## 4.2 Economic Agreement Completeness

The Economic Agreement must contain the minimum complete set of
economically meaningful rights, obligations, conditions, persistence
relationships, fulfillment relationships, release relationships, and
other economic semantics required for downstream derivation.

A downstream mechanism or implementation must not be forced to invent a
missing economic relationship in order to become coherent.

Completeness does not mean describing implementation.

It means downstream realization should not need to decide what the
economic agreement was supposed to mean.

------------------------------------------------------------------------

## 4.3 Behavioral Distinction Preservation

Economically distinct behaviors must remain distinct throughout
downstream derivation and implementation unless their equivalence has
itself been established normatively.

Implementation convenience is not sufficient reason to collapse distinct
economic events.

Examples of distinctions that may require preservation include:

-   request versus authoritative operation;
-   authorization versus execution;
-   execution versus settlement;
-   delivery versus fulfillment;
-   fulfillment versus non-fulfillment release;
-   observed fact versus requested behavior.

Where a distinction affects rights, obligations, authority, causality,
or economic consequences, the distinction must survive realization.

------------------------------------------------------------------------

## 4.4 Semantic Minimality

Authoritative protocol semantics should contain only the information and
distinctions necessary to preserve the Economic Agreement and its
derived correctness requirements.

Do not duplicate economically authoritative truth merely because the
same value is convenient downstream.

Do not assign economic meaning to information before the responsibility
that owns that interpretation.

Semantic Minimality does not prohibit causal evidence, verification
evidence, indexes, caches, or realization-specific structures when they
do not become competing normative truth.

------------------------------------------------------------------------

## 4.5 Economic Atomicity

A protocol operation whose economic meaning requires multiple causal
steps must not leave a partially authoritative economic result when the
complete normative consequence fails.

Atomicity is defined by the economic relationship being protected, not
merely by function or component boundaries.

Failure must preserve the authoritative economic state required by the
specification.

The concrete realization of atomicity may differ across execution
environments.

------------------------------------------------------------------------

## 4.6 Attribution Persistence

Where an economic consequence depends on an attributable cause, the
authoritative relationship between cause and consequence must persist
for as long as the consequence depends upon it.

Execution capability, routing capability, custody, or invocation does
not automatically confer attribution authority.

A realization must prevent substitution, replay, cross-relationship
reuse, or unrelated activity from manufacturing an attributable economic
consequence.

------------------------------------------------------------------------

## 4.7 Single Normative Ownership

Every normative concept must have one authoritative owner.

Downstream artifacts may consume, enforce, realize, reference, or verify
an upstream semantic concept, but they must not independently redefine
it.

Single Normative Ownership applies to:

-   economic relationships;
-   behavioral definitions;
-   authoritative derivations;
-   state semantics;
-   responsibility boundaries;
-   verification obligations;
-   implementation instructions where those instructions themselves
    require durable ownership.

> **Reference is not redefinition. Enforcement is not ownership.
> Implementation is not authority to reinterpret.**

Single Normative Ownership prevents competing authority; it does not by
itself guarantee that every descriptive artifact remains synchronized
with its normative source.

------------------------------------------------------------------------

## 4.8 Admission-Time Semantic Continuity

An authoritative admission must not create future protocol obligations
whose required semantics cannot remain authoritatively determined
throughout the admitted domain.

A state or configuration is not semantically admissible merely because
it is valid at the instant of admission.

### Prospective Semantic Support Test

For every authoritative admission that creates future protocol
obligations:

1.  derive the future normative determinations created by the admission;
2.  identify the authoritative facts required for those determinations;
3.  identify the realization capabilities required to obtain or derive
    those facts;
4.  determine the admitted semantic domain over which those obligations
    may persist;
5.  establish at admission that the required capabilities remain
    supported throughout that domain.

> **Present validity is insufficient when admission creates future
> semantic obligations.**

------------------------------------------------------------------------

# 5. Implementation Convergence Principle

> **When economic semantics, authoritative state, component
> responsibility, behavioral boundaries, and verification obligations
> have each been assigned a single normative owner before
> implementation, a competent implementer should require comparatively
> little design discretion to produce a conforming realization.**

Compact formulation:

> **Implementation Convergence = Semantic Completeness + Responsibility
> Clarity + Bounded Implementation Discretion + Verification-Gated
> Dependencies**

## 5.1 Interpretation

Implementation Convergence concerns **semantic discretion**, not
implementation effort.

A realization may require substantial engineering work,
platform-specific investigation, algorithm design, testing, integration,
and debugging while still exhibiting strong implementation convergence.

The relevant question is not:

> How much engineering work remained?

It is:

> How much authority remained for implementation to decide what the
> protocol economically means?

Strong convergence exists when necessary implementation discovery
remains bounded from redefining assigned economic semantics,
authoritative responsibilities, behavioral distinctions, and
verification obligations.

## 5.2 Bounded Implementation Discretion

Implementation discretion is bounded when alternative realization
choices may vary **how** an assigned responsibility is implemented but
may not:

-   create an already-unassigned economic responsibility;
-   remove an assigned responsibility;
-   relocate normative ownership;
-   weaken or strengthen an assigned economic condition;
-   collapse or reinterpret a required behavioral distinction;
-   change an already-assigned authoritative boundary;
-   remove or reinterpret a required dependency;
-   remove or reinterpret a verification obligation.

Engineering discretion is legitimate where multiple implementations
preserve the same normative responsibility and verification boundary.

## 5.3 Verification-Gated Dependencies

A downstream responsibility may rely on an upstream implementation
responsibility as validated only after the upstream verification gate
has closed.

Gate closure therefore functions as dependency authorization.

If evidence invalidates or reopens the upstream gate, downstream
reliance must be reconsidered until the dependency is restored to a
validated state.

------------------------------------------------------------------------

# 6. Precommitted Verification Boundary

Before implementation of a bounded protocol responsibility begins:

> **derive the normative conditions required to close that
> responsibility's verification gate independently of the implementation
> that will later be judged against them.**

The verification boundary defines **what must be demonstrated**.

It does not need to prescribe:

-   exact test code;
-   testing framework;
-   instrumentation;
-   oracle implementation;
-   fuzzing strategy;
-   proof technology;
-   concrete verification mechanics.

The purpose is to prevent implementation from becoming the source of its
own success criteria.

A mature responsibility handoff should therefore contain, at minimum:

> **Responsibility + Boundary + Prohibitions + Verification
> Obligations + Completion Boundary**

before implementation begins.

------------------------------------------------------------------------

# 7. Correction Ownership Procedure

When implementation, verification, integration, acceptance, or operation
exposes a defect, do not immediately modify the nearest artifact.

Apply the following procedure.

## 7.1 Identify the violated claim

Determine exactly what expected property, behavior, derivation,
boundary, or consequence failed.

## 7.2 Identify the authoritative owner

Determine which artifact, responsibility, or process layer owns the
violated claim.

## 7.3 Classify the defect

Classify the defect before correction.

Relevant classes include:

1.  **Economic-semantic defect** --- the normative economic relationship
    is missing, inconsistent, or incorrect.
2.  **Responsibility-assignment defect** --- ownership or a behavioral
    boundary is missing, conflicting, or assigned incorrectly.
3.  **Realization-assumption defect** --- a platform or execution
    assumption required by the normative design is incorrect or
    incomplete.
4.  **Implementation-conformance defect** --- implementation does not
    conform to an already-valid normative assignment.
5.  **Verification defect** --- the verification mechanism is
    insufficient, incorrect, or unable to establish the required claim.
6.  **Descriptive-documentation defect** --- a non-normative description
    is stale, misleading, or inconsistent with its authoritative source.
7.  **Infrastructure/tooling defect** --- build, test, deployment, or
    verification infrastructure is defective without changing protocol
    semantics.
8.  **Operational/security defect** --- execution of the engineering or
    deployment process creates an operational problem without changing
    protocol meaning.

## 7.4 Correct the minimum authoritative layer

Modify the lowest and most precise authoritative layer that actually
owns the defect.

Do not rewrite upstream semantics to rationalize a downstream
implementation deviation.

Do not patch downstream implementation around an upstream normative
defect.

## 7.5 Reopen invalidated dependencies

Determine which previously closed gates relied on the corrected claim.

Reopen and revalidate every downstream gate whose dependency was
invalidated.

> **Correction scope follows normative dependency, not file proximity.**

------------------------------------------------------------------------

# 8. Independent Conformance Review

Final closure of an implementation responsibility must not rely solely
on the implementation agent's own assessment.

> **Conformance must be evaluated against the precommitted normative and
> verification boundary by a review process independent of the
> implementation agent's acceptance judgment.**

This requirement does not imply that the reviewer must be
organizationally or epistemically independent from the entire project.

It requires separation between:

-   implementation;
-   the implementer's own claim of correctness; and
-   the judgment that the implementation conforms to its previously
    established responsibility.

The reviewer must be able to reject gate closure even when:

-   the implementation is locally reasonable;
-   tests are green;
-   the implementation agent believes the result is correct;
-   an alternative design would also have been reasonable before the
    responsibility was assigned.

The relevant question is conformance to the already-authorized
responsibility, not whether the implementation can be rationalized after
the fact.

------------------------------------------------------------------------

# 9. Verification Discipline

Verification must establish semantic proof obligations rather than
merely accumulate tests.

Where an economically meaningful quantity, classification, consequence,
or relationship is deterministically derived from authoritative facts,
verification should establish equivalence between the realization's
derivation and the normative derivation.

A useful general relationship is:

> **Safety Verification = Invariant Preservation + Authoritative
> Derivation Equivalence**

Verification should address both sides of a normative boundary:

-   prohibited behavior cannot become authoritative; and
-   behavior permitted or required by the semantics can become
    authoritative under the applicable conditions.

The concrete verification mechanism may differ from the production
mechanism.

> **Verification Mechanism ≠ Protocol Mechanism**

Verification infrastructure may use independent oracles, ghost state,
history reconstruction, mutation testing, adapters, instrumentation, or
other techniques without those mechanisms becoming protocol semantics.

------------------------------------------------------------------------

# 10. Responsibility-Oriented Implementation

Implementation should be decomposed according to semantic responsibility
and dependency rather than arbitrary code size.

A useful slice closes one bounded responsibility or dependency whose:

-   normative owner is known;
-   authoritative inputs are known;
-   outputs or consequences are known;
-   neighboring responsibilities are excluded;
-   verification boundary is precommitted;
-   completion boundary is explicit.

Small slices are not inherently better.

The objective is:

> **bounded responsibility, not maximal fragmentation.**

A responsibility should not be split merely to create process steps, and
neighboring responsibilities should not be combined merely because they
share implementation code.

------------------------------------------------------------------------

# 11. Methodology Cadence

v1.1 refines the implementation-facing cadence to make the gate ordering
explicit.

For a bounded implementation responsibility:

> **Validated State → Next Blocker → Responsibility Derivation →
> Verification-Gate Derivation → Bounded Implementation → Independent
> Conformance Review → Gate Closure → Next Validated State**

Where implementation or verification exposes a defect:

> **Observed Defect → Violated Claim → Normative Owner → Defect
> Classification → Minimum Authoritative Correction → Dependency
> Revalidation**

Methodology updates should be derived from repeated or materially
significant evidence rather than from every local implementation
observation.

------------------------------------------------------------------------

# 12. Formula Discipline

Where the methodology or protocol uses formulas:

> **Definition → Formula → Interpretation**

Define symbols before using them.

State what the formula computes.

Explain the economic or protocol interpretation after the formula.

Do not allow mathematical notation to substitute for an undefined
semantic relationship.

------------------------------------------------------------------------

# 13. Boundary Between Discovery and Implementation

Protocol Discovery Methodology retains the compact canonical chain
ending in `Specification → Implementation`.

v1.1 recognizes that this final transition contains substantial internal
structure.

Standby provides evidence for a provisional implementation sequence:

> **Validated Specification → Responsibility Decomposition → Realization
> Mapping → Gate Derivation → Bounded Implementation → Independent
> Conformance Review → Gate Closure → Compositional Verification →
> Canonical Acceptance**

This sequence is **not frozen as a separate Protocol Implementation
Method in v1.1**.

It remains an empirically supported hypothesis requiring validation
across additional protocols.

Similarly, the following three-layer interpretation remains provisional:

### Discovery

> **Context → Economic Agreement → Mechanism → Specification**

Question:

> **What must the protocol mean?**

### Convergence

> **Architecture → State / Transition Semantics → Invariants →
> Verification Obligations**

Question:

> **What responsibilities and properties must every correct realization
> preserve?**

### Implementation

> **Realization Mapping → Gated Responsibilities → Verification →
> Acceptance**

Question:

> **Does this concrete realization preserve them?**

This model should be tested rather than assumed in the next protocol.

------------------------------------------------------------------------

# 14. Provisional Findings Excluded from v1.1

The following findings are intentionally **not frozen** as Protocol
Discovery Methodology principles.

## 14.1 Realization Dependency Validation

**Status:** PROVISIONAL.

Hypothesis:

> **Before normative correctness depends upon a platform-specific
> realization assumption, validate that assumption or keep the
> dependency explicitly verification-gated.**

The evidence is strong enough to prioritize this question in the next
protocol but insufficient to establish a standalone general principle.

## 14.2 Implementation-State Reconstructibility

**Status:** PROVISIONAL --- candidate Protocol Implementation Method
property.

Hypothesis:

> **A competent fresh implementation session should be able to
> reconstruct the validated implementation frontier, authoritative
> dependencies, and verification obligations from durable project
> artifacts without hidden session state.**

## 14.3 Descriptive Semantic Fidelity

**Status:** PROVISIONAL supporting discipline.

Hypothesis:

> **Non-normative artifacts may simplify canonical semantics but should
> not strengthen, weaken, collapse, or contradict their authoritative
> behavioral distinctions or claim boundaries.**

## 14.4 Consumable Causal Proof Authority

**Status:** PROJECT-SPECIFIC OBSERVATION.

The Standby realization demonstrated that transaction-scoped causal
evidence can function as consumable proof authority.

Additional evidence is required before generalization.

------------------------------------------------------------------------

# 15. Evidence Limitations

Protocol Discovery Methodology v1.1 is informed by one deep empirical
case.

The following limitations remain explicit.

## 15.1 Single-protocol evidence

Standby is substantial evidence, not universal proof.

## 15.2 EVM execution model

Several findings were validated under synchronous EVM transaction
semantics.

Asynchronous, cross-domain, delayed-finality, or off-chain settlement
systems may require refinements.

## 15.3 Stable upstream context

The methodology has not yet been deeply tested against a protocol whose
external economic reality changes materially during implementation.

## 15.4 Realization evidence

The most significant realization-assumption failure occurred in F5.

Additional protocols are needed to determine whether Realization
Dependency Validation should become a frozen stage or principle.

## 15.5 Review independence

Independent Conformance Review means independence from the
implementation agent's acceptance judgment.

It does not claim independent third-party formal verification.

------------------------------------------------------------------------

# 16. Next-Protocol Validation Agenda

The next protocol should deliberately challenge v1.1 rather than merely
reproduce Standby's workflow.

Priority hypotheses:

### H1 --- Realization Dependency Validation

Determine whether realization-critical platform assumptions can be
systematically identified and gated before implementation depends upon
them.

### H2 --- Implementation-State Reconstructibility

Determine whether a fresh competent implementer can reconstruct the
exact validated frontier without conversational history.

### H3 --- Discovery / Convergence / Implementation

Test whether the emerging three-layer structure generalizes beyond
Standby.

### H4 --- Asynchronous semantics

Stress Economic Atomicity, Attribution Persistence, causal continuity,
and Admission-Time Semantic Continuity in an asynchronous or
cross-domain system.

### H5 --- Correction Ownership

Test whether the Correction Ownership Procedure reliably prevents
implementation defects from causing unnecessary upstream semantic
rewrites.

### H6 --- Precommitted Verification Boundary

Test whether deriving the gate before implementation continues to reveal
conformance defects that would otherwise be rationalized after
implementation.

------------------------------------------------------------------------

# 17. Compact v1.1 Reference

## Derivation

> **Economic Reality → Coordination Problem → Coordination Analysis →
> Economic Agreement → Capability Requirements → Mechanism →
> Specification → Implementation**

## Implementation Convergence

> **Implementation Convergence = Semantic Completeness + Responsibility
> Clarity + Bounded Implementation Discretion + Verification-Gated
> Dependencies**

Interpretation:

> **Implementation Convergence concerns semantic discretion, not
> implementation effort.**

## Precommitted Verification Boundary

> **Derive what must be demonstrated before implementing the
> responsibility that will be judged against it.**

## Correction Ownership Procedure

> **Identify the violated claim and normative owner, classify the
> defect, correct the minimum authoritative layer, and reopen affected
> downstream gates.**

## Independent Conformance Review

> **The implementation agent's own acceptance judgment cannot be the
> sole basis for gate closure.**

## Bounded Implementation Discretion

> **Implementation may choose how to realize an assigned responsibility
> but may not change what responsibility exists, what it means, who owns
> it, which behavioral distinctions it preserves, which dependencies it
> requires, or what must be verified.**

## Prospective Semantic Support Test

> **When admission creates future obligations, establish at admission
> that the authoritative facts and realization capabilities required for
> future normative determinations remain supportable throughout the
> admitted semantic domain.**

------------------------------------------------------------------------

# 18. Version Determination

**Protocol Discovery Methodology v1.0:** validated by Standby with
refinements.

**Protocol Discovery Methodology v1.1:** FROZEN successor.

**Protocol Discovery Methodology v2.0:** not justified by current
evidence.

**Protocol Implementation Method:** emergent / provisional.

**Realization Dependency Validation:** provisional / priority
next-protocol hypothesis.

------------------------------------------------------------------------

# 19. Closing Principle

Protocol Discovery Methodology does not promise to eliminate
implementation uncertainty.

Its purpose is to determine **who has authority over meaning when
uncertainty appears**.

A conforming engineering process may discover new realization
constraints, better algorithms, platform behavior, verification
techniques, infrastructure requirements, and implementation defects.

Those discoveries should improve the realization.

They should not silently become permission to redefine the economic
agreement.

> **The methodology succeeds when implementation can discover what it
> must learn without acquiring uncontrolled authority to decide what the
> protocol was supposed to mean.**
