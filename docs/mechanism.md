# Standby — Mechanism

**Canonical Document #3**  
**Layer:** Behavior  
**Status:** FINAL PASS / FROZEN

---

## 1. Purpose and Boundary

This document defines the minimum enforceable causal behavior required to make the Standby Economic Agreement reliably true within the economic environment established by `context.md`.

The Economic Agreement defines the economic rights, obligations, and relationships that must hold among the relevant participants. The Mechanism defines the minimum causal enforcement required to establish, preserve, fulfill, and release those relationships despite independent activity affecting shared mutable AMM liquidity.

Accordingly:

> **Economic Agreement defines the required economic truth. Mechanism defines the minimum causal behavior required to make that truth reliably hold.**

The Mechanism does not yet prescribe:

- the complete normative decomposition of protocol requirements;
- specific protocol operations or interfaces;
- component structure or architectural responsibility assignment;
- persistent state representation;
- formal protocol invariants;
- verification procedures or test obligations; or
- implementation-specific realization.

Those concerns belong to downstream canonical documents.

---

## 2. Mechanism Objective

Standby realizes a bounded future execution entitlement over shared mutable AMM liquidity without requiring the supporting liquidity to be segregated or exclusively reserved.

To accomplish this, the Mechanism must:

- admit only commitments whose corresponding Capacity Obligations can be supported alongside existing obligations;
- preserve sufficient Supporting Capacity while those obligations remain economically binding;
- permit exercise only when the corresponding entitlement is presently exercisable;
- recognize fulfillment only to the extent that the promised result is actually produced for the Beneficiary and causally attributable to the corresponding entitlement;
- release Capacity Obligations when their underlying economic relationship ceases without falsely representing release as fulfillment; and
- constrain economically authoritative use of the shared resource so that existing Capacity Obligations remain compatible with that use.

The protected object is therefore not a segregated quantity of particular assets.

It is the continued availability of the economic property required by the Economic Agreement:

> **sufficient Supporting Capacity for Aggregate Remaining Entitlement.**

---

## 3. Protected Economic Relationship

The Economic Agreement establishes the following economic relationship:

> **Supporting Capacity ≥ Aggregate Remaining Entitlement**

This remains an economic relationship at the Mechanism layer. It is not yet a formal protocol invariant or a prescription of the exact normative derivation by which either quantity must be computed.

The Mechanism must cause every economically authoritative outcome governed by Standby to remain consistent with this relationship for as long as valid Capacity Obligations exist.

A commitment may create a present Capacity Obligation as soon as the corresponding entitlement becomes valid, even when that entitlement is not yet exercisable. Economic reliance therefore begins with validity rather than exercise eligibility.

Equality between Supporting Capacity and Aggregate Remaining Entitlement is sufficient. The Mechanism introduces no requirement for excess capacity beyond that required by the Economic Agreement.

The protected economic property is **Supporting Capacity**, not ownership or reservation of particular underlying assets.

---

## 4. Core Causal Responsibilities

The following six responsibilities constitute the core causal behavior of the Standby Mechanism.

The definitions in this section are the canonical normative definitions of M1–M6 within this document.

### M1 — Commitment Admission

The Mechanism must prevent a new commitment from becoming economically authoritative unless its corresponding Capacity Obligation can be supported together with all Capacity Obligations already arising from valid entitlements.

Successful admission establishes the new entitlement and its corresponding Capacity Obligation as one economically coherent consequence.

Once the entitlement becomes valid, its Remaining Entitlement contributes to the economic burden placed upon Supporting Capacity, regardless of whether the entitlement is already exercisable.

Admission must therefore preserve the protected economic relationship at the moment the new right–obligation relationship becomes authoritative.

### M2 — Backing Preservation

The Mechanism must preserve sufficient Supporting Capacity for all Aggregate Remaining Entitlement for as long as the corresponding Capacity Obligations remain economically binding.

