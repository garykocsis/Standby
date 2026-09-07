// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LiquidityMath} from "v4-core/libraries/LiquidityMath.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {ProtocolFeeLibrary} from "v4-core/libraries/ProtocolFeeLibrary.sol";
import {SafeCast} from "v4-core/libraries/SafeCast.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {SwapMath} from "v4-core/libraries/SwapMath.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

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
/// @dev At implementation slice F5 this contract owns the Hook-wide immutable trust basis, one one-shot
///      Protected Execution Service configuration, the authoritative commitment record store with its
///      bounded enforcement-reference index, and the composition of the authoritative economic derivation
///      kernel. It does not yet own commitment admission, exercise, or O3 enforcement, so the four enabled
///      callbacks still fail closed with `HookNotImplemented` until their owning implementation slices
///      supply authoritative behavior, and no production path can create a commitment.
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
///      administrator.
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

    /// @dev Allocates a permanent identity and writes the commitment facts under it.
    ///
    ///      This is storage mechanics, not admission. It authenticates nobody, validates no economic
    ///      term, and derives nothing: it records exactly the facts it is handed. Whether those facts
    ///      describe an authentic, sufficiently backed Standby commitment is the admission slice's
    ///      question, and no production path reaches this function until that slice exists.
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
    /// @param _params The proposed swap.
    /// @return sqrtPriceX96 The predicted post-swap square-root price.
    /// @return liquidity The predicted post-swap active liquidity.
    function _prospectiveSwapState(SwapParams calldata _params)
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
    function _beginSwapDerivation(SwapParams calldata _params)
        internal
        view
        returns (SwapDerivation memory derivation)
    {
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
