// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title EligibilityRegistryFuzzTest
/// @notice Parameterized evidence that predicate independence, account scoping, authorization, and
///         latest-write fidelity hold across arbitrary accounts, callers, and eligibility combinations.
/// @dev Accounts and callers are unconstrained except where a semantic domain requires it: an
///      unauthorized-caller test must exclude the administrator, and an account-scoping test must use
///      two distinct accounts. Everything is exercised through the ordinary production entry points.
contract EligibilityRegistryFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    EligibilityRegistry internal registry;

    address internal admin = makeAddr("registryAdmin");

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        registry = new EligibilityRegistry(admin);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /// @dev Any account is ineligible under every predicate until an authorized write says otherwise.
    function testFuzz_anyAccount_defaultsToIneligibleUnderEveryPredicate(address account) public view {
        _assertEligibility(account, false, false, false);
    }

    /// @dev Any combination of the three predicates is representable for any account, and each read
    ///      returns exactly its own domain's written value.
    function testFuzz_anyEligibilityCombination_isReflectedExactly(
        address account,
        bool beneficiary,
        bool trader,
        bool liquidity
    ) public {
        _write(account, beneficiary, trader, liquidity);

        _assertEligibility(account, beneficiary, trader, liquidity);
    }

    /// @dev Updating exactly one domain from an arbitrary baseline leaves the other two domains at their
    ///      baseline values.
    function testFuzz_singleDomainUpdate_leavesTheOtherDomainsUnchanged(
        address account,
        bool beneficiary,
        bool trader,
        bool liquidity,
        uint8 domainSeed,
        bool updated
    ) public {
        _write(account, beneficiary, trader, liquidity);

        uint8 domain = domainSeed % 3;

        vm.startPrank(admin);
        if (domain == 0) {
            registry.setBeneficiaryEligibility(account, updated);
            _assertEligibility(account, updated, trader, liquidity);
        } else if (domain == 1) {
            registry.setTraderEligibility(account, updated);
            _assertEligibility(account, beneficiary, updated, liquidity);
        } else {
            registry.setLiquidityEligibility(account, updated);
            _assertEligibility(account, beneficiary, trader, updated);
        }
        vm.stopPrank();
    }

    /// @dev The latest authorized write is authoritative in every domain, regardless of the previous
    ///      value or of a repeated identical write.
    function testFuzz_latestAuthorizedWrite_isAuthoritative(address account, bool first, bool second) public {
        _write(account, first, first, first);
        _write(account, second, second, second);

        _assertEligibility(account, second, second, second);
    }

    /// @dev Eligibility is scoped per account: writing one account never changes another.
    function testFuzz_writes_areScopedToTheNamedAccount(
        address account,
        address otherAccount,
        bool beneficiary,
        bool trader,
        bool liquidity
    ) public {
        vm.assume(account != otherAccount);

        _write(account, beneficiary, trader, liquidity);

        _assertEligibility(account, beneficiary, trader, liquidity);
        _assertEligibility(otherAccount, false, false, false);
    }

    /// @dev No caller other than the administrator can write any domain, and a rejected write leaves the
    ///      previously established eligibility of every domain unchanged.
    function testFuzz_unauthorizedCaller_cannotWriteAnyDomain(
        address caller,
        address account,
        bool beneficiary,
        bool trader,
        bool liquidity,
        bool attempted
    ) public {
        vm.assume(caller != admin);

        _write(account, beneficiary, trader, liquidity);

        vm.startPrank(caller);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, caller));
        registry.setBeneficiaryEligibility(account, attempted);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, caller));
        registry.setTraderEligibility(account, attempted);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, caller));
        registry.setLiquidityEligibility(account, attempted);

        vm.stopPrank();

        _assertEligibility(account, beneficiary, trader, liquidity);
    }

    /// @dev Any non-zero account can administer its own registry, and that authority does not extend to
    ///      a registry administered by someone else.
    function testFuzz_administratorAuthority_isScopedToItsOwnRegistry(address otherAdmin, address account) public {
        vm.assume(otherAdmin != address(0));
        vm.assume(otherAdmin != admin);

        EligibilityRegistry otherRegistry = new EligibilityRegistry(otherAdmin);

        vm.prank(otherAdmin);
        otherRegistry.setBeneficiaryEligibility(account, true);
        assertTrue(otherRegistry.canReceiveProtectedService(account));

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, admin));
        otherRegistry.setTraderEligibility(account, true);

        assertFalse(otherRegistry.canSwap(account));
        assertFalse(registry.canReceiveProtectedService(account));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Establishes all three predicates for `_account` through the authorized administrator path.
    function _write(address _account, bool _beneficiary, bool _trader, bool _liquidity) internal {
        vm.startPrank(admin);
        registry.setBeneficiaryEligibility(_account, _beneficiary);
        registry.setTraderEligibility(_account, _trader);
        registry.setLiquidityEligibility(_account, _liquidity);
        vm.stopPrank();
    }

    /// @dev Reads all three predicates for `_account` and asserts each one independently.
    function _assertEligibility(address _account, bool _beneficiary, bool _trader, bool _liquidity) internal view {
        assertEq(registry.canReceiveProtectedService(_account), _beneficiary, "beneficiary eligibility");
        assertEq(registry.canSwap(_account), _trader, "trader eligibility");
        assertEq(registry.canProvideLiquidity(_account), _liquidity, "liquidity eligibility");
    }
}
