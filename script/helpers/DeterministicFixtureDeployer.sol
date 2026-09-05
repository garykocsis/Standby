// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {MockUSDC} from "../../src/mocks/MockUSDC.sol";
import {MockUSTB} from "../../src/mocks/MockUSTB.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title DeterministicFixtureDeployer
/// @notice Deploys the canonical Standby fixture currencies so that Uniswap currency ordering is a
///         guaranteed property of the deployment rather than an accident of CREATE nonce order.
/// @dev Explicitly fixture-scoped. This contract exists so `MockUSTB` becomes `currency0` and `MockUSDC`
///      becomes `currency1` by construction: a salt is selected against the actual CREATE2 deployer
///      address and the actual mock init-code hashes such that the predicted addresses already satisfy
///      the required ordering, and the deployment then asserts the deployed addresses match.
///
///      The alternative approaches are deliberately rejected: ordinary CREATE order does not guarantee
///      the relation, and relabelling deployed tokens after the fact would make the canonical identities
///      a function of deployment luck rather than of the fixture definition.
///
///      This contract owns no Standby economic truth. It knows the two fixture currency types and
///      nothing about PoolKeys, ticks, protected direction, capacity, obligations, or eligibility.
contract DeterministicFixtureDeployer {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice The bound on the deterministic ordered-salt search.
    /// @dev Each candidate salt satisfies the ordering with probability ~1/2, so the search terminates
    ///      almost immediately. The bound exists so the fixture fails loudly instead of consuming an
    ///      unbounded amount of gas.
    uint256 public constant MAX_SALT_SEARCH = 1024;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when no candidate salt within the search bound produces the required ordering.
    /// @param searched The number of candidate salts examined.
    error DeterministicFixtureDeployer__OrderedSaltNotFound(uint256 searched);

    /// @notice Thrown when a fixture currency did not deploy to its deterministically predicted address.
    /// @param predicted The address predicted for the selected salt.
    /// @param deployed The address the currency actually deployed to.
    error DeterministicFixtureDeployer__AddressMismatch(address predicted, address deployed);

    /// @notice Thrown when the deployed fixture currencies do not satisfy the required ordering.
    /// @param ustb The deployed MockUSTB address, required to be the lower address.
    /// @param usdc The deployed MockUSDC address, required to be the higher address.
    error DeterministicFixtureDeployer__CurrencyOrderingViolated(address ustb, address usdc);

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Deterministically deploys the canonical fixture currencies in the required address order.
    /// @dev Predicts both addresses for the selected salt before deploying, then proves the deployed
    ///      addresses equal those predictions and satisfy `address(MockUSTB) < address(MockUSDC)`.
    /// @return ustb The deployed MockUSTB, guaranteed to be the lower address.
    /// @return usdc The deployed MockUSDC, guaranteed to be the higher address.
    /// @return salt The CREATE2 salt that produced both addresses.
    function deployOrderedFixtureCurrencies() external returns (MockUSTB ustb, MockUSDC usdc, bytes32 salt) {
        salt = findOrderedSalt();

        address predictedUstb = predictAddress(salt, keccak256(type(MockUSTB).creationCode));
        address predictedUsdc = predictAddress(salt, keccak256(type(MockUSDC).creationCode));

        ustb = new MockUSTB{salt: salt}();
        usdc = new MockUSDC{salt: salt}();

        if (address(ustb) != predictedUstb) {
            revert DeterministicFixtureDeployer__AddressMismatch(predictedUstb, address(ustb));
        }

        if (address(usdc) != predictedUsdc) {
            revert DeterministicFixtureDeployer__AddressMismatch(predictedUsdc, address(usdc));
        }

        if (address(ustb) >= address(usdc)) {
            revert DeterministicFixtureDeployer__CurrencyOrderingViolated(address(ustb), address(usdc));
        }
    }

    /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Selects the lowest candidate salt whose predicted addresses satisfy the required ordering.
    /// @dev Uses the actual init-code hashes of both mocks and the actual CREATE2 deployer address, so
    ///      the selected salt is a deterministic function of this deployer's address and the compiled
    ///      mock bytecode.
    /// @return salt The selected CREATE2 salt.
    function findOrderedSalt() public view returns (bytes32 salt) {
        bytes32 ustbInitCodeHash = keccak256(type(MockUSTB).creationCode);
        bytes32 usdcInitCodeHash = keccak256(type(MockUSDC).creationCode);

        for (uint256 i = 0; i < MAX_SALT_SEARCH; ++i) {
            bytes32 candidate = bytes32(i);

            if (predictAddress(candidate, ustbInitCodeHash) < predictAddress(candidate, usdcInitCodeHash)) {
                return candidate;
            }
        }

        revert DeterministicFixtureDeployer__OrderedSaltNotFound(MAX_SALT_SEARCH);
    }

    /// @notice Predicts the CREATE2 address this deployer produces for a salt and init-code hash.
    /// @param _salt The CREATE2 salt.
    /// @param _initCodeHash The keccak256 hash of the contract creation code.
    /// @return predicted The deterministic CREATE2 address.
    function predictAddress(bytes32 _salt, bytes32 _initCodeHash) public view returns (address predicted) {
        predicted =
            address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, _initCodeHash)))));
    }
}
