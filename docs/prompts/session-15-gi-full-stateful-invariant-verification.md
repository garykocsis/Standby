# Standby — Session 15

## GI — Full Stateful Invariant Verification

You are implementing the next authorized Standby verification slice:

> **GI — Full Stateful Invariant Verification**

The preceding implementation slices are complete and independently gate-closed:

```text
F0   — Foundation                                      COMPLETE
F1   — Deterministic Economic Fixture                  COMPLETE
F2   — Eligibility Registry                            COMPLETE
F3   — StandbyHook Trust + PES Configuration           COMPLETE
F4   — Commitment Storage / Bounded References         COMPLETE
F5   — Authoritative Derivation Kernel                 COMPLETE
F6A  — Preliminary O3 Enforcement                      COMPLETE
F7   — O1 Commitment Admission                         COMPLETE
F6B  — O3 Bounded Enforcement                          COMPLETE
F8A  — Exercise Authorization                          COMPLETE
F8B  — Protected PoolManager Execution                 COMPLETE
F8C  — Authoritative Settlement / Direct Delivery      COMPLETE
F8D  — O2 Causal Finalization / Remaining Reduction    COMPLETE
GI   — Full Stateful Invariant Verification            CURRENT
F9   — Canonical Acceptance                            NOT AUTHORIZED
F10  — Demo Instrumentation                            NOT AUTHORIZED
```

The last closed gate is:

> **G8D — PASS / CLOSED**

GI is the only authorized current slice.

No production semantic slice is intentionally incomplete before GI.

---

# 1. Clean Rule / Authority Boundary

Apply the established ownership rule:

> **`CLAUDE.md` owns permanent operating behavior.**
>
> **`.claude/rules/*` owns permanent Solidity/testing conventions.**
>
> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Where permanent operating, Solidity, or testing behavior is already defined in those artifacts, follow it rather than restating or modifying it here.

This session prompt owns only the GI-specific requirements below.

---

# 2. Authoritative Sources

Before changing tests or production code, inspect the relevant frozen artifacts:

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
docs/implementation-plan.md
```

Inspect:

```text
docs/project-status.md
```

for current status only.

Also inspect the current production implementation and existing F0–F8D test suite.

At minimum inspect the current production surfaces for:

```text
StandbyHook
ExerciseRouter
EligibilityRegistry
PoolManager integration
commitment establishment
ordinary protected swaps
ordinary opposite-direction swaps
liquidity actions
O2 exercise
bounded commitment references
authoritative Supporting Capacity derivation
authoritative Capacity Obligation derivation
eligibility mutation
```

Inspect the existing deterministic fixture/deployer architecture before creating invariant fixture setup.

If a material discrepancy exists between the frozen artifacts and current implementation, surface it rather than silently redefining Standby semantics.

---

# 3. GI Objective

Implement the exact accepted GI responsibility:

> **GI verifies temporal and compositional safety of the completed Standby realization by adversarially composing authoritative O1, O2, O3, lifecycle, eligibility, and relevant environmental actions through production interfaces and independently checking that every reachable completed state preserves backing, commitment conservation, fulfillment attribution, bounded-reference integrity, causal isolation, authority/rejection atomicity, custody integrity, and required verification-domain completeness.**

GI is the first slice that introduces true **stateful invariant testing**.

Existing verification before GI principally includes:

```text
unit
integration
fuzz
periphery / adversarial
```

GI adds:

```text
persistent multi-operation histories
+
adversarial action sequencing
+
reachable-state exploration
+
independent reference/oracle checks
+
global invariant closure
```

GI does not define new protocol behavior.

---

# 4. GI Verification Boundary

GI must answer:

> **Can arbitrary sequences of successful and rejected Standby-relevant actions drive the completed production realization into an authoritative state that violates a frozen invariant or authoritative derivation?**

GI must therefore verify composition across:

```text
O1 commitment establishment
O2 authorization / execution / settlement / delivery / finalization
O3 backing-affecting transitions
ordinary protected swaps
ordinary opposite-direction swaps
liquidity changes
eligibility mutation
time / expiry evolution
bounded-reference churn
repeated / partial fulfillment
failed transitions
relevant unrelated external token transfers
```

GI must not introduce:

```text
new commitment semantics
new exercise semantics
new backing formulas
new eligibility rules
new lifecycle transitions
new obligation-release causes
new fulfillment semantics
new causal-state semantics
new custody semantics
```

Those responsibilities are already owned by the frozen artifacts and completed F0–F8D implementation.

---

# 5. Required Stateful Invariant Architecture

Implement a genuine Foundry handler-driven stateful invariant suite.

The required conceptual structure is:

```text
production fixture
        ↓
