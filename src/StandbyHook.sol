// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {BaseHook} from "v4-hooks-public/src/base/BaseHook.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";

import {IEligibilityRegistry} from "./interfaces/IEligibilityRegistry.sol";
import {CommitmentRefs, MAX_LIVE_COMMITMENTS as BOUNDED_REFERENCE_SLOTS} from "./libraries/CommitmentRefs.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title StandbyHook
/// @notice The Standby Uniswap v4 Hook.
/// @dev At implementation slice F4 this contract owns the Hook-wide immutable trust basis, one one-shot
///      Protected Execution Service configuration, and the authoritative commitment record store with its
///      bounded enforcement-reference index. It does not yet own economic derivation, commitment
///      admission, exercise, or O3 enforcement, so the four enabled callbacks still fail closed with
///      `HookNotImplemented` until their owning implementation slices supply authoritative behavior, and
///      no production path can create a commitment.
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

        PoolKey memory key = _service.poolKey;

        poolId = key.toId();
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

        bool ordered = _protectedZeroForOne ? _tickQ < _tickO : _tickQ > _tickO;

        if (!ordered) revert StandbyHook__InvalidServiceDomainOrder(_protectedZeroForOne, _tickQ, _tickO);

        (int24 lowerTick, int24 upperTick) = _protectedZeroForOne ? (_tickQ, _tickO) : (_tickO, _tickQ);

        uint160 sqrtLowerX96 = TickMath.getSqrtPriceAtTick(lowerTick);
        uint160 sqrtUpperX96 = TickMath.getSqrtPriceAtTick(upperTick);

        if (_sqrtPriceX96 < sqrtLowerX96 || _sqrtPriceX96 > sqrtUpperX96) {
            revert StandbyHook__CurrentPriceOutsideServiceDomain(_sqrtPriceX96, sqrtLowerX96, sqrtUpperX96);
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
