# Standby --- Demo Specification

**Artifact:** `demo-spec.md`\
**Status:** FINAL PASS / FROZEN\
**Project:** Standby\
**Purpose:** Canonical deterministic demonstration specification for the
ETHGlobal reference realization

------------------------------------------------------------------------

## 1. Purpose

This document defines the minimum deterministic demonstration required
to prove the essential economic claim of the Standby Uniswap v4
reference realization.

The demonstration is an acceptance-oriented proof of protocol behavior.
It is not the presentation script, implementation plan, user-interface
implementation specification, or replacement for the frozen canonical
protocol documentation.

The demo SHALL demonstrate only behavior already established by the
frozen canonical package and `uniswap-v4-realization.md`. It SHALL NOT
introduce new economic semantics, authorities, lifecycle behavior,
state, or protocol guarantees.

The canonical demonstration SHALL be reproducible from a known initial
state and SHALL establish its proof through actual Standby and Uniswap
v4 execution rather than simulated outcomes.

------------------------------------------------------------------------

## 2. Demo Objective

The canonical demo SHALL prove the following essential claim.

### DEMO-CLAIM-1 --- Essential Economic Claim

> **Standby turns shared AMM liquidity into enforceable future execution
> capacity without reserving that liquidity: the liquidity remains
> available for compatible ordinary use, but any transition that would
> leave an admitted commitment insufficiently backed is rejected, and
> the commitment can later be fulfilled through actual AMM execution and
> Beneficiary delivery.**

The minimum economic proof narrative is:

**shared resource → admitted promise → continued compatible use →
protected boundary → enforcement → actual fulfillment**

The demonstration SHALL establish every link in this sequence.

------------------------------------------------------------------------

## 3. Canonical Demo Narrative

The demonstration SHALL begin with the economic problem rather than with
protocol mechanics.

### DEMO-NARRATIVE-1 --- Institutional Scenario

An institution holds a tokenized short-duration Treasury or
cash-equivalent asset and may require a bounded amount of USDC at a
future time for settlement.

The institution could pre-position the required USDC or arrange
dedicated liquidity. Either approach commits resources before the future
need is known to have materialized.

Standby provides another coordination model.

The institution establishes a future execution commitment providing an
entitlement to qualifying USDC execution capacity backed by shared
Uniswap liquidity. The liquidity is not segregated for the institution.
Compatible ordinary use of the pool remains possible while the
commitment is outstanding.

Standby intervenes only when a backing-affecting transition would leave
the admitted commitment insufficiently supported.

If the future settlement need materializes, the authorized exerciser
exercises the commitment through actual AMM execution and the
authoritative Beneficiary receives the protected output.

The concise demo framing is:

> **An institution may need 50,000 USDC tomorrow. Instead of
> pre-positioning the USDC or reserving AMM liquidity, it uses Standby
> to secure 50,000 USDC of future execution capacity from a shared
> Uniswap pool.**

The central explanatory statement is:

> **Standby doesn't reserve liquidity. It protects capacity.**

------------------------------------------------------------------------

## 4. Demo Asset Model

### 4.1 Demo Currencies

The canonical demo SHALL use two deterministic mock ERC-20 currencies:

-   **MockUSTB** --- represents a tokenized short-duration Treasury or
    cash-equivalent asset.
-   **MockUSDC** --- represents the settlement asset.

Both currencies SHALL use six decimal places and the canonical fixture
SHALL initialize them on an approximately 1:1 NAV-anchored economic
basis.

MockUSTB is a representative demo asset only. The demonstration SHALL
NOT imply production integration with, endorsement by, or compatibility
with any specific tokenized-Treasury issuer.

### 4.2 Currency Ordering

The canonical PoolKey SHALL satisfy:

-   `currency0 = MockUSTB`
-   `currency1 = MockUSDC`

The demo deployment SHALL deterministically establish the required
address ordering rather than assume token naming determines Uniswap
currency ordering.

### 4.3 Protected Direction

The canonical protected direction SHALL be:

`zeroForOne = true`

representing:

**MockUSTB → MockUSDC**

MockUSDC is therefore the protected output currency.

Supporting Capacity, Capacity Obligation, Original Entitlement,
Remaining Entitlement, exercise quantity, and Beneficiary delivery SHALL
be denominated in MockUSDC.

------------------------------------------------------------------------

