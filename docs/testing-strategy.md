# Standby Protocol — Canonical Testing Strategy

**Canonical Document #8 of 8**  
**Document:** `testing-strategy.md`  
**Canonical Layer:** Proof  
**Status:** **FINAL PASS / FROZEN**  
**Upstream:** `context.md` → `economic-agreement.md` → `mechanism.md` → `spec.md` → `architecture.md` → `state-machine.md` → `invariants.md`  
**Downstream:** Uniswap v4 Reference Realization / Implementation Handoff

---

# Part I — Canonical Verification Model

## 1. Purpose and Canonical Responsibility

### 1.1 Purpose

This document defines the minimum complete set of realization-independent verification and acceptance obligations required to establish that a concrete realization of Standby faithfully preserves the normative protocol truth defined by the upstream canonical package.

Upstream canonical documents remain the normative owners of economic rights and obligations, mechanism semantics, Specification requirements, architectural responsibilities, authoritative information and transition semantics, and invariant properties. This document does not redefine those requirements.

### 1.2 Canonical Responsibility

> **Canonical Testing Strategy defines the minimum complete set of realization-independent verification and acceptance obligations required to establish that a concrete realization faithfully preserves the normative behavior, authoritative derivations, authority and admission boundaries, transition consequences, invariant properties, information-continuity requirements, causal relationships, enforcement boundaries, and economic-finality requirements defined by the upstream canonical package.**

It defines what must be demonstrated for realization acceptance, including required positive behavior, prohibited behavior, derivation equivalence, invariant preservation, transition-result correctness, continuity across authoritative sequences, complete enforcement coverage, and zero-residue failure behavior, while leaving the concrete realization, testing technique, framework, instrumentation, and test implementation downstream.

> **Canonical verification specifies what must be demonstrated, not how the demonstration must be implemented.**

### 1.3 Canonical Unit

The canonical unit of this document is a **verification obligation**, not a concrete test case.

The relationship between verification obligations and concrete tests is non-bijective:

- one verification obligation may require multiple concrete tests or proof techniques;
- one concrete test may discharge multiple verification obligations;
- verification completeness is therefore determined by semantic proof coverage, not test-count symmetry.

### 1.4 Single Normative Ownership

O1/O2/O3, D1–D4, and invariant sections own requirement-specific proof targets and applicability mappings. Sections 7–10 own reusable cross-cutting verification semantics. A requirement-specific obligation must reference those semantics rather than redefine them.

---

## 2. Canonical Verification Families

### VF-1 — Positive Acceptance Verification

Positive Acceptance Verification establishes that when every applicable canonical condition is satisfied, behavior permitted or required by the upstream semantics can become authoritative and produces the required authoritative result.

Safety obtained by rejecting all behavior is not canonical correctness.

### VF-2 — Negative Rejection Verification

Negative Rejection Verification establishes that when a required canonical condition is not satisfied, the prohibited authoritative consequence cannot become authoritative.

Rejection must be tied to canonical invalidity rather than an invented stronger requirement.

### VF-3 — Authoritative Derivation Equivalence

Authoritative Derivation Equivalence establishes that every realization-derived economically meaningful fact, quantity, predicate, classification, relationship, consequence, or reconstruction equals the applicable canonical derivation from authoritative information.

Invariant preservation does not by itself prove derivation correctness.

### VF-4 — Transition-Result Verification

Transition-Result Verification establishes that a successful authoritative operation produces exactly the authoritative economic effects required by the applicable upstream semantics and that, where a canonical derived consequence applies, every authoritative economic effect dependent upon that consequence is the exact effect required upstream.

Correct admission does not establish correct authoritative result. Correct derivation of a consequence likewise does not by itself establish correct downstream behavior dependent upon that consequence.

### VF-5 — Invariant Preservation Verification

Invariant Preservation Verification establishes that every applicable invariant remains satisfied across the operations, consequences, states, and sequences whose authoritative effects can threaten it.

### VF-6 — Domain-Completeness Verification

Domain-Completeness Verification establishes that a required correctness property holds over the complete canonical domain to which it applies, including relevant temporal, causal, authority, information, reachable-state, economic-effect-path, derivation-surface, and failure domains.

Correctness on selected nominal paths does not establish domain completeness.

### VF-7 — Economic-Finality Verification

Economic-Finality Verification establishes that economically coupled authoritative effects become final only as the complete canonically required effect set and that unsuccessful attempts leave zero prohibited authoritative economic residue attributable to the failed attempt.

---

## 3. Verification Applicability

### 3.1 Applicability Rule

> **Verification Scope = Requirement Semantics → Applicable Failure Modes → Necessary Proof Obligations**

Each upstream normative requirement must be assigned every verification family necessary to exclude the realization-failure modes exposed by that requirement's semantic structure, and no verification family should be required merely by mechanical uniformity.

### 3.2 Admission-Boundary Requirements

Core families:

- VF-1 Positive Acceptance;
- VF-2 Negative Rejection.

Add:

- VF-3 when admission depends on a derived predicate;
- VF-6 when admission correctness spans multiple authoritative paths or a broader domain.

### 3.3 Derivation Requirements

Core family:

- VF-3 Authoritative Derivation Equivalence.

Add:

- VF-1/VF-2 where the derivation controls an authoritative boundary;
- VF-6 where the derivation must remain possible over time or across a broader information domain.

### 3.4 Authoritative-Result Requirements

Core family:

- VF-4 Transition-Result Verification.

Add:

- VF-3 where the result is derived;
- VF-7 where the result consists of economically coupled effects.

### 3.5 Preservation Requirements

Core family:

