module fta::gate_registry;

use fta::datetime;
use fta::gate_record::{Self, GateRecord};
use fta::greek;
use fta::jump_auth::JumpAuth;
use fta::management_cap::ManagementCap;
use fta::network_node_registry::NetworkNodeRegistry;
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};
use world::access::{Self, OwnerCap, ReturnOwnerCapReceipt};
use world::character::Character;
use world::energy::EnergyConfig;
use world::gate::Gate;
use world::location::LocationRegistry;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> =
    b"This gate is not registered with the Frontier Transit Authority network";
#[error(code = 2)]
const EWrongManagementCap: vector<u8> = b"This management cap is not for the specified gate";
#[error(code = 3)]
const ELocationNotRevealed: vector<u8> =
    b"You cannot transfer a gate to FTA unless the location has been revealed (using the in-game UI)";
#[error(code = 4)]
const EGateOwnerCapMismatch: vector<u8> = b"OwnerCap<Gate> does not belong to this Gate";
#[error(code = 5)]
const EGatesNotLinked: vector<u8> = b"The two gates being transferred must be linked";
#[error(code = 6)]
const EWrongNetworkNode: vector<u8> =
    b"The NetworkNode provided is not the correct one for this Gate";
#[error(code = 7)]
const EGateHasNoNetworkNode: vector<u8> =
    b"A gate cannot be transferred to FTA if it is not connected to a network node";
#[error(code = 8)]
const EDifferentNetworkNodes: vector<u8> =
    b"If using the `transfer_gate_pair_same_network_node` function, both gates must be linked to the same network node";
#[error(code = 9)]
const EWrongCharacter: vector<u8> = b"The provided character is not yours";
#[error(code = 10)]
const ENetworkNodeNotRegistered: vector<u8> =
    b"A gate cannot be transferred to FTA if its network node is not already registered with FTA";
#[error(code = 11)]
const EGateAlreadyRegistered: vector<u8> = b"This gate is already registered";

public struct GateRegistry has store {
    // Maps gate ID to gate record
    table: LinkedTable<ID, GateRecord>,
}

public(package) fun new(ctx: &mut TxContext): GateRegistry {
    GateRegistry {
        table: linked_table::new<ID, GateRecord>(ctx),
    }
}

public(package) fun registered(registry: &GateRegistry, gate: &Gate): bool {
    registry.registered_by_id(object::id(gate))
}

public(package) fun registered_by_id(registry: &GateRegistry, gate_id: ID): bool {
    registry.table.contains(gate_id)
}

public(package) fun registered_by_record(registry: &GateRegistry, record: &GateRecord): bool {
    registry.registered_by_id(record.gate_id())
}

public(package) fun get(registry: &GateRegistry, gate: &Gate): &GateRecord {
    registry.get_by_id(object::id(gate))
}

public(package) fun get_mut(registry: &mut GateRegistry, gate: &Gate): &mut GateRecord {
    registry.get_by_id_mut(object::id(gate))
}

public(package) fun get_by_id(registry: &GateRegistry, gate_id: ID): &GateRecord {
    assert!(registry.registered_by_id(gate_id), EGateNotInNetwork);
    registry.table.borrow(gate_id)
}

public(package) fun get_by_id_mut(registry: &mut GateRegistry, gate_id: ID): &mut GateRecord {
    assert!(registry.registered_by_id(gate_id), EGateNotInNetwork);
    registry.table.borrow_mut(gate_id)
}

fun transfer_gate_pair_validation(gate_1: &Gate, gate_2: &Gate) {
    // Ensure the gates are bi-directionally linked
    assert!(
        gate_1.linked_gate_id().is_some() && gate_1.linked_gate_id().borrow() == object::id(gate_2),
        EGatesNotLinked,
    );
    assert!(
        gate_2.linked_gate_id().is_some() && gate_2.linked_gate_id().borrow() == object::id(gate_1),
        EGatesNotLinked,
    );

    // Ensure the gates both have a network node
    assert!(
        gate_1.energy_source_id().is_some() && gate_2.energy_source_id().is_some(),
        EGateHasNoNetworkNode,
    );
}