## 5. Canonical Pool and Service Configuration

The canonical deterministic fixture SHALL use the following
configuration.

  Parameter                               Canonical value
  ---------------------------- --------------------------
  Pair                                MockUSTB / MockUSDC
  Protected direction                        `zeroForOne`
  Initial tick                                        `0`
  `tickQ`                                          `-240`
  `tickO`                                          `+240`
  LP lower tick                                    `-300`
  LP upper tick                                    `+300`
  Tick spacing                                       `10`
  LP fee                               `500` pips / 0.05%
  Active liquidity `L`                `6,707,079,990,254`
  Commitment entitlement `q`     `50,000.000000 MockUSDC`

These numerical pool, fee, liquidity, range, and service-domain values
define the canonical deterministic demonstration fixture only. They
SHALL NOT be interpreted as general Standby protocol requirements. The
fixed fee and topology parameters are included because the canonical
demonstration requires reproducible AMM state transitions and expected
outputs.

The initial pool price is 1 MockUSDC per MockUSTB in raw-decimal parity.

The service domain is bounded by `tickQ` and `tickO`.

The controlled LP position SHALL span the complete service domain. Its
initialized boundaries SHALL lie outside the service domain, and no
initialized liquidity boundary SHALL exist strictly inside the service
domain.

The canonical demonstration SHALL therefore remain within one constant
active-liquidity interval.

------------------------------------------------------------------------

## 6. Supporting Capacity

### 6.1 Definitions

Let:

-   `sqrtP` denote the authoritative current PoolManager square-root
    price.
-   `sqrtQ` denote the square-root price corresponding to `tickQ`.
-   `L` denote active liquidity across the relevant interval.
-   `S` denote current Supporting Capacity in MockUSDC.
-   `S′` denote prospective Supporting Capacity derived from the
    prospective PoolManager state of a proposed transition.
-   `O` denote current aggregate Capacity Obligation in MockUSDC.
-   `q` denote the commitment entitlement or exercise quantity in
    MockUSDC.

### 6.2 Supporting Capacity Derivation

For the canonical protected `zeroForOne` direction, Supporting Capacity
SHALL be derived using the frozen realization:

`S = getAmount1Delta(sqrtQ, sqrtP, L, false)`

Supporting Capacity SHALL be derived from authoritative Uniswap v4 state
and SHALL NOT be persisted as independent economic truth.

Prospective Supporting Capacity SHALL be determined by first deriving
the prospective v4 state and then recomputing `S′`.

The implementation and demo SHALL NOT assume that:

`S′ = S − tokenAmount`

unless that equality independently follows from the authoritative AMM
state transition.

All numerical `S` and `S′` values in this artifact are expected outputs
of the canonical fixture's authoritative integer derivation. They do not
independently define Supporting Capacity.

### 6.3 Initial Capacity

For the canonical fixture, the authoritative integer derivation is
expected to produce:

`S₀ = 80,000.000000 MockUSDC`

and initially:

`O₀ = 0`

Therefore:

`80,000 ≥ 0`

and the system begins with positive shared Supporting Capacity and no
outstanding Capacity Obligation.

------------------------------------------------------------------------

## 7. Minimum Observable Proof Obligations

The canonical demonstration SHALL establish all five proof obligations
below.

### DP-1 --- Shared Capacity

The demo SHALL visibly establish that positive Supporting Capacity
arises from shared AMM state rather than from a Standby-controlled
segregated reserve.

Compatible ordinary use in DP-3 SHALL provide the decisive demonstration
that the backing resource remains shared.

### DP-2 --- Commitment Admission

The demo SHALL establish a future 50,000 MockUSDC Capacity Obligation
against the existing Supporting Capacity.

Admission SHALL change the obligation and commitment state without
reducing Supporting Capacity or segregating the corresponding MockUSDC.

### DP-3 --- Compatible Ordinary Use Succeeds

While the commitment remains outstanding, an ordinary
protected-direction transition SHALL successfully consume some of the
shared executable capacity while leaving:

`S′ ≥ O`

This proves positive permissiveness and demonstrates that Standby does
not simply reserve the committed amount.

### DP-4 --- Capacity-Destroying Ordinary Use Fails

An otherwise-valid ordinary protected-direction transition whose
prospective state would produce:

`S′ < O`

SHALL be rejected.

