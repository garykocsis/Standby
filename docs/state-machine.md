# Standby Protocol — Canonical State Machine

**Document:** `state-machine.md`  
**Canonical Layer:** Realization  
**Status:** **FINAL PASS / FROZEN**

## 1. Purpose and Scope

### 1.1 Purpose

`state-machine.md` defines the canonical authoritative information model and deterministic transition-state semantics of Standby. It establishes which authoritative economic facts must remain persistently knowable; which economically meaningful quantities, predicates, and consequences remain deterministically derived; which causal facts may exist only within an economically atomic transition; which authoritative facts are obtained from external or shared-resource state rather than owned persistently by Standby; how authoritative operations create, change, preserve, or rely upon those facts; and what information must remain available or reconstructible for future normative behavior.

The State Machine realizes the frozen Protocol Specification through the frozen Architecture. It does not redefine either.

### 1.2 Canonical responsibility

> **Canonical State Machine defines the minimum authoritative information model and deterministic transition-state semantics required to realize the frozen Specification through the frozen Architecture. It classifies which economically meaningful facts must persist, which remain deterministically derived, which exist only as transition-local causal evidence, and which are obtained from authoritative external or shared-resource state; and it defines how authoritative operations change or preserve those facts without prescribing concrete storage representation, contract layout, data structures, or implementation technique.**

Compactly:

> **State Machine = Authoritative Information Model + Deterministic Transition-State Semantics**

subject to:

> **Specification Fidelity + Architecture Fidelity + State Minimality + Realization Independence**

### 1.3 Canonical boundary

The Protocol Specification defines what authoritative behavior is correct. Architecture defines which authoritative responsibilities must exist, their authority and trust boundaries, complete enforcement topology, and required interaction composition. State Machine defines the minimum authoritative information basis needed by those responsibilities and deterministic state effects of authoritative operations. Invariants define properties permitted states and transitions must preserve. Testing Strategy defines how requirements, derivations, transitions, and invariants are verified. Realization and implementation determine concrete representation and execution technique.

Accordingly, this document may reference Specification-defined concepts without independently redefining them, and may state what information an architectural responsibility requires without redefining A1–A8.

### 1.4 Representation independence

The State Machine defines what must be authoritatively known, derivable, or transition-locally established. It does not require a particular representation. Unless independently required upstream, it does not prescribe contracts, component decomposition, mappings, structs, arrays, sets, bitmaps, storage slots, lifecycle enums, events as persistent state, transient-storage mechanisms, configuration-version representation, explicit backing-domain objects, cached aggregates, callback selection, router design, algorithms, or transaction mechanics.

## 2. Upstream Normative Dependencies

### 2.1 Dependency rule

The State Machine is downstream of the frozen Protocol Specification and Architecture. All economic meanings, behavioral requirements, authority classes, causal requirements, enforcement requirements, and architectural responsibilities referenced here retain their normative meaning from their canonical upstream owner. This document composes those semantics into an authoritative information and transition model; it does not strengthen, weaken, or reinterpret them.

### 2.2 Specification dependencies

The State Machine depends principally upon authoritative commitment terms; Entitlement Validity; Entitlement Exercisability; Actual Attributable Fulfilled Amount; Remaining Entitlement; Aggregate Remaining Entitlement; Supporting Capacity and backing sufficiency; O1 Commitment Establishment; O2 Commitment Exercise and Fulfillment; O3 Backing-Affecting Shared-Resource Transition; D1 Validity Consequence; D2 Exercisability Consequence; D3 Fulfillment Exhaustion Consequence; D4 Non-Fulfillment Release Consequence; normative authority distinctions; causal attribution; failure and economic-finality requirements; and authoritative information continuity.

### 2.3 Architecture dependencies

The State Machine must provide an adequate information basis for A1 Authoritative Economic Relationship Ownership, A2 Authoritative Operation Enforcement, A3 Authoritative Economic Determination, A4 Complete Backing Enforcement, A5 Causal Exercise and Fulfillment Integrity, A6 Economic Authority and Trust Separation, A7 Atomic Economic Composition, and A8 Authoritative Information Continuity. It does not assign those responsibilities to concrete components.

### 2.4 Admission-time semantic continuity

Where successful establishment fixes economic semantics that future normative behavior depends upon, sufficient authoritative information must remain available for those admitted semantics to remain stable. Later mutable configuration must not silently reinterpret an already-admitted commitment. This may be realized by preserving admitted semantic facts or an immutable authoritative basis from which they remain deterministically reconstructible; no particular representation is prescribed.

### 2.5 No downstream substitution

Implementation convenience cannot justify replacing an authoritative primitive fact with a weaker proxy, nor can cached derived state become the canonical source of an economic meaning whose authoritative derivation is defined upstream. Absence of a convenient representation cannot eliminate information required by future normative behavior.

## 3. State-Machine Semantic Model

### 3.1 Fact-and-consequence model

Standby uses a **fact-and-consequence state model**, not a mandatory lifecycle-enum state model. Persistent authoritative facts and semantic bases establish the economic relationship. Economically meaningful quantities, predicates, and consequences remain derived wherever deterministically reconstructible from bounded authoritative information. O1, O2, and O3 are the primary authoritative operation classes. D1–D4 are derived normative consequences rather than mandatory independent lifecycle operations.

The canonical model therefore does not require a sequence such as `Created → Active → Exercisable → Fulfilled → Expired`. Such a sequence would collapse economic dimensions that the frozen agreement and Specification intentionally distinguish.

### 3.2 Information classes

The canonical State Machine distinguishes six information classes:

1. **SM-1 — Persistent Commitment Authoritative Basis:** commitment-level facts and irreversible consequence bases that must remain knowable for future normative behavior.
2. **SM-2 — Protected Execution Service Semantic Basis:** authoritative semantic basis required to preserve and later interpret the Protected Execution Service applicable to an admitted commitment.
3. **SM-3 — Backing-Domain Semantic Basis:** authoritative basis, where independently necessary, required to preserve stable backing grouping and feasibility semantics; it does not imply a persistent backing-domain object.
4. **SM-4 — Derived Authoritative Economic State:** quantities, predicates, classifications, and consequences deterministically derived from bounded authoritative information rather than independently established through redundant persistence.
5. **SM-5 — Transition-Local Causal Evidence:** authoritative evidence required to establish causal correctness within an economically atomic transition but not inherently required after the economically final result exists.
6. **SM-6 — External / Shared-Resource Authoritative State:** authoritative facts owned outside Standby's persistent commitment information but consumed for normative determination or enforcement.

