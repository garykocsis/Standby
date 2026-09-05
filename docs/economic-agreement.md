# Standby Economic Agreement

**Canonical Document 2 of 8**\
**Status:** **FINAL PASS / FROZEN**\
**Upstream authority:** `context.md`\
**Downstream handoff:** `mechanism.md`

## 1. Purpose and Scope

This document defines the minimum normative economic relationships that
must hold for a beneficiary to rely on bounded future execution
availability from shared mutable AMM liquidity.

It answers **what rights, obligations, conditions, and fulfillment
relationships must economically hold**. It does not prescribe the
protocol mechanism, state representation, architecture, authority
structure, or implementation that makes those relationships reliably
true.

The canonical transformation is:

**Actor interests + coordination failure → rights + obligations +
conditions**

The minimum economic relationship is between a **Beneficiary**, which
receives future execution assurance, and a **Liquidity-Supplying Side**,
whose shared liquidity bears the economic burden required to support
that assurance.

## 2. Upstream Economic Basis

This Economic Agreement derives from the frozen Context conclusions that:

1. Executable Capacity is the economically relevant AMM resource property.
2. Executable Capacity is directional and mutable.
3. Present availability of Executable Capacity does not provide future assurance.
4. The validated need is bounded, contingent, and future.
5. Continued shared utilization of the underlying AMM liquidity is an intentional economic property.
6. Future execution assurance can create value for the Beneficiary while imposing economic cost on the Liquidity-Supplying Side.
7. Existing alternatives obtain certainty through different economic arrangements, including resource segregation or reliance on an external guarantor.
8. The opportunity for protocol-enforced future execution assurance is economically credible but commercially qualified rather than established as broad market adoption.

These conclusions establish the economic premises from which the rights and obligations below are derived. They do not themselves prescribe the enforcement mechanism.

## 3. Normative Economic Model

These terms describe economic rights, obligations, predicates, and
quantities. They do not require identically named protocol state
variables or lifecycle states.

### 3.1 Executable Capacity

**Executable Capacity** is the amount of asset conversion that the
relevant AMM resource can economically support in a specified conversion
direction under applicable execution conditions. It is directional and
mutable, and is not equivalent to TVL, nominal liquidity, an asset
balance, or ownership of a liquidity position. This document does not
determine its normative protocol derivation.

### 3.2 Future Execution Entitlement

A **Future Execution Entitlement** is a bounded economic right under a
valid agreement that permits the Beneficiary to rely upon future
executable conversion capacity in the agreed direction, subject to the
agreement's exercise conditions. It does not confer ownership of
liquidity or destination assets, exclusive control of particular
liquidity, or a guaranteed exchange price.

### 3.3 Original Entitlement

The **Original Entitlement** is the maximum bounded extent of Future
Execution Entitlement established when the agreement becomes valid. It
does not increase merely because the Beneficiary later desires
additional execution.

### 3.4 Remaining Entitlement

The **Remaining Entitlement** is the portion of an established Future
Execution Entitlement that remains both economically valid and
unfulfilled. Fulfillment reduces it by the amount actually fulfilled. If
validity ceases, it no longer constitutes Remaining Entitlement even
when no fulfillment occurred. The term does not require a persisted
field or lifecycle classification.

### 3.5 Validity

**Validity** is the economic condition in which an established Future
Execution Entitlement currently retains force under the agreement and
therefore continues to create corresponding economic reliance and
obligation. Validity does not imply current Exercisability.

### 3.6 Exercisability

**Exercisability** is the economic condition in which a valid Future
Execution Entitlement currently satisfies the agreement's conditions for
the Beneficiary to demand fulfillment. Exercisability implies Validity;
Validity need not imply Exercisability.

### 3.7 Exercise

**Exercise** is invocation of a currently exercisable Future Execution
Entitlement for some permitted amount of fulfillment. Exercise is not
itself Fulfillment and may fail without reducing Remaining Entitlement.

### 3.8 Fulfillment

**Fulfillment** is actual delivery, for the Beneficiary's benefit, of
the economic conversion outcome attributable to exercise of the specific
entitlement being satisfied. An exercise request, attempted execution,
execution without the required Beneficiary outcome, or unrelated receipt
does not constitute Fulfillment.

### 3.9 Fulfilled Amount

The **Fulfilled Amount** is the amount of a specific Future Execution
Entitlement actually satisfied through attributable Fulfillment.