- VF-5 Invariant Preservation.

Add:

- VF-6 where preservation spans time, causal context, information lifetime, reachable state, or complete path coverage;
- VF-3 where preservation depends on derived quantities or classifications.

### 3.6 Composition / Finality Requirements

Core family:

- VF-7 Economic-Finality Verification.

Successful behavior must establish the complete required effect set; failed behavior must leave zero prohibited authoritative economic residue. Add VF-4 where successful result correctness must also be demonstrated.

### 3.7 Independent Boundary Discrimination

> **Boundary Completeness = Aggregate Decision Correctness + Independent Condition Discrimination**

When multiple independently necessary normative conditions govern an authoritative boundary, verification must be capable of demonstrating that each required condition independently participates in that boundary rather than merely showing rejection when several conditions fail simultaneously.

---

# Part II — Behavioral Verification Obligations

## 4. Authoritative Operation Verification

### 4.1 O1 — Commitment Establishment

#### O1-V1 — Establishment Authority Verification

Verification must establish that O1 can become authoritative only through authority valid for establishing the specific economic relationship, and that possession of invocation capability does not silently confer authoritative term-determination or fact-admission authority.

#### O1-V2 — Complete Establishment Predicate Verification

Verification must establish both acceptance when every applicable establishment condition is satisfied and rejection when any independently necessary condition is unsatisfied. Independent required conditions must be discriminated rather than tested only in aggregate-failure combinations.

#### O1-V3 — Prospective Backing Derivation Verification

Verification must establish that every economically meaningful prospective backing quantity, relationship, domain classification, and feasibility result used by O1 equals the canonical derivation from authoritative facts.

#### O1-V4 — Backing Admission Boundary Verification

Verification must establish that O1 can become authoritative exactly when the complete prospective post-establishment backing condition satisfies the applicable canonical feasibility requirement, including equality where the Specification permits exact sufficiency.

#### O1-V5 — Complete Establishment Result Verification

Verification must establish that successful O1 creates exactly one complete authoritative commitment relationship with all canonically required terms, entitlement, Capacity Obligation, initial Remaining Entitlement, backing-domain relationship, and authoritative basis for later reasoning, with no unauthorized additional economic effect.

#### O1-V6 — Admission Semantic Continuity Verification

Verification must establish across the complete applicable dependency lifetime that the economic semantics fixed through successful O1 remain those governing the admitted commitment. Later mutable configuration, shared-resource state, unrelated commitment state, derived consequences, or other subsequent changes must not retroactively reinterpret, weaken, strengthen, or otherwise alter those admitted semantics.

The authoritative basis required to preserve and reconstruct that meaning must additionally satisfy the applicable Section 8 information-continuity requirements.

#### O1-V7 — Establishment Information Continuity Verification

Verification must establish that every authoritative fact, distinction, relationship, consequence basis, or sufficient derivational basis created or fixed through O1 remains authoritatively available or deterministically reconstructible for exactly as long as later normative behavior depends upon it.

#### O1-V8 — Establishment Atomicity Verification

Verification must establish that the economically interdependent effects constituting successful O1 become authoritative as one complete permissible economic result and that no forbidden proper subset can become the final authoritative result.

#### O1-V9 — Failed Establishment Residue Verification

Verification must establish that failed O1 leaves no prohibited authoritative economic residue attributable to the attempt, including no partial entitlement, Capacity Obligation, Aggregate Remaining Entitlement increase, authoritative term fragment usable later, or false lifecycle consequence.

---

### 4.2 O2 — Commitment Exercise and Fulfillment

#### O2-V1 — Commitment Binding Verification

Verification must establish that every commitment-specific exercise attempt is bound to exactly one authoritative commitment whose rights and obligations may be affected.

#### O2-V2 — Exercise Invocation Authority Verification

Verification must establish both acceptance under valid commitment-specific exercise authority and rejection when the applicable invocation authority is absent.

#### O2-V3 — Validity Boundary Verification

Verification must independently prove the canonical Validity predicate and establish that invalid entitlements cannot become authoritatively exercised while valid entitlements are not rejected merely because of an invented stronger requirement.

#### O2-V4 — Exercisability Boundary Verification

Verification must independently prove the canonical Exercisability predicate and establish that Validity alone is insufficient for exercise when exercise conditions are unsatisfied, while a valid and exercisable entitlement is not rejected merely because it was previously non-exercisable.

#### O2-V5 — Exercise Extent Verification

Verification must establish that a requested exercise amount is accepted exactly when it satisfies the canonical positive and Remaining-Entitlement extent boundary, including full remaining exercise where permitted, and rejected when outside that boundary.

#### O2-V6 — Qualifying Execution Verification

Verification must establish that fulfillment-dependent effects cannot become authoritative unless the actual execution satisfies the canonical Protected Execution Service qualification semantics and is causally attributable to the targeted exercise.

#### O2-V7 — Beneficiary Delivery Verification

Verification must establish that qualifying execution contributes to fulfillment only to the extent the promised result is actually delivered for the Beneficiary's benefit.

#### O2-V8 — Fulfillment Causal Attribution Verification

Verification must independently establish the complete causal chain binding the targeted commitment, authoritative exercise, qualifying execution, Beneficiary delivery, fulfillment evidence, and resulting commitment-specific economic effect.

No execution, delivery, or fulfillment fact attributable to another relationship may substitute.

#### O2-V9 — Actual Attributable Fulfilled Amount Verification

Verification must establish that the authoritative Actual Attributable Fulfilled Amount equals the canonical derivation from admitted causal evidence, qualifying execution, and actual Beneficiary delivery.

#### O2-V10 — Fulfillment Conservation Verification

