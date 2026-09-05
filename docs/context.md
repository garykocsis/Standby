# Standby — Context

**Canonical Document #1 of 8**  
**Status:** **FINAL PASS / FROZEN**


## 1. Purpose and Canonical Boundary

This document establishes the economic and execution context from which the Standby Economic Agreement is derived.

Its responsibility is to define the Standby-independent economic reality, relevant actors, shared resource, participant interests, coordination problem, validated problem scope, credible alternatives, and environmental preconditions required to derive the Economic Agreement without hidden premises.

This document is descriptive and upstream. It does **not** define Standby-specific rights, obligations, commitments, backing rules, lifecycle semantics, enforcement behavior, state, architecture, realization choices, or verification requirements.

A contextual statement belongs here only when it remains meaningful independently of Standby’s existence. Where a fact would become true only because Standby creates, preserves, enforces, records, or verifies it, that fact belongs downstream.

The completeness rule for this document is:

> **Context Completeness = Upstream Derivational Sufficiency + Downstream Non-Contamination**

Context is complete when every externally grounded premise needed to derive the Economic Agreement is explicit or scoped out, while no downstream protocol requirement is smuggled upstream as a premise of the problem.

---

## 2. Economic and Execution Environment

### 2.1 Shared AMM Execution Environment

An automated market maker (AMM) provides an on-chain execution environment in which liquidity supplied to a shared pool supports asset conversion by economically independent participants.

The relevant resource is shared: liquidity may support multiple economically valid uses rather than being dedicated by default to one future requirement.

### 2.2 Executable Capacity

Nominal pool liquidity is not equivalent to economically executable conversion capacity.

For a given conversion, the economically relevant question is not merely how much liquidity is present, but how much asset conversion the prevailing AMM state and execution conditions can actually support.

Accordingly, **executable capacity** is the amount of conversion that can be executed under the prevailing state and execution conditions of the AMM.

This contextual concept does not define Standby’s later normative notion of qualifying capacity or any protocol-specific capacity function.

### 2.3 Directionality

Executable capacity is direction-specific.

The capacity to convert one asset into another is not economically identical to the capacity to perform the reverse conversion. Pool state, liquidity distribution, asset composition, price impact, and other execution conditions can make the two capacities materially different.

A future conversion requirement therefore concerns a particular asset-conversion direction rather than generic pool liquidity.

### 2.4 Mutability Through Legitimate Pool Activity

Executable capacity is mutable.

Economically legitimate pool activity—including ordinary swaps and liquidity changes—can alter the state of the AMM and therefore change the amount of directional executable capacity available later.

These actions are not inherently adversarial. They are ordinary uses of the shared resource.

### 2.5 Present Availability Does Not Establish Future Availability

Sufficient executable capacity at one point in time does not imply that equivalent capacity will remain available at a later point in time.

Current AMM liquidity therefore establishes present execution availability, not future execution assurance.

---

## 3. Actors and Economic Interests

### 3.1 Beneficiary

The economically fundamental beneficiary role is occupied by an actor whose activity can create a bounded, contingent future asset-conversion requirement and who benefits from greater assurance that execution capacity will be available if that requirement materializes.

The strongest validated beneficiary class is an on-chain financial application with:

- a predictable risk window;
- a bounded but contingent future asset-conversion requirement;
- uncertainty in exact utilization and/or timing;
- value from execution readiness when the requirement materializes; and
- an operational reason not to depend solely on discretionary liquidity sourcing at that moment.

“On-chain financial application” is a validated beneficiary class, not a separate protocol role.

The beneficiary-side economic value of future execution assurance can be represented conceptually as:

\[
V = F + K + A
\]

where:

- \(F\) is avoided failure cost;
- \(K\) is avoided precautionary pre-positioning or idle-capital cost; and
- \(A\) is the value of deterministic autonomous execution availability.

The beneficiary therefore may rationally value future execution availability without fully owning or pre-positioning the destination asset in advance.

### 3.2 Liquidity Providers

Liquidity providers supply capital to the shared AMM environment and have an economic interest in productive capital utilization, the returns associated with liquidity provision, and preserving economically valuable capacity optionality.

Constraining the future economic usability of shared liquidity can impose costs on liquidity providers. Those costs can be represented conceptually as:

\[
C = C_{encumbrance} + C_{opportunity} + C_{risk}
\]

where the components represent the cost of constrained optionality, foregone alternative use, and incremental risk associated with supporting stronger future assurance.

At this contextual level, liquidity providers have no Standby-specific obligation to bear those costs.

### 3.3 Ordinary Pool Users

Ordinary pool users are economically independent actors who access shared AMM liquidity for present asset conversion.

Their legitimate activity can alter the same directional executable capacity that may later matter to a beneficiary.

Absent an additional economic arrangement, ordinary users have no pre-existing obligation to preserve capacity for another actor’s contingent future requirement.