### 3.10 Supporting Capacity

**Supporting Capacity** is the direction-specific Executable Capacity of
the relevant shared AMM resource that is economically applicable to
satisfying Remaining Entitlements under the agreement. This document
does not determine what protocol facts or calculations make Executable
Capacity qualifying Supporting Capacity.

### 3.11 Aggregate Remaining Entitlement

**Aggregate Remaining Entitlement** is the combined Remaining
Entitlement of all valid and unfulfilled beneficiary entitlements that
rely upon the same economically relevant Supporting Capacity. This
economic aggregation does not prescribe whether a protocol persists,
caches, iterates, derives, or otherwise represents the aggregate.

### 3.12 Capacity Obligation

A **Capacity Obligation** is the economic obligation corresponding to
valid beneficiary entitlements under which sufficient Supporting
Capacity must remain available to support their Aggregate Remaining
Entitlement.

**Supporting Capacity ≥ Aggregate Remaining Entitlement**

This is an economic sufficiency relationship, not yet the formal
protocol invariant.

### 3.13 Establishment

**Establishment** is the all-or-nothing economic formation of a Future
Execution Entitlement and its corresponding Capacity Obligation under
determinately established terms and supportability conditions.
Successful Establishment creates both; failed Establishment creates
neither. This does not itself prescribe transactional atomicity.

### 3.14 Release

**Release** is reduction or cessation of a Capacity Obligation because
the corresponding Remaining Entitlement has either been fulfilled or
ceased to remain valid. Release caused by cessation of validity is not
Fulfillment.

### 3.15 Economic Compatibility

**Economic Compatibility** is the property of a shared-resource change
whereby the resulting authoritative economic condition continues to
provide sufficient Supporting Capacity for Aggregate Remaining
Entitlement. It defines an economic boundary without prescribing how
incompatible activity is prevented.

## 4. Agreement Participants and Economic Roles

### 4.1 Beneficiary Party

The Beneficiary is a party because the agreement creates the Future
Execution Entitlement for its benefit. Its economic role is to receive
bounded future execution assurance. The Beneficiary is not necessarily
the transaction submitter, exercise caller, administrator, or
application contract.

### 4.2 Liquidity-Supplying Side

The agreement requires an obligation-bearing economic side whose
supplied shared liquidity bears the cost of maintaining the future
execution condition on which the Beneficiary relies. The canonical
abstraction is the **Liquidity-Supplying Side**, not necessarily each
individual LP.

The agreement does not inherently require one identified LP
counterparty, unanimous LP consent per entitlement, pro-rata individual
LP obligations, a dedicated LP subset, an LP registry, or bilateral
contracts with individual LPs.

### 4.3 Ordinary Users

Ordinary pool users are economically relevant non-party resource users.
Legitimate ordinary pool use does not itself make them parties to the
Economic Agreement.

### 4.4 No Required External Guarantor

The minimum agreement does not require a separate external balance-sheet
guarantor.

### 4.5 Resource-Relative Obligation-Bearing Role

The obligation-bearing role attaches economically to the side supplying
the shared liquidity resource rather than inherently to one fixed LP
identity. The agreement can remain coherent despite changing LP
composition provided the Capacity Obligation remains satisfied.

### 4.6 Economic Parties Are Distinct From Protocol Authorities

Pools, hooks, routers, administrators, governors, and other enforcement
or realization components are not agreement parties merely because they
later implement or control protocol behavior.

The core relationship is:

**Beneficiary ↔ Liquidity-Supplying Side**

with shared mutable AMM Executable Capacity as its subject.

## 5. Economic Subject of the Agreement

The agreement concerns a bounded amount of direction-specific future
executable conversion capacity associated with shared mutable AMM
liquidity.

### 5.1 Direction-Specific Subject

The subject is tied to an agreed asset-conversion direction.

### 5.2 Bounded Subject

The agreement concerns finite future capacity, not ownership or control
of the entire pool or all future liquidity.

### 5.3 Availability Rather Than Mandatory Utilization

The subject is future execution availability up to the bounded extent.
The Beneficiary need not consume the full entitlement.

### 5.4 Capacity Assurance Is Distinct From Price Assurance

The agreement concerns sufficient execution capacity, not a
predetermined exchange rate, guaranteed economic value, or
price-protection right.

### 5.5 Environment-Relative Subject

