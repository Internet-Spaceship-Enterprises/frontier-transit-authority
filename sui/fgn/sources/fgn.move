/*
/// Module: frontier_gate_network
module frontier_gate_network::frontier_gate_network;
*/
module fgn::fgn;

use sui::package::Publisher;
use sui::table::{Self, Table};
use sui::linked_table::{Self, LinkedTable};
use sui::transfer::Receiving;
use sui::clock::Clock;
use world:: {
    energy::EnergyConfig,
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
#[error(code = 3)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Gate Network";
#[error(code = 4)]
const EGateNotYours: vector<u8> = b"You cannot modify the fee for a gate you did not assign to FGN";
#[error(code = 5)]
const ENotEnoughNotice: vector<u8> = b"You have not provided enough notice for the fee change (takes_effect_on is too soon)";
#[error(code = 6)]
const EFeeChangePending: vector<u8> = b"You cannot schedule a fee change when there is already a fee change pending";
#[error(code = 7)]
const ENoFeeActive: vector<u8> = b"No jump fee is currently active";

// The minimum requirement for how long it takes for a new fee to take effect
const FEE_CHANGE_MINIMUM_NOTICE: u64 = 604800000; // 1 week
// The maximum fee percentage increase at a time
// This is in thousanths of a percent
const FEE_CHANGE_MAX_PERCENTAGE_THOUSANTHS: u64 = 20000; // 20%

/// The OTW for the module.
public struct FGN has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct Fee has store {
    // The fee, in EVE tokens
    jump_fee: u64,
    // The timestamp (milliseconds) when the fee takes effect
    takes_effect_on: u64,
    // The timestamp (milliseconds) when the new fee was submitted
    submitted_on: u64,
}

public struct GateRecord has store { 
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    gate_owner_cap_id: ID,
    network_node_id: ID,
    network_node_owner_cap_id: ID,
    // Where the key is the update timestamp and the value is the new fee structure
    fee_history: LinkedTable<u64, Fee>,
}

public struct FrontierGateNetwork has key {
    id: UID,
    // The key is the Gate ID, the value is the GateRecord
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
        gate_table: table::new<ID, GateRecord>(ctx),
    });
}

public fun transfer_gate(
    gate_network: &mut FrontierGateNetwork, 
    current_owner: &mut Character, 
    gate: &mut Gate, 
    gate_owner_cap: Receiving<OwnerCap<Gate>>,
    network_node: &mut NetworkNode, 
    network_node_owner_cap: Receiving<OwnerCap<NetworkNode>>, 
    jump_fee: u64,
    energy_config: &EnergyConfig,
    clock: &Clock,
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
    prepare_gate(gate, &borrowed_gate_owner_cap, network_node, &borrowed_network_owner_cap, energy_config, ctx);

    // Transfer the gate ownership to FGN
    access::transfer_owner_cap_with_receipt(borrowed_gate_owner_cap, gate_receipt, object::id_address(gate_network), ctx);
    // Transfer the network node ownership to FGN
    access::transfer_owner_cap_with_receipt(borrowed_network_owner_cap, network_receipt, object::id_address(gate_network), ctx);

    // Record the important values
    let mut record = GateRecord {
        transferred_on: clock.timestamp_ms(),
        transferred_from_character_id: object::id(current_owner),
        transferred_from_wallet_addr: ctx.sender(),
        gate_id: gate_id,
        gate_owner_cap_id: gate_owner_cap_id,
        network_node_id: nn_id,
        network_node_owner_cap_id: nn_owner_cap_id,
        fee_history: linked_table::new<u64, Fee>(ctx),
    };

    // Add the initial fee, taking effect immediately
    record.fee_history.push_back(clock.timestamp_ms(), Fee {
        takes_effect_on: clock.timestamp_ms(),
        submitted_on: clock.timestamp_ms(),
        jump_fee: jump_fee,
    });

    // Put the record in the table
    gate_network.gate_table.add(gate_id, record)
}