### 3.3 Persistence criterion

Economic importance alone does not justify independent persistence. Independent persistent representation is required only when future normative behavior cannot remain correct without preserving the authoritative information or sufficient authoritative evidence from which it can be reconstructed. Where a meaningful quantity or classification is deterministically reproducible from a bounded authoritative basis, preserve the basis rather than require redundant persistence of the result.

### 3.4 Derived-state authority

A derived value is not less authoritative merely because it is not independently persisted. Where the Specification requires an authoritative derivation, the result is authoritative when derived from required authoritative inputs according to the normative derivation.

> **Authoritative does not imply independently stored.**

### 3.5 Transition-locality criterion

Information may remain transition-local when necessary to establish causal correctness of one economically atomic transition but no future normative behavior depends upon preserving that intermediate evidence after the final authoritative result exists. If a later dependency exists, sufficient authoritative information or derivational basis must survive.

### 3.6 External-state criterion

Consumption of an authoritative external fact does not transfer ownership of that fact to Standby. External/shared-resource facts remain SM-6 when their authoritative source lies outside Standby's persistent economic relationship state, while applicable Architecture-defined authority and trust boundaries remain preserved.

### 3.7 Authoritative state evolution

Authoritative economic state may evolve through operation-driven authoritative fact change, change in authoritative external/shared-resource facts, or deterministic derived-consequence change.

> **Authoritative economic state evolution is not identical to Standby-owned persistent-state mutation.**

## 4. Persistent Commitment Authoritative Basis

### 4.1 Responsibility

SM-1 contains the minimum commitment-level information that must remain authoritatively knowable for the duration of future normative dependency. It preserves primitive economic facts and, where necessary, irreversible consequence evidence; it does not independently persist derived quantities, predicates, lifecycle classifications, or aggregates merely because they are important or frequently used.

### 4.2 Establishment boundary

Before successful O1, a proposed commitment is not an authoritative economic relationship. Successful O1 establishes a complete basis sufficient to determine commitment identity, admitted economic terms, applicable Protected Execution Service and backing semantics, Beneficiary, exercise authority, admitted entitlement extent, validity conditions, exercisability conditions, fulfillment history or authoritative fulfillment basis, and future-required irreversible consequence basis. This section owns the information requirement, not O1 behavioral admission semantics.

### 4.3 Commitment identity

Every admitted commitment must possess authoritative identity sufficient to distinguish its economic relationship and effects from every other commitment and support later exercise authorization, causal attribution, fulfillment determination, entitlement effects, and historical reconstruction. No concrete representation is prescribed.

### 4.4 Admission-time semantic basis

Each admitted commitment must retain an authoritative basis sufficient to determine the Protected Execution Service and applicable backing semantics under which it was admitted. Later mutable configuration must not silently change the economic interpretation of the admitted relationship.

### 4.5 Beneficiary

The authoritative Beneficiary must remain knowable while future exercise, delivery, fulfillment attribution, or historical reasoning depends upon it. Beneficiary remains semantically distinct from operation invoker, exercise authority, shared-resource executor, and entities possessing authority to determine or admit other economic facts, even if roles coincide in a realization.

### 4.6 Exercise authority

The authoritative basis for determining who may exercise the commitment must remain knowable while exercise remains normatively possible. Exercise authority does not itself confer authority to redefine commitment terms, determine fulfillment independently, admit external facts, alter backing semantics, or release the Capacity Obligation.

### 4.7 Admitted entitlement extent

The admitted entitlement extent must remain authoritatively knowable because later Remaining Entitlement, permissible exercise amount, fulfillment exhaustion, and related consequences depend upon it. It must not be rewritten merely to represent later fulfillment, non-exercisability, backing pressure, or non-fulfillment release.

### 4.8 Validity-relevant terms

Every admitted term required to determine continuing Entitlement Validity must remain authoritatively knowable while validity or a downstream consequence depends upon it. Where a validity-ending condition remains permanently reconstructible, no additional persistent validity classification is required; otherwise §11 governs durable consequence evidence.

### 4.9 Exercisability-relevant terms

Every admitted term required to determine Entitlement Exercisability must remain authoritatively knowable while future exercise may remain possible. Current exercisability may depend on changing external facts without changing admitted commitment terms. Temporary non-exercisability does not itself modify SM-1 absent an independent Specification-defined consequence.

### 4.10 Authoritative fulfillment basis

The State Machine must preserve a bounded authoritative basis sufficient to determine cumulative Actual Attributable Fulfilled Amount for each commitment. A successful O2 changes this basis only by the Actual Attributable Fulfilled Amount attributable to that commitment and exercise. Cumulative fulfillment may be preserved directly or by an equally authoritative bounded reconstructible basis. Remaining Entitlement need not independently persist when derivable from admitted entitlement extent and fulfillment basis.

### 4.11 Irreversible consequence basis

Where a Specification-defined irreversible consequence changes future normative behavior and cannot remain deterministically reconstructed from authoritative facts that will continue to be available, sufficient authoritative consequence evidence must persist. This does not inherently require a generic lifecycle classification. Where the consequence remains permanently reconstructible, no redundant consequence state is required.

### 4.12 Commitment-state minimality

SM-1 does not inherently include independently persisted Remaining Entitlement, Validity, Exercisability, fulfillment exhaustion, Capacity Obligation binding status, Aggregate Remaining Entitlement, Supporting Capacity, backing sufficiency, utilization, generic lifecycle status, or transition-local exercise evidence.

## 5. Protected Execution Service and Backing Semantic Basis

### 5.1 Responsibility

SM-2 preserves the authoritative meaning of the execution service against which commitments are admitted and later interpreted. SM-3 preserves, where independently necessary, stable grouping and feasibility semantics required to determine which commitments and services must be evaluated together for backing. These bases preserve economic interpretation, not changing economic quantities.

### 5.2 Protected Execution Service semantic basis