The assured subject is capacity relative to the relevant AMM execution
environment and legitimately established conditions, not an absolute
guarantee regardless of external impossibility.

## 6. Beneficiary Future Execution Entitlement

Once a valid agreement exists, the Beneficiary is entitled to rely upon
future availability of a bounded amount of Executable Capacity in the
agreed direction, subject to validity and exercise conditions.

### 6.1 Bounded and Direction-Specific

The entitlement extends only to its finite established extent and agreed
conversion direction.

### 6.2 Availability Right, Not Utilization Obligation

The Beneficiary may rely upon availability while the entitlement remains
valid but need not utilize it.

### 6.3 Conditional Exercisability

The entitlement becomes exercisable only when its exercise conditions
are satisfied.

### 6.4 Reliance May Precede Exercisability

The economic reliance created by a valid Future Execution Entitlement
may begin before that entitlement becomes exercisable.

**Validity ≠ Exercisability**

A future-starting entitlement may therefore create a present Capacity
Obligation.

### 6.5 Remaining Entitlement

The economically relevant right is only the portion that remains valid
and unfulfilled.

For fulfillment-driven reduction:

**Remaining Entitlement after = Remaining Entitlement before − Fulfilled
Amount**

This is an economic conservation relationship, not a protocol accounting
prescription.

### 6.6 No Implied Modification Rights

The entitlement does not itself create rights to transfer, amend,
enlarge, cancel, or otherwise modify the agreement.

### 6.7 No Price Entitlement

The entitlement concerns bounded future execution availability rather
than predetermined price or valuation.

## 7. Corresponding Capacity Obligation

While Future Execution Entitlements remain valid and unfulfilled, the
Liquidity-Supplying Side bears a corresponding obligation to support
sufficient direction-specific Executable Capacity.

### 7.1 Capacity, Not Asset Dedication

The obligation concerns sufficient Supporting Capacity, not dedication
or ownership of particular assets, LP positions, or destination-asset
reserves.

### 7.2 Obligation Tracks Remaining Entitlement

The obligation persists only to the extent necessary to support
Remaining Entitlement.

### 7.3 Aggregate Obligation

Multiple simultaneously valid entitlements relying upon the same
Supporting Capacity must be supported in aggregate.

### 7.4 Sufficiency Obligation

**Supporting Capacity ≥ Aggregate Remaining Entitlement**

### 7.5 No Implied Excess-Capacity Requirement

Exact sufficiency satisfies the agreement. No reserve margin, haircut,
overcollateralization, or other excess buffer is inherently required.

### 7.6 Obligation Begins With Validity

The Capacity Obligation begins when the entitlement becomes valid, even
if it becomes exercisable only later.

### 7.7 Obligation Persists With the Right

The obligation persists while the corresponding entitlement remains
valid and unfulfilled and is released as that entitlement is fulfilled
or ceases to remain valid. Validity cessation is not Fulfillment.

### 7.8 Compatible Shared Use

The obligation does not prohibit compatible shared use. Capacity may
change provided the sufficiency relationship remains satisfied.

### 7.9 Resource-Relative Satisfaction

Satisfaction depends on the relevant capacity of the shared resource,
not continued participation of a particular LP or preservation of a
particular LP position.

### 7.10 Economic Burden and Compensation

Assuming the Capacity Obligation can impose encumbrance, opportunity, or risk costs on the Liquidity-Supplying Side. Voluntary adoption therefore requires that the Liquidity-Supplying Side have sufficient economic reason to bear that cost. Where compensation provides that reason, the minimum Economic Agreement does not prescribe its price, payment asset, collection mechanism, accrual mechanism, or distribution mechanism.

## 8. Establishment, Validity, and Extent

### 8.1 Supportability at Establishment

A proposed entitlement becomes valid only if Supporting Capacity can
support it together with all existing Remaining Entitlements relying
upon the same capacity.

### 8.2 Cumulative Establishment Constraint

**Supporting Capacity ≥ Existing Aggregate Remaining Entitlement +
Proposed Entitlement**

This is an economic establishment condition, not yet a protocol
admission algorithm.

### 8.3 Boundary Sufficiency

Exact equality is sufficient.

### 8.4 Determinate Terms

The agreement must establish finite maximum extent, conversion
direction, validity conditions, and exercise conditions.

### 8.5 Validity Does Not Require Exercisability

A valid entitlement may exist before its exercise conditions are
satisfied; its Capacity Obligation already applies.

