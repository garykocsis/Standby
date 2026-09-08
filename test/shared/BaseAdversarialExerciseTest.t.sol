// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                              IMPORTS
//////////////////////////////////////////////////////////////*/

import {AdversarialExerciseRouter} from "../harness/AdversarialExerciseRouter.sol";
import {BaseExerciseAuthorizationTest} from "./BaseExerciseAuthorizationTest.t.sol";

/*//////////////////////////////////////////////////////////////
                             CONTRACTS
//////////////////////////////////////////////////////////////*/

/// @notice Shared fixture whose configured ExerciseRouter is hostile.
/// @dev The production ExerciseRouter proposes one swap, of the admitted shape, at the right moment. Every
///      Standby classification restriction has to hold without that cooperation, because the configured
///      ExerciseRouter is trusted for originating-user attribution and for nothing else. This fixture
///      therefore activates the canonical service with `AdversarialExerciseRouter` in that role — a real
///      configured coordinator, authenticated exactly as the production one is, that proposes whatever a
///      test asks it to.
///
///      Everything else is the ordinary F8A/F8B fixture and is unchanged: the real PoolManager, the
///      production Hook from the canonical deployment procedure, the production activation, the canonical
///      liquidity through the production liquidity path, and commitments created only by the production O1
///      transition. Nothing about the Hook is substituted, so every refusal observed here is a production
///      refusal.
///
///      The production `ExerciseRouter` is not exercised by this fixture and no claim about it may be drawn
///      from one: what is proven here is that the Hook does not depend on it.
abstract contract BaseAdversarialExerciseTest is BaseExerciseAuthorizationTest {
    /*//////////////////////////////////////////////////////////////
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @dev The hostile coordinator the service was actually activated with.
    AdversarialExerciseRouter internal adversarialExerciseRouter;

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @dev Activates the service with the hostile coordinator instead of the production router.
    function _resolveExerciseRouter() internal override returns (address router) {
        adversarialExerciseRouter = new AdversarialExerciseRouter(hook);

        router = address(adversarialExerciseRouter);
    }
}