For every Protected Execution Service upon which an admitted commitment depends, sufficient authoritative information must remain available to determine the designated shared AMM resource, protected execution direction, promised-result denomination, and qualifying execution conditions required for Supporting Capacity determination and successful fulfillment. These meanings remain Specification-owned.

### 5.3 Stable admitted interpretation

A commitment continues to be interpreted according to the Protected Execution Service semantics applicable to its admission. Later mutable configuration may define different semantics for future commitments but must not silently reinterpret an existing commitment.

> **Backing quantity may vary dynamically; the admitted semantic basis used to interpret the commitment may not vary implicitly.**

### 5.4 Current configuration versus admitted semantics

The State Machine distinguishes current service configuration governing prospective future admission from admitted service semantics governing an already-established commitment. Immutable facts, immutable references, versioned configuration, or another authoritative mechanism may realize this distinction; no representation is canonical.

### 5.5 Backing-domain semantic basis

A backing domain represents the economic grouping within which applicable commitment obligations and Supporting Capacity feasibility must be evaluated together. Persistent SM-3 is required only where stable grouping or feasibility semantics cannot remain deterministically reconstructed from other authoritative information.

> **The State Machine requires authoritative backing semantics, not necessarily an independently persisted backing-domain object.**

### 5.6 Backing-domain membership

Membership may remain derived from commitment admission-time semantic basis, applicable Protected Execution Service semantics, and any independently necessary backing-domain semantic basis. Mutable configuration must not retroactively change an admitted commitment's backing interpretation. Differences not treated by the Specification as requiring distinct backing domains must not be transformed into automatic state partitioning.

### 5.7 Feasibility semantics

The authoritative semantic basis must remain sufficient to determine applicable backing feasibility. Scalar feasibility may be used where Specification semantics support it; economically interdependent services, different denominations, directions, or qualifying conditions may require multidimensional or joint feasibility. No universal scalar aggregation may be introduced merely for convenience.

### 5.8 Dynamic economic quantities

SM-2 and SM-3 do not inherently persist Supporting Capacity, Aggregate Remaining Entitlement, backing surplus, utilization, current feasibility, current AMM balances, current AMM liquidity, or other changing shared-resource quantities.

### 5.9 No duplicated membership state

No independently persisted commitment-membership collection is required where membership remains deterministically reproducible from bounded authoritative facts. An implementation index/cache does not become the canonical economic source merely by being persisted.

### 5.10 Semantic continuity across O1, O2, and O3

The same preserved semantic basis supports O1 prospective admission/backing evaluation, O2 qualifying execution/delivery/fulfillment interpretation, and O3 affected-backing identification and prospective capacity/feasibility determination. Interpretation must remain consistent for the same admitted commitment absent an independently authoritative Specification-permitted change.

## 6. Derived Authoritative Economic State

### 6.1 Responsibility

SM-4 consists of economically meaningful quantities, predicates, classifications, and consequences deterministically obtained from bounded authoritative information. A derived result does not require independent persistence merely because later protocol behavior depends upon it.

> **Authority and persistence are independent properties. A deterministically derived economic result may be authoritative without being independently persisted.**

### 6.2 Derivation basis

A derived result must have a sufficient authoritative basis, potentially composing SM-1, SM-2, SM-3, other complete derived results, SM-5 within a transition, and SM-6. It must not acquire authority from an unauthoritative cache or approximation where normative derivation requires different inputs.

### 6.3 Remaining Entitlement

Remaining Entitlement is derived from admitted entitlement extent and cumulative Actual Attributable Fulfilled Amount according to the Specification-owned derivation. Non-fulfillment release does not manufacture fulfillment and therefore does not require Remaining Entitlement to be rewritten to zero. A released commitment may retain positive historical Remaining Entitlement while imposing no continuing Capacity Obligation.

### 6.4 Entitlement Validity

Validity is derived from applicable admitted validity terms, authoritative facts, and any required irreversible consequence basis. It does not inherently require a lifecycle field. Where an irreversible validity-ending consequence would otherwise cease to be reconstructible, §11 governs persistence of sufficient basis.

### 6.5 Entitlement Exercisability

Exercisability is derived independently from Validity and may depend on continuing Validity, positive permissible Remaining Entitlement, admitted exercisability terms, and applicable current authoritative conditions. A valid entitlement may be non-exercisable. Current non-exercisability does not by itself end Validity, release a Capacity Obligation, reduce Remaining Entitlement, create fulfillment, or require persistent modification.

### 6.6 Fulfillment exhaustion

Fulfillment exhaustion is derived from authoritative entitlement and fulfillment basis. Where cumulative Actual Attributable Fulfilled Amount exhausts admitted entitlement extent, no Remaining Entitlement remains available. No independently persisted `fulfilled`, `complete`, or equivalent classification is required when deterministically derivable.

### 6.7 Capacity Obligation binding status

Whether a commitment currently imposes a Capacity Obligation is derived from the Specification-defined relationship among entitlement, Remaining Entitlement, Validity, fulfillment consequences, and applicable non-fulfillment release. Exercisability is not a substitute. A valid commitment with positive Remaining Entitlement may remain binding while temporarily non-exercisable; positive historical Remaining Entitlement does not imply a binding obligation after release.

### 6.8 Aggregate Remaining Entitlement

Aggregate Remaining Entitlement is derived over applicable commitments whose Capacity Obligations remain binding within the relevant backing relationship. It need not independently persist. An implementation-maintained aggregate is an optimization only if equivalent to the authoritative normative derivation.

### 6.9 Supporting Capacity

Supporting Capacity is derived from authoritative shared-resource state according to applicable Protected Execution Service and backing semantics. It is not inherently Standby-owned persistent state. Changes in resource state may change Supporting Capacity authoritatively without mutating SM-1.

### 6.10 Backing sufficiency and feasibility

Backing sufficiency is derived over applicable commitment obligations, Supporting Capacity, and backing semantics. Scalar or multidimensional/joint feasibility must preserve the Specification-defined semantic structure. Backing surplus, utilization, or feasibility status need not persist.

### 6.11 Derived consequences D1–D4

D1–D4 remain Specification-defined derived consequences and are not promoted into mandatory independent lifecycle operations. Where D4 requires durable consequence evidence because later reconstruction would otherwise reverse an irreversible result, that evidence belongs to the persistent basis governed by §§4 and 11.

