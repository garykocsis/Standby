# Standby Protocol — Canonical Architecture

**Document:** `architecture.md`  
**Canonical Layer:** Realization  
**Status:** **FINAL PASS / FROZEN**  
**Upstream:** `context.md` → `economic-agreement.md` → `mechanism.md` → `spec.md`  
**Downstream:** `state-machine.md` → `invariants.md` → `testing-strategy.md`

---

## 1. Purpose and Scope

### 1.1 Architectural Responsibility

Canonical Architecture defines the minimum organization of authoritative responsibilities, authority and trust boundaries, enforcement boundaries, information-continuity responsibilities, and required interaction paths through which the complete normative behavior of the Protocol Specification can be realized without authority, enforcement, attribution, continuity, trust, or economic-finality gaps.

Architecture determines:

- which authoritative responsibilities must exist;
- what each responsibility may authoritatively determine or cause;
- what other responsibilities may rely upon it;
- which authority, trust, enforcement, attribution, and continuity boundaries must be preserved; and
- how those responsibilities must compose to realize the Protocol Specification.

Architecture does not prescribe concrete state representation, contract decomposition, storage layout, interface design, algorithms, integration mechanics, or implementation technique except where a structural constraint is itself necessary to realize a frozen Specification requirement.

### 1.2 Architecture / Realization Boundary

A decision is architectural when leaving it unresolved would delegate a protocol-correctness decision concerning authoritative responsibility, authority, trust, enforcement, continuity, attribution, or required interaction composition to implementation.

A decision is realization-level when multiple implementations can vary that decision while preserving the same architectural responsibilities, boundaries, and interaction semantics.

Accordingly:

- authoritative state ownership responsibility is architectural; storage representation is realization-level;
- authoritative economic determination is architectural; derivation algorithm implementation is realization-level;
- authoritative external-fact admission is architectural when external facts are required; oracle or evidence technology is realization-level;
- atomic economic composition is architectural; the mechanism used to achieve transaction-level composition is realization-level;
- complete enforcement topology is architectural; specific callbacks or interception mechanisms are realization-level;
- causal exercise-to-fulfillment integrity is architectural; the carrier of causal evidence is realization-level; and
- authoritative information continuity is architectural; persistence strategy is realization-level.

Architecture owns continuity responsibility, not persistence strategy.

### 1.3 Realization Independence

No implementation structure is canonical merely because it is used by the Standby ETHGlobal reference realization.

A conforming realization may organize contracts, modules, routers, state representations, execution paths, and integration mechanisms differently provided that it preserves every architectural responsibility, boundary, interaction requirement, and upstream normative requirement defined or referenced by this document.

---

## 2. Upstream Normative Dependencies

### 2.1 Upstream Semantic Ownership

Canonical Architecture consumes the economic and behavioral semantics established by the upstream canonical documents.

The Economic Agreement remains authoritative for the economic rights, obligations, establishment conditions, persistence conditions, fulfillment conditions, and release conditions that define the Standby economic relationship.

The Mechanism remains authoritative for the necessary causal behavior through which that economic relationship is preserved.

The Protocol Specification remains authoritative for normative economic definitions and derivations, authoritative operations, derived consequences, authority semantics, attribution semantics, backing semantics, failure semantics, composition requirements, and information-continuity requirements.

Where this document refers to a normative economic or behavioral concept defined upstream, the upstream definition remains authoritative.

Architecture assigns responsibility for realizing those semantics. It does not independently redefine them.

### 2.2 Specification Inputs

Architecture consumes, among other Specification semantics:

- Authoritative Commitment Terms;
- Entitlement Validity;
- Entitlement Exercisability;
- Actual Attributable Fulfilled Amount;
- Remaining Entitlement;
- Aggregate Remaining Entitlement;
- Supporting Capacity and Backing Sufficiency;
- Commitment Establishment;
- Commitment Exercise and Fulfillment;
- Backing-Affecting Shared-Resource Transitions;
- Validity, Exercisability, Fulfillment Exhaustion, and Non-Fulfillment Release consequences;
- normative authority distinctions;
- causal attribution requirements;
- atomic economic-finality requirements; and
- authoritative information-continuity requirements.