### 3.4 Independent Rationality and Misalignment

The coordination problem does not require malicious or irrational behavior.

Each participant can act rationally according to its own economic interest:

- the beneficiary values future execution readiness;
- liquidity providers value productive shared use and retained optionality; and
- ordinary users value present access to shared liquidity.

Those objectives do not automatically preserve the future execution condition valued by the beneficiary.

### 3.5 Potential Coordination Surplus

Where the beneficiary’s value of future assurance exceeds the economic cost imposed on liquidity providers,

\[
V > C,
\]

a mutually beneficial coordination arrangement may be economically feasible.

If conceptual compensation \(P\) is introduced, a mutually acceptable interval can exist where:

\[
C < P < V.
\]

This establishes only the possibility of economic surplus. It does not specify pricing, payment, premium collection, payer identity, allocation, or liquidity-provider accrual mechanics.

---

## 4. Economic Coordination Problem

### 4.1 Temporal Reliability Gap

An actor may observe sufficient directional executable capacity before a future conversion requirement materializes.

Because the underlying resource is shared and mutable, nothing about that present condition establishes that sufficient capacity will still exist at the relevant future moment.

### 4.2 Legitimate-Behavior Origin

The reliability gap arises through economically valid activity.

Ordinary swaps, liquidity changes, and changing pool conditions can alter future executable capacity even when every participant behaves correctly and rationally.

The problem is therefore not one of misconduct. It is a coordination failure arising from independent use of a shared mutable resource.

### 4.3 Absence of Existing Assurance

Ordinary AMM participation creates no pre-existing economic relationship requiring sufficient directional executable capacity to remain available for another actor’s contingent future requirement.

Current availability is therefore distinct from future assurance.

### 4.4 Reliability Coordination Failure

A beneficiary cannot obtain reliable future execution availability merely by observing sufficient shared AMM capacity today.

Better forecasting of future liquidity can estimate future conditions, but prediction does not itself create an economic relationship on which the beneficiary can rely.

Likewise, additional uncommitted liquidity may reduce the probability of future insufficiency without transforming present capacity into assured future capacity.

### 4.5 Allocation Opportunity

Where the beneficiary values future assurance more highly than the economic cost another participant would bear to support it, potential gains from coordination exist.

Ordinary AMM interaction contains no economic arrangement that automatically converts that difference in value into reliable future execution availability.

The problem therefore contains both:

- a **reliability failure** — present availability does not create future assurance; and
- an **allocation failure** — a potentially valuable transfer of capacity optionality is not coordinated by ordinary AMM interaction.

### 4.6 Desired Economic Outcome

The unresolved economic opportunity is for a beneficiary to obtain reliable future execution availability for a bounded contingent conversion requirement while the relevant liquidity remains part of a shared AMM resource rather than requiring certainty solely through destination-asset ownership, segregated resources, fragmented liquidity, or an external guarantor.

This statement defines the economically valuable outcome. It does not define the rights, obligations, or mechanism by which that outcome would be made reliable.

---

## 5. Problem Scope and Qualification

The validated Standby problem class is intentionally narrow.

### 5.1 Future Requirement

The relevant need concerns asset conversion at a later contingent moment rather than merely immediate trading.

Standby is not primarily a solution to the question of whether a trade can execute now.

### 5.2 Bounded Requirement

The future conversion exposure must have a meaningful finite upper bound.

Unbounded or indeterminate future demand is outside the validated problem class.

### 5.3 Contingent Utilization

Some or all of the potential future conversion may never be required.

Exact utilization and/or timing may remain uncertain.

This contingency is economically important because the beneficiary may value availability even when the capacity is ultimately unused, while resource providers bear costs from surrendering some degree of capacity optionality.

### 5.4 Execution Readiness

The beneficiary values execution availability when the qualifying future need materializes rather than having to begin discretionary liquidity sourcing only after that point.

This does not imply execution independent of all AMM, market, or system conditions.

### 5.5 On-Chain Asset Conversion

The validated problem concerns future on-chain asset conversion.

No claim is made here that the same context automatically applies to generic future claims on compute, storage, credit, blockspace, insurance capacity, off-chain settlement resources, or other unrelated mutable resources.

### 5.6 Shared Mutable AMM Resource

The desired assurance concerns executable capacity associated with shared mutable AMM liquidity.

The target economic problem is therefore distinct from certainty obtained solely through:

- destination-asset ownership;
- dedicated reserves or escrow;
- a dedicated liquidity venue; or
- an external balance-sheet guarantor.

### 5.7 Guarantee Boundary

This context does not establish:

- unlimited future execution rights;
- execution independent of relevant AMM or market conditions; or
- assurance over arbitrary unbounded future demand.

### 5.8 Product Boundary

The validated problem is not primarily:

