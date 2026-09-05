// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {MockFixtureCurrency} from "./MockFixtureCurrency.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title MockUSTB
/// @notice The deterministic fixture currency representing a tokenized short-duration Treasury asset.
/// @dev Demo/fixture instrumentation only. It implies no integration with, endorsement by, or
///      compatibility with any tokenized-Treasury issuer, and carries no Standby economic semantics.
///      Its position as `currency0` and its role in the canonical protected direction are properties of
///      the fixture, established by deterministic deployment, not properties of this contract.
contract MockUSTB is MockFixtureCurrency {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    string internal constant NAME = "Mock US Treasury Bill";
    string internal constant SYMBOL = "MockUSTB";

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