Any formula, predicate, or behavioral condition governing those concepts remains normatively owned by the Protocol Specification.

---

## 3. Architectural Semantic Model

### 3.1 Authoritative Responsibility as the Primary Unit

The primary unit of Canonical Architecture is an **authoritative responsibility**, not a component.

An architectural responsibility identifies a protocol-correctness function that must possess sufficient authority, information, enforcement capability, or causal position to realize one or more Specification requirements.

An architectural responsibility does not imply a one-to-one component boundary.

A single implementation component may realize multiple architectural responsibilities.

A single architectural responsibility may be realized through cooperation among multiple implementation components.

Distinct architectural responsibilities must remain semantically separable wherever their combination could collapse a required authority, trust, enforcement, attribution, continuity, or economic-finality boundary. This does not inherently require separate implementation components.

### 3.2 Minimum Responsibility Set

Standby requires eight authoritative architectural responsibilities:

- **A1 — Authoritative Economic Relationship Ownership**
- **A2 — Authoritative Operation Enforcement**
- **A3 — Authoritative Economic Determination**
- **A4 — Complete Backing Enforcement**
- **A5 — Causal Exercise and Fulfillment Integrity**
- **A6 — Economic Authority and Trust Separation**
- **A7 — Atomic Economic Composition**
- **A8 — Authoritative Information Continuity**

These responsibilities form the minimum general architectural semantic model.

---

## 4. Authoritative Responsibilities

### 4.1 A1 — Authoritative Economic Relationship Ownership

A1 maintains authoritative control over the existence, identity, terms, and economically authoritative state of each admitted commitment relationship.

A1 must provide a unique authoritative basis for determining whether a commitment relationship exists and what commitment-specific economic facts are authoritative.

Only an appropriately admitted authoritative transition may change that relationship.

A1 must not independently invent economic definitions, derived predicates, fulfillment evidence, or authority that the Specification assigns elsewhere.

A1 may rely upon authoritative determinations produced through A3, authority boundaries preserved through A6, and causal fulfillment evidence established through A5.

The concrete representation of authoritative relationship state is realization-level.

### 4.2 A2 — Authoritative Operation Enforcement

A2 ensures that every authoritative protocol operation becomes effective only when its applicable Specification predicates are satisfied and its required authoritative effects can be produced.

A2 must possess sufficient enforcement authority to prevent a forbidden authoritative operation result from becoming effective.

A2 consumes authoritative predicates and determinations supplied through the applicable architectural responsibilities; it does not acquire authority to redefine those predicates merely by enforcing them.

A2 must distinguish an operation request or attempted execution from a successful authoritative protocol operation.

Invocation alone does not make an operation authoritative.

### 4.3 A3 — Authoritative Economic Determination

A3 provides the authoritative derivation or admission of economically meaningful quantities, predicates, classifications, and consequences required by normative protocol behavior.

A3 includes authoritative determination of Specification-defined economic semantics where those determinations are required by establishment, exercise, fulfillment, backing preservation, derived consequences, or future normative reasoning.

A3 owns authority over the correctness of the economic determination, not a particular algorithm or implementation technique.

Where an economic determination depends upon an admitted fact, A3 is responsible for the authoritative economic use or admission of that fact within the determination process, while A6 preserves the Specification-defined authority and trust boundary governing who or what may authoritatively supply or establish that fact. Possession of operation-invocation or execution capability does not confer fact-admission authority.

Where normative behavior depends upon facts originating outside the authoritative Standby state boundary, those facts must enter A3 through an authoritative fact-admission boundary consistent with A6.

External-fact admission is therefore a conditional architectural sub-responsibility when such external facts are used; it is not an independently mandatory ninth architectural responsibility.

### 4.4 A4 — Complete Backing Enforcement

A4 establishes an enforcement boundary covering every economically authoritative pathway capable of impairing an applicable backing relationship, with sufficient authority to reject any transition that would violate Specification-defined backing sufficiency.

A4 applies according to the economic effect of an authoritative transition, not its function name, interface, router, component, caller, or implementation path.

