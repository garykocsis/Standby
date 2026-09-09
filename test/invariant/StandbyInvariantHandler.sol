// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             INTERFACES
//////////////////////////////////////////////////////////////*/

/// @notice The minimal exact-transfer fixture currency surface the invariant environment consumes.
/// @dev Deliberately narrow. GI never asks a currency anything economically meaningful: Supporting
///      Capacity and Capacity Obligation are raw amounts of the protected output currency, and no Standby
///      derivation may consult `decimals()`. The precision is read only so a campaign can state which
///      configuration it is running under.
interface IInvariantCurrency {
    /// @notice Returns the decimal precision of the currency.
    /// @return decimals_ The configured decimal precision.
    function decimals() external view returns (uint8 decimals_);

    /// @notice Returns the raw balance an account holds.
    /// @param _account The account to read.
    /// @return balance The raw balance.
    function balanceOf(address _account) external view returns (uint256 balance);

    /// @notice Mints fixture currency to an account.
    /// @param _to The account receiving the minted currency.
    /// @param _amount The raw amount minted.
    function mint(address _to, uint256 _amount) external;

    /// @notice Approves a spender to transfer currency on behalf of the caller.
    /// @param _spender The approved spender.
    /// @param _amount The approved raw amount.
    /// @return success Whether the approval succeeded.
    function approve(address _spender, uint256 _amount) external returns (bool success);

