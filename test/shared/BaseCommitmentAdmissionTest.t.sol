// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseActorAwareStandbyTest} from "./BaseActorAwareStandbyTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F7 O1 commitment-admission evidence.
/// @dev Built on the F6A fixture without altering it: the same real pinned `PoolManager`, the same
///      canonical `StandbyHook` deployment, the same F1 currencies, the same F2 registry under its own
///      administrator, the same production activation, and the same canonical liquidity added through the
///      production `beforeAddLiquidity` path. Nothing is seeded here either — every commitment these
///      tests treat as authentic is created by the production `establishCommitment` transition, never by
///      the F4 storage harness.
///
///      What this layer adds is the Beneficiary domain O1 consumes and the snapshot machinery that makes
///      "a rejected admission changed nothing" a checkable claim rather than an assertion about one field.
///
///      Every role stays its own address. The Beneficiary is not the exercise authority, neither is the
///      establishment authority, and none of them is the configuration authority, a trader, a liquidity
///      provider, or the registry administrator — so an admission that succeeds cannot be succeeding
///      because two distinct authorities happen to be the same account.
///
///      Time is moved to a realistic point before any test runs. Foundry starts at timestamp 1, where
///      "an exercise window that has already opened" is not expressible at all, and that is one of the
///      admission boundaries F7 must get right.
abstract contract BaseCommitmentAdmissionTest is BaseActorAwareStandbyTest {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Everything a rejected O1 must leave exactly as it found it.
    /// @dev Deliberately spans all four surfaces a partial admission could show up on: commitment
    ///      identity, the bounded index, the derived obligation, authoritative PoolManager state, and
    ///      protected-output custody. Checking only the commitment store would miss a written reference;
    ///      checking only the reference index would miss a consumed identity.
    /// @param nextCommitmentId The identity the next successful admission would receive.
    /// @param aggregateObligation The re-derived Aggregate Capacity Obligation.
    /// @param supportingCapacity The re-derived Supporting Capacity.
    /// @param references The whole bounded enforcement-reference index.
    /// @param sqrtPriceX96 The authoritative pool square-root price.
    /// @param tick The authoritative pool tick.
    /// @param liquidity The authoritative active liquidity.
    /// @param beneficiaryOutput The Beneficiary's protected-output balance.
    /// @param hookOutput The Hook's protected-output balance.
    /// @param exerciseRouterOutput The designated ExerciseRouter's protected-output balance.
    struct AdmissionState {
        uint256 nextCommitmentId;
        uint256 aggregateObligation;
        uint256 supportingCapacity;
        uint256[MAX_LIVE_COMMITMENTS] references;
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        uint256 beneficiaryOutput;
        uint256 hookOutput;
        uint256 exerciseRouterOutput;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev A realistic starting time, so both "the window has already opened" and "the window has not
    ///      opened yet" are expressible against the same fixture.
    uint256 internal constant FIXTURE_TIMESTAMP = 1_800_000_000;

    /// @dev How far ahead of admission the default exercise window opens.
    uint64 internal constant DEFAULT_EXERCISE_DELAY = 1 hours;

    /// @dev How far ahead of admission the default validity window ends.
    uint64 internal constant DEFAULT_VALIDITY_DURATION = 30 days;

    address internal beneficiary;
    address internal secondBeneficiary;
    address internal ineligibleBeneficiary;
    address internal commitmentExerciseAuthority;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Adds the Beneficiary domain to the activated canonical service and moves time forward.
    function setUp() public virtual override {
        super.setUp();

        beneficiary = makeAddr("beneficiary");
        secondBeneficiary = makeAddr("secondBeneficiary");
        ineligibleBeneficiary = makeAddr("ineligibleBeneficiary");
        commitmentExerciseAuthority = makeAddr("commitmentExerciseAuthority");

        _setBeneficiaryEligibility(beneficiary, true);
        _setBeneficiaryEligibility(secondBeneficiary, true);

        vm.warp(FIXTURE_TIMESTAMP);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Grants or revokes Beneficiary eligibility through the registry's own administrator.
    function _setBeneficiaryEligibility(address _account, bool _eligible) internal {
        vm.prank(registryAdmin);
        registry.setBeneficiaryEligibility(_account, _eligible);
    }

    /// @dev Runs the production O1 transition with the canonical roles and the default window.
    function _establish(uint128 _originalEntitlement) internal returns (uint256 commitmentId) {
        (uint64 exercisableFrom, uint64 validUntil) = _defaultWindow();

        commitmentId = _establishWithWindow(_originalEntitlement, exercisableFrom, validUntil);
    }

    /// @dev Runs the production O1 transition with the canonical roles and an explicit window.
    function _establishWithWindow(uint128 _originalEntitlement, uint64 _exercisableFrom, uint64 _validUntil)
        internal
        returns (uint256 commitmentId)
    {
        commitmentId = _establishAs(
            establishmentAuthority,
            beneficiary,
            commitmentExerciseAuthority,
            _originalEntitlement,
            _exercisableFrom,
            _validUntil
        );
    }

    /// @dev Runs the production O1 transition with every term and the caller chosen explicitly.
    function _establishAs(
        address _caller,
        address _beneficiary,
        address _exerciseAuthority,
        uint128 _originalEntitlement,
        uint64 _exercisableFrom,
        uint64 _validUntil
    ) internal returns (uint256 commitmentId) {
        vm.prank(_caller);
        commitmentId = hook.establishCommitment(
            _beneficiary, _exerciseAuthority, _originalEntitlement, _exercisableFrom, _validUntil
        );
    }

    /// @dev The default admitted window: opens shortly after admission, ends well after that.
    function _defaultWindow() internal view returns (uint64 exercisableFrom, uint64 validUntil) {
        exercisableFrom = uint64(block.timestamp) + DEFAULT_EXERCISE_DELAY;
        validUntil = uint64(block.timestamp) + DEFAULT_VALIDITY_DURATION;
    }

    /// @dev Captures every fact a rejected admission must leave untouched.
    ///
    ///      The obligation and the capacity are re-derived rather than remembered from an earlier call, so
    ///      the comparison is between two authoritative derivations rather than between a derivation and a
    ///      cached number.
    function _admissionState() internal view returns (AdmissionState memory state) {
        (uint160 sqrtPriceX96, int24 tick, uint128 liquidity) = _servicePoolState();

        state = AdmissionState({
            nextCommitmentId: hook.nextCommitmentId(),
            aggregateObligation: hook.aggregateObligation(),
            supportingCapacity: hook.supportingCapacity(),
            references: hook.enforcementReferences(),
            sqrtPriceX96: sqrtPriceX96,
            tick: tick,
            liquidity: liquidity,
            beneficiaryOutput: usdc.balanceOf(beneficiary),
            hookOutput: usdc.balanceOf(address(hook)),
            exerciseRouterOutput: usdc.balanceOf(exerciseRouter)
        });
    }

    /// @dev Proves a rejected admission left no authoritative residue of any kind.
    function _assertNoAdmissionResidue(AdmissionState memory _before, string memory _context) internal view {
        AdmissionState memory current = _admissionState();

        assertEq(current.nextCommitmentId, _before.nextCommitmentId, _context);
        assertEq(current.aggregateObligation, _before.aggregateObligation, _context);
        assertEq(current.supportingCapacity, _before.supportingCapacity, _context);
        assertEq(current.sqrtPriceX96, _before.sqrtPriceX96, _context);
        assertEq(current.tick, _before.tick, _context);
        assertEq(current.liquidity, _before.liquidity, _context);
        assertEq(current.beneficiaryOutput, _before.beneficiaryOutput, _context);
        assertEq(current.hookOutput, _before.hookOutput, _context);
        assertEq(current.exerciseRouterOutput, _before.exerciseRouterOutput, _context);

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            assertEq(current.references[slot], _before.references[slot], _context);
        }
    }

    /// @dev Returns the slot currently referencing a commitment identity, and whether one does.
    function _referenceSlotOf(uint256 _commitmentId) internal view returns (bool found, uint256 slot) {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (references[i] == _commitmentId) return (true, i);
        }
    }

    /// @dev Counts the bounded index slots currently holding a reference.
    function _occupiedReferenceCount() internal view returns (uint256 occupied) {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        for (uint256 i = 0; i < MAX_LIVE_COMMITMENTS; ++i) {
            if (references[i] != 0) ++occupied;
        }
    }
}
