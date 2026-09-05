# Standby Protocol Specification

**Canonical Document #4 --- FINAL PASS / FROZEN**

## 1. Purpose and Specification Boundary

### 1.1 Purpose

This document defines the complete normative behavioral requirements of
the Standby protocol required to realize the frozen Mechanism.

Standby provides bounded future execution assurance from shared mutable
AMM liquidity. The protocol does not reserve particular liquidity for a
Beneficiary. Instead, it constrains authoritative behavior so that
admitted Capacity Obligations remain supported by qualifying executable
capacity while those obligations remain binding.

The Economic Agreement defines what must economically be true among the
relevant participants. The Mechanism defines the minimum causal
enforcement required to make that agreement hold. This Specification
defines exactly what authoritative protocol behavior must permit,
require, reject, derive, preserve, and make knowable so that the
Mechanism is realized without ambiguity.

### 1.2 Specification Responsibility

The Protocol Specification governs authoritative operation classes,
derived authoritative consequences, authoritative economic definitions
and deterministic derivations, normative authority,
success/rejection/failure semantics, causal attribution, cross-operation
preservation, and authoritative information continuity.

The Specification defines normative behavior, not component
architecture, storage representation, lifecycle enums, callback/function
structure, verification technique, test implementation, or other
implementation techniques unless independently required by normative
behavior.

### 1.3 Normative Language

"Must" and "must not" express normative protocol requirements. "May"
identifies behavior permitted but not required.

"Authoritative" means capable of governing subsequent normative protocol
behavior or determining an economically meaningful protocol consequence.

### 1.4 Single Normative Ownership

Every canonical semantic definition, derivation, predicate, behavioral
requirement, and cross-cutting constraint has exactly one normative
home. Reference, composition, traceability, exclusion, and realization
sections may summarize or apply a rule but do not independently redefine
it.

## 2. Normative Semantic Model

### 2.1 S1 --- Authoritative Operation Model

An **authoritative operation** is governed behavior through which an
attempted protocol action may produce an authoritative economic
consequence. Operation classes are defined by economic effect rather
than implementation function, callback, component, or interface.

### 2.2 S2 --- Derived Authoritative Consequences

A **derived authoritative consequence** is an economically meaningful
consequence that follows deterministically when its complete
authoritative normative predicate holds. It does not require a
discretionary lifecycle operation merely to become authoritative.

### 2.3 S3 --- Authoritative Economic Definitions and Derivations

The Specification defines authoritative economic terms established by
governed behavior and deterministic normative derivations of every
economically meaningful quantity, classification, and relationship whose
value governs protocol behavior.

#### E1 --- Authoritative Commitment Terms

A successfully established commitment must have authoritative terms
sufficient to determine the Beneficiary, Protected Execution Service,
admitted entitlement extent, validity conditions, exercisability
conditions, qualifying fulfillment semantics, and non-fulfillment
release conditions.

Each term must obtain authority from an authorized source or
deterministic rule. A term does not become authoritative merely because
an operation initiator supplied it. Once established, a term must not
change unless an independently specified authoritative operation permits
that change and defines its consequences. Minimum Standby defines no
amendment operation.

#### E2 --- Entitlement Validity

An entitlement is **valid** exactly when it has been successfully
established and no authoritative validity-ending condition defined by
its terms has caused enforceability to cease.

Validity is independent of exercisability. A valid entitlement may be
presently non-exercisable while still imposing a Capacity Obligation.
Loss of validity is not fulfillment.

#### E3 --- Entitlement Exercisability

An entitlement is **exercisable** exactly when it is valid and all
authoritative exercise conditions defined by its terms presently hold.

Every exercisable entitlement is valid. A valid entitlement need not be
exercisable. Exercisability alone is not exercise, execution, delivery,
fulfillment, or entitlement reduction.

#### E4 --- Actual Attributable Fulfilled Amount

The **Actual Attributable Fulfilled Amount** is the amount of the
promised result actually delivered for the Beneficiary's benefit through
qualifying execution and causally attributable to the specific
authoritative exercise of the specific commitment.

Qualifying execution without Beneficiary delivery is not fulfillment.
Delivery not causally attributable to the specific exercise is not
fulfillment of that exercise.

#### E5 --- Remaining Entitlement

For a specific commitment, define:

-   (i): the commitment;
-   (C_i): its authoritative admitted entitlement extent, in the
    promised-result denomination;
-   (F_i): its cumulative Actual Attributable Fulfilled Amount, in the
    same denomination;
-   (R_i): its Remaining Entitlement, in the same denomination.