### 6.12 Derived-state non-redundancy

A realization may cache or index a derived result for efficiency, but such representation does not displace the normative derivation. Where correctness depends on a derived economic result, the implementation's authoritative result must remain equivalent to the canonical derivation from authoritative facts.

## 7. Transition-Local Causal Evidence

### 7.1 Responsibility

SM-5 consists of authoritative evidence required to establish causal correctness within an economically atomic transition but not inherently required as persistent economic state after the complete authoritative result exists. Its principal minimum-protocol use is O2.

### 7.2 Causal identity

An admitted exercise must establish sufficient causal identity to bind subsequent qualifying execution, Beneficiary delivery, fulfillment determination, and commitment-specific entitlement effect to the intended commitment, authorized exercise, applicable requested amount, and admitted Protected Execution Service semantics. Unrelated or ambiguous activity cannot substitute.

### 7.3 Exercise authorization context

Authorization evidence may remain transition-local when no future normative behavior depends upon preserving the intermediate proof after the final result exists. This distinguishes proof needed during the transition from economic state needed after it.

### 7.4 Qualifying execution evidence

O2 must possess sufficient evidence that qualifying execution actually occurred according to admitted service semantics. Authorization is not execution, and unrelated execution cannot satisfy the commitment merely because its result appears similar.

### 7.5 Beneficiary delivery evidence

Sufficient evidence must establish actual qualifying delivery for the authoritative Beneficiary, causally attributable to the same commitment-specific exercise before fulfillment may become authoritative.

### 7.6 Actual attributable fulfillment

Transition-local evidence must be sufficient for authoritative determination of Actual Attributable Fulfilled Amount. Only then may SM-1 reflect the resulting fulfillment effect.

> **Causal evidence proves the transition; persistent economic state records its authoritative final result.**

### 7.7 Transition-locality boundary

Intermediate evidence need not survive after the final result when the final authoritative economic state is complete, future consequences remain deterministically derivable, and no future requirement depends on reconstructing the intermediate proof. Otherwise sufficient information must survive under §11.

### 7.8 No persistent intermediate lifecycle

Transition-local authorization, execution, delivery, or attribution evidence does not require persistent intermediate commitment states such as `ExercisePending`, `Executed`, `DeliveryPending`, or `SettlementPending`.

## 8. External and Shared-Resource Authoritative State

### 8.1 Responsibility

SM-6 consists of authoritative facts required by Standby normative behavior whose authoritative ownership lies outside SM-1. Standby may consume such facts without copying them into Standby-owned persistent state.

### 8.2 Shared AMM resource state

Authoritative shared-resource state required to determine Supporting Capacity remains state of the applicable shared AMM resource. Standby consumes required facts and execution semantics but does not acquire economic ownership of underlying liquidity merely because commitments depend on executable capacity.

> **Standby protects capacity; it does not reserve or segregate the underlying liquidity.**

### 8.3 Current versus prospective resource state

O1 and O3 may require reasoning about prospective post-transition shared-resource condition rather than only currently observed condition. The State Machine must support authoritative derivation from applicable prospective effects where admission or preservation depends on the post-transition result, without prescribing computation technique.

### 8.4 Authoritative temporal facts

Where Validity or Exercisability depends on time, applicable authoritative temporal facts belong to external authoritative information unless upstream requirements establish different ownership. A fixed admitted temporal term may persist while current time remains externally obtained; advancing time need not mutate commitment state periodically.

### 8.5 Authoritative eligibility and other external facts

Where a deployment uses an external eligibility, attestation, registry, oracle, or other authoritative fact, it remains external unless the admitted relationship requires Standby to preserve it independently. A6/A3 governs whether and how such a fact becomes authoritative for Standby determination. Invocation or execution capability does not grant authority to supply the fact.

### 8.6 Institutional Beneficiary eligibility

A deployment may define current institutional Beneficiary eligibility as an authoritative exercisability condition. Current ineligibility does not by itself terminate Validity, create D4 release, reduce Remaining Entitlement, remove a binding Capacity Obligation, or create fulfillment. Restoration may restore Exercisability when all other predicates are satisfied. A permanent institutional offboarding/sanction or other event terminates a claim only if separately admitted as a validity-ending condition and handled under irreversible-consequence continuity rules.

### 8.7 Pool-access permissioning distinction

Permission to access the underlying shared AMM resource is conceptually distinct from Beneficiary eligibility for the Protected Execution Service. The same registry may support both without merging their economic meanings. Pool access does not automatically determine Standby Validity, Exercisability, or release absent explicit admitted semantics.

### 8.8 External fact continuity

An external fact need not be copied into Standby persistent state when it remains authoritatively available for every future dependency. Where a past external fact has an irreversible future consequence but will not remain reconstructible, sufficient authoritative consequence evidence must survive under §11.

### 8.9 External-state ownership boundary

> **Authority to consume a fact is distinct from ownership of the state that supplies that fact.**

Standby may determine an economic consequence using an admitted external fact while the underlying fact remains owned by another authoritative system.

## 9. Authoritative Transition Semantics

### 9.1 Transition model

Each primary authoritative operation is represented through: pre-transition authoritative basis; transition inputs; authoritative transition derivations; successful authoritative effect; and failure preservation. This does not prescribe function boundaries, transaction count, storage writes, callback sequencing, or realization mechanics.

### 9.2 Economic state transition versus storage mutation

A canonical state transition is a change in authoritative economic reality and need not imply Standby-owned storage mutation. O1 ordinarily creates SM-1; O2 ordinarily changes the fulfillment basis of an existing commitment; O3 may change only shared-resource state; D1–D4 may change because inputs changed.

> **State-transition semantics are defined by authoritative economic effect, not by the presence or absence of a particular storage write.**

### 9.3 O1 — Commitment Establishment

#### 9.3.1 Pre-transition state

Before successful establishment, the proposed commitment does not exist as an authoritative relationship. Existing commitments, applicable service/backing semantics, external/shared-resource state, and derived economic state may already exist. Proposed terms do not constitute admitted entitlement or Capacity Obligation before successful O1.

#### 9.3.2 Transition inputs