Any economically authoritative activity capable of reducing Supporting Capacity must therefore be constrained so that its resulting economic condition does not leave valid Remaining Entitlements unsupported.

Backing preservation protects the required capacity property of the shared resource. It does not require reservation, segregation, or preservation of particular underlying assets.

### M3 — Exercise Eligibility and Attributable Fulfillment

The Mechanism must permit exercise only when the specific entitlement being exercised is presently exercisable.

Validity alone does not establish exercisability.

A successful exercise may reduce the entitlement only to the extent that the promised result is actually produced for the Beneficiary and is causally attributable to that specific entitlement.

Accordingly:

> **Exercise is not itself Fulfillment.**

and:

> **Execution alone is not Fulfillment.**

Fulfillment requires actual realization of the promised result for the Beneficiary.

Any fulfillment-driven reduction in Remaining Entitlement must correspond to the Actual Attributable Fulfilled Amount.

The Mechanism must therefore preserve the causal distinction among exercise eligibility, invocation, attributable execution, beneficiary fulfillment, and reduction of the corresponding economic obligation even when a particular realization performs those effects within a single atomic transaction.

### M4 — Obligation Release

The Mechanism must cease burdening Supporting Capacity with a Capacity Obligation when the economic conditions sustaining the corresponding entitlement no longer hold.

Such release must remain economically distinct from fulfillment.

An obligation that ceases because its entitlement is no longer valid or enforceable must not be represented as though the Beneficiary received the promised result.

The Mechanism does not inherently require an explicit expiry or release transition when loss of the relevant economic condition can instead be authoritatively derived.

### M5 — Shared-Resource Compatibility

The Mechanism must preserve the ability for the protected resource to remain part of shared AMM liquidity rather than requiring segregation or exclusive reservation.

Shared-resource activity may continue while Capacity Obligations exist, provided that any such activity that becomes economically authoritative remains compatible with those obligations and does not produce an authoritative condition in which Aggregate Remaining Entitlement exceeds Supporting Capacity.

This requirement does not imply that every activity compatible with Standby's Capacity Obligations must necessarily be permitted by the protocol. Independently justified constraints may also govern shared-resource activity.

### M6 — Authoritative Economic Determination

The Mechanism must derive or admit authoritative determinations of every economically meaningful fact whose value governs Commitment Admission, Backing Preservation, Exercise Eligibility and Attributable Fulfillment, Obligation Release, or Shared-Resource Compatibility.

Such enforcement must operate from the economic reality defined by the Economic Agreement rather than from an ungrounded or independently mutable assertion.

Economically meaningful determinations may include, where applicable:

- Supporting Capacity;
- Remaining Entitlement;
- Aggregate Remaining Entitlement;
- entitlement validity;
- entitlement exercisability;
- Actual Attributable Fulfilled Amount; and
- facts determining whether a Capacity Obligation continues or has been released.

Mechanism establishes the requirement for authoritative determination of these facts and their economic purpose. The complete normative derivation of those facts belongs to Protocol Specification.

---

## 5. Cross-Cutting Mechanism Integrity

The following requirements do not constitute additional lifecycle stages or independent economic agreements.

They constrain the operation of M1–M6 wherever applicable.

The definitions in this section are the canonical normative definitions of A1–A5 within this document.

### A1 — Transition Authority Integrity

Every economically meaningful transition governed by the Mechanism must occur only through an actor, condition, or authoritative process whose ability to cause that transition is consistent with the rights, obligations, and roles established by the Economic Agreement.

Authority may therefore arise through an authorized participant or through an authoritative economic condition. Mechanism does not require every economically meaningful change to result from discretionary action by an actor.

### A2 — Complete Enforcement Coverage

Every economically authoritative pathway capable of changing a fact or resource condition governed by the Mechanism must be subject to the applicable Mechanism constraints before its economic effect can become authoritative.

Correct enforcement through one pathway is insufficient if an economically equivalent authoritative effect can arise through another pathway that escapes the applicable constraint.

### A3 — Atomic Economic Finality