fun transfer_gate(
    gate_registry: &mut GateRegistry,
    fta_address: address,
    network_node_registry: &NetworkNodeRegistry,
    current_owner: &Character,
    gate: &mut Gate,
    gate_owner_cap: OwnerCap<Gate>,
    gate_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    jump_fee: u64,
    fee_recipient: address,
    transferred_timestamp: u64,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
    ctx: &mut TxContext,
) {
    // Ensure the gate isn't already registered
    assert!(!gate_registry.registered(gate), EGateAlreadyRegistered);
    // Ensure the location has been revealed, since we can't do it afterwards
    assert!(location_registry.get_location(object::id(gate)).is_some(), ELocationNotRevealed);

    // Ensure the provided character is correct
    assert!(current_owner.character_address() == ctx.sender(), EWrongCharacter);

    // Ensure the correct network node was provided
    assert!(gate.energy_source_id().borrow() == object::id(network_node), EWrongNetworkNode);

    // Ensure the gate owner cap provided is the right one for the gate
    assert!(gate_owner_cap.is_authorized(object::id(gate)), EGateOwnerCapMismatch);
    assert!(gate.owner_cap_id() == object::id(&gate_owner_cap), EGateOwnerCapMismatch);

    // Ensure the gate is linked, since we can't link it after it's been transferred
    assert!(!gate.linked_gate_id().is_none(), EGatesNotLinked);

    // Ensure that the associated network node is already registered
    assert!(network_node_registry.registered(network_node), ENetworkNodeNotRegistered);

    // If the gate is currently offline, bring it online
    if (!gate.is_online()) {
        gate.online(network_node, energy_config, &gate_owner_cap);
    };

    // Record the important values
    let record = gate_record::new(
        transferred_timestamp,
        object::id(current_owner),
        ctx.sender(),
        object::id(gate),
        jump_fee,
        fee_recipient,
        ctx,
    );
    // Put the record in the registry
    gate_registry.table.push_back(record.gate_id(), record);

    // Update the gate metadata
    gate_registry.update_gate_metadata(gate, &gate_owner_cap, location_registry);

    // Authorize the JumpAuth extension for FTA to be able to issue jump permits
    gate.authorize_extension<JumpAuth>(&gate_owner_cap);

    // Transfer the gate ownership to FTA
    gate_owner_cap.transfer_owner_cap_with_receipt(
        gate_owner_cap_receipt,
        fta_address,
        ctx,
    );
}

public(package) fun transfer_gate_pair_same_network_node(
    gate_registry: &mut GateRegistry,
    fta_address: address,
    network_node_registry: &NetworkNodeRegistry,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node: &mut NetworkNode,
    jump_fee_1: u64,
    fee_recipient_1: address,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    jump_fee_2: u64,
    fee_recipient_2: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer_gate_pair_validation(gate_1, gate_2);

    // This function can only be used if both gates share the same network node
    assert!(
        gate_1.energy_source_id().borrow() == gate_2.energy_source_id().borrow(),
        EDifferentNetworkNodes,
    );

    let transferred_timestamp = clock.timestamp_ms();

    gate_registry.transfer_gate(
        fta_address,
        network_node_registry,
        current_owner,
        gate_1,
        gate_1_owner_cap,
        gate_1_owner_cap_receipt,
        network_node,
        jump_fee_1,
        fee_recipient_1,
        transferred_timestamp,
        energy_config,
        location_registry,
        ctx,
    );

    gate_registry.transfer_gate(
        fta_address,
        network_node_registry,
        current_owner,
        gate_2,
        gate_2_owner_cap,
        gate_2_owner_cap_receipt,
        network_node,
        jump_fee_2,
        fee_recipient_2,
        transferred_timestamp,
        energy_config,
        location_registry,
        ctx,
    );
}

public(package) fun transfer_gate_pair(
    gate_registry: &mut GateRegistry,
    fta_address: address,
    network_node_registry: &NetworkNodeRegistry,
    current_owner: &Character,
    gate_1: &mut Gate,
    gate_1_owner_cap: OwnerCap<Gate>,
    gate_1_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_1: &mut NetworkNode,
    jump_fee_1: u64,
    fee_recipient_1: address,
    gate_2: &mut Gate,
    gate_2_owner_cap: OwnerCap<Gate>,
    gate_2_owner_cap_receipt: ReturnOwnerCapReceipt,
    network_node_2: &mut NetworkNode,
    jump_fee_2: u64,
    fee_recipient_2: address,
    energy_config: &EnergyConfig,
    location_registry: &LocationRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    transfer_gate_pair_validation(gate_1, gate_2);

    let transferred_timestamp = clock.timestamp_ms();

    gate_registry.transfer_gate(
        fta_address,
        network_node_registry,
        current_owner,
        gate_1,
        gate_1_owner_cap,
        gate_1_owner_cap_receipt,
        network_node_1,
        jump_fee_1,
        fee_recipient_1,
        transferred_timestamp,
        energy_config,
        location_registry,
        ctx,
    );

    gate_registry.transfer_gate(
        fta_address,
        network_node_registry,
        current_owner,
        gate_2,
        gate_2_owner_cap,
        gate_2_owner_cap_receipt,
        network_node_2,
        jump_fee_2,
        fee_recipient_2,
        transferred_timestamp,
        energy_config,
        location_registry,
        ctx,
    );
}