O1 consumes authorized invocation context, proposed commitment terms supplied or determined under applicable authority, applicable Protected Execution Service semantics, backing semantics, and external/shared-resource facts required for prospective determination. Supplying a proposed fact does not itself make it authoritative.

#### 9.3.3 Prospective authoritative derivation

Before admission, O1 must be able to determine the complete prospective economic interpretation and post-establishment consequences required by the Specification, including commitment identity and terms, Beneficiary, exercise authority, entitlement extent, validity/exercisability terms, applicable service/backing semantics, prospective Capacity Obligation, affected backing relationship, prospective obligation composition, and prospective backing feasibility. Where admission changes an aggregate or feasibility relationship, evaluation must use the prospective post-establishment condition.

#### 9.3.4 Successful authoritative effect

Successful O1 establishes complete SM-1. The commitment thereafter participates in applicable derivations including Remaining Entitlement, Capacity Obligation, Aggregate Remaining Entitlement, and backing feasibility. Conceptually: **No Authoritative Commitment → Complete Authoritative Commitment Relationship**. This is economic state semantics, not a lifecycle enum.

#### 9.3.5 Establishment completeness

No incomplete subset may become authoritative: entitlement without semantic basis, obligation without commitment, identity without required terms, backing participation without its relationship, or partial terms surviving failure are prohibited partial outcomes.

#### 9.3.6 Failure preservation

If O1 does not satisfy complete success conditions, no entitlement, Capacity Obligation, backing participation, fulfillment basis, or partial commitment terms acquire authoritative economic effect for the proposal.

### 9.4 O2 — Commitment Exercise and Fulfillment

#### 9.4.1 Pre-transition state

O2 begins from an existing authoritative commitment whose current condition is determined from SM-1, SM-2, SM-3, SM-4, and SM-6. Before successful fulfillment, the current attempt contributes nothing to the commitment's fulfillment basis.

#### 9.4.2 Transition inputs

O2 consumes targeted commitment identity, exercise-authority context, requested amount, admitted service semantics, backing semantics, and current external/shared-resource facts required for exercise and fulfillment determination.

#### 9.4.3 Exercise-admission derivation

Before proceeding as an admitted protected exercise, authoritative information must establish commitment existence, applicable exercise authority, current Validity, current Exercisability, positive permissible requested amount, relationship to Remaining Entitlement, and applicability of admitted service semantics. Exercise admission authorizes an attempt; it does not establish fulfillment.

#### 9.4.4 Commitment-specific causal context

SM-5 must bind the targeted commitment and requested exercise to qualifying execution, Beneficiary delivery, Actual Attributable Fulfilled Amount, and resulting commitment-specific authoritative effect.

#### 9.4.5 Qualifying execution and Beneficiary delivery

The transition must establish qualifying execution and actual Beneficiary delivery before fulfillment may become authoritative. Execution alone is insufficient; delivery without the required causal/execution relationship is insufficient.

#### 9.4.6 Successful fulfillment effect

On successful O2, the commitment's authoritative cumulative fulfillment basis increases by exactly the Actual Attributable Fulfilled Amount established for that exercise. The resulting Remaining Entitlement, exhaustion consequence, Capacity Obligation, Aggregate Remaining Entitlement contribution, and backing relationship are then derived.

#### 9.4.7 Partial commitment fulfillment

Where permitted, an exercise smaller than pre-transition Remaining Entitlement may partially fulfill the commitment. Positive remainder may continue to create a Capacity Obligation according to validity/release semantics. Partial commitment fulfillment does not imply partial success of an individual exercise transition.

#### 9.4.8 Atomic economic finality

No forbidden partial authoritative O2 result may become final, including entitlement reduction without attributable fulfillment, fulfillment without qualifying execution and Beneficiary delivery, cross-relationship credit, excess fulfillment credit, or an economically interdependent resulting state violating applicable backing preservation. This defines authoritative composition, not transaction implementation.

#### 9.4.9 Failure preservation

An unsuccessful O2 attempt does not consume entitlement or create fulfillment and preserves the authoritative fulfillment basis, admitted entitlement extent, Remaining Entitlement derivational basis, exhaustion result, Capacity Obligation derivational basis, and admitted semantic basis. Failed transition-local evidence does not acquire persistent economic authority merely because the attempt occurred.

### 9.5 O3 — Backing-Affecting Shared-Resource Transition

#### 9.5.1 Pre-transition state

O3 begins from authoritative shared-resource state, admitted commitments, applicable service/backing semantics, and derived obligations/Supporting Capacity relevant to the affected relationship.

#### 9.5.2 Economic-effect classification

A proposed shared-resource transition belongs within O3 whenever its authoritative economic effect is capable of impairing an applicable Supporting Capacity relationship. Classification depends on economic effect, not operation name, interface, caller, routing path, component boundary, or implementation entry point.

#### 9.5.3 Affected backing determination

Before the transition becomes authoritative, sufficient information must determine every applicable backing relationship it could impair. Valid future non-exercisable commitments remain included where their Capacity Obligations remain binding.

#### 9.5.4 Prospective Supporting Capacity

O3 must determine Supporting Capacity using the prospective authoritative shared-resource condition resulting if the proposed transition became effective. Current pre-transition Supporting Capacity alone is insufficient where the transition could reduce it.

#### 9.5.5 Prospective backing feasibility

Prospective Supporting Capacity is evaluated against applicable binding obligations under relevant backing semantics. Scalar or multidimensional/joint feasibility applies as required; equality remains permissible where the Specification defines it as sufficient.

#### 9.5.6 Successful authoritative effect

If every affected backing relationship remains satisfied, the resource transition may become authoritative. The resulting state may consist of changed shared-resource state, unchanged SM-1, and changed SM-4. No Standby-owned commitment mutation is inherently required.

#### 9.5.7 Backing-preservation failure

If the transition would violate applicable backing, it must not become authoritative. Feasibility must not be restored by silently reducing entitlement, reducing Remaining Entitlement without fulfillment, manufacturing fulfillment, releasing a still-binding commitment, changing Beneficiary/exercise authority, changing admitted service semantics, or retroactively reclassifying backing.

> **The obligation constrains the shared-resource transition; shared-resource pressure does not rewrite the obligation.**

