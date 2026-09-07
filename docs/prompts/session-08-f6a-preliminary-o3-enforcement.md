# Standby — Session 08 Claude Code Implementation Prompt

**Project:** Standby
**Session:** 08
**Implementation Slice:** F6A — Preliminary O3 Enforcement with O = 0
**Status at session start:** F0–F5 complete; G0–G5 closed; F6A authorized for implementation; F7+ not authorized
**Primary objective:** Activate and verify the minimum real ordinary-O3 enforcement perimeter using the existing F5 authoritative derivation kernel while authentic reachable Aggregate Capacity Obligation remains zero.

---

# Operating-Rule Ownership

This session prompt is intentionally limited to **slice-specific F6A content**.

Permanent behavior is inherited by reference:

> **`CLAUDE.md` owns permanent operating behavior.**

> **`.claude/rules/*` owns permanent Solidity/testing conventions.**

> **Session prompts own only slice-specific objective, scope, requirements, prohibitions, file boundaries, gate evidence, and completion boundary.**

Therefore:

- follow `CLAUDE.md` for permanent repository operation, Git discipline, documentation discipline, prompt auditing, dependency discipline, gate authority, and completion-reporting behavior;
- follow `.claude/rules/*` for permanent Solidity and testing conventions;
- if this prompt appears to restate or conflict with a permanent rule, the permanent owner governs unless this prompt explicitly specializes that rule for F6A;
- do not infer a new permanent convention from an F6A-specific instruction.

This prompt intentionally specifies only what is materially different for **F6A — Preliminary O3 Enforcement with O = 0**.

---

# 1. Session Objective

Implement **F6A — Preliminary O3 Enforcement with O = 0**.

The purpose of this slice is to make ordinary backing-affecting shared-resource transitions authoritative only when they satisfy the already-defined Standby trust, eligibility, service-domain, topology, and prospective-backing conditions.

The exact objective is:

> **Activate the minimum ordinary O3 enforcement paths necessary to prove that backing-affecting shared-resource transitions are admitted or rejected using authoritative F5 prospective derivations, while Aggregate Capacity Obligation remains zero because commitment admission has not yet been implemented.**

The target outcome is:

```text
real callback enforcement
+
trusted-periphery authentication
+
transition-specific actor/eligibility enforcement
+
service-domain/topology enforcement
+
F5 prospective derivation consumption
+
real positive/negative PoolManager transition evidence
```

while:

```text
authentic reachable O = 0
```

because F7 commitment admission does not yet exist.

Do **not** implement downstream behavior in this session.

---

# 2. Current Validated State

The implementation ladder at the start of Session 08 is:

```text
F0   v4 Infrastructure / Deployment Foundation              COMPLETE — G0 CLOSED
F1   Deterministic Economic Fixture                         COMPLETE — G1 CLOSED
F2   EligibilityRegistry                                    COMPLETE — G2 CLOSED
F3   StandbyHook Trust + PES Configuration                  COMPLETE — G3 CLOSED
F4   Commitment Storage / Bounded Enforcement References    COMPLETE — G4 CLOSED
F5   Authoritative Derivation Kernel                        COMPLETE — G5 CLOSED

F6A  Preliminary O3 Enforcement with O = 0                  THIS SESSION

F7   O1 Commitment Admission                                NOT AUTHORIZED
F6B  O3 with authentic O > 0                                NOT AUTHORIZED
F8A  O2 Authorization / Hook-owned causal context           NOT AUTHORIZED
F8B  O2 exact-output execution / execution evidence         NOT AUTHORIZED
F8C  O2 authoritative settlement / Beneficiary delivery     NOT AUTHORIZED
F8D  O2 causal finalization / Remaining reduction           NOT AUTHORIZED
GI   Full Stateful Invariant Gate                           NOT AUTHORIZED
F9   Canonical Acceptance                                   NOT AUTHORIZED
F10  Demo Instrumentation                                   NOT AUTHORIZED
F9T  Public testnet / production-periphery evidence          OFF CRITICAL PATH
```

A downstream responsibility is not available merely because implementing it would be convenient.

If F6A appears to require a semantic change to an already-verified upstream responsibility, stop and report the contradiction rather than silently redesigning Standby.

---

# 3. F6A Source Boundary

Follow the permanent repository-reading and operating behavior defined by `CLAUDE.md`.

For this slice, materially relevant sources include:

```text
docs/project-status.md
docs/implementation-plan.md
docs/uniswap-v4-realization.md
docs/spec.md
docs/state-machine.md
docs/invariants.md
docs/testing-strategy.md
docs/architecture.md

src/StandbyHook.sol
src/EligibilityRegistry.sol
src/interfaces/IEligibilityRegistry.sol
existing F5 derivation libraries
existing activated-service/shared fixtures
```

