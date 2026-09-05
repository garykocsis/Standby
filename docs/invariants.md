# Standby — Canonical Invariants

**Canonical Document #7 of 8**  
**Status:** **FINAL PASS / FROZEN**


## 1. Purpose

This document defines the minimum complete set of correctness properties that every conforming realization of Standby must preserve across applicable authoritative economic states and authoritative transitions.

It occupies the proof layer immediately downstream of the Protocol Specification, Canonical Architecture, and State Machine.

Those upstream artifacts define the economic concepts, normative behavior, authoritative responsibilities, authoritative information, operations, derived consequences, and economic relationships of Standby. This document does not redefine them.

Its purpose is to identify the correctness properties whose preservation prevents those already-defined semantics from producing an economically invalid authoritative result.

The canonical relationship relevant to this document is:

**Protocol Specification → Canonical Architecture → State Machine → Invariants → Testing Strategy**

Accordingly:

- the Protocol Specification defines normative protocol behavior;
- the Canonical Architecture defines the authoritative responsibilities and boundaries required to realize that behavior;
- the State Machine defines the authoritative information and transition semantics through which that behavior evolves;
- this document defines what must remain true across those authoritative states and transitions;
- the Testing Strategy defines how a realization demonstrates preservation of those properties.

No implementation mechanism, Solidity structure, Uniswap v4 integration choice, persistence strategy, verification technique, or test architecture is defined here.

---

## 2. Normative Boundary

### 2.1 Canonical Responsibility

**Canonical Invariants define the minimum complete set of persistent correctness properties that constrain the reachable authoritative states and successful authoritative transitions of the protocol, such that preservation of those properties prevents the already-defined normative economic relationships from becoming invalid without redefining the upstream semantics from which those properties are derived.**

### 2.2 Boundary Rule

**An invariant does not define an economic concept, authoritative operation, state representation, derived predicate, or verification method. It states a correctness property that the already-defined authoritative semantics must collectively preserve.**

All economic terms appearing in this document retain their meanings from their normative upstream homes.

References to those terms are referential and do not create independent definitions.

---

## 3. Invariant Admission and Minimality

A candidate correctness property qualifies as a canonical Standby invariant only when all four conditions below hold.

### 3.1 Correctness Necessity

Violation of the property must permit an economically or normatively invalid authoritative state or authoritative transition result.

### 3.2 Preservation Character

The property must express something that applicable authoritative states or transitions must continue to preserve rather than merely restating the required behavior of one operation.

### 3.3 Upstream Derivability

The property must follow entirely from frozen upstream semantics.

An invariant may not introduce a new:

- economic requirement;
- authority;
- state variable;
- operation;
- mechanism;
- lifecycle classification;
- trust assumption;
- implementation requirement.

### 3.4 Independent Protective Value

Removing the invariant must expose a distinct correctness failure that is not sufficiently protected by the remaining canonical invariants.

### 3.5 Minimality Rules

Not every normative behavioral requirement requires a corresponding top-level invariant. A behavioral requirement qualifies only where it induces a distinct preservation property over authoritative state or transition space.

A correctness property necessarily implied by a stronger canonical invariant remains explicitly traceable as an invariant consequence but does not become a separate top-level invariant unless it protects a distinct independently possible failure.

Independent falsifiability does not require artificial fragmentation. Multiple related correctness properties may remain consequences of one invariant where they form one coherent canonical correctness boundary.

Architectural responsibilities and canonical invariants do not correspond one-to-one. An architectural responsibility warrants a distinct invariant only when it induces a realization-independent preservation property with independent protective value.

---

## 4. Authoritative Applicability Model

Canonical invariants constrain the authoritative economic semantics of Standby.

Depending on the invariant, their applicable scope includes:

- reachable authoritative economic states;
- authoritative facts used by normative behavior;
- authoritative information required by future normative behavior;
- prospective authoritative determinations used to decide whether a transition may become authoritative;
- successful authoritative transitions;
- economically final authoritative consequences.

The invariant layer does not require every non-authoritative or intermediate condition to satisfy the properties of an economically final authoritative state.

In particular, invariant preservation does not independently constrain:

- proposed commitments before successful establishment;
- prospective states that are evaluated and rejected;
- implementation-internal calculations that cannot govern normative behavior;
- transition-local causal evidence that does not become an authoritative economic result;
- temporary intermediate representations whose complete economically final result remains canonical.

