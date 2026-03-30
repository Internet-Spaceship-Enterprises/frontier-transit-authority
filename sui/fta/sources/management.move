module fta::management;

use fta::fta::FrontierTransitAuthority;
use fta::management_cap::{Self, ManagementCap};
use sui::clock::Clock;
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EManagementCapWrongResource: vector<u8> = b"This ManagementCap is for the wrong resource";

// Updates the fee for a gate
public fun update_gate_fee(
    fta: &mut FrontierTransitAuthority,
    management_cap: &ManagementCap<Gate>,
    gate: &Gate,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
    assert!(management_cap.is_authorized(object::id(gate)), EManagementCapWrongResource);
    let gate_record = fta.get_gate_record_mut(gate);
    gate_record.update_fee(jump_fee, takes_effect_on, clock);
}

// Updates the fee for a network node
public fun update_network_node_fee(
    fta: &mut FrontierTransitAuthority,
    management_cap: &ManagementCap<NetworkNode>,
    network_node: &NetworkNode,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
    assert!(management_cap.is_authorized(object::id(network_node)), EManagementCapWrongResource);
    let network_node_record = fta.get_network_node_record_mut(network_node);
    network_node_record.update_fee(jump_fee, takes_effect_on, clock);
}

// TODO: destroy managementcap when a gate or network node is removed from the FTA registry.