stateful adversarial handler
        ↓
production interfaces
        ↓
authoritative production state
        ↓
independent reference / history observations
        ↓
invariant assertions
```

A likely file shape is:

```text
test/invariant/StandbyInvariant.t.sol
test/invariant/StandbyInvariantHandler.sol
```

Additional narrowly scoped invariant helpers or independent oracle helpers are permitted where necessary.

Exact filenames are not normative.

The required property is a real stateful invariant campaign, not deterministic tests merely named `invariant`.

---

# 6. Production-Only Verification Environment

GI evidence must exercise the production realization.

Use the real production components required by the current architecture, including as applicable:

```text
PoolManager
StandbyHook
EligibilityRegistry
ExerciseRouter
ActorAwareTestRouter where required
production commitment path
production ordinary swap path
production liquidity path
canonical mock currencies
canonical deployment/configuration path
```

Do not use:

```text
StandbyHookHarness
```

as authoritative GI evidence.

Do not directly seed or mutate economically authoritative state such as:

```text
Remaining Entitlement
Original Entitlement
bounded commitment references
Supporting Capacity
Capacity Obligation
validity
exercisability
fulfillment
O2 causal lifecycle state
```

Fixture construction may initialize the production realization through its legitimate configuration/bootstrap paths.

---

# 7. Stateful Handler Responsibility

The handler is:

> **an adversarial transaction generator, not a semantic safety pre-filter.**

The handler must generate both actions that can succeed and actions that should reject.

Expected reverts are part of GI evidence.

Do not constrain inputs merely so that every operation succeeds.

Bound only inputs that are mechanically impossible, structurally meaningless, or likely to create generator noise rather than useful semantic exploration, such as:

```text
invalid TickMath domain
unbounded economically meaningless token amounts
unknown/unbounded actor identities
structurally impossible identifiers
```

Do not encode Standby's safety predicates into the handler merely to avoid reverts.

---

# 8. Minimum Stateful Action Universe

The handler must support, directly or through semantically equivalent production operations:

```text
establishCommitment(...)
ordinaryProtectedSwap(...)
ordinaryOppositeSwap(...)
addLiquidity(...)
removeLiquidity(...)
exercise(...)
advanceTime(...)
setBeneficiaryEligibility(...)
setTraderEligibility(...)
setLiquidityEligibility(...)
directTransferProtectedTokenToBeneficiary(...)
```

Additional handler actions require a traceable GI verification need.

Do not add actions solely to increase raw fuzz activity.

`directTransferProtectedTokenToBeneficiary(...)` is intentionally not Standby fulfillment.

It exists to verify that ordinary receipt of protected tokens by the Beneficiary cannot create fulfillment.

---

# 9. Persistent Actor Universe

Use a bounded persistent actor universe sufficient to test stable authority relationships across multi-operation histories.

At minimum support logical identities capable of representing:

```text
registry admin
commitment-establishment authority
Beneficiary A
Beneficiary B
authorized exerciser
unauthorized exerciser
eligible trader
ineligible trader
eligible LP
ineligible LP
outsider
```

One address may hold multiple roles in a particular campaign where legitimate.

However, the invariant environment must preserve enough separation to verify that:

```text
administrative authority
exercise authority
Beneficiary eligibility
trader eligibility
liquidity eligibility
ordinary invocation capability
```

cannot silently substitute for one another.

Avoid unconstrained fuzzed caller addresses where doing so destroys stable authority relationships across the generated sequence.

---

# 10. Authoritative Production State

Treat the production realization as authoritative.

Relevant production facts include, as applicable:

## PoolManager

```text
current pool state
price / tick
liquidity / executable topology
actual successful swap effects
```

## StandbyHook

```text
configured PES facts
commitment facts
Original Entitlement
Remaining Entitlement
bounded live references
historical commitment identity
next commitment identity
production Supporting Capacity derivation
production Capacity Obligation derivation
transaction-scoped O2 causal state where behaviorally observable
```

## EligibilityRegistry

```text
Beneficiary eligibility
trader eligibility
liquidity eligibility
```

## Token state

```text
Beneficiary balances
StandbyHook balances
ExerciseRouter balances
other balances required for delivery/custody evidence
```

## Environment

```text
block.timestamp
```

Do not create test-owned authoritative substitutes for production truth.

---

# 11. Ghost / Reference State Boundary

Ghost state is permitted only for independent verification and historical observation.

The governing rule is:

> **Ghost state may remember history that production does not persist for verification purposes, or independently calculate a normative oracle; it may not prescribe expected production state by duplicating the Standby state machine.**

Permitted ghost/reference state includes, as needed:

```text
successfully created commitment IDs
immutable original commitment snapshots
previously observed Remaining values
independently tracked successful fulfillment by commitment
successful action counters
failed / rejected action counters
observed Beneficiary delivery quantities
reference-slot / history observations
```

A permitted quantity is:

```text
ghostFulfilled[commitmentId]
```

It may increase only after an independently observed successfully completed authoritative O2.

GI may then assert:

```text
Original - Remaining == ghostFulfilled
```

Do not maintain a parallel lifecycle such as:

```text
ghostIsValid
ghostIsExercisable
ghostIsBinding
ghostIsExpired
ghostExpectedRemaining
ghostProtocolState
```

where those values merely duplicate Standby's own state machine.

---

# 12. Independent Derivation Requirement

Where GI compares a production-derived quantity against an expected result, the expected result must be independently expressed.

In particular:

```text
referenceS
referenceO
```

must not be calculated by calling the same production helper used to obtain:

```text
productionS
productionO
```

The independent oracle may use:

```text
authoritative PoolManager state
immutable commitment facts
current Remaining
current time
frozen qualification semantics
independent mathematical/reference calculations
```

but must remain sufficiently independent to detect a correlated production derivation defect.

Do not create false independence through a wrapper around the production implementation.

---

# 13. GI-A — Independent Economic Backing

Across every completed generated action, verify where applicable:

```text
referenceS == productionS
referenceO == productionO
referenceS >= referenceO
```

`referenceS` must be independently derived from authoritative production resource state.

`referenceO` must be independently derived from authoritative commitment state and frozen binding/release semantics.

These properties must remain true across histories involving:

```text
multiple commitments
ordinary protected swaps
opposite-direction swaps
partial fulfillment
full fulfillment
eligibility mutation
liquidity changes
expiry
reference reuse
failed operations
```

Do not assume S or O is stable between handler actions.

---

# 14. GI-B — Commitment Conservation

For every known commitment verify:

```text
Remaining <= Original
```

and:

```text
Remaining is monotonic non-increasing
```

Verify immutable admitted commitment facts remain unchanged.

Verify:

```text
Original - Remaining
    ==