Where future normative behavior depends upon an economically meaningful fact, quantity, classification, consequence, or relationship, **INV-04 — Authoritative Derivability Continuity** requires sufficient authoritative information to remain available for the lifetime of that canonical dependency.

Required information may remain authoritative directly or through deterministic reconstruction from authoritative facts.

No particular persistence representation is implied.

Once the applicable canonical dependency ends, INV-04 does not independently require the information to remain available solely because it previously participated in authoritative behavior.

Atomicity applies to **authoritative economic finality**, not to the absence of intermediate computation.

---

# 5. Canonical Invariant Set

## INV-01 — Commitment Establishment Integrity

### Canonical Property

**A commitment relationship may become authoritative only through an O1 establishment satisfying every canonically applicable establishment requirement for that relationship.**

### Protected Correctness Boundary

Legitimate authoritative origination of a commitment relationship.

### Applicability

Every commitment relationship that becomes authoritative.

### Explicit Consequences

- A proposed commitment has no authoritative economic effect merely because it has been described, submitted, or partially processed.
- Every canonically applicable establishment requirement must be satisfied before the relationship may become authoritative.
- A complete, internally coherent, and sufficiently backed commitment cannot become authoritative through a non-canonical establishment path.
- Legitimate establishment does not itself establish complete-or-zero economic finality; that boundary is protected by INV-13.

### Non-Ownership

INV-01 does not define establishment requirements, establishment authority, commitment contents, backing feasibility, O1 transition semantics, persistence representation, or atomic economic finality.

---

## INV-02 — Admission Semantic Continuity

### Canonical Property

**For every authoritative commitment, subsequent authoritative behavior must preserve the economic semantics fixed by its successful O1 establishment; those admitted semantics must not be retroactively reinterpreted, weakened, strengthened, or otherwise altered.**

### Protected Correctness Boundary

Stable economic meaning of an admitted commitment relationship.

### Applicability

Every authoritative commitment for as long as canonical behavior continues to depend upon semantics fixed by successful O1 establishment.

### Explicit Consequences

- Later changes applicable to future relationships cannot retroactively reinterpret an existing admitted relationship.
- Admitted entitlement semantics cannot be manufactured, expanded, weakened, or otherwise altered through later reinterpretation.
- Protected Execution Service or backing semantics fixed for a commitment at admission remain stable for that relationship.
- Preservation of admitted meaning does not require any particular persistence strategy.
- Sufficient authoritative basis may be used where the admitted semantics remain deterministically preserved without redundant representation.

### Non-Ownership

INV-02 does not require configuration immutability, prescribe admission snapshots, define commitment semantics, define Protected Execution Services, define backing domains, or prescribe storage or reconstruction mechanisms.

It protects admitted economic meaning rather than any particular representation of that meaning.

---

## INV-03 — Authoritative Fact Admission Integrity

### Canonical Property

**A fact whose authority depends upon external admission may govern an authoritative economic consequence only if that fact has become authoritative through its canonically applicable fact-admission rule.**

### Protected Correctness Boundary

Legitimate admission of externally sourced information where canonical semantics require such admission before the information may govern normative behavior.

### Applicability

Every fact whose canonical authority depends upon external fact admission.

### Explicit Consequences

- Mere observation or assertion of an external fact does not make that fact authoritative where external admission is canonically required.
- Correct downstream calculation cannot legitimize a fact that never validly acquired the authority required for that calculation.
- The fact must satisfy the canonically applicable admission semantics before it may govern an authoritative economic consequence.
- A fact already authoritative as part of the designated shared-resource condition under the applicable Protected Execution Service semantics does not require separate external-fact admission merely because Standby relies upon it.

### Non-Ownership

INV-03 does not define external fact sources, oracle mechanisms, attestations, signatures, admission procedures, trust architecture, or which shared-resource facts are already authoritative under other canonical semantics.

It applies only where upstream semantics make external admission a condition of fact authority.

---

## INV-04 — Authoritative Derivability Continuity

### Canonical Property

**Authoritative information must remain sufficient, for the duration of every applicable canonical dependency, to keep every economically meaningful fact, quantity, classification, consequence, or relationship required by future normative behavior authoritatively knowable, either directly or through deterministic reconstruction from authoritative facts.**

### Protected Correctness Boundary

Continued authoritative knowability of every economically meaningful fact, quantity, classification, consequence, or relationship on which future canonical behavior depends.

### Applicability

Every authoritative information dependency whose continued direct knowability or deterministic reconstructibility is required by future normative behavior.

### Explicit Consequences