/// Removes a gate from the registry and transfers ownership back to whoever holds
/// the management cap
public(package) fun deregister(
    registry: &mut GateRegistry,
    gate: &mut Gate,
    owner_cap: OwnerCap<Gate>,
) {
    let record = registry.get(gate);
    let owner_addr = record.management_cap_owner_address();

    // Remove the extension from the gate
    gate.revoke_extension_authorization(&owner_cap);
    registry.table.remove(object::id(gate)).destroy();

    // Send the OwnerCap to the entity that holds the ManagementCap
    access::transfer_owner_cap(owner_cap, owner_addr);
}

/// Process the destruction of a gate
public(package) fun destroyed(registry: &mut GateRegistry, gate_id: ID) {
    assert!(registry.registered_by_id(gate_id), EGateNotInNetwork);
    registry.table.remove(gate_id).destroy();
    // Since it's destroyed, we don't need to deregister the extension
    // and there's nothing to transfer the ownership of
}

// Returns a list of the IDs of all gates managed by the FTA
public(package) fun managed_gate_ids(registry: &GateRegistry): vector<ID> {
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

/// Prepares a gate for FTA operation
public(package) fun update_gate_metadata(
    gate_registry: &GateRegistry,
    gate: &mut Gate,
    gate_owner_cap: &OwnerCap<Gate>,
    location_registry: &LocationRegistry,
) {
    let record = gate_registry.get(gate);

    let location_opt = location_registry.get_location(object::id(gate));
    assert!(location_opt.is_some(), ELocationNotRevealed);
    let location = location_opt.borrow();
    let mut coords = b"(".to_string();
    coords.append(location.x());
    coords.append(b", ".to_string());
    coords.append(location.y());
    coords.append(b", ".to_string());
    coords.append(location.z());
    coords.append(b")".to_string());

    let mut name = b"Frontier Transit Authority - ".to_string();
    name.append(std::u64::to_string(location.solarsystem()));
    name.append(b" ".to_string());

    let hash = gate.location().hash();
    let mut i = 0;
    let mut sum = 0u64;
    while (i < hash.length()) {
        sum = sum + (*hash.borrow(i) as u64);
        i = i + 1;
    };
    name.append(greek::lookup(sum % greek::max(3), 3));

    let mut description = b"Solar System: ".to_string();
    description.append(std::u64::to_string(location.solarsystem()));
    description.append(b"\nCoordinates: \n\tX: ".to_string());
    description.append(location.x());
    description.append(b"\n\tY: ".to_string());
    description.append(location.y());
    description.append(b"\n\tZ: ".to_string());
    description.append(location.z());
    description.append(b"\n\nRegistered: ".to_string());
    description.append(datetime::datetime_from_timestamp_ms(record.transferred_on()));

    gate.update_metadata_name(gate_owner_cap, name);
    gate.update_metadata_description(gate_owner_cap, description);

    let mut url = b"http://localhost:5173?objectId=0x".to_string(); // TODO: update with the real URL
    url.append(object::id(gate).to_address().to_string());
    gate.update_metadata_url(gate_owner_cap, url);
}

/// Onlines or Offlines an FTA gate if it's not already online
public(package) fun change_gate_online(
    gate_registry: &GateRegistry,
    network_node_registry: &NetworkNodeRegistry,
    gate: &mut Gate,
    gate_owner_cap: &OwnerCap<Gate>,
    network_node: &mut NetworkNode,
    online: bool,
    energy_config: &EnergyConfig,
) {
    assert!(gate_registry.registered(gate), EGateNotInNetwork);
    assert!(gate.energy_source_id().is_some(), EGateHasNoNetworkNode);
    assert!(
        network_node_registry.registered_by_id(*gate.energy_source_id().borrow()),
        ENetworkNodeNotRegistered,
    );
    if (gate.is_online() != online) {
        if (online) {
            gate.online(network_node, energy_config, gate_owner_cap);
        } else {
            gate.offline(network_node, energy_config, gate_owner_cap);
        };
    }
}

// Transfers a management cap for a gate to a new owner and updates the gate record to reflect the new owner
public(package) fun transfer_management_cap(
    registry: &mut GateRegistry,
    gate: &Gate,
    cap: ManagementCap<Gate>,
    new_owner: address,
) {
    // Ensure this is the management cap for the gate
    assert!(cap.authorized_object_id() == object::id(gate), EWrongManagementCap);
    let record = registry.get_mut(gate);
    record.set_management_cap_owner_address(new_owner);
    cap.transfer(new_owner);
}
