module fta::management;

use fta::fta::FrontierTransitAuthority;
use fta::management_cap::ManagementCap;
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
    let gate_record = fta.gate_table_mut().get_by_gate_mut(gate);
    assert!(
        management_cap.is_authorized(object::id(gate), gate_record.object_registration_id()),
        EManagementCapWrongResource,
    );
    gate_record.update_fee(jump_fee, takes_effect_on, clock);
}

public fun update_gate_fee_recipient(
    fta: &mut FrontierTransitAuthority,
    management_cap: &ManagementCap<Gate>,
    gate: &Gate,
    recipient: address,
) {
    let gate_record = fta.gate_table_mut().get_by_gate_mut(gate);
    assert!(
        management_cap.is_authorized(object::id(gate), gate_record.object_registration_id()),
        EManagementCapWrongResource,
    );
    gate_record.update_fee_recipient(recipient);
}

/// Updates the fee for a network node
public fun update_network_node_fee(
    fta: &mut FrontierTransitAuthority,
    management_cap: &ManagementCap<NetworkNode>,
    network_node: &NetworkNode,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
    let network_node_record = fta.get_network_node_record_mut(network_node);
    assert!(
        management_cap.is_authorized(
            object::id(network_node),
            network_node_record.object_registration_id(),
        ),
        EManagementCapWrongResource,
    );
    network_node_record.update_fee(jump_fee, takes_effect_on, clock);
}

/// Updates the recipient for fees paid to jump through a gate connected to this network node
public fun update_network_node_fee_recipient(
    fta: &mut FrontierTransitAuthority,
    management_cap: &ManagementCap<NetworkNode>,
    network_node: &NetworkNode,
    recipient: address,
) {
    let network_node_record = fta.get_network_node_record_mut(network_node);
    assert!(
        management_cap.is_authorized(
            object::id(network_node),
            network_node_record.object_registration_id(),
        ),
        EManagementCapWrongResource,
    );
    network_node_record.update_fee_recipient(recipient);
}
