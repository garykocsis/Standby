// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {PoolId} from "v4-core/types/PoolId.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {MAX_LIVE_COMMITMENTS} from "../../src/libraries/CommitmentRefs.sol";

import {BaseCommitmentAdmissionTest} from "./BaseCommitmentAdmissionTest.t.sol";
import {ReferenceCalculations} from "./ReferenceCalculations.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared real-path fixture for F6B O3 enforcement evidence against an authentic positive
///         Aggregate Capacity Obligation.
/// @dev Built on the F7 admission fixture without altering it, which is the point: the only way an
///      obligation becomes positive here is the production `establishCommitment` transition the F7 layer
///      already exposes. Nothing writes an obligation, nothing writes a capacity, nothing plants a
///      commitment or a bounded reference, and no harness participates — every F6B claim is a claim about
///      whether a real Uniswap v4 pool transition became authoritative while a real commitment was live.
///
///      What this layer adds is the exact-output protected transition form the canonical A2/A3 sequence is
///      expressed in, the backing-specific rejection expectation, and the independent oracles that keep
///      F6B from verifying the production derivation against itself.
///
///      The oracles are deliberately asymmetric to what production does. Supporting Capacity is
///      recomputed by `ReferenceCalculations` from authoritative PoolManager state, and Aggregate Capacity
///      Obligation is recomputed by `ReferenceCalculations` from the persisted commitment *facts* —
///      Remaining Entitlement and validity end — read back through the fact-only commitment surface. No
///      oracle asks the Hook what it thinks a derived quantity is, and no oracle reads a production
///      classification.
///
///      Prospective Supporting Capacity has no second calculation here, by design. In this fixture its
///      independent expectation is an arithmetic identity of the frozen canonical geometry rather than a
///      reimplementation of the Uniswap swap loop: the canonical liquidity spans the whole service domain
///      as one constant-liquidity interval, so an exact-output protected swap of `out` protected-currency
///      units removes exactly `out` units from the capacity-bearing region, and a removal of `delta`
///      liquidity leaves the same price with `L - delta` active. Consumers of this fixture state that
///      expectation themselves, from frozen values, and never from the derivation under test.
abstract contract BaseAuthenticBackingTest is BaseCommitmentAdmissionTest {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Builds the canonical ordinary protected-direction exact-output swap, confined to the domain.
    ///
    ///      The price limit is the protected boundary, so a request larger than the domain can deliver
    ///      stops exactly on `tickQ` rather than leaving the configured realization domain. That keeps a
    ///      rejection attributable to backing instead of to a domain violation.
    function _protectedExactOutputSwapParams(uint256 _amountOut) internal pure returns (SwapParams memory params) {
        params = _swapParams(true, int256(_amountOut), StandbyFixtureConfig.TICK_Q);
    }

    /// @dev Builds a removal of part of the canonical liquidity position.
    ///
    ///      The range is the canonical LP range, so the position is active at every price the service
    ///      domain admits and the removal genuinely reduces Supporting Capacity. Only `canonicalProvider`
    ///      may execute it: the trusted perimeter scopes position custody by originating actor.
    function _canonicalRemovalParams(uint128 _removedLiquidity)
        internal
        pure
        returns (ModifyLiquidityParams memory params)
    {
        params = _liquidityParams(
            StandbyFixtureConfig.LP_TICK_LOWER, StandbyFixtureConfig.LP_TICK_UPPER, -int256(uint256(_removedLiquidity))
        );
    }

    /// @dev Expects the specific Standby insufficient-backing rejection, with both compared quantities.
    ///
    ///      Naming the pair is what makes the rejection attributable. A test that matched only the selector
    ///      would accept a refusal that compared the wrong capacity, the wrong obligation, or both.
    function _expectBackingRejection(bytes4 _callbackSelector, uint256 _prospectiveCapacity, uint256 _obligation)
        internal
    {
        _expectHookRejection(
            _callbackSelector,
            abi.encodeWithSelector(
                StandbyHook.StandbyHook__InsufficientProspectiveBacking.selector, _prospectiveCapacity, _obligation
            )
        );
    }

    /// @dev Independently derives current Supporting Capacity from authoritative PoolManager state.
    function _referenceSupportingCapacity() internal view returns (uint256 capacity) {
        (uint160 sqrtPriceX96,, uint128 liquidity) = _servicePoolState();

        capacity = ReferenceCalculations.referenceSupportingCapacity(
            StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE, sqrtPriceX96, StandbyFixtureConfig.TICK_Q, liquidity
        );
    }

    /// @dev Independently derives Aggregate Capacity Obligation from the persisted commitment facts.
    ///
    ///      Only facts cross the boundary: each referenced commitment's Remaining Entitlement and validity
    ///      end, read through the fact-only commitment surface. The oracle re-derives every classification
    ///      itself, so it disagrees with production whenever production's own derivation is wrong.
    function _referenceAggregateObligation() internal view returns (uint256 obligation) {
        uint256[MAX_LIVE_COMMITMENTS] memory references = hook.enforcementReferences();

        uint256 referenced = _occupiedReferenceCount();

        uint128[] memory remainingEntitlements = new uint128[](referenced);
        uint64[] memory validUntils = new uint64[](referenced);

        uint256 next;

        for (uint256 slot = 0; slot < MAX_LIVE_COMMITMENTS; ++slot) {
            if (references[slot] == 0) continue;

            StandbyHook.Commitment memory record = hook.commitment(references[slot]);

            remainingEntitlements[next] = record.remainingEntitlement;
            validUntils[next] = record.validUntil;

            ++next;
        }

        obligation =
            ReferenceCalculations.referenceAggregateObligation(remainingEntitlements, validUntils, block.timestamp);
    }

    /// @dev Proves both production economic derivations still equal their independent reconstructions.
    function _assertDerivationsMatchOracles(string memory _context) internal view {
        assertEq(hook.supportingCapacity(), _referenceSupportingCapacity(), _context);
        assertEq(hook.aggregateObligation(), _referenceAggregateObligation(), _context);
    }

    /// @dev Proves a commitment's complete authoritative fact record is byte-for-byte what it was.
    ///
    ///      Remaining Entitlement is the only mutable fact, and no F6B transition may move it — but the
    ///      other six are checked too, because "the ordinary transition changed nothing about the
    ///      commitment" is the claim, not "it changed nothing about one field".
    function _assertCommitmentFactsUnchanged(
        uint256 _commitmentId,
        StandbyHook.Commitment memory _before,
        string memory _context
    ) internal view {
        StandbyHook.Commitment memory current = hook.commitment(_commitmentId);

        assertEq(PoolId.unwrap(current.serviceId), PoolId.unwrap(_before.serviceId), _context);
        assertEq(current.beneficiary, _before.beneficiary, _context);
        assertEq(current.exerciseAuthority, _before.exerciseAuthority, _context);
        assertEq(uint256(current.exercisableFrom), uint256(_before.exercisableFrom), _context);
        assertEq(uint256(current.validUntil), uint256(_before.validUntil), _context);
        assertEq(uint256(current.originalEntitlement), uint256(_before.originalEntitlement), _context);
        assertEq(uint256(current.remainingEntitlement), uint256(_before.remainingEntitlement), _context);
    }

    /// @dev Proves a rejected transition returned the actor's own currency balances untouched.
    ///
    ///      Pool state surviving a revert is necessary but not sufficient evidence of atomicity: a
    ///      transition that had already moved value between the actor and the pool would show up here and
    ///      nowhere else.
    function _assertActorBalancesUnchanged(address _actor, uint256 _ustbBefore, uint256 _usdcBefore) internal view {
        assertEq(ustb.balanceOf(_actor), _ustbBefore, "a rejected transition must not move the actor's currency0");
        assertEq(usdc.balanceOf(_actor), _usdcBefore, "a rejected transition must not move the actor's currency1");
    }
}