Verification must establish that the authoritative reduction in Remaining Entitlement equals exactly the canonical fulfillment-caused amount, with no greater reduction, smaller successful reduction, unrelated commitment reduction, duplicate attribution, or resurrection through later fulfillment-history mutation.

#### O2-V11 — Post-Fulfillment Obligation and Backing Verification

Verification must establish that the resulting Remaining Entitlement, Capacity Obligation consequence, Aggregate Remaining Entitlement participation, and every affected backing relationship equal the canonical post-fulfillment result and remain sufficient where required.

#### O2-V12 — Exercise / Fulfillment Economic Finality Verification

Verification must establish that successful O2 finalizes the complete required effect set—correct target, authority, Validity, Exercisability, qualifying attributable execution, Beneficiary delivery, Actual Attributable Fulfilled Amount, exact entitlement reduction, resulting obligation consequence, and applicable backing preservation—and that failure at any economically meaningful stage leaves zero prohibited authoritative economic residue.

> **Causal Correctness = Valid Cause Chain + Correct Consequence**

---

### 4.3 O3 — Backing-Affecting Shared-Resource Transition

#### O3-V1 — Backing-Affecting Transition Classification Verification

Verification must establish that O3 classification is determined by authoritative economic effect rather than function name, interface, caller, router, component, or expected implementation path.

Every authoritative transition capable of changing relied-upon Supporting Capacity while binding Capacity Obligations exist must be included in the applicable classification domain.

#### O3-V2 — Affected Backing Relationship Verification

Verification must establish that every backing relationship, service, backing domain, and interdependent relationship affected by the proposed shared-resource transition is identified according to the canonical backing-domain semantics.

#### O3-V3 — Binding Capacity Obligation Verification

Verification must establish that the set of commitments whose Capacity Obligations are currently binding, and therefore participate in applicable Aggregate Remaining Entitlement or joint feasibility, equals the canonical derivation.

Resource pressure must not alter this obligation-side determination.

#### O3-V4 — Prospective Supporting Capacity Verification

Verification must establish that Supporting Capacity for the prospective resource state equals the canonical Protected Execution Service derivation, including execution semantics, qualification conditions, boundary treatment, and conservative representability.

#### O3-V5 — Prospective Backing Feasibility Verification

Verification must establish that the prospective post-transition backing condition is evaluated under the correct scalar or multidimensional feasibility relation and that interdependent services are not falsely treated as independent.

#### O3-V6 — Backing Preservation Boundary Verification

Verification must establish positive acceptance when the proposed O3 result preserves every applicable backing relationship and negative rejection when the proposed result would violate one.

Equality must be accepted where the canonical feasibility semantics permit exact sufficiency.

#### O3-V7 — Complete Backing Enforcement Verification

Verification must establish that every economically authoritative pathway capable of impairing an applicable backing relationship encounters the applicable preservation constraint before a prohibited result can become authoritative.

Correct enforcement on one nominal path does not establish complete enforcement.

> **Effect-Defined Constraint ⇒ Effect-Complete Path Verification**

#### O3-V8 — Backing-Pressure Failure Integrity Verification

Verification must establish that a backing-threatening O3 attempt cannot be made acceptable by reducing entitlement, manufacturing fulfillment, releasing a still-binding commitment, changing admitted semantics, reclassifying another commitment, or otherwise mutating the obligation side without independent canonical authority.

Failure must leave no prohibited authoritative economic residue.

---

## 5. Derived-Consequence Verification

Derived consequences are authoritative because their complete canonical predicates hold. They are not required to be implemented as dedicated lifecycle operations.

> **Derived Consequence Verification = Derivation Correctness + Consequence Correctness + Dependency Continuity**

### 5.1 D1 — Validity Consequence

#### D1-V1 — Validity Derivation Verification

Verification must establish that Validity equals the canonical derivation from successful establishment and the applicable authoritative validity-ending conditions.

#### D1-V2 — Validity Consequence Verification

Verification must establish that when the Validity predicate holds, every later authoritative behavior depending upon Validity consumes that consequence correctly; when the predicate does not hold, Validity-dependent behavior cannot proceed as though it did.

#### D1-V3 — Validity Continuity Verification

Verification must establish that the authoritative basis required to determine Validity remains available or reconstructible for its complete normative dependency lifetime.

### 5.2 D2 — Exercisability Consequence

#### D2-V1 — Exercisability Derivation Verification

Verification must establish that Exercisability equals the canonical derivation from current Validity and all authoritative exercise conditions.

#### D2-V2 — Exercisability Consequence Verification

Verification must establish that exercisable commitments are eligible for O2 subject to other applicable O2 conditions and that mere Exercisability creates no fulfillment, entitlement reduction, release, or new Capacity Obligation.

#### D2-V3 — Exercisability Continuity Verification

Verification must establish that every authoritative basis required to determine current Exercisability remains available or reconstructible while later normative behavior depends upon it.

### 5.3 D3 — Fulfillment Exhaustion Consequence

#### D3-V1 — Fulfillment Exhaustion Derivation Verification

Verification must establish that fulfillment exhaustion holds exactly when authoritative attributable fulfillment has reduced Remaining Entitlement to zero.

#### D3-V2 — Fulfillment Exhaustion Cause Verification

Verification must establish that zero Remaining Entitlement is classified as fulfillment exhaustion only when the zero arose from canonical attributable fulfillment rather than release, mutation, reconstruction error, or unrelated cause.

#### D3-V3 — Fulfillment Exhaustion Consequence Verification

