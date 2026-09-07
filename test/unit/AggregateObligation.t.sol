// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {StandbyHookHarness} from "../harness/StandbyHookHarness.sol";
import {BaseCommitmentStorageTest} from "../shared/BaseCommitmentStorageTest.t.sol";
import {ReferenceCalculations} from "../shared/ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Unit evidence for the F5 Aggregate Capacity Obligation derivation (G5-A).
/// @dev Aggregate obligation is the bounded sum of independently derived per-commitment obligations over
///      the enforcement-reference index. Three properties matter more than the arithmetic itself, and
///      each is proved here rather than assumed.
///
///      Reference membership is bookkeeping, not economics: a slot pointing at a terminal commitment
///      contributes exactly zero, and it does so without any transaction being sent to notice that the
///      commitment became terminal. Slot order carries no meaning: the same commitments arranged
///      differently produce the same sum. And the aggregate is derived rather than cached: time alone
///      changes it.
contract AggregateObligationTest is BaseCommitmentStorageTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint64 internal constant EXERCISABLE_FROM = 2_000;
    uint64 internal constant VALID_UNTIL = 3_000;

    uint64 internal constant NOW = 2_500;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Places the shared environment at a deterministic time inside the exercise window.
    function setUp() public virtual override {
        super.setUp();

        vm.warp(NOW);
    }

    /*//////////////////////////////////////////////////////////////
                          BOUNDED COMPOSITION
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves an empty enforcement-reference index derives zero obligation.
    function test_aggregateObligation_isZeroWhenEverySlotIsEmpty() public view {
        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(references[slot], 0, "the index must start empty");
        }

        assertEq(harness.aggregateObligation(), 0, "an empty index carries no obligation");
    }

    /// @notice Proves one binding commitment contributes exactly its Remaining Entitlement.
    function test_aggregateObligation_countsOneBindingCommitment() public {
        _reference(0, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));

        assertEq(harness.aggregateObligation(), 40_000, "the aggregate must equal the single remainder");
    }

    /// @notice Proves several binding commitments sum, and equal the independent reference.
    function test_aggregateObligation_sumsSeveralBindingCommitments() public {
        _reference(0, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));
        _reference(1, _record(15_000, EXERCISABLE_FROM, VALID_UNTIL));
        _reference(2, _record(1, EXERCISABLE_FROM, VALID_UNTIL));

        uint128[] memory remainders = new uint128[](3);
        uint64[] memory validUntils = new uint64[](3);

        (remainders[0], remainders[1], remainders[2]) = (40_000, 15_000, 1);
        (validUntils[0], validUntils[1], validUntils[2]) = (VALID_UNTIL, VALID_UNTIL, VALID_UNTIL);

        assertEq(harness.aggregateObligation(), 55_001, "the aggregate must be the sum");
        assertEq(
            harness.aggregateObligation(),
            ReferenceCalculations.referenceAggregateObligation(remainders, validUntils, block.timestamp),
            "the aggregate must equal the independent reference"
        );
    }

    /// @notice Proves a commitment whose exercise window has not opened still contributes in full.
    /// @dev Backing must already exist when the window opens. If a future commitment contributed nothing,
    ///      capacity could be consumed right up to the instant it became exercisable.
    function test_aggregateObligation_countsCommitmentsBeforeTheirExerciseWindow() public {
        _reference(0, _record(40_000, uint64(block.timestamp + 1_000), uint64(block.timestamp + 2_000)));

        assertEq(harness.aggregateObligation(), 40_000, "a future commitment contributes its full remainder");
    }

    /// @notice Proves a stale reference to an expired commitment contributes zero, with no transaction.
    /// @dev Nothing expires a commitment. Time passes and the derivation reports a different number,
    ///      because obligation was never stored in the first place.
    function test_aggregateObligation_dropsExpiredReferencesWithoutAnExpiryTransaction() public {
        _reference(0, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));

        assertEq(harness.aggregateObligation(), 40_000, "the commitment binds before expiry");

        vm.warp(VALID_UNTIL);

        assertEq(harness.aggregateObligation(), 0, "expiry alone removes the contribution");

        uint256[MAX_LIVE_COMMITMENTS] memory references = harness.enforcementReferences();

        assertEq(references[0], 1, "the stale reference is still present");
    }

    /// @notice Proves a stale reference to a fulfilled commitment contributes zero.
    function test_aggregateObligation_dropsExhaustedReferences() public {
        uint256 commitmentId = _record(40_000, EXERCISABLE_FROM, VALID_UNTIL);

        _reference(0, commitmentId);

        harness.writeRemainingEntitlement(commitmentId, 0);

        assertEq(harness.aggregateObligation(), 0, "an exhausted commitment contributes nothing");
        assertEq(harness.enforcementReferences()[0], commitmentId, "the reference itself is unchanged");
    }

    /// @notice Proves a mixed index counts exactly the binding commitments.
    function test_aggregateObligation_countsOnlyTheBindingCommitmentsInAMixedIndex() public {
        uint256 exhaustedId = _record(9_000, EXERCISABLE_FROM, VALID_UNTIL);

        _reference(0, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));
        _reference(1, _record(7_000, EXERCISABLE_FROM, uint64(block.timestamp)));
        _reference(2, exhaustedId);
        _reference(3, _record(2_500, uint64(block.timestamp + 500), uint64(block.timestamp + 5_000)));

        harness.writeRemainingEntitlement(exhaustedId, 0);

        assertEq(harness.aggregateObligation(), 42_500, "only the binding commitments contribute");
    }

    /// @notice Proves the derivation scales to a completely occupied bounded index.
    function test_aggregateObligation_derivesAcrossAFullyOccupiedIndex() public {
        uint256 expected;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            uint128 remainder = uint128(1_000 + slot);

            _reference(slot, _record(remainder, EXERCISABLE_FROM, VALID_UNTIL));

            expected += remainder;
        }

        assertEq(harness.aggregateObligation(), expected, "every occupied slot must contribute");
    }

    /*//////////////////////////////////////////////////////////////
                         ORDER INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves slot arrangement has no economic meaning.
    /// @dev Two independent Hooks hold the same three commitments in different slots. A derivation that
    ///      let position matter — by weighting, by short-circuiting, or by stopping at the first empty
    ///      slot — would disagree between them.
    function test_aggregateObligation_isIndependentOfSlotOrdering() public {
        StandbyHookHarness other = _deployIndependentHarness();

        _reference(0, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));
        _reference(1, _record(15_000, EXERCISABLE_FROM, VALID_UNTIL));
        _reference(2, _record(1, EXERCISABLE_FROM, VALID_UNTIL));

        _recordInto(other, 15_000, EXERCISABLE_FROM, VALID_UNTIL);
        _recordInto(other, 1, EXERCISABLE_FROM, VALID_UNTIL);
        _recordInto(other, 40_000, EXERCISABLE_FROM, VALID_UNTIL);

        other.writeEnforcementReference(15, 1);
        other.writeEnforcementReference(7, 2);
        other.writeEnforcementReference(4, 3);

        assertEq(other.aggregateObligation(), harness.aggregateObligation(), "slot arrangement must not change the sum");
    }

    /// @notice Proves an occupied high slot is counted even when lower slots are empty.
    /// @dev A scan that stopped at the first empty slot would report zero here.
    function test_aggregateObligation_countsAnOccupiedHighSlotWithEmptyLowSlots() public {
        _reference(MAX_LIVE_COMMITMENTS - 1, _record(40_000, EXERCISABLE_FROM, VALID_UNTIL));

        assertEq(harness.aggregateObligation(), 40_000, "the last slot must be scanned");
    }

    /*//////////////////////////////////////////////////////////////
                       DERIVED, NOT PERSISTED
    //////////////////////////////////////////////////////////////*/

    /// @notice Proves the aggregate tracks entitlement and time with no write of its own.
    /// @dev The only state change here is the authoritative Remaining Entitlement fact and the clock.
    ///      Nothing recomputes or refreshes an aggregate, because no aggregate is stored.
    function test_aggregateObligation_isDerivedRatherThanCached() public {
        uint256 commitmentId = _record(40_000, EXERCISABLE_FROM, VALID_UNTIL);

        _reference(0, commitmentId);

        assertEq(harness.aggregateObligation(), 40_000, "the initial aggregate");

        harness.writeRemainingEntitlement(commitmentId, 25_000);

        assertEq(harness.aggregateObligation(), 25_000, "a partial fulfillment is reflected immediately");

        vm.warp(VALID_UNTIL - 1);

        assertEq(harness.aggregateObligation(), 25_000, "the aggregate holds up to the expiry instant");

        vm.warp(VALID_UNTIL);

        assertEq(harness.aggregateObligation(), 0, "the aggregate releases exactly at expiry");
    }

    /// @notice Proves temporary Beneficiary ineligibility does not reduce the aggregate.
    /// @dev The registry is a real, separately administered authority here, and toggling it is a real
    ///      state change. It changes exercisability later; it never releases backing.
    function test_aggregateObligation_isUnaffectedByBeneficiaryEligibility() public {
        address beneficiary = makeAddr("beneficiary");

        _reference(
            0,
            harness.recordCommitment(
                StandbyHook.Commitment({
                    serviceId: PoolId.wrap(bytes32(uint256(1))),
                    beneficiary: beneficiary,
                    exercisableFrom: EXERCISABLE_FROM,
                    exerciseAuthority: makeAddr("exerciseAuthority"),
                    validUntil: VALID_UNTIL,
                    originalEntitlement: 40_000,
                    remainingEntitlement: 40_000
                })
            )
        );

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, true);

        assertEq(harness.aggregateObligation(), 40_000, "the eligible baseline");

        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(beneficiary, false);

        assertFalse(registry.canReceiveProtectedService(beneficiary), "the Beneficiary must actually be ineligible");
        assertEq(harness.aggregateObligation(), 40_000, "ineligibility must not release aggregate backing");
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Records a commitment with chosen economics into the shared harness.
    function _record(uint128 _remaining, uint64 _exercisableFrom, uint64 _validUntil)
        internal
        returns (uint256 commitmentId)
    {
        commitmentId = _recordInto(harness, _remaining, _exercisableFrom, _validUntil);
    }

    /// @dev Records a commitment with chosen economics into a specific harness.
    function _recordInto(StandbyHookHarness _target, uint128 _remaining, uint64 _exercisableFrom, uint64 _validUntil)
        internal
        returns (uint256 commitmentId)
    {
        commitmentId = _target.recordCommitment(
            StandbyHook.Commitment({
                serviceId: PoolId.wrap(bytes32(uint256(1))),
                beneficiary: makeAddr("beneficiary"),
                exercisableFrom: _exercisableFrom,
                exerciseAuthority: makeAddr("exerciseAuthority"),
                validUntil: _validUntil,
                originalEntitlement: _remaining,
                remainingEntitlement: _remaining
            })
        );
    }

    /// @dev Points one bounded slot at an existing commitment.
    function _reference(uint256 _slot, uint256 _commitmentId) internal {
        harness.writeEnforcementReference(_slot, _commitmentId);
    }

    /// @dev Deploys a second, independent commitment harness.
    ///
    ///      Its immutable trust basis deliberately differs from the shared harness's, which is what gives
    ///      it a different mined address. None of those addresses participates in obligation derivation,
    ///      so the two Hooks are economically identical for this comparison.
    function _deployIndependentHarness() internal returns (StandbyHookHarness deployed) {
        address otherConfigurationAuthority = makeAddr("otherConfigurationAuthority");
        address otherUniversalRouter = makeAddr("otherUniversalRouter");
        address otherPositionManager = makeAddr("otherPositionManager");

        bytes memory constructorArgs =
            abi.encode(poolManager, otherConfigurationAuthority, otherUniversalRouter, otherPositionManager);

        (, bytes32 salt) = HookMiner.find(
            address(this),
            hookDeployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(StandbyHookHarness).creationCode,
            constructorArgs
        );

        deployed = new StandbyHookHarness{salt: salt}(
            poolManager, otherConfigurationAuthority, otherUniversalRouter, otherPositionManager
        );
    }
}
