// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {console2} from "forge-std/console2.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseStandbyInvariantTest} from "./BaseStandbyInvariantTest.t.sol";
import {StandbyInvariantHandler} from "./StandbyInvariantHandler.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice The required GI stateful sequence classes, driven through the same adversarial handler.
/// @dev These are stateful histories, not unit tests. Each one composes several authoritative transitions
///      in a fixed order and asserts what the composition must have preserved — which is exactly what a
///      generated campaign explores, expressed here as the specific semantic classes GI is required to
///      reach rather than left to whether a particular seed happened to reach them.
///
///      Every action runs through `StandbyInvariantHandler`, so each step in a sequence carries the same
///      transition-local evidence a generated action carries: exact fulfillment attribution, exact
///      Beneficiary delivery, unchanged commitment facts, monotone remainders, fulfillment conservation,
///      empty causal context, and zero protocol custody. The sequences add the ordering.
///
///      Nothing here is configuration-specific. The economic quantities are derived from the campaign's own
///      independently reconstructed Supporting Capacity and Aggregate Capacity Obligation, so the same
///      sequences are meaningful under the canonical `zeroForOne` service and the generalized `oneForZero`
///      one with asymmetric decimal precision.
abstract contract StandbySequenceEvidence is BaseStandbyInvariantTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The number of generated actions the deterministic diagnostic campaign performs.
    uint256 internal constant DIAGNOSTIC_CAMPAIGN_STEPS = 600;

    /// @dev The default admitted validity duration of a scripted commitment.
    uint64 internal constant SEQUENCE_VALIDITY = 30 days;

    /// @dev The number of generated action kinds the diagnostic campaign draws from.
    uint256 internal constant CAMPAIGN_ACTION_COUNT = 12;

    /*//////////////////////////////////////////////////////////////
                        BACKING PRESSURE CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves ordinary swaps respect an authentic obligation across a multi-step history.
    /// @dev O1 -> backing-preserving protected swap -> backing-destructive protected swap attempt ->
    ///      opposite-direction swap -> partial O2 -> protected swap.
    function test_backingPressureSequence_preservesBackingAcrossOrdinaryAndProtectedTransitions() public {
        uint256 capacity = _referenceSupportingCapacity();
        uint128 entitlement = uint128(capacity / 2);

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        assertEq(hook.aggregateObligation(), entitlement, "O1 must establish an authentic positive obligation");

        assertTrue(
            _protectedExactOutputSwap(eligibleTrader, (capacity - entitlement) / 2),
            "a backing-preserving protected swap must be admitted"
        );

        uint256 pressured = _referenceSupportingCapacity();

        assertLt(pressured, capacity, "the admitted swap must actually consume Supporting Capacity");
        assertGe(pressured, hook.aggregateObligation(), "backing must survive the admitted swap");

        assertFalse(
            _protectedExactOutputSwap(eligibleTrader, _destructiveProtectedOutput(pressured)),
            "a backing-destructive protected swap must be refused"
        );

        assertEq(_referenceSupportingCapacity(), pressured, "a refused swap must leave the authoritative pool alone");
        assertEq(hook.aggregateObligation(), uint256(entitlement), "a refused swap must release no obligation");

        assertTrue(
            _oppositeExactInputSwap(eligibleTrader, capacity / 8), "an opposite-direction swap must remain admissible"
        );
        assertGt(_referenceSupportingCapacity(), pressured, "the opposite-direction swap must restore capacity");

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement / 2, type(uint256).max),
            "a backed partial exercise must complete"
        );

        assertTrue(
            _protectedExactOutputSwap(eligibleTrader, (_referenceSupportingCapacity() - hook.aggregateObligation()) / 2),
            "a backing-preserving protected swap must remain admissible after fulfillment"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                        ELIGIBILITY CHURN CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves eligibility loss releases nothing and eligibility restoration fulfils nothing.
    /// @dev O1 -> Beneficiary eligibility off -> backing-threatening O3 attempt -> O2 attempt ->
    ///      Beneficiary eligibility on -> O2.
    function test_eligibilityChurnSequence_neverReleasesObligationOrManufacturesFulfillment() public {
        uint256 capacity = _referenceSupportingCapacity();
        uint128 entitlement = uint128(capacity / 2);

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        assertTrue(
            handler.scriptedSetBeneficiaryEligibility(registryAdmin, beneficiaryA, false),
            "the registry administrator must be able to revoke Beneficiary eligibility"
        );

        assertEq(
            hook.aggregateObligation(),
            uint256(entitlement),
            "Beneficiary ineligibility must not release a binding obligation"
        );

        assertFalse(
            _protectedExactOutputSwap(eligibleTrader, _destructiveProtectedOutput(_referenceSupportingCapacity())),
            "an obligation held by an ineligible Beneficiary must still refuse a destructive swap"
        );

        assertFalse(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement / 4, type(uint256).max),
            "an ineligible Beneficiary must not be exercised for"
        );

        assertEq(
            uint256(hook.commitment(commitmentId).remainingEntitlement),
            uint256(entitlement),
            "a refused exercise must fulfil nothing"
        );

        assertTrue(
            handler.scriptedSetBeneficiaryEligibility(registryAdmin, beneficiaryA, true),
            "the registry administrator must be able to restore Beneficiary eligibility"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement / 4, type(uint256).max),
            "a restored Beneficiary must be exercisable again"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                       MULTIPLE COMMITMENT CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves fulfillment is attributed to exactly one commitment across interleaved exercises.
    /// @dev O1(C1) -> O1(C2) -> partial O2(C1) -> ordinary swap -> O2(C2) -> later O2(C1).
    function test_multipleCommitmentSequence_attributesEveryFulfillmentToExactlyOneCommitment() public {
        uint256 capacity = _referenceSupportingCapacity();
        uint128 entitlement = uint128(capacity / 4);

        uint256 first = _establishStandardCommitment(beneficiaryA, entitlement);
        uint256 second = _establishStandardCommitment(beneficiaryB, entitlement);

        assertEq(hook.aggregateObligation(), uint256(entitlement) * 2, "both commitments must be binding");

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, first, entitlement / 2, type(uint256).max),
            "the first commitment must be partially exercisable"
        );

        assertEq(
            uint256(hook.commitment(second).remainingEntitlement),
            uint256(entitlement),
            "one commitment's fulfillment must not reduce another"
        );

        assertTrue(
            _protectedExactOutputSwap(eligibleTrader, (_referenceSupportingCapacity() - hook.aggregateObligation()) / 2),
            "an ordinary swap must remain admissible between exercises"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, second, entitlement, type(uint256).max),
            "the second commitment must be exhaustible"
        );

        assertEq(uint256(hook.commitment(second).remainingEntitlement), 0, "full exercise must exhaust the remainder");

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, first, entitlement / 2, type(uint256).max),
            "the first commitment must remain exercisable afterwards"
        );

        assertEq(uint256(hook.commitment(first).remainingEntitlement), 0, "the first commitment must now be exhausted");
        assertEq(hook.aggregateObligation(), 0, "two exhausted commitments must impose nothing");

        assertEq(
            _protectedOutputCurrency().balanceOf(beneficiaryA),
            uint256(entitlement),
            "the first Beneficiary must hold exactly its own fulfillment"
        );
        assertEq(
            _protectedOutputCurrency().balanceOf(beneficiaryB),
            uint256(entitlement),
            "the second Beneficiary must hold exactly its own fulfillment"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                         EXPIRY / REUSE CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves expiry releases obligation without fulfilling, and that slots reuse without amnesia.
    /// @dev 16 x O1 -> exhausted bounded index -> refused O1 -> advance time -> expiry -> new O1 ->
    ///      reference reuse -> historical commitment interaction.
    function test_expiryAndReuseSequence_reclaimsReferencesWithoutRewritingHistory() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity() / 32);
        uint64 validUntil = uint64(block.timestamp) + 1 days;

        uint256[] memory established = new uint256[](MAX_LIVE_COMMITMENTS);

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            (bool admitted, uint256 commitmentId) = handler.scriptedEstablish(
                establishmentAuthority,
                beneficiaryA,
                authorizedExerciser,
                entitlement,
                uint64(block.timestamp),
                validUntil
            );

            assertTrue(admitted, "the bounded index must admit sixteen live commitments");

            established[i] = commitmentId;
        }

        assertEq(
            hook.aggregateObligation(),
            uint256(entitlement) * MAX_LIVE_COMMITMENTS,
            "sixteen live commitments must all be binding"
        );

        (bool overflowAdmitted,) = handler.scriptedEstablish(
            establishmentAuthority, beneficiaryA, authorizedExerciser, entitlement, uint64(block.timestamp), validUntil
        );

        assertFalse(overflowAdmitted, "a full bounded index must refuse a seventeenth live commitment");

        StandbyHook.Commitment memory displaced = hook.commitment(established[0]);

        handler.scriptedAdvanceTime(2 days);

        assertEq(hook.aggregateObligation(), 0, "expiry must release every obligation");
        assertEq(
            uint256(hook.commitment(established[0]).remainingEntitlement),
            uint256(entitlement),
            "expiry must not rewrite Remaining Entitlement as though it were fulfilled"
        );
        assertEq(handler.ghostFulfilled(established[0]), 0, "expiry must manufacture no fulfillment");

        uint256 nextBefore = hook.nextCommitmentId();

        (bool reusedAdmission, uint256 reusedId) = handler.scriptedEstablish(
            establishmentAuthority,
            beneficiaryB,
            authorizedExerciser,
            entitlement,
            uint64(block.timestamp),
            uint64(block.timestamp) + SEQUENCE_VALIDITY
        );

        assertTrue(reusedAdmission, "an expired reference must become reclaimable");
        assertEq(reusedId, nextBefore, "commitment identities must never be recycled");

        StandbyHook.Commitment memory afterReuse = hook.commitment(established[0]);

        assertEq(
            uint256(afterReuse.originalEntitlement),
            uint256(displaced.originalEntitlement),
            "slot reuse must not rewrite a historical admitted extent"
        );
        assertEq(
            uint256(afterReuse.remainingEntitlement),
            uint256(displaced.remainingEntitlement),
            "slot reuse must not rewrite a historical remainder"
        );
        assertEq(afterReuse.beneficiary, displaced.beneficiary, "slot reuse must not rewrite a historical Beneficiary");
        assertEq(
            uint256(afterReuse.validUntil),
            uint256(displaced.validUntil),
            "slot reuse must not rewrite a historical term"
        );

        assertFalse(
            handler.scriptedExercise(authorizedExerciser, established[0], entitlement, type(uint256).max),
            "an expired commitment must not be exercisable after its slot was reused"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, reusedId, entitlement, type(uint256).max),
            "the commitment now holding the reused slot must be exercisable"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                       FULFILLMENT CHURN CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves repeated partial exercise and final exhaustion stay exact.
    /// @dev O1 -> partial O2 -> ordinary swap -> second partial O2 -> full exhaustion.
    function test_fulfillmentChurnSequence_staysExactAcrossRepeatedPartialExercise() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity() / 2);

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        uint256 quarter = uint256(entitlement) / 4;

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, quarter, type(uint256).max),
            "the first partial exercise must complete"
        );

        assertTrue(
            _oppositeExactInputSwap(eligibleTrader, quarter), "an opposite-direction swap must remain admissible"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, quarter, type(uint256).max),
            "the second partial exercise must complete"
        );

        uint256 remainder = uint256(hook.commitment(commitmentId).remainingEntitlement);

        assertEq(remainder, uint256(entitlement) - 2 * quarter, "two partial exercises must discharge exactly twice q");

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, remainder, type(uint256).max),
            "the final exercise must exhaust the remainder"
        );

        assertEq(uint256(hook.commitment(commitmentId).remainingEntitlement), 0, "the commitment must be exhausted");
        assertEq(
            handler.ghostFulfilled(commitmentId),
            uint256(entitlement),
            "independently tracked fulfillment must equal the admitted extent"
        );
        assertEq(hook.aggregateObligation(), 0, "an exhausted commitment must impose nothing");
        assertEq(
            _protectedOutputCurrency().balanceOf(beneficiaryA),
            uint256(entitlement),
            "the Beneficiary must hold exactly the whole admitted extent"
        );

        assertFalse(
            handler.scriptedExercise(authorizedExerciser, commitmentId, 1, type(uint256).max),
            "an exhausted commitment must not be exercisable again"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                      CAUSAL CONTAMINATION CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves failed and completed O2 evidence never authorizes a later unrelated fulfillment.
    /// @dev failed O2(C1) -> valid O2(C2) -> O2(C1) -> orphan evidence -> O2(C2).
    function test_causalContaminationSequence_neverLetsOneExerciseAuthorizeAnother() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity() / 4);

        uint256 first = _establishStandardCommitment(beneficiaryA, entitlement);
        uint256 second = _establishStandardCommitment(beneficiaryB, entitlement);

        assertFalse(
            handler.scriptedExercise(unauthorizedExerciser, first, entitlement / 2, type(uint256).max),
            "an unauthorized exerciser must be refused"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, second, entitlement / 2, type(uint256).max),
            "a refused exercise must not contaminate an unrelated valid one"
        );

        assertEq(
            uint256(hook.commitment(first).remainingEntitlement),
            uint256(entitlement),
            "the refused exercise's commitment must be untouched"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, first, entitlement / 2, type(uint256).max),
            "the previously refused commitment must remain exercisable by its own authority"
        );

        handler.scriptedOrphanEvidence(authorizedExerciser, first);
        handler.scriptedOrphanEvidence(outsider, second);

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, second, entitlement / 2, type(uint256).max),
            "orphan evidence attempts must leave later valid exercise unaffected"
        );

        assertEq(
            handler.ghostFulfilled(first) + handler.ghostFulfilled(second),
            uint256(entitlement) / 2 * 3,
            "exactly three half-exercises may have been attributed"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                   EXTERNAL DELIVERY DISCRIMINATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves Beneficiary receipt of protected output is not Standby fulfillment.
    /// @dev O1 -> direct protected-token transfer to the Beneficiary -> O2.
    function test_directTransferSequence_isNeverFulfillmentAndNeverSatisfiesAnEntitlement() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity() / 2);

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        uint256 donation = uint256(entitlement) / 2;

        assertTrue(handler.scriptedDirectTransfer(beneficiaryA, donation), "an unrelated transfer must be possible");

        assertEq(
            _protectedOutputCurrency().balanceOf(beneficiaryA),
            donation,
            "the Beneficiary must have received the tokens"
        );
        assertEq(
            uint256(hook.commitment(commitmentId).remainingEntitlement),
            uint256(entitlement),
            "an unrelated transfer must not reduce Remaining Entitlement"
        );
        assertEq(hook.aggregateObligation(), uint256(entitlement), "an unrelated transfer must release no obligation");
        assertEq(handler.ghostFulfilled(commitmentId), 0, "an unrelated transfer must create no fulfillment");

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement, type(uint256).max),
            "the whole entitlement must still be exercisable after the donation"
        );

        assertEq(
            _protectedOutputCurrency().balanceOf(beneficiaryA),
            donation + uint256(entitlement),
            "the Beneficiary must hold the donation plus the whole fulfilled entitlement"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                    FAILED-OPERATION SEQUENCE CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves refused operations never change a later authoritative result.
    /// @dev failed O1 -> valid O1 -> failed backing-threatening O3 -> valid O2 -> failed liquidity action ->
    ///      valid ordinary swap.
    function test_failedOperationSequence_neverChangesALaterAuthoritativeResult() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity() / 2);

        (bool unauthorizedAdmission,) = handler.scriptedEstablish(
            outsider,
            beneficiaryA,
            authorizedExerciser,
            entitlement,
            uint64(block.timestamp),
            uint64(block.timestamp) + SEQUENCE_VALIDITY
        );

        assertFalse(unauthorizedAdmission, "an account without establishment authority must be refused");
        assertEq(hook.nextCommitmentId(), 1, "a refused O1 must consume no identity");

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        assertFalse(
            _protectedExactOutputSwap(eligibleTrader, _destructiveProtectedOutput(_referenceSupportingCapacity())),
            "a backing-threatening swap must be refused"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement / 2, type(uint256).max),
            "a refused O3 must not disturb a later valid O2"
        );

        assertFalse(
            handler.scriptedModifyLiquidity(
                ineligibleProvider,
                serviceConfig.lpTickLower,
                serviceConfig.lpTickUpper,
                int256(uint256(serviceConfig.liquidity)) / 8,
                false
            ),
            "an ineligible provider must be refused"
        );

        assertTrue(
            _protectedExactOutputSwap(eligibleTrader, (_referenceSupportingCapacity() - hook.aggregateObligation()) / 2),
            "a refused liquidity action must not disturb a later valid ordinary swap"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                         LIQUIDITY PERIMETER
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves caller and path variation cannot bypass effect-defined backing protection.
    /// @dev Untrusted perimeter, ineligible provider, prohibited interior topology, backing-threatening
    ///      removal, and backing-preserving removal, all against the same authentic obligation.
    function test_liquidityPerimeterSequence_cannotBypassEffectDefinedBackingProtection() public {
        uint128 entitlement = uint128((_referenceSupportingCapacity() * 3) / 4);

        _establishStandardCommitment(beneficiaryA, entitlement);

        int256 half = int256(uint256(serviceConfig.liquidity)) / 2;

        assertFalse(
            handler.scriptedModifyLiquidity(
                eligibleProvider, serviceConfig.lpTickLower, serviceConfig.lpTickUpper, -half, true
            ),
            "a removal routed through the ordinary-swap perimeter must be refused"
        );

        assertFalse(
            handler.scriptedModifyLiquidity(
                eligibleProvider, serviceConfig.lpTickLower, serviceConfig.lpTickUpper, -half, false
            ),
            "a backing-threatening removal must be refused whoever performs it"
        );

        assertFalse(
            handler.scriptedModifyLiquidity(
                eligibleProvider,
                serviceConfig.tickQ < serviceConfig.tickO
                    ? serviceConfig.tickQ + serviceConfig.tickSpacing
                    : serviceConfig.tickO + serviceConfig.tickSpacing,
                serviceConfig.tickQ < serviceConfig.tickO
                    ? serviceConfig.tickO - serviceConfig.tickSpacing
                    : serviceConfig.tickQ - serviceConfig.tickSpacing,
                int256(uint256(serviceConfig.liquidity)) / 8,
                false
            ),
            "a position introducing an interior boundary must be refused"
        );

        assertEq(hook.aggregateObligation(), uint256(entitlement), "no refused liquidity action may release obligation");

        assertTrue(
            handler.scriptedModifyLiquidity(
                eligibleProvider,
                serviceConfig.lpTickLower,
                serviceConfig.lpTickUpper,
                -int256(uint256(serviceConfig.liquidity)) / 16,
                false
            ),
            "a backing-preserving removal must remain possible"
        );

        assertGe(
            _referenceSupportingCapacity(), hook.aggregateObligation(), "the admitted removal must preserve backing"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                        BACKING BOUNDARY CLASS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves exact sufficiency at the backing boundary stays accepted under composition.
    /// @dev A commitment for the whole present Supporting Capacity leaves `S == O`, which preserves backing
    ///      and must be admitted. From there every capacity-reducing ordinary transition must be refused,
    ///      because any of them would leave `S < O` — while the exercise the commitment exists for stays
    ///      admissible, since a complete exercise releases exactly the obligation it consumes.
    function test_exactBackingBoundarySequence_acceptsExactSufficiencyAndRefusesEverythingBeyondIt() public {
        uint128 entitlement = uint128(_referenceSupportingCapacity());

        uint256 commitmentId = _establishStandardCommitment(beneficiaryA, entitlement);

        assertEq(
            hook.aggregateObligation(),
            _referenceSupportingCapacity(),
            "exact sufficiency must be admitted, leaving S equal to O"
        );

        assertFalse(
            _protectedExactOutputSwap(eligibleTrader, 1),
            "at exact sufficiency even the smallest capacity-reducing swap must be refused"
        );

        assertFalse(
            handler.scriptedModifyLiquidity(
                eligibleProvider,
                serviceConfig.lpTickLower,
                serviceConfig.lpTickUpper,
                -int256(uint256(serviceConfig.liquidity)) / 8,
                false
            ),
            "at exact sufficiency a liquidity removal must be refused"
        );

        assertTrue(
            _oppositeExactInputSwap(eligibleTrader, uint256(entitlement) / 8),
            "an opposite-direction swap must remain admissible at exact sufficiency"
        );

        assertTrue(
            handler.scriptedExercise(authorizedExerciser, commitmentId, entitlement / 2, type(uint256).max),
            "the exercise the commitment exists for must remain admissible"
        );

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                       CAMPAIGN QUALITY EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Runs a deterministic generated campaign and reports what it actually exercised. (G-I-23)
    /// @dev The same adversarial generator the stateful invariant campaigns drive, sequenced by a fixed
    ///      pseudo-random schedule so that the resulting activity is reproducible and reportable. Every
    ///      transition-local assertion the handler makes applies to every one of these actions.
    ///
    ///      The floors asserted below are test-quality guards and nothing else: they say a green result was
    ///      produced by a campaign that actually admitted commitments, fulfilled them partially and
    ///      completely, refused unbacked transitions against an authentic positive obligation, and moved
    ///      through lifecycle and eligibility change. They are not protocol semantics, and no protocol
    ///      requirement is expressed as a counter threshold.
    function test_deterministicCampaign_exercisesMeaningfulProtocolBehavior() public {
        uint256 seed = uint256(keccak256("standby.gi.deterministic.campaign"));

        for (uint256 step = 0; step < DIAGNOSTIC_CAMPAIGN_STEPS; ++step) {
            seed = uint256(keccak256(abi.encode(seed, step)));

            _performGeneratedAction(seed);
        }

        StandbyInvariantHandler.ActionCounters memory counters = handler.counters();

        _reportCampaign(counters);

        assertGt(counters.establishSuccesses, 0, "the campaign must admit commitments");
        assertGt(counters.establishRejections, 0, "the campaign must exercise refused admissions");
        assertGt(counters.maxObservedObligation, 0, "the campaign must reach an authentic positive obligation");
        assertGt(counters.maxLiveReferences, 1, "the campaign must hold several live commitments at once");

        assertGt(counters.exerciseSuccesses, 0, "the campaign must complete real exercises");
        assertGt(counters.exerciseRejections, 0, "the campaign must exercise refused exercises");
        assertGt(counters.partialFulfillments, 0, "the campaign must reach partial fulfillment");
        assertGt(counters.fullFulfillments, 0, "the campaign must reach full fulfillment");

        assertGt(counters.protectedSwapSuccesses, 0, "the campaign must execute ordinary protected swaps");
        assertGt(counters.oppositeSwapSuccesses, 0, "the campaign must execute opposite-direction swaps");
        assertGt(counters.swapBackingRejections, 0, "the campaign must refuse backing-destructive transitions");

        assertGt(counters.liquidityAddSuccesses, 0, "the campaign must exercise liquidity additions");
        assertGt(counters.liquidityRemoveSuccesses, 0, "the campaign must exercise liquidity removals");

        assertGt(counters.beneficiaryEligibilityMutations, 0, "the campaign must mutate Beneficiary eligibility");
        assertGt(counters.traderEligibilityMutations, 0, "the campaign must mutate trader eligibility");
        assertGt(counters.liquidityEligibilityMutations, 0, "the campaign must mutate liquidity eligibility");

        assertGt(counters.timeAdvances, 0, "the campaign must advance time");
        assertGt(counters.expiryEvents, 0, "the campaign must reach expiry");
        assertGt(counters.directBeneficiaryTransfers, 0, "the campaign must transfer protected output directly");
        assertGt(counters.orphanEvidenceAttempts, 0, "the campaign must probe orphan O2 evidence");

        _assertGlobalClosure();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Runs the production O1 transition for a commitment that is exercisable from admission.
    function _establishStandardCommitment(address _beneficiary, uint128 _entitlement)
        internal
        returns (uint256 commitmentId)
    {
        bool admitted;

        (admitted, commitmentId) = handler.scriptedEstablish(
            establishmentAuthority,
            _beneficiary,
            authorizedExerciser,
            _entitlement,
            uint64(block.timestamp),
            uint64(block.timestamp) + SEQUENCE_VALIDITY
        );

        assertTrue(admitted, "a backed, authorized, eligible admission must be accepted");
    }

    /// @dev Requests an ordinary exact-output swap in the protected direction, bounded by the domain.
    function _protectedExactOutputSwap(address _actor, uint256 _amountOut) internal returns (bool executed) {
        executed = handler.scriptedSwap(
            _actor, serviceConfig.protectedZeroForOne, int256(_amountOut), serviceConfig.tickQ, false
        );
    }

    /// @dev Requests an ordinary exact-input swap in the opposite direction, bounded by the domain.
    function _oppositeExactInputSwap(address _actor, uint256 _amountIn) internal returns (bool executed) {
        executed = handler.scriptedSwap(
            _actor, !serviceConfig.protectedZeroForOne, -int256(_amountIn), serviceConfig.tickO, false
        );
    }

    /// @dev The smallest protected output that must break backing from a given capacity.
    ///
    ///      Composed from the present headroom plus a margin, so the request is destructive under either
    ///      configuration's rounding rather than by a hard-coded amount.
    function _destructiveProtectedOutput(uint256 _capacity) internal view returns (uint256 amountOut) {
        amountOut = _capacity - hook.aggregateObligation() + _capacity / 100 + 2;
    }

    /// @dev Performs one generated action of the deterministic campaign.
    function _performGeneratedAction(uint256 _seed) internal {
        uint256 action = _seed % CAMPAIGN_ACTION_COUNT;

        if (action == 0) {
            handler.establishCommitment(_seed, uint128(_seed >> 32), uint64(_seed >> 96), uint64(_seed >> 160));
        } else if (action == 1) {
            handler.exercise(_seed, _seed >> 32, _seed >> 64);
        } else if (action == 2) {
            handler.ordinaryProtectedSwap(_seed, _seed >> 32);
        } else if (action == 3) {
            handler.ordinaryOppositeSwap(_seed, _seed >> 32);
        } else if (action == 4) {
            handler.addLiquidity(_seed, uint128(_seed >> 32));
        } else if (action == 5) {
            handler.removeLiquidity(_seed, uint128(_seed >> 32));
        } else if (action == 6) {
            handler.advanceTime(_seed);
        } else if (action == 7) {
            handler.setBeneficiaryEligibility(_seed);
        } else if (action == 8) {
            handler.setTraderEligibility(_seed);
        } else if (action == 9) {
            handler.setLiquidityEligibility(_seed);
        } else if (action == 10) {
            handler.directTransferProtectedTokenToBeneficiary(_seed, _seed >> 32);
        } else {
            handler.attemptOrphanExerciseEvidence(_seed);
        }
    }

    /// @dev Re-asserts the whole global invariant closure at the end of a scripted history.
    function _assertGlobalClosure() internal view {
        invariant_supportingCapacityEqualsIndependentReference();
        invariant_capacityObligationEqualsIndependentReference();
        invariant_supportingCapacityCoversCapacityObligation();
        invariant_commitmentConservation();
        invariant_beneficiaryHoldingsMatchIndependentDeliveryHistory();
        invariant_boundedReferenceIntegrity();
        invariant_bindingCommitmentsRetainALiveReference();
        invariant_protocolHoldsNoCurrencyCustody();
        invariant_noReusableCausalEvidenceSurvives();
    }

    /// @dev Reports what the deterministic campaign actually exercised.
    function _reportCampaign(StandbyInvariantHandler.ActionCounters memory _counters) internal pure {
        console2.log("--- GI deterministic campaign diagnostics ---");
        console2.log("O1 admitted / refused:", _counters.establishSuccesses, _counters.establishRejections);
        console2.log("O2 completed / refused:", _counters.exerciseSuccesses, _counters.exerciseRejections);
        console2.log("O2 partial / full:", _counters.partialFulfillments, _counters.fullFulfillments);
        console2.log(
            "protected swaps attempted / executed:", _counters.protectedSwapAttempts, _counters.protectedSwapSuccesses
        );
        console2.log(
            "opposite swaps attempted / executed:", _counters.oppositeSwapAttempts, _counters.oppositeSwapSuccesses
        );
        console2.log(
            "backing-refused swaps / liquidity:", _counters.swapBackingRejections, _counters.liquidityBackingRejections
        );
        console2.log("liquidity added / removed:", _counters.liquidityAddSuccesses, _counters.liquidityRemoveSuccesses);
        console2.log(
            "eligibility mutations B/T/L:",
            _counters.beneficiaryEligibilityMutations,
            _counters.traderEligibilityMutations,
            _counters.liquidityEligibilityMutations
        );
        console2.log("eligibility mutations refused:", _counters.eligibilityMutationRejections);
        console2.log("time advances / expiry events:", _counters.timeAdvances, _counters.expiryEvents);
        console2.log(
            "direct transfers / orphan probes:", _counters.directBeneficiaryTransfers, _counters.orphanEvidenceAttempts
        );
        console2.log("reference reuse events:", _counters.referenceReuseEvents);
        console2.log("max live references:", _counters.maxLiveReferences);
        console2.log("max observed obligation:", _counters.maxObservedObligation);
        console2.log("backing-boundary observations:", _counters.backingBoundaryObservations);
    }
}
