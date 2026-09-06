// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IEligibilityRegistry} from "./interfaces/IEligibilityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title EligibilityRegistry
/// @notice The dedicated external authority over mutable Standby participant eligibility.
/// @dev The registry owns three logically distinct permission domains — Beneficiary eligibility,
///      trader eligibility, and liquidity-action eligibility — and nothing else. Each predicate has its
///      own authoritative storage and its own mutation entry point, so one domain can never be changed
///      as a side effect of changing another, even when one administrator grants all three to one
///      account.
///
///      The registry knows nothing about pools, PoolManager state, Supporting Capacity, Aggregate
///      Capacity Obligation, commitments, Remaining Entitlement, validity, exercisability, exercise
///      authority, service domains, currencies, or lifecycle time. It answers a membership question;
///      the economic consequence of an answer belongs to the component that asks it.
///
///      Administration is a single immutable administrator, which is sufficient for the reference
///      realization. Registry administration authority is its own permission domain and is deliberately
///      not shared with Standby configuration authority, commitment-establishment authority, or
///      exercise authority.
///
///      Every predicate fails closed: an account is ineligible under every domain until an authorized
///      write makes it eligible.
contract EligibilityRegistry is IEligibilityRegistry {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The account authorized to administer registry membership.
    address public immutable i_admin;

    /// @dev Authoritative Beneficiary eligibility. Separate storage from the other two domains.
    mapping(address account => bool eligible) private _beneficiaryEligibility;

    /// @dev Authoritative trader eligibility. Separate storage from the other two domains.
    mapping(address account => bool eligible) private _traderEligibility;

    /// @dev Authoritative liquidity-action eligibility. Separate storage from the other two domains.
    mapping(address account => bool eligible) private _liquidityEligibility;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when Beneficiary eligibility is written for an account.
    event BeneficiaryEligibilitySet(address indexed account, bool eligible);

    /// @notice Emitted when trader eligibility is written for an account.
    event TraderEligibilitySet(address indexed account, bool eligible);

    /// @notice Emitted when liquidity-action eligibility is written for an account.
    event LiquidityEligibilitySet(address indexed account, bool eligible);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the registry is constructed without an administrator.
    error EligibilityRegistry__InvalidAdmin();

    /// @notice Thrown when an account other than the registry administrator attempts a membership write.
    /// @param caller The unauthorized caller.
    error EligibilityRegistry__NotAdmin(address caller);

    /*//////////////////////////////////////////////////////////////
                              MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Restricts a membership write to the registry administrator.
    modifier onlyAdmin() {
        if (msg.sender != i_admin) revert EligibilityRegistry__NotAdmin(msg.sender);
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the registry to its immutable administrator.
    /// @dev A zero administrator is rejected: it would permanently freeze every predicate at its
    ///      fail-closed default with no authorized path to membership.
    /// @param _admin The account authorized to administer registry membership.
    constructor(address _admin) {
        if (_admin == address(0)) revert EligibilityRegistry__InvalidAdmin();

        i_admin = _admin;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Sets whether an account is eligible to be the Beneficiary of a Protected Execution Service.
    /// @dev Writes the Beneficiary domain only. Trader and liquidity-action eligibility are untouched.
    /// @param account The account whose Beneficiary eligibility is written.
    /// @param eligible The authoritative Beneficiary eligibility after this write.
    function setBeneficiaryEligibility(address account, bool eligible) external onlyAdmin {
        _beneficiaryEligibility[account] = eligible;

        emit BeneficiaryEligibilitySet(account, eligible);
    }

    /// @notice Sets whether an account is eligible to perform ordinary permissioned swaps.
    /// @dev Writes the trader domain only. Beneficiary and liquidity-action eligibility are untouched.
    /// @param account The account whose trader eligibility is written.
    /// @param eligible The authoritative trader eligibility after this write.
    function setTraderEligibility(address account, bool eligible) external onlyAdmin {
        _traderEligibility[account] = eligible;

        emit TraderEligibilitySet(account, eligible);
    }

    /// @notice Sets whether an account is eligible to perform permissioned liquidity actions.
    /// @dev Writes the liquidity-action domain only. Beneficiary and trader eligibility are untouched.
    /// @param account The account whose liquidity-action eligibility is written.
    /// @param eligible The authoritative liquidity-action eligibility after this write.
    function setLiquidityEligibility(address account, bool eligible) external onlyAdmin {
        _liquidityEligibility[account] = eligible;

        emit LiquidityEligibilitySet(account, eligible);
    }

    /// @inheritdoc IEligibilityRegistry
    function canReceiveProtectedService(address account) external view returns (bool eligible) {
        eligible = _beneficiaryEligibility[account];
    }

    /// @inheritdoc IEligibilityRegistry
    function canSwap(address account) external view returns (bool eligible) {
        eligible = _traderEligibility[account];
    }

    /// @inheritdoc IEligibilityRegistry
    function canProvideLiquidity(address account) external view returns (bool eligible) {
        eligible = _liquidityEligibility[account];
    }
}
