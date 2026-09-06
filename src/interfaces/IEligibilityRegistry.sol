// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

/// @title IEligibilityRegistry
/// @notice The read surface through which Standby consumes authoritative participant eligibility.
/// @dev This interface deliberately exposes only the three eligibility predicates. Registry membership
///      administration is the registry's own responsibility: a Standby consumer reads eligibility, it
///      does not administer it, so no mutation function belongs on the consumed surface.
///
///      The three predicates are logically distinct permission domains. A deployment may grant several
///      of them to one account without merging their meanings, and the registry answers each one
///      independently. The registry answers only "is this account eligible under this predicate"; what
///      Standby does with an answer is owned by the consuming component, not by the registry.
interface IEligibilityRegistry {
    /// @notice Returns whether an account may be the Beneficiary of a Protected Execution Service.
    /// @param account The account whose Beneficiary eligibility is queried.
    /// @return eligible True when the account is currently eligible to receive protected service.
    function canReceiveProtectedService(address account) external view returns (bool eligible);

    /// @notice Returns whether an account may perform ordinary permissioned swaps.
    /// @param account The account whose trader eligibility is queried.
    /// @return eligible True when the account is currently eligible to swap.
    function canSwap(address account) external view returns (bool eligible);

    /// @notice Returns whether an account may perform permissioned liquidity actions.
    /// @param account The account whose liquidity-action eligibility is queried.
    /// @return eligible True when the account is currently eligible to provide liquidity.
    function canProvideLiquidity(address account) external view returns (bool eligible);
}