When a Mechanism transition requires multiple economically interdependent effects to realize one Economic Agreement consequence, those effects must become authoritative as one indivisible economic outcome.

Failure of any required effect must prevent the other interdependent effects from becoming economically authoritative when partial authoritative completion would create a condition forbidden by the Economic Agreement.

This is a requirement for **economic atomicity**.

It does not, at the Mechanism layer, prescribe transaction-level atomicity or a particular implementation technique for achieving the required indivisibility.

### A4 — Commitment Causal Integrity

Every authoritative effect that establishes, exercises, fulfills, reduces, or releases a commitment must remain causally attributable to the specific economic relationship whose rights and obligations it changes.

Correct determination of an amount or economic fact is insufficient if that fact is attributed to the wrong commitment.

Commitment Causal Integrity therefore applies across the economic relationship from Establishment through Persistence and ultimately to Fulfillment or Release.

### A5 — Authoritative Economic Continuity

Every economically authoritative consequence that continues to govern subsequent enforcement must remain authoritatively knowable for as long as that enforcement depends upon it, either directly or through deterministic reconstruction from authoritative facts.

Transition-local causal evidence need not persist after the economically final outcome is established unless later authoritative reasoning depends upon it.

Mechanism therefore requires continuity of economically relevant authoritative knowledge without prescribing which derived values, classifications, or intermediate causal facts must be stored directly.

---

## 6. Causal Composition

M1–M6 and A1–A5 compose into one continuing mechanism rather than a collection of independent checks.

Conceptually, the economic relationship progresses through:

**Commitment Admission → Backed Persistence → Fulfillment or Release**

During Backed Persistence, shared AMM activity may continue subject to Backing Preservation and Shared-Resource Compatibility.

A valid entitlement may remain non-exercisable while already imposing a Capacity Obligation. Once its exercise conditions hold, an authorized exercise may attempt to produce attributable fulfillment. Successful fulfillment reduces the corresponding Remaining Entitlement only by the amount actually fulfilled for the Beneficiary.

Alternatively, when the economic conditions sustaining any Remaining Entitlement cease, the Capacity Obligation corresponding to that remaining entitlement is released. Prior partial fulfillment does not convert that release into fulfillment.

Throughout these causal relationships:

- authoritative economic facts must be correctly determined;
- only legitimate authority may cause governed effects;
- all economically authoritative pathways must remain covered;
- interdependent economic effects must reach atomic economic finality;
- effects must remain attributable to the correct commitment; and
- persistent economic consequences must remain authoritatively knowable while later enforcement depends upon them.

**This causal composition is not a protocol state machine.**

It does not prescribe canonical lifecycle states, state variables, transition functions, storage representation, or implementation sequencing.

---

## 7. Derivational Cross-Validation

The canonical Mechanism above was derived from `context.md` and `economic-agreement.md`.

### 7.1 Economic Agreement Traceability

The following mapping makes the upstream derivation explicit. It does not redefine the Mechanism categories in §§4–5.

| Economic Agreement category | Primary Mechanism realization |
| --- | --- |
| EA1 — Agreement Participants and Economic Roles | A1, A4 |
| EA2 — Economic Subject of the Agreement | M2, M5, M6 |
| EA3 — Beneficiary Right | M1, M3 |
| EA4 — Corresponding Economic Obligation | M1, M2, M3, M4, A5 |
| EA5 — Establishment, Validity, and Extent | M1, M3, M4, M6, A5 |
| EA6 — Fulfillment and Release | M3, M4, A3, A4 |
| EA7 — Economic Compatibility Constraint | M2, M5, M6, A2 |

### 7.2 Historical Mechanism Cross-Validation

Previously frozen Standby mechanism semantics are used here only as a cross-validation target. Their historical transition names, mathematical notation, and realization details do not become normative Mechanism definitions merely by being used for comparison.

#### Commitment Creation

