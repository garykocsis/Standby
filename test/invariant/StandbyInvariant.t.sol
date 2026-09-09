// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {DeterministicFixtureDeployer} from "../../script/helpers/DeterministicFixtureDeployer.sol";
import {StandbyFixtureConfig} from "../../script/helpers/StandbyFixtureConfig.sol";

import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

import {DerivationTestCurrency} from "../shared/BaseDerivationTest.t.sol";
import {StandbySequenceEvidence} from "./StandbySequenceEvidence.t.sol";
import {IInvariantCurrency} from "./StandbyInvariantHandler.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice The canonical GI stateful invariant campaign. (G-I-1 … G-I-21, G-I-22 canonical half)
/// @dev The frozen canonical identity and direction: `MockUSTB` as currency0, `MockUSDC` as currency1,
///      both six-decimal, protected direction `zeroForOne`, the canonical domain, the canonical position,
///      and the canonical liquidity — reached through the real deterministic ordered deployment rather
///      than assumed.
///
///      The campaign runs with `fail_on_revert = true`. That is not strictness for its own sake: the
///      handler wraps every production call and records the refusals itself, so the only way a generated
///      call can revert is a failed assertion or an unmodelled failure, and both must fail the campaign
///      rather than being silently discarded as an uninteresting sequence.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 96
/// forge-config: default.invariant.fail_on_revert = true
/// forge-config: ci.invariant.runs = 512
/// forge-config: ci.invariant.depth = 192
/// forge-config: ci.invariant.fail_on_revert = true
contract StandbyCanonicalInvariantTest is StandbySequenceEvidence {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen canonical deterministic fixture geometry.
    function _serviceConfig() internal pure override returns (InvariantServiceConfig memory config) {
        config = InvariantServiceConfig({
            decimals0: StandbyFixtureConfig.CURRENCY_DECIMALS,
            decimals1: StandbyFixtureConfig.CURRENCY_DECIMALS,
            protectedZeroForOne: StandbyFixtureConfig.PROTECTED_DIRECTION_ZERO_FOR_ONE,
            initialTick: StandbyFixtureConfig.INITIAL_TICK,
            tickQ: StandbyFixtureConfig.TICK_Q,
            tickO: StandbyFixtureConfig.TICK_O,
            lpTickLower: StandbyFixtureConfig.LP_TICK_LOWER,
            lpTickUpper: StandbyFixtureConfig.LP_TICK_UPPER,
            tickSpacing: StandbyFixtureConfig.TICK_SPACING,
            lpFee: StandbyFixtureConfig.LP_FEE,
            liquidity: StandbyFixtureConfig.CANONICAL_LIQUIDITY
        });
    }

    /// @dev Deploys the canonical fixture currencies through the deterministic ordered deployment path.
    function _deployCurrencies()
        internal
        override
        returns (IInvariantCurrency deployed0, IInvariantCurrency deployed1)
    {
        (MockUSTB ustb, MockUSDC usdc,) = new DeterministicFixtureDeployer().deployOrderedFixtureCurrencies();

        (deployed0, deployed1) = (IInvariantCurrency(address(ustb)), IInvariantCurrency(address(usdc)));
    }
}

/// @notice The generalized GI stateful invariant campaign. (G-I-22 generalized half)
/// @dev A supported configuration that shares nothing with the canonical one that could hide a
///      canonical-only assumption: the protected direction is `oneForZero`, so the protected output is
///      currency0 rather than currency1; the currencies are eighteen- and eight-decimal rather than both
///      six, so neither `1e6` nor equal precision is a usable universal scale; and the tick layout,
///      spacing, fee, and liquidity are all different.
///
///      Supporting Capacity and Capacity Obligation stay raw amounts of whichever currency the protected
///      direction makes the output, and the same invariant closure is asserted over them.
/// forge-config: default.invariant.runs = 256
/// forge-config: default.invariant.depth = 96
/// forge-config: default.invariant.fail_on_revert = true
/// forge-config: ci.invariant.runs = 512
/// forge-config: ci.invariant.depth = 192
/// forge-config: ci.invariant.fail_on_revert = true
contract StandbyGeneralizedInvariantTest is StandbySequenceEvidence {
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev A protected `oneForZero` service with asymmetric decimal precision.
    function _serviceConfig() internal pure override returns (InvariantServiceConfig memory config) {
        config = InvariantServiceConfig({
            decimals0: 18,
            decimals1: 8,
            protectedZeroForOne: false,
            initialTick: 0,
            tickQ: 1_200,
            tickO: -600,
            lpTickLower: -1_200,
            lpTickUpper: 1_800,
            tickSpacing: 60,
            lpFee: 3_000,
            liquidity: 1_000_000_000_000_000
        });
    }

    /// @dev Deploys two currencies with the configured precisions, already in the required address order.
    ///
    ///      The ordering is obtained by redeploying the pair rather than by relabelling one as the other,
    ///      because relabelling would silently swap the precisions this campaign intends.
    function _deployCurrencies()
        internal
        override
        returns (IInvariantCurrency deployed0, IInvariantCurrency deployed1)
    {
        for (uint256 attempt = 0; attempt < MAX_CURRENCY_ORDERING_ATTEMPTS; ++attempt) {
            DerivationTestCurrency candidate0 = new DerivationTestCurrency(serviceConfig.decimals0);
            DerivationTestCurrency candidate1 = new DerivationTestCurrency(serviceConfig.decimals1);

            if (address(candidate0) < address(candidate1)) {
                return (IInvariantCurrency(address(candidate0)), IInvariantCurrency(address(candidate1)));
            }
        }

        assertTrue(false, "ordered currency deployment failed");
    }
}
