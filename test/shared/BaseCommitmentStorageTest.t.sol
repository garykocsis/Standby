// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {HookMiner} from "v4-hooks-public/src/utils/HookMiner.sol";

import {PoolId} from "v4-core/types/PoolId.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";

import {StandbyHookHarness} from "../harness/StandbyHookHarness.sol";
import {BaseStandbyServiceTest} from "./BaseStandbyServiceTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared fixture for isolated F4 commitment-storage and bounded-reference verification.
/// @dev Inherits the real unconfigured Standby environment and adds one `StandbyHookHarness`, mined to a
///      permission-valid address through the same mask the canonical deployment procedure uses, so the
///      harness is a real Hook and not an address-unconstrained stand-in.
///
///      The harness Hook is deliberately left unconfigured. F4 storage mechanics record the facts they
///      are given and interpret nothing, so they must work identically whether or not a Protected
///      Execution Service exists; leaving activation out proves that the two responsibilities are not
///      entangled. Commitment facts here are arbitrary test data, not admitted economic terms.
abstract contract BaseCommitmentStorageTest is BaseStandbyServiceTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    StandbyHookHarness internal harness;

    /*//////////////////////////////////////////////////////////////
                                SETUP
    //////////////////////////////////////////////////////////////*/

    /// @notice Deploys the commitment-storage harness alongside the real unconfigured environment.
    function setUp() public virtual override {
        super.setUp();

        harness = _deployCommitmentHarness();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Mines and deploys the harness at an address encoding the required Hook permission bits.
    function _deployCommitmentHarness() internal returns (StandbyHookHarness deployed) {
        bytes memory constructorArgs =
            abi.encode(poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager);

        (, bytes32 salt) = HookMiner.find(
            address(this),
            hookDeployer.REQUIRED_HOOK_PERMISSION_MASK(),
            type(StandbyHookHarness).creationCode,
            constructorArgs
        );

        deployed = new StandbyHookHarness{salt: salt}(
            poolManager, configurationAuthority, trustedUniversalRouter, trustedPositionManager
        );
    }

    /// @dev Builds a distinguishable commitment record from a single seed.
    ///
    ///      Every field is derived from the seed and no two fields share a value, so a mechanic that
    ///      wrote the right value into the wrong field, or copied one record over another, cannot produce
    ///      a passing round trip. These are arbitrary facts: nothing here asserts they are admissible.
    function _commitmentFor(uint256 _seed) internal pure returns (StandbyHook.Commitment memory record) {
        record = StandbyHook.Commitment({
            serviceId: PoolId.wrap(keccak256(abi.encode("serviceId", _seed))),
            beneficiary: address(uint160(uint256(keccak256(abi.encode("beneficiary", _seed))))),
            exercisableFrom: uint64(uint256(keccak256(abi.encode("exercisableFrom", _seed)))),
            exerciseAuthority: address(uint160(uint256(keccak256(abi.encode("exerciseAuthority", _seed))))),
            validUntil: uint64(uint256(keccak256(abi.encode("validUntil", _seed)))),
            originalEntitlement: uint128(uint256(keccak256(abi.encode("originalEntitlement", _seed)))),
            remainingEntitlement: uint128(uint256(keccak256(abi.encode("remainingEntitlement", _seed))))
        });
    }

    /// @dev Asserts that a stored record equals an expected record field by field.
    function _assertCommitmentEquals(
        StandbyHook.Commitment memory _actual,
        StandbyHook.Commitment memory _expected,
        string memory _context
    ) internal pure {
        assertEq(PoolId.unwrap(_actual.serviceId), PoolId.unwrap(_expected.serviceId), _context);
        assertEq(_actual.beneficiary, _expected.beneficiary, _context);
        assertEq(uint256(_actual.exercisableFrom), uint256(_expected.exercisableFrom), _context);
        assertEq(_actual.exerciseAuthority, _expected.exerciseAuthority, _context);
        assertEq(uint256(_actual.validUntil), uint256(_expected.validUntil), _context);
        assertEq(uint256(_actual.originalEntitlement), uint256(_expected.originalEntitlement), _context);
        assertEq(uint256(_actual.remainingEntitlement), uint256(_expected.remainingEntitlement), _context);
    }
}
