// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";

import {DeployStandbyHook} from "../../script/DeployStandbyHook.s.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {ExerciseRouter} from "../../src/ExerciseRouter.sol";
import {StandbyHook} from "../../src/StandbyHook.sol";
import {ActorAwareTestRouter} from "../../src/demo/ActorAwareTestRouter.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";
import {IInvariantCurrency, StandbyInvariantHandler} from "./StandbyInvariantHandler.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared production-only environment and global invariant closure for the GI campaigns.
/// @dev Every contract this fixture stands up is the production one, and every fact it establishes is
///      established the way production establishes it: the real pinned `PoolManager`, the canonical
///      `DeployStandbyHook` mining and deployment procedure, the real `EligibilityRegistry` under its own
///      administrator, the production `ExerciseRouter` the service is activated with, a real
///      `PoolManager.initialize`, the production `configureAndActivate` transition, and bootstrap liquidity
///      added through the production `beforeAddLiquidity` path by an eligible provider routed through the
///      trusted liquidity perimeter.
///
///      No `StandbyHookHarness` is involved anywhere. No Remaining Entitlement, admitted extent, bounded
///      reference, Supporting Capacity, Capacity Obligation, validity, exercisability, fulfillment, or O2
///      causal state is written directly. The only thing this fixture decides is the configuration the
///      service is activated with; everything after activation is reached by generated production
///      transitions.
///
///      The fixture is parameterized rather than canonical-only, because GI must not prove safety for one
///      demo identity and direction. A concrete campaign supplies its service geometry and its currencies.
///
///      Two independent oracles carry the derivation equivalence. Supporting Capacity is recomputed by
///      `ReferenceCalculations` from authoritative PoolManager state with its own Q64.96 arithmetic.
///      Aggregate Capacity Obligation is recomputed from the persisted commitment *facts* of the whole
///      allocated history — every identity in `[1, nextCommitmentId)`, not the bounded index production
///      scans — so an obligation that silently escaped the index would be visible as a disagreement rather
///      than shared by both sides of the comparison.
abstract contract BaseStandbyInvariantTest is Test {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The complete description of the Standby service one campaign runs against.
    /// @param decimals0 The decimal precision of currency0.
    /// @param decimals1 The decimal precision of currency1.
    /// @param protectedZeroForOne The protected swap direction.
    /// @param initialTick The tick whose exact price the pool is initialized at.
    /// @param tickQ The protected execution-quality boundary.
    /// @param tickO The opposite realization-domain boundary.
    /// @param lpTickLower The lower endpoint of the bootstrap liquidity position.
    /// @param lpTickUpper The upper endpoint of the bootstrap liquidity position.
    /// @param tickSpacing The pool tick spacing.
    /// @param lpFee The static LP fee, in pips.
    /// @param liquidity The bootstrap liquidity added over the position.
    struct InvariantServiceConfig {
        uint8 decimals0;
        uint8 decimals1;
        bool protectedZeroForOne;
        int24 initialTick;
        int24 tickQ;
        int24 tickO;
        int24 lpTickLower;
        int24 lpTickUpper;
        int24 tickSpacing;
        uint24 lpFee;
        uint128 liquidity;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A realistic starting time, so both an already-open and a not-yet-open exercise window are
    ///      expressible against the same campaign.
    uint256 internal constant FIXTURE_TIMESTAMP = 1_800_000_000;

    /// @dev Campaign funding. Far larger than any position, swap, or exercise a campaign can produce.
    uint256 internal constant CAMPAIGN_FUNDING = 1e30;

    /// @dev The bound on the deterministic search for correctly ordered currency addresses.
    uint256 internal constant MAX_CURRENCY_ORDERING_ATTEMPTS = 64;

    address internal configurationAuthority;
    address internal registryAdmin;
    address internal establishmentAuthority;
    address internal beneficiaryA;
    address internal beneficiaryB;
    address internal ineligibleBeneficiary;
    address internal authorizedExerciser;
    address internal unauthorizedExerciser;
    address internal eligibleTrader;
    address internal ineligibleTrader;
    address internal eligibleProvider;
    address internal ineligibleProvider;
    address internal donor;
    address internal outsider;

    IPoolManager internal poolManager;
    ActorAwareTestRouter internal swapPerimeter;
    ActorAwareTestRouter internal liquidityPerimeter;
    DeployStandbyHook internal hookDeployer;
    StandbyHook internal hook;
    EligibilityRegistry internal registry;
    ExerciseRouter internal exerciseRouter;

    IInvariantCurrency internal currency0;
    IInvariantCurrency internal currency1;

    PoolKey internal servicePoolKey;
    PoolId internal servicePoolId;

    InvariantServiceConfig internal serviceConfig;

    StandbyInvariantHandler internal handler;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Builds, activates, and bootstraps one production Standby service and its campaign handler.
    function setUp() public virtual {
        serviceConfig = _serviceConfig();

        _createActors();

        poolManager = IPoolManager(address(new PoolManager(address(this))));

        swapPerimeter = new ActorAwareTestRouter(poolManager);
        liquidityPerimeter = new ActorAwareTestRouter(poolManager);

        hookDeployer = new DeployStandbyHook();

        (hook,) = hookDeployer.deployStandbyHook(
            poolManager,
            address(hookDeployer),
            configurationAuthority,
            address(swapPerimeter),
            address(liquidityPerimeter)
        );

        registry = new EligibilityRegistry(registryAdmin);
        exerciseRouter = new ExerciseRouter(hook);

        (currency0, currency1) = _deployCurrencies();

        servicePoolKey = PoolKey({
            currency0: Currency.wrap(address(currency0)),
            currency1: Currency.wrap(address(currency1)),
            fee: serviceConfig.lpFee,
            tickSpacing: serviceConfig.tickSpacing,
            hooks: IHooks(address(hook))
        });
        servicePoolId = servicePoolKey.toId();

        poolManager.initialize(servicePoolKey, TickMath.getSqrtPriceAtTick(serviceConfig.initialTick));

        vm.prank(configurationAuthority);
        hook.configureAndActivate(
            servicePoolKey,
            serviceConfig.protectedZeroForOne,
            serviceConfig.tickQ,
            serviceConfig.tickO,
            IEligibilityRegistry(address(registry)),
            address(exerciseRouter),
            establishmentAuthority
        );

        _grantInitialEligibility();
        _fundActors();
        _addBootstrapLiquidity();

        vm.warp(FIXTURE_TIMESTAMP);

        handler = new StandbyInvariantHandler(_environment(), _actors());

        _targetCampaignActions();
    }

    /*//////////////////////////////////////////////////////////////
                        GI-A — ECONOMIC BACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves production Supporting Capacity equals its independent reconstruction. (G-I-1)
    function invariant_supportingCapacityEqualsIndependentReference() public view {
        assertEq(
            hook.supportingCapacity(),
            _referenceSupportingCapacity(),
            "production Supporting Capacity must equal the independent reference"
        );
    }

    /// @notice Proves production Aggregate Capacity Obligation equals its independent reconstruction.
    ///         (G-I-2)
    /// @dev The reference sums the whole allocated commitment history rather than the bounded index, so an
    ///      obligation that vanished from the index is a disagreement rather than a shared blind spot.
    function invariant_capacityObligationEqualsIndependentReference() public view {
        assertEq(
            hook.aggregateObligation(),
            _referenceAggregateObligation(),
            "production Aggregate Capacity Obligation must equal the independent reference"
        );
    }

    /// @notice Proves the service stays backed in every reachable authoritative state. (G-I-3)
    function invariant_supportingCapacityCoversCapacityObligation() public view {
        assertGe(
            _referenceSupportingCapacity(),
            _referenceAggregateObligation(),
            "Supporting Capacity must never fall below Aggregate Capacity Obligation"
        );
    }

    /*//////////////////////////////////////////////////////////////
                     GI-B/C — COMMITMENT CONSERVATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves every commitment's admitted facts, bound, monotonicity, and conservation.
    ///         (G-I-4, G-I-5, G-I-6, G-I-7)
    function invariant_commitmentConservation() public view {
        uint256 count = handler.commitmentCount();

        for (uint256 i = 0; i < count; ++i) {
            uint256 commitmentId = handler.knownCommitmentIds(i);

            StandbyHook.Commitment memory record = hook.commitment(commitmentId);
            StandbyInvariantHandler.AdmittedFacts memory facts = handler.admittedCommitmentFacts(commitmentId);

            assertEq(
                PoolId.unwrap(record.serviceId),
                PoolId.unwrap(facts.serviceId),
                "an admitted service identity must never change"
            );
            assertEq(record.beneficiary, facts.beneficiary, "an admitted Beneficiary must never change");
            assertEq(
                record.exerciseAuthority, facts.exerciseAuthority, "an admitted exercise authority must never change"
            );
            assertEq(
                uint256(record.exercisableFrom),
                uint256(facts.exercisableFrom),
                "an admitted exercise window must never change"
            );
            assertEq(uint256(record.validUntil), uint256(facts.validUntil), "an admitted validity must never change");
            assertEq(
                uint256(record.originalEntitlement),
                uint256(facts.originalEntitlement),
                "an admitted entitlement extent must never be rewritten"
            );

            assertLe(
                uint256(record.remainingEntitlement),
                uint256(facts.originalEntitlement),
                "Remaining Entitlement must never exceed the admitted extent"
            );
            assertLe(
                uint256(record.remainingEntitlement),
                uint256(handler.ghostLastRemaining(commitmentId)),
                "Remaining Entitlement must never increase"
            );
            assertEq(
                uint256(facts.originalEntitlement) - uint256(record.remainingEntitlement),
                handler.ghostFulfilled(commitmentId),
                "the discharged portion must equal independently tracked successful fulfillment"
            );
        }
    }

    /// @notice Proves every Beneficiary holds exactly Standby delivery plus unrelated donation.
    ///         (G-I-12, G-I-14)
    /// @dev No Beneficiary trades, provides liquidity, exercises, or holds protected output at campaign
    ///      start, so its balance is a complete independent history of everything that reached it. Standby
    ///      delivery and unrelated donation are accounted separately, so a direct transfer can never be
    ///      mistaken for fulfillment and fulfillment can never be satisfied by a donation.
    function invariant_beneficiaryHoldingsMatchIndependentDeliveryHistory() public view {
        _assertBeneficiaryHoldings(beneficiaryA);
        _assertBeneficiaryHoldings(beneficiaryB);
        _assertBeneficiaryHoldings(ineligibleBeneficiary);
    }

    /*//////////////////////////////////////////////////////////////
                    GI-E — BOUNDED REFERENCE INTEGRITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the bounded index stays bounded, unique, and non-dangling. (G-I-17, G-I-18)
    function invariant_boundedReferenceIntegrity() public view {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();
        uint256 nextCommitmentId = hook.nextCommitmentId();
        uint256 live;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            uint256 commitmentId = references[slot];

            if (commitmentId == 0) continue;

            ++live;

            assertLt(commitmentId, nextCommitmentId, "a live reference must resolve to an allocated commitment");

            for (uint256 other = slot + 1; other < MAX_LIVE_COMMITMENTS; ++other) {
                assertTrue(references[other] != commitmentId, "a commitment must never occupy two references");
            }
        }

        assertLe(live, MAX_LIVE_COMMITMENTS, "the live reference set must stay bounded");
    }

    /// @notice Proves only frozen permanent non-binding causes release a live reference. (G-I-20)
    /// @dev Stated as its contrapositive, which is the checkable form: every commitment that still carries
    ///      a positive Capacity Obligation still occupies a reference. A binding commitment that had lost
    ///      its reference would have silently left the aggregate the whole service is enforced against.
    function invariant_bindingCommitmentsRetainALiveReference() public view {
        uint256 nextCommitmentId = hook.nextCommitmentId();

        for (uint256 commitmentId = 1; commitmentId < nextCommitmentId; ++commitmentId) {
            StandbyHook.Commitment memory record = hook.commitment(commitmentId);

            uint256 obligation = ReferenceCalculations.referenceCommitmentObligation(
                record.remainingEntitlement, record.validUntil, block.timestamp
            );

            if (obligation == 0) continue;

            assertTrue(_isReferenced(commitmentId), "a commitment still carrying obligation must stay referenced");
        }
    }

    /*//////////////////////////////////////////////////////////////
                      GI-D/GI-23 — CUSTODY / CAUSALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the protocol holds no currency custody of any kind. (G-I-16)
    /// @dev No campaign action donates to the Hook or the ExerciseRouter, so any balance either holds was
    ///      created by a protocol flow. Both currencies are checked, because a coordinator that briefly
    ///      held the input side would be a custodian just as much as one holding the output.
    function invariant_protocolHoldsNoCurrencyCustody() public view {
        assertEq(currency0.balanceOf(address(hook)), 0, "the Hook must hold no currency0");
        assertEq(currency1.balanceOf(address(hook)), 0, "the Hook must hold no currency1");
        assertEq(currency0.balanceOf(address(exerciseRouter)), 0, "the ExerciseRouter must hold no currency0");
        assertEq(currency1.balanceOf(address(exerciseRouter)), 0, "the ExerciseRouter must hold no currency1");
    }

    /// @notice Proves no reusable O2 causal evidence survives a completed transaction. (G-I-21)
    function invariant_noReusableCausalEvidenceSurvives() public view {
        StandbyHook.ExerciseAuthorizationContext memory context = hook.exerciseAuthorization();

        assertEq(
            uint256(context.state),
            uint256(StandbyHook.ExerciseAuthorizationState.EMPTY),
            "no causal context may survive its transaction"
        );
        assertEq(PoolId.unwrap(context.serviceId), bytes32(0), "no surviving causal context may name a service");
        assertEq(context.commitmentId, 0, "no surviving causal context may name a commitment");
        assertEq(context.exerciseRouter, address(0), "no surviving causal context may name a coordinator");
        assertEq(context.exerciser, address(0), "no surviving causal context may name an exerciser");
        assertEq(context.beneficiary, address(0), "no surviving causal context may name a Beneficiary");
        assertEq(context.q, 0, "no surviving causal context may carry a quantity");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The service geometry this campaign runs against.
    function _serviceConfig() internal view virtual returns (InvariantServiceConfig memory config);

    /// @dev Deploys the campaign's currencies, already satisfying the Uniswap ordering requirement.
    function _deployCurrencies()
        internal
        virtual
        returns (IInvariantCurrency deployed0, IInvariantCurrency deployed1);

    /// @dev Creates the bounded persistent actor universe, one identity per role.
    function _createActors() internal {
        configurationAuthority = makeAddr("configurationAuthority");
        registryAdmin = makeAddr("registryAdmin");
        establishmentAuthority = makeAddr("establishmentAuthority");
        beneficiaryA = makeAddr("beneficiaryA");
        beneficiaryB = makeAddr("beneficiaryB");
        ineligibleBeneficiary = makeAddr("ineligibleBeneficiary");
        authorizedExerciser = makeAddr("authorizedExerciser");
        unauthorizedExerciser = makeAddr("unauthorizedExerciser");
        eligibleTrader = makeAddr("eligibleTrader");
        ineligibleTrader = makeAddr("ineligibleTrader");
        eligibleProvider = makeAddr("eligibleProvider");
        ineligibleProvider = makeAddr("ineligibleProvider");
        donor = makeAddr("donor");
        outsider = makeAddr("outsider");
    }

    /// @dev Grants the eligibility the campaign starts from, through the registry's own administrator.
    ///
    ///      The three permanently ineligible identities are never granted anything here and are never
    ///      candidates for a campaign eligibility mutation, so "ineligible" stays a stable relationship a
    ///      multi-operation history can be verified against.
    function _grantInitialEligibility() internal {
        vm.startPrank(registryAdmin);

        registry.setBeneficiaryEligibility(beneficiaryA, true);
        registry.setBeneficiaryEligibility(beneficiaryB, true);
        registry.setTraderEligibility(eligibleTrader, true);
        registry.setLiquidityEligibility(eligibleProvider, true);

        vm.stopPrank();
    }

    /// @dev Funds the campaign actors by role, and only by role.
    ///
    ///      The asymmetry is deliberate and load-bearing. Beneficiaries are funded with nothing at all, so
    ///      every unit of protected output they ever hold arrived through a Standby delivery or an
    ///      unrelated donation this campaign tracked. Exercisers hold input currency only, so an exercise
    ///      delivery can never have come out of the exerciser's own protected-output balance. The donor
    ///      holds protected output and no Standby role whatsoever.
    function _fundActors() internal {
        _fundTradingActor(eligibleTrader);
        _fundTradingActor(ineligibleTrader);
        _fundTradingActor(eligibleProvider);
        _fundTradingActor(ineligibleProvider);
        _fundTradingActor(outsider);

        _fundExerciser(authorizedExerciser);
        _fundExerciser(unauthorizedExerciser);

        _protectedOutputCurrency().mint(donor, CAMPAIGN_FUNDING);
    }

    /// @dev Funds an actor with both currencies and approves both trusted perimeters on its behalf.
    function _fundTradingActor(address _account) internal {
        currency0.mint(_account, CAMPAIGN_FUNDING);
        currency1.mint(_account, CAMPAIGN_FUNDING);

        vm.startPrank(_account);

        currency0.approve(address(swapPerimeter), type(uint256).max);
        currency1.approve(address(swapPerimeter), type(uint256).max);
        currency0.approve(address(liquidityPerimeter), type(uint256).max);
        currency1.approve(address(liquidityPerimeter), type(uint256).max);

        vm.stopPrank();
    }

    /// @dev Funds an exerciser with input currency only, and lets the production router coordinate payment.
    function _fundExerciser(address _account) internal {
        IInvariantCurrency inputCurrency = _inputCurrency();

        inputCurrency.mint(_account, CAMPAIGN_FUNDING);

        vm.prank(_account);
        inputCurrency.approve(address(exerciseRouter), type(uint256).max);
    }

    /// @dev Adds the bootstrap liquidity through the production enforcement path.
    function _addBootstrapLiquidity() internal {
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: serviceConfig.lpTickLower,
            tickUpper: serviceConfig.lpTickUpper,
            liquidityDelta: int256(uint256(serviceConfig.liquidity)),
            salt: bytes32(0)
        });

        vm.prank(eligibleProvider);
        liquidityPerimeter.modifyLiquidity(servicePoolKey, params, bytes(""));
    }

    /// @dev Restricts the campaign to the handler's generated action surface.
    ///
    ///      The scripted entry points the sequence suites use are deliberately excluded: they exist so a
    ///      required semantic sequence can be expressed directly, and letting the fuzzer call them with
    ///      unconstrained addresses would replace the persistent actor universe with anonymous callers.
    function _targetCampaignActions() internal {
        bytes4[] memory selectors = new bytes4[](12);

        selectors[0] = StandbyInvariantHandler.establishCommitment.selector;
        selectors[1] = StandbyInvariantHandler.exercise.selector;
        selectors[2] = StandbyInvariantHandler.ordinaryProtectedSwap.selector;
        selectors[3] = StandbyInvariantHandler.ordinaryOppositeSwap.selector;
        selectors[4] = StandbyInvariantHandler.addLiquidity.selector;
        selectors[5] = StandbyInvariantHandler.removeLiquidity.selector;
        selectors[6] = StandbyInvariantHandler.advanceTime.selector;
        selectors[7] = StandbyInvariantHandler.setBeneficiaryEligibility.selector;
        selectors[8] = StandbyInvariantHandler.setTraderEligibility.selector;
        selectors[9] = StandbyInvariantHandler.setLiquidityEligibility.selector;
        selectors[10] = StandbyInvariantHandler.directTransferProtectedTokenToBeneficiary.selector;
        selectors[11] = StandbyInvariantHandler.attemptOrphanExerciseEvidence.selector;

        targetContract(address(handler));
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    /// @dev Assembles the production environment the handler drives.
    function _environment() internal view returns (StandbyInvariantHandler.InvariantEnvironment memory environment) {
        environment = StandbyInvariantHandler.InvariantEnvironment({
            poolManager: poolManager,
            hook: hook,
            exerciseRouter: exerciseRouter,
            registry: registry,
            swapPerimeter: swapPerimeter,
            liquidityPerimeter: liquidityPerimeter,
            currency0: currency0,
            currency1: currency1,
            poolKey: servicePoolKey,
            protectedZeroForOne: serviceConfig.protectedZeroForOne,
            tickQ: serviceConfig.tickQ,
            tickO: serviceConfig.tickO,
            tickSpacing: serviceConfig.tickSpacing,
            lpTickLower: serviceConfig.lpTickLower,
            lpTickUpper: serviceConfig.lpTickUpper,
            initialLiquidity: serviceConfig.liquidity,
            initialCapacity: _referenceSupportingCapacity()
        });
    }

    /// @dev Assembles the bounded persistent actor universe the handler acts through.
    function _actors() internal view returns (StandbyInvariantHandler.InvariantActors memory actors) {
        actors = StandbyInvariantHandler.InvariantActors({
            registryAdmin: registryAdmin,
            establishmentAuthority: establishmentAuthority,
            beneficiaryA: beneficiaryA,
            beneficiaryB: beneficiaryB,
            ineligibleBeneficiary: ineligibleBeneficiary,
            authorizedExerciser: authorizedExerciser,
            unauthorizedExerciser: unauthorizedExerciser,
            eligibleTrader: eligibleTrader,
            ineligibleTrader: ineligibleTrader,
            eligibleProvider: eligibleProvider,
            ineligibleProvider: ineligibleProvider,
            donor: donor,
            outsider: outsider
        });
    }

    /// @dev Independently derives Supporting Capacity from authoritative PoolManager state.
    function _referenceSupportingCapacity() internal view returns (uint256 capacity) {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(servicePoolId);

        capacity = ReferenceCalculations.referenceSupportingCapacity(
            serviceConfig.protectedZeroForOne,
            sqrtPriceX96,
            serviceConfig.tickQ,
            poolManager.getLiquidity(servicePoolId)
        );
    }

    /// @dev Independently derives Aggregate Capacity Obligation over the whole allocated history.
    function _referenceAggregateObligation() internal view returns (uint256 obligation) {
        uint256 nextCommitmentId = hook.nextCommitmentId();

        for (uint256 commitmentId = 1; commitmentId < nextCommitmentId; ++commitmentId) {
            StandbyHook.Commitment memory record = hook.commitment(commitmentId);

            obligation += ReferenceCalculations.referenceCommitmentObligation(
                record.remainingEntitlement, record.validUntil, block.timestamp
            );
        }
    }

    /// @dev Proves an account holds exactly what Standby delivered plus what unrelated transfers donated.
    function _assertBeneficiaryHoldings(address _beneficiary) internal view {
        assertEq(
            _protectedOutputCurrency().balanceOf(_beneficiary),
            handler.ghostDelivered(_beneficiary) + handler.ghostDonated(_beneficiary),
            "a Beneficiary must hold exactly Standby delivery plus unrelated donation"
        );
    }

    /// @dev Reports whether the bounded index currently references an identity.
    function _isReferenced(uint256 _commitmentId) internal view returns (bool referenced) {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] == _commitmentId) return true;
        }
    }

    /// @dev The protected output currency, selected by the protected direction alone.
    function _protectedOutputCurrency() internal view returns (IInvariantCurrency currency) {
        currency = serviceConfig.protectedZeroForOne ? currency1 : currency0;
    }

    /// @dev The protected input currency, selected by the protected direction alone.
    function _inputCurrency() internal view returns (IInvariantCurrency currency) {
        currency = serviceConfig.protectedZeroForOne ? currency0 : currency1;
    }
}