The rejection SHALL occur because of Standby's backing requirement
rather than permission failure, insufficient balance, allowance failure,
slippage protection, service-domain violation, or unrelated AMM failure.

The rejected transition SHALL NOT change authoritative pool or Standby
economic state.

### DP-5 --- Protected Exercise Delivers

The authorized exerciser SHALL execute the commitment through the
canonical O2 path.

The demonstration SHALL establish:

-   exact-output AMM execution;
-   authoritative input-debt settlement;
-   actual MockUSDC delivery to the authoritative Beneficiary;
-   causal fulfillment of the demonstrated commitment;
-   Remaining Entitlement reduction;
-   corresponding Capacity Obligation reduction.

Remaining Entitlement SHALL NOT be reduced until the required AMM
execution, authoritative input-debt settlement, direct output delivery
to the authoritative Beneficiary, and causal finalization have completed
within the canonical atomic O2 transition.

For the canonical full exercise, Remaining Entitlement and the
commitment's Capacity Obligation SHALL become zero.

------------------------------------------------------------------------

## 8. Canonical Live Action Sequence

Deployment, token creation, pool initialization, PES configuration,
controlled liquidity provision, eligibility configuration, account
funding, and approvals MAY occur before the live proof begins.

The canonical live proof SHALL begin from a configured, liquid,
commitment-free PES.

### 8.1 Canonical Pre-State

Before the first live action:

-   the Standby and Uniswap v4 infrastructure is deployed;
-   the PES is active;
-   controlled liquidity exists;
-   required actors are eligible;
-   required balances and approvals exist;
-   no commitment exists;
-   authoritative derivation yields `S = 80,000.000000 MockUSDC`;
-   `O = 0`.

### 8.2 Action 1 --- Admit Commitment

Admit a commitment with:

`q = 50,000.000000 MockUSDC`

Expected authoritative state:

-   `S = 80,000.000000`
-   `O = 50,000.000000`
-   Remaining Entitlement = `50,000.000000`

Backing condition:

`80,000 ≥ 50,000`

**Expected result: PASS / ADMITTED**

### 8.3 Action 2 --- Compatible Ordinary Use

Execute the canonical eligible ordinary protected-direction exact-output
swap for:

`15,000.000000 MockUSDC`

The canonical authoritative integer derivation is expected to produce:

-   `S = 65,000.000000`
-   `O = 50,000.000000`
-   Remaining Entitlement = `50,000.000000`

Backing condition:

`65,000 ≥ 50,000`

**Expected result: PASS / ORDINARY SWAP SUCCEEDS**

### 8.4 Action 3 --- Attempt Capacity-Destroying Ordinary Use

From the Action 2 state, attempt the canonical otherwise-valid ordinary
protected-direction exact-output swap for:

`20,000.000000 MockUSDC`

The canonical prospective integer derivation is expected to produce:

`S′ = 45,000.000000 MockUSDC`

while:

`O = 50,000.000000 MockUSDC`

Therefore:

`45,000 < 50,000`

**Expected result: REJECT**

Because the transaction cannot become authoritative, post-rejection
authoritative state remains:

-   `S = 65,000.000000`
-   `O = 50,000.000000`
-   Remaining Entitlement = `50,000.000000`

### 8.5 Action 4 --- Full Protected Exercise

From the unchanged post-Action-3 authoritative state, exercise:

`q = 50,000.000000 MockUSDC`

through the canonical O2 path.

The protected execution SHALL remain within `tickQ`.

PoolManager SHALL deliver exactly:

`50,000.000000 MockUSDC`

to the authoritative Beneficiary.

Only after the required AMM execution, authoritative input-debt
settlement, direct Beneficiary delivery, and causal finalization have
completed within the canonical atomic O2 transition may Remaining
Entitlement be reduced.

Following authoritative fulfillment:

-   Remaining Entitlement = `0`
-   `O = 0`
-   the authoritative integer derivation for the realized canonical
    PoolManager state is expected to produce
    `S = 15,000.000000 MockUSDC`.

**Expected result: PASS / FULFILLED**

### 8.6 Optional Action 5 --- Post-Fulfillment Closure

Following full fulfillment, the demonstration MAY execute an
independently valid ordinary pool transition to show that no Capacity
Obligation remains for the fulfilled commitment.

This action is supplementary.

