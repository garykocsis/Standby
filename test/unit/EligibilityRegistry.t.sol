// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {Test} from "forge-std/Test.sol";

import {EligibilityRegistry} from "../../src/EligibilityRegistry.sol";
import {IEligibilityRegistry} from "../../src/interfaces/IEligibilityRegistry.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title EligibilityRegistryTest
/// @notice Unit evidence that the Standby eligibility authority keeps three independent predicates,
///         admits and revokes each one, and admits membership writes only from its administrator.
/// @dev The registry is deployed through its ordinary constructor and every eligibility fact is
///      established through the ordinary administrator path. No harness, no privileged seeding, and no
///      Standby economic state participates: F2 proves the registry answers a membership question, not
///      what Standby later does with the answer.
contract EligibilityRegistryTest is Test {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    EligibilityRegistry internal registry;

    address internal admin = makeAddr("registryAdmin");
    address internal intruder = makeAddr("intruder");
    address internal account = makeAddr("account");
    address internal otherAccount = makeAddr("otherAccount");

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event BeneficiaryEligibilitySet(address indexed account, bool eligible);
    event TraderEligibilitySet(address indexed account, bool eligible);
    event LiquidityEligibilitySet(address indexed account, bool eligible);

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        registry = new EligibilityRegistry(admin);
    }

    /*//////////////////////////////////////////////////////////////
                          DEFAULT DENIAL
    //////////////////////////////////////////////////////////////*/

    /// @dev Every predicate fails closed for every account before any authorized write.
    function test_allPredicates_defaultToIneligible() public view {
        address[5] memory accounts = [account, otherAccount, admin, intruder, address(registry)];

        for (uint256 i = 0; i < accounts.length; ++i) {
            _assertEligibility(accounts[i], false, false, false);
        }

        _assertEligibility(address(0), false, false, false);
    }

    /*//////////////////////////////////////////////////////////////
                     G2-C — READ FIDELITY
    //////////////////////////////////////////////////////////////*/

    /// @dev Beneficiary eligibility transitions false -> true -> false and each read returns the
    ///      authoritative fact. Revocation is required evidence, not only admission.
    function test_beneficiaryEligibility_isAdmittedAndRevokedByTheAdmin() public {
        assertFalse(registry.canReceiveProtectedService(account));

        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, true);
        assertTrue(registry.canReceiveProtectedService(account));

        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, false);
        assertFalse(registry.canReceiveProtectedService(account));
    }

    /// @dev Trader eligibility transitions false -> true -> false.
    function test_traderEligibility_isAdmittedAndRevokedByTheAdmin() public {
        assertFalse(registry.canSwap(account));

        vm.prank(admin);
        registry.setTraderEligibility(account, true);
        assertTrue(registry.canSwap(account));

        vm.prank(admin);
        registry.setTraderEligibility(account, false);
        assertFalse(registry.canSwap(account));
    }

    /// @dev Liquidity-action eligibility transitions false -> true -> false.
    function test_liquidityEligibility_isAdmittedAndRevokedByTheAdmin() public {
        assertFalse(registry.canProvideLiquidity(account));

        vm.prank(admin);
        registry.setLiquidityEligibility(account, true);
        assertTrue(registry.canProvideLiquidity(account));

        vm.prank(admin);
        registry.setLiquidityEligibility(account, false);
        assertFalse(registry.canProvideLiquidity(account));
    }

    /// @dev The latest authorized write is the authoritative fact, including a repeated identical write
    ///      and an immediate reversal.
    function test_repeatedWrites_reflectTheLatestAuthorizedWrite() public {
        vm.startPrank(admin);

        registry.setTraderEligibility(account, true);
        registry.setTraderEligibility(account, true);
        assertTrue(registry.canSwap(account));

        registry.setTraderEligibility(account, false);
        registry.setTraderEligibility(account, true);
        registry.setTraderEligibility(account, false);
        assertFalse(registry.canSwap(account));

        vm.stopPrank();
    }

    /// @dev A membership write is scoped to the named account and does not travel to another account.
    function test_eligibilityWrites_areScopedToTheNamedAccount() public {
        vm.startPrank(admin);
        registry.setBeneficiaryEligibility(account, true);
        registry.setTraderEligibility(account, true);
        registry.setLiquidityEligibility(account, true);
        vm.stopPrank();

        _assertEligibility(account, true, true, true);
        _assertEligibility(otherAccount, false, false, false);
    }

    /*//////////////////////////////////////////////////////////////
                  G2-A — PREDICATE INDEPENDENCE
    //////////////////////////////////////////////////////////////*/

    /// @dev One account holds Beneficiary eligibility while remaining ineligible to swap and to provide
    ///      liquidity. A single shared eligibility flag could not produce this state.
    function test_oneAccount_holdsBeneficiaryEligibilityAlone() public {
        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, true);

        _assertEligibility(account, true, false, false);
    }

    /// @dev One account holds trader eligibility alone.
    function test_oneAccount_holdsTraderEligibilityAlone() public {
        vm.prank(admin);
        registry.setTraderEligibility(account, true);

        _assertEligibility(account, false, true, false);
    }

    /// @dev One account holds liquidity-action eligibility alone.
    function test_oneAccount_holdsLiquidityEligibilityAlone() public {
        vm.prank(admin);
        registry.setLiquidityEligibility(account, true);

        _assertEligibility(account, false, false, true);
    }

    /// @dev The same account can hold every one of the eight combinations of the three predicates, and
    ///      each combination is reached from the previous one by authorized writes only.
    function test_oneAccount_holdsEveryCombinationOfTheThreePredicates() public {
        for (uint256 combination = 0; combination < 8; ++combination) {
            bool beneficiary = (combination & 1) != 0;
            bool trader = (combination & 2) != 0;
            bool liquidity = (combination & 4) != 0;

            vm.startPrank(admin);
            registry.setBeneficiaryEligibility(account, beneficiary);
            registry.setTraderEligibility(account, trader);
            registry.setLiquidityEligibility(account, liquidity);
            vm.stopPrank();

            _assertEligibility(account, beneficiary, trader, liquidity);
        }
    }

    /*//////////////////////////////////////////////////////////////
                 G2-D — CROSS-DOMAIN ISOLATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Granting and then revoking Beneficiary eligibility leaves trader and liquidity-action
    ///      eligibility exactly as they were, from both an all-ineligible and an all-eligible baseline.
    function test_beneficiaryUpdates_leaveTraderAndLiquidityEligibilityUnchanged() public {
        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, true);
        _assertEligibility(account, true, false, false);

        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, false);
        _assertEligibility(account, false, false, false);

        _grantAllEligibility(account);

        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, false);
        _assertEligibility(account, false, true, true);

        vm.prank(admin);
        registry.setBeneficiaryEligibility(account, true);
        _assertEligibility(account, true, true, true);
    }

    /// @dev Trader updates leave Beneficiary and liquidity-action eligibility unchanged.
    function test_traderUpdates_leaveBeneficiaryAndLiquidityEligibilityUnchanged() public {
        vm.prank(admin);
        registry.setTraderEligibility(account, true);
        _assertEligibility(account, false, true, false);

        vm.prank(admin);
        registry.setTraderEligibility(account, false);
        _assertEligibility(account, false, false, false);

        _grantAllEligibility(account);

        vm.prank(admin);
        registry.setTraderEligibility(account, false);
        _assertEligibility(account, true, false, true);

        vm.prank(admin);
        registry.setTraderEligibility(account, true);
        _assertEligibility(account, true, true, true);
    }

    /// @dev Liquidity-action updates leave Beneficiary and trader eligibility unchanged.
    function test_liquidityUpdates_leaveBeneficiaryAndTraderEligibilityUnchanged() public {
        vm.prank(admin);
        registry.setLiquidityEligibility(account, true);
        _assertEligibility(account, false, false, true);

        vm.prank(admin);
        registry.setLiquidityEligibility(account, false);
        _assertEligibility(account, false, false, false);

        _grantAllEligibility(account);

        vm.prank(admin);
        registry.setLiquidityEligibility(account, false);
        _assertEligibility(account, true, true, false);

        vm.prank(admin);
        registry.setLiquidityEligibility(account, true);
        _assertEligibility(account, true, true, true);
    }

    /*//////////////////////////////////////////////////////////////
                       G2-B — AUTHORIZATION
    //////////////////////////////////////////////////////////////*/

    /// @dev The registry is bound to the administrator supplied at construction.
    function test_registryAdmin_isTheConstructorAdministrator() public view {
        assertEq(registry.i_admin(), admin);
    }

    /// @dev A zero administrator is rejected rather than producing a permanently frozen registry.
    function test_construction_rejectsAZeroAdministrator() public {
        vm.expectRevert(EligibilityRegistry.EligibilityRegistry__InvalidAdmin.selector);
        new EligibilityRegistry(address(0));
    }

    /// @dev The authorized administrator can write all three eligibility categories.
    function test_admin_updatesAllThreeEligibilityCategories() public {
        _grantAllEligibility(account);

        _assertEligibility(account, true, true, true);
    }

    /// @dev An unauthorized account cannot grant any category, and the failed writes leave the
    ///      fail-closed defaults intact.
    function test_unauthorizedGrant_revertsInEveryCategoryAndChangesNothing() public {
        vm.startPrank(intruder);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setBeneficiaryEligibility(account, true);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setTraderEligibility(account, true);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setLiquidityEligibility(account, true);

        vm.stopPrank();

        _assertEligibility(account, false, false, false);
    }

    /// @dev An unauthorized account cannot revoke any category, and previously established eligibility
    ///      survives the failed writes unchanged.
    function test_unauthorizedRevocation_revertsAndLeavesEstablishedEligibilityUnchanged() public {
        _grantAllEligibility(account);

        vm.startPrank(intruder);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setBeneficiaryEligibility(account, false);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setTraderEligibility(account, false);

        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, intruder));
        registry.setLiquidityEligibility(account, false);

        vm.stopPrank();

        _assertEligibility(account, true, true, true);
    }

    /// @dev The administrator of one registry holds no authority over an independently deployed one.
    function test_administratorAuthority_isScopedToItsOwnRegistry() public {
        EligibilityRegistry otherRegistry = new EligibilityRegistry(intruder);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(EligibilityRegistry.EligibilityRegistry__NotAdmin.selector, admin));
        otherRegistry.setBeneficiaryEligibility(account, true);

        assertFalse(otherRegistry.canReceiveProtectedService(account));
    }

    /*//////////////////////////////////////////////////////////////
                     OBSERVATIONAL EVIDENCE
    //////////////////////////////////////////////////////////////*/

    /// @dev Each category emits its own event, so an observer can reconstruct which permission domain
    ///      changed without inferring it from the other two.
    function test_eligibilityWrites_emitDomainSpecificEvents() public {
        vm.startPrank(admin);

        vm.expectEmit(true, false, false, true, address(registry));
        emit BeneficiaryEligibilitySet(account, true);
        registry.setBeneficiaryEligibility(account, true);

        vm.expectEmit(true, false, false, true, address(registry));
        emit TraderEligibilitySet(account, true);
        registry.setTraderEligibility(account, true);

        vm.expectEmit(true, false, false, true, address(registry));
        emit LiquidityEligibilitySet(account, false);
        registry.setLiquidityEligibility(account, false);

        vm.stopPrank();
    }

    /// @dev The registry answers through the read interface Standby consumes, and that interface carries
    ///      the three predicates only.
    function test_registry_answersThroughTheConsumedReadInterface() public {
        vm.prank(admin);
        registry.setTraderEligibility(account, true);

        IEligibilityRegistry consumed = IEligibilityRegistry(address(registry));

        assertFalse(consumed.canReceiveProtectedService(account));
        assertTrue(consumed.canSwap(account));
        assertFalse(consumed.canProvideLiquidity(account));
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Reads all three predicates for `_account` and asserts each one independently.
    function _assertEligibility(address _account, bool _beneficiary, bool _trader, bool _liquidity) internal view {
        assertEq(registry.canReceiveProtectedService(_account), _beneficiary, "beneficiary eligibility");
        assertEq(registry.canSwap(_account), _trader, "trader eligibility");
        assertEq(registry.canProvideLiquidity(_account), _liquidity, "liquidity eligibility");
    }

    /// @dev Establishes all three predicates for `_account` through the authorized administrator path.
    function _grantAllEligibility(address _account) internal {
        vm.startPrank(admin);
        registry.setBeneficiaryEligibility(_account, true);
        registry.setTraderEligibility(_account, true);
        registry.setLiquidityEligibility(_account, true);
        vm.stopPrank();
    }
}