Also consult the existing F3/F4/F5 tests and harnesses as needed to understand verified upstream behavior.

Consult additional repository files only as required to implement or verify F6A within the authorized boundary.

Do not treat this source list as a replacement for the permanent authority hierarchy in `CLAUDE.md`.

---

# 4. Existing Upstream Responsibilities F6A Must Preserve

## 4.1 F3 — Trust and PES configuration

One StandbyHook instance realizes:

```text
one Hook
→ one configured PES
→ one PoolId
```

Lifecycle:

```text
UNCONFIGURED → ACTIVATED
```

Activation already fixes the authoritative basis including:

- PoolKey / PoolId;
- EligibilityRegistry;
- service-domain boundaries;
- protected direction;
- trusted ordinary-swap periphery;
- trusted liquidity periphery;
- designated ExerciseRouter;
- commitment-establishment authority.

The Hook trusts exactly one immutable PoolManager.

Preserve these distinct identities:

```text
Hook msg.sender
    =
PoolManager

callback sender
    =
periphery / locker

economic actor
    =
authenticated originating user exposed by a trusted periphery
```

Do not collapse them.

---

## 4.2 F4 — Commitment storage

Persistent commitment state and bounded references already exist.

F6A does not create commitments.

Because F7 does not yet exist, no authentic binding commitment can currently be admitted.

Therefore every reachable production state during F6A has:

```text
Aggregate Capacity Obligation O = 0
```

This is a **reachable-state consequence**, not an F6A-specific constant.

Do not hard-code `O = 0`.

Production O3 enforcement must still obtain authoritative current `O` through the existing F5 Aggregate Capacity Obligation derivation.

---

## 4.3 F5 — Authoritative derivation kernel

F5 is complete and G5 is closed.

Production authoritative derivations already exist for:

```text
temporal commitment validity
temporal exercise qualification
permanent non-binding classification
per-commitment Capacity Obligation
Aggregate Capacity Obligation O
current Supporting Capacity S
service-domain geometry
topology classification
prospective swap state
prospective swap Supporting Capacity S'
prospective liquidity-removal state
prospective liquidity-removal Supporting Capacity S'
prospective traversal demand
```

F5 has already established prospective-state equivalence against real PoolManager execution for the supported realization.

Use this ownership boundary:

> **F5 derives what the authoritative economic facts are. F6A decides whether an ordinary backing-affecting transition may become authoritative using those facts.**

F6A must consume F5.

F6A must not reproduce:

```text
Supporting Capacity formulas
Aggregate Obligation scanning/formulas
prospective swap derivation
prospective liquidity-removal derivation
service-domain economic interpretation
```

Do not create shortcuts such as:

```text
S' = S - amount
```

or any other F6A-specific economic approximation.

---

# 5. Exact F6A Responsibility

F6A owns the authoritative enforcement consequence for ordinary O3 transitions.

Its responsibility is:

```text
1. authenticate supported callback provenance
2. authenticate configured periphery where required
3. recover originating economic actor where an eligibility predicate consumes it
4. apply transition-specific eligibility
5. classify current swaps as ordinary O3
6. consume existing F5 prospective-state derivation
7. enforce applicable service-domain validity
8. enforce applicable topology validity
9. compare prospective S' against authoritative current O where backing may decrease
10. permit or reject the real PoolManager transition
```

F6A does **not** own:

```text
O1 commitment admission
new commitment creation
authentic positive O
O2 exercise authorization
O2 causal context
O2 exact-output orchestration
O2 execution evidence
Beneficiary delivery
fulfillment
Remaining Entitlement reduction
generic admin release
pause/deactivation
```

Use this boundary:

> **F6A makes authoritative the Hook's admission/rejection of ordinary O3 PoolManager transitions based on authenticated transition provenance, transition-specific eligibility, service-domain/topology validity, and the existing F5 authoritative prospective derivation kernel, while authentic reachable Aggregate Capacity Obligation remains zero.**

---

# 6. Domain Validity and Backing Sufficiency Are Distinct

The eventual O3 backing relationship is:

```text
proposed transition
→ prospective authoritative state
→ prospective Supporting Capacity S'
→ authoritative current Aggregate Capacity Obligation O
→ require S' >= O
```

During F6A:

```text
O = 0
```

because no authentic commitments can yet exist.

That does **not** mean every transition is valid.

Preserve the distinction:

```text
transition admissibility
    =
authenticated/supported transition path
+
transition-specific eligibility where applicable
+
valid realization/service-domain/topology state
+
prospective backing sufficiency where applicable
```

`S' >= O` must never replace:

- service-domain validity;
- realization constraints;
- topology validity;
- trusted-periphery authentication;
- transition-specific eligibility.

An invalid-domain transition must reject even when:

```text
O = 0
```