- Future-required canonical determinations cannot become impossible because their authoritative basis was discarded.
- A required authoritative fact or relationship may remain directly knowable rather than needing to be re-derived.
- A required derived quantity, classification, consequence, or relationship may remain knowable through deterministic reconstruction from authoritative facts.
- Derived information need not itself be persistently represented where sufficient authoritative basis remains available.
- Loss of information required by a continuing canonical dependency is a correctness failure even before an incorrect downstream derivation is produced.
- The continuity obligation lasts only for the applicable canonical dependency lifetime.
- Once no future canonical behavior depends upon the information, INV-04 does not independently require continued retention.

### Non-Ownership

INV-04 does not define the underlying fact, quantity, classification, consequence, or relationship; define its authoritative semantics or derivation; establish external-fact authority; preserve admission-fixed meaning; guarantee correctness of a performed derivation; preserve economically meaningful causal distinctions; prescribe persistence; require snapshots, caches, redundant derived state, or permanent history; or specify a reconstruction mechanism.

It protects continued authoritative knowability, not the correctness of a derivation performed from that information.

---

## INV-05 — Commitment Derivation Integrity

### Canonical Property

**Every authoritative derived economic property of a commitment must equal the result of its applicable Specification-defined derivation from the applicable authoritative basis.**

### Protected Correctness Boundary

Correct derivation of authoritative commitment-level economic state.

### Applicability

Every authoritative derived economic property of a commitment, including prospective commitment-level determinations where canonical behavior depends upon them.

### Explicit Consequences

This invariant includes correct derivation, where applicable, of:

- Remaining Entitlement;
- Validity;
- Exercisability;
- Capacity Obligation binding;
- fulfillment exhaustion;
- non-fulfillment release.

Validity, Exercisability, Remaining Entitlement, and Capacity Obligation binding remain distinct authoritative economic properties. One cannot be substituted for another except where the Specification explicitly establishes such a derivation.

Remaining Entitlement therefore cannot, under its canonical derivation:

- become negative;
- exceed the admitted entitlement extent;
- be reduced through non-fulfillment release as though release were fulfillment.

A valid but temporarily non-exercisable commitment may retain a binding Capacity Obligation.

A released commitment may retain positive historical Remaining Entitlement while imposing no continuing Capacity Obligation.

### Non-Ownership

INV-05 does not redefine any derived commitment property, its authoritative basis, its derivation, or the operation that changes that basis.

INV-04 protects continued availability of sufficient authoritative information; INV-05 protects correctness of the result derived from the applicable authoritative basis.

---

## INV-06 — Exercise Authorization Integrity

### Canonical Property

**An exercise may produce an authoritative exercise-specific economic effect only when it is bound to a specific authoritative commitment and satisfies that commitment's canonically applicable exercise invocation authority, Validity, Exercisability, and permissible exercise extent.**

### Protected Correctness Boundary

Legitimacy of an authoritative exercise against a particular commitment.

### Applicability

Every attempted exercise capable of producing an authoritative exercise-specific economic effect.

### Explicit Consequences

- Exercise must be bound to a specific authoritative commitment.
- The applicable exercise invocation authority must be satisfied.
- The commitment must satisfy its current canonical Validity and Exercisability requirements.
- The attempted exercise extent must remain within the canonically permissible positive extent.
- Genuine execution or delivery cannot retroactively legitimize an exercise that was not entitled to produce an authoritative exercise-specific economic effect.

### Non-Ownership

INV-06 does not define exercise invocation authority, Validity, Exercisability, permissible exercise extent, qualifying execution, delivery, fulfillment attribution, or fulfillment accounting.

---

## INV-07 — Fulfillment Attribution Integrity

### Canonical Property

**Authoritative fulfillment may arise only from actual delivery for the Beneficiary's benefit produced through qualifying execution and causally attributable to the specific authoritative exercise and commitment being fulfilled; the same economic delivery must not be attributed as authoritative fulfillment beyond the amount it canonically supports.**

### Protected Correctness Boundary

Legitimate and non-duplicative causal attribution of actual economic delivery as fulfillment.

### Applicability

Every authoritative fulfillment determination arising from commitment exercise and fulfillment.

### Explicit Consequences

- Exercise admission is not fulfillment.
- Qualifying execution alone is not fulfillment.
- Delivery alone is not fulfillment.
- The promised result must actually be delivered for the Beneficiary's benefit.
- Fulfillment remains specific to the authoritative exercise and commitment from which it arose.
- Delivery attributable to one commitment cannot satisfy another merely because the commitments share descriptive properties.
- Delivery attributable to one exercise cannot satisfy another merely because both concern the same commitment.
- The same economic delivery cannot support authoritative fulfillment beyond its canonically attributable amount.

