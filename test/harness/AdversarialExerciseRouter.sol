// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "v4-core/interfaces/callback/IUnlockCallback.sol";
import {IERC20Minimal} from "v4-core/interfaces/external/IERC20Minimal.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

import {StandbyHook} from "../../src/StandbyHook.sol";
import {IActorAwarePeriphery} from "../../src/interfaces/IActorAwarePeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice A hostile O2 coordinator, used as the configured ExerciseRouter of an adversarial service.
/// @dev The production `ExerciseRouter` proposes exactly one swap, of exactly the shape the Hook admits, at
///      exactly the right point in the operation. That is a property of the router, and Standby must not
///      depend on it: the configured ExerciseRouter is trusted for originating-user attribution and for
///      nothing else, so every classification restriction has to hold against a router that does its worst.
///      This contract is that router. It is configured as a real service's ExerciseRouter, it authenticates
///      like the real one, and it proposes whatever a test tells it to.
///
///      It is deliberately not a subclass of the production router. Its purpose is to reach operation
///      shapes the production router structurally cannot express — a swap with no authorization behind it,
///      a substituted quantity, direction, price limit, or pool, a second swap against one authorization,
///      an extra unrelated pool interaction inside the same unlock, and a second authorization — so
///      inheriting production behavior would defeat the point.
///
///      It closes the deltas of whatever it manages to execute, mechanically and from its own balance, for
///      the same reason the delta-closure router does and with the same absence of meaning: an operation
///      that Standby permits must be observable, and F8B settles nothing. Every refused operation unwinds
///      the unlock long before that closure could matter.
///
///      Nothing this contract does is Standby behavior, and no test may read its ability to *attempt*
///      something as evidence that the attempt is admissible.
contract AdversarialExerciseRouter is IActorAwarePeriphery, IUnlockCallback {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice One hostile pool interaction sequence, carried across the unlock boundary.
    /// @param key The pool the operations are performed against.
    /// @param first The first proposed swap.
    /// @param second The second proposed swap, performed only when `performSecond` is set.
    /// @param performSecond Whether a second swap is attempted inside the same unlock.
    /// @param hookData The payload forwarded to the Hook verbatim.
    struct RoutedAttempt {
        PoolKey key;
        SwapParams first;
        SwapParams second;
        bool performSecond;
        bytes hookData;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The transient slot holding the originator of the request currently executing.
    bytes32 private constant ACTOR_CONTEXT_SLOT = keccak256("standby.test.AdversarialExerciseRouter.actorContext");

    StandbyHook public immutable i_hook;
    IPoolManager public immutable i_poolManager;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the originator is queried while no request is executing.
    error AdversarialExerciseRouter__NoActiveContext();

    /// @notice Thrown when the unlock callback is invoked by anything other than the PoolManager.
    /// @param caller The unauthorized caller.
    error AdversarialExerciseRouter__NotPoolManager(address caller);

    /// @notice Thrown when the mechanical closure of a currency debt does not succeed.
    /// @param currency The currency the debt is denominated in.
    /// @param amount The raw amount owed.
    error AdversarialExerciseRouter__ClosureTransferFailed(address currency, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the hostile coordinator to the Hook whose service it is configured on.
    /// @param _hook The StandbyHook that owns the Protected Execution Service.
    constructor(StandbyHook _hook) {
        i_hook = _hook;
        i_poolManager = _hook.poolManager();
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Proposes a swap with no Hook authorization behind it.
    /// @dev The configured ExerciseRouter identity, on the configured service pool, in the protected
    ///      direction, for a plausible quantity — and nothing else. If identity were classification, this
    ///      would be an O2 execution.
    /// @param _key The pool to swap against.
    /// @param _params The proposed swap.
    /// @param _hookData The payload forwarded to the Hook verbatim.
    function swapWithoutAuthorization(PoolKey calldata _key, SwapParams calldata _params, bytes calldata _hookData)
        external
    {
        _begin();

        _unlock(_key, _params, _params, false, _hookData);

        _end();
    }

    /// @notice Obtains a real authorization and then proposes an arbitrary swap against it.
    /// @param _commitmentId The commitment to authorize.
    /// @param _q The quantity to authorize.
    /// @param _key The pool to swap against.
    /// @param _params The proposed swap, which need not be the one the authorization admits.
    /// @param _hookData The payload forwarded to the Hook verbatim.
    function authorizeThenSwap(
        uint256 _commitmentId,
        uint256 _q,
        PoolKey calldata _key,
        SwapParams calldata _params,
        bytes calldata _hookData
    ) external {
        _begin();

        i_hook.authorizeExercise(_commitmentId, _q);

        _unlock(_key, _params, _params, false, _hookData);

        _end();
    }

    /// @notice Obtains one authorization and proposes two swaps against it inside one unlock.
    /// @param _commitmentId The commitment to authorize.
    /// @param _q The quantity to authorize.
    /// @param _key The pool to swap against.
    /// @param _first The first proposed swap.
    /// @param _second The second proposed swap.
    function authorizeThenSwapTwice(
        uint256 _commitmentId,
        uint256 _q,
        PoolKey calldata _key,
        SwapParams calldata _first,
        SwapParams calldata _second
    ) external {
        _begin();

        i_hook.authorizeExercise(_commitmentId, _q);

        _unlock(_key, _first, _second, true, bytes(""));

        _end();
    }

    /// @notice Attempts a second authorization before executing anything.
    /// @param _commitmentId The commitment to authorize.
    /// @param _firstQ The first authorized quantity.
    /// @param _secondQ The second authorized quantity.
    function authorizeTwice(uint256 _commitmentId, uint256 _firstQ, uint256 _secondQ) external {
        _begin();

        i_hook.authorizeExercise(_commitmentId, _firstQ);
        i_hook.authorizeExercise(_commitmentId, _secondQ);

        _end();
    }

    /// @notice Performs the proposed hostile operations inside the PoolManager unlock.
    /// @param _data The encoded attempt.
    /// @return result The encoded balance delta of the last performed operation.
    function unlockCallback(bytes calldata _data) external returns (bytes memory result) {
        if (msg.sender != address(i_poolManager)) revert AdversarialExerciseRouter__NotPoolManager(msg.sender);

        RoutedAttempt memory attempt = abi.decode(_data, (RoutedAttempt));

        BalanceDelta delta = i_poolManager.swap(attempt.key, attempt.first, attempt.hookData);

        if (attempt.performSecond) delta = delta + i_poolManager.swap(attempt.key, attempt.second, attempt.hookData);

        _closeDelta(attempt.key.currency0, delta.amount0());
        _closeDelta(attempt.key.currency1, delta.amount1());

        result = abi.encode(delta);
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = _actorContext();

        if (actor == address(0)) revert AdversarialExerciseRouter__NoActiveContext();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Zeroes one currency's outstanding delta. Mechanical accounting closure, never settlement.
    function _closeDelta(Currency _currency, int128 _amount) internal {
        if (_amount < 0) {
            uint256 owed = uint256(int256(-_amount));

            i_poolManager.sync(_currency);

            bool paid = IERC20Minimal(Currency.unwrap(_currency)).transfer(address(i_poolManager), owed);

            if (!paid) revert AdversarialExerciseRouter__ClosureTransferFailed(Currency.unwrap(_currency), owed);

            i_poolManager.settle();
        } else if (_amount > 0) {
            i_poolManager.take(_currency, address(this), uint256(int256(_amount)));
        }
    }

    /// @dev Opens the unlock carrying one hostile attempt.
    function _unlock(
        PoolKey calldata _key,
        SwapParams memory _first,
        SwapParams memory _second,
        bool _performSecond,
        bytes memory _hookData
    ) internal {
        i_poolManager.unlock(
            abi.encode(
                RoutedAttempt({
                    key: _key,
                    first: _first,
                    second: _second,
                    performSecond: _performSecond,
                    hookData: _hookData
                })
            )
        );
    }

    /// @dev Binds the caller as the originator of the request.
    function _begin() internal {
        _setActorContext(msg.sender);
    }

    /// @dev Clears the originator.
    function _end() internal {
        _setActorContext(address(0));
    }

    /// @dev Writes the transient originator context.
    function _setActorContext(address _actor) internal {
        bytes32 slot = ACTOR_CONTEXT_SLOT;

        assembly ("memory-safe") {
            tstore(slot, _actor)
        }
    }

    /// @dev Reads the transient originator context.
    function _actorContext() internal view returns (address actor) {
        bytes32 slot = ACTOR_CONTEXT_SLOT;

        assembly ("memory-safe") {
            actor := tload(slot)
        }
    }
}
