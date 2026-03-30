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
    // The address that should receive the jump fee for this gate
    fee_recipient: address,
    // Where the key is the update timestamp and the value is the new fee structure
    fee_history: FeeHistory,
}

/// Creates a new GateRecord
public(package) fun new(
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    jump_fee: u64,
    fee_recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): GateRecord {
    //TODO: must switch to management cap
    ERROR;
    GateRecord {
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        gate_id: gate_id,
        fee_recipient: fee_recipient,
        fee_history: fee_history::new(jump_fee, clock, ctx),
    }
}

/// Destroys a GateRecord
public(package) fun destroy(record: GateRecord) {
    let GateRecord {
        transferred_on: _,
        transferred_from_character_id: _,
        transferred_from_wallet_addr: _,
        gate_id: _,
        fee_recipient: _,
        fee_history: fee_history,
    } = record;
    fee_history.destroy();
}

/// Updates the fee associated with a Gate in a GateRecord
public(package) fun update_fee(
    record: &mut GateRecord,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
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

public(package) fun current_fee(record: &GateRecord, clock: &Clock): u64 {
    record.fee_history.current_fee(clock)
}

public(package) fun fee_recipient(record: &GateRecord): address {
    record.fee_recipient
}
