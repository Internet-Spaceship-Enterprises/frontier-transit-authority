module fta::network_node_registry;

use fta::network_node_record::{Self, NetworkNodeRecord};
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};
use world::access::OwnerCap;
use world::character::Character;
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
#[error(code = 2)]
const ENetworkNodeOwnerCapMismatch: vector<u8> =
    b"OwnerCap<NetworkNode> does not belong to this NetworkNode";

public struct NetworkNodeRegistry has store {
    // Maps network node ID to network node record
    table: LinkedTable<ID, NetworkNodeRecord>,
}

public(package) fun new(ctx: &mut TxContext): NetworkNodeRegistry {
    NetworkNodeRegistry {
        table: linked_table::new<ID, NetworkNodeRecord>(ctx),
    }
}

/// Registers a network node to be used in FTA operations.
/// For now, it does not actually transfer ownership, it just tracks the fees associated with using it.
public(package) fun register(
    network_node_registry: &mut NetworkNodeRegistry,
    current_owner: &Character,
    network_node: &NetworkNode,
    network_node_owner_cap: &OwnerCap<NetworkNode>,
    jump_fee: u64,
    fee_recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // If it's already registered, bail out
    assert!(!network_node_registry.registered(network_node), ENetworkNodeAlreadyRegistered);
    // Ensure the network node owner cap provided is the right one for the network node
    assert!(
        network_node_owner_cap.is_authorized(object::id(network_node)),
        ENetworkNodeOwnerCapMismatch,
    );
    assert!(
        network_node.owner_cap_id() == object::id(network_node_owner_cap),
        ENetworkNodeOwnerCapMismatch,
    );
    network_node_registry.add(
        network_node_record::new(
            clock.timestamp_ms(),
            object::id(current_owner),
            ctx.sender(),
            object::id(network_node),
            jump_fee,
            fee_recipient,
            ctx,
        ),
    );
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