#### 9.5.8 O3 failure preservation

A rejected O3 proposal preserves the authoritative economic pre-state with respect to the proposed resource transition. Failure preservation applies to the authoritative shared-resource effect itself, not only Standby-owned persistent state.

### 9.6 Cross-operation transition rules

1. **No implicit admitted-semantic mutation.** O2/O3 interpret commitments according to preserved O1 admission semantics; later mutable configuration cannot implicitly amend them.
2. **No resource-driven rights mutation.** O3 cannot resolve backing pressure by changing commitment rights or fulfillment history.
3. **No failed-attempt economic mutation.** Failure cannot leave an economic consequence requiring successful completion.
4. **Derived-state recomputation.** Dependent derived results reflect authoritative post-state when primitive, semantic, or external facts change; independent mutation of each result is not required.
5. **Causal source of authoritative changes.** Establishment derives from O1; fulfillment-basis change from attributable O2; backing-relevant shared-resource change from authoritative resource transition subject to O3; external facts change according to their source; D1–D4 change deterministically with inputs.

## 10. Derived Consequences and Cross-Dimensional State

### 10.1 Responsibility

This section defines how Specification-owned derived consequences participate in the State Machine and how independently meaningful commitment dimensions compose into coherent authoritative economic state. It does not redefine D1–D4 or introduce lifecycle states.

### 10.2 Primary operations and derived consequences

O1, O2, and O3 are primary authoritative operation classes. D1–D4 are derived normative consequences whose results follow from applicable authoritative bases. A derived consequence does not require separate invocation or persistent transition merely to become authoritative.

### 10.3 D1 — Validity Consequence

Validity remains derived. A change does not inherently require a persistent classification. Permanently reconstructible validity-ending conditions require no redundant state; otherwise §11 requires sufficient evidence to preserve irreversibility.

### 10.4 D2 — Exercisability Consequence

Exercisability remains independently derived and requires continuing Validity, a permissible positive amount remaining available, and other Specification-defined current exercise conditions. Validity does not imply current Exercisability. Temporary loss of Exercisability is not a validity-ending condition absent independently admitted semantics.

### 10.5 D3 — Fulfillment Exhaustion Consequence

Exhaustion is derived from admitted entitlement extent and cumulative Actual Attributable Fulfilled Amount. When the full extent is consumed, Remaining Entitlement is zero and no further positive amount remains. No second transition is required to mark `fulfilled` or `exhausted`.

### 10.6 D4 — Non-Fulfillment Release Consequence

D4 eliminates a Capacity Obligation associated with unfulfilled entitlement without treating that entitlement as fulfilled. It does not increase Actual Attributable Fulfilled Amount, reduce Remaining Entitlement by pretending fulfillment, or rewrite fulfillment history. Positive Remaining Entitlement may remain after release while no longer imposing a Capacity Obligation. Once irreversible D4 release occurs, the released obligation cannot become binding again absent a new establishment or independently Specification-authorized relationship change.

### 10.7 Independent commitment dimensions

The State Machine preserves independent meanings of Validity, Exercisability, admitted entitlement extent, cumulative Actual Attributable Fulfilled Amount, Remaining Entitlement, fulfillment exhaustion, applicable non-fulfillment release, and Capacity Obligation binding status. One must not substitute for another where the Specification distinguishes them.

### 10.8 Validity and Exercisability

Current Exercisability implies continuing Validity; Validity does not imply Exercisability. A commitment may therefore be valid, currently non-exercisable, positively unfulfilled, and still backed by a binding Capacity Obligation.

### 10.9 Exercisability and Remaining Entitlement

A positive exercise requires positive permissible Remaining Entitlement. A fulfillment-exhausted commitment cannot remain exercisable for an additional positive amount merely because validity conditions otherwise continue.

### 10.10 Fulfillment exhaustion and Capacity Obligation

Where fulfillment exhaustion has reduced Remaining Entitlement to zero through Actual Attributable Fulfilled Amount, no remaining quantitative entitlement requires future backing. No separate lifecycle label is needed.

### 10.11 Non-fulfillment release and Capacity Obligation

An applicable irreversible non-fulfillment release removes the Capacity Obligation associated with released unfulfilled entitlement. Positive historical Remaining Entitlement does not make the released obligation binding again.

> **Remaining Entitlement records what remains unfulfilled; Capacity Obligation binding status determines whether that remainder still requires protected future capacity.**

### 10.12 Permitted combinations

Coherent combinations include valid/exercisable/positive remainder/backed; valid/currently non-exercisable/positive remainder/backed; valid but exhausted/no remaining obligation; invalid following a validity-ending condition/positive unfulfilled remainder/released obligation; and historically exhausted commitments whose later validity conditions no longer matter to future quantitative exercise. These are compositions, not lifecycle states.

### 10.13 Forbidden combinations

The State Machine must not admit an interpretation with invalid yet exercisable entitlement; positive exercise without positive permissible remainder; exhaustion with positive Remaining Entitlement under the same derivation; exhausted entitlement imposing an obligation for the exhausted amount; irreversibly released entitlement continuing to impose the released obligation; release represented as fulfillment; temporary non-exercisability treated as irreversible release absent applicable semantics; or backing pressure rewriting these dimensions. Formal invariant ownership remains downstream in `invariants.md`.

### 10.14 No mandatory lifecycle projection

A realization may introduce lifecycle labels only as faithful projections of authoritative facts and derived consequences that cannot become independent contradictory sources of economic truth. A projection that loses a canonical distinction is insufficient as authoritative state representation.

## 11. Information Continuity and Irreversible Consequences

### 11.1 Responsibility

Information continuity ensures every authoritative fact, semantic distinction, consequence, or sufficient derivational basis required by future normative behavior remains authoritatively available for the duration of that dependency. This realizes State Machine information implications of A8 without redefining A8.

### 11.2 Continuity criterion

For every future-used item, ask whether every future dependent operation or derivation will still possess an authoritative basis sufficient to determine the correct result after the transition/external change that established the condition. If yes, no additional persistence is required; if no, sufficient authoritative information must survive.

> **Persistence is justified by future normative dependency and loss of derivability, not merely by the economic importance of a result.**

### 11.3 Persistent fact versus derived result

