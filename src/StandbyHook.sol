// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LiquidityMath} from "v4-core/libraries/LiquidityMath.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {ProtocolFeeLibrary} from "v4-core/libraries/ProtocolFeeLibrary.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/types/BeforeSwapDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {IActorAwarePeriphery} from "./interfaces/IActorAwarePeriphery.sol";
import {IEligibilityRegistry} from "./interfaces/IEligibilityRegistry.sol";
import {
    CommitmentRefs,
    EMPTY_REFERENCE,
    MAX_LIVE_COMMITMENTS as BOUNDED_REFERENCE_SLOTS
} from "./libraries/CommitmentRefs.sol";
import {ServiceDomain} from "./libraries/ServiceDomain.sol";
import {StandbyMath} from "./libraries/StandbyMath.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title StandbyHook
/// @notice The Standby Uniswap v4 Hook.
/// @dev At implementation slice F8B this contract owns the Hook-wide immutable trust basis, one one-shot
///      Protected Execution Service configuration, the authoritative commitment record store with its
///      bounded enforcement-reference index, the composition of the authoritative economic derivation
///      kernel, the admission or rejection of ordinary O3 backing-affecting pool transitions, the O1
///      admission that turns a proposed commitment into an authoritative binding one, the O2
///      authorization that binds one exercise attempt into a transaction-scoped causal context, and the
///      O2 classification and execution evidence that bind exactly one PoolManager swap to that context.
///
///      Authorization is not exercise. It executes no swap, settles no input, delivers nothing to the
///      Beneficiary, fulfils nothing, and reduces no Remaining Entitlement. What authorization establishes
///      is that exactly one commitment, one authenticated exerciser, one authoritative Beneficiary, one
///      service, one ExerciseRouter, and one quantity have been bound together by the Hook before any
///      protected execution could be attempted.
///
///      Execution evidence is not fulfillment either. `EXECUTED` says that the unique PoolManager swap
///      causally bound to the active authorization actually produced exactly the authorized protected
///      output `q` — and nothing beyond that. It does not say that the input debt has been paid, that the
///      exerciser's cost bound was honoured, that the Beneficiary received anything, that the commitment
///      was fulfilled, or that any Remaining Entitlement or Aggregate Capacity Obligation moved. No
///      production path at this slice reduces Remaining Entitlement, so no fulfillment can occur.
///
///      What separates a Standby exercise from an ordinary swap is therefore not who asked for it. It is
///      the conjunction of an existing Hook-owned authorization, the bound ExerciseRouter as the
///      PoolManager operation sender, the configured service pool, the protected direction, exact-output
///      mode, the exact authorized quantity, the configured qualification boundary — and then, separately
///      and afterwards, authoritative PoolManager evidence that the swap actually produced `q`. Router
///      identity alone, `hookData` alone, an authorization alone, a protected-direction swap alone, and a
///      `q`-shaped amount alone each classify nothing.
///
///      O1 admission is where Aggregate Capacity Obligation first becomes positive. Enforcement was never
///      told that: it obtains the obligation from the same derivation that reported zero while no
///      commitment could exist, so a positive obligation changes what that derivation returns and nothing
///      about how enforcement reads it.
///
///      The derivation kernel is composition, not a second economics. The Hook is where authoritative
///      inputs meet economic consequence: it reads PoolManager state, the immutable service basis, the
///      persisted commitment facts, the bounded references, and the current time, and passes them through
///      the pure kernel in `StandbyMath` and `ServiceDomain`. Every production consumer of an F5 quantity
///      — the read surface today, enforcement later — resolves through these same functions, so no
///      economic meaning is ever expressed twice in production. None of it is persisted: Supporting
///      Capacity, Capacity Obligation, validity, and every other derived classification are recomputed
///      from authoritative facts on each use.
///
///      Trust is separated by ownership scope, following `uniswap-v4-realization.md` RR-STATE-2 and
///      RR-STATE-3:
///
///      - PoolManager, configuration authority, the trusted ordinary-swap perimeter, and the trusted
///        liquidity perimeter are realization-wide immutable Hook dependencies. They are fixed at
///        deployment and are never duplicated into per-service state.
///      - The designated ExerciseRouter, the EligibilityRegistry, and the commitment-establishment
///        authority are per-service semantic facts, fixed once by activation.
///
///      The ordinary-swap perimeter and the liquidity perimeter are distinct roles and are held in
///      distinct immutables. A deployment may give one address both roles without collapsing their
///      meanings, exactly as the EligibilityRegistry keeps its three predicates distinct under one
///      administrator. Each enabled callback authenticates the perimeter its own transition family
///      designates, so a perimeter trusted for one family authorizes nothing in the other.
///
///      Three identities stay distinct in every callback and are never collapsed: the Hook's own
///      `msg.sender`, which must be the immutable PoolManager; the callback sender, which must be the
///      configured perimeter for that transition family; and the economic actor, which is the originating
///      user that perimeter authenticates. `hookData` and `tx.origin` establish neither of the last two.
contract StandbyHook is BaseHook {
    using CommitmentRefs for uint256[BOUNDED_REFERENCE_SLOTS];
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;
    using ProtocolFeeLibrary for uint16;
    using ProtocolFeeLibrary for uint24;
    using SafeCast for uint256;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The complete authoritative Protected Execution Service basis.
    /// @dev This is the minimum fact-complete basis required by `uniswap-v4-realization.md` §9.1. Every
    ///      field is either an economically meaningful fact that cannot be reconstructed from another
    ///      persisted fact, or the single service-existence fact required by RR-STATE-7.
    ///
    ///      Deliberately absent, because they are deterministically derivable from this basis and
    ///      persisting them would create a synchronization invariant with no authoritative owner: the
    ///      PoolId, the boundary square-root prices of `tickQ` and `tickO`, the numeric service-domain
    ///      minimum and maximum, the promised-result currency, and every dynamic economic quantity.
    /// @param poolKey The complete PoolKey basis. PoolId is not a reversible source for the pool facts
    ///        later derivation needs, so the key itself is persisted (RR-STATE-1).
    /// @param registry The per-service eligibility source. Membership stays externally mutable; the
    ///        reference itself cannot be replaced (RR-STATE-4).
    /// @param protectedZeroForOne The protected swap direction of the service.
    /// @param tickQ The protected execution-quality boundary, in the protected direction.
    /// @param tickO The opposite realization-domain boundary.
    /// @param configured The single service-existence fact. There is no separate active/paused state.
    /// @param exerciseRouter The designated O2 coordinator for this service (RR-STATE-3).
    /// @param establishmentAuthority The per-service commitment-establishment authority (RR-STATE-5).
    struct ProtectedExecutionService {
        PoolKey poolKey;
        IEligibilityRegistry registry;
        bool protectedZeroForOne;
        int24 tickQ;
        int24 tickO;
        bool configured;
        address exerciseRouter;
        address establishmentAuthority;
    }

    /// @notice The complete authoritative fact record of one historical commitment.
    /// @dev These are the frozen commitment facts of `uniswap-v4-realization.md` §10.1 and nothing else.
    ///      Every economically meaningful property of a commitment — validity, exercisability, binding
    ///      status, fulfillment, expiry, reclaimability, its Capacity Obligation — is deterministically
    ///      derivable from these facts plus the admitted service semantics, so none of them is persisted
    ///      here. Persisting a classification alongside the facts it comes from would create a
    ///      synchronization invariant with no authoritative owner.
    ///
    ///      Immutable Protected Execution Service semantics are referenced, not copied (RR-O1-2, RR-O1-3):
    ///      `serviceId` is the whole admitted semantic basis, because the service that identity resolves
    ///      to is itself one-shot and unreplaceable. Direction, boundaries, denomination, registry, and
    ///      ExerciseRouter are therefore never snapshotted per commitment.
    ///
    ///      Field order is chosen for storage packing rather than presentation: the record occupies four
    ///      slots instead of five, which matters because bounded enforcement scans read up to
    ///      `MAX_LIVE_COMMITMENTS` records in a single ordinary pool transaction. The semantic content is
    ///      exactly the frozen set.
    /// @param serviceId The Protected Execution Service under which the commitment was admitted.
    /// @param beneficiary The account for whose benefit qualifying execution must be delivered.
    /// @param exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param exerciseAuthority The account authorized to exercise the commitment.
    /// @param validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param originalEntitlement The admitted entitlement extent, never rewritten to represent later
    ///        fulfillment, non-exercisability, backing pressure, or release.
    /// @param remainingEntitlement The portion of the admitted extent not yet discharged by attributable
    ///        fulfillment. Authoritative persistent state, not a derived classification.
    struct Commitment {
        PoolId serviceId;
        address beneficiary;
        uint64 exercisableFrom;
        address exerciseAuthority;
        uint64 validUntil;
        uint128 originalEntitlement;
        uint128 remainingEntitlement;
    }

    /// @dev The working state of one prospective swap derivation.
    /// @param poolId The service pool the derivation reads.
    /// @param tickSpacing The authoritative pool tick spacing.
    /// @param zeroForOne The proposed swap direction.
    /// @param exactOutput Whether the proposed swap specifies its output rather than its input.
    /// @param sqrtPriceLimitX96 The proposed square-root price limit.
    /// @param swapFee The effective swap fee, in pips, including any protocol fee.
    /// @param amountRemaining The input or output amount still to be swapped.
    /// @param sqrtPriceX96 The square-root price reached so far.
    /// @param tick The tick reached so far, under v4's own post-step tick convention.
    /// @param liquidity The active liquidity reached so far.
    /// @param steps The number of swap steps traversed so far.
    struct SwapDerivation {
        PoolId poolId;
        int24 tickSpacing;
        bool zeroForOne;
        bool exactOutput;
        uint160 sqrtPriceLimitX96;
        uint24 swapFee;
        int256 amountRemaining;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 steps;
    }

    /// @notice The lifecycle position of the transaction-scoped O2 causal context.
    /// @dev The frozen O2 causal lifecycle is `EMPTY -> AUTHORIZED -> EXECUTED -> consumed/EMPTY`
    ///      (`uniswap-v4-realization.md` §16). This slice owns the arcs up to `EXECUTED`; consumption
    ///      belongs to finalization and is deliberately not expressible here, because declaring it early
    ///      would let something claim a transition no code can make.
    ///
    ///      Two of these positions are implementation guards rather than causal lifecycle positions, and
    ///      neither carries economic truth of its own.
    ///
    ///      `AUTHORIZING` is the in-flight marker of one authorization attempt, written before the
    ///      authorization consults anything outside this Hook and replaced by `AUTHORIZED` only if every
    ///      predicate succeeds. It exists so that an overlapping authorization cannot arise during those
    ///      external reads, and it can never be observed by a successful call: a completed authorization
    ///      reads `AUTHORIZED`, and a failed one reverts, which discards the transient write with
    ///      everything else.
    ///
    ///      `EXECUTING` means exactly one thing: the unique `beforeSwap` corresponding to this
    ///      authorization has been accepted as the exact O2 swap, and its corresponding authoritative
    ///      `afterSwap` is now expected. It is what binds the accepted proposal to the evidence that
    ///      follows it, and it is the reason no execution nonce, execution hash, or swap ledger is needed:
    ///      the PoolManager itself orders and authenticates the two callbacks, and the Hook already holds
    ///      the facts both of them must agree with. A matching `beforeSwap` reaches `EXECUTING` and can
    ///      reach nothing further, because a proposal is not an execution.
    enum ExerciseAuthorizationState {
        EMPTY,
        AUTHORIZING,
        AUTHORIZED,
        EXECUTING,
        EXECUTED
    }

    /// @notice The complete transaction-scoped causal context of one authorized exercise attempt.
    /// @dev These are the minimum causal bindings of `uniswap-v4-realization.md` §16 and nothing else. The
    ///      context exists so that a later stage can prove that the execution in front of it belongs to
    ///      exactly this authorized attempt — this commitment, this actor, this Beneficiary, this service,
    ///      this quantity — and it carries no fact that is not needed for that proof.
    ///
    ///      Nothing derived is bound here. Supporting Capacity, prospective Supporting Capacity, Aggregate
    ///      Capacity Obligation, Remaining Entitlement, validity, exercisability, and Beneficiary
    ///      eligibility were all evaluated to reach this context and none of them is stored in it: a
    ///      snapshot would be a second, silently ageing source of truth for a quantity that must be
    ///      re-derived from authoritative facts wherever it is used.
    ///
    ///      Immutable service semantics are referenced through `serviceId` rather than copied, exactly as
    ///      commitment records reference them. The protected execution this context authorizes is therefore
    ///      fully reconstructible without duplicating anything: the bound service fixes the pool, the
    ///      protected direction, and the qualifying execution boundary `P_Q`, and `q` fixes the exact
    ///      output of the single protected exact-output swap it admits.
    /// @param state The lifecycle position of the context.
    /// @param serviceId The Protected Execution Service the authorized exercise belongs to.
    /// @param commitmentId The one commitment the authorization is for.
    /// @param exerciseRouter The authenticated ExerciseRouter the request arrived through.
    /// @param exerciser The authenticated originating exerciser.
    /// @param beneficiary The Beneficiary resolved from authoritative commitment state.
    /// @param q The authorized protected-output quantity.
    struct ExerciseAuthorizationContext {
        ExerciseAuthorizationState state;
        PoolId serviceId;
        uint256 commitmentId;
        address exerciseRouter;
        address exerciser;
        address beneficiary;
        uint256 q;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The size of the bounded enforcement-reference index.
    /// @dev Republished from the single definition in `CommitmentRefs.sol`, which is imported under an
    ///      alias so that one value can carry the frozen name here without shadowing itself. This bounds
    ///      the candidate universe a later enforcement scan must inspect. It is not a limit on how many
    ///      commitments a service may have over its lifetime: historical records are permanent and
    ///      unbounded, and slots are reused.
    uint256 public constant MAX_LIVE_COMMITMENTS = BOUNDED_REFERENCE_SLOTS;

    /// @notice The bound on the swap-step traversal a prospective swap derivation may perform.
    /// @dev A prospective swap derivation reproduces the Uniswap v4 swap loop, which advances one step
    ///      per candidate target the tick bitmap yields. Inside the configured service domain the frozen
    ///      topology admits no initialized liquidity boundary, so the only extra steps come from tick
    ///      bitmap word edges, and a supported transition needs very few of them.
    ///
    ///      This is a bounded-execution realization constant, not an economic quantity. A derivation that
    ///      would exceed it is refused rather than truncated, because a truncated traversal would report
    ///      a prospective state the pool would never actually reach.
    uint256 public constant MAX_PROSPECTIVE_SWAP_STEPS = 16;

    /// @dev The base transient slot of the O2 causal context, with one field per successive slot.
    ///
    ///      Transient storage is the realization of the frozen requirement that O2 causal evidence is
    ///      transaction-scoped rather than persistent lifecycle state (`uniswap-v4-realization.md` §16,
    ///      `implementation-plan.md` §14.2). Two of its properties are doing real work here rather than
    ///      merely saving gas. The context cannot outlive its transaction, so an authorization can never be
    ///      replayed in a later one however the transaction that created it ended. And a revert discards
    ///      every write, so a failed authorization leaves nothing usable behind without any unwinding code
    ///      to get wrong.
    ///
    ///      The base is a namespaced hash, so the seven context slots cannot collide with any other
    ///      transient consumer that follows the same convention.
    bytes32 private constant EXERCISE_AUTHORIZATION_BASE_SLOT = keccak256("standby.StandbyHook.exerciseAuthorization");

    /// @dev Field offsets from `EXERCISE_AUTHORIZATION_BASE_SLOT`.
    uint256 private constant AUTHORIZATION_STATE_OFFSET = 0;
    uint256 private constant AUTHORIZATION_SERVICE_ID_OFFSET = 1;
    uint256 private constant AUTHORIZATION_COMMITMENT_ID_OFFSET = 2;
    uint256 private constant AUTHORIZATION_EXERCISE_ROUTER_OFFSET = 3;
    uint256 private constant AUTHORIZATION_EXERCISER_OFFSET = 4;
    uint256 private constant AUTHORIZATION_BENEFICIARY_OFFSET = 5;
    uint256 private constant AUTHORIZATION_Q_OFFSET = 6;

    /// @notice The only account authorized to configure and activate the Protected Execution Service.
    /// @dev Semantically distinct from commitment-establishment authority, exercise authority,
    ///      EligibilityRegistry administration, trader eligibility, and liquidity-action eligibility.
    address public immutable i_configurationAuthority;

    /// @notice The trusted ordinary-swap perimeter: the Universal Router role of RR-PERM-4A.
    /// @dev Realization-wide, not per service. F3 binds the role only; the perimeter is consumed by the
    ///      enforcement slice that resolves ordinary-swap participant provenance.
    address public immutable i_trustedUniversalRouter;

    /// @notice The trusted liquidity perimeter: the PositionManager role of RR-PERM-4A.
    /// @dev A distinct role from `i_trustedUniversalRouter`, held distinctly so the two can never be
    ///      collapsed into one generic trusted-router concept.
    address public immutable i_trustedPositionManager;

    /// @dev The authoritative Protected Execution Service. Written exactly once, by a successful
    ///      `configureAndActivate`, and never mutated afterwards.
    ProtectedExecutionService private _service;

    /// @dev The identity the next recorded commitment will receive. Starts at 1, so `0` is permanently
    ///      reserved as the nonexistent-commitment sentinel, and only ever increases across successful
    ///      commitment recordings. A successfully persisted allocation permanently consumes its identity;
    ///      if the surrounding transactions reverts, the allocation and counter increment revert atomically,
    ///      so no authoritative identity is consumed.
    ///
    ///      This counter is also the authoritative existence predicate: an identity has been allocated if
    ///      and only if it lies in `[1, _nextCommitmentId)`. Existence therefore never depends on the
    ///      field values of a record, which means a commitment whose facts happen to be zero-valued is
    ///      still unambiguously an existing commitment.
    uint256 private _nextCommitmentId;

    /// @dev Permanent commitment history. Records are never deleted and never rewritten except through
    ///      the authoritative Remaining Entitlement transition, so a historical record stays readable for
    ///      as long as the Hook exists, regardless of what the bounded reference index does later.
    mapping(uint256 commitmentId => Commitment commitment) private _commitments;

    /// @dev The bounded enforcement-reference index: `0` is an empty slot, a nonzero entry is a
    ///      commitment identity that later derivation may need to inspect.
    ///
    ///      Membership is bookkeeping, not economics. It asserts nothing about validity, exercisability,
    ///      eligibility, fulfillment, expiry, or whether the referenced commitment carries any Capacity
    ///      Obligation at all; a referenced commitment may be entirely terminal and merely awaiting
    ///      reclamation of its slot. Nothing may read membership as an economic classification.
    uint256[BOUNDED_REFERENCE_SLOTS] private _enforcementRefs;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted once, when the Protected Execution Service is configured and activated.
    /// @param serviceId The PoolId derived from the configured PoolKey.
    /// @param poolKey The complete configured PoolKey basis.
    /// @param protectedZeroForOne The protected swap direction of the service.
    /// @param tickQ The protected execution-quality boundary.
    /// @param tickO The opposite realization-domain boundary.
    /// @param registry The configured EligibilityRegistry.
    /// @param exerciseRouter The designated O2 coordinator.
    /// @param establishmentAuthority The commitment-establishment authority.
    event ProtectedExecutionServiceActivated(
        PoolId indexed serviceId,
        PoolKey poolKey,
        bool protectedZeroForOne,
        int24 tickQ,
        int24 tickO,
        address registry,
        address exerciseRouter,
        address establishmentAuthority
    );

    /// @notice Emitted when a successful O1 admission establishes an authoritative commitment.
    /// @dev Observational evidence of an admission that has already become authoritative. Every fact it
    ///      carries is readable from the commitment record and the bounded index afterwards, so nothing
    ///      later enforces against this event.
    /// @param commitmentId The permanent identity allocated to the admitted commitment.
    /// @param serviceId The Protected Execution Service the commitment was admitted under.
    /// @param beneficiary The account for whose benefit qualifying execution must be delivered.
    /// @param exerciseAuthority The account authorized to exercise the commitment.
    /// @param originalEntitlement The admitted entitlement extent.
    /// @param exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param enforcementReferenceSlot The bounded index slot that now references the commitment.
    event CommitmentEstablished(
        uint256 indexed commitmentId,
        PoolId indexed serviceId,
        address indexed beneficiary,
        address exerciseAuthority,
        uint128 originalEntitlement,
        uint64 exercisableFrom,
        uint64 validUntil,
        uint256 enforcementReferenceSlot
    );

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an account other than the configuration authority attempts activation.
    /// @param caller The unauthorized caller.
    error StandbyHook__NotConfigurationAuthority(address caller);

    /// @notice Thrown when activation is attempted while a Protected Execution Service already exists.
    error StandbyHook__ServiceAlreadyConfigured();

    /// @notice Thrown when a service fact is read before a Protected Execution Service exists.
    error StandbyHook__ServiceNotConfigured();

    /// @notice Thrown when the supplied PoolKey does not bind this exact Hook.
    /// @param hooks The Hook address the supplied PoolKey binds.
    error StandbyHook__PoolKeyDoesNotBindThisHook(address hooks);

    /// @notice Thrown when the pool identified by the supplied PoolKey is not initialized.
    /// @param poolId The PoolId derived from the supplied PoolKey.
    error StandbyHook__PoolNotInitialized(PoolId poolId);

    /// @notice Thrown when the pool already holds active liquidity at activation time.
    /// @param liquidity The authoritative current pool liquidity.
    error StandbyHook__PoolLiquidityNotZero(uint128 liquidity);

    /// @notice Thrown when the pool does not use the supported static-fee accounting model.
    /// @param fee The unsupported PoolKey fee.
    error StandbyHook__UnsupportedFeeModel(uint24 fee);

    /// @notice Thrown when a service boundary is not a valid Uniswap tick.
    /// @param tick The invalid boundary tick.
    error StandbyHook__InvalidServiceTick(int24 tick);

    /// @notice Thrown when a service boundary is not aligned to the pool tick spacing.
    /// @param tick The misaligned boundary tick.
    /// @param tickSpacing The authoritative pool tick spacing.
    error StandbyHook__MisalignedServiceTick(int24 tick, int24 tickSpacing);

    /// @notice Thrown when the service boundaries are not ordered as the protected direction requires.
    /// @param protectedZeroForOne The proposed protected direction.
    /// @param tickQ The proposed execution-quality boundary.
    /// @param tickO The proposed opposite boundary.
    error StandbyHook__InvalidServiceDomainOrder(bool protectedZeroForOne, int24 tickQ, int24 tickO);

    /// @notice Thrown when the authoritative current pool price lies outside the closed service domain.
    /// @param sqrtPriceX96 The authoritative current pool price.
    /// @param sqrtLowerX96 The square-root price of the numerically lower service boundary.
    /// @param sqrtUpperX96 The square-root price of the numerically upper service boundary.
    error StandbyHook__CurrentPriceOutsideServiceDomain(
        uint160 sqrtPriceX96, uint160 sqrtLowerX96, uint160 sqrtUpperX96
    );

    /// @notice Thrown when activation is attempted without an EligibilityRegistry.
    error StandbyHook__InvalidEligibilityRegistry();

    /// @notice Thrown when activation is attempted without a designated ExerciseRouter.
    error StandbyHook__InvalidExerciseRouter();

    /// @notice Thrown when activation is attempted without a commitment-establishment authority.
    error StandbyHook__InvalidEstablishmentAuthority();

    /// @notice Thrown when the Hook has no trusted ordinary-swap perimeter to establish a service against.
    error StandbyHook__InvalidTrustedUniversalRouter();

    /// @notice Thrown when the Hook has no trusted liquidity perimeter to establish a service against.
    error StandbyHook__InvalidTrustedPositionManager();

    /// @notice Thrown when an identity that was never allocated is read or referenced.
    /// @param commitmentId The unallocated identity, including the reserved sentinel `0`.
    error StandbyHook__CommitmentDoesNotExist(uint256 commitmentId);

    /// @notice Thrown when an enforcement-reference slot outside the bounded index is addressed.
    /// @param slot The out-of-range slot.
    error StandbyHook__InvalidEnforcementReferenceSlot(uint256 slot);

    /// @notice Thrown when a commitment already referenced by the bounded index would be referenced twice.
    /// @param commitmentId The already-referenced identity.
    /// @param slot The slot that already holds it.
    error StandbyHook__DuplicateEnforcementReference(uint256 commitmentId, uint256 slot);

    /// @notice Thrown when an account other than the commitment-establishment authority attempts O1.
    /// @dev Distinct from `StandbyHook__InvalidEstablishmentAuthority`, which reports that an activation
    ///      attempt named no establishment authority at all.
    /// @param caller The unauthorized caller.
    error StandbyHook__NotEstablishmentAuthority(address caller);

    /// @notice Thrown when a proposed commitment names no Beneficiary.
    error StandbyHook__InvalidBeneficiary();

    /// @notice Thrown when a proposed commitment names no exercise authority.
    error StandbyHook__InvalidExerciseAuthority();

    /// @notice Thrown when a proposed commitment carries no entitlement extent.
    error StandbyHook__InvalidOriginalEntitlement();

    /// @notice Thrown when a proposed commitment's exercise window could never open before validity ends.
    /// @param exercisableFrom The proposed timestamp from which exercise may become possible.
    /// @param validUntil The proposed timestamp at which the entitlement stops being valid.
    error StandbyHook__InvalidCommitmentWindow(uint64 exercisableFrom, uint64 validUntil);

    /// @notice Thrown when a proposed commitment would be admitted already outside its validity window.
    /// @dev Half-open validity: `validUntil` equal to the current time is already invalid, so admitting it
    ///      would create a commitment that is binding on nothing from the moment it exists.
    /// @param validUntil The proposed timestamp at which the entitlement stops being valid.
    /// @param timestamp The authoritative current time.
    error StandbyHook__CommitmentAlreadyInvalid(uint64 validUntil, uint256 timestamp);

    /// @notice Thrown when the proposed Beneficiary is not currently eligible for protected service.
    /// @param beneficiary The ineligible proposed Beneficiary.
    error StandbyHook__BeneficiaryNotEligible(address beneficiary);

    /// @notice Thrown when every bounded enforcement reference is held by a still-binding commitment.
    /// @dev A realization limit, never an economic one. It says nothing about whether the proposed
    ///      commitment would have been backed, and it must never be reported as, or substituted for,
    ///      insufficient backing.
    error StandbyHook__EnforcementReferenceCapacityExhausted();

    /// @notice Thrown when admitting a proposed commitment would leave the service unbacked.
    /// @dev Distinct from `StandbyHook__InsufficientProspectiveBacking`, which compares a *derived
    ///      post-transition* Supporting Capacity against the current obligation. This one compares the
    ///      authoritative *present* Supporting Capacity against the obligation admission would create,
    ///      because O1 changes the obligation and leaves the pool untouched.
    /// @param supportingCapacity The authoritative current Supporting Capacity.
    /// @param prospectiveObligation The Aggregate Capacity Obligation admission would establish.
    error StandbyHook__InsufficientAdmissionBacking(uint256 supportingCapacity, uint256 prospectiveObligation);

    /// @notice Thrown when a predicted post-transition price would leave the closed service domain.
    /// @dev Distinct from `StandbyHook__CurrentPriceOutsideServiceDomain`, which reports that the
    ///      authoritative present state is already an invalid derivation basis. This one reports that a
    ///      proposed transition would take the pool out of the configured realization domain, which is a
    ///      fact about the transition rather than about the present.
    /// @param sqrtPriceX96 The predicted post-transition square-root price.
    /// @param sqrtLowerX96 The square-root price of the numerically lower service boundary.
    /// @param sqrtUpperX96 The square-root price of the numerically upper service boundary.
    error StandbyHook__ProspectivePriceOutsideServiceDomain(
        uint160 sqrtPriceX96, uint160 sqrtLowerX96, uint160 sqrtUpperX96
    );

    /// @notice Thrown when a proposed swap violates the price-limit conditions Uniswap v4 itself imposes.
    /// @dev The prospective derivation reproduces v4's own entry conditions so that it never predicts a
    ///      state for a swap the PoolManager would reject outright.
    /// @param zeroForOne The proposed swap direction.
    /// @param sqrtPriceX96 The authoritative current square-root price.
    /// @param sqrtPriceLimitX96 The proposed square-root price limit.
    error StandbyHook__UnsupportedSwapPriceLimit(bool zeroForOne, uint160 sqrtPriceX96, uint160 sqrtPriceLimitX96);

    /// @notice Thrown when a prospective swap derivation would exceed the bounded step traversal.
    /// @dev Defensive fail-closed protection only. Activation refuses any service whose own domain could
    ///      reach this, so an activated service can encounter it only on a path that has already left the
    ///      configured domain — a path no supported Standby operation takes.
    /// @param steps The bound that was reached.
    error StandbyHook__ProspectiveSwapStepBoundExceeded(uint256 steps);

    /// @notice Thrown when a proposed service domain could not be prospectively derived within the bound.
    /// @dev A realization-admissibility failure, and deliberately nothing else. It does not mean the
    ///      proposed service would be unbacked, would have zero Supporting Capacity, or would carry an
    ///      invalid commitment state; it means this reference realization cannot authoritatively evaluate
    ///      prospective transitions across a domain that wide at that tick spacing, so it refuses to
    ///      activate a service it could not later enforce.
    /// @param demand The traversal demand the proposed immutable domain implies.
    /// @param bound The supported traversal bound.
    error StandbyHook__ProspectiveTraversalDemandExceedsBound(uint256 demand, uint256 bound);

    /// @notice Thrown when a liquidity-removal derivation is asked about a non-removal.
    /// @param liquidityDelta The proposed liquidity delta.
    error StandbyHook__NotALiquidityRemoval(int256 liquidityDelta);

    /// @notice Thrown when a callback concerns a pool that is not this Hook's configured service.
    /// @dev Callback enablement is a property of the Hook address, so any pool may bind this Hook. Only
    ///      the one configured service pool is a Standby transition; every other pool is refused rather
    ///      than enforced against the wrong service basis.
    /// @param poolId The PoolId the callback concerned.
    error StandbyHook__PoolIsNotConfiguredService(PoolId poolId);

    /// @notice Thrown when an ordinary swap does not arrive through the trusted ordinary-swap perimeter.
    /// @param sender The callback sender that attempted the transition.
    error StandbyHook__UntrustedSwapPerimeter(address sender);

    /// @notice Thrown when a liquidity action does not arrive through the trusted liquidity perimeter.
    /// @param sender The callback sender that attempted the transition.
    error StandbyHook__UntrustedLiquidityPerimeter(address sender);

    /// @notice Thrown when the authenticated actor of an ordinary swap is not an eligible trader.
    /// @param actor The authenticated originating user.
    error StandbyHook__TraderNotEligible(address actor);

    /// @notice Thrown when the authenticated actor of a liquidity addition is not an eligible provider.
    /// @param actor The authenticated originating user.
    error StandbyHook__LiquidityProviderNotEligible(address actor);

    /// @notice Thrown when a liquidity addition would initialize a boundary strictly inside the domain.
    /// @dev The single-active-liquidity-region topology is what makes Supporting Capacity and every
    ///      prospective derivation authoritative, so this is refused however eligible the provider is and
    ///      however much liquidity the addition would contribute.
    /// @param tickLower The lower endpoint of the proposed liquidity range.
    /// @param tickUpper The upper endpoint of the proposed liquidity range.
    error StandbyHook__ProhibitedInteriorLiquidityBoundary(int24 tickLower, int24 tickUpper);

    /// @notice Thrown when a proposed transition would leave Supporting Capacity below the obligation.
    /// @param prospectiveCapacity The Supporting Capacity the proposed transition would leave behind.
    /// @param obligation The authoritative current Aggregate Capacity Obligation.
    error StandbyHook__InsufficientProspectiveBacking(uint256 prospectiveCapacity, uint256 obligation);

    /// @notice Thrown when an O2 authorization does not arrive through the configured ExerciseRouter.
    /// @dev The exercise perimeter is per service, not realization-wide: it is the ExerciseRouter fixed by
    ///      activation, and neither trusted ordinary-transition perimeter substitutes for it.
    /// @param caller The account that attempted the authorization.
    error StandbyHook__NotExerciseRouter(address caller);

    /// @notice Thrown when an O2 authorization is attempted while another is already unresolved.
    /// @dev Covers both shapes the restriction has to close: a second authorization attempted after one has
    ///      already succeeded in this transaction, and a nested one attempted while an authorization is
    ///      still deciding. Neither may overwrite, coexist with, or substitute for the active context.
    error StandbyHook__ExerciseAuthorizationAlreadyActive();

    /// @notice Thrown when the targeted commitment belongs to a different Protected Execution Service.
    /// @dev Distinct from `StandbyHook__PoolIsNotConfiguredService`, which reports that a *callback*
    ///      concerned the wrong pool. This one reports that an authentic commitment record names a service
    ///      other than the one this Hook operates, so its admitted semantics are not the semantics this
    ///      authorization would be evaluated under.
    /// @param commitmentId The targeted identity.
    /// @param commitmentServiceId The service the commitment was admitted under.
    error StandbyHook__CommitmentNotInService(uint256 commitmentId, PoolId commitmentServiceId);

    /// @notice Thrown when the authenticated exerciser is not the commitment's exercise authority.
    /// @dev The exerciser reported here is the originating account the configured ExerciseRouter
    ///      authenticated, never the router itself and never a caller-supplied address.
    /// @param commitmentId The targeted identity.
    /// @param exerciser The authenticated originating exerciser.
    error StandbyHook__NotCommitmentExerciseAuthority(uint256 commitmentId, address exerciser);

    /// @notice Thrown when the targeted commitment is no longer temporally valid.
    /// @param commitmentId The targeted identity.
    /// @param validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param timestamp The authoritative current time.
    error StandbyHook__CommitmentNotValid(uint256 commitmentId, uint64 validUntil, uint256 timestamp);

    /// @notice Thrown when the targeted commitment's admitted exercise window is not currently open.
    /// @dev Distinct from `StandbyHook__CommitmentNotValid`. A commitment whose window has not opened is
    ///      fully valid and fully binding; it is simply not yet exercisable, and nothing about that
    ///      releases backing or changes a term.
    /// @param commitmentId The targeted identity.
    /// @param exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @param timestamp The authoritative current time.
    error StandbyHook__CommitmentNotExercisable(
        uint256 commitmentId, uint64 exercisableFrom, uint64 validUntil, uint256 timestamp
    );

    /// @notice Thrown when a requested exercise quantity is outside the permissible extent.
    /// @dev One requirement, `0 < q <= Remaining`, so one rejection. Both operands are reported, which is
    ///      what makes the two failing shapes — nothing requested, and more requested than remains —
    ///      distinguishable without splitting one predicate into two.
    /// @param q The requested protected-output quantity.
    /// @param remainingEntitlement The authoritative unfulfilled remainder.
    error StandbyHook__InvalidExerciseExtent(uint256 q, uint128 remainingEntitlement);

    /// @notice Thrown when the complete successful exercise would leave the service unbacked.
    /// @dev Distinct from both other backing rejections, because the compared quantities are different
    ///      facts. `StandbyHook__InsufficientProspectiveBacking` compares a derived post-transition
    ///      Supporting Capacity against the *current* obligation, because an ordinary transition changes
    ///      the pool and not the obligation. `StandbyHook__InsufficientAdmissionBacking` compares present
    ///      capacity against the obligation admission would create, because O1 changes the obligation and
    ///      not the pool. This one compares the capacity the protected exact-output execution would leave
    ///      against the obligation a complete successful exercise would leave, because O2 changes both.
    /// @param prospectiveCapacity The Supporting Capacity the protected exact-output execution would leave.
    /// @param prospectiveObligation The Aggregate Capacity Obligation a complete successful O2 would leave.
    error StandbyHook__InsufficientProspectiveExerciseBacking(
        uint256 prospectiveCapacity, uint256 prospectiveObligation
    );

    /// @notice Thrown when a swap is proposed while the O2 causal context admits no protected execution.
    /// @dev The causal exclusion zone, reported as one condition. Once an authorization exists the service
    ///      is inside an O2 operation, and the only swap that may proceed is the exact protected execution
    ///      that authorization admits — so a swap arriving against an unresolved `AUTHORIZING`,
    ///      `EXECUTING`, or `EXECUTED` context is refused rather than quietly re-classified as an ordinary
    ///      O3 transition it would then be enforced as under the wrong rule.
    /// @param state The causal position the context was actually in.
    error StandbyHook__ExerciseExecutionNotAuthorized(ExerciseAuthorizationState state);

    /// @notice Thrown when the PoolManager operation sender is not the ExerciseRouter the context bound.
    /// @dev Distinct from `StandbyHook__NotExerciseRouter`, which reports that an *authorization request*
    ///      did not arrive through the configured ExerciseRouter. This one reports that the account that
    ///      asked the PoolManager to perform the swap is not the router the active authorization is bound
    ///      to. It is a required conjunct of O2 classification and never sufficient on its own.
    /// @param sender The callback sender that proposed the swap.
    error StandbyHook__NotAuthorizedExerciseExecutor(address sender);

    /// @notice Thrown when a proposed swap is not the exact protected execution the authorization admits.
    /// @dev One rejection for one requirement: the proposed swap must be the canonical protected execution
    ///      reconstructed from the immutable service basis and the authorized quantity. Direction,
    ///      exact-output mode, the exact quantity, and the qualification boundary are that one shape, and a
    ///      swap that differs in any of them is not the authorized execution. The proposed shape is
    ///      reported, because the admitted one is derivable from the service and the causal context.
    /// @param zeroForOne The proposed swap direction.
    /// @param amountSpecified The proposed amount, negative for exact input and positive for exact output.
    /// @param sqrtPriceLimitX96 The proposed square-root price limit.
    error StandbyHook__NotTheAuthorizedProtectedExecution(
        bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96
    );

    /// @notice Thrown when execution evidence is offered while no protected execution is in flight.
    /// @dev Execution evidence is only meaningful for a swap this Hook already accepted as the exact O2
    ///      execution. A context that is not `EXECUTING` has no accepted swap awaiting evidence, so
    ///      `EMPTY -> EXECUTED`, `AUTHORIZED -> EXECUTED`, and a second `EXECUTED` transition are all
    ///      refused here rather than being distinguished into separate conditions they do not have.
    /// @param state The causal position the context was actually in.
    error StandbyHook__NoProtectedExecutionInFlight(ExerciseAuthorizationState state);

    /// @notice Thrown when the actual protected output of the executed swap is not exactly `q`.
    /// @dev The authoritative execution evidence, and the one requirement that separates a swap that was
    ///      requested from a swap that happened. The output is taken from the PoolManager's own
    ///      `BalanceDelta` on the configured protected-output side, so a partial exact-output execution, an
    ///      output on the wrong currency side, and a wrong-signed delta all fail the same comparison.
    /// @param actualProtectedOutput The protected-output amount the PoolManager actually produced.
    /// @param authorizedQuantity The protected-output quantity the authorization admits.
    error StandbyHook__ProtectedOutputNotExecuted(int256 actualProtectedOutput, uint256 authorizedQuantity);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the Hook immutably to its realization-wide trust dependencies.
    /// @dev Reverts through `Hooks.validateHookPermissions` unless the deployment address encodes
    ///      exactly the permissions declared by `getHookPermissions()`.
    ///
    ///      The trusted perimeter roles are validated by `configureAndActivate`, which is where the
    ///      frozen realization sequence places that check, rather than here. A Hook deployed without a
    ///      complete trust basis is inert: it can never host a Protected Execution Service, so it can
    ///      never reach any Standby economic transition.
    ///
    ///      Commitment identity starts at 1, so `0` is permanently reserved as the nonexistent-commitment
    ///      sentinel and no allocated identity can ever collide with it.
    /// @param _poolManager The PoolManager whose callbacks this Hook answers.
    /// @param _configurationAuthority The only account authorized to activate the service.
    /// @param _trustedUniversalRouter The trusted ordinary-swap perimeter.
    /// @param _trustedPositionManager The trusted liquidity perimeter.
    constructor(
        IPoolManager _poolManager,
        address _configurationAuthority,
        address _trustedUniversalRouter,
        address _trustedPositionManager
    ) BaseHook(_poolManager) {
        i_configurationAuthority = _configurationAuthority;
        i_trustedUniversalRouter = _trustedUniversalRouter;
        i_trustedPositionManager = _trustedPositionManager;

        _nextCommitmentId = 1;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Configures and activates this Hook's one Protected Execution Service, atomically.
    /// @dev The only service lifecycle transition: `UNCONFIGURED -> ACTIVATED`. There is no partial
    ///      configuration setter, no separate activation step, no pause, no deactivation, no
    ///      reconfiguration, and no post-activation semantic setter. Every validation precedes the
    ///      single authoritative write, so a rejected attempt persists nothing.
    ///
    ///      Pool initialization, current liquidity, and current price are read from authoritative
    ///      PoolManager state. They are never taken from caller-supplied substitutes. The one Slot0 read
    ///      supplies both the initialization fact and the authoritative current price used for domain
    ///      containment; the current price is used directly rather than reconstructed from the current
    ///      tick (RR-SC-4).
    ///
    ///      Custom accounting needs no separate check here: the PoolKey must bind this exact Hook, and
    ///      this Hook declares no return-delta permission, so the supported accounting model follows
    ///      structurally from the Hook binding.
    /// @param _poolKey The complete PoolKey of the pool this service is established over.
    /// @param _protectedZeroForOne The protected swap direction of the service.
    /// @param _tickQ The protected execution-quality boundary, in the protected direction.
    /// @param _tickO The opposite realization-domain boundary.
    /// @param _registry The EligibilityRegistry this service consumes.
    /// @param _exerciseRouter The designated O2 coordinator for this service.
    /// @param _establishmentAuthority The commitment-establishment authority for this service.
    /// @return activatedServiceId The PoolId that identifies the activated service.
    function configureAndActivate(
        PoolKey calldata _poolKey,
        bool _protectedZeroForOne,
        int24 _tickQ,
        int24 _tickO,
        IEligibilityRegistry _registry,
        address _exerciseRouter,
        address _establishmentAuthority
    ) external returns (PoolId activatedServiceId) {
        if (msg.sender != i_configurationAuthority) revert StandbyHook__NotConfigurationAuthority(msg.sender);

        activatedServiceId = _poolKey.toId();

        if (address(_poolKey.hooks) != address(this)) {
            revert StandbyHook__PoolKeyDoesNotBindThisHook(address(_poolKey.hooks));
        }

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(activatedServiceId);

        if (sqrtPriceX96 == 0) revert StandbyHook__PoolNotInitialized(activatedServiceId);

        if (_service.configured) revert StandbyHook__ServiceAlreadyConfigured();

        uint128 liquidity = poolManager.getLiquidity(activatedServiceId);

        if (liquidity != 0) revert StandbyHook__PoolLiquidityNotZero(liquidity);

        if (_poolKey.fee.isDynamicFee()) revert StandbyHook__UnsupportedFeeModel(_poolKey.fee);

        _validateServiceDomain(_poolKey.tickSpacing, _protectedZeroForOne, _tickQ, _tickO, sqrtPriceX96);

        _validateProspectiveDerivability(_tickQ, _tickO, _poolKey.tickSpacing);

        if (address(_registry) == address(0)) revert StandbyHook__InvalidEligibilityRegistry();
        if (_exerciseRouter == address(0)) revert StandbyHook__InvalidExerciseRouter();
        if (_establishmentAuthority == address(0)) revert StandbyHook__InvalidEstablishmentAuthority();

        if (i_trustedUniversalRouter == address(0)) revert StandbyHook__InvalidTrustedUniversalRouter();
        if (i_trustedPositionManager == address(0)) revert StandbyHook__InvalidTrustedPositionManager();

        _service = ProtectedExecutionService({
            poolKey: _poolKey,
            registry: _registry,
            protectedZeroForOne: _protectedZeroForOne,
            tickQ: _tickQ,
            tickO: _tickO,
            configured: true,
            exerciseRouter: _exerciseRouter,
            establishmentAuthority: _establishmentAuthority
        });

        emit ProtectedExecutionServiceActivated(
            activatedServiceId,
            _poolKey,
            _protectedZeroForOne,
            _tickQ,
            _tickO,
            address(_registry),
            _exerciseRouter,
            _establishmentAuthority
        );
    }

    /// @notice Establishes one authoritative Standby commitment against the activated service.
    /// @dev The O1 transition, and the point at which Aggregate Capacity Obligation can first become
    ///      positive. It is deliberately not a pool transition: it moves no price, changes no liquidity,
    ///      takes custody of nothing, and reserves nothing. What it establishes is an obligation that
    ///      every later backing-affecting transition must respect.
    ///
    ///      The caller supplies only commitment-specific terms. Supporting Capacity, the current and
    ///      prospective Aggregate Capacity Obligation, the proposed commitment's own Capacity Obligation,
    ///      validity, binding status, the reference slot, the commitment identity, and the initial
    ///      Remaining Entitlement are all derived here from authoritative facts. A caller with
    ///      establishment authority determines terms, never economics.
    ///
    ///      The sequence is derive-first / persist-last (RR-O1-10). Every predicate — authority, service
    ///      existence, the commitment terms, current Beneficiary eligibility, an available or
    ///      authoritatively reclaimable bounded reference, and backing sufficiency — completes before the
    ///      first authoritative write, so a rejected admission consumes no identity, writes no record,
    ///      touches no reference, and changes no derived obligation.
    ///
    ///      Two of those failures look adjacent and are kept apart on purpose. A full bounded index is a
    ///      realization limit and is refused as one even when backing would comfortably have covered the
    ///      proposal; insufficient backing is an economic refusal. Collapsing them would make the
    ///      realization's own capacity look like an economic verdict.
    ///
    ///      Establishment authority is resolved from the service, so service existence is a precondition
    ///      of authenticating anybody rather than a check that could meaningfully precede it: an
    ///      unconfigured Hook has no establishment authority for a caller to be. Both predicates precede
    ///      everything else.
    ///
    ///      Nothing derived here is persisted. Capacity Obligation, validity, exercisability, and binding
    ///      status are recomputed from the recorded facts on every later use, which is what lets an
    ///      admitted commitment expire, and its reference become reclaimable, with no transaction sent to
    ///      notice.
    /// @param _beneficiary The account for whose benefit qualifying execution must be delivered.
    /// @param _exerciseAuthority The account authorized to exercise the commitment.
    /// @param _originalEntitlement The admitted entitlement extent, in raw protected-output units.
    /// @param _exercisableFrom The admitted timestamp from which exercise may become possible.
    /// @param _validUntil The admitted timestamp at which the entitlement stops being valid.
    /// @return commitmentId The permanent identity allocated to the admitted commitment.
    function establishCommitment(
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil
    ) external returns (uint256 commitmentId) {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();
        if (msg.sender != _service.establishmentAuthority) revert StandbyHook__NotEstablishmentAuthority(msg.sender);

        _validateCommitmentTerms(_beneficiary, _exerciseAuthority, _originalEntitlement, _exercisableFrom, _validUntil);

        if (!_service.registry.canReceiveProtectedService(_beneficiary)) {
            revert StandbyHook__BeneficiaryNotEligible(_beneficiary);
        }

        uint256 currentObligation = _aggregateObligation();

        (bool slotFound, uint256 slot) = _admissibleReferenceSlot();

        if (!slotFound) revert StandbyHook__EnforcementReferenceCapacityExhausted();

        uint256 prospectiveObligation =
            currentObligation + StandbyMath.commitmentObligation(_originalEntitlement, _validUntil, block.timestamp);

        uint256 capacity = _supportingCapacity();

        if (capacity < prospectiveObligation) {
            revert StandbyHook__InsufficientAdmissionBacking(capacity, prospectiveObligation);
        }

        PoolId admittedServiceId = _serviceId();

        commitmentId = _recordCommitment(
            Commitment({
                serviceId: admittedServiceId,
                beneficiary: _beneficiary,
                exercisableFrom: _exercisableFrom,
                exerciseAuthority: _exerciseAuthority,
                validUntil: _validUntil,
                originalEntitlement: _originalEntitlement,
                remainingEntitlement: _originalEntitlement
            })
        );

        _writeEnforcementReference(slot, commitmentId);

        emit CommitmentEstablished(
            commitmentId,
            admittedServiceId,
            _beneficiary,
            _exerciseAuthority,
            _originalEntitlement,
            _exercisableFrom,
            _validUntil,
            slot
        );
    }

    /// @notice Authorizes one exercise attempt and creates the Hook-owned transaction-scoped causal context.
    /// @dev The first stage of O2, and deliberately only the first. It executes no swap, moves no price,
    ///      settles no input, delivers nothing to the Beneficiary, fulfils nothing, reduces no Remaining
    ///      Entitlement, and reduces no Aggregate Capacity Obligation. What it produces is a causal
    ///      capability: proof, for the rest of this transaction, that this Hook bound exactly one
    ///      commitment, one authenticated exerciser, one authoritative Beneficiary, one service, one
    ///      ExerciseRouter, and one quantity together before any protected execution could be attempted.
    ///
    ///      The caller supplies two things and neither of them is an economic fact: which commitment, and
    ///      how much of it. Everything the decision actually turns on is resolved here from authoritative
    ///      state — the Beneficiary from the commitment record, the exercise authority from the commitment
    ///      record, eligibility from the configured registry, validity and exercisability from the F5
    ///      kernel, Remaining Entitlement from the persisted facts, and both sides of the backing
    ///      comparison from the F5 derivations over real PoolManager state.
    ///
    ///      Authority is established in one direction only. The configured ExerciseRouter is authenticated
    ///      first, and only then is it asked who originated the request; asking first and deciding
    ///      afterwards would let any contract implementing the attribution interface nominate an exerciser.
    ///      The router's own identity is never an answer to that question and never satisfies exercise
    ///      authority: it is the coordinator of the request, not a party to the commitment.
    ///
    ///      The backing comparison is the one an O2 has to pass, not the one an ordinary transition passes.
    ///      A successful exercise changes the pool *and* the obligation, so prospective Supporting Capacity
    ///      is compared against the obligation a complete successful exercise would leave, `O - q`
    ///      (RR-O2-6). Neither side is reduced here: `O` and Remaining Entitlement are exactly what they
    ///      were, and stay that way until fulfillment is actually attributable. Exact sufficiency passes.
    ///
    ///      The context is written last and only on success, so it is a consequence of authorization rather
    ///      than an input to it. A rejected attempt reverts, which discards the transient write along with
    ///      everything else and leaves nothing a later stage could mistake for authorization.
    /// @param _commitmentId The commitment the authenticated exerciser is asking to exercise.
    /// @param _q The protected-output quantity the authenticated exerciser is asking to exercise.
    function authorizeExercise(uint256 _commitmentId, uint256 _q) external {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();
        if (msg.sender != _service.exerciseRouter) revert StandbyHook__NotExerciseRouter(msg.sender);

        _beginExerciseAuthorization();

        address exerciser = _authenticatedActor(msg.sender);

        if (!_commitmentExists(_commitmentId)) revert StandbyHook__CommitmentDoesNotExist(_commitmentId);

        Commitment storage record = _commitments[_commitmentId];

        PoolId authorizedServiceId = _serviceId();

        if (PoolId.unwrap(record.serviceId) != PoolId.unwrap(authorizedServiceId)) {
            revert StandbyHook__CommitmentNotInService(_commitmentId, record.serviceId);
        }

        if (exerciser != record.exerciseAuthority) {
            revert StandbyHook__NotCommitmentExerciseAuthority(_commitmentId, exerciser);
        }

        _requireExercisableCommitment(_commitmentId, record.exercisableFrom, record.validUntil);

        address authoritativeBeneficiary = record.beneficiary;

        if (!_service.registry.canReceiveProtectedService(authoritativeBeneficiary)) {
            revert StandbyHook__BeneficiaryNotEligible(authoritativeBeneficiary);
        }

        uint128 remainingEntitlement = record.remainingEntitlement;

        if (_q == 0 || _q > remainingEntitlement) revert StandbyHook__InvalidExerciseExtent(_q, remainingEntitlement);

        _requireProspectiveExerciseBacking(_q);

        _writeExerciseAuthorization(
            ExerciseAuthorizationContext({
                state: ExerciseAuthorizationState.AUTHORIZED,
                serviceId: authorizedServiceId,
                commitmentId: _commitmentId,
                exerciseRouter: msg.sender,
                exerciser: exerciser,
                beneficiary: authoritativeBeneficiary,
                q: _q
            })
        );
    }

    /// @notice Returns the transaction-scoped O2 causal context this Hook currently holds.
    /// @dev Observation of Hook-owned state, never a substitute for it. Nothing may treat a value read here
    ///      as authority: authorization is proven by the context the Hook itself consults, and a caller
    ///      that has read this has learned what the Hook decided, not acquired the ability to decide.
    ///
    ///      Outside an authorized exercise the whole context reads as its zero value with state `EMPTY`,
    ///      including in every later transaction, because transient storage does not survive the
    ///      transaction that wrote it.
    /// @return context The current causal context.
    function exerciseAuthorization() external view returns (ExerciseAuthorizationContext memory context) {
        context = _readExerciseAuthorization();
    }

    /// @notice Returns the one protected execution the active authorization admits.
    /// @dev The single production expression of what a Standby exercise executes. The ExerciseRouter has to
    ///      propose a swap to the PoolManager, and the shape of that swap is not the router's to choose:
    ///      the pool, the protected direction, exact-output mode, the quantity, and the qualification
    ///      boundary `P_Q` are all facts this Hook already owns (RR-O2-7, RR-O2-8). Reconstructing them
    ///      here — from the same function the authorization backing derivation uses — is what makes the
    ///      authorized execution and the executable execution the same object rather than two descriptions
    ///      that have to be kept in agreement.
    ///
    ///      Reading this grants nothing. It is a proposal, and the proposal is validated again on the
    ///      authoritative PoolManager callback path against the causal context, so a caller that ignores
    ///      what it read here is refused exactly as a caller that never read it.
    ///
    ///      It reverts unless an authorization is currently AUTHORIZED, because outside that position there
    ///      is no admitted execution to describe.
    /// @return key The configured service pool the execution is performed against.
    /// @return params The exact protected exact-output swap the authorization admits.
    function authorizedProtectedExecution() external view returns (PoolKey memory key, SwapParams memory params) {
        ExerciseAuthorizationContext memory context = _readExerciseAuthorization();

        if (context.state != ExerciseAuthorizationState.AUTHORIZED) {
            revert StandbyHook__ExerciseExecutionNotAuthorized(context.state);
        }

        (key, params) = (_service.poolKey, _canonicalProtectedExecution(context.q));
    }

    /// @notice Returns the complete authoritative Protected Execution Service basis.
    /// @dev Before activation every field reads as its zero value and `configured` is false.
    /// @return service The persisted service basis.
    function protectedExecutionService() external view returns (ProtectedExecutionService memory service) {
        service = _service;
    }

    /// @notice Returns the PoolId identifying the activated Protected Execution Service.
    /// @dev Derived from the persisted PoolKey rather than persisted independently. Reverts before
    ///      activation, because an unconfigured Hook has no service identity to report.
    /// @return poolId The service identity.
    function serviceId() external view returns (PoolId poolId) {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();

        poolId = _serviceId();
    }

    /// @notice Returns the complete authoritative fact record of a historical commitment.
    /// @dev A fact-only read. It reports what was recorded and never what it means: no validity,
    ///      exercisability, binding status, obligation, or reclaimability is computed or implied here.
    ///
    ///      An identity that was never allocated reverts rather than returning a zero-valued record, so a
    ///      caller can never mistake the absence of a commitment for the presence of an empty one.
    /// @param _commitmentId The identity to read.
    /// @return commitmentRecord The persisted commitment facts.
    function commitment(uint256 _commitmentId) external view returns (Commitment memory commitmentRecord) {
        if (!_commitmentExists(_commitmentId)) revert StandbyHook__CommitmentDoesNotExist(_commitmentId);

        commitmentRecord = _commitments[_commitmentId];
    }

    /// @notice Returns the identity the next recorded commitment will receive.
    /// @dev The authoritative allocation fact. Because identities are allocated strictly in sequence from
    ///      1 and are never recycled, this also delimits the allocated history: every identity in
    ///      `[1, nextCommitmentId)` exists and every other identity does not.
    /// @return nextId The next identity to be allocated.
    function nextCommitmentId() external view returns (uint256 nextId) {
        nextId = _nextCommitmentId;
    }

    /// @notice Returns the whole bounded enforcement-reference index.
    /// @dev A fact-only read of an index, not of an economic ledger. Each entry is either `0`, meaning the
    ///      slot is empty, or a commitment identity that later derivation may need to inspect. A nonzero
    ///      entry is not evidence that the referenced commitment is valid, exercisable, eligible,
    ///      unfulfilled, or currently obligation-bearing.
    ///
    ///      The whole index is returned in one call because it is bounded by construction, and because
    ///      the meaning of a slot is only well defined relative to the complete set.
    /// @return references The bounded enforcement-reference index, slot by slot.
    function enforcementReferences() external view returns (uint256[BOUNDED_REFERENCE_SLOTS] memory references) {
        references = _enforcementRefs;
    }

    /// @notice Returns current Supporting Capacity, in raw units of the protected output currency.
    /// @dev Derived from authoritative PoolManager state and the immutable service configuration on every
    ///      call; nothing about it is stored. This read is not a separate observability formula: it
    ///      resolves through the same derivation later enforcement must use, so a value shown here and a
    ///      value enforced against can never disagree.
    ///
    ///      Reverts when the authoritative current price lies outside the closed service domain. That is
    ///      not zero capacity — it is a state for which no authoritative Standby Supporting Capacity
    ///      exists, and reporting zero would present an invalid derivation basis as an ordinary economic
    ///      fact.
    /// @return capacity The current Supporting Capacity.
    function supportingCapacity() external view returns (uint256 capacity) {
        capacity = _supportingCapacity();
    }

    /// @notice Returns the current Aggregate Capacity Obligation of the service.
    /// @dev The bounded sum of the current Capacity Obligation of every commitment the enforcement-
    ///      reference index points at. It is derived on every call and never cached, so a commitment that
    ///      has expired or been fulfilled stops contributing without any transaction being sent to notice.
    ///
    ///      Reference membership carries no economic meaning: a stale reference to a terminal commitment
    ///      contributes exactly zero, and slot order cannot change the sum.
    /// @return obligation The Aggregate Capacity Obligation, in raw units of the protected output currency.
    function aggregateObligation() external view returns (uint256 obligation) {
        obligation = _aggregateObligation();
    }

    /// @notice Returns the current Capacity Obligation of one commitment.
    /// @dev Binding is not exercisability. A commitment whose window has not opened, or whose Beneficiary
    ///      is currently ineligible, still imposes its full Remaining Entitlement; only exhaustion or
    ///      expiry releases it.
    /// @param _commitmentId The identity to derive.
    /// @return obligation The Capacity Obligation, in raw units of the protected output currency.
    function commitmentObligation(uint256 _commitmentId) external view returns (uint256 obligation) {
        if (!_commitmentExists(_commitmentId)) revert StandbyHook__CommitmentDoesNotExist(_commitmentId);

        obligation = _commitmentObligation(_commitmentId);
    }

    /// @notice Previews the Supporting Capacity a proposed swap would leave behind.
    /// @dev Diagnostic surface over an already-authoritative derivation. It introduces no economic
    ///      semantics of its own, duplicates no arithmetic, and is never a precondition for anything: it
    ///      calls the same prospective-state derivation that pre-transition enforcement will call, so a
    ///      preview and an enforcement decision are the same computation.
    ///
    ///      The prospective state is derived by reproducing the supported Uniswap v4 swap semantics from
    ///      the exact current state, not by subtracting an estimated amount from present capacity.
    /// @param _params The proposed swap.
    /// @return capacity The Supporting Capacity of the predicted post-swap state.
    function prospectiveSupportingCapacityAfterSwap(SwapParams calldata _params)
        external
        view
        returns (uint256 capacity)
    {
        (uint160 sqrtPriceX96, uint128 liquidity) = _prospectiveSwapState(_params);

        capacity = _prospectiveSupportingCapacity(sqrtPriceX96, liquidity);
    }

    /// @notice Previews the Supporting Capacity a proposed liquidity removal would leave behind.
    /// @dev As with the swap preview, this exposes the authoritative derivation rather than a second one.
    ///      A removal cannot move the square-root price, so the whole question is whether the removed
    ///      range is active at the current tick; capacity is then recomputed from the prospective
    ///      liquidity rather than approximated as a token amount.
    /// @param _params The proposed liquidity modification, whose liquidity delta must be a removal.
    /// @return capacity The Supporting Capacity of the predicted post-removal state.
    function prospectiveSupportingCapacityAfterLiquidityRemoval(ModifyLiquidityParams calldata _params)
        external
        view
        returns (uint256 capacity)
    {
        (uint160 sqrtPriceX96, uint128 liquidity) = _prospectiveLiquidityRemovalState(_params);

        capacity = _prospectiveSupportingCapacity(sqrtPriceX96, liquidity);
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the required Standby Hook callback-permission surface.
    /// @dev All return-delta / custom-accounting permissions are disabled: Standby enforces backing,
    ///      it does not take custom accounting deltas.
    /// @return permissions The Hook permissions Uniswap v4 validates against the deployed address.
    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        permissions = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Classifies a proposed swap and decides whether it may become an authoritative pool transition.
    ///
    ///      Classification is by causal context, never by who asked. With no O2 operation in progress every
    ///      swap is an ordinary O3 transition and is enforced as one, whoever routed it and whatever
    ///      `hookData` it carries. Once an authorization exists the service is inside an O2 causal
    ///      exclusion zone, and the only swap that may proceed is the exact protected execution that
    ///      authorization admits; anything else is refused rather than quietly re-classified.
    ///
    ///      The exclusion is not tidiness. O2 was authorized against the prospective post-fulfillment
    ///      condition `S' >= O - q`, while an ordinary transition must satisfy `S' >= O`. Letting a
    ///      mismatching swap fall through to the ordinary rule while an authorization is unresolved would
    ///      break the causal continuity between the state the authorization was decided on and the
    ///      execution it authorized.
    function _beforeSwap(address _sender, PoolKey calldata _key, SwapParams calldata _params, bytes calldata)
        internal
        virtual
        override
        returns (bytes4 selector, BeforeSwapDelta delta, uint24 lpFeeOverride)
    {
        _requireConfiguredServicePool(_key);

        if (_exerciseAuthorizationState() == ExerciseAuthorizationState.EMPTY) {
            _requireAdmissibleOrdinarySwap(_sender, _params);
        } else {
            _beginProtectedExecution(_sender, _params);
        }

        (selector, delta, lpFeeOverride) = (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @dev Completes a swap callback: inert for an ordinary transition, authoritative evidence for O2.
    ///
    ///      For an ordinary O3 transition this is completion plumbing and nothing else. The backing
    ///      decision was already made, from derived prospective state, before the transition became
    ///      authoritative, and nothing here is execution evidence, fulfillment proof, or settlement.
    ///
    ///      For the one protected execution this Hook accepted, it is the only place execution evidence can
    ///      come from. The PoolManager has performed the swap by the time this runs and hands over its own
    ///      `BalanceDelta`, which is the sole authoritative statement of what the pool actually produced.
    ///
    ///      It takes no delta, because the Hook declares no return-delta permission.
    function _afterSwap(
        address _sender,
        PoolKey calldata _key,
        SwapParams calldata _params,
        BalanceDelta _delta,
        bytes calldata
    ) internal virtual override returns (bytes4 selector, int128 hookDelta) {
        if (_exerciseAuthorizationState() != ExerciseAuthorizationState.EMPTY) {
            _recordProtectedExecution(_sender, _key, _params, _delta);
        }

        (selector, hookDelta) = (IHooks.afterSwap.selector, int128(0));
    }

    /// @dev Decides whether a proposed ordinary swap may become an authoritative pool transition.
    ///
    ///      The decision sequence separates four questions that must never merge. Whether the callback is
    ///      authentic: `onlyPoolManager` answers that before this runs. Whether the transition belongs to
    ///      this service and arrives through the perimeter that may authenticate its participant.
    ///      Whether the originating user may trade at all. And finally what the transition would do to the
    ///      economics, which is derived rather than asserted: the F5 prospective-state derivation predicts
    ///      the exact post-swap state, the same capacity kernel measures it, and the authoritative current
    ///      Aggregate Capacity Obligation is what it is compared against.
    ///
    ///      Two rejections that look alike are deliberately distinct. A predicted price outside the closed
    ///      service domain is refused as a realization-domain violation, not reported as some quantity of
    ///      capacity, and that refusal does not weaken when the obligation happens to be zero. Insufficient
    ///      prospective backing is refused as an economic violation. Neither substitutes for the other.
    ///
    ///      One derivation and one comparison serve both directions, rather than a protected-direction rule
    ///      plus a mirrored opposite-direction one. The protected direction is the case that ordinarily
    ///      consumes capacity, but "ordinarily" is not "always": an opposite-direction swap that reaches a
    ///      liquidity boundary sitting exactly on a service boundary crosses it, and leaves less active
    ///      liquidity behind than it found. SPEC-B10 governs any transition whose Supporting Capacity can
    ///      change, so the same comparison covers both, and covering both is what makes the enforcement
    ///      surface complete rather than merely correct on the expected path. This is not symmetry for its
    ///      own sake: there is no second formula here, only one authoritative derivation used once.
    function _requireAdmissibleOrdinarySwap(address _sender, SwapParams calldata _params) internal view {
        if (_sender != i_trustedUniversalRouter) revert StandbyHook__UntrustedSwapPerimeter(_sender);

        address actor = _authenticatedActor(_sender);

        if (!_service.registry.canSwap(actor)) revert StandbyHook__TraderNotEligible(actor);

        (uint160 sqrtPriceX96, uint128 liquidity) = _prospectiveSwapState(_params);

        _requireProspectiveBacking(sqrtPriceX96, liquidity);
    }

    /// @dev Accepts a proposed swap as the one protected execution the active authorization admits.
    ///
    ///      What it establishes is exactly this: the swap in front of the PoolManager right now is the
    ///      execution attempt this Hook authorized. What it deliberately does not establish is that any
    ///      execution happened. Router intent is not execution proof, a requested exact output is not an
    ///      actual output, and a successful `beforeSwap` is not AMM execution — so this reaches `EXECUTING`
    ///      and can reach nothing further.
    ///
    ///      The state requirement is the whole causal restriction in one place. `AUTHORIZED` is the only
    ///      position that admits a swap: an `AUTHORIZING` context has not decided yet, an `EXECUTING` one
    ///      already has its swap in flight, and an `EXECUTED` one has already had it. A second swap, a
    ///      nested swap, and a swap after execution are therefore the same refusal rather than three
    ///      special cases.
    function _beginProtectedExecution(address _sender, SwapParams calldata _params) internal {
        ExerciseAuthorizationContext memory context = _readExerciseAuthorization();

        if (context.state != ExerciseAuthorizationState.AUTHORIZED) {
            revert StandbyHook__ExerciseExecutionNotAuthorized(context.state);
        }

        _requireAuthorizedProtectedExecution(_sender, _params, context);

        _writeExerciseAuthorizationState(ExerciseAuthorizationState.EXECUTING);
    }

    /// @dev Establishes that the accepted protected execution actually produced exactly `q`.
    ///
    ///      This is the only transition to execution evidence, and it consumes exactly one authoritative
    ///      fact that no earlier stage had: the PoolManager's own `BalanceDelta` for the swap it has just
    ///      performed. Nothing else here is new. The context is the one the authorization wrote, and the
    ///      callback facts are revalidated against it rather than assumed from the presence of `EXECUTING`,
    ///      so evidence cannot be satisfied by an unrelated callback that merely arrives while a protected
    ///      execution is in flight.
    ///
    ///      The comparison is exact and signed. Only the protected-output side of the delta counts, only a
    ///      positive amount is output owed to the swap caller, and only exactly `q` is the authorized
    ///      quantity — so a partial exact-output execution, an amount on the input side, and a wrong-signed
    ///      delta all fail it. A partial execution is a failure of the complete O2 rather than a smaller
    ///      exercise (RR-O2-9), and refusing it here reverts the containing transaction with it.
    ///
    ///      What `EXECUTED` does not mean is as load-bearing as what it does. The input debt is unpaid, the
    ///      exerciser's cost bound is unexamined, the Beneficiary has received nothing, the commitment is
    ///      unfulfilled, and Remaining Entitlement and Aggregate Capacity Obligation are untouched.
    function _recordProtectedExecution(
        address _sender,
        PoolKey calldata _key,
        SwapParams calldata _params,
        BalanceDelta _delta
    ) internal {
        ExerciseAuthorizationContext memory context = _readExerciseAuthorization();

        if (context.state != ExerciseAuthorizationState.EXECUTING) {
            revert StandbyHook__NoProtectedExecutionInFlight(context.state);
        }

        _requireConfiguredServicePool(_key);
        _requireAuthorizedProtectedExecution(_sender, _params, context);

        int256 actualProtectedOutput = _actualProtectedOutput(_delta);

        if (actualProtectedOutput != context.q.toInt256()) {
            revert StandbyHook__ProtectedOutputNotExecuted(actualProtectedOutput, context.q);
        }

        _writeExerciseAuthorizationState(ExerciseAuthorizationState.EXECUTED);
    }

    /// @dev Requires a callback swap to be exactly the protected execution a causal context admits.
    ///
    ///      Classification is conjunctive, and this is the conjunction. The account that asked the
    ///      PoolManager to perform the swap must be the ExerciseRouter the context bound — necessary, never
    ///      sufficient — and the proposed swap must equal the canonical protected execution reconstructed
    ///      from the immutable service basis and the authorized quantity. That single equality is where
    ///      protected direction, exact-output mode, the exact quantity `q`, and the configured
    ///      qualification boundary `P_Q` are all decided, because they are not four independent policies:
    ///      they are the one execution the service defines, and comparing against it is what makes an
    ///      alternative price limit, an exact-input substitution, an opposite direction, and a `q ± 1`
    ///      substitution the same rejection.
    ///
    ///      The pool is not compared here. Every path into this function has already established that the
    ///      callback concerns the configured service pool, and a context's `serviceId` is that same pool by
    ///      construction: the service is one-shot and immutable, and the authorization stamped the context
    ///      with it.
    function _requireAuthorizedProtectedExecution(
        address _sender,
        SwapParams calldata _params,
        ExerciseAuthorizationContext memory _context
    ) internal view {
        if (_sender != _context.exerciseRouter) revert StandbyHook__NotAuthorizedExerciseExecutor(_sender);

        SwapParams memory authorized = _canonicalProtectedExecution(_context.q);

        if (
            _params.zeroForOne != authorized.zeroForOne || _params.amountSpecified != authorized.amountSpecified
                || _params.sqrtPriceLimitX96 != authorized.sqrtPriceLimitX96
        ) {
            revert StandbyHook__NotTheAuthorizedProtectedExecution(
                _params.zeroForOne, _params.amountSpecified, _params.sqrtPriceLimitX96
            );
        }
    }

    /// @dev Reads the protected-output side of an executed swap's authoritative PoolManager delta.
    ///
    ///      Which side that is follows from the configured protected direction and from nothing else:
    ///      protected `zeroForOne` takes currency0 in and produces currency1, protected `oneForZero` is its
    ///      mirror. The value is returned signed and unmodified, because its sign is authoritative — a
    ///      positive amount is currency the PoolManager owes the swap caller, which is what "produced" means
    ///      here, and a negative amount is currency the caller owes. Taking an absolute value would turn a
    ///      debt into a delivery.
    function _actualProtectedOutput(BalanceDelta _delta) internal view returns (int256 actualProtectedOutput) {
        actualProtectedOutput = _service.protectedZeroForOne ? _delta.amount1() : _delta.amount0();
    }

    /// @dev Reconstructs the one protected execution the service admits for a quantity.
    ///
    ///      The protected execution is not a free choice and is never taken from a request. It is the one
    ///      the frozen realization defines: the service's own protected direction, exact-output for exactly
    ///      `_q`, bounded by the configured qualification boundary `P_Q` (RR-O2-7, RR-O2-8). Every consumer
    ///      of that shape — the authorization backing derivation, the execution classifier, the evidence
    ///      revalidation, and the router's own proposal — resolves through this one reconstruction, so the
    ///      quantity that was authorized and the quantity that is executable are the same question.
    function _canonicalProtectedExecution(uint256 _q) internal view returns (SwapParams memory params) {
        params = SwapParams({
            zeroForOne: _service.protectedZeroForOne,
            amountSpecified: _q.toInt256(),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(_service.tickQ)
        });
    }

    /// @dev Decides whether a proposed liquidity addition may become an authoritative pool transition.
    ///
    ///      Addition is permissioned on the way in: introducing or increasing liquidity requires current
    ///      liquidity-action eligibility of the authenticated originating user, which is a different
    ///      permission domain from trader eligibility and from Beneficiary eligibility.
    ///
    ///      Topology is enforced independently of backing. An addition cannot reduce Supporting Capacity,
    ///      so no prospective backing comparison is manufactured for it — but it can initialize a liquidity
    ///      boundary strictly inside the service domain, which would destroy the single-active-region basis
    ///      every authoritative derivation depends on. That refusal is a realization-domain requirement and
    ///      holds whatever the current obligation is.
    function _beforeAddLiquidity(
        address _sender,
        PoolKey calldata _key,
        ModifyLiquidityParams calldata _params,
        bytes calldata
    ) internal view virtual override returns (bytes4 selector) {
        _requireConfiguredServicePool(_key);

        if (_sender != i_trustedPositionManager) revert StandbyHook__UntrustedLiquidityPerimeter(_sender);

        address actor = _authenticatedActor(_sender);

        if (!_service.registry.canProvideLiquidity(actor)) revert StandbyHook__LiquidityProviderNotEligible(actor);

        if (
            ServiceDomain.introducesInteriorBoundary(
                _params.tickLower, _params.tickUpper, _service.tickQ, _service.tickO
            )
        ) {
            revert StandbyHook__ProhibitedInteriorLiquidityBoundary(_params.tickLower, _params.tickUpper);
        }

        selector = IHooks.beforeAddLiquidity.selector;
    }

    /// @dev Decides whether a proposed liquidity reduction may become an authoritative pool transition.
    ///
    ///      Removal is deliberately not the mirror image of addition. Liquidity-action eligibility governs
    ///      introducing liquidity, not keeping the ability to withdraw it: a provider who loses eligibility
    ///      after contributing must still be able to exit, or eligibility administration would become a
    ///      capital trap and a backdoor over property that was never Standby's to hold. No eligibility
    ///      predicate is therefore consulted here, and — because none is — no originating user is
    ///      recovered. Recovering one would imply an authorization question that does not exist. The
    ///      trusted execution perimeter is still authenticated, because the permissioned MVP admits
    ///      authoritative pool transitions only through it.
    ///
    ///      What removal is subject to is backing, because it can reduce active liquidity and therefore
    ///      Supporting Capacity. The F5 prospective-removal derivation supplies the post-removal state and
    ///      the same capacity kernel measures it.
    ///
    ///      Uniswap routes every non-positive liquidity delta here, including the zero-delta operation that
    ///      collects fees. That operation changes neither active liquidity nor price, so it is classified
    ///      by its actual effect rather than by which callback dispatched it: its prospective state is the
    ///      present state, and it is neither refused nor given economic meaning it does not have.
    function _beforeRemoveLiquidity(
        address _sender,
        PoolKey calldata _key,
        ModifyLiquidityParams calldata _params,
        bytes calldata
    ) internal view virtual override returns (bytes4 selector) {
        _requireConfiguredServicePool(_key);

        if (_sender != i_trustedPositionManager) revert StandbyHook__UntrustedLiquidityPerimeter(_sender);

        uint160 sqrtPriceX96;
        uint128 liquidity;

        if (_params.liquidityDelta == 0) {
            (, sqrtPriceX96,, liquidity) = _currentPoolState();
        } else {
            (sqrtPriceX96, liquidity) = _prospectiveLiquidityRemovalState(_params);
        }

        _requireProspectiveBacking(sqrtPriceX96, liquidity);

        selector = IHooks.beforeRemoveLiquidity.selector;
    }

    /// @dev Requires the callback to concern the activated Protected Execution Service of this Hook.
    ///
    ///      A Hook address encodes its callback permissions, so anyone may initialize an unrelated pool
    ///      that binds this Hook. Such a pool is not this service: its state is not the state Standby
    ///      derives from, and enforcing the configured service basis against it would be enforcing the
    ///      wrong economics. It is refused instead.
    function _requireConfiguredServicePool(PoolKey calldata _key) internal view {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();

        PoolId poolId = _key.toId();

        if (PoolId.unwrap(poolId) != PoolId.unwrap(_serviceId())) {
            revert StandbyHook__PoolIsNotConfiguredService(poolId);
        }
    }

    /// @dev Obtains the authenticated originating user from an already-authenticated trusted perimeter.
    ///
    ///      The order matters and is the whole point: the caller has established that `_perimeter` is
    ///      exactly the immutable perimeter configured for this transition family before this runs. Asking
    ///      an arbitrary callback sender who its user is, and only then deciding whether to trust it, would
    ///      let any contract that implements the interface nominate an economic actor.
    ///
    ///      A trusted perimeter with no routed action in flight fails closed rather than answering, so an
    ///      absent execution context cannot produce an actor.
    function _authenticatedActor(address _perimeter) internal view returns (address actor) {
        actor = IActorAwarePeriphery(_perimeter).msgSender();
    }

    /// @dev Requires a predicted post-transition state to keep the service backed.
    ///
    ///      Both sides of the comparison are authoritative derivations rather than assertions: prospective
    ///      Supporting Capacity comes from the derived post-transition state through the one capacity
    ///      kernel, and the Aggregate Capacity Obligation is derived from the persisted commitment facts
    ///      over the bounded reference index at the current time. Nothing here knows or cares what that
    ///      obligation currently is.
    ///
    ///      Exact sufficiency is accepted: a transition that leaves capacity exactly equal to the
    ///      obligation preserves backing and must not be refused.
    function _requireProspectiveBacking(uint160 _sqrtPriceX96, uint128 _liquidity) internal view {
        uint256 prospectiveCapacity = _prospectiveSupportingCapacity(_sqrtPriceX96, _liquidity);
        uint256 obligation = _aggregateObligation();

        if (prospectiveCapacity < obligation) {
            revert StandbyHook__InsufficientProspectiveBacking(prospectiveCapacity, obligation);
        }
    }

    /// @dev Claims the single O2 authorization slot for this transaction, before anything external is read.
    ///
    ///      The claim precedes the authenticated-actor query, the registry read, and the PoolManager reads
    ///      the backing derivation performs, which is the whole point of its position. Those reads leave
    ///      this Hook, and an authorization that had not yet marked itself in flight would let a second one
    ///      start, complete, and be overwritten by the first when it returned — two authorizations, one
    ///      surviving context, and no way for a later stage to tell which attempt it belongs to.
    ///
    ///      A second top-level attempt made after one has already succeeded fails here too, against
    ///      `AUTHORIZED`. The two cases are one restriction: while an O2 causal context is unresolved, no
    ///      other authorization may become active.
    function _beginExerciseAuthorization() internal {
        if (_exerciseAuthorizationState() != ExerciseAuthorizationState.EMPTY) {
            revert StandbyHook__ExerciseAuthorizationAlreadyActive();
        }

        _writeExerciseAuthorizationState(ExerciseAuthorizationState.AUTHORIZING);
    }

    /// @dev Requires a commitment to be currently valid and currently within its admitted exercise window.
    ///
    ///      Two predicates rather than one, because they are different facts with different consequences
    ///      and a caller deserves to be told which one it failed. Validity ending is permanent and releases
    ///      the Capacity Obligation; a window that has not opened is temporary, releases nothing, and
    ///      leaves the commitment fully binding.
    ///
    ///      Both are asked of the F5 kernel rather than restated here, so authorization and every other
    ///      consumer agree by construction about what the half-open window means at its endpoints.
    function _requireExercisableCommitment(uint256 _commitmentId, uint64 _exercisableFrom, uint64 _validUntil)
        internal
        view
    {
        if (!StandbyMath.isValid(_validUntil, block.timestamp)) {
            revert StandbyHook__CommitmentNotValid(_commitmentId, _validUntil, block.timestamp);
        }

        if (!StandbyMath.isTemporallyExerciseQualified(_exercisableFrom, _validUntil, block.timestamp)) {
            revert StandbyHook__CommitmentNotExercisable(_commitmentId, _exercisableFrom, _validUntil, block.timestamp);
        }
    }

    /// @dev Requires a complete successful exercise of `q` to leave the service backed.
    ///
    ///      Both sides are authoritative derivations of a *post-exercise* world. The capacity side is the
    ///      F5 prospective derivation applied to the exact protected execution this authorization admits;
    ///      the obligation side is the current authoritative aggregate less the quantity a complete
    ///      successful exercise would discharge.
    ///
    ///      The subtraction is checked and is meant to be. A commitment that has reached this point is
    ///      valid with positive Remaining Entitlement, so it is not permanently non-binding, so the bounded
    ///      index cannot have reclaimed its reference and its full remainder is inside the aggregate:
    ///      `q <= Remaining <= O` holds structurally. Should any of that ever cease to be true, failing
    ///      closed on the arithmetic is the correct outcome, and clamping the difference at zero would
    ///      instead weaken the requirement into one that always passes.
    ///
    ///      Exact sufficiency passes: an exercise that leaves capacity exactly equal to the obligation it
    ///      leaves behind has preserved backing.
    function _requireProspectiveExerciseBacking(uint256 _q) internal view {
        uint256 prospectiveCapacity = _prospectiveExerciseCapacity(_q);
        uint256 prospectiveObligation = _aggregateObligation() - _q;

        if (prospectiveCapacity < prospectiveObligation) {
            revert StandbyHook__InsufficientProspectiveExerciseBacking(prospectiveCapacity, prospectiveObligation);
        }
    }

    /// @dev Derives the Supporting Capacity the canonical protected exercise of exactly `q` would leave.
    ///
    ///      The execution being measured is the one the service admits, reconstructed by the single
    ///      production reconstruction rather than restated here — so the swap this authorization is decided
    ///      against is byte-for-byte the swap the execution classifier will later require.
    ///
    ///      No arithmetic happens here. The prospective state comes from the same F5 derivation ordinary
    ///      transitions use, and the same capacity kernel measures it, so an authorization decision and an
    ///      enforcement decision can never disagree about what a state is worth.
    function _prospectiveExerciseCapacity(uint256 _q) internal view returns (uint256 capacity) {
        (uint160 sqrtPriceX96, uint128 liquidity) = _prospectiveSwapState(_canonicalProtectedExecution(_q));

        capacity = _prospectiveSupportingCapacity(sqrtPriceX96, liquidity);
    }

    /// @dev Writes the complete authorized causal context, replacing the in-flight marker.
    function _writeExerciseAuthorization(ExerciseAuthorizationContext memory _context) internal {
        _writeExerciseAuthorizationState(_context.state);

        _writeAuthorizationWord(AUTHORIZATION_SERVICE_ID_OFFSET, uint256(PoolId.unwrap(_context.serviceId)));
        _writeAuthorizationWord(AUTHORIZATION_COMMITMENT_ID_OFFSET, _context.commitmentId);
        _writeAuthorizationWord(AUTHORIZATION_EXERCISE_ROUTER_OFFSET, uint256(uint160(_context.exerciseRouter)));
        _writeAuthorizationWord(AUTHORIZATION_EXERCISER_OFFSET, uint256(uint160(_context.exerciser)));
        _writeAuthorizationWord(AUTHORIZATION_BENEFICIARY_OFFSET, uint256(uint160(_context.beneficiary)));
        _writeAuthorizationWord(AUTHORIZATION_Q_OFFSET, _context.q);
    }

    /// @dev Reads the complete causal context. Outside an authorized exercise every field is its zero value.
    function _readExerciseAuthorization() internal view returns (ExerciseAuthorizationContext memory context) {
        context = ExerciseAuthorizationContext({
            state: _exerciseAuthorizationState(),
            serviceId: PoolId.wrap(bytes32(_readAuthorizationWord(AUTHORIZATION_SERVICE_ID_OFFSET))),
            commitmentId: _readAuthorizationWord(AUTHORIZATION_COMMITMENT_ID_OFFSET),
            exerciseRouter: address(uint160(_readAuthorizationWord(AUTHORIZATION_EXERCISE_ROUTER_OFFSET))),
            exerciser: address(uint160(_readAuthorizationWord(AUTHORIZATION_EXERCISER_OFFSET))),
            beneficiary: address(uint160(_readAuthorizationWord(AUTHORIZATION_BENEFICIARY_OFFSET))),
            q: _readAuthorizationWord(AUTHORIZATION_Q_OFFSET)
        });
    }

    /// @dev Reads the lifecycle position of the causal context.
    function _exerciseAuthorizationState() internal view returns (ExerciseAuthorizationState state) {
        state = ExerciseAuthorizationState(_readAuthorizationWord(AUTHORIZATION_STATE_OFFSET));
    }

    /// @dev Writes the lifecycle position of the causal context.
    function _writeExerciseAuthorizationState(ExerciseAuthorizationState _state) internal {
        _writeAuthorizationWord(AUTHORIZATION_STATE_OFFSET, uint256(_state));
    }

    /// @dev Writes one word of the transient causal context.
    function _writeAuthorizationWord(uint256 _offset, uint256 _value) internal {
        bytes32 slot = _authorizationSlot(_offset);

        assembly ("memory-safe") {
            tstore(slot, _value)
        }
    }

    /// @dev Reads one word of the transient causal context.
    function _readAuthorizationWord(uint256 _offset) internal view returns (uint256 value) {
        bytes32 slot = _authorizationSlot(_offset);

        assembly ("memory-safe") {
            value := tload(slot)
        }
    }

    /// @dev Resolves the transient slot of one causal-context field.
    function _authorizationSlot(uint256 _offset) internal pure returns (bytes32 slot) {
        slot = bytes32(uint256(EXERCISE_AUTHORIZATION_BASE_SLOT) + _offset);
    }

    /// @dev Validates the commitment-specific terms a proposed admission supplies.
    ///
    ///      These are the terms and nothing else: no economics, no eligibility, no capacity, no reference
    ///      availability. Each rejection is its own condition with its own reason, so a caller learns
    ///      which term was inadmissible rather than that "something" was.
    ///
    ///      An already-open exercise window is deliberately admissible. `exercisableFrom` in the past is
    ///      an ordinary admitted term, not a defect: what admission requires is that the window can be
    ///      open at some point before validity ends, and that validity has not already ended. Requiring a
    ///      future `exercisableFrom` would refuse commitments the frozen semantics permit.
    ///
    ///      Temporal validity is asked of the F5 kernel rather than restated here, so admission and every
    ///      later derivation agree by construction about what the half-open window means at its endpoint.
    function _validateCommitmentTerms(
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil
    ) internal view {
        if (_beneficiary == address(0)) revert StandbyHook__InvalidBeneficiary();
        if (_exerciseAuthority == address(0)) revert StandbyHook__InvalidExerciseAuthority();
        if (_originalEntitlement == 0) revert StandbyHook__InvalidOriginalEntitlement();

        if (_validUntil <= _exercisableFrom) {
            revert StandbyHook__InvalidCommitmentWindow(_exercisableFrom, _validUntil);
        }

        if (!StandbyMath.isValid(_validUntil, block.timestamp)) {
            revert StandbyHook__CommitmentAlreadyInvalid(_validUntil, block.timestamp);
        }
    }

    /// @dev Locates a bounded reference slot a new commitment may occupy.
    ///
    ///      Two structurally different candidates, in one deliberate order. An empty slot is preferred,
    ///      because taking one displaces nothing. Only when the index is structurally full does the scan
    ///      ask an economic question, and it asks the F5 kernel: a slot may be taken over exactly when its
    ///      commitment is permanently released from Capacity Obligation, which is the same predicate that
    ///      makes that commitment's obligation zero. Reclaimability is therefore not a second notion of
    ///      terminality living beside the obligation derivation — it is that derivation's own predicate
    ///      (RR-O1-6, RR-O1-8).
    ///
    ///      A commitment that is merely not yet exercisable, or whose Beneficiary is currently
    ///      ineligible, is not reclaimable and cannot be displaced however full the index is.
    ///
    ///      Reuse costs the displaced commitment its reference, never its record: history is permanent
    ///      and stays readable under its own identity (RR-O1-7).
    function _admissibleReferenceSlot() internal view returns (bool found, uint256 slot) {
        (found, slot) = _enforcementRefs.firstEmptySlot();

        if (found) return (found, slot);

        uint256 timestamp = block.timestamp;

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            Commitment storage record = _commitments[_enforcementRefs[i]];

            if (StandbyMath.isPermanentlyNonBinding(record.remainingEntitlement, record.validUntil, timestamp)) {
                return (true, i);
            }
        }
    }

    /// @dev Allocates a permanent identity and writes the commitment facts under it.
    ///
    ///      This is storage mechanics, not admission. It authenticates nobody, validates no economic
    ///      term, and derives nothing: it records exactly the facts it is handed. Whether those facts
    ///      describe an authentic, sufficiently backed Standby commitment is `establishCommitment`'s
    ///      question, and it is answered in full before this runs.
    ///
    ///      The identity is consumed before the record is written and the counter only increases, so a
    ///      reverted surrounding transaction releases the identity with the rest of the state and a
    ///      committed one retires it forever. Either way an identity is never reused.
    /// @param _commitment The complete commitment facts to record.
    /// @return commitmentId The permanent identity allocated to the record.
    function _recordCommitment(Commitment memory _commitment) internal returns (uint256 commitmentId) {
        commitmentId = _nextCommitmentId;

        _nextCommitmentId = commitmentId + 1;

        _commitments[commitmentId] = _commitment;
    }

    /// @dev Writes the Remaining Entitlement of an existing commitment, leaving every other fact intact.
    ///
    ///      Remaining Entitlement is the one mutable commitment fact, and this is the only mechanism that
    ///      changes it. The mechanism applies no economic rule — it does not decide what the new value
    ///      should be, does not require it to decrease, and does not bound it by the admitted extent. The
    ///      authoritative reduction and its causal justification belong to the fulfillment slice.
    ///
    ///      Expiry and eligibility deliberately have no path to this function. A commitment that has
    ///      passed `validUntil`, or whose Beneficiary has lost eligibility, keeps the Remaining
    ///      Entitlement it had: those conditions change what the facts mean, never the facts themselves.
    /// @param _commitmentId The identity whose Remaining Entitlement is written.
    /// @param _remainingEntitlement The Remaining Entitlement after this write.
    function _writeRemainingEntitlement(uint256 _commitmentId, uint128 _remainingEntitlement) internal {
        if (!_commitmentExists(_commitmentId)) revert StandbyHook__CommitmentDoesNotExist(_commitmentId);

        _commitments[_commitmentId].remainingEntitlement = _remainingEntitlement;
    }

    /// @dev Writes a commitment identity into one slot of the bounded enforcement-reference index.
    ///
    ///      The write is the single authoritative way the index changes, and it enforces exactly the two
    ///      structural properties the index must have: every nonzero reference resolves to an existing
    ///      historical commitment, and no identity appears in two slots. Both are structural, not
    ///      economic. Whether a slot may be taken over from the commitment currently occupying it is an
    ///      economic judgement, and it is not made here.
    ///
    ///      Writing an occupied slot replaces the reference. It does not touch the replaced commitment's
    ///      historical record, which remains readable and unchanged for the life of the Hook (RR-O1-7).
    /// @param _slot The slot to write, within the bounded index.
    /// @param _commitmentId The existing commitment identity to reference.
    function _writeEnforcementReference(uint256 _slot, uint256 _commitmentId) internal {
        if (_slot >= MAX_LIVE_COMMITMENTS) revert StandbyHook__InvalidEnforcementReferenceSlot(_slot);
        if (!_commitmentExists(_commitmentId)) revert StandbyHook__CommitmentDoesNotExist(_commitmentId);

        (bool alreadyReferenced, uint256 occupiedSlot) = _enforcementRefs.slotOf(_commitmentId);

        if (alreadyReferenced && occupiedSlot != _slot) {
            revert StandbyHook__DuplicateEnforcementReference(_commitmentId, occupiedSlot);
        }

        _enforcementRefs[_slot] = _commitmentId;
    }

    /// @dev Reports whether an identity has been allocated.
    ///
    ///      Judged from the allocation counter rather than from record contents, so existence is a fact
    ///      about identity alone. The reserved sentinel `0` never exists.
    function _commitmentExists(uint256 _commitmentId) internal view returns (bool exists) {
        exists = _commitmentId != 0 && _commitmentId < _nextCommitmentId;
    }

    /// @dev Derives the service identity from the persisted PoolKey.
    ///
    ///      PoolId is never persisted independently, so every consumer that needs it reconstructs it from
    ///      the one authoritative key. Callers are responsible for having established that a service
    ///      exists; an unconfigured Hook would reconstruct the identity of a zero-valued key.
    function _serviceId() internal view returns (PoolId poolId) {
        PoolKey memory key = _service.poolKey;

        poolId = key.toId();
    }

    /// @dev Reads the complete authoritative pool state the capacity derivations consume.
    ///
    ///      The square-root price is taken directly from Slot0 (RR-SC-4). It is deliberately never
    ///      reconstructed from the current tick: a tick identifies the interval a price sits in, not the
    ///      price, so reconstructing it would silently round the derivation basis. The tick is read for
    ///      what it is actually authoritative about — which liquidity ranges are active, and where the
    ///      next swap step begins.
    function _currentPoolState()
        internal
        view
        returns (PoolId poolId, uint160 sqrtPriceX96, int24 tick, uint128 liquidity)
    {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();

        poolId = _serviceId();

        (sqrtPriceX96, tick,,) = poolManager.getSlot0(poolId);

        liquidity = poolManager.getLiquidity(poolId);
    }

    /// @dev Derives current Supporting Capacity from the authoritative present pool state.
    ///
    ///      The present state must lie inside the closed service domain for an authoritative Standby
    ///      capacity to exist at all. A present state outside it is refused rather than reported as zero,
    ///      because those are different facts: zero capacity at `P_Q` is an ordinary valid state, whereas
    ///      a price outside the domain means the derivation basis itself has already been violated.
    function _supportingCapacity() internal view returns (uint256 capacity) {
        (, uint160 sqrtPriceX96,, uint128 liquidity) = _currentPoolState();

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(_service.tickQ, _service.tickO);

        if (!ServiceDomain.containsPrice(sqrtPriceX96, sqrtLowerX96, sqrtUpperX96)) {
            revert StandbyHook__CurrentPriceOutsideServiceDomain(sqrtPriceX96, sqrtLowerX96, sqrtUpperX96);
        }

        capacity = _supportingCapacityFromState(sqrtPriceX96, liquidity);
    }

    /// @dev Derives Supporting Capacity from a predicted post-transition state.
    ///
    ///      There is no separate prospective capacity formula. A prospective state is derived first, and
    ///      then measured by exactly the same kernel that measures the present, which is what makes a
    ///      prediction comparable with the capacity the pool actually reports afterwards.
    function _prospectiveSupportingCapacity(uint160 _sqrtPriceX96, uint128 _liquidity)
        internal
        view
        returns (uint256 capacity)
    {
        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(_service.tickQ, _service.tickO);

        if (!ServiceDomain.containsPrice(_sqrtPriceX96, sqrtLowerX96, sqrtUpperX96)) {
            revert StandbyHook__ProspectivePriceOutsideServiceDomain(_sqrtPriceX96, sqrtLowerX96, sqrtUpperX96);
        }

        capacity = _supportingCapacityFromState(_sqrtPriceX96, _liquidity);
    }

    /// @dev The single composition point between authoritative pool state and the capacity kernel.
    ///
    ///      `sqrtQ` is derived from the persisted canonical boundary tick rather than persisted itself
    ///      (RR-SC-3), and the protected direction — never currency identity or decimals — selects which
    ///      currency the result is denominated in.
    function _supportingCapacityFromState(uint160 _sqrtPriceX96, uint128 _liquidity)
        internal
        view
        returns (uint256 capacity)
    {
        capacity = StandbyMath.supportingCapacity(
            _service.protectedZeroForOne, _sqrtPriceX96, TickMath.getSqrtPriceAtTick(_service.tickQ), _liquidity
        );
    }

    /// @dev Derives the current Capacity Obligation of an existing commitment.
    ///
    ///      Only two authoritative facts participate: Remaining Entitlement and temporal validity.
    ///      Eligibility, exercise authority, and the exercise window are deliberately not inputs, because
    ///      none of them can release backing.
    function _commitmentObligation(uint256 _commitmentId) internal view returns (uint256 obligation) {
        Commitment storage record = _commitments[_commitmentId];

        obligation = StandbyMath.commitmentObligation(record.remainingEntitlement, record.validUntil, block.timestamp);
    }

    /// @dev Derives Aggregate Capacity Obligation over the bounded enforcement-reference index.
    ///
    ///      The scan is bounded by construction and its cost does not grow with commitment history. Each
    ///      nonzero reference resolves to a historical record whose obligation is derived through the one
    ///      kernel; empty slots and terminal commitments contribute nothing, so a stale reference costs a
    ///      read and no economics. Addition is checked, and the sum of at most `MAX_LIVE_COMMITMENTS`
    ///      `uint128` remainders cannot approach the bound in any case.
    ///
    ///      Nothing about the sum depends on slot order.
    function _aggregateObligation() internal view returns (uint256 obligation) {
        uint256 timestamp = block.timestamp;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            uint256 commitmentId = _enforcementRefs[slot];

            if (commitmentId == EMPTY_REFERENCE) continue;

            Commitment storage record = _commitments[commitmentId];

            obligation += StandbyMath.commitmentObligation(record.remainingEntitlement, record.validUntil, timestamp);
        }
    }

    /// @dev Derives the pool state a proposed swap would leave behind.
    ///
    ///      The derivation reproduces the supported Uniswap v4 swap semantics from the exact current
    ///      state rather than estimating a price impact: the same `SwapMath.computeSwapStep`, the same
    ///      effective swap fee including any protocol fee, the same step targets the tick bitmap yields,
    ///      the same tick transitions, and the same loop termination. Reproducing the step traversal is
    ///      not incidental — v4 splits a swap at tick bitmap word edges even where no liquidity boundary
    ///      exists, and a single-step approximation would disagree with real execution by the rounding of
    ///      every skipped step.
    ///
    ///      Two v4 behaviors are consumed as configured facts rather than reproduced. The LP fee is read
    ///      from authoritative Slot0, which is the effective fee under the realization's static-fee model
    ///      and this Hook's absence of any fee override. Custom accounting is structurally excluded,
    ///      because the Hook declares no return-delta permission.
    ///
    ///      v4's own price-limit entry conditions are reproduced too, so the derivation never predicts a
    ///      state for a swap the PoolManager would have rejected outright.
    ///
    ///      The proposal is taken in memory rather than calldata because two kinds of caller ask this
    ///      question: enforcement, which forwards a swap someone else proposed, and O2 authorization, which
    ///      reconstructs the canonical protected execution from the immutable service basis. The derivation
    ///      is the same either way, and there must not be a second one for the reconstructed case.
    /// @param _params The proposed swap.
    /// @return sqrtPriceX96 The predicted post-swap square-root price.
    /// @return liquidity The predicted post-swap active liquidity.
    function _prospectiveSwapState(SwapParams memory _params)
        internal
        view
        returns (uint160 sqrtPriceX96, uint128 liquidity)
    {
        SwapDerivation memory derivation = _beginSwapDerivation(_params);

        while (derivation.amountRemaining != 0 && derivation.sqrtPriceX96 != derivation.sqrtPriceLimitX96) {
            _advanceSwapDerivation(derivation);
        }

        (sqrtPriceX96, liquidity) = (derivation.sqrtPriceX96, derivation.liquidity);
    }

    /// @dev Loads the authoritative starting point of a prospective swap derivation.
    ///
    ///      The effective swap fee is composed exactly as the pool composes it: the LP fee alone when no
    ///      protocol fee is set for this direction, and the pinned combination of the two otherwise. A
    ///      zero-amount swap is short-circuited before the price-limit conditions are reproduced, because
    ///      the pool short-circuits it there too.
    function _beginSwapDerivation(SwapParams memory _params) internal view returns (SwapDerivation memory derivation) {
        if (!_service.configured) revert StandbyHook__ServiceNotConfigured();

        derivation.poolId = _serviceId();
        derivation.tickSpacing = _service.poolKey.tickSpacing;
        derivation.zeroForOne = _params.zeroForOne;
        derivation.exactOutput = _params.amountSpecified > 0;
        derivation.sqrtPriceLimitX96 = _params.sqrtPriceLimitX96;

        uint24 protocolFee;
        uint24 lpFee;

        (derivation.sqrtPriceX96, derivation.tick, protocolFee, lpFee) = poolManager.getSlot0(derivation.poolId);

        uint16 directedProtocolFee =
            _params.zeroForOne ? protocolFee.getZeroForOneFee() : protocolFee.getOneForZeroFee();

        derivation.swapFee = directedProtocolFee == 0 ? lpFee : directedProtocolFee.calculateSwapFee(lpFee);

        derivation.liquidity = poolManager.getLiquidity(derivation.poolId);

        if (_params.amountSpecified == 0) return derivation;

        _requireSupportedSwapPriceLimit(_params.zeroForOne, derivation.sqrtPriceX96, _params.sqrtPriceLimitX96);

        derivation.amountRemaining = _params.amountSpecified;
    }

    /// @dev Advances a prospective swap derivation by exactly one Uniswap v4 swap step.
    ///
    ///      Every effect of the pinned loop body that can influence the final price or active liquidity is
    ///      reproduced here: the step arithmetic, the amount bookkeeping that decides whether the loop
    ///      continues, the tick transition across an initialized boundary, and v4's own post-step tick
    ///      convention — including the preemptive decrement on a downward crossing, which determines
    ///      which bitmap word the next step consults.
    ///
    ///      Fee growth and protocol-fee accrual are deliberately not reproduced: they change what LPs and
    ///      the protocol are owed, not the price or the active liquidity, and Supporting Capacity depends
    ///      only on the latter.
    function _advanceSwapDerivation(SwapDerivation memory _derivation) internal view {
        if (_derivation.steps == MAX_PROSPECTIVE_SWAP_STEPS) {
            revert StandbyHook__ProspectiveSwapStepBoundExceeded(MAX_PROSPECTIVE_SWAP_STEPS);
        }

        ++_derivation.steps;

        uint160 sqrtPriceStartX96 = _derivation.sqrtPriceX96;

        (int24 tickNext, bool initialized) =
            _nextSwapTargetTick(_derivation.poolId, _derivation.tick, _derivation.tickSpacing, _derivation.zeroForOne);

        uint160 sqrtPriceNextX96 = TickMath.getSqrtPriceAtTick(tickNext);

        {
            uint256 amountIn;
            uint256 amountOut;
            uint256 feeAmount;

            (_derivation.sqrtPriceX96, amountIn, amountOut, feeAmount) = SwapMath.computeSwapStep(
                _derivation.sqrtPriceX96,
                SwapMath.getSqrtPriceTarget(_derivation.zeroForOne, sqrtPriceNextX96, _derivation.sqrtPriceLimitX96),
                _derivation.liquidity,
                _derivation.amountRemaining,
                _derivation.swapFee
            );

            _derivation.amountRemaining = _derivation.exactOutput
                ? _derivation.amountRemaining - amountOut.toInt256()
                : _derivation.amountRemaining + (amountIn + feeAmount).toInt256();
        }

        if (_derivation.sqrtPriceX96 == sqrtPriceNextX96) {
            if (initialized) {
                (, int128 liquidityNet) = poolManager.getTickLiquidity(_derivation.poolId, tickNext);

                _derivation.liquidity =
                    LiquidityMath.addDelta(_derivation.liquidity, _derivation.zeroForOne ? -liquidityNet : liquidityNet);
            }

            _derivation.tick = _derivation.zeroForOne ? tickNext - 1 : tickNext;
        } else if (_derivation.sqrtPriceX96 != sqrtPriceStartX96) {
            _derivation.tick = TickMath.getTickAtSqrtPrice(_derivation.sqrtPriceX96);
        }
    }

    /// @dev Derives the pool state a proposed liquidity removal would leave behind.
    ///
    ///      A removal cannot move the square-root price, so the entire question is whether the removed
    ///      range is active at the authoritative current tick. Capacity is afterwards recomputed from the
    ///      prospective liquidity rather than approximated as a withdrawn token amount.
    /// @param _params The proposed liquidity modification.
    /// @return sqrtPriceX96 The unchanged authoritative square-root price.
    /// @return liquidity The predicted post-removal active liquidity.
    function _prospectiveLiquidityRemovalState(ModifyLiquidityParams calldata _params)
        internal
        view
        returns (uint160 sqrtPriceX96, uint128 liquidity)
    {
        if (_params.liquidityDelta >= 0) revert StandbyHook__NotALiquidityRemoval(_params.liquidityDelta);

        int24 tick;

        (, sqrtPriceX96, tick, liquidity) = _currentPoolState();

        liquidity = StandbyMath.liquidityAfterRemoval(
            liquidity, tick, _params.tickLower, _params.tickUpper, uint256(-_params.liquidityDelta).toUint128()
        );
    }

    /// @dev Locates the next candidate swap-step target, reading the authoritative tick bitmap.
    ///
    ///      The bitmap word is read from PoolManager and the search over it is performed by the pure
    ///      kernel, so the state read and the arithmetic stay on their own sides of the boundary. The
    ///      min/max clamping mirrors the pinned swap loop, which applies it because the bitmap itself is
    ///      unaware of the tick bounds.
    function _nextSwapTargetTick(PoolId _poolId, int24 _tick, int24 _tickSpacing, bool _zeroForOne)
        internal
        view
        returns (int24 tickNext, bool initialized)
    {
        (int16 wordPos, int24 compressed, uint8 bitPos) =
            StandbyMath.bitmapSearchPosition(_tick, _tickSpacing, _zeroForOne);

        uint256 word = poolManager.getTickBitmap(_poolId, wordPos);

        (tickNext, initialized) = StandbyMath.nextTickWithinOneWord(word, compressed, bitPos, _tickSpacing, _zeroForOne);

        if (tickNext <= TickMath.MIN_TICK) tickNext = TickMath.MIN_TICK;
        if (tickNext >= TickMath.MAX_TICK) tickNext = TickMath.MAX_TICK;
    }

    /// @dev Reproduces the price-limit conditions Uniswap v4 imposes on a swap before it begins.
    function _requireSupportedSwapPriceLimit(bool _zeroForOne, uint160 _sqrtPriceX96, uint160 _sqrtPriceLimitX96)
        internal
        pure
    {
        bool supported = _zeroForOne
            ? _sqrtPriceLimitX96 < _sqrtPriceX96 && _sqrtPriceLimitX96 > TickMath.MIN_SQRT_PRICE
            : _sqrtPriceLimitX96 > _sqrtPriceX96 && _sqrtPriceLimitX96 < TickMath.MAX_SQRT_PRICE;

        if (!supported) {
            revert StandbyHook__UnsupportedSwapPriceLimit(_zeroForOne, _sqrtPriceX96, _sqrtPriceLimitX96);
        }
    }

    /// @dev Validates the proposed service geometry against the authoritative pool environment.
    ///
    ///      `tickQ` and `tickO` are direction-relative semantic boundaries, not numerical low/high
    ///      positions (RR-SC-5): protected `zeroForOne` requires `tickQ < tickO`, protected
    ///      `oneForZero` requires `tickQ > tickO`. Both must be valid, tick-spacing-aligned Uniswap
    ///      ticks (RR-SC-3).
    ///
    ///      The service domain is closed (RR-SC-6), so the authoritative current price may lie strictly
    ///      inside it or exactly on either boundary. Containment is evaluated in square-root price
    ///      space rather than in tick space, because a current tick equal to a boundary tick does not
    ///      imply a current price at or below that boundary's price.
    function _validateServiceDomain(
        int24 _tickSpacing,
        bool _protectedZeroForOne,
        int24 _tickQ,
        int24 _tickO,
        uint160 _sqrtPriceX96
    ) internal pure {
        _validateServiceTick(_tickQ, _tickSpacing);
        _validateServiceTick(_tickO, _tickSpacing);

        if (!ServiceDomain.isDirectionConsistent(_protectedZeroForOne, _tickQ, _tickO)) {
            revert StandbyHook__InvalidServiceDomainOrder(_protectedZeroForOne, _tickQ, _tickO);
        }

        (uint160 sqrtLowerX96, uint160 sqrtUpperX96) = ServiceDomain.sqrtBounds(_tickQ, _tickO);

        if (!ServiceDomain.containsPrice(_sqrtPriceX96, sqrtLowerX96, sqrtUpperX96)) {
            revert StandbyHook__CurrentPriceOutsideServiceDomain(_sqrtPriceX96, sqrtLowerX96, sqrtUpperX96);
        }
    }

    /// @dev Requires the proposed immutable domain to be prospectively derivable within the supported
    ///      bound.
    ///
    ///      Prospective backing enforcement depends on deriving the exact post-transition v4 state, and
    ///      that derivation walks the same bounded step traversal Uniswap walks. A domain wide enough — in
    ///      tick-bitmap words, which is boundary ticks and tick spacing together — to demand more steps
    ///      than the realization supports would be a service whose ordinary supported operations could not
    ///      be authoritatively evaluated. The service basis is immutable, so nothing could repair that
    ///      afterwards.
    ///
    ///      The check therefore belongs here, before any authoritative persistence, rather than being
    ///      discovered at runtime by an already-activated service. `ServiceDomain` derives the topology
    ///      fact; this Hook owns the supported bound and the consequence.
    function _validateProspectiveDerivability(int24 _tickQ, int24 _tickO, int24 _tickSpacing) internal pure {
        uint256 demand = ServiceDomain.prospectiveTraversalDemand(_tickQ, _tickO, _tickSpacing);

        if (demand > MAX_PROSPECTIVE_SWAP_STEPS) {
            revert StandbyHook__ProspectiveTraversalDemandExceedsBound(demand, MAX_PROSPECTIVE_SWAP_STEPS);
        }
    }

    /// @dev Requires a service boundary to be a valid Uniswap tick aligned to the pool tick spacing.
    ///      The pool is already initialized when this runs, so its tick spacing is at least
    ///      `TickMath.MIN_TICK_SPACING` and the modulo is well defined.
    function _validateServiceTick(int24 _tick, int24 _tickSpacing) internal pure {
        if (_tick < TickMath.MIN_TICK || _tick > TickMath.MAX_TICK) revert StandbyHook__InvalidServiceTick(_tick);
        if (_tick % _tickSpacing != 0) revert StandbyHook__MisalignedServiceTick(_tick, _tickSpacing);
    }
}