### Non-Ownership

INV-07 does not define exercise authorization, qualifying-execution semantics, Beneficiary identity, Actual Attributable Fulfilled Amount, Remaining Entitlement reduction, fulfillment-history accounting, evidence representation, persistence, or economic atomicity.

---

## INV-08 — Fulfillment Conservation

### Canonical Property

**When fulfillment of an amount becomes authoritative for a commitment, cumulative authoritative fulfillment must increase by exactly that amount and Remaining Entitlement must decrease by exactly that amount. Authoritative fulfillment already recognized must remain conserved against any later recreation of the entitlement it discharged.**

### Protected Correctness Boundary

Exact and persistent conservation of authoritative fulfillment into entitlement discharge.

### Applicability

Every authoritative fulfillment transition and the continuing authoritative fulfillment basis of every commitment for which fulfillment has been recognized.

### Explicit Consequences

- Fulfillment and fulfillment-caused entitlement reduction remain exactly equal.
- Fulfillment cannot leave the fulfilled amount economically outstanding.
- Fulfillment cannot discharge more entitlement than became authoritatively fulfilled.
- Previously recognized fulfillment cannot later be erased or reduced so as to recreate entitlement already discharged through fulfillment.
- Non-fulfillment release cannot manufacture a fulfillment-based reduction of Remaining Entitlement.
- Cumulative authoritative fulfillment need not be represented by a dedicated stored counter where sufficient authoritative basis preserves the canonical result.

### Non-Ownership

INV-08 does not establish whether fulfillment is legitimate, define Actual Attributable Fulfilled Amount, redefine Remaining Entitlement, derive fulfillment exhaustion or release, prescribe fulfillment-history representation, or require a cumulative storage field.

INV-07 owns fulfillment legitimacy; INV-08 owns the accounting consequence and its conservation.

---

## INV-09 — Economic Cause Continuity

### Canonical Property

**Authoritative information must remain sufficient, for the duration of the applicable canonical dependency, to preserve every economically distinct causal distinction on which canonical historical truth, future behavior, or continuing economic meaning depends.**

### Protected Correctness Boundary

Continuity of canonically meaningful economic causation across authoritative state evolution.

### Applicability

Every economically distinct causal fact or distinction that remains necessary to canonical historical truth, future normative behavior, or continuing economic meaning.

### Explicit Consequences

- Fulfillment exhaustion and non-fulfillment release remain authoritatively distinguishable for the duration of their applicable canonical dependency.
- Release without fulfillment cannot become historically indistinguishable from actual fulfillment where the distinction remains canonically meaningful.
- Economically distinct causes do not become equivalent merely because they currently produce the same derived status or backing consequence.
- Required causal distinctions may be preserved directly or through sufficient authoritative basis from which the distinction remains deterministically establishable.
- Preservation is not independently required after the applicable canonical dependency ends.
- Transition-local evidence need not remain permanently available merely because it was necessary to establish an economically final result.

### Non-Ownership

INV-09 does not define exhaustion, release, fulfillment, lifecycle states, persistence representation, reason codes, events, permanent archival requirements, transition-local evidence retention, or reconstruction mechanisms.

INV-04 protects authoritative knowability generally; INV-09 protects economically meaningful causal distinction specifically.

---

## INV-10 — Backing Derivation Integrity

### Canonical Property

**Every authoritative current or prospective backing determination must equal the applicable Specification-defined backing derivation from the authoritative binding Capacity Obligations, Protected Execution Service and backing-domain semantics, qualifying Supporting Capacity, and applicable feasibility relation.**

### Protected Correctness Boundary

Correct construction of the complete authoritative backing problem.

### Applicability

Every current or prospective backing determination governing authoritative commitment admission, exercise consequences, shared-resource transitions, or continuing backing state.

### Explicit Consequences

- All and only applicable binding Capacity Obligations participate in the backing determination.
- A valid but temporarily non-exercisable commitment remains included where its Capacity Obligation continues to bind.
- Positive historical Remaining Entitlement from a released commitment does not by itself create a continuing Capacity Obligation.
- Supporting Capacity remains faithful to the applicable Protected Execution Service rather than being replaced by an economically different liquidity measure.
- Backing-domain compatibility and interaction remain represented according to their canonical semantics.
- Shared capacity cannot be impermissibly double counted.
- Capacity from a non-substitutable backing domain or dimension cannot be substituted merely because aggregate capacity elsewhere is sufficient.
- Joint or multidimensional feasibility remains represented where required by the applicable Protected Execution Service.
- Prospective transition reasoning uses the correct prospective backing basis rather than merely the pre-transition state.