Where a future result remains reproducible from bounded authoritative facts, preserve the facts rather than require independent persistence of the result. Remaining Entitlement and fixed-time validity-ending consequences are representative cases.

### 11.4 Reconstructible irreversible consequences

An irreversible consequence does not require independent consequence evidence when authoritative inputs remain available, prove the consequence in every future dependent evaluation, and cannot later reconstruct the consequence as not having occurred.

### 11.5 Historically evidenced irreversible consequences

Where an irreversible consequence depends on an event/fact whose occurrence will not remain permanently reconstructible, sufficient authoritative historical evidence must survive to prevent future reversal. No particular Boolean, enum, event, timestamp, snapshot, or record representation is prescribed.

### 11.6 Irreversible Consequence Persistence Rule

> **A derived irreversible consequence does not require independent persistent state when its occurrence and continuing normative effect remain deterministically reconstructible from bounded authoritative facts. If later reconstruction could otherwise reverse the consequence because its triggering fact is no longer authoritatively available, sufficient authoritative consequence evidence must persist to make the irreversible result permanently derivable.**

### 11.7 D4 continuity

Future reasoning must distinguish still-binding positive Remaining Entitlement from released but historically unfulfilled positive Remaining Entitlement. If release cannot be permanently reconstructed, sufficient release consequence evidence must survive. Remaining Entitlement must not be rewritten to zero to erase the distinction between fulfillment and release.

### 11.8 Temporary conditions versus irreversible consequences

A mutable condition that may recover must not be treated as evidence of irreversible consequence absent explicit admitted semantics. Temporary Beneficiary ineligibility may leave Validity intact, Remaining Entitlement unchanged, and Capacity Obligation binding; restored eligibility may restore Exercisability.

### 11.9 Admission-time semantic continuity

Future behavior must interpret an admitted commitment according to the economics under which it was established. Mutable service/backing configuration changes require admitted semantic facts or an immutable authoritative reference sufficient to reconstruct them; reference only to current mutable configuration is insufficient where reinterpretation could occur.

### 11.10 Fulfillment continuity

After successful O2, future behavior must retain a bounded authoritative basis sufficient to determine cumulative Actual Attributable Fulfilled Amount. Intermediate exercise/execution/delivery evidence need not persist once the final result exists unless a future dependency independently requires it.

### 11.11 Shared-resource continuity

Standby need not persist historical copies of changing shared-resource state merely because current Supporting Capacity depends upon it. Historical resource facts require preservation only where a future normative dependency specifically depends on the historical fact rather than current state or final economic result.

### 11.12 Derived aggregate continuity

Aggregate Remaining Entitlement, Supporting Capacity, and backing feasibility need not independently persist when reproducible from bounded authoritative bases. Caches/indexes must not acquire economic meaning different from canonical derivation.

### 11.13 Dependency expiration

Information need not remain authoritative indefinitely merely because it was once required. When no present or future normative behavior depends on a fact or intermediate causal proof, no independent continuity requirement remains.

### 11.14 Continuity and historical truth

Removal of a future dependency does not authorize falsification of a canonically meaningful economic fact. Release does not become fulfillment; historical Remaining Entitlement need not become zero; past Beneficiary identity is not rewritten; and admitted semantic history must not be reinterpreted while historical or future reasoning depends upon it.

## 12. Traceability, General/Reference Boundary, and Exclusions

### 12.1 Responsibility

This section records upstream traceability, distinguishes the general Standby state model from the ETHGlobal reference realization, and identifies realization choices and protocol features not required by the canonical State Machine. It creates no new economic definitions, state semantics, architectural responsibilities, or implementation requirements.

### 12.2 Specification traceability

SM-1 supports establishment, exercise, fulfillment, authority, attribution, derived-consequence, and continuity requirements across SPEC-E, SPEC-X, SPEC-D, SPEC-A, and SPEC-C. SM-2 supports service interpretation required by establishment, exercise/fulfillment, Supporting Capacity, backing, and continuity. SM-3 supports SPEC-B grouping, compatibility, and feasibility. SM-4 realizes E1–E7 and D1–D4 information needs without redundant independent state. SM-5 supports SPEC-X/SPEC-A causal authorization, execution, delivery, and attribution. SM-6 supports requirements depending on AMM, temporal, eligibility, or other externally owned facts.

### 12.3 Operation-family traceability

O1 is realized through establishment inputs, prospective derivation, complete SM-1 creation, derived post-state, and failure preservation. O2 is realized through existing commitment facts, exercise predicates, SM-5, qualifying execution/delivery, exact fulfillment-basis change, resulting derivation, and failure preservation. O3 is realized through shared-resource state, affected-backing identification, prospective Supporting Capacity/feasibility, resource transition admission/rejection, and preservation of commitment rights independently of resource pressure.

### 12.4 Derived-consequence traceability

D1 derives Validity; D2 derives Exercisability; D3 derives fulfillment exhaustion; D4 derives non-fulfillment release and, where necessary, relies on durable consequence evidence. No mandatory lifecycle operations are introduced.

### 12.5 Architecture traceability

A1 is supported principally by SM-1. A2 uses authoritative/derived information for O1/O2/O3. A3 uses authoritative derivational bases underlying SM-4. A4 uses commitment obligations, service/backing semantics, shared-resource state, prospective Supporting Capacity, and feasibility. A5 uses SM-5 plus commitment-specific fulfillment effect. A6 is supported by distinctions among commitment-owned facts, external facts, invocation/exercise authority, and term/fact determination. A7 is supported by complete success and failure-preservation semantics. A8 is supported by persistence, reconstruction, continued external availability, and durable irreversible-consequence evidence.

### 12.6 Bidirectional traceability

Completeness requires both **Upstream Requirement → State/Transition Realization** and **State/Transition Element → Upstream Normative Justification**. Implementation convenience cannot justify an otherwise unsupported canonical state element.

### 12.7 General Standby model

The canonical State Machine does not assume a particular number of commitments, pool configuration, service representation, institutional identity system, router, hook permission set, bounded-gas strategy, or persistence mechanism.

### 12.8 ETHGlobal reference realization