The Remaining Entitlement is:

\[ R_i = C_i - F_i \]

and must satisfy:

\[ 0 `\le `{=tex}R_i `\le `{=tex}C_i. \]

Remaining Entitlement records how much admitted entitlement has not been
fulfilled. It is not by itself a statement that the remaining amount
currently imposes a Capacity Obligation. Non-fulfillment release does
not require the Remaining Entitlement to be rewritten as zero.

#### E6 --- Aggregate Remaining Entitlement

Define:

- \(j\): a Protected Execution Service;
- \(I_j\): the set of commitments whose Capacity Obligations are currently binding and are assigned to the authoritative backing domain applicable to service \(j\);
- \(R_i\): Remaining Entitlement of each commitment \(i\) in \(I_j\);
- \(ARE_j\): Aggregate Remaining Entitlement applicable to service \(j\), in the promised-result denomination applicable to that backing domain.

A Protected Execution Service and a backing domain are related normative concepts but are not necessarily identical. Backing-domain identity, compatibility, independence, and interdependence are governed by SPEC-B8, SPEC-B11, and SPEC-B12.

Aggregate Remaining Entitlement is:

\[ ARE_j = `\sum`{=tex}\_{i `\in `{=tex}I_j} R_i. \]

A valid commitment with positive Remaining Entitlement contributes even
when not presently exercisable. A released unfulfilled remainder does
not contribute.

#### E7 --- Supporting Capacity and Backing Sufficiency

A **Protected Execution Service** is the authoritative economic service
against which a commitment's entitlement and Supporting Capacity are
defined. It comprises the designated shared AMM resource, protected
execution direction, promised-result denomination, and qualifying
execution conditions necessary to determine both Supporting Capacity and
successful fulfillment.

For a Protected Execution Service, define:

-   (j): that service;
-   (s): current authoritative state of its designated shared AMM
    resource;
-   (x): a positive representable amount of promised result in the
    service's denomination;
-   (Q_j(s,x)): the normative predicate true exactly when a qualifying
    exact execution from state (s) can deliver exactly amount (x) under
    service (j);
-   (SC_j(s)): Supporting Capacity for service (j) in state (s);
-   (ARE_j): Aggregate Remaining Entitlement relying upon the applicable
    backing domain.

Supporting Capacity is the greatest representable promised-result amount that itself qualifies for exact execution under the authoritative service semantics:

\[ SC_j(s) = `\max `{=tex}{x `\mid `{=tex}Q_j(s,x)}. \]

Where no positive representable amount qualifies, Supporting Capacity is
zero.

Backing is sufficient exactly when:

\[ SC_j(s) `\ge `{=tex}ARE_j. \]

Equality is sufficient. Supporting Capacity is not TVL, raw token
balance, nominal liquidity, LP ownership, or segregated assets; it is
qualifying directional executable capacity under the authoritative
current resource condition.

### 2.4 S4 --- Normative Authority

Normative authority determines why an operation, term, fact, or derived
consequence may become authoritative.

The Specification distinguishes Operation Invocation Authority (A-OP),
Authoritative Term Determination (A-TERM), Authoritative Fact Admission
(A-FACT), and Condition-Derived Authority (A-COND).

Authority to invoke an operation is not authority to determine every
term, admit every fact, or choose a derived consequence.

### 2.5 S5 --- Normative Effect and Failure Semantics

A successful governed operation must produce the complete set of
economically interdependent authoritative effects required for its
normative consequence. An operation lacking a required precondition must
not produce a consequence depending upon it. Failure must not leave
authoritative a forbidden proper subset of interdependent effects or a
forbidden change to the protected relationship.

A derived consequence must follow when its complete authoritative
predicate holds and must not follow when it does not.

These requirements impose atomic economic finality, not blanket
transaction-level atomicity.

### 2.6 S6 --- Normative Causal Attribution

Every authoritative operation, fact, fulfillment, reduction, release,
and derived consequence affecting a commitment must remain causally
attributable to the specific economic relationship whose rights or
obligations it changes.

Attribution requires continuing authoritative distinguishability but not
a particular identifier or storage representation.

### 2.7 S7 --- Cross-Operation Economic Preservation

Every governed behavior must be evaluated against relevant authoritative
consequences of prior behavior. Every authoritative pathway capable of
producing a governed economic effect remains subject to applicable
requirements regardless of implementation form or operation name.
Derived consequences participate in later normative reasoning. Backing
quantities compose only according to authoritative backing-domain
relationships.