Verification must establish that exhaustion removes the commitment's Remaining Entitlement from current backing burden, ends its Capacity Obligation because of fulfillment, and prevents further positive exercise without a separate discretionary completion operation.

#### D3-V4 — Fulfillment Exhaustion Continuity Verification

Verification must establish that any future normative distinction depending upon fulfillment exhaustion remains authoritatively knowable for the complete dependency lifetime.

### 5.4 D4 — Non-Fulfillment Release Consequence

#### D4-V1 — Non-Fulfillment Release Derivation Verification

Verification must establish that D4 occurs exactly when the canonical validity-ending condition releases a still-unfulfilled positive remainder.

#### D4-V2 — Release Cause Integrity Verification

Verification must establish that D4 is caused by the applicable validity-ending semantics rather than by manufactured fulfillment, entitlement rewrite, unrelated commitment state, resource pressure, or discretionary lifecycle choice.

#### D4-V3 — Released Obligation Consequence Verification

Verification must establish that D4 removes the released remainder from current Capacity Obligation and backing burden without representing that remainder as Actual Attributable Fulfilled Amount, fulfillment exhaustion, or delivery.

Historical Remaining Entitlement need not be rewritten to zero.

#### D4-V4 — Release Historical Continuity Verification

Verification must establish that any historical distinction between fulfillment and non-fulfillment release required by later normative reasoning remains authoritative or reconstructible for its complete dependency lifetime, and that release finality cannot be silently reversed without a new authoritative O1 establishment.

---

# Part III — Cross-Cutting Proof Closure

## 6. Invariant Verification Closure

Operation-level proofs establish local transition correctness. They do not by themselves establish all global properties required by the invariant set.

> **Invariant Acceptance = Local Transition Proof + Global Property Closure**

The `IVC` namespace identifies invariant-verification-closure obligations. It does not imply a one-to-one relationship with canonical invariants.

### IVC-01 — Establishment Exclusivity Verification
**Primary invariant trace:** INV-01

Verification must establish across the complete establishment domain that authoritative commitment existence and relationship creation can arise only from successful canonical O1 establishment.

### IVC-02 — Admitted-Semantics Domain Verification
**Primary invariant trace:** INV-02

Verification must establish across every future dependency and relevant configuration mutation that admitted commitment semantics remain stable and are not retroactively reinterpreted.

### IVC-03 — External Fact Admission Exclusivity Verification
**Primary invariant trace:** INV-03

Where external facts can govern Standby behavior, verification must establish that only facts admitted through the applicable authoritative fact-admission boundary may acquire canonical authority.

### IVC-04 — Admitted Fact Consumption Verification
**Primary invariant trace:** INV-03

Verification must establish that once a fact is authoritatively admitted, all downstream behavior consumes the authoritative admitted fact or canonical reconstruction rather than an unadmitted, stale, caller-asserted, or implementation-local substitute.

### IVC-05 — Dependency-Lifetime Reconstructibility Verification
**Primary invariant trace:** INV-04

Verification must establish that every future-required authoritative fact, distinction, relationship, consequence, or derivational basis remains knowable for exactly its normative dependency lifetime.

### IVC-06 — Commitment Derivation Coverage Verification
**Primary invariant trace:** INV-05

Verification must establish the correctness of every canonical commitment-derived property across every authoritative context in which it governs behavior.

### IVC-07 — Exercise Boundary Completeness Verification
**Primary invariant trace:** INV-06

Verification must establish the complete Validity, Exercisability, authority, extent, and commitment-specific exercise boundary across all applicable states and sequences.

### IVC-08 — Cross-Exercise Fulfillment Non-Duplication Verification
**Primary invariant trace:** INV-07

Verification must establish that one execution, delivery, or fulfillment fact cannot be attributed to multiple exercises or commitments unless the upstream semantics independently authorize such attribution.

### IVC-09 — Fulfillment Conservation Across Sequences Verification
**Primary invariant trace:** INV-08

Verification must establish exact fulfillment conservation over repeated partial exercises, complete exercise, intervening shared-resource transitions, and later release/exhaustion consequences.

### IVC-10 — Economic Cause Domain Verification
**Primary invariant trace:** INV-09

Verification must establish that economically distinct causes—especially fulfillment exhaustion and non-fulfillment release—remain distinguishable wherever later normative behavior depends upon the distinction.

### IVC-11 — Backing Derivation Coverage Verification
**Primary invariant trace:** INV-10

Verification must establish complete correctness of backing-domain membership, aggregation, Supporting Capacity derivation, joint feasibility, and cross-domain non-substitution across the canonical derivation domain.

### IVC-12 — Backing Sufficiency Across Reachable States Verification
**Primary invariant trace:** INV-11

Verification must establish that every reachable authoritative state produced by permitted operations and derived consequences satisfies the applicable backing-sufficiency relationship whenever a binding Capacity Obligation exists.

**INV-12 — Complete Backing Enforcement requires no additional IVC obligation beyond complete discharge of O3-V7 across the Section 10 economic-effect path domain.**

### IVC-13 — Atomic Composition Coverage Verification
**Primary invariant trace:** INV-13

Verification must establish complete-or-zero authoritative economic finality across every economically coupled operation and every economically meaningful failure position capable of exposing a forbidden partial result.

---

## 7. Authoritative Derivation Equivalence

> **Derivation Verification = Implementation Result ≡ Independent Normative Oracle**

Verification of an authoritative derivation must compare the realization's result against an independently specified expression of the normative derivation or an equivalent independent proof basis. Recomputing the expected result through the same implementation logic does not establish derivation equivalence.

### 7.1 Commitment Derivations

Verification must cover, as applicable:

