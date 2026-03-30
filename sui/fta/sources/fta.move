/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use assets::EVE::EVE;
use fta::constants;
use fta::gate_table::{Self, GateTable};
use fta::network_node_record::NetworkNodeRecord;
use sui::balance::{Self, Balance};
use sui::dynamic_field as df;
use sui::linked_table::{Self, LinkedTable};
use sui::package::Publisher;
use world::character::Character;
use world::gate::Gate;
use world::network_node::NetworkNode;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const ELinkedGateNotInNetwork: vector<u8> =
    b"The gate linked to this gate is not part of the Frontier Transit Authority";
#[error(code = 3)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";
#[error(code = 4)]
const EGateHasNoNetworkNode: vector<u8> =
    b"The gate does not have a network node (it may have been destroyed)";
#[error(code = 5)]
const EOwnerCharacterNotSet: vector<u8> = b"The owner character dynamic field has not been set";
#[error(code = 6)]
const ENetworkNodeNotRegistered: vector<u8> =
    b"The network node is not registered with the Frontier Transit Authority";
#[error(code = 7)]
const EGateNetworkNodeNotRegistered: vector<u8> =
    b"The network node for this gate is not registered with the Frontier Transit Authority";

/// The OTW for the module.
public struct FTA has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct FrontierTransitAuthority has key {
    id: UID,
    deployer_addr: address,
    // The key is the Gate ID, the value is the GateRecord
    gate_table: GateTable,
    network_node_table: LinkedTable<ID, NetworkNodeRecord>,
    // The balance of the bounty account (for paying bounties)
    bounty_balance: Balance<EVE>,
    // The balance of the developer account (to fund development efforts and Sui transaction fees)
    developer_balance: Balance<EVE>,
}

// Called only once, upon module publication. It must be
// private to prevent external invocation.
fun init(otw: FTA, ctx: &mut TxContext) {
    // Claim the Publisher object.
    let publisher: Publisher = sui::package::claim(otw, ctx);

    // Transfer it to the publisher address
    transfer::public_transfer(publisher, ctx.sender());

    // Transfers the DeveloperCap to the sender (publisher).
    transfer::transfer(
        DeveloperCap {
            id: object::new(ctx),
        },
        ctx.sender(),
    );

    // Create the Transit Authority object and make it shared
    // TODO: should this use a OTW?
    transfer::share_object(FrontierTransitAuthority {
        id: object::new(ctx),
        deployer_addr: ctx.sender(),
        gate_table: gate_table::new(ctx),
        network_node_table: linked_table::new<ID, NetworkNodeRecord>(ctx),
        bounty_balance: balance::zero(),
        developer_balance: balance::zero(),
    });
}

// Configures the character that should own the gates
// TODO: once there's a way to receive the OwnerCap<Gate> without it needing to be owned by a character,
// switch this to the shared object so only approved operations in the contract can use it.
public fun set_owner_character(
    fta: &mut FrontierTransitAuthority,
    _: &DeveloperCap,
    character: &mut Character,
    ctx: &TxContext,
) {
    assert!(ctx.sender() == fta.deployer_addr);
    assert!(character.character_address() == ctx.sender());
    df::add(&mut fta.id, constants::owner_character_field_name(), object::id(character));
}

// Gets the ID of the character that holds gate ownership
public fun get_owner_character(fta: &FrontierTransitAuthority): ID {
    assert!(df::exists_(&fta.id, constants::owner_character_field_name()), EOwnerCharacterNotSet);
    *df::borrow(&fta.id, constants::owner_character_field_name())
}

/// Asserts that a gate is valid for jump or update operations
public(package) fun check_gate_validity(fta: &FrontierTransitAuthority, gate: &Gate) {
    let linked_gate_id_opt = gate.linked_gate_id();
    // Ensure the gate is linked to another gate
    assert!(linked_gate_id_opt.is_some(), ENoLinkedGate);
    let linked_gate_id = linked_gate_id_opt.borrow();
    // Ensure this gate is in the network
    assert!(fta.gate_table.gate_registered(gate), EGateNotInNetwork);
    // Ensure the linked gate is in the network
    assert!(fta.gate_table.gate_registered_by_id(*linked_gate_id), ELinkedGateNotInNetwork);
    // Ensure the network node for this gate is registered
    assert!(
        fta.network_node_table.contains(*gate.energy_source_id().borrow()),
        EGateNetworkNodeNotRegistered,
    );
}

public(package) fun gate_table(fta: &FrontierTransitAuthority): &GateTable {
    &fta.gate_table
}

public(package) fun gate_table_mut(fta: &mut FrontierTransitAuthority): &mut GateTable {
    &mut fta.gate_table
}

public(package) fun network_node_table(
    fta: &FrontierTransitAuthority,
): &LinkedTable<ID, NetworkNodeRecord> {
    &fta.network_node_table
}

public(package) fun bounty_balance(fta: &mut FrontierTransitAuthority): &mut Balance<EVE> {
    &mut fta.bounty_balance
}

public(package) fun developer_balance(fta: &mut FrontierTransitAuthority): &mut Balance<EVE> {
    &mut fta.developer_balance
}

public(package) fun add_network_node_record(
    fta: &mut FrontierTransitAuthority,
    record: NetworkNodeRecord,
) {
    fta.network_node_table.push_back(record.network_node_id(), record);
}

public(package) fun get_network_node_record(
    fta: &FrontierTransitAuthority,
    network_node: &NetworkNode,
): &NetworkNodeRecord {
    assert!(fta.network_node_table.contains(object::id(network_node)), ENetworkNodeNotRegistered);
    fta.network_node_table.borrow(object::id(network_node))
}

public(package) fun get_network_node_record_mut(
    fta: &mut FrontierTransitAuthority,
    network_node: &NetworkNode,
): &mut NetworkNodeRecord {
    assert!(fta.network_node_table.contains(object::id(network_node)), ENetworkNodeNotRegistered);
    fta.network_node_table.borrow_mut(object::id(network_node))
}

public(package) fun get_network_node_record_for_gate(
    fta: &FrontierTransitAuthority,
    gate: &Gate,
): &NetworkNodeRecord {
    let energy_source_id_opt = gate.energy_source_id();
    assert!(energy_source_id_opt.is_some(), EGateHasNoNetworkNode);
    let network_node_id = *energy_source_id_opt.borrow();
    assert!(fta.network_node_table.contains(network_node_id), ENetworkNodeNotRegistered);
    fta.network_node_table.borrow(network_node_id)
}

public(package) fun network_node_registered(
    fta: &FrontierTransitAuthority,
    network_node: &NetworkNode,
): bool {
    fta.network_node_table.contains(object::id(network_node))
}

// public fun gate_registered(fta: &FrontierTransitAuthority, gate: &Gate): bool {
//     fta.gate_table().gate_registered(gate)
// }

public fun gate_network_node_registered(fta: &FrontierTransitAuthority, gate: &Gate): bool {
    let energy_source_id_opt = gate.energy_source_id();
    assert!(energy_source_id_opt.is_some(), EGateHasNoNetworkNode);
    fta.network_node_table.contains(*energy_source_id_opt.borrow())
}
