/*
/// Module: frontier_gate_network
module frontier_gate_network::frontier_gate_network;
*/
module fgn::fgn;

use sui::package::{Publisher};
use sui::table::{Self, Table};
use sui::transfer::Receiving;
use world:: {
    gate::{Self, Gate},
    access::{Self, OwnerCap},
    character::{Self, Character},
    network_node::{Self, NetworkNode},
};

#[error(code = 0)]
const EGateOwnerCapMismatch: vector<u8> = b"OwnerCap<Gate> does not belong to this Gate";
#[error(code = 1)]
const ENetworkNodeOwnerCapMismatch: vector<u8> = b"OwnerCap<NetworkNode> does not belong to this NetworkNode";
#[error(code = 2)]
const EGateLinked: vector<u8> = b"To transfer a gate to FGN, the gate cannot be linked";

/// The OTW for the module.
public struct FGN has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct GateRecord has store { 
    transferred_from_character_id: ID,
    gate_id: ID,
    gate_owner_cap_id: ID,
    network_node_id: ID,
    network_node_owner_cap_id: ID,
}

public struct FrontierGateNetwork has key {
    id: UID,
    gate_table: Table<ID, GateRecord>,
}

// Called only once, upon module publication. It must be
// private to prevent external invocation.
fun init(otw: FGN, ctx: &mut TxContext) {
    // Claim the Publisher object.
    let publisher: Publisher = sui::package::claim(otw, ctx);

    // Transfer it to the publisher address
    transfer::public_transfer(publisher, ctx.sender());

    // Transfers the DeveloperCap to the sender (publisher).
    transfer::transfer(DeveloperCap {
        id: object::new(ctx)
    }, ctx.sender());

    // Create the Gate Network object and make it shared
    // TODO: should this use a OTW?
    transfer::share_object(FrontierGateNetwork {
        id: object::new(ctx),
        gate_table: table::new<ID, GateRecord>(ctx)
    });
}

public fun transfer_gate(
    gate_network: &mut FrontierGateNetwork, 
    current_owner: &mut Character, 
    gate: &mut Gate, 
    gate_owner_cap: Receiving<OwnerCap<Gate>>,
    network_node: &mut NetworkNode, 
    network_node_owner_cap: Receiving<OwnerCap<NetworkNode>>, 
    ctx: &mut TxContext
) {
    // Ensure the gate is not linked, because we won't be able to unlink it if we
    // don't own the other side.
    assert!(gate.linked_gate_id().is_none(), EGateLinked);

    // Borrow the owner cap for the gate
    let (borrowed_gate_owner_cap, gate_receipt) = character::borrow_owner_cap<Gate>(current_owner, gate_owner_cap, ctx);
    let gate_id = object::id(gate);
    let gate_owner_cap_id = object::id(&borrowed_gate_owner_cap);
    // Run some access checks to ensure this is the right owner cap for this gate
    assert!(access::is_authorized(&borrowed_gate_owner_cap, gate_id), EGateOwnerCapMismatch);
    assert!(gate::owner_cap_id(gate) == gate_owner_cap_id, EGateOwnerCapMismatch);

    // Borrow the owner cap for the network node
    let (borrowed_network_owner_cap, network_receipt) = character::borrow_owner_cap<NetworkNode>(current_owner, network_node_owner_cap, ctx);
    let nn_id = object::id(network_node);
    let nn_owner_cap_id = object::id(&borrowed_network_owner_cap);
    // Run some access checks to ensure this is the right owner cap for this network node
    assert!(access::is_authorized(&borrowed_network_owner_cap, nn_id), ENetworkNodeOwnerCapMismatch);
    assert!(network_node::owner_cap_id(network_node) == nn_owner_cap_id, ENetworkNodeOwnerCapMismatch);
    
    // Use the borrowed owner cap to prepare the gate
    // prepare_gate(gate, &borrowed_gate_owner_cap, gate_network,ctx);

    // Transfer the gate ownership to FGN
    access::transfer_owner_cap_with_receipt(borrowed_gate_owner_cap, gate_receipt, object::id_address(gate_network), ctx);
    // Transfer the network node ownership to FGN
    access::transfer_owner_cap_with_receipt(borrowed_network_owner_cap, network_receipt, object::id_address(gate_network), ctx);

    // Record the important values
    let record = GateRecord {
        transferred_from_character_id: object::id(current_owner),
        gate_id: gate_id,
        gate_owner_cap_id: gate_owner_cap_id,
        network_node_id: nn_id,
        network_node_owner_cap_id: nn_owner_cap_id,
    };
    // Put it in a table
    gate_network.gate_table.add(gate_id, record)
}

// /// Prepares a gate for FGN operation
// fun prepare_gate(
//     gate_network: &mut FrontierGateNetwork,
//     gate: &mut Gate, 
//     gate_owner_cap: &OwnerCap<Gate>>,
//     network_node: &mut NetworkNode, 
//     network_node_owner_cap: &OwnerCap<NetworkNode>, 
//     ctx: &mut TxContext
// ) {
//     gate::offline(gate, )
// }