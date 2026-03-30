module fta::network_node_registry;

use fta::network_node_record::NetworkNodeRecord;
use sui::linked_table::{Self, LinkedTable};
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 1)]
const ENetworkNodeAlreadyRegistered: vector<u8> =
    b"This network node is already registered with the Frontier Transit Authority";
#[error(code = 2)]
const ENetworkNodeNotRegistered: vector<u8> =
    b"This network node is not registered with the Frontier Transit Authority network";
#[error(code = 3)]
const EGateHasNoNetworkNode: vector<u8> =
    b"The gate does not have a network node (it may have been destroyed)";

public struct NetworkNodeRegistry has store {
    // Maps network node ID to network node record
    table: LinkedTable<ID, NetworkNodeRecord>,
}

public(package) fun new(ctx: &mut TxContext): NetworkNodeRegistry {
    NetworkNodeRegistry {
        table: linked_table::new<ID, NetworkNodeRecord>(ctx),
    }
}

public(package) fun registered(registry: &NetworkNodeRegistry, node: &NetworkNode): bool {
    registry.registered_by_id(object::id(node))
}

public(package) fun registered_by_id(registry: &NetworkNodeRegistry, node_id: ID): bool {
    registry.table.contains(node_id)
}

public(package) fun registered_by_gate(registry: &NetworkNodeRegistry, gate: &Gate): bool {
    let energy_source_id_opt = gate.energy_source_id();
    assert!(energy_source_id_opt.is_some(), EGateHasNoNetworkNode);
    registry.registered_by_id(*energy_source_id_opt.borrow())
}

public(package) fun registered_by_record(
    registry: &NetworkNodeRegistry,
    record: &NetworkNodeRecord,
): bool {
    registry.table.contains(record.network_node_id())
}

public(package) fun add(registry: &mut NetworkNodeRegistry, record: NetworkNodeRecord) {
    assert!(!registry.registered_by_record(&record), ENetworkNodeAlreadyRegistered);
    registry.table.push_back(record.network_node_id(), record);
}

public(package) fun get(registry: &NetworkNodeRegistry, node: &NetworkNode): &NetworkNodeRecord {
    assert!(registry.registered(node), ENetworkNodeNotRegistered);
    registry.get_by_id(object::id(node))
}

public(package) fun get_mut(
    registry: &mut NetworkNodeRegistry,
    node: &NetworkNode,
): &mut NetworkNodeRecord {
    assert!(registry.registered(node), ENetworkNodeNotRegistered);
    registry.get_by_id_mut(object::id(node))
}

public(package) fun get_by_id(registry: &NetworkNodeRegistry, node_id: ID): &NetworkNodeRecord {
    assert!(registry.registered_by_id(node_id), ENetworkNodeNotRegistered);
    registry.table.borrow(node_id)
}

public(package) fun get_by_id_mut(
    registry: &mut NetworkNodeRegistry,
    node_id: ID,
): &mut NetworkNodeRecord {
    assert!(registry.registered_by_id(node_id), ENetworkNodeNotRegistered);
    registry.table.borrow_mut(node_id)
}

public(package) fun get_by_gate(registry: &NetworkNodeRegistry, gate: &Gate): &NetworkNodeRecord {
    let energy_source_id_opt = gate.energy_source_id();
    assert!(energy_source_id_opt.is_some(), EGateHasNoNetworkNode);
    let network_node_id = *energy_source_id_opt.borrow();
    assert!(registry.registered_by_id(network_node_id), ENetworkNodeNotRegistered);
    registry.get_by_id(network_node_id)
}

public(package) fun deregister(registry: &mut NetworkNodeRegistry, node: &NetworkNode) {
    assert!(registry.registered(node), ENetworkNodeNotRegistered);
    registry.table.remove(object::id(node)).destroy();
}

public(package) fun deregister_by_id(registry: &mut NetworkNodeRegistry, network_node_id: ID) {
    assert!(registry.registered_by_id(network_node_id), ENetworkNodeNotRegistered);
    registry.table.remove(network_node_id).destroy();
}

// Returns a list of the IDs of all network nodes managed by the FTA
public(package) fun managed_network_node_ids(registry: &NetworkNodeRegistry): vector<ID> {
    let mut keys = vector::empty<ID>();

    let cur_ref = registry.table.front();
    if (option::is_none(cur_ref)) {
        return keys
    };

    let mut cur = *option::borrow(cur_ref);
    vector::push_back(&mut keys, cur);

    loop {
        let next_ref = registry.table.next(cur);
        if (option::is_none(next_ref)) {
            break
        };
        cur = *option::borrow(next_ref);
        vector::push_back(&mut keys, cur);
    };

    keys
}