and even if a numeric comparison would otherwise satisfy:

```text
S' >= 0
```

Preserve the F5 distinction between:

```text
valid state with S == 0
```

and:

```text
state for which authoritative Supporting Capacity is not validly derivable
because the realization/domain basis is invalid
```

Do not coerce invalid derivation into a plausible numeric capacity.

---

# 7. Callback Responsibilities

The Hook enables:

```text
beforeSwap
afterSwap
beforeAddLiquidity
beforeRemoveLiquidity
```

F6A is the first slice in which these callbacks begin real O3 enforcement.

---

# 8. `beforeSwap`

`beforeSwap` is the ordinary O3 swap-enforcement callback.

The semantic decision sequence is:

```text
beforeSwap
│
├─ authenticate msg.sender == immutable PoolManager
├─ require activated PES
├─ authenticate PoolKey / PoolId as configured service
├─ authenticate callback sender == configured trusted swap periphery
├─ recover originating economic actor from authenticated periphery
├─ require EligibilityRegistry.canSwap(actor)
├─ classify swap as ordinary O3
│    because no authoritative O2 context exists in F6A
├─ derive prospective swap state through F5
├─ enforce applicable service-domain validity
├─ for backing-affecting protected-direction behavior:
│      derive S' through F5
│      derive current O through F5
│      require S' >= O
└─ permit if all required predicates pass
```

Do not classify O2 by ExerciseRouter identity.

At F6A:

```text
no authoritative O2 causal context exists
→ all reachable swaps are ordinary O3
```

---

# 9. Protected and Opposite Swap Directions

## 9.1 Protected direction

Protected-direction ordinary swaps may reduce Supporting Capacity.

They therefore consume:

```text
F5 prospective swap state
→ F5 prospective S'
→ F5 current O
→ require S' >= O
```

During F6A, authoritative `O` will derive to zero.

Do not special-case that fact in production logic.

---

## 9.2 Opposite direction

Opposite-direction swaps may increase Supporting Capacity.

Do not manufacture redundant backing arithmetic merely for symmetry.

They remain subject to:

```text
PoolManager authenticity
configured trusted swap periphery
actor attribution
canSwap(actor)
supported realization
service-domain validity
```

The gate must specifically prove that opposite-direction service-domain enforcement remains active while `O = 0`.

---

# 10. `beforeAddLiquidity`

Liquidity addition has its own authorization semantics.

The decision sequence is:

```text
beforeAddLiquidity
│
├─ authenticate PoolManager
├─ require activated configured service
├─ authenticate PoolKey / PoolId
├─ authenticate configured trusted liquidity periphery
├─ recover originating economic actor
├─ require EligibilityRegistry.canProvideLiquidity(actor)
├─ consume existing topology/domain classification
├─ reject prohibited topology
└─ permit valid addition
```

The existing topology rule remains authoritative:

> Liquidity introduction may not introduce an initialized liquidity boundary strictly inside the configured service domain.

Do not add a redundant prospective-liquidity-add backing formula merely because addition may increase Supporting Capacity.

---

# 11. `beforeRemoveLiquidity`

Removal intentionally differs from addition.

The decision sequence is:

```text
beforeRemoveLiquidity
│
├─ authenticate PoolManager
├─ require activated configured service
├─ authenticate PoolKey / PoolId
├─ authenticate configured trusted liquidity periphery
├─ DO NOT require continuing canProvideLiquidity eligibility
├─ consume existing F5 prospective-removal derivation
├─ enforce applicable service-domain validity
├─ derive prospective S' through F5
├─ derive authoritative current O through F5
├─ require S' >= O
└─ permit or reject
```

Loss of LP eligibility must not trap capital.

Therefore:

```text
loss of canProvideLiquidity
≠
loss of ability to exit
```

For F6A, actor attribution is not an economic authorization dependency for removal because no removal eligibility predicate consumes that actor.

The trusted liquidity execution path must still be authenticated.

Do not recover an originator merely to invent an authorization predicate that does not exist.

---

# 12. `afterSwap`

Because `afterSwap` is enabled, every successfully accepted swap invokes it.

Therefore F6A cannot leave it unconditionally reverting; otherwise positively permitted ordinary swaps could never complete.

However, F6A must not give `afterSwap` the later F8B execution-evidence responsibility.

Use this boundary:

```text
afterSwap in F6A
    =
economically inert callback completion plumbing for ordinary O3
```

It is not:

```text
O2 execution proof
fulfillment proof
settlement proof
Remaining Entitlement mutation
persistent economic state
```

Retain the immutable PoolManager trust boundary.

Do not introduce any equivalent of:

```text
AUTHORIZED → EXECUTED
```

F8B owns that later responsibility.

---

# 13. Actor-Aware Periphery