A4 relies upon authoritative economic determinations supplied through A3.

A4 does not redefine Supporting Capacity, Aggregate Remaining Entitlement, backing-domain membership, or the applicable feasibility relation. Those semantics remain Specification-owned.

A4 must ensure that an implementation cannot preserve backing on one nominal protocol path while permitting an economically equivalent authoritative bypass to impair the protected capacity property.

### 4.5 A5 — Causal Exercise and Fulfillment Integrity

A5 preserves authoritative causal identity from a specific authorized exercise through qualifying execution, Beneficiary delivery, fulfillment determination, and the resulting commitment-specific economic effect.

A5 must prevent execution, delivery, fulfillment evidence, or entitlement effects belonging to one economic relationship from being substituted for another.

Execution evidence may produce commitment-specific economic consequences only when the required causal relationship to that commitment and exercise has been established.

A5 does not prescribe how causal evidence is represented or transported.

The evidence mechanism may be transaction-scoped where no future normative dependency requires its persistence.

### 4.6 A6 — Economic Authority and Trust Separation

A6 preserves the distinct authority classes defined by the Protocol Specification and prevents invocation, execution, configuration, or implementation capability from implicitly conferring authoritative determination, fact-admission, consequence, or relationship-modification authority.

Possession of invocation or execution capability must not by itself confer:

- authoritative term-determination authority;
- authoritative fact-admission authority;
- condition-derived authority; or
- authority to alter another commitment relationship.

A6 must prevent implementation convenience from collapsing economically distinct authorities.

Where one implementation component performs multiple roles, it must still preserve the normative authority boundaries among those roles.

The concrete trust and reliance relationships among A1–A8 are defined in §5.

### 4.7 A7 — Atomic Economic Composition

A7 ensures that economically interdependent authoritative effects compose such that no forbidden partial authoritative outcome can become final.

Where multiple effects jointly constitute one successful normative economic result, the architecture must ensure that either the complete permissible result becomes authoritative or the forbidden partial result does not become authoritative.

A7 applies wherever the Protocol Specification requires atomic economic finality, including establishment, exercise and fulfillment, and backing-affecting transitions where multiple authoritative effects are economically interdependent.

A7 does not require blanket transaction-level atomicity as a general architectural rule.

A realization may use transaction atomicity, rollback, staged finalization, or another mechanism provided the resulting authoritative economic semantics satisfy A7.

### 4.8 A8 — Authoritative Information Continuity

A8 ensures that every authoritative fact, distinction, consequence, or sufficient derivational basis required by future normative behavior remains authoritatively available or deterministically reconstructible for the duration of that dependency.

A8 requires continuity of authoritative meaning, not a particular persistence mechanism.

Information may be:

- directly retained;
- retained through sufficient authoritative source facts;
- deterministically reconstructed; or
- transition-local where no future normative dependency survives the transition.

Information whose future normative dependency has ended need not remain persistently represented unless another normative requirement independently requires it.

---

## 5. Authority, Trust, and Reliance Boundaries

### 5.1 A6 → A3 — Authoritative Input Boundary

A3 may derive normative economic meaning only from facts and inputs that possess the applicable authority required by the Protocol Specification.

A6 governs which actors, conditions, or authoritative sources may supply those inputs.

Caller assertion alone is not authoritative economic truth.

### 5.2 A3 → A4 — Economic Determination Boundary

A4 relies upon A3 for the authoritative economic determinations necessary to evaluate applicable backing relationships.

Backing enforcement must not rely upon implementation-local approximations where the Specification requires an authoritative derivation.

### 5.3 A4 → A2 — Backing Admission Boundary

Where an authoritative operation can establish or alter an applicable backing relationship, A4's backing-preservation result is a required input to A2's operation-enforcement decision.

A2 must not admit a transition that A4 determines would violate the applicable backing relationship.

### 5.4 A2 → A1 — Authoritative Mutation Boundary

A1 may recognize a protocol operation as having changed authoritative economic relationship truth only when the operation has passed the applicable A2 enforcement path.

Operation invocation or attempted execution alone is insufficient.