- Validity;
- Exercisability;
- Remaining Entitlement;
- permissible exercise extent;
- Capacity Obligation binding status;
- backing-domain participation;
- every authoritative commitment property controlling later economic behavior.

### 7.2 Fulfillment Derivations

Verification must cover, as applicable:

- qualifying execution status;
- Beneficiary-delivery qualification;
- causal attribution;
- Actual Attributable Fulfilled Amount;
- the complete derivational chain from authoritative causal evidence to the final fulfillment amount.

### 7.3 Backing Derivations

Verification must cover, as applicable:

- affected backing relationship;
- applicable backing domain;
- binding obligation set;
- Aggregate Remaining Entitlement where scalar aggregation is applicable;
- Supporting Capacity;
- current feasibility;
- prospective Supporting Capacity;
- prospective feasibility;
- joint or multidimensional feasibility where required.

### 7.4 Derived-Consequence Derivations

Verification must independently establish the authoritative derivation of D1, D2, D3, and D4.

### 7.5 Prospective-State Derivations

Every economically meaningful hypothetical post-state quantity, predicate, classification, relationship, or feasibility result used to admit or reject an operation must be independently checked against the canonical prospective-state derivation.

### 7.6 Authoritative Reconstruction

Every later reconstructed economically meaningful fact, quantity, classification, relationship, consequence, or cause used by future authoritative behavior must equal the canonical reconstruction from authoritative inputs.

### 7.7 Independent Normative Oracle

Expected results must come from an independently expressed normative derivation, mathematical model, independently implemented oracle, exhaustive proof basis, or another demonstrably independent expression of upstream semantics.

### 7.8 Protected Execution Service Qualification Equivalence

Verification must establish that every qualification rule, limiting condition, boundary convention, execution semantic, and other Protected Execution Service semantic that the Specification requires to be common between Supporting Capacity determination and successful fulfillment is applied normatively identically in both contexts.

Where the Specification defines an inclusive or exclusive qualification boundary, the realization must produce the same authoritative boundary interpretation when determining Supporting Capacity and when determining whether actual execution qualifies for fulfillment.

Where Supporting Capacity depends upon authoritative AMM execution semantics, the realization must not substitute an approximation that can produce an authoritative result different from the Specification-defined result.

This requirement does not require shared implementation code between capacity determination and fulfillment determination. It requires semantic equivalence of the authoritative results.

---

## 8. Information Continuity and Reconstructibility

> **Information Continuity = Sufficient Authoritative Basis × Dependency Lifetime**

Verification of authoritative information continuity must prove that sufficient authoritative information remains available, directly or through deterministic reconstruction, for the complete lifetime of every normative dependency on that information. It must also distinguish required continuity from unnecessary permanent retention.

### IC-V1 — Admission-Basis Continuity Verification

Verification must establish that the authoritative basis fixing admitted economic meaning remains sufficient to preserve and reconstruct that meaning for its full dependency lifetime.

### IC-V2 — Commitment-State Reconstructibility Verification

Verification must establish that every commitment fact and derived commitment property required by future canonical behavior remains directly knowable or deterministically reconstructible.

### IC-V3 — Fulfillment and Causal-History Continuity Verification

Verification must establish that fulfillment history and causal distinctions remain knowable for exactly as long as future behavior depends upon them, while transition-local evidence may disappear once no independent future dependency remains.

### IC-V4 — Backing-State Reconstructibility Verification

Verification must establish that every backing-domain relationship, binding obligation determination, and backing derivation required by future behavior remains supported by sufficient authoritative information.

### IC-V5 — Economic-Cause Continuity Verification

Verification must establish that economically distinct causes whose distinction governs future behavior remain distinguishable for the complete dependency lifetime.

### IC-V6 — Dependency-Termination Verification

Verification must establish that information may cease to be normatively required only when every canonical dependency on that information has ended; permanent retention must not be treated as a canonical requirement absent independent upstream necessity.

### IC-V7 — Authoritative Basis Mutation Verification

Verification must establish that mutation, replacement, reuse, versioning, or reconstruction of authoritative bases cannot silently alter the economic meaning of already-admitted relationships or destroy required future knowability.

### IC-V8 — Cross-Operation Dependency Continuity Verification

Verification must establish across multi-operation histories that each later authoritative operation consumes all prior authoritative facts and consequences on which its correctness canonically depends.

---

## 9. Economic Finality and Failure Residue

> **Finality Proof = Exact Success Effect Set + Failure-Point Closure + Zero Economic Residue + No Latent Mutation**

Verification of an economically coupled authoritative operation must establish the completeness and exclusivity of its successful authoritative effect set, cover every economically distinguishable failure position capable of producing partial effects, prove zero prohibited authoritative economic residue on failure, and establish that no latent or compensating mutation changes later canonical behavior.

### EF-V1 — Complete Economic Effect-Set Verification

Verification must identify the complete set of authoritative economic effects that jointly constitute successful completion of each economically coupled operation.

### EF-V2 — Successful Economic Finality Verification

Verification must establish that all required members of that effect set become authoritative when the operation succeeds.

### EF-V3 — Success-Result Exclusivity Verification

Verification must establish that successful completion produces no unauthorized additional economic effect and no canonically forbidden alternative result.

### EF-V4 — Economically Relevant Failure-Point Coverage Verification

Verification must cover every economically distinguishable failure position at which a forbidden proper subset of interdependent effects could otherwise become authoritative.

### EF-V5 — Failed-Operation Residue Verification

Verification must establish that failure leaves zero prohibited authoritative economic residue attributable to the failed attempt.

This requirement does not mean that absolutely no internal computation or ephemeral data existed; it concerns authoritative economic residue.