    /// @notice Transfers currency from the caller to another account.
    /// @param _to The recipient.
    /// @param _amount The raw amount transferred.
    /// @return success Whether the transfer succeeded.
    function transfer(address _to, uint256 _amount) external returns (bool success);
}

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title StandbyInvariantHandler
/// @notice The adversarial stateful transaction generator of the GI invariant campaigns.
/// @dev This contract is a transaction generator, not a safety pre-filter. It composes O1, O2, O3,
///      liquidity, eligibility, lifecycle, and unrelated-external actions into arbitrary multi-operation
///      histories, and it deliberately generates requests that must be refused: unauthorized callers,
///      ineligible actors, untrusted perimeters, inadmissible terms, over-extent quantities, breached cost
///      bounds, backing-destructive transitions, and evidence with no exercise behind it. Every one of
///      those rejections is GI evidence.
///
///      Every action runs through a production interface. Commitments are admitted by
///      `StandbyHook.establishCommitment`, exercises are coordinated by the production `ExerciseRouter`,
///      ordinary swaps and liquidity actions arrive through the real trusted perimeters and the real
///      `PoolManager`, and eligibility is mutated through the real `EligibilityRegistry` administrator. No
///      economically authoritative state is ever written directly: not Remaining Entitlement, not the
///      admitted extent, not a bounded reference, not Supporting Capacity, not Capacity Obligation, not
///      validity, not exercisability, not fulfillment, and not the O2 causal context.
///
///      Ghost state here remembers history and never prescribes it. It holds the identities admission
///      actually produced, the immutable facts those admissions actually recorded, the last Remaining
///      Entitlement actually observed, the quantity each successfully completed O2 actually fulfilled, and
///      the protected output actually delivered or donated to each Beneficiary. It maintains no parallel
///      validity, exercisability, binding, expiry, or obligation classification: those are Standby's own
///      state machine, and duplicating them would verify the duplicate rather than the protocol.
///
///      Assertions are made where the property is: transition-local exactness immediately around the
///      transition that has to have it, and continuous properties in the campaign's invariant functions.
///      Every external production call is wrapped, so a refused Standby request is recorded rather than
///      discarded — which is what lets the campaigns run with `fail_on_revert = true` and treat any
///      unwrapped revert, including a failed assertion, as a campaign failure.
///
///      Actors are a bounded persistent universe rather than fuzzed addresses, because the properties
///      under test are about stable authority relationships across a history: that administrative
///      authority, establishment authority, exercise authority, Beneficiary eligibility, trader
///      eligibility, liquidity eligibility, and ordinary invocation capability never substitute for one
///      another. A fresh random caller per call would destroy exactly the relationships GI is verifying.
contract StandbyInvariantHandler is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The complete production environment one campaign drives.
    /// @param poolManager The real pinned PoolManager.
    /// @param hook The production StandbyHook whose service is activated.
    /// @param exerciseRouter The production ExerciseRouter the service was activated with.
    /// @param registry The production EligibilityRegistry the service consumes.
    /// @param swapPerimeter The trusted ordinary-swap perimeter.
    /// @param liquidityPerimeter The trusted liquidity perimeter.
    /// @param currency0 The pool's currency0.
    /// @param currency1 The pool's currency1.
    /// @param poolKey The activated service pool.
    /// @param protectedZeroForOne The protected swap direction of the service.
    /// @param tickQ The protected execution-quality boundary.
    /// @param tickO The opposite realization-domain boundary.
    /// @param tickSpacing The pool tick spacing.
    /// @param lpTickLower The lower endpoint of the bootstrap liquidity position.
    /// @param lpTickUpper The upper endpoint of the bootstrap liquidity position.
    /// @param initialLiquidity The liquidity the bootstrap position contributed.
    /// @param initialCapacity The independently derived Supporting Capacity at campaign start.
    struct InvariantEnvironment {
        IPoolManager poolManager;
        StandbyHook hook;
        ExerciseRouter exerciseRouter;
        EligibilityRegistry registry;
        ActorAwareTestRouter swapPerimeter;
        ActorAwareTestRouter liquidityPerimeter;
        IInvariantCurrency currency0;
        IInvariantCurrency currency1;
        PoolKey poolKey;
        bool protectedZeroForOne;
        int24 tickQ;
        int24 tickO;
        int24 tickSpacing;
        int24 lpTickLower;
        int24 lpTickUpper;
        uint128 initialLiquidity;
        uint256 initialCapacity;
    }

    /// @notice The bounded persistent actor universe of one campaign.
    /// @dev Each identity holds exactly one role, so no property can pass because two semantically
    ///      distinct authorities happened to be the same account. The three permanently ineligible
    ///      identities are never granted eligibility by any handler action, so "ineligible" stays a stable
    ///      relationship a multi-operation history can rely on.
    /// @param registryAdmin The EligibilityRegistry administrator.
    /// @param establishmentAuthority The per-service commitment-establishment authority.
    /// @param beneficiaryA The first eligible Beneficiary.
    /// @param beneficiaryB The second eligible Beneficiary.
    /// @param ineligibleBeneficiary A Beneficiary that is never eligible.
    /// @param authorizedExerciser The exercise authority admitted commitments name.
    /// @param unauthorizedExerciser A funded exerciser that is never a commitment's exercise authority.
    /// @param eligibleTrader An eligible ordinary trader.
    /// @param ineligibleTrader A trader that is never eligible.
    /// @param eligibleProvider The eligible liquidity provider that holds the bootstrap position.
    /// @param ineligibleProvider A provider that is never eligible.
    /// @param donor An account holding protected output currency and no Standby role at all.
    /// @param outsider An account holding no authority, eligibility, or entitlement of any kind.
    struct InvariantActors {
        address registryAdmin;
        address establishmentAuthority;
        address beneficiaryA;
        address beneficiaryB;
        address ineligibleBeneficiary;
        address authorizedExerciser;
        address unauthorizedExerciser;
        address eligibleTrader;
        address ineligibleTrader;
        address eligibleProvider;
        address ineligibleProvider;
        address donor;
        address outsider;
    }

    /// @notice The immutable facts one admission actually recorded.
    /// @dev Remembered history, never prescribed state. It exists so that "the admitted facts never
    ///      changed" is checkable across bounded-reference reclamation and slot reuse.
    /// @param serviceId The service the commitment was admitted under.
    /// @param beneficiary The admitted Beneficiary.
    /// @param exerciseAuthority The admitted exercise authority.
    /// @param exercisableFrom The admitted exercise-window opening.
    /// @param validUntil The admitted validity end.
    /// @param originalEntitlement The admitted entitlement extent.
    struct AdmittedFacts {
        PoolId serviceId;
        address beneficiary;
        address exerciseAuthority;
        uint64 exercisableFrom;
        uint64 validUntil;
        uint128 originalEntitlement;
    }

    /// @notice Diagnostic activity counters for one campaign.
    /// @dev Test diagnostics only. No counter is a protocol semantic and no threshold is a requirement;
    ///      they exist so a green campaign can be shown to have exercised meaningful protocol behavior
    ///      rather than trivial churn.
    struct ActionCounters {
        uint256 establishAttempts;
        uint256 establishSuccesses;
        uint256 establishRejections;
        uint256 exerciseAttempts;
        uint256 exerciseSuccesses;
        uint256 exerciseRejections;
        uint256 partialFulfillments;
        uint256 fullFulfillments;
        uint256 protectedSwapAttempts;
        uint256 protectedSwapSuccesses;
        uint256 swapBackingRejections;
        uint256 oppositeSwapAttempts;
        uint256 oppositeSwapSuccesses;
        uint256 liquidityAddAttempts;
        uint256 liquidityAddSuccesses;
        uint256 liquidityRemoveAttempts;
        uint256 liquidityRemoveSuccesses;
        uint256 liquidityBackingRejections;
        uint256 beneficiaryEligibilityMutations;
        uint256 traderEligibilityMutations;
        uint256 liquidityEligibilityMutations;
        uint256 eligibilityMutationRejections;
        uint256 timeAdvances;
        uint256 expiryEvents;
        uint256 directBeneficiaryTransfers;
        uint256 orphanEvidenceAttempts;
        uint256 referenceReuseEvents;
        uint256 maxLiveReferences;
        uint256 maxObservedObligation;
        uint256 backingBoundaryObservations;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The candidate liquidity ranges a campaign may act on.
    uint256 internal constant LIQUIDITY_RANGE_COUNT = 4;

    /// @dev How many of the most recent commitments a generated exercise prefers to target.
    uint256 internal constant RECENT_COMMITMENT_WINDOW = 4;

    IPoolManager internal immutable i_poolManager;
    StandbyHook internal immutable i_hook;
    ExerciseRouter internal immutable i_exerciseRouter;
    EligibilityRegistry internal immutable i_registry;
    ActorAwareTestRouter internal immutable i_swapPerimeter;
    ActorAwareTestRouter internal immutable i_liquidityPerimeter;
    IInvariantCurrency internal immutable i_currency0;
    IInvariantCurrency internal immutable i_currency1;

    bool internal immutable i_protectedZeroForOne;
    int24 internal immutable i_tickQ;
    int24 internal immutable i_tickO;
    int24 internal immutable i_tickSpacing;
    int24 internal immutable i_lpTickLower;
    int24 internal immutable i_lpTickUpper;
    uint256 internal immutable i_initialCapacity;
    uint128 internal immutable i_initialLiquidity;

    address internal immutable i_registryAdmin;
    address internal immutable i_establishmentAuthority;
    address internal immutable i_beneficiaryA;
    address internal immutable i_beneficiaryB;
    address internal immutable i_ineligibleBeneficiary;
    address internal immutable i_authorizedExerciser;
    address internal immutable i_unauthorizedExerciser;
    address internal immutable i_eligibleTrader;
    address internal immutable i_ineligibleTrader;
    address internal immutable i_eligibleProvider;
    address internal immutable i_ineligibleProvider;
    address internal immutable i_donor;
    address internal immutable i_outsider;

    /// @dev The activated service pool this campaign drives.
    PoolKey internal servicePoolKey;

    /// @dev The identity of the activated service pool.
    PoolId internal servicePoolId;

    /// @notice Every commitment identity a successful production admission actually produced.
    uint256[] public knownCommitmentIds;

    /// @dev The immutable facts each admission recorded, remembered at the moment it succeeded.
    mapping(uint256 commitmentId => AdmittedFacts facts) internal admittedFacts;

    /// @dev The last Remaining Entitlement observed for a commitment, for monotonicity.
    mapping(uint256 commitmentId => uint128 remaining) internal lastObservedRemaining;

    /// @dev Independently tracked successful attributable fulfillment, by commitment.
    mapping(uint256 commitmentId => uint256 fulfilled) internal fulfilledByCommitment;

    /// @dev Protected output delivered to an account by successfully completed O2, independently tracked.
    mapping(address beneficiary => uint256 delivered) internal deliveredToBeneficiary;

    /// @dev Protected output an unrelated direct transfer moved to an account, tracked separately.
    mapping(address beneficiary => uint256 donated) internal donatedToBeneficiary;

    /// @dev Liquidity a given actor currently holds over a given range through the trusted perimeter.
    mapping(bytes32 positionKey => uint128 liquidity) internal positionLiquidity;

    /// @dev The campaign's diagnostic activity counters.
    ActionCounters internal actionCounters;

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the handler to one activated production environment and its persistent actors.
    /// @dev The bootstrap liquidity position is recorded as ghost custody bookkeeping only. It was created
    ///      before this contract existed, by the production `beforeAddLiquidity` path through the trusted
    ///      liquidity perimeter, and remembering who holds it lets removal requests be generated at
    ///      meaningful sizes rather than being rejected by position accounting every time.
    /// @param _environment The activated production environment.
    /// @param _actors The bounded persistent actor universe.
    constructor(InvariantEnvironment memory _environment, InvariantActors memory _actors) {
        i_poolManager = _environment.poolManager;
        i_hook = _environment.hook;
        i_exerciseRouter = _environment.exerciseRouter;
        i_registry = _environment.registry;
        i_swapPerimeter = _environment.swapPerimeter;
        i_liquidityPerimeter = _environment.liquidityPerimeter;
        i_currency0 = _environment.currency0;
        i_currency1 = _environment.currency1;

        i_protectedZeroForOne = _environment.protectedZeroForOne;
        i_tickQ = _environment.tickQ;
        i_tickO = _environment.tickO;
        i_tickSpacing = _environment.tickSpacing;
        i_lpTickLower = _environment.lpTickLower;
        i_lpTickUpper = _environment.lpTickUpper;
        i_initialCapacity = _environment.initialCapacity;
        i_initialLiquidity = _environment.initialLiquidity;

        i_registryAdmin = _actors.registryAdmin;
        i_establishmentAuthority = _actors.establishmentAuthority;
        i_beneficiaryA = _actors.beneficiaryA;
        i_beneficiaryB = _actors.beneficiaryB;
        i_ineligibleBeneficiary = _actors.ineligibleBeneficiary;
        i_authorizedExerciser = _actors.authorizedExerciser;
        i_unauthorizedExerciser = _actors.unauthorizedExerciser;
        i_eligibleTrader = _actors.eligibleTrader;
        i_ineligibleTrader = _actors.ineligibleTrader;
        i_eligibleProvider = _actors.eligibleProvider;
        i_ineligibleProvider = _actors.ineligibleProvider;
        i_donor = _actors.donor;
        i_outsider = _actors.outsider;

        servicePoolKey = _environment.poolKey;
        servicePoolId = _environment.poolKey.toId();

        positionLiquidity[_positionKey(_actors.eligibleProvider, _environment.lpTickLower, _environment.lpTickUpper)] =
            _environment.initialLiquidity;
    }

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL FUNCTIONS — CAMPAIGN
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes one O1 commitment admission, valid or not.
    /// @dev The caller, the proposed Beneficiary, the exercise authority, the extent, and the window are
    ///      all generated: unauthorized callers, a permanently ineligible Beneficiary, a zero extent, an
    ///      extent no backing could cover, an already-ended validity, and an impossible window are all
    ///      reachable and all must be refused by production rather than by this generator.
    /// @param _seed The action-shaping seed.
    /// @param _entitlement The proposed entitlement extent, bounded to the campaign's economic scale.
    /// @param _fromDelay The proposed exercise-window delay.
    /// @param _duration The proposed validity duration.
    function establishCommitment(uint256 _seed, uint128 _entitlement, uint64 _fromDelay, uint64 _duration) external {
        address caller = _seed % 8 == 0 ? _anyActor(_seed >> 3) : i_establishmentAuthority;
        address beneficiary = _proposedBeneficiary(_seed >> 8);
        address authority = (_seed >> 16) % 8 == 0 ? i_outsider : i_authorizedExerciser;

        uint128 entitlement = uint128(bound(uint256(_entitlement), 0, _economicScale()));
        uint64 exercisableFrom =
            uint64(block.timestamp) + ((_seed >> 24) % 4 == 0 ? uint64(bound(uint256(_fromDelay), 0, 3 days)) : 0);
        uint64 validUntil = uint64(block.timestamp) + uint64(bound(uint256(_duration), 0, 45 days));

        scriptedEstablish(caller, beneficiary, authority, entitlement, exercisableFrom, validUntil);
    }

    /// @notice Requests one O2 exercise of a known commitment, valid or not.
    /// @dev Quantity generation spans the whole admissible boundary and past it: exact exhaustion, a
    ///      partial amount, zero, and more than the commitment still carries. The caller is the commitment's
    ///      exercise authority most of the time and an unauthorized account otherwise, and the cost bound is
    ///      occasionally too small for any real debt.
    /// @param _seed The action-shaping seed.
    /// @param _q The requested protected-output quantity, bounded against authoritative Remaining.
    /// @param _maxInput The exerciser's own cost bound.
    function exercise(uint256 _seed, uint256 _q, uint256 _maxInput) external {
        if (knownCommitmentIds.length == 0) return;

        uint256 commitmentId = _knownCommitment(_seed);
        address exerciser = _exerciseCaller(_seed >> 8);

        uint256 remaining = uint256(i_hook.commitment(commitmentId).remainingEntitlement);

        uint256 pick = (_seed >> 16) % 8;
        uint256 q;

        if (pick < 3) q = remaining;
        else if (pick < 7) q = bound(_q, 0, remaining);
        else q = bound(_q, remaining, remaining + 1 + remaining / 4);

        uint256 maxInput = (_seed >> 24) % 8 == 0 ? bound(_maxInput, 0, 1e6) : type(uint256).max;

        scriptedExercise(exerciser, commitmentId, q, maxInput);
    }

    /// @notice Requests one ordinary swap in the protected direction, valid or not.
    /// @param _seed The action-shaping seed.
    /// @param _amount The requested amount, bounded to the campaign's economic scale.
    function ordinaryProtectedSwap(uint256 _seed, uint256 _amount) external {
        _ordinarySwap(_seed, _amount, true);
    }

    /// @notice Requests one ordinary swap in the opposite direction, valid or not.
    /// @param _seed The action-shaping seed.
    /// @param _amount The requested amount, bounded to the campaign's economic scale.
    function ordinaryOppositeSwap(uint256 _seed, uint256 _amount) external {
        _ordinarySwap(_seed, _amount, false);
    }

    /// @notice Requests one liquidity addition, valid or not.
    /// @dev Reaches an ineligible provider, an untrusted perimeter, and a range whose endpoint would sit
    ///      strictly inside the configured service domain — each of which production must refuse.
    /// @param _seed The action-shaping seed.
    /// @param _liquidity The proposed liquidity, bounded to the bootstrap position's scale.
    function addLiquidity(uint256 _seed, uint128 _liquidity) external {
        (int24 tickLower, int24 tickUpper) = _candidateRange(_seed >> 8);

        scriptedModifyLiquidity(
            _liquidityActor(_seed),
            tickLower,
            tickUpper,
            int256(uint256(uint128(bound(uint256(_liquidity), 0, uint256(i_initialLiquidity))))),
            (_seed >> 16) % 8 == 0
        );
    }

    /// @notice Requests one liquidity removal, valid or not.
    /// @dev Removal sizes are generated slightly beyond what the actor actually holds, so both an
    ///      authoritative position-accounting refusal and a Standby backing refusal are reachable.
    /// @param _seed The action-shaping seed.
    /// @param _liquidity The proposed removal, bounded against the actor's own tracked position.
    function removeLiquidity(uint256 _seed, uint128 _liquidity) external {
        address actor = _liquidityActor(_seed);

        (int24 tickLower, int24 tickUpper) = _candidateRange(_seed >> 8);

        uint256 held = uint256(positionLiquidity[_positionKey(actor, tickLower, tickUpper)]);
        uint256 removal = bound(uint256(_liquidity), 0, held + held / 4 + 1);

        scriptedModifyLiquidity(actor, tickLower, tickUpper, -int256(removal), (_seed >> 16) % 8 == 0);
    }

    /// @notice Advances authoritative time, occasionally past the campaign's whole validity horizon.
    /// @param _seed The action-shaping seed.
    function advanceTime(uint256 _seed) external {
        scriptedAdvanceTime(_seed % 8 == 0 ? 31 days : bound(_seed, 1 hours, 2 days));
    }

    /// @notice Mutates Beneficiary eligibility, from the registry administrator or from an outsider.
    /// @dev The permanently ineligible Beneficiary is never a candidate, so "ineligible" remains a stable
    ///      relationship across the whole generated history.
    /// @param _seed The action-shaping seed.
    function setBeneficiaryEligibility(uint256 _seed) external {
        scriptedSetBeneficiaryEligibility(
            _eligibilityCaller(_seed), _mutableBeneficiary(_seed >> 8), _grantsEligibility(_seed >> 16)
        );
    }

    /// @notice Mutates trader eligibility, from the registry administrator or from an outsider.
    /// @param _seed The action-shaping seed.
    function setTraderEligibility(uint256 _seed) external {
        scriptedSetTraderEligibility(
            _eligibilityCaller(_seed),
            (_seed >> 8) % 2 == 0 ? i_eligibleTrader : i_outsider,
            _grantsEligibility(_seed >> 16)
        );
    }

    /// @notice Mutates liquidity-action eligibility, from the registry administrator or from an outsider.
    /// @param _seed The action-shaping seed.
    function setLiquidityEligibility(uint256 _seed) external {
        scriptedSetLiquidityEligibility(
            _eligibilityCaller(_seed),
            (_seed >> 8) % 2 == 0 ? i_eligibleProvider : i_outsider,
            _grantsEligibility(_seed >> 16)
        );
    }

    /// @notice Transfers protected output currency directly to a Beneficiary, outside Standby entirely.
    /// @dev Ordinary receipt of the protected output currency is not Standby fulfillment, and this action
    ///      exists to keep that claim behavioral rather than asserted.
    /// @param _seed The action-shaping seed.
    /// @param _amount The raw amount transferred.
    function directTransferProtectedTokenToBeneficiary(uint256 _seed, uint256 _amount) external {
        scriptedDirectTransfer(_mutableBeneficiary(_seed), bound(_amount, 0, _economicScale() / 4 + 1));
    }

    /// @notice Attempts to use O2 evidence that no exercise in this transaction produced.
    /// @dev Two probes of the same frozen property. A direct `authorizeExercise` never arrives through the
    ///      configured ExerciseRouter, and a direct `finalizeExercise` has no causally proven exercise
    ///      behind it — including immediately after a successful one, which is the shape a surviving,
    ///      reusable context would take.
    /// @param _seed The action-shaping seed.
    function attemptOrphanExerciseEvidence(uint256 _seed) external {
        uint256 commitmentId = (_seed % 4 == 0 || knownCommitmentIds.length == 0)
            ? i_hook.nextCommitmentId()
            : _knownCommitment(_seed >> 8);

        scriptedOrphanEvidence(_anyActor(_seed >> 16), commitmentId);
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL FUNCTIONS — OBSERVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the campaign's diagnostic activity counters.
    /// @return counters_ The counters accumulated by this campaign.
    function counters() external view returns (ActionCounters memory counters_) {
        counters_ = actionCounters;
    }

    /// @notice Returns how many commitments successful production admissions have produced.
    /// @return count The number of known commitment identities.
    function commitmentCount() external view returns (uint256 count) {
        count = knownCommitmentIds.length;
    }

    /// @notice Returns the immutable facts remembered for one admitted commitment.
    /// @param _commitmentId The identity to read.
    /// @return facts The facts the admission actually recorded.
    function admittedCommitmentFacts(uint256 _commitmentId) external view returns (AdmittedFacts memory facts) {
        facts = admittedFacts[_commitmentId];
    }

    /// @notice Returns the independently tracked successful fulfillment of one commitment.
    /// @param _commitmentId The identity to read.
    /// @return fulfilled The sum of the quantities successfully completed O2 exercises discharged.
    function ghostFulfilled(uint256 _commitmentId) external view returns (uint256 fulfilled) {
        fulfilled = fulfilledByCommitment[_commitmentId];
    }

    /// @notice Returns the protected output successfully completed O2 delivered to an account.
    /// @param _beneficiary The account to read.
    /// @return delivered The independently tracked delivered quantity.
    function ghostDelivered(address _beneficiary) external view returns (uint256 delivered) {
        delivered = deliveredToBeneficiary[_beneficiary];
    }

    /// @notice Returns the protected output unrelated direct transfers moved to an account.
    /// @param _beneficiary The account to read.
    /// @return donated The independently tracked donated quantity.
    function ghostDonated(address _beneficiary) external view returns (uint256 donated) {
        donated = donatedToBeneficiary[_beneficiary];
    }

    /// @notice Returns the last Remaining Entitlement this handler observed for a commitment.
    /// @param _commitmentId The identity to read.
    /// @return remaining The last observed remainder.
    function ghostLastRemaining(uint256 _commitmentId) external view returns (uint128 remaining) {
        remaining = lastObservedRemaining[_commitmentId];
    }

    /*//////////////////////////////////////////////////////////////
                     PUBLIC FUNCTIONS — SCRIPTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs one production O1 admission with every term chosen explicitly.
    /// @dev The single implementation of the action. The campaign entry point generates its arguments and
    ///      the scripted sequence suites choose them, so both prove properties of the same transition.
    /// @param _caller The account attempting the admission.
    /// @param _beneficiary The proposed Beneficiary.
    /// @param _exerciseAuthority The proposed exercise authority.
    /// @param _originalEntitlement The proposed entitlement extent.
    /// @param _exercisableFrom The proposed exercise-window opening.
    /// @param _validUntil The proposed validity end.
    /// @return admitted Whether production admitted the commitment.
    /// @return commitmentId The identity allocated when admitted, otherwise zero.
    function scriptedEstablish(
        address _caller,
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil
    ) public returns (bool admitted, uint256 commitmentId) {
        uint256[MAX_LIVE_COMMITMENTS] memory referencesBefore = i_hook.enforcementReferences();
        uint256 nextIdBefore = i_hook.nextCommitmentId();

        ++actionCounters.establishAttempts;

        vm.prank(_caller);
        try i_hook.establishCommitment(
            _beneficiary, _exerciseAuthority, _originalEntitlement, _exercisableFrom, _validUntil
        ) returns (uint256 admittedId) {
            ++actionCounters.establishSuccesses;

            (admitted, commitmentId) = (true, admittedId);

            _recordAdmission(admittedId, referencesBefore);
        } catch {
            ++actionCounters.establishRejections;

            assertEq(i_hook.nextCommitmentId(), nextIdBefore, "a refused O1 must consume no commitment identity");

            _assertReferencesUnchanged(referencesBefore, "a refused O1 must not touch the bounded reference index");
        }

        _observeAuthoritativeState();
    }

    /// @notice Runs one production O2 exercise request with every field chosen explicitly.
    /// @dev The exactness claims are made here because they are transition-local: a successful exercise
    ///      must reduce exactly one commitment by exactly the exercised quantity and deliver exactly that
    ///      quantity to the authoritative Beneficiary, and a refused one must do neither.
    /// @param _exerciser The account requesting the exercise.
    /// @param _commitmentId The commitment the request names.
    /// @param _q The requested protected-output quantity.
    /// @param _maxInput The exerciser's own cost bound.
    /// @return fulfilled Whether the exercise completed and fulfilled the commitment.
    function scriptedExercise(address _exerciser, uint256 _commitmentId, uint256 _q, uint256 _maxInput)
        public
        returns (bool fulfilled)
    {
        address beneficiary = i_hook.commitment(_commitmentId).beneficiary;

        uint256[] memory remainingBefore = _remainingSnapshot();
        uint256 beneficiaryBefore = _protectedOutputBalance(beneficiary);
        uint256 obligationBefore = i_hook.aggregateObligation();
        uint256 capacityBefore = _referenceCapacity();

        ++actionCounters.exerciseAttempts;

        vm.prank(_exerciser);
        try i_exerciseRouter.exercise(_commitmentId, _q, _maxInput) {
            ++actionCounters.exerciseSuccesses;

            fulfilled = true;

            fulfilledByCommitment[_commitmentId] += _q;
            deliveredToBeneficiary[beneficiary] += _q;

            _assertExactFulfillment(_commitmentId, beneficiary, _q, remainingBefore, beneficiaryBefore);

            if (i_hook.commitment(_commitmentId).remainingEntitlement == 0) ++actionCounters.fullFulfillments;
            else ++actionCounters.partialFulfillments;
        } catch {
            ++actionCounters.exerciseRejections;

            _assertNoFulfillmentOccurred(remainingBefore, "a refused O2 must fulfil nothing");

            assertEq(
                _protectedOutputBalance(beneficiary), beneficiaryBefore, "a refused O2 must deliver nothing at all"
            );
            assertEq(i_hook.aggregateObligation(), obligationBefore, "a refused O2 must release no obligation");
            assertEq(_referenceCapacity(), capacityBefore, "a refused O2 must leave the authoritative pool untouched");
        }

        _observeAuthoritativeState();
    }

    /// @notice Runs one ordinary swap with its actor, shape, and perimeter chosen explicitly.
    /// @param _actor The originating user the perimeter authenticates.
    /// @param _zeroForOne The proposed swap direction.
    /// @param _amountSpecified The proposed amount, negative for exact input and positive for exact output.
    /// @param _limitTick The tick whose exact price bounds the swap.
    /// @param _throughLiquidityPerimeter Whether to route through the liquidity perimeter instead.
    /// @return executed Whether the swap became an authoritative pool transition.
    function scriptedSwap(
        address _actor,
        bool _zeroForOne,
        int256 _amountSpecified,
        int24 _limitTick,
        bool _throughLiquidityPerimeter
    ) public returns (bool executed) {
        ActorAwareTestRouter perimeter = _throughLiquidityPerimeter ? i_liquidityPerimeter : i_swapPerimeter;

        SwapParams memory params = SwapParams({
            zeroForOne: _zeroForOne,
            amountSpecified: _amountSpecified,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(_limitTick)
        });

        bool protectedDirection = _zeroForOne == i_protectedZeroForOne;

        if (protectedDirection) ++actionCounters.protectedSwapAttempts;
        else ++actionCounters.oppositeSwapAttempts;

        uint256[] memory remainingBefore = _remainingSnapshot();

        vm.prank(_actor);
        try perimeter.swap(servicePoolKey, params, bytes("")) {
            executed = true;

            if (protectedDirection) ++actionCounters.protectedSwapSuccesses;
            else ++actionCounters.oppositeSwapSuccesses;
        } catch (bytes memory reason) {
            if (_reportsInsufficientProspectiveBacking(reason)) ++actionCounters.swapBackingRejections;
        }

        _assertNoFulfillmentOccurred(remainingBefore, "an ordinary swap must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Runs one liquidity modification with its actor, range, and perimeter chosen explicitly.
    /// @param _actor The originating user the perimeter authenticates.
    /// @param _tickLower The lower endpoint of the range.
    /// @param _tickUpper The upper endpoint of the range.
    /// @param _liquidityDelta The proposed liquidity change.
    /// @param _throughSwapPerimeter Whether to route through the ordinary-swap perimeter instead.
    /// @return executed Whether the modification became an authoritative pool transition.
    function scriptedModifyLiquidity(
        address _actor,
        int24 _tickLower,
        int24 _tickUpper,
        int256 _liquidityDelta,
        bool _throughSwapPerimeter
    ) public returns (bool executed) {
        ActorAwareTestRouter perimeter = _throughSwapPerimeter ? i_swapPerimeter : i_liquidityPerimeter;

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: _tickLower,
            tickUpper: _tickUpper,
            liquidityDelta: _liquidityDelta,
            salt: bytes32(0)
        });

        if (_liquidityDelta > 0) ++actionCounters.liquidityAddAttempts;
        else ++actionCounters.liquidityRemoveAttempts;

        uint256[] memory remainingBefore = _remainingSnapshot();

        vm.prank(_actor);
        try perimeter.modifyLiquidity(servicePoolKey, params, bytes("")) {
            executed = true;

            _recordPositionChange(_actor, _tickLower, _tickUpper, _liquidityDelta);

            if (_liquidityDelta > 0) ++actionCounters.liquidityAddSuccesses;
            else ++actionCounters.liquidityRemoveSuccesses;
        } catch (bytes memory reason) {
            if (_reportsInsufficientProspectiveBacking(reason)) ++actionCounters.liquidityBackingRejections;
        }

        _assertNoFulfillmentOccurred(remainingBefore, "a liquidity action must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Advances authoritative time by an explicit amount.
    /// @param _seconds The number of seconds to advance.
    function scriptedAdvanceTime(uint256 _seconds) public {
        uint256[] memory remainingBefore = _remainingSnapshot();
        uint256 bindingBefore = _bindingCommitmentCount();

        vm.warp(block.timestamp + _seconds);

        ++actionCounters.timeAdvances;

        uint256 bindingAfter = _bindingCommitmentCount();

        if (bindingAfter < bindingBefore) actionCounters.expiryEvents += bindingBefore - bindingAfter;

        _assertNoFulfillmentOccurred(remainingBefore, "expiry must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Mutates Beneficiary eligibility with its caller and target chosen explicitly.
    /// @param _caller The account attempting the mutation.
    /// @param _account The account whose eligibility is mutated.
    /// @param _eligible The eligibility to set.
    /// @return mutated Whether the registry accepted the mutation.
    function scriptedSetBeneficiaryEligibility(address _caller, address _account, bool _eligible)
        public
        returns (bool mutated)
    {
        uint256 obligationBefore = i_hook.aggregateObligation();
        uint256[] memory remainingBefore = _remainingSnapshot();

        vm.prank(_caller);
        try i_registry.setBeneficiaryEligibility(_account, _eligible) {
            mutated = true;

            ++actionCounters.beneficiaryEligibilityMutations;
        } catch {
            ++actionCounters.eligibilityMutationRejections;
        }

        assertEq(
            i_hook.aggregateObligation(),
            obligationBefore,
            "Beneficiary eligibility must release no Capacity Obligation"
        );

        _assertNoFulfillmentOccurred(remainingBefore, "eligibility mutation must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Mutates trader eligibility with its caller and target chosen explicitly.
    /// @param _caller The account attempting the mutation.
    /// @param _account The account whose eligibility is mutated.
    /// @param _eligible The eligibility to set.
    /// @return mutated Whether the registry accepted the mutation.
    function scriptedSetTraderEligibility(address _caller, address _account, bool _eligible)
        public
        returns (bool mutated)
    {
        uint256 obligationBefore = i_hook.aggregateObligation();
        uint256[] memory remainingBefore = _remainingSnapshot();

        vm.prank(_caller);
        try i_registry.setTraderEligibility(_account, _eligible) {
            mutated = true;

            ++actionCounters.traderEligibilityMutations;
        } catch {
            ++actionCounters.eligibilityMutationRejections;
        }

        assertEq(i_hook.aggregateObligation(), obligationBefore, "trader eligibility must release no obligation");

        _assertNoFulfillmentOccurred(remainingBefore, "trader eligibility must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Mutates liquidity-action eligibility with its caller and target chosen explicitly.
    /// @param _caller The account attempting the mutation.
    /// @param _account The account whose eligibility is mutated.
    /// @param _eligible The eligibility to set.
    /// @return mutated Whether the registry accepted the mutation.
    function scriptedSetLiquidityEligibility(address _caller, address _account, bool _eligible)
        public
        returns (bool mutated)
    {
        uint256 obligationBefore = i_hook.aggregateObligation();
        uint256[] memory remainingBefore = _remainingSnapshot();

        vm.prank(_caller);
        try i_registry.setLiquidityEligibility(_account, _eligible) {
            mutated = true;

            ++actionCounters.liquidityEligibilityMutations;
        } catch {
            ++actionCounters.eligibilityMutationRejections;
        }

        assertEq(i_hook.aggregateObligation(), obligationBefore, "liquidity eligibility must release no obligation");

        _assertNoFulfillmentOccurred(remainingBefore, "liquidity eligibility must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /// @notice Transfers protected output currency directly to an account, outside Standby.
    /// @param _beneficiary The recipient.
    /// @param _amount The raw amount transferred.
    /// @return transferred Whether the transfer succeeded.
    function scriptedDirectTransfer(address _beneficiary, uint256 _amount) public returns (bool transferred) {
        uint256[] memory remainingBefore = _remainingSnapshot();
        uint256 balanceBefore = _protectedOutputBalance(_beneficiary);

        vm.prank(i_donor);
        try _protectedOutputCurrency().transfer(_beneficiary, _amount) {
            transferred = true;

            donatedToBeneficiary[_beneficiary] += _amount;

            ++actionCounters.directBeneficiaryTransfers;

            assertEq(
                _protectedOutputBalance(_beneficiary),
                balanceBefore + _amount,
                "an unrelated transfer must move exactly what it transferred"
            );
        } catch {}

        _assertNoFulfillmentOccurred(
            remainingBefore, "Beneficiary receipt of protected output must never be Standby fulfillment"
        );

        _observeAuthoritativeState();
    }

    /// @notice Attempts to consume O2 evidence this transaction did not produce.
    /// @dev Both probes must be refused. The state assertions afterwards are what make "refused" mean "left
    ///      nothing behind" rather than merely "reverted".
    /// @param _caller The account attempting to use the evidence.
    /// @param _commitmentId The commitment the attempts name.
    function scriptedOrphanEvidence(address _caller, uint256 _commitmentId) public {
        uint256[] memory remainingBefore = _remainingSnapshot();

        ++actionCounters.orphanEvidenceAttempts;

        vm.prank(_caller);
        try i_hook.authorizeExercise(_commitmentId, 1) {
            assertTrue(false, "authorization outside the configured ExerciseRouter must never succeed");
        } catch {}

        vm.prank(_caller);
        try i_hook.finalizeExercise(_commitmentId) {
            assertTrue(false, "finalization without a causally proven exercise must never succeed");
        } catch {}

        _assertNoFulfillmentOccurred(remainingBefore, "orphan O2 evidence must never fulfil a commitment");

        _observeAuthoritativeState();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Generates one ordinary swap request in the requested direction relative to the protected one.
    ///
    ///      The amount and the price limit are generated by their own helpers rather than inline, so that
    ///      this frame stays small enough to compile without the optimizer — which is what the repository's
    ///      coverage instrumentation builds with.
    function _ordinarySwap(uint256 _seed, uint256 _amount, bool _protectedDirection) internal {
        bool zeroForOne = _protectedDirection == i_protectedZeroForOne;

        scriptedSwap(
            _swapActor(_seed),
            zeroForOne,
            _generatedSwapAmount(_seed, _amount),
            _generatedSwapLimitTick(_seed, zeroForOne, _protectedDirection),
            (_seed >> 8) % 8 == 0
        );
    }

    /// @dev The amount one generated ordinary swap requests, as exact input or exact output.
    function _generatedSwapAmount(uint256 _seed, uint256 _amount) internal view returns (int256 amountSpecified) {
        uint256 magnitude = bound(_amount, 0, _economicScale());

        amountSpecified = (_seed >> 16) % 2 == 0 ? int256(magnitude) : -int256(magnitude);
    }

    /// @dev The price limit one generated ordinary swap is bounded by.
    ///
    ///      The domain boundary the swap moves toward most of the time, and a tick beyond that boundary
    ///      otherwise: the first is the ordinary supported shape, the second is a transition that would take
    ///      the pool out of the configured realization domain and must be refused as one.
    function _generatedSwapLimitTick(uint256 _seed, bool _zeroForOne, bool _protectedDirection)
        internal
        view
        returns (int24 limitTick)
    {
        if ((_seed >> 24) % 8 == 0) return _zeroForOne ? i_lpTickLower : i_lpTickUpper;

        limitTick = _protectedDirection ? i_tickQ : i_tickO;
    }

    /// @dev Remembers the immutable facts one successful admission recorded, and any slot reuse it caused.
    function _recordAdmission(uint256 _commitmentId, uint256[MAX_LIVE_COMMITMENTS] memory _referencesBefore) internal {
        StandbyHook.Commitment memory record = i_hook.commitment(_commitmentId);

        admittedFacts[_commitmentId] = AdmittedFacts({
            serviceId: record.serviceId,
            beneficiary: record.beneficiary,
            exerciseAuthority: record.exerciseAuthority,
            exercisableFrom: record.exercisableFrom,
            validUntil: record.validUntil,
            originalEntitlement: record.originalEntitlement
        });

        lastObservedRemaining[_commitmentId] = record.remainingEntitlement;

        knownCommitmentIds.push(_commitmentId);

        uint256[MAX_LIVE_COMMITMENTS] memory referencesAfter = i_hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (referencesAfter[slot] != _commitmentId) continue;

            if (_referencesBefore[slot] != 0) ++actionCounters.referenceReuseEvents;

            return;
        }

        assertTrue(false, "an admitted commitment must occupy a bounded enforcement reference");
    }

    /// @dev Records the position custody a successful liquidity modification produced.
    function _recordPositionChange(address _actor, int24 _tickLower, int24 _tickUpper, int256 _liquidityDelta)
        internal
    {
        bytes32 key = _positionKey(_actor, _tickLower, _tickUpper);

        if (_liquidityDelta > 0) {
            positionLiquidity[key] += uint128(uint256(_liquidityDelta));

            return;
        }

        uint128 removed = uint128(uint256(-_liquidityDelta));
        uint128 held = positionLiquidity[key];

        positionLiquidity[key] = held > removed ? held - removed : 0;
    }

    /// @dev Re-observes every authoritative fact a completed action must have preserved.
    ///
    ///      This is the continuous half of the transition-local evidence: whatever the action was, the
    ///      admitted facts of every historical commitment are still what admission recorded, no remainder
    ///      has grown, no remainder exceeds its admitted extent, the discharged portion of every commitment
    ///      still equals exactly the independently tracked successful fulfillment, every Beneficiary holds
    ///      exactly what Standby delivered plus what unrelated transfers donated, the protocol holds no
    ///      protected-output custody, and no reusable O2 causal evidence survives.
    function _observeAuthoritativeState() internal {
        uint256 count = knownCommitmentIds.length;

        for (uint256 i = 0; i < count; ++i) {
            uint256 commitmentId = knownCommitmentIds[i];

            StandbyHook.Commitment memory record = i_hook.commitment(commitmentId);
            AdmittedFacts memory facts = admittedFacts[commitmentId];

            assertEq(
                PoolId.unwrap(record.serviceId), PoolId.unwrap(facts.serviceId), "the admitted service must not change"
            );
            assertEq(record.beneficiary, facts.beneficiary, "the admitted Beneficiary must not change");
            assertEq(
                record.exerciseAuthority, facts.exerciseAuthority, "the admitted exercise authority must not change"
            );
            assertEq(
                uint256(record.exercisableFrom),
                uint256(facts.exercisableFrom),
                "the admitted exercise window must not change"
            );
            assertEq(uint256(record.validUntil), uint256(facts.validUntil), "the admitted validity must not change");
            assertEq(
                uint256(record.originalEntitlement),
                uint256(facts.originalEntitlement),
                "the admitted entitlement extent must never be rewritten"
            );

            assertLe(
                uint256(record.remainingEntitlement),
                uint256(facts.originalEntitlement),
                "Remaining Entitlement must never exceed the admitted extent"
            );
            assertLe(
                uint256(record.remainingEntitlement),
                uint256(lastObservedRemaining[commitmentId]),
                "Remaining Entitlement must never increase"
            );
            assertEq(
                uint256(facts.originalEntitlement) - uint256(record.remainingEntitlement),
                fulfilledByCommitment[commitmentId],
                "the discharged portion must equal independently tracked successful fulfillment"
            );

            lastObservedRemaining[commitmentId] = record.remainingEntitlement;
        }

        _assertBeneficiaryHoldings(i_beneficiaryA);
        _assertBeneficiaryHoldings(i_beneficiaryB);
        _assertBeneficiaryHoldings(i_ineligibleBeneficiary);

        _assertNoProtocolCustody();

        assertEq(
            uint256(i_hook.exerciseAuthorization().state),
            uint256(StandbyHook.ExerciseAuthorizationState.EMPTY),
            "no reusable O2 causal context may survive a completed action"
        );

        _updateDiagnostics();
    }

    /// @dev Proves one successfully completed O2 had exactly the consequence it must have.
    function _assertExactFulfillment(
        uint256 _commitmentId,
        address _beneficiary,
        uint256 _q,
        uint256[] memory _remainingBefore,
        uint256 _beneficiaryBefore
    ) internal view {
        uint256 count = knownCommitmentIds.length;

        for (uint256 i = 0; i < count; ++i) {
            uint256 commitmentId = knownCommitmentIds[i];
            uint256 remaining = uint256(i_hook.commitment(commitmentId).remainingEntitlement);

            if (commitmentId == _commitmentId) {
                assertEq(
                    remaining,
                    _remainingBefore[i] - _q,
                    "a successful O2 must reduce its own commitment by exactly the exercised quantity"
                );
            } else {
                assertEq(remaining, _remainingBefore[i], "a successful O2 must reduce no other commitment");
            }
        }

        assertEq(
            _protectedOutputBalance(_beneficiary),
            _beneficiaryBefore + _q,
            "a successful O2 must deliver exactly the exercised quantity to the authoritative Beneficiary"
        );
    }

    /// @dev Proves no commitment's Remaining Entitlement moved across an action.
    function _assertNoFulfillmentOccurred(uint256[] memory _remainingBefore, string memory _context) internal view {
        uint256 count = knownCommitmentIds.length;

        for (uint256 i = 0; i < count; ++i) {
            assertEq(
                uint256(i_hook.commitment(knownCommitmentIds[i]).remainingEntitlement), _remainingBefore[i], _context
            );
        }
    }

    /// @dev Proves the bounded enforcement-reference index is exactly what it was.
    function _assertReferencesUnchanged(uint256[MAX_LIVE_COMMITMENTS] memory _referencesBefore, string memory _context)
        internal
        view
    {
        uint256[MAX_LIVE_COMMITMENTS] memory current = i_hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(current[slot], _referencesBefore[slot], _context);
        }
    }

    /// @dev Proves an account holds exactly the Standby deliveries plus the unrelated donations it received.
    ///
    ///      Beneficiaries hold no protected output at campaign start, never trade, never provide liquidity,
    ///      and never exercise, so their balance is a complete independent history of what reached them.
    function _assertBeneficiaryHoldings(address _beneficiary) internal view {
        assertEq(
            _protectedOutputBalance(_beneficiary),
            deliveredToBeneficiary[_beneficiary] + donatedToBeneficiary[_beneficiary],
            "a Beneficiary must hold exactly what Standby delivered plus what unrelated transfers donated"
        );
    }

    /// @dev Proves neither the Hook nor the ExerciseRouter holds currency of either kind.
    function _assertNoProtocolCustody() internal view {
        assertEq(i_currency0.balanceOf(address(i_hook)), 0, "the Hook must hold no currency0 custody");
        assertEq(i_currency1.balanceOf(address(i_hook)), 0, "the Hook must hold no currency1 custody");
        assertEq(
            i_currency0.balanceOf(address(i_exerciseRouter)), 0, "the ExerciseRouter must hold no currency0 custody"
        );
        assertEq(
            i_currency1.balanceOf(address(i_exerciseRouter)), 0, "the ExerciseRouter must hold no currency1 custody"
        );
    }

    /// @dev Updates the campaign quality diagnostics that describe the reachable states actually visited.
    function _updateDiagnostics() internal {
        uint256 live;

        uint256[MAX_LIVE_COMMITMENTS] memory references = i_hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] != 0) ++live;
        }

        if (live > actionCounters.maxLiveReferences) actionCounters.maxLiveReferences = live;

        uint256 obligation = i_hook.aggregateObligation();

        if (obligation > actionCounters.maxObservedObligation) actionCounters.maxObservedObligation = obligation;

        if (obligation != 0 && _referenceCapacity() == obligation) ++actionCounters.backingBoundaryObservations;
    }

    /// @dev Captures the Remaining Entitlement of every known commitment, positionally.
    function _remainingSnapshot() internal view returns (uint256[] memory remaining) {
        uint256 count = knownCommitmentIds.length;

        remaining = new uint256[](count);

        for (uint256 i = 0; i < count; ++i) {
            remaining[i] = uint256(i_hook.commitment(knownCommitmentIds[i]).remainingEntitlement);
        }
    }

    /// @dev Counts the commitments that currently carry a positive Capacity Obligation, from facts alone.
    function _bindingCommitmentCount() internal view returns (uint256 binding) {
        uint256 count = knownCommitmentIds.length;

        for (uint256 i = 0; i < count; ++i) {
            StandbyHook.Commitment memory record = i_hook.commitment(knownCommitmentIds[i]);

            if (
                ReferenceCalculations.referenceCommitmentObligation(
                    record.remainingEntitlement, record.validUntil, block.timestamp
                ) != 0
            ) ++binding;
        }
    }

    /// @dev Independently derives Supporting Capacity from authoritative PoolManager state.
    function _referenceCapacity() internal view returns (uint256 capacity) {
        (uint160 sqrtPriceX96,,,) = i_poolManager.getSlot0(servicePoolId);

        capacity = ReferenceCalculations.referenceSupportingCapacity(
            i_protectedZeroForOne, sqrtPriceX96, i_tickQ, i_poolManager.getLiquidity(servicePoolId)
        );
    }

    /// @dev Independently derives the current Aggregate Capacity Obligation from commitment facts.
    ///
    ///      Used only to shape generated amounts. Nothing decided by this value is a safety judgement: it
    ///      chooses the magnitude a proposal is drawn at, and production alone decides whether the proposal
    ///      is admissible.
    function _referenceObligation() internal view returns (uint256 obligation) {
        uint256 count = knownCommitmentIds.length;

        for (uint256 i = 0; i < count; ++i) {
            StandbyHook.Commitment memory record = i_hook.commitment(knownCommitmentIds[i]);

            obligation += ReferenceCalculations.referenceCommitmentObligation(
                record.remainingEntitlement, record.validUntil, block.timestamp
            );
        }
    }

    /// @dev The economic scale generated amounts are drawn against.
    ///
    ///      Centred on the present backing headroom, independently derived, plus a margin. That is where
    ///      the interesting boundary is: an amount drawn from this range is frequently one the service can
    ///      still support and frequently one it cannot, so admission and refusal are both ordinary
    ///      outcomes rather than one being an accident. The margin keeps the range positive when the
    ///      service is fully committed, so backing-destructive proposals stay reachable there too.
    function _economicScale() internal view returns (uint256 scale) {
        uint256 capacity = _referenceCapacity();
        uint256 obligation = _referenceObligation();

        scale = (capacity > obligation ? capacity - obligation : 0) + i_initialCapacity / 8 + 1;
    }

    /// @dev The protected output currency, selected by the protected direction alone.
    function _protectedOutputCurrency() internal view returns (IInvariantCurrency currency) {
        currency = i_protectedZeroForOne ? i_currency1 : i_currency0;
    }

    /// @dev Reads an account's protected-output balance.
    function _protectedOutputBalance(address _account) internal view returns (uint256 balance) {
        balance = _protectedOutputCurrency().balanceOf(_account);
    }

    /// @dev Selects a known commitment identity.
    ///
    ///      Recent identities are preferred, because a history that only ever targeted the oldest
    ///      commitment would spend most of its exercise attempts on expired or exhausted ones and would
    ///      reach very little completed fulfillment. Every identity stays reachable, so a stale target is
    ///      still generated.
    function _knownCommitment(uint256 _seed) internal view returns (uint256 commitmentId) {
        uint256 count = knownCommitmentIds.length;

        if (_seed % 4 == 0 || count <= RECENT_COMMITMENT_WINDOW) {
            return knownCommitmentIds[(_seed >> 2) % count];
        }

        commitmentId = knownCommitmentIds[count - 1 - ((_seed >> 2) % RECENT_COMMITMENT_WINDOW)];
    }

    /// @dev Selects the account a generated ordinary swap originates from.
    function _swapActor(uint256 _seed) internal view returns (address actor) {
        uint256 pick = _seed % 8;

        if (pick < 5) actor = i_eligibleTrader;
        else if (pick < 7) actor = i_ineligibleTrader;
        else actor = i_outsider;
    }

    /// @dev Selects the account a generated liquidity action originates from.
    function _liquidityActor(uint256 _seed) internal view returns (address actor) {
        uint256 pick = _seed % 8;

        if (pick < 5) actor = i_eligibleProvider;
        else if (pick < 7) actor = i_ineligibleProvider;
        else actor = i_outsider;
    }

    /// @dev Selects the account a generated exercise request originates from.
    function _exerciseCaller(uint256 _seed) internal view returns (address exerciser) {
        uint256 pick = _seed % 8;

        if (pick < 6) exerciser = i_authorizedExerciser;
        else if (pick < 7) exerciser = i_unauthorizedExerciser;
        else exerciser = i_outsider;
    }

    /// @dev Decides whether a generated eligibility mutation grants or revokes.
    ///
    ///      Revocation stays reachable on every call, but a history in which every eligible identity spent
    ///      half its life ineligible would refuse almost everything and reach very little composition, so
    ///      grants are the more common draw.
    function _grantsEligibility(uint256 _seed) internal pure returns (bool eligible) {
        eligible = _seed % 4 != 0;
    }

    /// @dev Selects the account a generated eligibility mutation originates from.
    function _eligibilityCaller(uint256 _seed) internal view returns (address caller) {
        caller = _seed % 8 == 0 ? i_outsider : i_registryAdmin;
    }

    /// @dev Selects the Beneficiary a generated admission proposes.
    function _proposedBeneficiary(uint256 _seed) internal view returns (address beneficiary) {
        uint256 pick = _seed % 8;

        if (pick < 4) beneficiary = i_beneficiaryA;
        else if (pick < 7) beneficiary = i_beneficiaryB;
        else beneficiary = i_ineligibleBeneficiary;
    }

    /// @dev Selects a Beneficiary whose eligibility the campaign is allowed to mutate.
    function _mutableBeneficiary(uint256 _seed) internal view returns (address beneficiary) {
        beneficiary = _seed % 2 == 0 ? i_beneficiaryA : i_beneficiaryB;
    }

    /// @dev Selects any persistent identity, including ones with no authority at all.
    function _anyActor(uint256 _seed) internal view returns (address actor) {
        uint256 pick = _seed % 6;

        if (pick == 0) actor = i_outsider;
        else if (pick == 1) actor = i_authorizedExerciser;
        else if (pick == 2) actor = i_unauthorizedExerciser;
        else if (pick == 3) actor = i_establishmentAuthority;
        else if (pick == 4) actor = i_registryAdmin;
        else actor = i_eligibleTrader;
    }

    /// @dev Selects one candidate liquidity range.
    ///
    ///      Four structurally different shapes: the bootstrap position, a position whose endpoints sit
    ///      exactly on the configured service boundaries, a position entirely outside the domain, and a
    ///      position whose endpoints sit strictly inside it — which the realization must refuse however
    ///      eligible the provider is.
    function _candidateRange(uint256 _seed) internal view returns (int24 tickLower, int24 tickUpper) {
        (int24 domainLow, int24 domainHigh) = i_tickQ < i_tickO ? (i_tickQ, i_tickO) : (i_tickO, i_tickQ);

        uint256 pick = _seed % LIQUIDITY_RANGE_COUNT;

        if (pick == 0) return (i_lpTickLower, i_lpTickUpper);
        if (pick == 1) return (domainLow, domainHigh);
        if (pick == 2) return (i_lpTickLower - 10 * i_tickSpacing, domainLow);

        return (domainLow + i_tickSpacing, domainHigh - i_tickSpacing);
    }

    /// @dev The custody key of one actor's position over one range.
    function _positionKey(address _actor, int24 _tickLower, int24 _tickUpper) internal pure returns (bytes32 key) {
        key = keccak256(abi.encode(_actor, _tickLower, _tickUpper));
    }

    /// @dev Reports whether a rejection reason carries the Standby insufficient-backing refusal.
    ///
    ///      A Hook rejection reaches a caller wrapped by the pinned `Hooks` library, so the Standby reason
    ///      is a payload inside it rather than the outer selector. This searches for it. It is diagnostic
    ///      only: no campaign outcome depends on the classification.
    function _reportsInsufficientProspectiveBacking(bytes memory _reason) internal pure returns (bool reports) {
        bytes4 selector = StandbyHook.StandbyHook__InsufficientProspectiveBacking.selector;

        if (_reason.length < 4) return false;

        for (uint256 offset = 0; offset + 4 <= _reason.length; ++offset) {
            if (
                _reason[offset] == selector[0] && _reason[offset + 1] == selector[1]
                    && _reason[offset + 2] == selector[2] && _reason[offset + 3] == selector[3]
            ) return true;
        }
    }
}