### 5.5 A5 → A1 — Commitment-Specific Fulfillment Boundary

A1 may apply a commitment-specific fulfillment effect only when the required causal relationship has been established through A5 and the corresponding economic determination has been made through A3.

No unrelated execution or delivery may substitute for commitment-specific attributable fulfillment.

### 5.6 A1 / A3 → A8 — Future Dependency Boundary

A8 must preserve authoritative relationship facts and economic derivational bases for as long as A1, A2, A3, A4, A5, or A6 may require them for future normative behavior.

A8 does not independently determine the economic meaning of those facts.

---

## 6. Complete Enforcement Topology

This section applies the A4 responsibility defined in §4.4 to system-wide enforcement-path composition. It does not independently redefine A4 or the Specification-owned backing relationship.

### 6.1 Economic-Effect Coverage

For purposes of satisfying A4, every economically authoritative pathway capable of affecting the protected backing relationship must be classified as either:

1. a pathway that can impair the relationship and therefore must encounter the applicable backing-preservation enforcement; or
2. a pathway demonstrably incapable of violating that relationship and therefore not requiring interception.

There is no valid architectural category of an authoritative capacity-affecting pathway that remains uncontrolled merely because it is assumed to be safe.

### 6.2 Operation Enforcement vs. Enforcement Topology

A2 and A4 address different correctness properties.

A2 ensures that a particular authoritative operation becomes effective only when its normative predicates and effects are satisfied.

A4 ensures that every economically relevant authoritative pathway capable of impairing backing is covered by the preservation constraint.

Correct enforcement on one nominal protocol path does not establish complete backing enforcement if another economically authoritative path can bypass the same preservation requirement.

### 6.3 Protected Property

A4 applies to the protected execution-capacity property defined upstream. Accordingly, satisfying A4 does not itself introduce asset ownership, segregation, or reservation requirements absent an independent upstream requirement.

Authority over every asset is therefore not the architectural requirement.

Sufficient enforcement control over every authoritative transition capable of destroying the protected property is the architectural requirement.

---

## 7. Required Interaction Paths

The paths in this section define required composition among architectural responsibilities.

They do not redefine the normative predicates or effects of the Specification operations and consequences to which they correspond.

### 7.1 O1 — Commitment Establishment

The required architectural composition is:

**Authorized Invocation → Authoritative Term Determination → Prospective Economic Derivation → Backing Feasibility → Authoritative Admission → Complete Economic Relationship Establishment → Authoritative Continuity**

A6 preserves the applicable authority boundaries.

A3 produces the required authoritative economic determinations.

A4 determines whether prospective admission preserves the applicable backing relationship.

A2 prevents establishment from becoming authoritative unless all applicable requirements are satisfied.

A1 establishes the resulting authoritative economic relationship.

A7 ensures that the economically interdependent establishment effects do not leave a forbidden partial authoritative relationship.

A8 preserves the authoritative facts or derivational basis required by future normative behavior.

An establishment that fails before complete economic finalization must not leave a partial authoritative commitment relationship.

### 7.2 O2 — Commitment Exercise and Fulfillment

The required architectural composition is:

**Authoritative Commitment → Exercise Authority → Validity / Exercisability / Amount Determination → Exercise Admission → Commitment-Specific Causal Context → Qualifying Execution → Beneficiary Delivery → Attributable Fulfillment Determination → Commitment-Specific Entitlement Effect → Resulting Backing Preservation → Atomic Economic Finalization → Authoritative Continuity**

A1 provides the authoritative target commitment.

A6 preserves exercise and determination authority boundaries.

A3 determines the applicable economic predicates and consequences.

A2 admits the exercise attempt only when the applicable normative conditions permit it.

A5 preserves causal identity from the targeted exercise through execution, delivery, fulfillment, and the resulting commitment-specific effect.

A3 determines whether the actual execution and delivery satisfy the Specification-defined fulfillment semantics.

A1 applies only the commitment-specific economic effect supported by authoritative attributable fulfillment.

A4 verifies preservation of the resulting backing relationship.

A7 prevents a forbidden partial successful exercise from becoming economically final.