Correctness must hold at every economically authoritative boundary
across permitted sequences. Order independence is not generally
required.

### 2.8 S8 --- Authoritative Information Continuity

Every authoritative fact, consequence, distinction, or sufficient
derivational basis required by future normative behavior must remain
authoritatively knowable for as long as that dependency exists, directly
or through deterministic reconstruction from authoritative facts.

Transition-local causal evidence need not persist after the economically
final consequence is established unless later normative reasoning
independently depends upon it.

## 3. Authoritative Behavioral Surface

### 3.1 O1 --- Commitment Establishment

O1 is the authoritative operation class through which a new Beneficiary
entitlement and corresponding Capacity Obligation may come into
existence.

### 3.2 O2 --- Commitment Exercise and Fulfillment

O2 is the authoritative operation class through which a presently
exercisable entitlement may be invoked and may produce qualifying
attributable fulfillment and exact Remaining Entitlement reduction.

### 3.3 O3 --- Backing-Affecting Shared-Resource Transition

O3 is any authoritative activity capable of changing Supporting Capacity
while Capacity Obligations relying upon that capacity exist. O3 is
classified by economic effect rather than operation name.

### 3.4 D1 --- Validity Consequence

D1 is the derived consequence by which a successfully established
entitlement is economically operative while its authoritative validity
conditions remain satisfied.

### 3.5 D2 --- Exercisability Consequence

D2 is the derived consequence by which a valid entitlement becomes
eligible for O2 when its complete authoritative exercise conditions
hold.

### 3.6 D3 --- Fulfillment Exhaustion Consequence

D3 is the derived consequence by which a commitment has no Remaining
Entitlement and no continuing Capacity Obligation because its admitted
entitlement has been exhausted through authoritative attributable
fulfillment.

### 3.7 D4 --- Non-Fulfillment Release Consequence

D4 is the derived consequence by which an unfulfilled Remaining
Entitlement ceases to impose a Capacity Obligation because an
authoritative validity-ending condition caused the entitlement to cease
to be valid. D4 is release, not fulfillment.

## 4. Governed Operation Requirements

### 4.1 SPEC-E --- Commitment Establishment

**SPEC-E1 --- Establishment Invocation Authority.** An establishment
attempt may become authoritative only when initiated through authority
valid for establishing that specific economic relationship.

**SPEC-E2 --- Authoritative Commitment Terms.** Every attempt must
determine the complete E1 terms from authorized sources or
Specification-defined rules. Caller input is not authoritative merely
because the caller has invocation authority.

**SPEC-E3 --- Determinate Establishment Consequence.** Successful
establishment immediately creates a valid Beneficiary entitlement and
corresponding Capacity Obligation. The full admitted extent is initially
unfulfilled and immediately participates in applicable Aggregate
Remaining Entitlement. Future exercisability does not defer backing.

**SPEC-E4 --- Backing Sufficiency at Admission.** Before a commitment
may become authoritative, the resulting Aggregate Remaining Entitlement,
including its full admitted extent, must satisfy E7 Backing Sufficiency
against applicable Supporting Capacity. Equality is permitted.

**SPEC-E5 --- Complete Establishment Success.** Success must produce as
one authoritative economic consequence exactly one commitment
relationship containing its authoritative terms, Beneficiary
entitlement, Capacity Obligation, initial Remaining Entitlement, correct
backing-domain inclusion, and authoritative basis for subsequent
validity, exercisability, fulfillment, release, attribution, and backing
reasoning.

**SPEC-E6 --- Establishment Rejection and Failure Preservation.** If any
establishment requirement fails, no part of the proposed relationship
may become authoritative. Failure must not create an entitlement,
Capacity Obligation, Aggregate Remaining Entitlement increase, partially
admitted terms usable later, or partial lifecycle consequence.

### 4.2 SPEC-X --- Exercise and Fulfillment

**SPEC-X1 --- Commitment-Specific Exercise Target.** Every exercise
attempt must identify one specific authoritative commitment.

**SPEC-X2 --- Exercise Invocation Authority.** An exercise may become
authoritative only under authority valid for the targeted commitment.
The initiator need not be the Beneficiary unless the terms require it.

**SPEC-X3 --- Validity Requirement.** Only a currently valid entitlement
may be exercised. Positive Remaining Entitlement alone is insufficient
after release.

**SPEC-X4 --- Exercisability Requirement.** A valid entitlement may be
exercised only when all authoritative exercisability conditions
presently hold.

