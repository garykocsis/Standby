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
import {ModifyLiquidityParams, SwapParams} from "v4-core/types/PoolOperation.sol";

import {IActorAwarePeriphery} from "../interfaces/IActorAwarePeriphery.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @title ActorAwareTestRouter
/// @notice A minimal deterministic-local execution perimeter that preserves originating-user identity
///         across the Uniswap v4 unlock boundary.
/// @dev The official pinned v4 test routers execute real pool operations but tell a Hook nothing about who
///      asked for them: by the time `beforeSwap` runs, the only caller identity Uniswap carries is the
///      locker's. Standby's permissioned MVP needs the originating user, so the deterministic-local and
///      demo environments need a perimeter that can supply one. That is this contract, and that is all of
///      it (`uniswap-v4-realization.md` RR-PERM-4, RR-PERM-4A; `implementation-plan.md` §11.3).
///
///      This contract is not a Standby economic authority. Its single authoritative contribution is:
///
///      > for the routed action currently executing, the direct originating caller was address X.
///
///      It decides no eligibility, validates no PoolId, derives no Supporting Capacity, sums no Aggregate
///      Capacity Obligation, classifies no service domain or topology, distinguishes no O1/O2/O3, and
///      proves no fulfillment. It cannot: the Hook re-derives every one of those from authoritative state,
///      and the Hook trusts this contract's answer only after authenticating that the callback sender is
///      exactly the perimeter its immutable configuration designates for that transition family. Deploying
///      an identical copy of this bytecode therefore grants nothing.
///
///      Attribution is execution context, not protocol history. The originator is bound in transient
///      storage when a routed action begins and cleared when it ends, so the lifecycle is
///      `EMPTY -> ACTIVE(actor) -> EMPTY` within one transaction and no reusable identity survives it. A
///      second routed action attempted while a context is already active is rejected rather than stacked:
///      Standby needs one unambiguous originator per routed action, and a nested context would make
///      "the actor" a question about call depth.
///
///      The originator is the direct caller of the user-facing entry point. `tx.origin` is never consulted,
///      and no caller-supplied actor field, forwarded address, or hook payload can substitute for it.
///      `hookData` is forwarded to the pool verbatim and is never read here.
///
///      Supported currency domain: exact-transfer ERC-20 currencies, matching the realization's supported
///      assumptions. Native currency is not supported and is not silently approximated — settlement of a
///      native currency simply fails.
contract ActorAwareTestRouter is IActorAwarePeriphery, IUnlockCallback {
    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice The pool operation a routed action performs.
    enum RoutedAction {
        Swap,
        ModifyLiquidity
    }

    /// @notice One routed action, carried across the PoolManager unlock boundary.
    /// @param action The pool operation to perform.
    /// @param actor The authenticated originator of the routed action.
    /// @param key The pool the action is performed against.
    /// @param swapParams The proposed swap, meaningful for `RoutedAction.Swap`.
    /// @param liquidityParams The proposed liquidity modification, meaningful for
    ///        `RoutedAction.ModifyLiquidity`.
    /// @param hookData Opaque payload forwarded to the pool's Hook verbatim.
    struct RoutedCall {
        RoutedAction action;
        address actor;
        PoolKey key;
        SwapParams swapParams;
        ModifyLiquidityParams liquidityParams;
        bytes hookData;
    }

    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The transient slot holding the originator of the routed action currently executing.
    ///      Transient storage is used deliberately: the fact is transaction-local, and ordinary storage
    ///      would leave a reusable identity behind for the next transaction to find.
    bytes32 private constant ACTOR_CONTEXT_SLOT = keccak256("standby.demo.ActorAwareTestRouter.actorContext");

    /// @notice The PoolManager this perimeter routes actions to.
    IPoolManager public immutable i_poolManager;

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when the unlock callback is invoked by anything other than the PoolManager.
    /// @param caller The unauthorized caller.
    error ActorAwareTestRouter__NotPoolManager(address caller);

    /// @notice Thrown when the originator is queried while no routed action is executing.
    error ActorAwareTestRouter__NoActiveActorContext();

    /// @notice Thrown when a routed action is attempted while another is already executing.
    /// @param actor The originator of the routed action already in flight.
    error ActorAwareTestRouter__ActorContextAlreadyActive(address actor);

    /// @notice Thrown when the originating actor's payment of a routed action's debt does not succeed.
    /// @param currency The currency the debt is denominated in.
    /// @param payer The originating actor the debt was charged to.
    /// @param amount The raw amount owed.
    error ActorAwareTestRouter__SettlementTransferFailed(address currency, address payer, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                             CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Binds the perimeter to the PoolManager it routes actions to.
    /// @param _poolManager The PoolManager this perimeter unlocks and operates against.
    constructor(IPoolManager _poolManager) {
        i_poolManager = _poolManager;
    }

    /*//////////////////////////////////////////////////////////////
                         EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Routes a swap, preserving the caller as the originating actor.
    /// @dev The caller pays what the swap owes and receives what it yields; this perimeter never holds a
    ///      position of its own in the outcome.
    /// @param _key The pool to swap against.
    /// @param _params The proposed swap.
    /// @param _hookData Opaque payload forwarded to the pool's Hook verbatim.
    /// @return delta The balance delta the swap produced for the routed action.
    function swap(PoolKey calldata _key, SwapParams calldata _params, bytes calldata _hookData)
        external
        returns (BalanceDelta delta)
    {
        address actor = _beginActorContext();

        RoutedCall memory routed = RoutedCall({
            action: RoutedAction.Swap,
            actor: actor,
            key: _key,
            swapParams: _params,
            liquidityParams: ModifyLiquidityParams({tickLower: 0, tickUpper: 0, liquidityDelta: 0, salt: bytes32(0)}),
            hookData: _hookData
        });

        delta = abi.decode(i_poolManager.unlock(abi.encode(routed)), (BalanceDelta));

        _endActorContext();
    }

    /// @notice Routes a liquidity modification, preserving the caller as the originating actor.
    /// @dev Uniswap credits a position to the account that calls `modifyLiquidity`, which here is this
    ///      perimeter rather than the user. The position salt is therefore derived from the originating
    ///      actor and the caller-supplied salt, so that one actor's position cannot be modified or
    ///      withdrawn through this shared perimeter by another. That is position custody and nothing more:
    ///      Standby never reads the salt, and no Standby economic decision changes because of it.
    /// @param _key The pool to modify liquidity in.
    /// @param _params The proposed liquidity modification.
    /// @param _hookData Opaque payload forwarded to the pool's Hook verbatim.
    /// @return delta The balance delta the modification produced for the routed action, fees included.
    function modifyLiquidity(PoolKey calldata _key, ModifyLiquidityParams calldata _params, bytes calldata _hookData)
        external
        returns (BalanceDelta delta)
    {
        address actor = _beginActorContext();

        RoutedCall memory routed = RoutedCall({
            action: RoutedAction.ModifyLiquidity,
            actor: actor,
            key: _key,
            swapParams: SwapParams({zeroForOne: false, amountSpecified: 0, sqrtPriceLimitX96: 0}),
            liquidityParams: _params,
            hookData: _hookData
        });

        delta = abi.decode(i_poolManager.unlock(abi.encode(routed)), (BalanceDelta));

        _endActorContext();
    }

    /// @notice Performs the routed action inside the PoolManager unlock.
    /// @dev Only the PoolManager may invoke this. Everything economically meaningful about the action is
    ///      decided by the pool and its Hook; this function performs the operation and settles the
    ///      resulting deltas against the originating actor.
    /// @param _data The encoded routed action.
    /// @return result The encoded balance delta of the performed action.
    function unlockCallback(bytes calldata _data) external returns (bytes memory result) {
        if (msg.sender != address(i_poolManager)) revert ActorAwareTestRouter__NotPoolManager(msg.sender);

        RoutedCall memory routed = abi.decode(_data, (RoutedCall));

        BalanceDelta delta = routed.action == RoutedAction.Swap ? _executeSwap(routed) : _executeModifyLiquidity(routed);

        _settle(routed.key.currency0, routed.actor, delta.amount0());
        _settle(routed.key.currency1, routed.actor, delta.amount1());

        result = abi.encode(delta);
    }

    /// @inheritdoc IActorAwarePeriphery
    function msgSender() external view returns (address actor) {
        actor = _actorContext();

        if (actor == address(0)) revert ActorAwareTestRouter__NoActiveActorContext();
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Performs the swap against the real PoolManager.
    function _executeSwap(RoutedCall memory _routed) internal returns (BalanceDelta delta) {
        delta = i_poolManager.swap(_routed.key, _routed.swapParams, _routed.hookData);
    }

    /// @dev Performs the liquidity modification against the real PoolManager, under actor-scoped custody.
    function _executeModifyLiquidity(RoutedCall memory _routed) internal returns (BalanceDelta delta) {
        ModifyLiquidityParams memory params = _routed.liquidityParams;

        params.salt = keccak256(abi.encode(_routed.actor, params.salt));

        (delta,) = i_poolManager.modifyLiquidity(_routed.key, params, _routed.hookData);
    }

    /// @dev Resolves one currency's side of a routed action against the originating actor.
    ///
    ///      A debt is paid by the actor and a credit is delivered to the actor, so this perimeter never
    ///      becomes the economic counterparty of the action it routes.
    function _settle(Currency _currency, address _actor, int128 _amount) internal {
        if (_amount < 0) {
            uint256 owed = uint256(int256(-_amount));

            i_poolManager.sync(_currency);

            bool paid = IERC20Minimal(Currency.unwrap(_currency)).transferFrom(_actor, address(i_poolManager), owed);

            if (!paid) revert ActorAwareTestRouter__SettlementTransferFailed(Currency.unwrap(_currency), _actor, owed);

            i_poolManager.settle();
        } else if (_amount > 0) {
            i_poolManager.take(_currency, _actor, uint256(int256(_amount)));
        }
    }

    /// @dev Binds the caller as the originator of a new routed action.
    ///
    ///      A context that is already active is rejected rather than replaced or stacked, so exactly one
    ///      unambiguous originator exists for the duration of a routed action.
    function _beginActorContext() internal returns (address actor) {
        address active = _actorContext();

        if (active != address(0)) revert ActorAwareTestRouter__ActorContextAlreadyActive(active);

        actor = msg.sender;

        _setActorContext(actor);
    }

    /// @dev Clears the originator context, returning the perimeter to EMPTY.
    function _endActorContext() internal {
        _setActorContext(address(0));
    }

    /// @dev Writes the transient originator context.
    function _setActorContext(address _actor) internal {
        bytes32 slot = ACTOR_CONTEXT_SLOT;

        assembly ("memory-safe") {
            tstore(slot, _actor)
        }
    }

    /// @dev Reads the transient originator context. Zero means no routed action is executing.
    function _actorContext() internal view returns (address actor) {
        bytes32 slot = ACTOR_CONTEXT_SLOT;

        assembly ("memory-safe") {
            actor := tload(slot)
        }
    }
}