A8 preserves the authoritative post-result and any information required by later normative behavior.

Consistent with the Specification-owned distinction between exercise, execution, and fulfillment, exercise admission or execution alone cannot authorize a fulfillment-dependent architectural effect.

Only Specification-defined Actual Attributable Fulfilled Amount may produce the corresponding commitment-specific entitlement reduction.

### 7.3 O3 — Backing-Affecting Shared-Resource Transition

The required architectural composition is:

**Proposed Shared-Resource Transition → Affected Backing Identification → Prospective Supporting-Capacity Determination → Applicable Obligation / Feasibility Determination → Complete Backing Enforcement → Authoritative Transition Admission → Economically Atomic Finalization → Continued Authoritative Derivability**

A1 supplies the authoritative commitment relationships relevant to the applicable obligations.

A3 identifies affected backing relationships and derives the applicable prospective economic state.

A4 determines whether the proposed transition preserves every affected backing relationship.

A2 prevents a forbidden transition from becoming authoritative.

A7 ensures that economically interdependent resource and preservation effects do not finalize inconsistently.

A8 preserves the authoritative basis required for later Supporting Capacity and backing reasoning.

Backing preservation must evaluate the prospective resulting economic state rather than merely the pre-transition state.

### 7.4 D1–D4 — Authoritative Derived Consequences

The general architectural composition for Specification-defined derived consequences is:

**Authoritative Facts → Authoritative Derived Consequence → Normative Consumption → Economic Relationship Interpretation → Authoritative Information Continuity**

A1 supplies applicable authoritative relationship facts.

A3 authoritatively derives the consequence.

A2 consumes the current consequence when an invoked operation depends upon it.

A1 reflects the authoritative economic interpretation where the consequence affects the relationship.

A8 preserves sufficient authoritative information for later normative reasoning.

A6 prevents an actor from acquiring discretionary consequence authority merely by invoking a lifecycle-related action.

Derived consequences do not inherently require dedicated lifecycle operations, lifecycle managers, mutable lifecycle enums, or explicit transition transactions.

A derived consequence is authoritative because its Specification-defined predicate and authoritative basis establish it, not merely because a maintenance operation has been invoked.

Where the Specification makes a derived consequence irreversible, A8 must preserve sufficient authoritative basis to prevent later reasoning from reconstructing that consequence as if it had never occurred.

---

## 8. Authoritative Information Continuity

### 8.1 Continuity Requirement

Authoritative information must remain available or deterministically reconstructible for exactly as long as future normative behavior depends upon it.

Architecture must preserve the ability to determine future protocol behavior correctly.

It need not preserve redundant representations after their normative dependency has ended.

### 8.2 Persistent Economic Information

Where future normative behavior depends upon an authoritative economic fact, relationship distinction, historical consequence, or derivational basis, the architecture must ensure continued authoritative knowability.

This requirement applies regardless of whether the realization chooses direct persistence or deterministic reconstruction.

### 8.3 Transition-Local Causal Evidence

Evidence required only to establish causal integrity within one economically atomic transition may remain transition-local.

Once the final authoritative economic result exists, transition-local evidence need not persist unless future normative behavior independently depends upon it.

### 8.4 Derived Information

An economically meaningful aggregate, classification, or consequence need not be independently persisted where it can be deterministically reproduced from a bounded sufficient set of authoritative facts.

Architecture must preserve the authoritative derivational basis, not redundant derived state.

### 8.5 Irreversible Consequences

Where a Specification-defined consequence is irreversible for an existing economic relationship, the architecture must preserve sufficient authoritative evidence or derivational basis so that future reasoning cannot incorrectly reconstruct the pre-consequence relationship.

---

## 9. Specification Traceability

### 9.1 Forward Traceability