It SHALL NOT be required to establish DEMO-CLAIM-1, DP-1 through DP-5,
or canonical demo acceptance.

The rejected Action 3 transaction SHALL NOT be assumed to be replayable
after O2 because O2 changes authoritative pool state.

------------------------------------------------------------------------

## 9. Canonical State Matrix

  ---------------------------------------------------------------------------
  Stage                Supporting        Capacity       Remaining Required
                         Capacity      Obligation     Entitlement outcome
  --------------- --------------- --------------- --------------- -----------
  Pre-state         80,000.000000               0               0 Shared
                                                                  capacity
                                                                  exists

  A1 ---            80,000.000000   50,000.000000   50,000.000000 ADMITTED
  Admission                                                       

  A2 --- Ordinary   65,000.000000   50,000.000000   50,000.000000 SUCCESS
  use                                                             

  A3 ---            45,000.000000   50,000.000000   50,000.000000 REJECT
  Prospective                                                     
  state                                                           

  A3 ---            65,000.000000   50,000.000000   50,000.000000 UNCHANGED
  Authoritative                                                   
  post-revert                                                     

  A4 --- Full       15,000.000000               0               0 FULFILLED
  fulfillment                                                     
  ---------------------------------------------------------------------------

Every Supporting Capacity value in this matrix is an expected result of
the canonical authoritative integer derivation.

The `45,000.000000 MockUSDC` value in the A3 prospective row is not
authoritative state. It is the derived prospective Supporting Capacity
that causes rejection.

------------------------------------------------------------------------

## 10. Demo Observability Requirements

### DEMO-OBS-1 --- Authoritative Observability

Every displayed value used as evidence for a demo proof obligation SHALL
be derived from authoritative Standby state, PoolManager state,
transaction results, or authoritative token balances.

The demo interface SHALL NOT maintain independent economic truth or
simulate protocol outcomes.

### DEMO-OBS-2 --- Economic Legibility

The canonical demonstration SHALL expose enough human-readable evidence
for a judge to observe the economic proof without interpreting raw EVM
traces.

The primary observable economic values SHALL include:

-   Supporting Capacity `S`;
-   Capacity Obligation `O`;
-   Remaining Entitlement;
-   relevant transaction quantity;
-   transaction acceptance or rejection;
-   Beneficiary MockUSDC delivery.

Current price or tick MAY be displayed as secondary explanatory
evidence.

### DEMO-OBS-3 --- Prospective vs Authoritative State

For rejected transitions, the demonstration SHALL clearly distinguish:

-   current authoritative state;
-   proposed transaction facts;
-   prospective derived state used for authorization.

The A3 `S′ = 45,000.000000 MockUSDC` value SHALL be labeled as
prospective and SHALL NOT be represented as state that became
authoritative.

### DEMO-OBS-4 --- Proof-Minimal Evidence

For each proof obligation, the interface SHALL expose the minimum
evidence necessary for a judge to independently determine whether the
obligation has been established.

Implementation telemetry that does not materially contribute to the
economic proof SHOULD remain secondary.

### DEMO-OBS-5 --- Non-Reservation Evidence

Non-reservation SHALL be demonstrated by:

1.  commitment admission without segregation of the committed backing
    amount; and
2.  successful compatible ordinary use of the same shared executable
    capacity while the commitment remains outstanding.

Zero MockUSDC custody by Standby contracts MAY be displayed as
supporting evidence but SHALL NOT by itself constitute proof of
non-reservation.

### DEMO-OBS-6 --- Canonical State Matrix

The interface SHALL expose the before/action/after evidence required by
the canonical state matrix, including state that changes and state that
must remain unchanged.

### DEMO-OBS-7 --- Evidence Classification

The interface SHALL distinguish:

-   authoritative current state;
-   proposed transaction facts;
-   prospective derived state.

A rejected prospective state SHALL never be displayed as authoritative
protocol state.

------------------------------------------------------------------------

## 11. Minimum Evidence by Proof Obligation

### 11.1 DP-1 Evidence

Mandatory evidence:

-   authoritative derivation yields `S = 80,000.000000 MockUSDC`;
-   `O = 0`;
-   shared pool liquidity exists;
-   no live commitment exists.

Supporting evidence MAY include zero MockUSDC balances held by
StandbyHook and ExerciseRouter.