F6A requires a minimal actor-aware Anvil/demo periphery.

Implement:

```text
src/demo/ActorAwareTestRouter.sol
```

This component is **not a Standby economic authority**.

Its sole authoritative contribution is:

> **For the currently executing routed action, the direct originating caller was address X.**

It must not decide or attest:

```text
eligibility
PoolId validity
Supporting Capacity
Aggregate Obligation
service-domain validity
topology validity
O1/O2/O3 classification
transition safety
fulfillment
```

Those remain owned by their existing authoritative components.

---

# 14. Minimum Actor-Attribution Interface

A minimal interface is preferred, conceptually:

```solidity
interface IActorAwarePeriphery {
    function msgSender() external view returns (address);
}
```

Exact naming is implementation discretion.

Do not generalize this into a forwarding framework.

The Hook must always follow:

```text
authenticate exact configured periphery
→ only then query its originator
```

Never:

```text
query arbitrary callback sender
→ obtain actor
→ then decide whether sender was trusted
```

Authentication must precede interpretation.

---

# 15. Actor Origin

The router binds the direct caller at the user-facing routed entry point:

```text
actor = msg.sender
```

Do not use:

```text
tx.origin
```

Do not accept authoritative actor identity from:

```text
hookData
arbitrary calldata actor field
arbitrary forwarded address
```

---

# 16. Transaction-Local Attribution

Originator attribution is execution context, not protocol history.

Preferred conceptual lifecycle:

```text
EMPTY
  ↓ routed action begins
ACTIVE(actor)
  ↓ PoolManager execution / Hook callbacks
EMPTY
```

Use transaction-local/transient state where compatible with the pinned environment.

Do not leave reusable actor identity across transactions.

If the pinned environment makes transient storage unsuitable and ordinary storage is genuinely required, preserve transaction-local behavior, clear it safely, and record the implementation reason.

That choice is engineering implementation detail; the semantic requirement is that actor attribution cannot survive as reusable identity state.

---

# 17. Nested Actor Context

Reject nested originator contexts.

Required state model:

```text
EMPTY → ACTIVE(actor) → EMPTY
```

Forbidden:

```text
ACTIVE → ACTIVE(newActor)
```

No actor stack or generalized nested-forwarding semantics are required.

Do not add them.

---

# 18. Inactive Actor Context

`msgSender()` must fail closed when there is no active routed actor context.

Do not return:

```text
msg.sender
```

or another plausible fallback.

Inactive context does not establish an economic actor.

---

# 19. Distinct Swap and Liquidity Periphery Roles

F3 stores distinct configured roles:

```text
trusted ordinary-swap periphery
trusted liquidity periphery
```

Preserve this distinction.

Callbacks remain:

```text
beforeSwap
→ sender == trustedSwapPeriphery
```

and:

```text
beforeAddLiquidity
beforeRemoveLiquidity
→ sender == trustedLiquidityPeriphery
```

The same router implementation may support both action families.

For G6A evidence, prefer two deployed instances of the same bytecode:

```text
swapRouter
liquidityRouter
```

This permits direct proof that:

```text
swapRouter cannot authorize liquidity callback
liquidityRouter cannot authorize swap callback
```

Do not create separate implementations merely to prove the distinction.

---

# 20. Core Harness Versus Actor-Aware Evidence

Preserve two evidence paths.

## Core execution path

Existing real PoolManager infrastructure such as:

```text
PoolSwapTest
PoolModifyLiquidityTest
```

may continue proving:

```text
v4 execution
callback behavior
economic math
prospective-state equivalence
```

It does **not** prove user-level actor attribution.

## Actor-aware path

Use:

```text
real PoolManager
ActorAwareTestRouter
StandbyHook
EligibilityRegistry
```

to prove:

```text
trusted-periphery attribution
actual originating-user recovery
canSwap(actor)
canProvideLiquidity(actor)
permissioned production transition behavior
```

Do not substitute official core-router evidence for actor-attribution evidence.

---

# 21. Shared F6A Fixture

Create or complete:

```text
test/shared/BaseActorAwareStandbyTest.t.sol
```

It may construct legitimate F6A state using real paths, including:

```text
real PoolManager
canonical StandbyHook
EligibilityRegistry
activated PES
ActorAware swap router
ActorAware liquidity router
canonical currencies
canonical domain
funded actors
eligibility configuration
real canonical liquidity
```

It must not:

```text
seed S
seed O
mutate Hook economic storage
manufacture PoolManager state
inject prospective state
fake actor context
pre-authorize O3 transitions
```

At canonical F6A bootstrap:

```text
S = canonical initial Supporting Capacity
O = 0
no commitment
```

The state must arise through legitimate construction paths.

---

# 22. Required Periphery Evidence

Create:

```text
test/periphery/ActorAttribution.t.sol
```