| Specification Family | Architectural Realization |
|---|---|
| `SPEC-E1–E6` — Commitment Establishment | A1, A2, A3, A4, A6, A7, A8 |
| `SPEC-X1–X14` — Exercise and Fulfillment | A1, A2, A3, A4, A5, A6, A7, A8 |
| `SPEC-B1–B12` — Backing / Resource Compatibility | A1, A2, A3, A4, A7, A8; A5 and A6 where applicable |
| `SPEC-D1–D13` — Derived Consequences | A1, A2, A3, A6, A7, A8; A4 and A5 where applicable |
| `SPEC-A1–A12` — Authority / Attribution | A1, A2, A3, A5, A6, A8; A4 and A7 where applicable |
| `SPEC-C1–C14` — Continuity / Composition | A1, A2, A3, A5, A7, A8; A4 and A6 where applicable |

Every Specification family therefore possesses an architectural realization.

### 9.2 Reverse Traceability

| Architectural Responsibility | Principal Specification Basis |
|---|---|
| A1 — Authoritative Economic Relationship Ownership | `SPEC-E`, `SPEC-X`, `SPEC-A`, `SPEC-C` |
| A2 — Authoritative Operation Enforcement | `SPEC-E`, `SPEC-X`, `SPEC-B`, `SPEC-D`, `SPEC-A`, `SPEC-C` |
| A3 — Authoritative Economic Determination | `SPEC-E`, `SPEC-X`, `SPEC-B`, `SPEC-D`, `SPEC-A`, `SPEC-C` |
| A4 — Complete Backing Enforcement | principally `SPEC-B`; required by applicable `SPEC-E` and `SPEC-X` behavior |
| A5 — Causal Exercise and Fulfillment Integrity | `SPEC-X`, `SPEC-A`, `SPEC-C` |
| A6 — Economic Authority and Trust Separation | principally `SPEC-A`; required by applicable `SPEC-E`, `SPEC-X`, and `SPEC-D` behavior |
| A7 — Atomic Economic Composition | `SPEC-E`, `SPEC-X`, `SPEC-B`, `SPEC-C` |
| A8 — Authoritative Information Continuity | principally `SPEC-C`; required across other families where future normative dependencies exist |

Every architectural responsibility therefore has upstream Specification justification.

Traceability establishes correspondence only. It does not create additional normative behavior or architectural semantics.

---

## 10. General Architecture / Reference Realization Boundary

### 10.1 General Architecture

Sections 1–9 define the general Canonical Architecture of Standby.

A conforming realization must satisfy the responsibilities and boundaries established there without regard to the particular implementation technology chosen.

### 10.2 Reference-Realization Decisions

The following validated ETHGlobal reference choices are not general architectural requirements:

- Uniswap v4 as the shared AMM realization;
- a Standby hook as authoritative state and enforcement owner;
- a narrow exercise router;
- one protected commitment direction per configured pool;
- bidirectional ordinary swaps;
- a transaction-scoped causal-evidence mechanism;
- a bounded potentially-live commitment set;
- `MAX_LIVE_COMMITMENTS = 16`;
- historical records surviving live-slot reuse;
- generic-router compatibility mechanics;
- a particular hook-permission configuration;
- EVM transaction rollback as an atomic-composition mechanism; and
- particular bounded-gas data structures or algorithms.

These choices may realize the general architecture but do not redefine it.

---

## 11. ETHGlobal Reference Realization Cross-Validation

This section demonstrates one validated realization of A1–A8. It creates no additional general architectural requirement.

### 11.1 A1 Reference Realization

The Standby hook may serve as the authoritative owner of commitment relationship state.

The bounded potentially-live commitment representation and historical-record strategy may realize authoritative relationship ownership without becoming general architectural requirements.

### 11.2 A2 Reference Realization

The Standby hook may provide authoritative operation enforcement for establishment, exercise-related protocol effects, and applicable shared-resource transitions.

The narrow exercise router may participate in the O2 path without becoming the source of authoritative protocol truth.

### 11.3 A3 Reference Realization

Authoritative commitment facts and Uniswap v4 execution semantics may provide the basis for the economic determinations required by Standby.

The one-protected-direction-per-configured-pool choice may simplify the applicable Supporting Capacity feasibility relation without changing the general architecture.

### 11.4 A4 Reference Realization

The Uniswap v4 hook enforcement surface may realize complete backing enforcement where its enabled permissions cover every authoritative pool transition capable of impairing the configured Protected Execution Service.

