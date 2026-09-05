// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title MockFixtureCurrency
/// @notice The minimal six-decimal ERC-20 shared by the deterministic Standby fixture currencies.
/// @dev Fixture instrumentation only. This contract carries no Standby economic semantics: it knows
///      nothing about Supporting Capacity, Capacity Obligation, commitments, eligibility, protected
///      direction, or currency ordering. It performs no fee-on-transfer and no rebasing, so a
///      transferred amount is always the received amount.
///
///      `mint` is deliberately unpermissioned so fixture construction can fund actors deterministically.
///      These currencies are never intended for any environment where that matters.
abstract contract MockFixtureCurrency {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The frozen decimal precision of every canonical Standby fixture currency.
    uint8 internal constant DECIMALS = 6;

    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 amount)) public allowance;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when an account transfers more than it holds.
    /// @param from The account the transfer debits.
    /// @param balance The balance actually held.
    /// @param amount The amount the transfer attempted to debit.
    error MockFixtureCurrency__InsufficientBalance(address from, uint256 balance, uint256 amount);

    /// @notice Thrown when a spender transfers more than it is approved for.
    /// @param owner The account whose tokens are spent.
    /// @param spender The spender.
    /// @param approved The remaining approved amount.
    /// @param amount The amount the transfer attempted to spend.
    error MockFixtureCurrency__InsufficientAllowance(address owner, address spender, uint256 approved, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Returns the human-readable currency name.
    /// @return name_ The currency name.
    function name() external pure virtual returns (string memory name_);

    /// @notice Returns the currency symbol.
    /// @return symbol_ The currency symbol.
    function symbol() external pure virtual returns (string memory symbol_);

    /// @notice Returns the decimal precision of the currency.
    /// @return decimals_ The decimal precision, always six for Standby fixture currencies.
    function decimals() external pure returns (uint8 decimals_) {
        decimals_ = DECIMALS;
    }

    /// @notice Mints fixture currency to an account.
    /// @dev Unpermissioned fixture funding. Not a production issuance model.
    /// @param to The account receiving the minted currency.
    /// @param amount The raw amount minted.
    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    /// @notice Approves a spender to transfer currency on behalf of the caller.
    /// @param spender The approved spender.
    /// @param amount The approved raw amount.
    /// @return success Always true; failure reverts.
    function approve(address spender, uint256 amount) external returns (bool success) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        success = true;
    }

    /// @notice Transfers currency from the caller to another account.
    /// @param to The recipient.
    /// @param amount The raw amount transferred.
    /// @return success Always true; failure reverts.
    function transfer(address to, uint256 amount) external returns (bool success) {
        _transfer(msg.sender, to, amount);

        success = true;
    }

    /// @notice Transfers currency between accounts using an allowance.
    /// @param from The account the transfer debits.
    /// @param to The recipient.
    /// @param amount The raw amount transferred.
    /// @return success Always true; failure reverts.
    function transferFrom(address from, address to, uint256 amount) external returns (bool success) {
        uint256 approved = allowance[from][msg.sender];

        if (approved != type(uint256).max) {
            if (approved < amount) {
                revert MockFixtureCurrency__InsufficientAllowance(from, msg.sender, approved, amount);
            }

            allowance[from][msg.sender] = approved - amount;
        }

        _transfer(from, to, amount);

        success = true;
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Moves `amount` from `from` to `to` with no fee and no supply change.
    function _transfer(address from, address to, uint256 amount) internal {
        uint256 balance = balanceOf[from];

        if (balance < amount) revert MockFixtureCurrency__InsufficientBalance(from, balance, amount);

        unchecked {
            balanceOf[from] = balance - amount;
        }

        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }
}