### 11.2 DP-2 Evidence

Mandatory evidence:

-   requested commitment = `50,000.000000 MockUSDC`;
-   admission succeeds;
-   `S` remains `80,000.000000`;
-   `O` changes `0 → 50,000.000000`;
-   Remaining Entitlement becomes `50,000.000000`;
-   backing condition is satisfied.

### 11.3 DP-3 Evidence

Mandatory evidence:

-   ordinary output request = `15,000.000000 MockUSDC`;
-   ordinary swap succeeds;
-   authoritative derivation yields `S` change
    `80,000.000000 → 65,000.000000`;
-   `O` remains `50,000.000000`;
-   Remaining Entitlement remains `50,000.000000`;
-   `65,000 ≥ 50,000`.

### 11.4 DP-4 Evidence

Mandatory evidence:

-   ordinary output request = `20,000.000000 MockUSDC`;
-   prospective authoritative derivation yields `S′ = 45,000.000000`;
-   current `O = 50,000.000000`;
-   `45,000 < 50,000`;
-   explicit Standby backing rejection;
-   authoritative `S` remains `65,000.000000`;
-   `O` remains `50,000.000000`;
-   Remaining Entitlement remains `50,000.000000`.

### 11.5 DP-5 Evidence

Mandatory evidence:

-   exercise quantity = `50,000.000000 MockUSDC`;
-   Beneficiary balance immediately before exercise;
-   Beneficiary balance immediately after exercise;
-   exact Beneficiary increase = `50,000.000000 MockUSDC`;
-   Remaining Entitlement changes `50,000.000000 → 0`;
-   `O` changes `50,000.000000 → 0`;
-   protected execution succeeds;
-   resulting backing state remains valid.

------------------------------------------------------------------------

## 12. Demo Acceptance Criteria

### DEMO-AC-1 --- Shared Capacity Without Reservation

The canonical pre-state passes only if:

-   the configured shared AMM liquidity exists;
-   authoritative derivation yields Supporting Capacity
    `80,000.000000 MockUSDC`;
-   `O = 0`;
-   no live commitment exists;
-   Supporting Capacity is derived from authoritative PoolManager state.

### DEMO-AC-2 --- Commitment Admission

Admission passes only if:

-   the authorized establishment path succeeds;
-   Original Entitlement = `50,000.000000 MockUSDC`;
-   Remaining Entitlement = `50,000.000000 MockUSDC`;
-   `O` changes `0 → 50,000.000000`;
-   `S` remains `80,000.000000`;
-   `S ≥ O`;
-   admission does not segregate the committed MockUSDC amount;
-   the commitment becomes authoritative atomically.

### DEMO-AC-3 --- Compatible Shared Use

The compatible ordinary transition passes only if:

-   the ordinary swap succeeds;
-   the trader receives the requested output;
-   actual PoolManager state changes;
-   Supporting Capacity rederived from resulting authoritative state
    equals `65,000.000000 MockUSDC`;
-   `O` remains `50,000.000000`;
-   Remaining Entitlement remains `50,000.000000`;
-   `S ≥ O`.

### DEMO-AC-4 --- Capacity-Destroying Shared Use Rejection

The destructive ordinary transition passes the demo acceptance test only
if:

-   the proposed transaction is otherwise executable;
-   its prospective state produces `S′ = 45,000.000000 MockUSDC`;
-   `S′ < O`;
-   Standby rejects the transition because of backing insufficiency;
-   rejection is not attributable to eligibility, balance, allowance,
    slippage, service-domain violation, or unrelated v4 failure;
-   PoolManager state does not become authoritative for the rejected
    transition;
-   actual `S` remains `65,000.000000`;
-   `O` remains `50,000.000000`;
-   Remaining Entitlement remains `50,000.000000`.

### DEMO-AC-5 --- Actual Beneficiary Fulfillment

Full protected exercise passes only if:

-   exercise authority is valid;
-   current commitment validity and exercisability requirements hold;
-   current Beneficiary eligibility holds;
-   one exact-output protected AMM swap executes;
-   execution remains inside the configured service boundary;
-   the authoritative MockUSTB input debt is settled;
-   PoolManager delivers exactly `50,000.000000 MockUSDC` to the
    authoritative Beneficiary;
-   the ExerciseRouter does not custody the protected output;
-   actual delivery is causally attributable to the exercised
    commitment;
