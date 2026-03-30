module fta::gate_control;

use fta::access;
use fta::fta::FrontierTransitAuthority;
use sui::transfer::Receiving;
use world::access::OwnerCap;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const EGateHasNoNetworkNode: vector<u8> =
    b"The gate does not have a network node (it may have been destroyed)";
#[error(code = 3)]
const ENetworkNodeNotRegistered: vector<u8> =
    b"The network node for this gate has not been registered with the Frontier Transit Authority";

/// Onlines or Offlines an FTA gate if it's not already online
public(package) fun change_gate_online(
    fta: &mut FrontierTransitAuthority,
    gate: &mut Gate,
    gate_owner_cap_ticket: Receiving<OwnerCap<Gate>>,
    network_node: &mut NetworkNode,
    online: bool,
    energy_config: &EnergyConfig,
    ctx: &TxContext,
) {
    assert!(fta.gate_registry().registered(gate), EGateNotInNetwork);
    assert!(gate.energy_source_id().is_some(), EGateHasNoNetworkNode);
    assert!(
        fta.network_node_registry().registered_by_id(*gate.energy_source_id().borrow()),
        ENetworkNodeNotRegistered,
    );
    if (gate.is_online() != online) {
        let (gate_owner_cap, receipt) = access::borrow_gate_owner_cap(
            fta,
            gate,
            gate_owner_cap_ticket,
            ctx,
        );
        if (online) {
            gate.online(network_node, energy_config, &gate_owner_cap);
        } else {
            gate.offline(network_node, energy_config, &gate_owner_cap);
        };
        access::return_owner_cap(fta, gate_owner_cap, receipt, ctx);
    }
}

// public(package) fun prepare_for_jump(
//     fta: &FrontierTransitAuthority,
//     character: &mut Character,
//     gate_1: &mut Gate,
//     gate_1_owner_cap_ticket: Receiving<OwnerCap<Gate>>,
//     network_node_1: &mut NetworkNode,
//     gate_2: &mut Gate,
//     gate_2_owner_cap_ticket: Receiving<OwnerCap<Gate>>,
//     network_node_2: &mut NetworkNode,
//     energy_config: &EnergyConfig,
//     ctx: &mut TxContext,
// ) {
//     assert!(
//         gate_1.linked_gate_id().is_some() && gate_1.linked_gate_id().borrow() == object::id(gate_2),
//         EGatesNotLinked,
//     );
//     change_online(
//         fta,
//         character,
//         gate_1,
//         gate_1_owner_cap_ticket,
//         network_node_1,
//         true,
//         energy_config,
//         ctx,
//     );
//     change_online(
//         fta,
//         character,
//         gate_2,
//         gate_2_owner_cap_ticket,
//         network_node_2,
//         true,
//         energy_config,
//         ctx,
//     );
// }