The reference realization may instantiate the model through a Standby hook as principal authoritative state/enforcement owner; narrow exercise router; one protected commitment direction per configured pool; ordinary bidirectional swaps; transaction-scoped exercise causal evidence; bounded potentially-live commitment set; survival of required history despite reuse; generic-router compatibility; and minimal hook permission surface covering all capacity-impairing authoritative transitions. These choices demonstrate feasibility and do not redefine the general model.

### 12.9 Bounded commitment realization

A bounded potentially-live commitment set may make required derivations/enforcement executable in the reference environment. The canonical model does not require a particular bound such as `MAX_LIVE_COMMITMENTS = 16`. Any bounded realization must preserve required facts and historical consequence bases despite slot/index/capacity reuse.

### 12.10 Institutional permissioning reference policy

Institutional permissioning is not universal. A reference deployment may consume an authoritative institutional registry/attestation as an external eligibility source. Where current Beneficiary eligibility is an exercisability predicate, ineligibility may make the commitment non-exercisable while Validity and Remaining Entitlement remain unchanged and a binding Capacity Obligation remains binding; restoration may restore Exercisability. Pool-wide access permissioning remains distinct. Permanent eligibility-related termination requires a separately admitted validity-ending/release condition and §11 continuity treatment.

### 12.11 State Machine exclusions

The canonical State Machine does not inherently require lifecycle enums; persistent Remaining Entitlement, Validity, Exercisability, exhaustion, or Capacity Obligation status; cached Aggregate Remaining Entitlement, Supporting Capacity, backing surplus, or utilization; a persistent backing-domain object; duplicated membership collections; persistent O2 intermediate state; historical copies of all resource state; configuration snapshots in a particular representation; specific commitment indexing; dedicated reserves; segregated liquidity; epochs; overbooking; custom accounting; dynamic fees; cancellation; amendment; explicit expiry operations; protocol-native premium settlement; or another upstream-excluded feature absent newly validated necessity.

### 12.12 Implementation exclusions

Nothing requires a particular Solidity storage layout, mapping, struct, array, bitmap, event schema, transient-storage mechanism, callback set, contract decomposition, router interface, identifier encoding, configuration-version field, backing-domain identifier, Supporting Capacity algorithm, AMM-state inspection technique, or transaction rollback mechanism.

## 13. State Machine Completeness and Final Gate

### 13.1 Completeness criterion

The State Machine is complete only when every Specification behavior has sufficient authoritative information; every primary operation has deterministic transition-state semantics; every derived consequence has a complete basis; every architectural responsibility has needed information; every future dependency retains continuity; no necessary information is omitted; no derived information is redundantly required to persist without necessity; every State Machine element traces upstream; and the model remains realization-independent.

### 13.2 Information-model completeness

SM-1 through SM-6 collectively provide authoritative homes for persistent commitment facts, admitted service semantics, backing semantics, derived state, transition-local evidence, and externally owned authoritative facts. No identified dependency requires a seventh class.

**Whole-document result: PASS.**

### 13.3 Transition completeness

O1 defines complete relationship establishment/failure preservation. O2 defines commitment-specific exercise/fulfillment effects, causal evidence, exact fulfillment-basis change, resulting derivation, and failure preservation. O3 defines prospective resource/backing evaluation, resource-state admission/rejection, and preservation of commitment rights. Every identified authoritative state change has a deterministic causal basis.

**Whole-document result: PASS.**

### 13.4 Derived-consequence completeness

D1–D4 possess sufficient State Machine bases without redundant lifecycle transitions. Irreversible consequences whose future correctness cannot be reconstructed require sufficient durable consequence evidence.

**Whole-document result: PASS.**

### 13.5 Cross-dimensional consistency

Validity, Exercisability, entitlement extent, fulfillment, Remaining Entitlement, exhaustion, release, and Capacity Obligation binding status remain independent where required. Valid-but-non-exercisable and released-but-historically-unfulfilled conditions remain representable without lifecycle collapse.

**Whole-document result: PASS.**

### 13.6 Failure-preservation completeness

Failed O1 creates no partial relationship; failed O2 consumes no entitlement/creates no fulfillment; rejected O3 does not allow the prohibited resource state to become authoritative.

**Whole-document result: PASS.**

### 13.7 Information-continuity completeness

Future dependencies are supported through persistent facts, deterministic reconstruction, continuing external facts, or durable consequence evidence. Transition-local evidence disappears only when no future dependency remains.

**Whole-document result: PASS.**

### 13.8 Minimality and non-redundancy

Persistence is required only for authoritative facts, admitted semantic continuity, or future reconstruction. Derived quantities/classifications remain derived wherever bounded reconstruction is sufficient. No redundant lifecycle, aggregate, Supporting Capacity cache, or backing-domain object is required.

**Whole-document result: PASS.**

### 13.9 Upstream fidelity

The State Machine does not strengthen, weaken, or reinterpret the frozen Economic Agreement, Mechanism, Protocol Specification, or Architecture. It preserves distinctions among validity, exercisability, exercise, execution, delivery, fulfillment, Remaining Entitlement, release, and backing obligation.

**Whole-document result: PASS.**

### 13.10 Downstream non-contamination

The State Machine does not prescribe concrete state representation, component decomposition, storage layout, algorithm, callback selection, verification method, or implementation technique. Reference choices remain reference-only.

**Whole-document result: PASS.**

### 13.11 Bidirectional traceability

Every major Specification operation, derived consequence, authority/attribution requirement, backing requirement, and continuity requirement has an identified State Machine realization. Every canonical information class and transition element has upstream justification.

**Whole-document result: PASS.**

### 13.12 Final verdict

> **STATE MACHINE CANONICAL ARTIFACT — FINAL PASS / FROZEN**

### 13.13 Required final gate sequence

Before `state-machine.md` may become Canonical Document #6 FINAL PASS / FROZEN, the assembled artifact must pass:

1. **Gate 1 — Internal Consistency and Semantic Completeness**
2. **Gate 2 — Upstream Fidelity**
3. **Gate 3 — State Minimality and Downstream Non-Contamination**
4. **Gate 4 — Bidirectional Traceability**
5. **Gate 5 — Artifact Fidelity**
6. **Gate 6 — Final Post-Correction Gate**

All six final gates have passed. `state-machine.md` is **FINAL PASS / FROZEN**.