### 8.6 Established-Term Stability

Terms determining extent, direction, validity, and exercise conditions
cannot be unilaterally reinterpreted after Establishment in a way that
changes the economic burden already assumed. This does not imply a
general governance freeze or amendment mechanism.

### 8.7 Validity Cessation

When validity conditions cease to hold, the Beneficiary no longer
possesses the corresponding Future Execution Entitlement and the
associated Capacity Obligation no longer persists. Such cessation does
not imply Fulfillment.

### 8.8 Determinate Establishment

Whether an entitlement became valid must be objectively determinable
from the terms and conditions governing Establishment.

### 8.9 Failed Establishment Creates No Entitlement

If Establishment conditions are not satisfied, neither the proposed
entitlement nor its Capacity Obligation comes into existence. This is
economic all-or-nothing formation, not a prescription of transactional
atomicity.

## 9. Fulfillment and Release

### 9.1 Invocation Is Not Fulfillment

A request or attempt to exercise does not itself satisfy any portion of
the entitlement.

### 9.2 Execution Alone Is Not Fulfillment

Conversion does not fulfill the entitlement unless the required outcome
is actually delivered for the Beneficiary's benefit.

### 9.3 Beneficiary Receipt and Causal Attribution

Fulfillment occurs only to the extent the Beneficiary actually receives
the required conversion outcome and that outcome is attributable to
fulfillment of the specific entitlement.

### 9.4 Entitlement-Specific Attribution

Performance attributable to one entitlement cannot discharge another
merely because the Beneficiary, asset, or economic value is similar.

### 9.5 Exact Fulfillment Conservation

The Remaining Entitlement and corresponding Capacity Obligation may
decrease through Fulfillment only by the amount actually and causally
fulfilled.

**Decrease in Remaining Entitlement = Fulfilled Amount**

### 9.6 Partial Fulfillment

Where less than the Remaining Entitlement may be fulfilled, only the
actually Fulfilled Amount ceases to remain outstanding; the remainder
retains its right and obligation. This does not itself require arbitrary
partial exercise support.

### 9.7 Fulfillment Bound

No entitlement can be fulfilled or reduced beyond its Remaining
Entitlement.

### 9.8 Subject-Matching Fulfillment

Fulfillment must satisfy the conversion subject and direction
established by the agreement. Unrelated value does not discharge the
entitlement merely because an external valuation considers it
equivalent.

### 9.9 Failed Fulfillment Preservation

If required Fulfillment does not complete, Remaining Entitlement and
corresponding Capacity Obligation remain unchanged.

### 9.10 No Premature Release

The entitlement and obligation cannot be treated as fulfilled before
required attributable Beneficiary Fulfillment has occurred. No
authoritative economic result may contain Fulfillment-driven Release
without the required Beneficiary Fulfillment. This is an economic
finality requirement, not a transaction-level atomicity prescription.

### 9.11 Fulfillment and Non-Fulfilling Cessation Are Distinct

Release because an entitlement ceases to remain valid is economically distinct from Fulfillment. Cessation of validity due to an agreed temporal boundary or other validity condition must not be represented as performance that did not occur.

## 10. Economic Compatibility of Shared Use

The shared AMM resource remains economically shared while beneficiary
entitlements exist. The agreement protects the required capacity
property rather than particular assets or LP positions.

### 10.1 Continued Shared Use

An entitlement does not inherently prohibit continued economically
legitimate use of the shared AMM resource.

### 10.2 Agreement Compatibility Is an Additional Constraint

Otherwise legitimate shared use is compatible only if the resulting
condition continues to satisfy Capacity Obligations.

### 10.3 Resulting-Condition Compatibility

Shared-resource activity is compatible only when the resulting
authoritative economic condition retains sufficient Supporting Capacity
for Aggregate Remaining Entitlement.

### 10.4 Exact Sufficiency Is Compatible

A resulting condition with exact sufficiency remains compatible.

### 10.5 Actor-Neutral Compatibility

Compatibility depends on economic effect rather than solely on actor
identity or action type.

### 10.6 Complete Economic Compatibility Boundary

Every form of shared-resource activity capable of changing economically
relevant Supporting Capacity must remain compatible with valid
beneficiary entitlements. This does not identify protocol authorities,
callbacks, paths, or enforcement components.

### 10.7 Compatible Capacity Change Is Permitted

Capacity may increase, decrease, or otherwise change provided the
resulting condition remains sufficient.