**SPEC-X5 --- Authoritative Exercise Amount.** For commitment (i), let
(R_i) have the E5 meaning and define (X_i) as the positive authoritative
promised-result amount requested for the specific exercise in the same
denomination. The exercise amount must satisfy:

\[ 0 \< X_i `\le `{=tex}R_i. \]

A successful individual exercise must fulfill exactly (X_i); it must not
be reinterpreted as successful fulfillment of a smaller amount.

**SPEC-X6 --- Qualifying Execution Requirement.** Fulfillment may be
recognized only when qualifying execution of the Protected Execution
Service actually occurs and is causally attributable to the targeted
exercise.

**SPEC-X7 --- Beneficiary Delivery Requirement.** Qualifying execution
contributes to fulfillment only to the extent the promised result is
actually delivered for the Beneficiary's benefit.

**SPEC-X8 --- Actual Attributable Fulfilled Amount.** For a successful
exercise of commitment (i), define (AAF_i) as the Actual Attributable
Fulfilled Amount for that exercise and use (X_i) as defined by SPEC-X5.
Successful exercise requires:

\[ AAF_i = X_i. \]

**SPEC-X9 --- Exact Entitlement Reduction.** For a successful exercise
of commitment (i), define (R_i) as pre-exercise Remaining Entitlement,
(R'\_i) as post-exercise Remaining Entitlement, and use (X_i) as defined
by SPEC-X5. The resulting entitlement must satisfy:

\[ R'\_i = R_i - X_i. \]

No greater or smaller reduction and no reduction of another commitment
may be attributed to that exercise.

**SPEC-X10 --- Commitment-Level Partial Fulfillment.** Where the terms
permit it, an exercise smaller than pre-exercise Remaining Entitlement
may fulfill part of the commitment. This does not permit partial success
of the individual exercise.

**SPEC-X11 --- Fulfillment Exhaustion.** When attributable fulfillment
reduces Remaining Entitlement to zero, D3 must follow. The Capacity
Obligation ceases because the entitlement was fulfilled, not released.

**SPEC-X12 --- Exercise Success Completeness.** Successful exercise must
establish as one authoritative economic consequence the correct target,
authority, validity, exercisability, qualifying attributable execution,
Beneficiary delivery, Actual Attributable Fulfilled Amount, exact
Remaining Entitlement reduction, and resulting obligation consequence.

**SPEC-X13 --- Exercise Rejection.** No authoritative fulfillment may
result from wrong or indeterminate target, absent authority, invalidity,
non-exercisability, impermissible extent, absent qualifying execution,
absent attribution, absent Beneficiary delivery, or indeterminate Actual
Attributable Fulfilled Amount.

**SPEC-X14 --- Exercise Failure Preservation.** Failed exercise must not
falsely reduce Remaining Entitlement, record fulfillment, release a
Capacity Obligation, or leave authoritative a forbidden proper subset of
interdependent successful-exercise effects.

### 4.3 Operation-Specific Backing Requirements

**SPEC-B7 --- Post-Fulfillment Backing Preservation.** A successful O2 that changes authoritative shared-resource condition must leave every backing relationship affected by that change sufficient under the applicable authoritative backing semantics.

**SPEC-B9 --- Establishment Backing Preservation.** O1 may succeed only
when the resulting condition satisfies E7 Backing Sufficiency for the
backing domain affected by the new Capacity Obligation.

**SPEC-B10 --- Shared-Resource Transition Preservation.** O3 may become
authoritative only when its resulting resource condition preserves every
applicable backing relationship whose Supporting Capacity can be changed
by that transition.

## 5. Derived Consequence Requirements

**SPEC-D1 --- Validity Derivation.** An entitlement is valid exactly
when successfully established and no authoritative validity-ending
condition has caused enforceability to cease.

**SPEC-D2 --- Validity Burden Consequence.** For commitment (i), use
(R_i) as defined by E5. While the entitlement is valid and (R_i) is
positive, that unfulfilled remainder imposes the applicable Capacity
Obligation and contributes to applicable Aggregate Remaining
Entitlement.

**SPEC-D3 --- Exercisability Derivation.** An entitlement is exercisable
exactly when currently valid and all authoritative exercise conditions
presently hold.

**SPEC-D4 --- No Consequence from Mere Exercisability.** Becoming
exercisable is not exercise, execution, delivery, fulfillment,
entitlement reduction, or release.

**SPEC-D5 --- Fulfillment Exhaustion Predicate.** Fulfillment exhaustion
holds exactly when authoritative attributable fulfillment has reduced
Remaining Entitlement to zero. A zero produced by other semantics must
not be represented as fulfillment exhaustion.

**SPEC-D6 --- Fulfillment Exhaustion Consequence.** When exhaustion
holds, no Remaining Entitlement from that commitment contributes to
Aggregate Remaining Entitlement, no Capacity Obligation remains, and no
further positive exercise may become authoritative. No separate
completion operation is required.

**SPEC-D7 --- Non-Fulfillment Release Predicate.** D4 occurs when an
authoritative validity-ending condition causes an entitlement with
positive Remaining Entitlement to cease to be valid.

**SPEC-D8 --- Release Is Not Fulfillment.** Released amount must not be
represented as Actual Attributable Fulfilled Amount, fulfillment
exhaustion, or evidence of delivery. Historical Remaining Entitlement
need not be rewritten as zero.

**SPEC-D9 --- Representation Independence.** Derived consequences must
be deterministically authoritative from their predicates and
authoritative facts. Mutable lifecycle-status representations are not
required merely to materialize them.

**SPEC-D10 --- Authoritative Predicate Basis.** Every fact used to
determine a derived consequence must be authoritative because it was
established through authoritative behavior, deterministically derived
from authoritative facts, or admitted through an authorized
external-fact boundary.

**SPEC-D11 --- Exact Consequence from Authoritative Predicate.** When a
complete authoritative predicate holds, its consequence must govern
subsequent behavior without an additional discretionary lifecycle
decision. When it does not hold, the consequence must not become
authoritative.

**SPEC-D12 --- Validity-Termination Semantics.** Commitment terms must
determine applicable validity-ending conditions and whether their
satisfaction permanently terminates the entitlement.

**SPEC-D13 --- Release Finality.** Once D4 releases an unfulfilled
remainder, that entitlement must not regain validity or reimpose a
Capacity Obligation without a new O1 establishment satisfying admission
requirements.

## 6. Cross-Cutting Protocol Requirements

### 6.1 SPEC-A --- Authority and Attribution

**SPEC-A1 --- Operation Invocation Authority.** Every governed operation
must have a normative invocation-authority rule. Permissionless
invocation is valid where that rule permits it.

**SPEC-A2 --- Commitment-Specific Invocation Authority.** Where an
operation changes a specific commitment, invocation authority must be
valid for that commitment.

**SPEC-A3 --- Authoritative Term Authority.** Every authoritative term
must obtain authority from the source or deterministic rule authorized
to establish that class of term. Invocation authority alone does not
confer term authority.

**SPEC-A4 --- No Silent Term Mutation.** No authoritative term may
change after establishment unless an independently specified
authoritative operation permits it and defines its consequences. Minimum
Standby defines no amendment operation.

**SPEC-A5 --- External Fact Admission Authority.** A fact originating
outside the authoritative protocol/resource basis may affect
authoritative Standby behavior only after becoming authoritative through
the admission rule defined for that fact class.

**SPEC-A6 --- Derived-Consequence Authority.** A derived consequence
obtains authority from satisfaction of its complete authoritative
predicate, not discretionary actor choice.

**SPEC-A7 --- Continuing Commitment Distinguishability.** Every
commitment whose relationship may still affect authoritative reasoning
must remain uniquely distinguishable for as long as that distinction is
normatively required. No particular identity representation is required.

**SPEC-A8 --- Operation-to-Commitment Binding.** Every
commitment-specific authoritative operation must be bound to exactly the
commitment whose rights or obligations it may affect.

**SPEC-A9 --- Evidence-to-Exercise Binding.** Every fact relied upon for
qualifying execution, Beneficiary delivery, or Actual Attributable
Fulfilled Amount must be causally bound to the authoritative exercise
for which fulfillment is determined.

**SPEC-A10 --- Effect Scoping.** Commitment-specific effects must be
scoped exclusively to the relationship to which the operation and
evidence are attributable. Resource-derived consequences of a shared
resource change may affect other backing relationships according to
their own derivations.

**SPEC-A11 --- No Cross-Relationship Substitution.** An actor,
operation, fact, execution, delivery, fulfillment, release, or other
consequence attributable to one commitment must not satisfy a
requirement of another merely because descriptive properties match.

**SPEC-A12 --- Authoritative Resource-Fact Basis.** A resource fact may
be treated as authoritative without separate external-fact admission
only when it is part of the authoritative condition of the designated
shared resource under the Protected Execution Service's semantics.

### 6.2 SPEC-C --- Continuity and Composition

**SPEC-C1 --- Dependency-Lifetime Continuity.** Every authoritative
fact, distinction, relationship, or consequence required by future
normative behavior must remain authoritatively knowable for the duration
of that dependency.

**SPEC-C2 --- Direct-or-Reconstructive Knowability.** A required fact or
consequence may remain authoritative directly or through deterministic
reconstruction from authoritative facts, provided either yields exactly
the required normative result.

**SPEC-C3 --- Authoritative Reconstruction.** Reconstruction must use
the Specification-defined authoritative derivation and authoritative
inputs applicable to the consequence.

**SPEC-C4 --- Resolution Semantics Preservation.** Resolution must not
destroy any authoritative distinction between fulfillment and
non-fulfillment release still needed by later normative reasoning.

**SPEC-C5 --- Transition-Evidence Expiration.** Information needed
solely to establish one transition's correctness and causal integrity
need not remain available after its complete economically final
consequence is established unless later behavior independently depends
on it.

**SPEC-C6 --- Consequence Continuity.** Every economically authoritative
consequence must remain directly or reconstructively authoritative for
as long as later normative behavior depends upon it.

**SPEC-C7 --- Authoritative Prior-Consequence Basis.** Every governed
operation must be evaluated against all prior authoritative facts and
consequences on which its correctness depends.

**SPEC-C8 --- Economic-Effect Closure.** Any authoritative pathway
producing a governed economic effect is subject to the applicable
requirement regardless of pathway name, interface, component, or
implementation form.

**SPEC-C9 --- Derived-Consequence Composition.** Every derived
consequence whose predicate holds must participate in subsequent
normative reasoning whether or not a separate operation materializes it.

**SPEC-C10 --- Backing-Domain Composition.** Economic quantities may be
aggregated, offset, or jointly evaluated only where the Specification
establishes the applicable backing-domain relationship. Unrelated
domains must not influence one another; interdependent domains must not
be treated as independent.

**SPEC-C11 --- Sequence Preservation.** For every permitted sequence,
each successive authoritative outcome must satisfy every applicable
requirement when evaluated against the complete authoritative
consequences of the preceding sequence.

**SPEC-C12 --- Authoritative-Boundary Preservation.** Protected economic
relationships must hold at every economically authoritative boundary. A
transient internal condition need not independently satisfy them when it
cannot govern later normative behavior or survive as an authoritative
outcome.

**SPEC-C13 --- No Unjustified Commutativity Requirement.** Independently
permissible operations need not be order-independent where prior
authoritative effects legitimately change later eligibility or outcomes.

**SPEC-C14 --- Resolution-Boundary Release.** After a relationship is
fully resolved and no future Specification requirement depends upon
particular information, that information need not remain normatively
available solely because it once participated in authoritative behavior.

### 6.3 General Backing and Resource Compatibility

**SPEC-B1 --- Qualification Consistency.** Supporting Capacity and
successful fulfillment for the same Protected Execution Service must use
normatively identical qualifying execution conditions.

**SPEC-B2 --- Exact-Output Capacity.** Supporting Capacity must
represent the maximum exact promised-result amount obtainable through
qualifying execution.

**SPEC-B3 --- Boundary Semantics.** Every limiting qualification
condition must have determinate inclusive or exclusive boundary
semantics, applied identically to Supporting Capacity and fulfillment.

**SPEC-B4 --- Conservative Representability.** A discrete Supporting
Capacity value must not round upward beyond the greatest representable
promised-result amount actually deliverable under qualifying conditions.

**SPEC-B5 --- Execution-Semantics Fidelity.** Supporting Capacity must
derive from authoritative AMM execution semantics, including every
resource-level effect materially determining promised-result amount or
qualification. An approximation must not replace the normative
derivation where it can produce a different authoritative result.

**SPEC-B6 --- Downward-Closed Capacity.** Use (s), (j), and (Q_j(s,x))
as defined by E7. Define (y) as any positive representable
promised-result amount in the same service denomination. If (Q_j(s,x))
is true and (y `\le `{=tex}x), then (Q_j(s,y)) must also be true.

**SPEC-B8 --- Backing-Domain Compatibility.** Commitments may contribute
to the same Aggregate Remaining Entitlement only when their Capacity
Obligations rely upon the same authoritative Supporting Capacity domain
and that capacity is sufficient under the qualification applicable to
every included entitlement.

Differences in Beneficiary, exercise authority, admitted entitlement extent, Remaining Entitlement, exercisability timing, validity-ending timing, or fulfillment history do not by themselves require separate backing domains. Differences that change the authoritative Supporting Capacity semantics must not be blindly aggregated.

**SPEC-B11 --- No Cross-Service Backing Double Counting.** Supporting
Capacity relied upon by one Protected Execution Service must not
simultaneously be treated as independently available to another when
fulfillment or another permitted transition in either can impair
capacity relied upon by the other.

**SPEC-B12 --- Cross-Service Feasibility.** Where multiple services rely
upon economically interdependent capacity from the same mutable
resource, admission and every backing-affecting transition must preserve
joint feasibility of all Capacity Obligations relying upon that
resource. Separate scalar Backing Sufficiency tests are valid only where
authoritative derivation establishes backing independence. This
requirement does not assume joint feasibility equals a universal sum
across services. Different protected directions, promised-result denominations, or qualifying execution conditions may therefore require a multidimensional feasibility relationship.

## 7. Normative Relationship Reference

This section is reference-only and introduces no independent normative
definition.

### 7.1 Remaining Entitlement

Using the symbols defined by E5:

\[ R_i = C_i - F_i. \]

### 7.2 Aggregate Remaining Entitlement

Using the symbols defined by E6:

\[ ARE_j = `\sum`{=tex}\_{i `\in `{=tex}I_j} R_i. \]

### 7.3 Supporting Capacity and Backing Sufficiency

Using the symbols defined by E7:

\[ SC_j(s) = `\max `{=tex}{x `\mid `{=tex}Q_j(s,x)} \]

and:

\[ SC_j(s) `\ge `{=tex}ARE_j. \]

### 7.4 Successful Exercise Fulfillment

Using (X_i) as defined by SPEC-X5 and (AAF_i) as defined by SPEC-X8:

\[ AAF_i = X_i. \]

### 7.5 Successful Exercise Reduction

Using (R_i), (R'\_i), and (X_i) as defined by SPEC-X9:

\[ R'\_i = R_i - X_i. \]

### 7.6 Joint Backing Feasibility

SPEC-B11 and SPEC-B12 require joint feasibility where services rely upon
economically interdependent capacity. No universal scalar summation
formula is introduced; a scalar combination is valid only where
authoritative service/resource semantics establish it.

## 8. Behavioral Composition

This section demonstrates composition and introduces no new
requirements.

### 8.1 Establishment Followed by Exercise

O1 establishes an immediately valid entitlement and Capacity Obligation
only after applicable backing requirements pass. A later O2 uses
authoritative terms, current validity, current exercisability, current
Remaining Entitlement, and relevant prior consequences.

### 8.2 Establishment Followed by Shared-Resource Activity

After O1 establishes a Capacity Obligation, any O3 capable of changing
relied-upon Supporting Capacity is subject to applicable post-transition
backing requirements.

### 8.3 Partial Fulfillment Followed by Further Exercise

Where permitted, successful partial commitment fulfillment reduces only
the targeted commitment's Remaining Entitlement by the exact fulfilled
exercise amount. A later O2 uses the resulting Remaining Entitlement.

### 8.4 Fulfillment Exhaustion

When attributable fulfillment reduces Remaining Entitlement to zero, D3
follows and the Capacity Obligation ends because of fulfillment. No
separate completion operation is required.

### 8.5 Partial Fulfillment Followed by Non-Fulfillment Release

A partially fulfilled commitment may later cease to be valid with
positive Remaining Entitlement. D4 removes that unfulfilled remainder
from current backing burden without converting it into fulfillment.

### 8.6 Validity and Exercisability Through Time

Successful establishment creates immediate validity and backing. Future
exercise conditions may delay exercisability. D2 changes exercise
eligibility when its predicate holds but creates no new entitlement or
Capacity Obligation. A later validity-ending predicate may cause D4
without a discretionary expiry operation.

### 8.7 Cross-Service Resource Effects

An operation attributable to one commitment may change shared-resource
condition and therefore Supporting Capacity for multiple services.
Commitment-specific effects remain scoped to their target;
resource-derived capacity consequences apply to every economically
affected backing relationship.

### 8.8 Sequential Correctness

Every later operation evaluates against authoritative consequences of
the preceding sequence. Correctness is required at every economically
authoritative boundary. Legitimate order-sensitive outcomes are
permitted.

## 9. Minimum Protocol Exclusions and Boundary Conditions

Minimum Standby does not inherently require:

-   live NAV;
-   dedicated reserves;
-   epochs;
-   overbooking;
-   custom accounting;
-   dynamic fees;
-   cancellation;
-   amendment;
-   explicit expiry transitions;
-   protocol-native premium settlement;
-   persistent intermediate exercise state;
-   redundant lifecycle enums;
-   cached Aggregate Remaining Entitlement; or
-   identical or full-range LP positions.

Non-segregation is constitutive shared-resource semantics: assurance is
realized by preserving qualifying capacity in mutable shared AMM
liquidity rather than converting protected capacity into an exclusively
reserved resource.

Economic compensation remains conceptually relevant where Beneficiary
value of execution certainty exceeds price paid and price exceeds the
liquidity-supplying side's economic cost. Concrete pricing, collection,
and LP-accrual mechanics are outside the minimum Specification unless
independently justified upstream.

Equality under applicable Backing Sufficiency is sufficient; no hidden
excess-backing requirement is introduced.

## 10. General Protocol Semantics vs. ETHGlobal Reference Realization

Sections 1--9 define or delimit general Standby semantics.

The ETHGlobal reference realization may use a Standby hook as
authoritative enforcement/state owner, a narrow exercise router, one
protected commitment direction per configured pool, bidirectional
ordinary swaps, transaction-scoped exercise evidence, a bounded
potentially-live commitment set, a maximum of sixteen potentially-live
commitments, historical records surviving live-slot reuse, generic
router compatibility, a minimum hook-permission surface, and bounded-gas
techniques.

These choices are not general protocol requirements merely because the
reference realization uses them. The reference realization must not
weaken or reinterpret the general Specification.

Transaction-level atomicity may be a valid or necessary
reference-realization technique while the general Specification requires
atomic economic finality at authoritative economic boundaries.

## 11. Bidirectional Traceability

This section records provenance and introduces no new normative
requirement.

### 11.1 Economic Agreement → Mechanism → Specification

-   EA1 → A1, A4 → S4, S6, SPEC-A and operation-specific authority
    requirements.
-   EA2 → M2, M5, M6 → Protected Execution Service, E7, SPEC-B, SPEC-C.
-   EA3 → M1, M3 → E1--E5, SPEC-E, SPEC-X.
-   EA4 → M1, M2, M3, M4, A5 → E5--E7, SPEC-E, SPEC-X, SPEC-B, SPEC-D,
    SPEC-C.
-   EA5 → M1, M3, M4, M6, A5 → E1--E3, SPEC-E, SPEC-D, SPEC-A, SPEC-C.
-   EA6 → M3, M4, A3, A4 → E4--E6, SPEC-X, SPEC-D, SPEC-A, SPEC-C.
-   EA7 → M2, M5, M6, A2 → E6--E7, SPEC-B, SPEC-C.

### 11.2 Mechanism → Specification

-   M1 → E1, E2, E5, E6, E7; SPEC-E; applicable SPEC-A/B/C.
-   M2 → E6, E7; SPEC-B; SPEC-C.
-   M3 → E2--E5; SPEC-X; SPEC-A; applicable SPEC-D/C.
-   M4 → E2, E5, E6; SPEC-D; SPEC-C.
-   M5 → Protected Execution Service; E7; SPEC-B; SPEC-C.
-   M6 → S3; E1--E7; SPEC-A; SPEC-C.
-   A1 → S4; SPEC-A.
-   A2 → SPEC-B10; SPEC-C8/C11.
-   A3 → S5; SPEC-E6; SPEC-X12--X14; SPEC-C12.
-   A4 → S6; SPEC-X; SPEC-A7--A11; applicable SPEC-C.
-   A5 → S8; SPEC-C.

### 11.3 Specification → Upstream Justification

SPEC-E realizes establishment of the Beneficiary right and corresponding
Capacity Obligation. SPEC-X realizes eligible attributable fulfillment.
SPEC-B preserves mutable shared backing. SPEC-D preserves validity,
exercisability, fulfillment-exhaustion, and release distinctions. SPEC-A
realizes authority and commitment-specific causal integrity. SPEC-C
preserves correctness through information dependencies and operation
sequences.

No requirement family is justified solely by implementation convenience.

## 12. Handoff to Architecture

Architecture must determine the minimum responsibilities, authority
boundaries, interaction paths, and authoritative ownership needed to
realize every Specification requirement without authority, enforcement,
attribution, state-ownership, atomicity, or reconstruction gaps.

Architecture may determine where a normative responsibility is realized.
It must not reinterpret whether that responsibility exists.

The Architecture derivation begins with:

> Given the complete frozen normative behavior of Standby, what minimum
> architectural responsibilities and authority boundaries are necessary
> to realize every Specification requirement without introducing
> authority, enforcement, attribution, state-ownership, atomicity, or
> reconstruction gaps?