### EF-V6 — Failure Non-Substitution Verification

Verification must establish that failure cannot be made superficially safe through a compensating, substituting, or obligation-rewriting mutation that itself changes canonical economic meaning.

### EF-V7 — Post-Failure Sequence Integrity Verification

Verification must establish through later canonical behavior that no latent mutation, stale evidence, partially admitted fact, hidden obligation change, or other residue from a failed attempt alters later authoritative results.

---

## 10. Verification Domain Completeness

Domain-complete verification must prove correctness across every dimension necessary to exclude a semantically distinct realization failure mode.

### 10.1 Temporal Domain

Verification must cover relevant transitions across time-dependent predicate changes, including future exercisability, validity-ending conditions, and dependency-lifetime transitions.

### 10.2 Causal Domain

Verification must cover distinct commitment, exercise, execution, delivery, fulfillment, and release causes and must exclude causal substitution across relationships.

### 10.3 Authority Domain

Verification must cover every normative authority class and every implementation pathway capable of exercising or bypassing those authority boundaries.

### 10.4 Information Domain

Verification must cover direct authoritative facts, deterministically reconstructed information, authoritative external/shared-resource facts, and transition-local causal evidence according to their canonical lifetimes.

### 10.5 Reachable-State Domain

Verification must cover the reachable authoritative states and sequences that can materially alter commitment, fulfillment, backing, consequence, or continuity semantics.

### 10.6 Economic-Effect Path Domain

Where a canonical constraint applies by economic effect, verification must cover the complete set of authoritative transitions capable of producing that effect, not merely enumerated function names, interfaces, callers, components, or expected paths.

### 10.7 Derivation-Surface Domain

Verification must cover every implementation surface that computes, caches, reconstructs, classifies, approximates, or otherwise supplies an economically meaningful canonical derivation.

### 10.8 Failure Domain

Verification must cover every economically distinguishable failure position capable of leaving partial authoritative consequences, corrupting authoritative information, or changing later canonical behavior.

### 10.9 Sequence Semantics Preservation

Domain-complete sequence verification must evaluate each authoritative operation or derived consequence against the complete authoritative facts and consequences produced by its actual preceding sequence.

Verification must not impose order independence, commutativity, or equivalent outcomes among independently permissible operation orderings unless the upstream canonical semantics independently require such equivalence.

Different permitted operation orders may legitimately produce different later eligibility, derived consequences, Capacity Obligations, backing determinations, or authoritative results when earlier authoritative effects change the normative basis for later behavior.

Sequence completeness therefore requires correctness of each permitted sequence under its actual authoritative history, not equivalence among different sequences.

---

# Part IV — Traceability and Acceptance

## 11. Canonical Traceability Model

### 11.1 Traceability Rule

Every canonical verification obligation must identify its upstream normative origin.

Traceability records correspondence and does not create new normative behavior.

The canonical chain is:

> **Specification Requirement → Architecture Responsibility → State Operation / Derived Consequence → Invariant Protection where applicable → Verification Obligation → Downstream Realization Evidence**

### 11.2 Operation / Consequence Verification Traceability

#### O1 — Commitment Establishment

| Verification obligation | Principal Specification basis | Architecture realization | Principal invariant protection |
|---|---|---|---|
| O1-V1 | SPEC-E1; SPEC-A1, A3 | A2, A6; A1 for result | INV-01 |
| O1-V2 | SPEC-E1–E4; applicable SPEC-A/B | A2, A3, A4, A6 | INV-01; INV-03 where applicable |
| O1-V3 | SPEC-E4; SPEC-B1–B6, B8, B9, B11–B12 as applicable | A3, A4 | INV-10 |
| O1-V4 | SPEC-E4; SPEC-B9 | A2, A4 | INV-11 |
| O1-V5 | SPEC-E3, E5 | A1, A2, A3 | INV-01, INV-05 |
| O1-V6 | SPEC-E2, E5; SPEC-A4; applicable SPEC-C | A1, A6, A8 | INV-02 |
| O1-V7 | SPEC-E5; SPEC-C1–C3, C6–C7 | A8 | INV-04 |
| O1-V8 | SPEC-E5 | A7 | INV-13 |
| O1-V9 | SPEC-E6 | A2, A7 | INV-01, INV-13 |

#### O2 — Commitment Exercise and Fulfillment

| Verification obligation | Principal Specification basis | Architecture realization | Principal invariant protection |
|---|---|---|---|
| O2-V1 | SPEC-X1; SPEC-A2, A7–A8 | A1, A2, A6 | INV-06, INV-07 |
| O2-V2 | SPEC-X2; SPEC-A1–A2 | A2, A6 | INV-06 |
| O2-V3 | SPEC-X3; SPEC-D1–D2 | A2, A3 | INV-05, INV-06 |
| O2-V4 | SPEC-X4; SPEC-D3–D4 | A2, A3 | INV-05, INV-06 |
| O2-V5 | SPEC-X5 | A2, A3 | INV-05, INV-06 |
| O2-V6 | SPEC-X6 | A2, A3, A5 | INV-07 |
| O2-V7 | SPEC-X7 | A3, A5 | INV-07 |
| O2-V8 | SPEC-X6–X8; SPEC-A8–A11 | A5, A6 | INV-07, INV-09 |
| O2-V9 | SPEC-X8 | A3, A5 | INV-07 |
| O2-V10 | SPEC-X9–X11 | A1, A3, A5 | INV-08; INV-09 where applicable |
| O2-V11 | SPEC-X11–X12; SPEC-B7 | A1, A3, A4 | INV-10, INV-11; INV-12 where applicable |
| O2-V12 | SPEC-X12–X14 | A2, A7 | INV-13 |