### Non-Ownership

INV-10 does not define Remaining Entitlement, Capacity Obligation binding, Protected Execution Services, Supporting Capacity, backing domains, aggregation, compatibility, scalar or multidimensional feasibility formulas, reserve or margin policy, actual backing sufficiency, or enforcement topology.

INV-04 protects continued authoritative knowability of required backing information; INV-10 protects correctness of the backing derivation performed from that information.

---

## INV-11 — Backing Sufficiency

### Canonical Property

**For every authoritative set of binding Capacity Obligations sharing an applicable backing relationship, qualifying Supporting Capacity must satisfy the applicable Specification-defined feasibility relation required by those obligations and their Protected Execution Services.**

### Protected Correctness Boundary

Canonical feasibility of every authoritative backing relationship.

### Applicability

Every authoritative economic state containing one or more binding Capacity Obligations.

A prospective state that would violate INV-11 may be evaluated, but it cannot become the authoritative result of a successful transition.

### Explicit Consequences

- No correctly derived backing deficit may exist in an authoritative state.
- Individual feasibility is insufficient where binding obligations interact.
- Jointly binding obligations must remain jointly feasible where the Protected Execution Service requires joint feasibility.
- Every required non-substitutable capacity dimension must satisfy its applicable feasibility requirement.
- Surplus capacity outside an applicable backing relationship cannot conceal a deficiency unless canonical semantics permit that substitution.
- No excess safety margin, reserve, or overcollateralization is implied beyond the Specification-defined feasibility relation.
- Equality is sufficient wherever the applicable feasibility relation permits equality.
- Every successful authoritative transition leaves all applicable backing relationships feasible.

Where the Specification-defined backing relationship is scalar and fully substitutable, INV-11 specializes to the corresponding Specification-defined scalar backing condition. That scalar form is a special case rather than a universal redefinition of backing feasibility.

### Non-Ownership

INV-11 does not define which obligations bind, Supporting Capacity, backing domains, aggregation, feasibility formulas, safety margins, dedicated reserves, prospective derivation, enforcement topology, transition rejection mechanics, or economic atomicity.

---

## INV-12 — Complete Backing Enforcement

### Canonical Property

**Every authoritative transition whose prospective economic effect can impair Supporting Capacity required by a binding Capacity Obligation must be subject to the applicable backing-preservation constraint before that capacity-impairing effect may become authoritative.**

### Protected Correctness Boundary

Complete enforcement coverage over every authoritative pathway capable of economically impairing required Supporting Capacity.

### Applicability

Every authoritative transition whose prospective economic effect can impair Supporting Capacity required by one or more binding Capacity Obligations.

### Explicit Consequences

- Enforcement coverage follows economic effect rather than operation name, interface, caller, router, component, or nominal path.
- No capacity-impairing authoritative pathway may bypass applicable backing preservation.
- The applicable preservation constraint governs the threatening effect before that effect becomes authoritative.
- Privileged or trusted pathways receive no correctness exemption.
- Supporting Capacity may remain mutable where the resulting backing relationship remains canonically feasible.
- The invariant does not require liquidity immobility.
- Shared-resource pressure cannot justify rewriting a still-binding obligation to make an otherwise impermissible transition appear feasible.

### Non-Ownership

INV-12 does not define Supporting Capacity, Capacity Obligation binding, backing derivation, feasibility, implementation functions, callbacks, contract boundaries, routers, caller authority, rejection mechanics, rollback mechanics, or atomicity.

“Subject to” denotes normative enforcement coverage rather than a required implementation control-flow topology.

---

## INV-13 — Authoritative Economic Atomicity

### Canonical Property

**Where Specification-defined transition semantics require multiple economically coupled effects to constitute one authoritative operation, no proper subset of those effects may become authoritative as that operation's economic result: either the complete Specification-defined authoritative effect set becomes economically final, or no partial authoritative economic result attributable to the attempt may survive.**

### Protected Correctness Boundary

Complete-or-zero authoritative economic finality for canonically coupled operation effects.

### Applicability

Every authoritative operation whose Specification-defined semantics couple multiple economic effects into one normative result.

