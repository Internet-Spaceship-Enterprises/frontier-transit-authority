/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use fta::gate_record::GateRecord;
use fta::network_node_record::NetworkNodeRecord;
use sui::dynamic_field as df;
use sui::package::Publisher;
use sui::table::{Self, Table};
use world::character::Character;
use world::gate::Gate;

#[error(code = 0)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 1)]
const ELinkedGateNotInNetwork: vector<u8> =
    b"The gate linked to this gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";
#[error(code = 3)]
const EGateHasNoNetworkNode: vector<u8> =
    b"The gate does not have a network node (it may have been destroyed)";
#[error(code = 4)]
const EOwnerCharacterNotSet: vector<u8> = b"The owner character dynamic field has not been set";

/// The OTW for the module.
public struct FTA has drop {}

const OWNER_CHARACTER_FIELD_NAME: vector<u8> = b"owner_character";

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct FrontierTransitAuthority has key {
    id: UID,
    deployer_addr: address,
    // The key is the Gate ID, the value is the GateRecord
    gate_table: Table<ID, GateRecord>,
    network_node_table: Table<ID, NetworkNodeRecord>,
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
        gate_table: table::new<ID, GateRecord>(ctx),
        network_node_table: table::new<ID, NetworkNodeRecord>(ctx),
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
    df::add(&mut fta.id, OWNER_CHARACTER_FIELD_NAME, object::id(character));
}

// Gets the ID of the character that holds gate ownership
public fun get_owner_character(fta: &FrontierTransitAuthority): ID {
    assert!(df::exists_(&fta.id, OWNER_CHARACTER_FIELD_NAME), EOwnerCharacterNotSet);
    *df::borrow(&fta.id, b"owner_character")
}

// public(package) fun get_gate_pair_hash(fta: &FrontierTransitAuthority, gate: &Gate): vector<u8> {
//     let gate_id = object::id(gate);
//     let linked_gate_id_opt = gate.linked_gate_id();
//     assert!(linked_gate_id_opt.is_some(), ENoLinkedGate);
//     let linked_gate_id = linked_gate_id_opt.borrow();
//     let key = gate_pair_hash(&gate_id, linked_gate_id);
//     assert!(fta.gate_table.contains(key), EGateNotInNetwork);
//     key
// }

fun check_gate_validity(fta: &FrontierTransitAuthority, gate: &Gate, ctx: &TxContext) {
    let gate_id = object::id(gate);
    let linked_gate_id_opt = gate.linked_gate_id();
    assert!(linked_gate_id_opt.is_some(), ENoLinkedGate);
    let linked_gate_id = linked_gate_id_opt.borrow();
    assert!(fta.gate_table.contains(gate_id), EGateNotInNetwork);
    assert!(fta.gate_table.contains(*linked_gate_id), ELinkedGateNotInNetwork);
    assert!(fta.gate_table.borrow(gate_id).transferred_from_wallet_addr() == ctx.sender())
}

public(package) fun get_gate_record(
    fta: &FrontierTransitAuthority,
    gate: &Gate,
    ctx: &TxContext,
): &GateRecord {
    check_gate_validity(fta, gate, ctx);
    fta.gate_table.borrow(object::id(gate))
}

public(package) fun get_gate_record_mut(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    ctx: &TxContext,
): &mut GateRecord {
    check_gate_validity(fta, gate, ctx);
    fta.gate_table.borrow_mut(object::id(gate))
}

public(package) fun gate_table(fta: &FrontierTransitAuthority): &Table<ID, GateRecord> {
    &fta.gate_table
}

public(package) fun network_node_table(
    fta: &FrontierTransitAuthority,
): &Table<ID, NetworkNodeRecord> {
    &fta.network_node_table
}

public(package) fun add_gate_record(fta: &mut FrontierTransitAuthority, record: GateRecord) {
    fta.gate_table.add(*record.gate_id(), record);
}

public(package) fun add_network_node_record(
    fta: &mut FrontierTransitAuthority,
    record: NetworkNodeRecord,
) {
    fta.network_node_table.add(*record.network_node_id(), record);
}

// Returns a unique key for a pair of gates, regardless of the order in which they are given
// public(package) fun gate_pair_hash(gate_a_id: &ID, gate_b_id: &ID): vector<u8> {
//     let mut a_addr_bytes = object::id_to_bytes(gate_a_id);
//     let mut b_addr_bytes = object::id_to_bytes(gate_b_id);
//     let a_int = bcs::peel_u256(&mut bcs::new(a_addr_bytes));
//     let b_int = bcs::peel_u256(&mut bcs::new(b_addr_bytes));

//     if (a_int > b_int) {
//         a_addr_bytes.append(b_addr_bytes);
//         hash::sha3_256(a_addr_bytes)
//     } else {
//         b_addr_bytes.append(a_addr_bytes);
//         hash::sha3_256(b_addr_bytes)
//     }
// }

public fun gate_registered(fta: &FrontierTransitAuthority, gate: &Gate): bool {
    fta.gate_table.contains(object::id(gate))
}

public fun gate_count(fta: &FrontierTransitAuthority): u64 {
    fta.gate_table.length()
}

// Gets the fee to jump through a gate, which is the sum of the fee set on each gate
public fun jump_fee(fta: &FrontierTransitAuthority, gate: &Gate, ctx: &TxContext): u64 {
    fta.check_gate_validity(gate, ctx);
    let linked_gate_id = gate.linked_gate_id().borrow();
    fta.gate_table[object::id(gate)].current_fee() + fta.gate_table[*linked_gate_id].current_fee()
}

public fun gate_network_node_registered(fta: &FrontierTransitAuthority, gate: &Gate): bool {
    let energy_source_id_opt = gate.energy_source_id();
    assert!(energy_source_id_opt.is_some(), EGateHasNoNetworkNode);
    fta.network_node_table.contains(*energy_source_id_opt.borrow())
}