-   Remaining Entitlement is not reduced before the required execution,
    input-debt settlement, direct Beneficiary delivery, and causal
    finalization complete within the atomic O2 transition;
-   Remaining Entitlement changes `50,000.000000 → 0`;
-   `O` changes `50,000.000000 → 0`;
-   Supporting Capacity rederived from final authoritative PoolManager
    state equals the canonical expected `15,000.000000 MockUSDC`;
-   final backing remains valid.

### DEMO-AC-6 --- End-to-End Economic Proof

The canonical demonstration passes only if DP-1 through DP-5 are
established in order from one deterministic canonical pre-state.

Each successful action SHALL operate on authoritative state resulting
from the preceding successful action.

The rejected A3 transition SHALL leave authoritative state unchanged
before A4 executes.

The canonical proof SHALL NOT depend upon resetting the pool, manually
modifying state, or substituting simulated state between required
actions.

### DEMO-AC-7 --- Interface Fidelity

Every displayed value relied upon to establish DP-1 through DP-5 SHALL
be reproducible from:

-   authoritative Standby contract state;
-   authoritative PoolManager state;
-   token balances;
-   or the demonstrated transaction result.

The interface SHALL NOT determine protocol authorization, backing
validity, fulfillment, or any other authoritative economic outcome.

------------------------------------------------------------------------

## 13. Demo Execution Environment

Canonical acceptance requires a deterministic execution environment
using the actual Uniswap v4 execution stack and actual Standby
contracts. The judged reference demonstration SHALL use a local Anvil
environment to provide deterministic execution.

The canonical environment SHALL include:

-   actual Uniswap v4 PoolManager execution;
-   actual StandbyHook;
-   actual ExerciseRouter;
-   actual EligibilityRegistry;
-   MockUSTB and MockUSDC as the demo economic currencies.

The Uniswap execution environment SHALL NOT be replaced by a mock AMM
for the canonical integration demonstration.

A public test-L2 deployment MAY be produced as supplementary submission
evidence but SHALL NOT be required for canonical demo acceptance.

Deployment scripts, account construction, RPC wiring, frontend stack,
and other environment-construction choices belong to the Implementation
Plan rather than this artifact.

------------------------------------------------------------------------

## 14. Demo Interface Boundary

The canonical demonstration SHOULD use human-readable instrumentation
sufficient to make the economic proof legible. A minimal purpose-built
interface is the preferred reference presentation, but the interface is
not protocol authority and is not a production dApp requirement.

The interface SHOULD prominently expose:

-   Supporting Capacity;
-   Capacity Obligation;
-   Remaining Entitlement;
-   Beneficiary MockUSDC balance;
-   latest transaction outcome;
-   backing relation `S ≥ O`.

The interface MAY expose current pool price/tick and implementation
telemetry as secondary evidence.

The reference interface SHOULD support the four required live actions:

1.  Admit Commitment
2.  Compatible Ordinary Swap
3.  Attempt Capacity-Destroying Ordinary Swap
4.  Exercise Commitment

Detailed frontend architecture and implementation choices belong to the
Implementation Plan.

------------------------------------------------------------------------

## 15. Claim and Interpretation Boundaries

### 15.1 What the Demo Establishes

Successful completion of the canonical demonstration establishes that,
for the demonstrated Standby configuration:

-   a future exact-output execution commitment can be admitted against
    qualifying shared AMM capacity;
-   commitment admission does not require segregating the committed
    output amount;
-   compatible ordinary use remains possible while the commitment is
    outstanding;
-   a transition that would make the outstanding obligation
    insufficiently backed cannot become authoritative;
-   the commitment can later be exercised through actual AMM execution;
-   the authoritative Beneficiary can receive the exact protected
    output;
-   fulfillment can reduce Remaining Entitlement and release the
    corresponding Capacity Obligation.

### 15.2 What the Demo Does Not Establish

The canonical demonstration SHALL NOT be interpreted as proving that
Standby:

-   guarantees arbitrary future execution under all conditions;
-   guarantees a fixed input price;
-   eliminates AMM price impact or slippage;
-   protects all AMM liquidity or all pool behavior;
-   guarantees exercise independent of commitment validity or
    exercisability;
-   guarantees exercise independent of Beneficiary eligibility or
    exercise authority;