At minimum prove:

## 22.1 Valid attribution

```text
eligible Alice
→ trusted swap router
→ router binds Alice
→ PoolManager
→ Hook authenticates router
→ Hook recovers Alice
```

Equivalent actor attribution must be demonstrated for liquidity addition.

## 22.2 Untrusted attestor rejection

An untrusted contract exposing an actor-like interface must not establish economic identity.

Example:

```text
fakeRouter claims actor = eligibleAlice
→ callback sender is not configured periphery
→ reject before claimed actor becomes authoritative
```

## 22.3 Forged `hookData`

Example:

```text
actual actor = ineligible Alice
hookData contains eligible Bob
```

Expected:

```text
Alice remains authoritative actor
→ canSwap(Alice) fails
→ transition rejects
```

## 22.4 Periphery-role crossing

Prove:

```text
swapRouter used for liquidity path
→ reject

liquidityRouter used for swap path
→ reject
```

## 22.5 Inactive actor context

A trusted router with no active routed action must not expose a usable actor.

## 22.6 Nested actor context

A second routed action while originator context is ACTIVE must reject.

---

# 23. Required Swap Integration Evidence

Create:

```text
test/integration/O3SwapEnforcement.t.sol
```

Use the real:

```text
ActorAwareTestRouter
→ PoolManager
→ StandbyHook
```

path where actor identity is material.

At minimum prove:

## 23.1 Eligible protected-direction swap succeeds

From authentic F6A state:

```text
aggregateObligation() = 0
```

execute a valid protected-direction ordinary swap.

Prove:

```text
transaction succeeds
PoolManager authoritative state changes
F5 prospective derivation is the production enforcement path
authoritative post-state S corresponds to actual post-transition PoolManager state
aggregateObligation() remains authentically derived as zero
no commitment state changes
```

The swap must complete through `afterSwap`.

## 23.2 Ineligible trader rejects

For an otherwise valid transition:

```text
canSwap(actor) = false
→ reject
```

After revert, authoritative PoolManager state must remain unchanged.

The rejection should be attributable to Standby permissioning, not unrelated allowance/balance/slippage failure.

## 23.3 Valid opposite-direction swap succeeds

Prove direction classification permits valid opposite-direction ordinary activity.

## 23.4 Opposite-direction domain violation rejects at O = 0

Prove:

```text
O = 0
```

does not disable service-domain enforcement.

## 23.5 Untrusted actor path cannot authorize

An untrusted router attempting the real PoolManager path must fail before its claimed actor can become authoritative.

## 23.6 `afterSwap` remains economically inert

After a successful ordinary O3 swap, prove F6A did not create:

```text
commitment mutation
Remaining mutation
O2 causal state
O2 execution-evidence state
fulfillment state
```

---

# 24. Required Liquidity Integration Evidence

Create:

```text
test/integration/O3LiquidityEnforcement.t.sol
```

At minimum prove:

## 24.1 Eligible topology-valid addition succeeds

```text
eligible LP
+ trusted liquidity router
+ valid topology
→ succeeds
```

## 24.2 Ineligible addition rejects

```text
canProvideLiquidity(actor) = false
→ valid addition rejects
```

## 24.3 Topology-invalid addition rejects

Even where the actor is eligible:

```text
prohibited interior initialized boundary
→ reject
```

## 24.4 Valid removal succeeds

A valid removal through the trusted liquidity perimeter must positively execute.

## 24.5 Eligibility-revoked LP may still exit

Mandatory sequence:

```text
Alice eligible
→ Alice adds liquidity

registry revokes Alice canProvideLiquidity

Alice performs otherwise-safe removal
→ removal succeeds
```

This is the behavioral proof that eligibility loss does not trap LP capital.

## 24.6 Removal consumes F5 prospective derivation

Where practical, prove:

```text
F5 predicted prospective removal state / S'
```

agrees with:

```text
actual PoolManager post-removal state
→ authoritative post-state S
```

Do not implement an independent production formula.

---

# 25. Required Behavioral Fuzz Evidence

Create:

```text
test/fuzz/O3SwapFuzz.t.sol
test/fuzz/O3LiquidityFuzz.t.sol
```

Behavioral transition fuzz must use real production paths.

Do not close G6A behavioral claims using `StandbyHookHarness`.

---

# 26. O3 Swap Fuzz

Vary mechanically valid combinations including:

```text
actor eligibility
swap direction
amount
supported ordinary exact-input/exact-output forms
price limit
arbitrary/forged hookData
```

Properties should include:

```text
ineligible actor
→ cannot produce successful authoritative ordinary swap
```

```text
wrong periphery
→ cannot produce successful authoritative ordinary swap
```

```text
accepted transition
→ actual post-state agrees with production F5 prospective derivation
```