M1 — Commitment Admission, together with M6 and the applicable cross-cutting integrity constraints, independently recovers the previously validated requirement that a new commitment may become authoritative only when its additional obligation can be supported alongside existing valid obligations.

It also recovers the previously validated conclusion that a future-starting commitment burdens Supporting Capacity when its entitlement becomes valid rather than only when it later becomes exercisable.

#### Exercise

M3 — Exercise Eligibility and Attributable Fulfillment, together with M6, A1, A3, A4, and A5, independently recovers the previously validated exercise semantics:

- the entitlement must be eligible for exercise;
- exercise must relate to the correct commitment;
- actual economically relevant execution must occur;
- the promised result must actually be produced for the Beneficiary;
- the fulfilled amount must be authoritatively determined; and
- the corresponding economic obligation may be reduced only by that attributable fulfilled amount.

#### Backing-Preserving Resource Activity

M2 — Backing Preservation and M5 — Shared-Resource Compatibility, together with M6 and A2, independently recover the previously validated requirement that every economically authoritative resource transition capable of reducing usable Supporting Capacity must preserve sufficient backing for existing valid obligations.

#### Release

M4 — Obligation Release independently recovers the previously validated conclusion that loss of validity or enforceability may release the Capacity Obligation corresponding to the Remaining Entitlement without falsely representing that release as fulfillment. Prior partial fulfillment remains fulfillment and does not change the economic classification of the later release of the remainder.

The canonical Mechanism is therefore semantically consistent with the previously frozen Standby mechanism while remaining independently derived from the canonical upstream documents.

---

## 8. Minimum-Mechanism Exclusions

The minimum Standby Mechanism does not inherently require:

- live NAV;
- dedicated reserves;
- epochs;
- overbooking;
- custom accounting;
- dynamic fees;
- cancellation;
- amendment;
- explicit expiry transitions;
- protocol-native premium settlement;
- persistent exercise-intermediate state;
- redundant lifecycle classifications;
- cached Aggregate Remaining Entitlement; or
- identical or full-range LP positions.

These exclusions do not prohibit a particular realization from using such mechanisms where independently justified.

They establish only that those mechanisms are not necessary consequences of the canonical Standby Economic Agreement or minimum Mechanism.

Economic compensation remains conceptually relevant to voluntary participation in Standby. Concrete pricing, premium collection, distribution, and LP accrual mechanics are not part of the minimum Mechanism established here.

---

## 9. General Protocol Semantics and Reference Realization

The requirements established in this document define the general Standby Mechanism.

They do not make any particular ETHGlobal realization constitutive of Standby.

A reference realization may employ choices such as:

- a Uniswap v4 hook as an authoritative enforcement component;
- a dedicated exercise path or router;
- a bounded number of potentially live commitments;
- a particular protected commitment direction;
- transaction-scoped causal evidence;
- particular historical-record retention;
- specific hook permissions; or
- bounded-gas implementation techniques.

Such choices may realize the canonical Mechanism but do not become general Standby protocol requirements unless independently derived by the appropriate downstream canonical document.

In particular, implementation-specific limits, component boundaries, storage arrangements, routing assumptions, and callback structures remain outside the general Mechanism defined here.

---

## 10. Handoff to Protocol Specification

The Economic Agreement established the economic truth that Standby must preserve.

This Mechanism establishes the minimum causal behavior required to make that economic truth reliably hold over shared mutable AMM liquidity.

The next canonical layer must transform these causal responsibilities and integrity constraints into a complete normative protocol specification.

The handoff question is:

> **Given the frozen Mechanism's causal responsibilities and integrity constraints, what complete normative protocol requirements must govern every authoritative operation, condition, and transition so that the Mechanism is realized without ambiguity, hidden authority, unsupported economic states, or unintended strengthening or weakening of the Economic Agreement?**

The transformation is:

> **Mechanism: What causal enforcement is necessary?**  
> **Specification: What exactly must the protocol normatively permit, require, reject, derive, and preserve?**

That question is the starting point for `spec.md`.