Generic-router compatibility is compatible with A4 because preservation occurs at the authoritative pool/hook enforcement boundary rather than depending upon voluntary use of a proprietary swap router.

Bidirectional ordinary swapping is compatible with A4. Only an authoritative transition capable of impairing an applicable protected backing relationship requires the corresponding preservation enforcement; use of the shared resource does not itself make every direction a protected service.

The reference hook permission surface must be complete with respect to capacity-impairing authoritative transitions while remaining no broader than necessary for that enforcement responsibility. Completeness forbids relevant bypass; minimality avoids unrelated authority.

The concrete callback and permission configuration remains subject to downstream realization and verification.

### 11.5 A5 Reference Realization

The narrow exercise router and transaction-scoped causal evidence may realize the commitment-specific causal chain required by A5.

The causal evidence may remain transaction-local when the final authoritative economic result is sufficient for all future normative behavior.

### 11.6 A6 Reference Realization

The reference realization may distinguish commitment authority, exercise authority, router execution capability, ordinary swap invocation, and configuration authority while allowing individual components to participate in multiple roles where those normative authority boundaries remain preserved.

### 11.7 A7 Reference Realization

EVM transaction composition and rollback may realize atomic economic composition.

EVM atomicity is the reference realization mechanism, not the general architectural requirement.

### 11.8 A8 Reference Realization

The bounded potentially-live commitment representation, historical records surviving slot reuse, and transaction-scoped intermediate causal evidence may jointly satisfy authoritative information continuity.

The exact bound, storage representation, indexing method, and historical-record mechanism remain realization-level choices.

The bounded potentially-live commitment set demonstrates one feasible way to make the required authoritative determinations and enforcement paths executable within the reference environment; neither the bound nor the particular bounded-gas strategy is a general architectural requirement.

### 11.9 Cross-Validation Result

The ETHGlobal reference realization can satisfy A1–A8 without:

- weakening the general architecture;
- strengthening it with reference-specific requirements;
- introducing an unowned architectural responsibility; or
- reinterpreting an upstream Specification requirement.

Reference-realization cross-validation therefore passes.

---

## 12. Architectural Exclusions and Non-Requirements

### 12.1 Preserved Upstream Exclusions

All minimum-protocol exclusions normatively established by the Protocol Specification remain upstream-owned and are incorporated here by reference.

No such exclusion may be promoted into an architectural necessity absent new upstream justification.

### 12.2 Architecture-Specific Non-Requirements

Canonical Architecture does not require:

- one contract per architectural responsibility;
- eight architectural components corresponding to A1–A8;
- a particular contract decomposition;
- a particular storage representation;
- a particular router architecture;
- a particular callback architecture;
- a particular oracle or external-fact technology;
- a particular causal-evidence carrier;
- blanket EVM transaction atomicity;
- persistent representation of every derived quantity or lifecycle classification; or
- a particular maximum number of commitments.

Any such decision remains realization-level unless independently shown necessary to preserve a frozen architectural or upstream normative requirement.

---

## 13. Architecture Completeness and Validation

### 13.1 Completeness Criterion

The frozen Protocol Discovery Methodology defines:

**Architecture Completeness = Responsibility Sufficiency + Transition-Path Composability + Bidirectional Specification Traceability**

This document applies that criterion; it does not redefine it.

### 13.2 Responsibility Sufficiency

A1–A8 were independently tested for necessity and joint sufficiency.

Removing any one responsibility leaves at least one Specification-required authority, ownership, derivation, enforcement, attribution, trust, finality, or continuity obligation without a complete architectural home.

No ninth top-level responsibility was found necessary.

**Result: PASS**

### 13.3 Transition-Path Composability

The architecture was tested against:

- O1 — Commitment Establishment;
- O2 — Commitment Exercise and Fulfillment;
- O3 — Backing-Affecting Shared-Resource Transition; and
- D1–D4 — authoritative derived consequences.

Each transition class can compose through A1–A8 without an authority, trust, enforcement, attribution, continuity, or economic-finality gap.

**Result: PASS**

