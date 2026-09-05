// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {MockFixtureCurrency} from "./MockFixtureCurrency.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title MockUSDC
/// @notice The deterministic fixture currency representing the settlement asset.
/// @dev Demo/fixture instrumentation only. It implies no integration with, endorsement by, or
///      compatibility with any stablecoin issuer, and carries no Standby economic semantics. Its
///      position as `currency1` and its role as the canonical protected output currency are properties
///      of the fixture, established by deterministic deployment, not properties of this contract.
contract MockUSDC is MockFixtureCurrency {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string internal constant NAME = "Mock USD Coin";
    string internal constant SYMBOL = "MockUSDC";

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @inheritdoc MockFixtureCurrency
    function name() external pure override returns (string memory name_) {
        name_ = NAME;
    }

    /// @inheritdoc MockFixtureCurrency
    function symbol() external pure override returns (string memory symbol_) {
        symbol_ = SYMBOL;
    }
}