/// Prepares a gate for FGN operation
fun prepare_gate(
    gate: &mut Gate, 
    gate_owner_cap: &OwnerCap<Gate>,
    network_node: &mut NetworkNode, 
    network_node_owner_cap: &OwnerCap<NetworkNode>, 
    energy_config: &EnergyConfig,
    ctx: &mut TxContext
) {
    if(gate.is_online()) {
        gate.offline(network_node, energy_config, gate_owner_cap);
    };
    // TODO: set metadata name using the system/location
    gate.update_metadata_name(gate_owner_cap, b"Frontier Gate Network".to_string());
    // TODO: configure the authorization extension
}

public fun change_fee(
    gate_network: &mut FrontierGateNetwork, 
    gate_id: ID,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure that enough notice is given for the change
    assert!(takes_effect_on - clock.timestamp_ms() >= FEE_CHANGE_MINIMUM_NOTICE, ENotEnoughNotice);

    // Ensure the gate is actually part of the network
    assert!(gate_network.gate_table.contains(gate_id), EGateNotInNetwork);

    // Load the record
    let record = &mut gate_network.gate_table[gate_id];

    // Ensure the sender is the entity that previously owned the gate
    assert!(record.transferred_from_wallet_addr == ctx.sender(), EGateNotYours);

    // Get the key for the last fee modification
    let last_modified_key_option = record.fee_history.back();

    // Ensure a value was found (there should always be, since one is created in the init() function)
    assert!(option::is_some(last_modified_key_option), ENoFeeActive);

    // Get the latest change
    let latest_change = record.fee_history.borrow(*last_modified_key_option.borrow());
    
    // Ensure that the latest change is active, not pending.
    // This prevents scheduling a new change when the last change hasn't taken effect yet.
    assert!(latest_change.takes_effect_on <= clock.timestamp_ms(), EFeeChangePending);

    let diff = (jump_fee - latest_change.jump_fee);

    assert!((jump_fee - latest_change.jump_fee) * 100000 / latest_change.jump_fee <= FEE_CHANGE_MAX_PERCENTAGE_THOUSANTHS, EFeeIncreaseTooLarge);

    // Schedule the change
    record.fee_history.push_back(clock.timestamp_ms(), Fee {
        jump_fee: jump_fee,
        takes_effect_on: takes_effect_on,
        submitted_on: clock.timestamp_ms(),
    });
}

/// Retrieves the current per-jump fee (in EVE tokens) for a given gate
public fun current_fee(
    gate_network: &FrontierGateNetwork, 
    gate_id: ID,
    clock: &Clock,
): u64 {
    // Ensure the gate is actually part of the network
    assert!(gate_network.gate_table.contains(gate_id), EGateNotInNetwork);

    // Get the gate record
    let fee_history = &gate_network.gate_table[gate_id].fee_history;

    // Get the key for the last fee modification
    let last_modified_key_option = fee_history.back();

    // Ensure a value was found (there should always be, since one is created in the init() function)
    assert!(option::is_some(last_modified_key_option), ENoFeeActive);

    // Borrow the value from the option
    let latest_fee_key = *last_modified_key_option.borrow();

    // Get the latest change
    let latest_fee = fee_history.borrow(latest_fee_key);

    // If the latest fee is active, use it
    if(latest_fee.takes_effect_on <= clock.timestamp_ms()) {
        latest_fee.jump_fee
    } else {
        // Otherwise, get the previous fee, which MUST be active since we don't allow
        // setting a new fee while a fee change is pending.
        let prev_fee_key_option = fee_history.prev(latest_fee_key);
        assert!(option::is_some(prev_fee_key_option), ENoFeeActive);
        let prev_fee_key = *prev_fee_key_option.borrow();

        let prev_fee = fee_history.borrow(prev_fee_key);
        assert!(prev_fee.takes_effect_on <= clock.timestamp_ms(), ENoFeeActive);
        prev_fee.jump_fee
    }
}

public fun gate_count(
    gate_network: &FrontierGateNetwork, 
): u64 {
    gate_network.gate_table.length()
}