independently tracked successful attributable fulfillment
```

where applicable.

The following must not manufacture fulfillment or reduce Remaining as though fulfillment occurred:

```text
ordinary protected swap
ordinary opposite swap
liquidity add
liquidity removal
expiry
Beneficiary eligibility mutation
trader eligibility mutation
liquidity eligibility mutation
direct token transfer
failed O1
failed O2
failed O3
```

Expiry may release backing obligation according to frozen non-fulfillment semantics without rewriting historical Remaining to zero.

Eligibility loss must not release an otherwise binding obligation.

---

# 15. GI-C — Fulfillment Attribution / Exactness

For every successfully completed O2 verify:

```text
exactly one commitment is affected
fulfillment amount == q
Remaining[target] decreases exactly q
ghostFulfilled[target] increases exactly q
unrelated commitments are not reduced
```

Under canonical mock-transfer semantics also verify:

```text
authoritative Beneficiary protected-output increase == q
```

The following alone must not create fulfillment:

```text
authorization
protected execution without completed O2
settlement alone
delivery alone
ordinary swap
liquidity action
direct token transfer
expiry
eligibility mutation
failed O2
```

One successful execution/delivery must not be attributed more than once.

One commitment's fulfillment evidence must not reduce another commitment.

Repeated partial exercise and final exhaustion must remain exact.

---

# 16. GI-D — O2 Causal Isolation

Verify across stateful histories that O2 causal evidence remains transaction-scoped and non-reusable.

After every completed top-level handler action, no reusable O2 authorization/execution/finalization evidence may remain capable of later reducing entitlement.

Campaigns must be capable of exposing contamination through histories equivalent to:

```text
O2(C1)
→ failed O2(C2)
→ O2(C1)
→ O2(C2)
```

and:

```text
failed O2(C1)
→ valid O2(C2)
```

and:

```text
successful O2(C1)
→ later O2(C2)
```

Verify:

```text
prior success cannot authorize later unrelated fulfillment
failed context cannot authorize later fulfillment
one commitment's context cannot substitute for another
replay cannot create a second Remaining reduction
completed top-level O2 leaves no reusable causal evidence
```

If nested O2 is structurally forbidden by the production lifecycle, verify that the production architecture remains fail-closed.

Do not invent a new supported nested-exercise path solely for GI.

---

# 17. GI-E — Bounded Reference Integrity

Across commitment/lifecycle churn verify:

```text
live bounded references <= 16
```

For every nonzero reference verify:

```text
reference is unique
reference resolves to a real historical commitment
reference is not dangling
```

Verify historical commitment identity remains valid after reference-slot reclamation and reuse.

Relevant histories include equivalents of:

```text
multiple O1
→ partial fulfillment
→ full fulfillment
→ expiry
→ reference reclamation
→ new O1
→ slot reuse
→ later old/new commitment interaction
```

Commitment IDs must not be recycled.

Reference-slot reuse must not rewrite historical commitment facts.

---

# 18. Reference Reclaimability

Verify that bounded live reference capacity becomes reclaimable only through frozen permanent non-binding causes.

For the current realization these include, as applicable:

```text
Remaining == 0 through authoritative fulfillment
canonical expiry / non-fulfillment release
```

The following must not independently make an otherwise binding commitment reclaimable:

```text
Beneficiary eligibility loss
trader eligibility mutation
liquidity eligibility mutation
resource pressure
ordinary swap
liquidity transition
direct token transfer
failed exercise
```

Do not convert slot-management convenience into a new lifecycle semantic.

---

# 19. GI-F — Authority / Rejection Integrity

Generate invalid, unauthorized, ineligible, and backing-threatening requests through production surfaces.

Rejected transitions must leave no prohibited authoritative economic residue attributable to the failed attempt.

Observe relevant pre/post state according to the attempted operation, including where applicable:

```text
commitment existence
immutable commitment facts
Remaining
reference membership
reference count
aggregate O
Supporting Capacity
PoolManager state
Beneficiary balance
fulfillment observations
causal-context behavior
Hook / Router custody
```

The required property is:

> **No failed Standby operation may leave a prohibited authoritative Standby economic consequence or latent state capable of changing later canonical behavior.**

Do not require unrelated legitimate external state to remain unchanged merely because a later Standby call fails.

---

# 20. O3 Stateful Enforcement

GI must exercise histories in which authentic positive Capacity Obligation exists before backing-affecting operations are attempted.

Required sequence classes include equivalents of:

```text
O1
→ ordinary protected swap toward backing boundary
→ destructive protected swap attempt
```

and:

```text
multiple O1
→ liquidity removal attempt
```

and:

```text
O1
→ Beneficiary eligibility loss
→ backing-threatening O3 attempt
```

Verify that rejection cannot make the request acceptable by:

```text
reducing Remaining
manufacturing fulfillment
releasing a still-binding commitment
rewriting admitted terms
corrupting reference state
```

Equality at the backing boundary must remain accepted where existing F6B semantics permit exact sufficiency.

---

# 21. Liquidity Perimeter

The post-F8D coverage report identified untrusted-perimeter liquidity removal as a GI-relevant candidate because it intersects existing O3 enforcement and authority responsibilities.

Where reachable through actual production interfaces, exercise sufficient variants of:

```text
authorized liquidity action
unauthorized liquidity action
eligible LP action
ineligible LP action
backing-preserving removal
backing-threatening removal
```

to verify that caller/path variation cannot bypass effect-defined backing protection.

Do not introduce new liquidity semantics merely to improve branch coverage.

---

# 22. Direct Beneficiary Token Transfer

Support unrelated direct protected-token transfers to the authoritative Beneficiary.

After such a transfer:

```text
Beneficiary balance may increase
```

but verify:

```text
Remaining unchanged
ghostFulfilled unchanged
no Standby fulfillment created
no commitment fact rewritten
no obligation released solely because of receipt
```

This action exists to establish:

> **Beneficiary token receipt is not sufficient Standby fulfillment.**

Only the canonical attributable O2 path may create fulfillment.

---

# 23. Custody Integrity

Under protocol-controlled flows verify, where applicable:

```text
StandbyHook protected-output balance == 0
ExerciseRouter protected-output balance == 0
```

Do not count deliberate unrelated donations as protocol-created custody.

If unrelated donations are intentionally included, account for them separately so GI can distinguish:

```text
protocol-created custody
```

from:

```text
unrelated external donation
```

Do not use Router or Hook token custody as substitute Beneficiary-delivery evidence.

---

# 24. Failed-Operation Sequence Integrity

GI must verify not only immediate rollback but later sequence correctness.

Required sequence classes include equivalents of:

```text
failed O1
→ later valid O1
```

```text
failed O2(C1)
→ valid O2(C2)
```

```text
failed backing-threatening O3
→ later valid O2
```

```text
failed liquidity action
→ later valid ordinary swap
```

A failed operation must not leave:

```text
stale causal evidence
partial commitment facts
hidden obligation change
false fulfillment
reference corruption
partial delivery
partial Remaining mutation
```

capable of changing a later authoritative result.

---

# 25. Required Stateful Sequence Classes

Ensure the campaigns can meaningfully reach sequence classes equivalent to:

## Backing pressure

```text
O1
→ ordinary protected swap
→ backing-threatening ordinary swap attempt
→ opposite-direction swap
→ partial O2
→ protected swap
```

## Eligibility churn

```text
O1
→ Beneficiary eligibility off
→ O3 attempt
→ Beneficiary eligibility on
→ O2
```

## Multiple commitments

```text
O1(C1)
→ O1(C2)
→ partial O2(C1)
→ ordinary swap
→ O2(C2)
→ later O2(C1)
```

## Expiry / reuse

```text
O1
→ advance time
→ expiry
→ new O1
→ reference reuse
```

## Fulfillment churn

```text
O1
→ partial O2
→ ordinary swap
→ second partial O2
→ full exhaustion
```

## Causal contamination

```text
failed O2(C1)
→ valid O2(C2)
```

## External-delivery discrimination

```text
O1
→ direct protected-token transfer to Beneficiary
→ verify no fulfillment
→ valid O2
```

These are required semantic classes.

They need not all be implemented as deterministic scripted tests if equivalent stateful histories are demonstrably reached by the campaign.

---

# 26. Campaign Diagnostics

A green invariant campaign is insufficient if it exercises little meaningful protocol behavior.

Maintain diagnostic counters sufficient to report activity for:

```text
successful O1
rejected O1