- best execution;
- price optimization;
- swap routing;
- block trading;
- general liquidity sourcing;
- destination-asset custody;
- execution-venue replacement; or
- a generic external credit guarantee.

### 5.9 Alternative-Arrangement Boundary

Pre-positioning, dedicated reserves, dedicated pools, and external liquidity guarantors remain valid alternative economic arrangements.

Standby’s economic opportunity is conditional on the shared-liquidity arrangement providing a preferable combination of assurance, utilization, cost, and dependency for the relevant participants.

### 5.10 Market Qualification

The underlying settlement, collateral, treasury-liquidity, and operational-liquidity problem is recurring and economically meaningful.

However, the market for protocol-enforced future execution capacity backed by shared secondary-AMM liquidity is emerging rather than commercially proven.

This context therefore establishes economic plausibility, not demonstrated broad institutional product-market fit or proven willingness to pay at scale.

---

## 6. Alternatives and Economic Tradeoffs

### 6.1 Ordinary Shared-Liquidity Reliance

A beneficiary may rely on ordinary AMM liquidity being available when needed.

This preserves unrestricted shared use and requires no special assurance arrangement, but it does not create reliable future execution availability.

### 6.2 Destination-Asset Pre-Positioning

A beneficiary can acquire and hold the destination asset before the future requirement materializes.

This obtains certainty through ownership rather than future execution capacity.

The tradeoff can include precautionary capital commitment, idle-capital cost, balance-sheet effects, and reduced flexibility where the asset may never be needed.

Where those costs are small, pre-positioning may be preferable.

### 6.3 Dedicated Reserve or Escrow

A dedicated reserve or escrow can set aside the relevant resource specifically for the future requirement.

This can provide strong assurance through segregation, but the dedicated resource no longer retains the same shared-utilization property.

### 6.4 Dedicated Liquidity Pool

A separate liquidity pool can provide a more controlled execution resource while allowing assets to remain usable for conversion.

The tradeoff is liquidity fragmentation and reduced sharing of capital across broader pool activity.

### 6.5 External Market Maker, RFQ Provider, or Liquidity Guarantor

Another party can undertake to provide the required execution or asset when needed.

This can provide future assurance, but the source of that assurance shifts to an external balance sheet, counterparty, or operational undertaking rather than relying exclusively on the future state of shared AMM liquidity.

### 6.6 Residual Economic Opportunity

At a first-principles level, future assurance concerning a mutable resource can be obtained through one of three broad economic arrangements:

1. **Segregate the resource** so competing use cannot destroy the required future condition.
2. **Preserve the required property of the shared resource** while allowing compatible use.
3. **Externalize the guarantee** to another balance sheet or guarantor.

This context does not select among those branches.

The residual economic question is whether bounded future execution assurance can be supported by shared mutable AMM liquidity without requiring certainty solely through ownership, segregation, liquidity fragmentation, or an external guarantor.

Technical mechanism alternatives—such as reservation ledgers, position locking, transition controls, or specific enforcement architectures—are outside the responsibility of this document.

---

## 7. Environmental Assumptions and Preconditions

Context distinguishes environmental facts the later derivation may rely upon from conditions Standby would itself have to establish or preserve.

### 7.1 AMM Execution Environment

An on-chain AMM environment exists for the relevant asset-conversion direction.

### 7.2 Capacity Dependence

The amount of executable conversion available in a direction depends upon the prevailing economic state and execution conditions of the AMM.

### 7.3 Authoritative On-Chain Facts

The economically relevant AMM state is represented by authoritative on-chain facts from which current execution conditions can, in principle, be determined.

This assumption does not define Standby’s normative capacity derivation, determine which facts later qualify for a particular calculation, or assume that an implementation derives an economically meaningful quantity correctly.

### 7.4 Asset Executability

The relevant assets are capable of participating in the target on-chain AMM conversion and resulting transfer within the target execution environment.

No assumption is made here about legal title, off-chain redemption, live NAV, regulatory eligibility, issuer solvency, or other external asset properties unless separately required by a later scoped realization.

### 7.5 Requirement Boundedness

An in-scope beneficiary can express a meaningful finite upper bound on the relevant contingent future conversion requirement.

### 7.6 Explicitly Rejected Environmental Assumptions

Context does **not** assume that:

- sufficient future liquidity will exist without an additional arrangement;
- liquidity providers will voluntarily preserve future capacity;
- ordinary users will avoid capacity-reducing activity;
- current capacity implies future capacity;
- beneficiary utilization will match a forecast;
- capacity is equivalent to TVL, raw balances, or LP-position ownership;
- an external oracle or live NAV feed exists;
- liquidity is dedicated to Standby;
- LP positions are identical or full range;
- premium settlement occurs on-chain; or
- the beneficiary’s underlying business contingency must be externally verified.