### 10.8 Residual Capacity Optionality

Capacity beyond that required for Remaining Entitlements remains
economically available for compatible shared use.

### 10.9 Continuous Compatibility

Sufficiency must remain satisfied throughout the period in which
entitlements remain valid. Later restoration does not retroactively cure
an authoritative period of insufficiency.

### 10.10 Authoritative-State Compatibility

No economically authoritative resource condition may represent valid
beneficiary entitlements while lacking sufficient Supporting Capacity.
This concerns economically effective conditions, not
implementation-local transient facts.

## 11. Consolidated Economic Agreement

1.  **Right and obligation:** A valid Future Execution Entitlement
    creates a corresponding Capacity Obligation.
2.  **Establishment:** A proposed entitlement becomes valid only when
    Supporting Capacity can support existing Remaining Entitlements plus
    the proposed entitlement; equality is sufficient.
3.  **Persistence:** The Capacity Obligation persists throughout
    Validity, including before Exercisability. Compatible shared use may
    continue, but valid Remaining Entitlements must remain supported.
4.  **Fulfillment:** Fulfillment requires actual Beneficiary delivery
    attributable to the specific entitlement. Fulfillment-driven
    reduction equals the actual attributable Fulfilled Amount.
5.  **Release:** Capacity Obligation is reduced or released only as
    Remaining Entitlement is fulfilled or ceases to remain valid.
    Validity cessation without performance is not Fulfillment.
6.  **Shared-liquidity character:** The agreement protects sufficient
    executable-capacity support rather than particular assets, balances,
    LP positions, or LP identities.

## 12. What the Economic Agreement Does Not Require

The minimum Economic Agreement does not inherently require:

-   Beneficiary ownership or pre-positioning of destination assets;
-   dedicated reserves or segregated liquidity;
-   reservation of particular assets or LP positions;
-   a particular LP to remain in the pool;
-   individual bilateral obligations with every LP;
-   a separate external guarantor;
-   price assurance or a predetermined exchange rate;
-   mandatory utilization;
-   live NAV;
-   epochs;
-   overbooking;
-   custom protocol accounting;
-   reserve margins or overcollateralization;
-   dynamic fees;
-   cancellation;
-   amendment;
-   transferability;
-   protocol-native premium settlement;
-   a particular compensation pricing or distribution mechanism;
-   persistent intermediate exercise state;
-   redundant lifecycle enums;
-   cached Aggregate Remaining Entitlement;
-   explicit expiry transitions;
-   identical or full-range LP positions;
-   a particular enforcement mechanism;
-   a particular authority structure; or
-   a particular implementation architecture.

These exclusions do not prohibit a downstream design from independently
deriving an additional feature where justified. They establish only that
such features are not inherent requirements of the minimum Economic
Agreement.

## 13. Mechanism Handoff

The Economic Agreement establishes the rights, obligations, conditions,
conservation relationships, and compatibility boundary required for
bounded future execution assurance from shared mutable AMM liquidity. It
deliberately leaves unresolved how those relationships become
enforceable protocol behavior.

The Economic Agreement does not determine:

1.  how direction-specific Executable Capacity is normatively derived
    from authoritative AMM facts;
2.  what makes Executable Capacity qualify as Supporting Capacity;
3.  how Aggregate Remaining Entitlement is authoritatively determined;
4.  how supportability is evaluated when a new entitlement is proposed;
5.  how incompatible shared-resource transitions are prevented from
    becoming authoritative;
6.  how exercise is causally associated with the specific entitlement
    being exercised;
7.  how actual Beneficiary Fulfillment is measured and attributed;
8.  how exact fulfillment-driven entitlement reduction becomes
    authoritative;
9.  how Validity, Exercisability, and non-enforceability are
    operationally determined;
10. what economic facts must be persisted and what may be derived;
11. which protocol components possess authority necessary to enforce the
    agreement;
12. how economically authoritative outcomes are made final;
13. how protocol behavior can be reconstructed from authoritative facts;
    or
14. how compliance with the agreement is verified.

Those questions belong to `mechanism.md` and the downstream
Specification, Architecture, State, Invariants, and Verification
documents.

The terminal handoff question is:

> **What minimum enforceable protocol behavior is required to make the
> Economic Agreement's establishment, capacity-sufficiency,
> compatibility, fulfillment, and release relationships reliably true
> over shared mutable AMM liquidity?**