successful O2
failed O2

partial O2
full O2

ordinary protected swaps
ordinary opposite-direction swaps
rejected backing-threatening swaps

liquidity activity
rejected liquidity activity where applicable

Beneficiary eligibility mutation
trader eligibility mutation
liquidity eligibility mutation

time advancement / expiry
multiple commitments
reference reclamation / reuse where reachable
direct Beneficiary transfers
```

Counters are test diagnostics only.

Do not turn exact counter thresholds into protocol semantics.

However:

> **A green campaign with zero successful O2 does not establish meaningful fulfillment-conservation evidence.**

Similarly:

> **A green campaign that never reaches authentic positive `O` does not establish meaningful O3-with-obligation evidence.**

Tune action generation only enough to produce semantically useful reachable histories without converting the handler into a safety pre-filter.

---

# 27. Canonical and Generalized Campaigns

GI must not prove correctness only for the canonical demo identity/direction.

At minimum provide:

## Canonical campaign

```text
MockUSTB = currency0
MockUSDC = currency1
protected direction = zeroForOne
```

## Generalized campaign

Provide a supported non-canonical configuration sufficient to verify:

```text
protected direction = oneForZero
different token ordering / protected-output identity where supported
```

Also preserve the frozen currency-denominational verification obligation.

Where supported by the current realization, include asymmetric currency-decimal configuration sufficient to expose dependence on:

```text
both currencies being 6 decimals
both currencies using equal decimals
1e6 being treated as a universal economic scale
```

Supporting Capacity and Capacity Obligation must remain denominated in the same raw units of the protected output currency.

Do not invent support outside the frozen/current realization domain.

---

# 28. Post-F8D Diagnostic Observations

Post-F8D coverage observations may inform GI only where they intersect frozen responsibilities.

Include behaviorally where appropriate:

```text
untrusted-perimeter liquidity removal
nested / substituted exercise attribution
reachable unresolved exercise-delta fail-closed behavior
```

Do not create separate GI obligations merely to cover:

```text
causal-position read-surface refusal
extreme tick-bound clamping
```

Extreme tick-bound handling remains principally an F5 derivation concern unless GI exposes a reachable compositional counterexample.

Do not manufacture unreachable states solely to increase coverage.

---

# 29. G-I — Full Stateful Invariant Gate

Implementation and tests must provide evidence for all 23 conditions.

Claude may provide an advisory assessment but does not close G-I.

## G-I-1 — Supporting Capacity Equivalence

Prove:

```text
referenceS == productionS
```

across applicable reachable states.

## G-I-2 — Capacity Obligation Equivalence

Prove:

```text
referenceO == productionO
```

across applicable reachable states.

## G-I-3 — Backing Sufficiency

Prove:

```text
referenceS >= referenceO
```

in every reachable authoritative state with binding obligation.

## G-I-4 — Remaining Bound

Prove for every commitment:

```text
Remaining <= Original
```

## G-I-5 — Immutable Commitment Facts

Prove admitted immutable commitment facts never change.

## G-I-6 — Remaining Monotonicity

Prove:

```text
Remaining never increases
```

## G-I-7 — Fulfillment Conservation

Prove:

```text
Original - Remaining
    ==
