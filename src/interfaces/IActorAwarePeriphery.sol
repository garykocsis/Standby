// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/*//////////////////////////////////////////////////////////////
                            INTERFACES
//////////////////////////////////////////////////////////////*/

/// @title IActorAwarePeriphery
/// @notice The one question Standby asks a trusted execution perimeter: who originated the routed action
///         currently executing.
/// @dev This interface is provenance and transport only. A perimeter implementing it attests exactly one
///      fact — the direct originating caller of the action it is currently routing — and attests nothing
///      else. It does not decide eligibility, pool identity, service-domain validity, topology validity,
///      Supporting Capacity, Aggregate Capacity Obligation, O1/O2/O3 classification, transition safety, or
///      fulfillment. Those remain owned by the components the architecture assigns them to.
///
///      Answering this question does not make a perimeter authoritative. Trust flows the other way: the
///      Hook first authenticates that the callback sender is exactly the perimeter its immutable
///      configuration designates for that transition family, and only then asks this question. An
///      unauthenticated contract implementing this interface establishes no economic identity, however
///      convincing its answer looks.
interface IActorAwarePeriphery {
    /// @notice Returns the authenticated originator of the routed action currently executing.
    /// @dev Fails closed when no routed action is in flight. Returning `msg.sender`, `tx.origin`, or any
    ///      other plausible substitute in that case would manufacture an economic actor out of an absent
    ///      execution context.
    /// @return actor The account that originated the routed action currently executing.
    function msgSender() external view returns (address actor);
}