### Explicit Consequences

- A successful operation cannot finalize only a proper subset of its canonically coupled authoritative economic effects.
- A failed operation leaves zero partial authoritative economic residue attributable to the attempt.
- A failed O1 establishment cannot leave a fragment of the proposed commitment relationship authoritative.
- Delivery, fulfillment recognition, entitlement discharge, and applicable shared-resource effects cannot become independently final where the Specification couples them into one economic operation.
- Architectural or component boundaries do not divide effects that the Specification economically couples.
- Transition-local computation and causal evidence may exist without violating atomicity where they do not become an incomplete authoritative economic result.
- Atomicity applies to authoritative economic finality rather than instruction-level execution.

### Non-Ownership

INV-13 does not define which effects are canonically coupled, redefine O1/O2/O3, prescribe EVM transaction boundaries, call ordering, rollback implementation, storage writes, events, component topology, reentrancy strategy, or external effects outside the Specification-defined economic operation.

The canonical effect set is semantic rather than an enumeration of implementation writes or calls.

---

# 6. Invariant Consequence Register

The following correctness properties remain explicitly traceable but are not additional top-level invariants.

Their appearance here does not create a second normative definition.

| Correctness consequence | Canonical invariant protection |
|---|---|
| Admission-time semantic stability | INV-02 |
| Legitimate external fact authority where admission is required | INV-03 |
| Continued authoritative knowability of future-required information | INV-04 |
| Deterministic reconstructibility where direct derived state is absent | INV-04 |
| Validity correctness | INV-05 |
| Exercisability correctness | INV-05 |
| Remaining Entitlement bounds | INV-05 |
| Capacity Obligation binding correctness | INV-05 |
| Validity and Exercisability remain distinct | INV-05 |
| Remaining Entitlement and Capacity Obligation remain distinct | INV-05 |
| Exercise does not imply fulfillment | INV-06 + INV-07 |
| Execution alone does not imply fulfillment | INV-07 |
| No cross-commitment fulfillment substitution | INV-07 |
| No duplicate economic-delivery attribution | INV-07 |
| Exact fulfillment-caused entitlement reduction | INV-08 |
| No entitlement resurrection through fulfillment-history mutation | INV-08 |
| Fulfillment exhaustion remains distinct from non-fulfillment release | INV-05 + INV-09, with fulfillment-accounting integrity from INV-08 |
| Released historical Remaining Entitlement need not remain backed | INV-05 + INV-10 |
| No impermissible capacity double counting | INV-10 |
| No impermissible cross-domain substitution | INV-10 |
| Multidimensional and joint backing correctness | INV-10 + INV-11 |
| Equality may be sufficient where canonical feasibility permits it | INV-11 |
| No unchecked capacity-impairing authoritative path | INV-12 |
| Failure Preservation / zero authoritative failure residue | INV-13 |

Properties represented as consequences do not become separate invariant families unless future canonical semantics expose a distinct independently falsifiable correctness boundary.

---

# 7. Operation-to-Invariant Preservation Traceability

This mapping identifies the principal invariant families threatened by each canonical authoritative operation.

It is a preservation traceability aid only and does not independently define O1, O2, or O3 behavior.

| Canonical operation | Principal invariant preservation responsibilities |
|---|---|
| **O1 — Commitment Establishment** | INV-01; INV-02; INV-03 where external fact admission is applicable; INV-04; INV-05; INV-10; INV-11; INV-13 |
| **O2 — Commitment Exercise and Fulfillment** | INV-02; INV-03 where applicable; INV-04; INV-05; INV-06; INV-07; INV-08; INV-09 where continuing causal distinction is required; INV-10 and INV-11 where resulting backing is affected; INV-12 where the prospective shared-resource effect can impair required Supporting Capacity; INV-13 |
| **O3 — Backing-Affecting Shared-Resource Transition** | INV-04; INV-05 where commitment properties participate in the determination; INV-10; INV-11; INV-12; INV-13; INV-02, INV-07, and INV-08 additionally constrain any attempted obligation-side repair through semantic reinterpretation or manufactured fulfillment |

The mapping is intentionally many-to-many.

A canonical operation may threaten multiple invariants, and an invariant may constrain multiple operation classes.

---

# 8. Derived-Consequence Traceability

D1–D4 remain derived authoritative consequences rather than mandatory lifecycle operations.