### 13.4 Bidirectional Specification Traceability

Every Specification requirement family has an architectural realization.

Every A1–A8 responsibility has an upstream Specification justification.

No Specification family is delegated directly to implementation without an architectural home.

No architectural responsibility exists without upstream normative justification.

**Result: PASS**

### 13.5 Historical Phase 9 Cross-Validation

The freshly derived A1–A8 model preserves every independently validated architectural necessity from the earlier Phase 9 architecture.

| Historical Responsibility | Canonical Realization |
|---|---|
| AR-1 — Authoritative Transition Enforcement | A2 |
| AR-2 — Authoritative State Ownership | A1, with A8 for continuity |
| AR-3 — Economic Authority Separation | A6 |
| AR-4 — Complete Enforcement Boundary | A4 |
| AR-5 — Atomic Exercise Settlement | A7 |
| AR-6 — Authoritative External-Fact Admission | A3 + A6, conditional where external facts are used |
| AR-7 — Causal Exercise Attribution | A5 |
| AR-8 — Authoritative Transition Reconstructibility | A8 |

Three canonical refinements were validated:

1. Historical AR-5 is generalized into A7 — Atomic Economic Composition across every applicable authoritative operation, not only exercise settlement.
2. Historical AR-6 is preserved as a conditional A3 + A6 concern rather than a universally mandatory standalone responsibility.
3. Historical AR-8 is generalized from reconstructibility as a particular strategy to A8 — Authoritative Information Continuity as the architectural obligation.

These refinements preserve the frozen Specification without strengthening or weakening it.

**Result: PASS**

### 13.6 ETHGlobal Reference Cross-Validation

The validated ETHGlobal reference realization can satisfy A1–A8 without adding, removing, weakening, or reinterpreting a general architectural responsibility.

**Result: PASS**

### 13.7 Frozen-Exclusion Preservation

No frozen upstream exclusion has been reintroduced as a mandatory architectural requirement.

**Result: PASS**

### 13.8 Single Normative Ownership

Architectural definitions, responsibility semantics, cross-responsibility boundaries, enforcement topology, interaction composition, continuity policy, traceability, reference-realization classification, and validation results each possess a distinct canonical home.

Upstream economic and behavioral semantics remain upstream-owned.

**Result: PASS**

### 13.9 Realization Independence

The architecture determines protocol-correctness responsibilities and required composition while leaving component decomposition, state representation, persistence strategy, algorithm choice, integration mechanism, callback selection, router implementation, and transaction mechanism realization-level unless a structural constraint is independently necessary for correctness.

**Result: PASS**

### 13.10 Downstream Non-Contamination

The architecture does not prematurely determine state-machine representation, invariant decomposition, test structure, Solidity interfaces, function decomposition, storage layout, callback mechanics, or implementation algorithms.

**Result: PASS**

### 13.11 Artifact Completeness and Fidelity

The canonical artifact was reviewed against the complete frozen Architecture derivation, historical Phase 9 cross-validation, ETHGlobal reference-realization validation, frozen exclusions, Specification traceability, and all validated responsibility/interactions.

No omitted architectural responsibility, transition path, authority boundary, enforcement requirement, continuity requirement, or required cross-validation remains.

**Result: PASS**

### 13.12 Final Status

The architecture semantic model and this canonical artifact have passed:

- internal semantic consistency;
- semantic non-redundancy;
- Single Normative Ownership;
- responsibility sufficiency;
- O1/O2/O3 transition-path composability;
- D1–D4 consequence composability;
- bidirectional Specification traceability;
- authority/trust-boundary completeness;
- complete-enforcement-topology review;
- upstream fidelity;
- no-strengthening / no-weakening review;
- frozen-exclusion preservation;
- realization independence;
- downstream non-contamination;
- historical Phase 9 cross-validation;
- ETHGlobal reference-realization cross-validation;
- artifact completeness and fidelity; and
- final post-correction review.

# **FINAL PASS / FROZEN**

No semantic change may be made to this document unless a later canonical-package consistency gate reveals a genuine contradiction requiring the affected frozen canonical layer to be reopened.