independently tracked successful attributable fulfillment
```

## G-I-8 — Expiry Is Not Fulfillment

Prove expiry/non-fulfillment release does not manufacture fulfillment or rewrite Remaining as though fulfillment occurred.

## G-I-9 — Eligibility Mutation Integrity

Prove eligibility changes do not:

```text
manufacture fulfillment
reduce Remaining
release otherwise binding O
```

## G-I-10 — Ordinary Swap Non-Fulfillment

Prove ordinary swaps never create fulfillment.

## G-I-11 — Liquidity Non-Fulfillment

Prove liquidity actions never create fulfillment.

## G-I-12 — Direct Transfer Non-Fulfillment

Prove direct protected-token transfers never create fulfillment.

## G-I-13 — Exact O2 Attribution

For every successful O2 prove:

```text
exactly one commitment
exactly q fulfillment
exactly q Remaining reduction
```

## G-I-14 — Exact Beneficiary Delivery

Under canonical mock semantics prove successful O2 delivers exactly:

```text
q
```

protected output to the authoritative Beneficiary.

## G-I-15 — Failed O2 Integrity

Prove failed O2 produces:

```text
zero fulfillment
zero Remaining reduction
zero prohibited authoritative residue
```

## G-I-16 — Protocol Custody Integrity

Under protocol-controlled flows prove no protected-output custody remains in:

```text
StandbyHook
ExerciseRouter
```

excluding separately accounted unrelated donations.

## G-I-17 — Reference Bound

Prove:

```text
live references <= 16
```

## G-I-18 — Reference Validity

Prove every nonzero reference is:

```text
unique
non-dangling
historically valid
```

## G-I-19 — History Across Reuse

Prove historical commitment identity and immutable facts survive bounded-reference slot reuse.

## G-I-20 — Reclamation Cause Integrity

Prove only frozen permanent non-binding causes permit economic live-reference reclamation.

## G-I-21 — O2 Context Isolation

Prove no reusable cross-transaction O2 authorization/execution/finalization context survives completed top-level actions.

## G-I-22 — Generalization

Prove canonical and supported generalized protected-direction/configuration campaigns pass.

## G-I-23 — Campaign Quality

Provide diagnostic evidence that campaigns actually exercise meaningful:

```text
O1
O2
O3
swap
liquidity
lifecycle
eligibility
success
rejection
multi-commitment
partial fulfillment
full fulfillment
```

behavior rather than achieving a trivial green result.

---

# 30. Assertion Shape

Not every G-I property must be encoded as a top-level Foundry:

```solidity
function invariant_...()
```

Use the proof shape appropriate to the property.

Continuous global properties naturally belong in invariant functions, for example:

```text
S >= O
Remaining <= Original
reference integrity
custody
```

Transition-specific exactness may be checked immediately around handler operations, for example:

```text
successful O2 changed exactly one Remaining by q
failed O2 changed no fulfillment state
direct transfer did not change fulfillment
failed operation left no prohibited residue
```

Assertions executed inside handler-generated histories are valid GI evidence.

Do not weaken semantic proof coverage merely to fit a particular Foundry function shape.

---

# 31. Production-Code Boundary

GI is presumed to be a verification-only slice.

Do not proactively modify production semantics to make the invariant suite easier to implement or pass.

If GI discovers a genuine production counterexample:

1. preserve or minimize the failing sequence;
2. identify the violated frozen invariant or verification obligation;
3. trace the defect to its existing normative implementation owner;
4. record the finding in the Session 15 log;
5. report the affected previous slice/gate;
6. do not invent a new GI-owned semantic repair.

Potential existing owners include:

```text
F4
F5
F6B
F7
F8A
F8B
F8C
F8D
```

If a production correction is unambiguously required by already-frozen semantics, keep it minimal and explicitly report:

```text
violated frozen property
existing normative owner
counterexample
root cause
production change
affected previous gate
```

Do not silently patch production code while constructing the invariant suite.

---

# 32. Responsibility Leakage / Out of Scope

GI verifies composition of already-owned responsibilities.

It must not absorb those responsibilities.

## F4 remains owner of

```text
commitment identity
bounded-reference representation
historical commitment persistence
```

## F5 remains owner of

```text
authoritative derivation kernel
Supporting Capacity derivation
Capacity Obligation derivation
prospective derivation
```

## F6B remains owner of

```text
O3 backing enforcement with authentic O > 0
```

## F7 remains owner of

```text
O1 commitment admission
```

## F8A remains owner of

```text
O2 authorization
exercise authority
validity / exercisability admission
Hook-owned causal authorization context
```

## F8B remains owner of

```text
protected exact-output PoolManager execution
execution evidence
```

## F8C remains owner of

```text
actual input settlement
authenticated exerciser payment
direct Beneficiary delivery
PoolManager delta closure
```

## F8D remains owner of

```text
actual final backing
exact Remaining reduction
exact-once causal-context consumption
durable fulfillment
```

GI verifies their composition.

Also out of scope:

```text
F9 canonical acceptance
F10 demo instrumentation
frontend work
public testnet deployment
gas optimization
coverage maximization
unrelated refactoring
new protocol features
```

---

# 33. GI vs F9

Do not implement F9.

GI asks:

> **Does adversarial stateful composition preserve frozen safety and derivation properties?**

F9 asks:

> **Does a fresh deterministic production deployment reproduce the canonical A1 → A4 acceptance scenario exactly?**

GI must not substitute a scripted A1→A4 acceptance test for stateful invariant verification.

Do not begin F9 merely because the GI campaign reaches states similar to the canonical demo path.

---

# 34. GI-Specific Verification Evidence

Use the repository-standard verification already required by:

```text
CLAUDE.md
.claude/rules/*
```

Do not duplicate or reinterpret those permanent verification requirements here.

For GI specifically, also execute the stateful invariant campaigns required to establish G-I.

Report the actual GI campaign configuration used, including as applicable:

```text
runs
depth / calls
target contracts
target selectors
campaign variants
canonical configuration
generalized configuration
```

Report actual campaign results.

Do not claim G-I evidence solely because the repository-standard suite passes.

Do not claim G-I evidence from a campaign that failed to exercise meaningful O1/O2/O3 state evolution.

---

# 35. Campaign Quality Check

Before proposing G-I PASS, inspect the campaign diagnostics.

Determine whether the runs actually achieved meaningful instances of:

```text
successful commitment establishment
authentic positive O
successful O2
failed O2
partial fulfillment
full fulfillment where reachable
backing-threatening O3 rejection
ordinary protected swap
ordinary opposite-direction swap
liquidity activity
eligibility mutation
time / expiry activity
multiple commitments
reference churn / reuse where reachable
```

If important classes remain zero or effectively unreachable:

1. report that fact;
2. determine whether handler construction or action weighting is the cause;
3. improve state exploration where possible without semantic pre-filtering;
4. identify any remaining reachability limitation.

A green but semantically empty campaign is not sufficient G-I evidence.

---

# 36. Oracle Independence Check

Before completion, explicitly inspect the invariant implementation for correlated-oracle risk.

Verify that expected/reference results for:

```text
Supporting Capacity
Capacity Obligation
fulfillment conservation
commitment-history integrity
Beneficiary delivery
reference integrity
```

are not merely wrappers around the production values being checked.

Document the independent basis used for each significant oracle.

If a property cannot be checked independently without duplicating the entire protocol state machine, prefer a narrower independent historical/observable proof rather than creating a second authoritative Standby implementation.

---

# 37. File Boundary

GI should primarily add test-side files.

Expected changes are likely to include:

```text
test/invariant/*
```

and narrowly necessary invariant-specific helper files.

Maintain:

```text
docs/prompts/session-15-log.md
```

Do not update:

```text
docs/project-status.md
```

during GI implementation.

Do not modify frozen canonical artifacts.

Production files should remain unchanged unless GI discovers a genuine implementation defect already governed by frozen semantics.

---

# 38. Session Evidence / Post-Project Retrospective

Maintain:

```text
docs/prompts/session-15-log.md
```

as the Claude implementation-process record for GI.

Preserve materially relevant:

```text
invariant architecture
handler design
actor design
ghost/reference-state decisions
oracle-independence decisions
files changed
campaign configuration
action-selection tuning
counterexamples encountered
test failures and corrections
production defects discovered
production changes, if any
verification commands and results
campaign diagnostics
known reachability limitations
advisory G-I assessment
```

This log is non-normative.

Do not update:

```text
docs/project-status.md
```

during GI implementation.

The status-only update occurs only after independent review and explicit G-I closure.

A separate retrospective record will later be produced:

```text
docs/prompts/retrospective/session-15-chatgpt-record.md
```

Do not create or modify that file during GI implementation.

---

# 39. Completion Report

When GI implementation is complete, report:

1. files inspected;
2. files changed;
3. invariant architecture;
4. production components exercised;
5. handler actions implemented;
6. persistent actor model;
7. ghost/reference state used;
8. independent oracle strategy;
9. invariant functions added;
10. transition-local stateful assertions added;
11. canonical campaign configuration;
12. generalized campaign configuration;
13. campaign diagnostics / action counters;
14. GI-specific campaign commands executed;
15. repository verification results required by the permanent instructions;
16. all material counterexamples encountered during implementation;
17. any production defect discovered;
18. any production code changed;
19. advisory G-I-1 through G-I-23 assessment;
20. known limitations, reachability gaps, deviations, or discrepancies;
21. scope check;
22. recommended next step;
23. prompt audit.

For every G-I condition, use:

```text
PASS
FAIL
NOT YET PROVEN
```

with concise supporting evidence.

Do not infer PASS merely because:

```text
forge test succeeds
```

or:

```text
no invariant failed
```

if campaign activity does not actually discharge the condition.

Do not declare G-I closed.

---

# 40. Counterexample Reporting

If a stateful invariant or handler assertion fails, preserve the counterexample.

Report:

```text
generated action sequence
failing invariant / assertion
relevant authoritative pre-state
relevant authoritative post-state
independent expected result
actual production result
suspected normative owner
```

First determine whether the failure is caused by:

```text
handler defect
oracle defect
fixture defect
invalid test assumption
production implementation defect
frozen-artifact discrepancy
```

Do not dismiss a counterexample as a test issue without establishing its cause.

If unresolved, report G-I as not yet proven.

---

# 41. Accepted GI Semantic Statement

Before editing, preserve this accepted responsibility:

> **GI does not introduce new Standby semantics. It subjects the F8D-complete production realization to adversarial multi-operation histories and independently verifies that backing, commitment state, fulfillment attribution, bounded references, causal evidence, authority boundaries, failure atomicity, and custody remain correct throughout the reachable state space required by the frozen verification domain.**

The intended verification shape is:

```text
Production Paths
        +
Stateful Adversarial Sequences
        +
Independent Reference / History Evidence
        +
Global Invariant Closure
```

Implement that responsibility and nothing broader.

---

# 42. Completion Boundary

The GI completion boundary is:

```text
stateful invariant architecture implemented
GI handler implemented
production-path campaigns implemented
independent oracle/history evidence implemented
G-I-1 through G-I-23 evidence collected
canonical campaign executed
generalized campaign executed
GI-specific campaign diagnostics reviewed
repository verification complete
session-15-log.md updated
completion report produced
```

Stop at the GI completion boundary.

Do not begin F9.
