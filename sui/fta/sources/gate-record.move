module fta::gate_record;

use fta::fee_history::{Self, FeeHistory};
use sui::clock::Clock;

#[error(code = 1)]
const EGateNotYours: vector<u8> =
    b"You cannot modify the configuration for a gate you did not assign to FTA";

public struct GateRecord has store {
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    gate_owner_cap_id: ID,
    network_node_id: Option<ID>,
    network_node_owner_cap_id: Option<ID>,
    // Where the key is the update timestamp and the value is the new fee structure
    fee_history: FeeHistory,
}

public(package) fun new(
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    gate_owner_cap_id: ID,
    network_node_id: Option<ID>,
    network_node_owner_cap_id: Option<ID>,
    jump_fee: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): GateRecord {
    GateRecord {
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        gate_id: gate_id,
        gate_owner_cap_id: gate_owner_cap_id,
        network_node_id: network_node_id,
        network_node_owner_cap_id: network_node_owner_cap_id,
        fee_history: fee_history::new(jump_fee, clock, ctx),
    }
}

public(package) fun update_fee(
    record: &mut GateRecord,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
    ctx: &TxContext,
) {
    assert!(record.transferred_from_wallet_addr == ctx.sender(), EGateNotYours);
    record.fee_history.update_fee(jump_fee, takes_effect_on, clock);
}

public(package) fun transferred_on(record: &GateRecord): &u64 {
    &record.transferred_on
}

public(package) fun transferred_from_character_id(record: &GateRecord): &ID {
    &record.transferred_from_character_id
}

public(package) fun transferred_from_wallet_addr(record: &GateRecord): &address {
    &record.transferred_from_wallet_addr
}

public(package) fun gate_id(record: &GateRecord): &ID {
    &record.gate_id
}

public(package) fun gate_owner_cap_id(record: &GateRecord): &ID {
    &record.gate_owner_cap_id
}

public(package) fun network_node_a_id(record: &GateRecord): &Option<ID> {
    &record.network_node_id
}

public(package) fun network_node_owner_cap_id(record: &GateRecord): &Option<ID> {
    &record.network_node_owner_cap_id
}

public(package) fun current_fee(record: &GateRecord): u64 {
    record.current_fee()
}