-   supports every token or tokenized asset;
-   constitutes integration with a particular tokenized-Treasury issuer;
-   constitutes production-ready institutional settlement
    infrastructure.

Standby protects qualifying future execution capacity under the
configured service conditions demonstrated by the reference realization.

------------------------------------------------------------------------

## 16. Whole-Demo Completeness Requirements

The canonical demo is complete only if the following economic causal
chain is visible:

1.  shared executable capacity exists;
2.  a future right-obligation relationship becomes authoritative;
3.  the backing resource remains shared;
4.  compatible shared use remains permitted;
5.  use that would violate the admitted obligation is prevented;
6.  the future right is exercised through actual AMM execution;
7.  the authoritative Beneficiary receives the promised output;
8.  fulfillment releases the corresponding obligation.

No additional required live action is necessary to establish
DEMO-CLAIM-1.

### DEMO-GATE-1 --- Non-Reservation Proof

Non-reservation is established by commitment admission without
backing-asset segregation together with demonstrated compatible use of
the same shared executable capacity.

Zero Standby token custody is supporting evidence but is not sufficient
by itself.

### DEMO-GATE-2 --- Rejection Attribution

The canonical destructive ordinary transition SHALL be otherwise
executable and SHALL fail specifically because its prospective
Supporting Capacity would violate the outstanding Capacity Obligation.

### DEMO-GATE-3 --- Claim Boundary

The demo establishes protected future execution capacity under the
configured Standby service conditions.

It does not establish guaranteed input price, zero slippage, universal
asset support, or unconditional execution independent of validity,
eligibility, authority, and service-domain requirements.

------------------------------------------------------------------------

## 17. Required vs Supplementary Demonstration Content

### Required

Canonical acceptance requires:

-   economic scenario framing;
-   DP-1 through DP-5;
-   Actions 1 through 4;
-   authoritative state observability;
-   exact Beneficiary delivery;
-   explicit A3 backing rejection;
-   end-to-end execution from one deterministic pre-state.

### Supplementary

The following MAY be shown if useful and time permits:

-   optional post-fulfillment ordinary use;
-   transaction hashes;
-   PoolId;
-   raw `sqrtPriceX96`;
-   raw active liquidity;
-   exact current tick;
-   exerciser input debt;
-   `maxInput`;
-   gas usage;
-   hook callback details;
-   contract addresses;
-   public test-L2 deployment.

Supplementary evidence SHALL NOT be necessary for canonical demo
acceptance.

------------------------------------------------------------------------

## 18. Relationship to Testing

The canonical demo scenario SHOULD be reused as an end-to-end acceptance
fixture for continuity between verification and presentation.

General protocol verification remains governed by the frozen
`testing-strategy.md` and is not redefined by this artifact.

Concrete fixture construction, test organization, and implementation
mapping belong to the Implementation Plan.

------------------------------------------------------------------------

## 19. Submission Documentation Handoff

The short economic framing defined in this artifact SHALL inform the
live demonstration.

The richer judge-facing explanation of the economic coordination
problem, Standby's solution, architecture, demo flow, and canonical
documentation SHALL later be synthesized into the project `README.md`
during ETHGlobal Demo / Submission Preparation.

The README is the intended public entry point into the deeper canonical
documentation.

This artifact SHALL NOT duplicate the full economic derivation already
owned by the frozen canonical package.

------------------------------------------------------------------------

## 20. Demo Completion Condition

The canonical Standby demonstration is successful when a judge can
directly observe that:

> a 50,000 MockUSDC future execution commitment was admitted against
> shared Uniswap liquidity without reserving that liquidity; ordinary
> use of compatible capacity remained possible; an ordinary transition
> that would have destroyed required backing was prevented; and the
> admitted commitment was subsequently fulfilled through actual AMM
> execution delivering exactly 50,000 MockUSDC to the Beneficiary.

That observable result constitutes the minimum deterministic proof of
DEMO-CLAIM-1.

------------------------------------------------------------------------

## 21. Artifact Status

`demo-spec.md` has passed:

-   whole-demo completeness/adversarial gate;
-   whole-document structural and semantic-completeness gate;
-   upstream-fidelity gate;
-   artifact-fidelity gate;
-   final post-correction consistency review.

**Status: FINAL PASS / FROZEN.**

The next roadmap step is **Implementation Plan**.