```text
domain-invalid transition
→ cannot become authoritative merely because O = 0
```

Do not fabricate positive O.

---

# 27. O3 Liquidity Fuzz

Vary:

```text
add/remove classification
actor eligibility
tickLower
tickUpper
bounded liquidity delta
eligibility before/after addition
```

Properties should include:

```text
ineligible addition
→ cannot become authoritative
```

```text
invalid topology addition
→ cannot become authoritative
```

```text
safe removal
→ does not depend on current canProvideLiquidity status
```

```text
accepted removal
→ actual PoolManager state agrees with production F5 prospective derivation
```

Do not fabricate commitments or positive O.

---

# 28. Harness Boundary

`StandbyHookHarness` may remain available for narrowly isolated verification.

It may expose internal production logic or narrowly seed authoritative input facts for unit/predicate verification.

Harness-only evidence is not valid for:

```text
trusted-periphery authenticity
actor attribution
real callback enforcement
successful production swap
successful liquidity addition
successful liquidity removal
rejected transition atomicity
integration correctness
G6A periphery correctness
```

When the property being proved is a real authoritative transition, use the real production path.

---

# 29. Authorized Production File Scope

F6A is authorized to modify:

```text
src/StandbyHook.sol
src/demo/ActorAwareTestRouter.sol
```

A minimal actor-attribution interface is also authorized if useful, for example:

```text
src/interfaces/IActorAwarePeriphery.sol
```

The interface must remain limited to provenance/transport responsibility.

Existing upstream components may be consumed but should not have their semantic ownership redesigned merely for F6A convenience.

Potential consumed dependencies include:

```text
src/EligibilityRegistry.sol
src/interfaces/IEligibilityRegistry.sol
src/libraries/StandbyMath.sol
src/libraries/ServiceDomain.sol
src/libraries/CommitmentRefs.sol
```

If a semantic change to F2/F3/F4/F5 appears necessary:

> **stop and report the contradiction before making that change.**

Narrow behavior-preserving refactoring inside the authorized dependency footprint is acceptable only when genuinely necessary.

---

# 30. Authorized Test File Scope

F6A may create or modify:

```text
test/shared/BaseActorAwareStandbyTest.t.sol

test/periphery/ActorAttribution.t.sol

test/integration/O3SwapEnforcement.t.sol
test/integration/O3LiquidityEnforcement.t.sol

test/fuzz/O3SwapFuzz.t.sol
test/fuzz/O3LiquidityFuzz.t.sol
```

Narrow changes to existing shared activated fixtures are allowed if required for composition.

Do not create downstream F7/F6B/F8 tests merely as placeholders.

Do not implement:

```text
O1Admission.t.sol
positive-O O3 gate tests
O2Authorization*.t.sol
O2Execution*.t.sol
O2Finalization*.t.sol
```

as part of this slice.

---

# 31. Explicit Forbidden Shortcuts

Do **not**:

```text
hard-code O = 0 into O3 enforcement
add fake/settable Aggregate Obligation
seed commitments for F6A
fabricate positive O
duplicate F5 Supporting Capacity logic
duplicate F5 prospective-swap logic
duplicate F5 prospective-removal logic
duplicate F5 Aggregate Obligation logic
use currentS - amount as backing arithmetic
derive actor from hookData
derive actor from arbitrary calldata
use tx.origin
trust msgSender() before authenticating configured periphery
accept an untrusted actor-aware router as authoritative
require continuing canProvideLiquidity for removal
weaken topology checks because liquidity addition increases liquidity
weaken service-domain enforcement because O = 0
classify O2 from ExerciseRouter identity
introduce O2 causal context
implement O2 execution evidence
use afterSwap as fulfillment/execution proof
implement Beneficiary delivery
reduce Remaining Entitlement
create commitments
implement O1 admission
use StandbyHookHarness as production-transition G6A evidence
introduce demo-only economic backdoors
silently redesign verified upstream semantics
```

---

# 32. G6A Traceability Matrix

G6A requires evidence for all twelve obligations.

| G6A requirement                                                  | Primary evidence                                              |
| ---------------------------------------------------------------- | ------------------------------------------------------------- |
| 1. Only immutable PoolManager callbacks are authoritative        | callback provenance + adversarial integration                 |
| 2. Only trusted periphery can supply authenticated actor         | `ActorAttribution.t.sol`                                      |
| 3. Forged `hookData` cannot establish actor                      | periphery + swap integration                                  |
| 4. Ordinary swap requires `canSwap`                              | swap integration + swap fuzz                                  |
| 5. Liquidity addition requires `canProvideLiquidity`             | liquidity integration + liquidity fuzz                        |
| 6. Removal does not require continuing eligibility               | revoke-after-add integration + fuzz                           |
| 7. Direction classification is correct                           | swap integration + fuzz                                       |
| 8. Opposite-direction domain enforcement remains active at O = 0 | swap integration + fuzz                                       |
| 9. Liquidity topology enforcement remains active at O = 0        | liquidity integration + fuzz                                  |
| 10. F5 prospective derivations are consumed                      | structural review + real predicted/actual transition evidence |
| 11. Valid transitions are positively permitted                   | swap + liquidity integration                                  |
| 12. Integration and fuzz evidence passes                         | focused suites + permanent full-regression requirements       |