Any downstream design that requires one of these conditions must derive and justify it rather than treating it as an unstated contextual premise.

---

## 8. Contextual Conclusions and Downstream Handoff

The preceding sections establish the following authoritative contextual conclusions.

### 8.1 Authoritative Contextual Conclusions

**HC-1 — Executable Capacity Is the Relevant Resource Property**

The beneficiary’s economic concern is executable asset-conversion capacity under relevant AMM conditions, not nominal liquidity alone.

**HC-2 — Executable Capacity Is Directional and Mutable**

Capacity for one conversion direction is economically distinct from the reverse direction and can change through legitimate AMM activity.

**HC-3 — Present Availability Provides No Future Assurance**

Sufficient capacity now does not establish sufficient capacity later.

**HC-4 — The Validated Need Is Bounded, Contingent, and Future**

The relevant beneficiary problem concerns a finite future conversion exposure whose actual utilization and/or timing may remain uncertain.

**HC-5 — Shared Utilization Is an Intentional Economic Property**

The unresolved problem concerns future assurance while the relevant liquidity remains part of a shared mutable AMM resource rather than being made reliable solely through ownership, segregation, fragmentation, or external guarantee.

**HC-6 — Assurance Can Create Both Value and Cost**

The beneficiary may value future assurance through avoided failure, avoided precautionary pre-positioning, and deterministic execution availability, while liquidity providers can bear encumbrance, opportunity, and risk costs.

A coordination surplus may exist where \(V > C\), and where compensation \(P\) is conceptually introduced, a feasible interval may exist where \(C < P < V\).

**HC-7 — Existing Alternatives Achieve Certainty Through Different Economic Arrangements**

Future certainty can already be obtained through ownership, segregation, separated liquidity, or external guarantee. Ordinary shared AMM liquidity instead provides present availability without future assurance.

**HC-8 — The Opportunity Is Economically Credible but Commercially Qualified**

The underlying problem is economically meaningful, while broad commercial demand for protocol-enforced future execution capacity backed by shared AMM liquidity remains unproven.

### 8.2 Questions Context Deliberately Leaves Unresolved

This document does not determine:

1. what economic right, if any, the beneficiary receives;
2. what economic obligation another participant assumes;
3. how such an arrangement becomes valid;
4. when or under what conditions a future right may be exercised;
5. what relationship must hold between future rights and shared executable capacity;
6. what should happen when ordinary pool activity conflicts with a future arrangement;
7. what constitutes economically valid fulfillment;
8. how an arrangement terminates or ceases to be enforceable;
9. what protocol state, accounting, lifecycle representation, or authority is required; or
10. how any resulting requirement is implemented, enforced, reconstructed, or verified.

Those questions belong to the downstream canonical derivation.

### 8.3 Economic Agreement Derivation Question

The next canonical document must answer:

> **What must economically be true among the relevant participants for a beneficiary to be entitled to rely on bounded future execution availability from shared mutable AMM liquidity despite independent activity that can change that capacity?**

That question defines the handoff from Context to the Economic Agreement.

---

## 9. Context Terminology

**Beneficiary**  
The economic actor whose activity gives rise to the bounded, contingent future asset-conversion requirement and who values greater future execution assurance.

**Liquidity Provider (LP)**  
An actor that supplies liquidity to the shared AMM environment and bears economic consequences associated with how that liquidity remains usable.

**Ordinary Pool User**  
An economically independent participant that accesses shared AMM liquidity for current asset conversion without a pre-existing obligation to preserve capacity for another actor’s contingent future need.

**Shared AMM Liquidity**  
Liquidity available within an AMM environment for economically valid use by multiple participants rather than dedicated by default to one future requirement.

**Executable Capacity**  
The amount of asset conversion that can be executed under the prevailing state and execution conditions of the AMM.

**Directional Executable Capacity**  
Executable capacity associated with a particular asset-conversion direction.

**Future Conversion Requirement**  
A potential asset-conversion need that may materialize at a later point in time.

**Bounded Requirement**  
A future conversion requirement with a meaningful finite upper bound.

**Contingent Requirement**  
A future conversion requirement whose actual utilization and/or precise timing is uncertain.

**Execution Availability**  
The existence of executable capacity at a particular point in time.

**Execution Assurance**  
The economically meaningful ability of an actor to rely upon sufficient execution availability at a relevant future time, subject to whatever conditions a later economic agreement establishes.

**Pre-Positioning**  
Acquiring and holding the destination asset before a contingent future need materializes in order to obtain certainty through ownership rather than future conversion capacity.

**Resource Segregation**  
Obtaining future assurance by dedicating or isolating the relevant resource from competing shared use.

**External Guarantee**  
Obtaining future assurance through another party’s balance sheet, undertaking, or performance obligation rather than exclusively through the future state of the shared AMM resource.