| Derived consequence | Principal invariant protection |
|---|---|
| **D1 — Validity Consequence** | INV-04 for continuing authoritative knowability where future-required; INV-05 for derivation correctness |
| **D2 — Exercisability Consequence** | INV-04 for continuing authoritative knowability where future-required; INV-05 for derivation correctness; INV-06 when exercise is attempted |
| **D3 — Fulfillment Exhaustion Consequence** | INV-04 where future authoritative knowability remains required; INV-05 + INV-08 + INV-09 where causal distinction remains canonically relevant |
| **D4 — Non-Fulfillment Release Consequence** | INV-04 where future authoritative knowability remains required; INV-05 + INV-09; INV-08 prevents false fulfillment substitution |

No separate lifecycle invariant is implied by this mapping.

---

# 9. Architecture and State Coverage

The canonical invariant set was derived and checked against all frozen Architecture responsibilities A1–A8 and State Machine information classes SM-1–SM-6.

The correspondence is deliberately non-bijective.

## 9.1 Architecture Coverage

- **A1 — Authoritative Economic Relationship Ownership** is reflected principally through INV-01, INV-02, INV-04, and INV-05.
- **A2 — Authoritative Operation Enforcement** is reflected principally through INV-01, INV-06, INV-12, and INV-13.
- **A3 — Authoritative Economic Determination** is reflected principally through INV-03, INV-04, INV-05, and INV-10.
- **A4 — Complete Backing Enforcement** is reflected through INV-10, INV-11, and INV-12.
- **A5 — Causal Exercise and Fulfillment Integrity** is reflected through INV-06, INV-07, and INV-08.
- **A6 — Economic Authority and Trust Separation** remains an architectural responsibility rather than a separate top-level invariant. Its realization must prevent authority or trust arrangements from creating pathways that bypass or invalidate the canonical invariant set.
- **A7 — Atomic Economic Composition** is reflected through INV-13.
- **A8 — Authoritative Information Continuity** is reflected compositionally through INV-02, INV-04, INV-08, and INV-09 as applicable. INV-05 and INV-10 then protect correctness of commitment and backing derivations performed from the authoritative information whose continuity is protected by INV-04.

## 9.2 State-Information Coverage

- **SM-1 — Persistent Commitment Authoritative Basis** is protected principally through INV-02, INV-04, INV-05, INV-08, and INV-09.
- **SM-2 — Protected Execution Service Semantic Basis** participates in INV-02 where admission-fixed, INV-04 where continued authoritative knowability is future-required, and INV-10 when consumed by backing derivation.
- **SM-3 — Backing-Domain Semantic Basis** participates in INV-04 for continuity and INV-10 for correct backing derivation; INV-02 additionally applies where the relevant semantics were fixed by admission.
- **SM-4 — Derived Authoritative Economic State** is protected principally through INV-05 and INV-10, while INV-04 protects continued authoritative knowability where future normative behavior depends upon that result.
- **SM-5 — Transition-Local Causal Evidence** participates in INV-06, INV-07, and INV-13 while necessary to establish authoritative consequences. INV-04 applies only where future normative behavior independently requires continued authoritative knowability, and INV-09 applies where an economically meaningful causal distinction must remain preserved.
- **SM-6 — External / Shared-Resource Authoritative State** participates in INV-03 where external admission is required; INV-04 where future-required authoritative information must remain knowable; and INV-10, INV-11, INV-12, and INV-13 for shared-resource backing correctness.

This coverage does not require each architectural responsibility or information class to have its own invariant.

---

# 10. Authoritative Information Composition

The information-related invariants protect distinct successive correctness boundaries.

### INV-02 — Admission Semantic Continuity

**Does the admitted relationship continue to mean what successful O1 established?**

### INV-03 — Authoritative Fact Admission Integrity

**Where external admission is required, did the fact legitimately acquire authority?**

### INV-04 — Authoritative Derivability Continuity

**Does every economically meaningful fact, quantity, classification, consequence, or relationship required by future normative behavior remain authoritatively knowable, either directly or through deterministic reconstruction from authoritative facts?**

### INV-05 — Commitment Derivation Integrity

**Given the applicable authoritative basis, is the commitment-level derived result correct?**

### INV-09 — Economic Cause Continuity

**Where canonical semantics continue to depend upon an economically meaningful causal distinction, does that distinction remain preserved?**

These properties are complementary rather than interchangeable.

Stable meaning does not guarantee continued authoritative knowability; continued knowability does not guarantee correct derivation; correct derivation does not establish legitimate external fact admission; and computational sufficiency does not necessarily preserve every economically meaningful causal distinction.