Negative revert tests alone are insufficient.

Where a boundary permits valid behavior, positively prove the permitted side.

---

# 33. Particularly Important F6A Evidence Path

Preserve explicit evidence of this complete real path:

```text
eligible ordinary actor
→ trusted swap router
→ router binds transaction-local originator
→ PoolManager invokes StandbyHook.beforeSwap
→ Hook authenticates PoolManager
→ Hook authenticates configured swap periphery
→ Hook recovers actor
→ Hook checks canSwap(actor)
→ Hook consumes F5 prospective-swap derivation
→ Hook consumes F5 aggregateObligation()
→ authentic O derives to zero
→ Hook evaluates S' >= O
→ service-domain-valid transition passes
→ PoolManager executes swap
→ afterSwap returns without creating F8 semantics
→ actual post-state agrees with F5-derived expectation
```

This path is especially important evidence that:

> **F5 produces authoritative economic facts; F6A consumes those facts to determine whether a real transition may proceed.**

---

# 34. F6A Verification Execution Boundary

Use the permanent verification commands, profiles, formatting conventions, fuzz configuration, and test-running behavior defined by `.claude/rules/*` and `CLAUDE.md`.

This prompt adds only the **F6A-specific evidence requirement**:

```text
ActorAttribution periphery evidence
O3 swap integration evidence
O3 liquidity integration evidence
O3 swap behavioral fuzz evidence
O3 liquidity behavioral fuzz evidence
F5-derivation-consumption structural evidence
positive permission of valid transitions
negative rejection of forbidden transitions
full regression evidence required by permanent testing rules
```

The completion evidence must make it possible to independently assess G6A-1 through G6A-12 without introducing a new session-specific testing convention.

---

# 35. Production-Derivation Singularity Review

Before proposing G6A PASS, inspect the F6A production diff.

Confirm that O3 enforcement consumes the existing authoritative F5 derivations.

Specifically verify:

```text
beforeSwap
→ existing F5 prospective-swap derivation

backing decision
→ existing F5 Aggregate Obligation derivation

beforeRemoveLiquidity
→ existing F5 prospective-removal derivation
```

Search production code for prohibited duplication.

There must be no new production formula equivalent to:

```text
Supporting Capacity S
prospective Supporting Capacity S'
Aggregate Capacity Obligation O
prospective swap state
prospective liquidity-removal state
```

Intentional verification-only comparison logic remains separate from production authority.

---

# 36. Semantic Minimality / Downstream Non-Contamination Review

Before proposing G6A PASS, inspect the diff and prove F6A did not introduce:

```text
O1 commitment establishment
new commitment creation
authentic positive O
O2 exercise authorization
O2 causal state
O2 execution evidence
O2 Beneficiary settlement/delivery
fulfillment
Remaining Entitlement mutation
generic administrative release
pause/deactivation
new economically authoritative derived storage
```

It is acceptable for F6A to activate ordinary O3 callbacks and actor-attribution plumbing needed for this slice.

It is not acceptable to pull downstream semantics forward.

---

# 37. F6A Implementation Questions That Are Engineering Discretion

You may exercise ordinary engineering discretion over:

```text
internal function names
exact interface naming for the minimal actor-aware periphery
narrow helper organization
transient-storage key organization
small structs required to avoid stack complexity
test helper naming
test-file internal organization
gas-neutral refactoring inside the authorized footprint
```

provided those choices preserve the semantic ownership above.

You do **not** have discretion to redefine:

```text
who the authoritative callback caller is
which configured periphery is trusted for each callback family
whether hookData establishes actor identity
whether tx.origin establishes actor identity
whether ordinary swaps require canSwap
whether liquidity additions require canProvideLiquidity
whether removal requires continuing canProvideLiquidity
whether service-domain validity disappears when O = 0
whether topology validity disappears when O = 0
whether O may be hard-coded to zero
whether F5 prospective derivations may be duplicated
whether ExerciseRouter identity alone classifies O2
whether afterSwap creates O2 execution evidence in F6A
```

If an implementation decision reaches one of these semantic questions, consult upstream authority rather than inventing a local interpretation.

---

# 38. F6A Documentation Mutation Boundary

Do not edit frozen normative artifacts merely to make F6A implementation convenient.

Do not update:

```text
docs/project-status.md
```

to claim F6A complete or G6A closed during this implementation session.

Permanent documentation/setup behavior is governed by `CLAUDE.md`.

If implementation exposes a genuine contradiction requiring an upstream artifact correction, report it rather than silently changing frozen semantics.

---

# 39. Session 08 Evidence Artifact Boundary

The Session 08 implementation record is:

```text
docs/prompts/session-08-log.md
```

Create or update that artifact as required by the permanent logging and prompt-audit behavior in `CLAUDE.md`.

This prompt does **not** redefine:

```text
log format
prompt-audit mechanics
repository documentation behavior
permanent completion-reporting behavior
```

The slice-specific requirement is only that the Session 08 record contain enough F6A implementation and verification evidence for independent G6A review, including any material:

```text
implementation decision
file change
callback behavior activated
actor-attribution mechanism
trusted-periphery behavior
eligibility behavior
liquidity add/removal distinction
F5 derivation consumption
dependency/API assumption
test evidence
failure/correction
deviation
unresolved ambiguity
```

relevant to F6A.

---

# 40. Repository Operation

Follow the permanent repository and Git operating behavior in `CLAUDE.md`.

This prompt defines no F6A-specific Git convention.

The slice-specific completion boundary is:

```text
produce reviewable F6A implementation
+
required G6A evidence
+
Session 08 implementation record
→ stop before F7/F6B/F8
```

Claude's proposed gate assessment is not canonical gate closure.

---

# 41. Explicit Non-Goals

Do not implement any of the following during Session 08:

```text
F7 O1 commitment admission
F6B authentic positive-obligation O3 proof
F8A O2 authorization
F8B O2 execution evidence
F8C Beneficiary settlement/delivery
F8D causal fulfillment / Remaining mutation
full invariant handler campaign
canonical acceptance flow
demo frontend
public-testnet deployment
```

Do not create fake positive obligations merely to demonstrate the eventual backing rule.

F6A intentionally proves the ordinary transition perimeter **before authentic obligations exist**.

---

# 42. F6A Completion State

At successful F6A implementation, the following should be live:

```text
real ordinary-O3 callback enforcement
trusted-periphery authentication
ordinary trader actor attribution
ordinary trader canSwap enforcement
liquidity-add actor attribution
liquidity-add canProvideLiquidity enforcement
eligibility-independent liquidity removal
service-domain enforcement
liquidity topology enforcement
F5 prospective derivation consumption
afterSwap ordinary-O3 completion plumbing
```

while the following remain absent:

```text
authentic commitment admission
authentic positive O
O1 transition
O2 authorization
O2 causal context
O2 execution evidence
Beneficiary delivery
fulfillment
Remaining Entitlement reduction
```

Stop at this boundary.

---

# 43. F6A Completion Evidence

Follow the permanent completion-reporting format in `CLAUDE.md`.

For this slice, the report/evidence must be sufficient to independently assess:

```text
G6A-1   immutable PoolManager callback authority
G6A-2   trusted-periphery actor attribution
G6A-3   forged hookData resistance
G6A-4   ordinary-swap canSwap enforcement
G6A-5   liquidity-add canProvideLiquidity enforcement
G6A-6   eligibility-independent removal
G6A-7   direction classification
G6A-8   opposite-direction domain enforcement at O = 0
G6A-9   topology enforcement at O = 0
G6A-10  F5 prospective derivation consumption
G6A-11  positive permission of valid transitions
G6A-12  integration + fuzz evidence
```

It must also identify:

```text
production files changed
test/evidence files changed
actor-attribution mechanism implemented
any material pinned-v4 API/dependency assumption
any deviation or unresolved ambiguity
whether F7/F6B/F8 behavior was avoided
```

Claude may state:

```text
G6A overall: PASS PROPOSED
```

only if all required evidence exists.

Claude must not mark G6A canonically closed.

Claude must not begin F7.

---

# 44. Final Session Constraint

The implementation must converge on this semantic result:

> **F6A makes ordinary shared-resource transitions authoritative only through the configured PoolManager and trusted transition perimeter, applies transition-specific eligibility without trapping liquidity-provider exits, preserves service-domain and topology validity independently of backing sufficiency, and consumes the already-verified F5 prospective derivation kernel to evaluate backing-affecting transitions. Aggregate Capacity Obligation remains authentically derived and happens to be zero only because F7 commitment admission does not yet exist. F6A introduces no O1 or O2 semantics, no duplicate economic derivation, and no positive-obligation claim.**

That is the F6A implementation target.

Do not advance beyond it during Session 08.

The output of this session is:

```text
F6A implementation
+
G6A review evidence
+
Session 08 Claude implementation record
```

It is **not** canonical G6A closure and does not authorize F7, F6B, or F8.