#### O3 — Backing-Affecting Shared-Resource Transition

| Verification obligation | Principal Specification basis | Architecture realization | Principal invariant protection |
|---|---|---|---|
| O3-V1 | S1/O3; SPEC-C8; SPEC-B10 | A2, A4 | INV-12 |
| O3-V2 | SPEC-B8, B10–B12; SPEC-C10 | A1, A3, A4 | INV-10 |
| O3-V3 | E5–E6; applicable SPEC-D | A1, A3 | INV-05, INV-10 |
| O3-V4 | E7; SPEC-B1–B6 | A3, A4 | INV-10 |
| O3-V5 | SPEC-B8, B10–B12 | A3, A4 | INV-10, INV-11 |
| O3-V6 | SPEC-B10 | A2, A4 | INV-11, INV-12 |
| O3-V7 | SPEC-C8; SPEC-B10 | A2, A4 | INV-12 |
| O3-V8 | SPEC-B10; SPEC-A4, A10–A11; applicable SPEC-D/C | A1, A2, A4, A6, A7 | INV-02, INV-07, INV-08, INV-13 as applicable |

#### D1–D4 — Derived Consequences

| Verification obligation | Principal Specification basis | Architecture realization | Principal invariant protection |
|---|---|---|---|
| D1-V1 | SPEC-D1, D10–D11 | A3 | INV-05 |
| D1-V2 | SPEC-D1–D2, D11 | A1, A2, A3 | INV-05 |
| D1-V3 | SPEC-C1–C3, C6–C7 | A8 | INV-04 |
| D2-V1 | SPEC-D3, D10–D11 | A3 | INV-05 |
| D2-V2 | SPEC-D3–D4, D11 | A1, A2, A3 | INV-05; INV-06 when exercise is attempted |
| D2-V3 | SPEC-C1–C3, C6–C7 | A8 | INV-04 |
| D3-V1 | SPEC-D5–D6, D10–D11; SPEC-X11 | A3 | INV-05, INV-08 |
| D3-V2 | SPEC-D5, D8 | A3, A5 | INV-08, INV-09 |
| D3-V3 | SPEC-D6, D11 | A1, A2, A3 | INV-05, INV-08, INV-09 |
| D3-V4 | SPEC-C1–C4, C6–C7 | A8 | INV-04, INV-09 |
| D4-V1 | SPEC-D7, D10–D12 | A3 | INV-05 |
| D4-V2 | SPEC-D7–D8 | A3; A5 where causal distinction applies | INV-08, INV-09 |
| D4-V3 | SPEC-D7–D8, D13 | A1, A2, A3 | INV-05, INV-09 |
| D4-V4 | SPEC-C1–C4, C6 | A8 | INV-04, INV-09 |

### 11.3 Cross-Cutting Verification Traceability

#### Invariant Closure

| Closure obligation | Primary invariant basis |
|---|---|
| IVC-01 | INV-01 |
| IVC-02 | INV-02 |
| IVC-03 | INV-03 |
| IVC-04 | INV-03 |
| IVC-05 | INV-04 |
| IVC-06 | INV-05 |
| IVC-07 | INV-06 |
| IVC-08 | INV-07 |
| IVC-09 | INV-08 |
| IVC-10 | INV-09 |
| IVC-11 | INV-10 |
| IVC-12 | INV-11 |
| IVC-13 | INV-13 |

INV-12 is discharged through O3-V7 plus complete Section 10 economic-effect-path coverage.

#### Derivation Families

| Derivation class | Principal Specification basis | Architecture |
|---|---|---|
| Commitment derivations | E1–E6; SPEC-D1–D4; applicable SPEC-C3 | A1, A3, A8 |
| Fulfillment derivations | E4; SPEC-X6–X9; SPEC-A8–A11 | A3, A5 |
| Backing derivations | E6–E7; SPEC-B1–B12 | A3, A4 |
| Derived-consequence derivations | SPEC-D1–D13 | A3; A8 for future dependency |
| Prospective-state derivations | SPEC-E4; SPEC-B7, B9, B10, B12 | A3, A4 |
| Authoritative reconstruction | SPEC-C1–C3, C6–C7 | A3, A8 |
| Protected Execution Service qualification equivalence | SPEC-B1, SPEC-B3, applicable SPEC-B5 | A3, A5; A4 where backing consumes the determination |

#### Information Continuity

- IC-V1 → SPEC-C1–C3; admitted semantics from E1/E5 and SPEC-A4.
- IC-V2 → SPEC-C1–C3, C6–C7.
- IC-V3 → SPEC-C1–C6 plus SPEC-A9–A11 where causal history remains required.
- IC-V4 → SPEC-C1–C3, C7, C10.
- IC-V5 → SPEC-C4, C6.
- IC-V6 → SPEC-C1, C14.
- IC-V7 → SPEC-A4; SPEC-C1–C4.
- IC-V8 → SPEC-C7, C9, C11.

#### Economic Finality

The EF family principally realizes:

- SPEC-E5–E6 for O1;
- SPEC-X12–X14 for O2;
- applicable SPEC-B7/B10 and SPEC-C12 for backing-affecting composition;
- INV-13 across economically coupled operation surfaces.

#### Domain Completeness

Principal traces include:

- temporal completeness → SPEC-C1, C6, C11;
- causal completeness → SPEC-A8–A11; SPEC-C4/C11;
- authority completeness → SPEC-A1–A6; SPEC-C8;
- information completeness → SPEC-C1–C7;
- reachable-state completeness → SPEC-C11–C12;
- economic-effect path completeness → SPEC-C8;
- derivation-surface completeness → S3; SPEC-C3;
- failure-domain completeness → SPEC-E6, SPEC-X14, SPEC-C11–C12;
- Sequence Semantics Preservation → SPEC-C7, SPEC-C11, SPEC-C13.

### 11.4 Specification-Level Bidirectional Coverage

Every Specification family has at least one verification destination:

- **SPEC-E** → O1 obligations plus applicable derivation, continuity, finality, and domain verification.
- **SPEC-X** → O2 obligations plus applicable derivation, invariant, continuity, and finality verification.
- **SPEC-B** → O1/O2/O3 backing obligations plus derivation, qualification-equivalence, invariant, and domain verification.
- **SPEC-D** → D1–D4 obligations plus O2/O3 consumption where applicable.
- **SPEC-A** → O1/O2/O3 authority/admission/attribution obligations plus invariant and domain closure.
- **SPEC-C** → information continuity, derived-consequence composition, domain completeness, sequence semantics, finality, and authoritative-boundary verification.

Conversely, every O-V, D-V, IVC, IC, EF, derivation, and domain-completeness obligation has an identifiable upstream normative basis.

No verification obligation is justified solely by testing convenience.

---

## 12. Canonical Realization Acceptance

### 12.1 Acceptance Standard

A realization is canonically acceptable only when every applicable verification obligation in this document has been discharged by sufficient evidence.

Canonical acceptance is determined by **semantic proof completeness**, not an arbitrary implementation-level coverage metric.

### 12.2 Two-Sided Boundary Acceptance

Every normative boundary requiring acceptance/rejection proof must establish both:

1. prohibited behavior cannot become authoritative; and
2. behavior permitted or required by canonical semantics can become authoritative when every applicable condition is satisfied.

A realization that remains safe only by rejecting valid canonical behavior is incorrect.

### 12.3 Independent Derivation Acceptance

A realization cannot establish canonical derivation correctness by using the same implementation logic to compute both the actual and expected result.

Every authoritative derivation must be independently verified against the applicable canonical derivation or equivalent proof basis.

### 12.4 Invariant Acceptance

Invariant preservation is necessary but insufficient.

Canonical acceptance requires both invariant preservation and authoritative derivation equivalence, together with every other applicable verification family.

### 12.5 Enforcement Acceptance

Correctness on nominal protocol paths is insufficient where a requirement applies by economic effect.

Acceptance requires complete coverage of every authoritative pathway capable of producing the governed economic effect.

### 12.6 Economic-Finality Acceptance

Successful coupled operations must finalize exactly the complete canonical economic result.

Failed attempts must leave zero prohibited authoritative economic residue attributable to the attempt and must not alter later canonical behavior through latent or compensating mutation.

### 12.7 Traceability Acceptance

Every verification obligation used for acceptance must trace backward to legitimate upstream normative authority, and every upstream canonical requirement must possess adequate downstream proof coverage.

---

# Part V — Realization Boundary

## 13. Downstream Realization Boundary

### 13.1 What This Document Does Not Prescribe

This canonical Testing Strategy does not require:

- a particular programming language;
- Solidity test contracts;
- Foundry, Hardhat, Echidna, Halmos, Certora, or another framework;
- unit tests as a particular canonical category;
- fuzzing as a mandatory proof technique;
- stateful invariant handlers as a particular implementation;
- a specific number of tests;
- a specific code-coverage percentage;
- a particular mock, fork, or local-chain environment;
- a specific transaction rollback mechanism;
- a specific Uniswap v4 callback configuration;
- a specific router design;
- a specific state representation;
- a specific instrumentation or event schema;
- a particular formal-verification technique.

Those are downstream realization and verification-engineering choices.

### 13.2 Permissible Downstream Proof Techniques

A downstream implementation plan may use any combination of techniques sufficient to discharge the canonical obligations, including:

- deterministic unit-level proof examples;
- transition tests;
- integration tests;
- boundary tests;
- property-based fuzzing;
- stateful invariant campaigns;
- adversarial traces;
- differential or model-based testing;
- formal proofs;
- static analysis;
- end-to-end acceptance traces;
- realization-specific conformance tests.

The technique is not canonical. The proof obligation is.

### 13.3 Reference-Realization Boundary

The ETHGlobal Uniswap v4 reference realization may require realization-specific proof obligations for:

- hook permission completeness;
- generic-router compatibility;
- bounded live-commitment representation;
- slot/history reuse;
- transaction-scoped causal evidence;
- concrete Supporting Capacity derivation over Uniswap v4 state;
- bounded-gas feasibility;
- concrete A1–A8 responsibility assignment.

Those realization-specific tests must trace back to this canonical Testing Strategy and the frozen upstream package. They do not redefine general Standby verification semantics.

### 13.4 Final Status

The assembled canonical Testing Strategy has passed:

- verification-family completeness;
- requirement-to-verification applicability completeness;
- O1 verification completeness;
- O2 verification completeness;
- O3 verification completeness;
- D1–D4 verification completeness;
- invariant verification closure;
- authoritative derivation-equivalence completeness;
- information-continuity completeness;
- economic-finality completeness;
- domain-completeness review;
- internal consistency and semantic completeness;
- bidirectional traceability;
- upstream artifact fidelity;
- hidden-requirement / no-strengthening / no-weakening review;
- realization independence;
- correction-regression review; and
- final post-correction review.

# **FINAL PASS / FROZEN**

No semantic change may be made to this document unless a later canonical-package consistency gate reveals a genuine contradiction requiring the affected frozen canonical layer to be reopened.