---

# 11. Backing-Invariant Composition

INV-10, INV-11, and INV-12 form three successive but independently falsifiable correctness boundaries.

### INV-10 — Backing Derivation Integrity

**Construct the correct backing problem.**

The applicable binding Capacity Obligations, qualifying Supporting Capacity, Protected Execution Service and backing-domain semantics, and applicable feasibility relation must be correctly represented.

### INV-11 — Backing Sufficiency

**Require the authoritative state to satisfy that backing problem.**

A correctly constructed backing relationship cannot remain authoritative where its Specification-defined feasibility relation is unsatisfied.

### INV-12 — Complete Backing Enforcement

**Ensure no capacity-threatening authoritative pathway escapes that feasibility constraint.**

Even a transition that happens to leave sufficient capacity must not bypass the applicable preservation boundary where its prospective economic effect can impair Supporting Capacity required by a binding Capacity Obligation.

INV-04 precedes this backing chain by protecting continued authoritative knowability of information required for future backing determinations.

---

# 12. Exercise and Fulfillment Invariant Composition

INV-06, INV-07, and INV-08 protect three successive O2 correctness boundaries.

### INV-06 — Exercise Authorization Integrity

**May this exercise legitimately produce an authoritative exercise-specific economic effect against this commitment?**

### INV-07 — Fulfillment Attribution Integrity

**What actual delivery may legitimately become fulfillment of this specific authoritative exercise and commitment?**

### INV-08 — Fulfillment Conservation

**What exact entitlement-accounting consequence must that authoritative fulfillment produce and preserve?**

This partition preserves the upstream distinctions among exercise, qualifying execution, delivery, fulfillment, and fulfillment accounting without independently redefining those concepts.

---

# 13. Authoritative Economic Finality

INV-13 protects the complete economic-finality boundary of operations whose Specification-defined meaning consists of multiple economically coupled authoritative effects.

Its governing interpretation is:

> **Atomicity applies to authoritative economic finality, not to the absence of intermediate computation.**

A realization may therefore use transition-local computation, evidence, or intermediate representation without violating INV-13, provided no improper subset becomes the authoritative economic result.

Failure integrity follows as an explicit consequence:

> **Failure Integrity = Non-Success + Zero Authoritative Economic Residue**

Accordingly, Failure Preservation is not an additional top-level invariant.

It is the non-success consequence of the complete-or-zero authoritative economic-finality property protected by INV-13.

---

# 14. Downstream Verification Boundary

This document defines **what must remain true**.

It does not define how a realization proves those properties.

The downstream `testing-strategy.md` must derive verification obligations from the canonical Specification, Architecture, State Machine, and invariant set.

Verification must not equate invariant preservation with complete correctness.

Where an economically meaningful quantity, classification, consequence, relationship, or reconstruction is deterministically derived from authoritative facts, verification must independently establish equivalence between the realization's derivation and the normative derivation.

Accordingly:

> **Safety Verification = Invariant Preservation + Authoritative Derivation Equivalence**

Acceptance must also establish both sides of each normative boundary:

- behavior forbidden by the canonical semantics cannot become authoritative; and
- behavior permitted or required by those semantics can become authoritative under the applicable conditions.

The Testing Strategy owns the concrete verification model, test classes, adversarial scenarios, traceability to tests, realization-specific proof obligations, and acceptance criteria.

`invariants.md` introduces none of those mechanisms.

---

# 15. Canonical Set Summary

The minimum complete Standby invariant set is:

1. **INV-01 — Commitment Establishment Integrity**
2. **INV-02 — Admission Semantic Continuity**
3. **INV-03 — Authoritative Fact Admission Integrity**
4. **INV-04 — Authoritative Derivability Continuity**
5. **INV-05 — Commitment Derivation Integrity**
6. **INV-06 — Exercise Authorization Integrity**
7. **INV-07 — Fulfillment Attribution Integrity**
8. **INV-08 — Fulfillment Conservation**
9. **INV-09 — Economic Cause Continuity**
10. **INV-10 — Backing Derivation Integrity**
11. **INV-11 — Backing Sufficiency**
12. **INV-12 — Complete Backing Enforcement**
13. **INV-13 — Authoritative Economic Atomicity**

Properties represented as explicit consequences of these invariants do not constitute additional canonical invariant families.

The set is minimal in the sense that no top-level invariant may be removed without losing independent correctness protection. Minimality does not reduce the visibility, traceability, or downstream verification obligation of invariant consequences.