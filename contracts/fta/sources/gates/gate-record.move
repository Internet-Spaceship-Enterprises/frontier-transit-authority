module fta::gate_record;

use fta::fee_history::{Self, FeeHistory};
use fta::management_cap;
use sui::clock::Clock;
use world::gate::Gate;

public struct GateRecord has store {
    object_registration_id: ID,
    management_cap_id: ID,
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    linked_gate_id: ID,
    // The address that should receive the jump fee for this gate
    fee_recipient: address,
    // Where the key is the update timestamp and the value is the new fee structure
    fee_history: FeeHistory,
    // Tracks who holds the management cap
    management_cap_owner_address: address,
}

/// Creates a new GateRecord
public(package) fun new(
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    gate_id: ID,
    linked_gate_id: ID,
    jump_fee: u64,
    fee_recipient: address,
    ctx: &mut TxContext,
): GateRecord {
    // Create a management cap for this network node
    let object_registration_id = ctx.fresh_object_address().to_id();
    let cap = management_cap::new<Gate>(gate_id, object_registration_id, ctx);
    // Prepare the record
    let record = GateRecord {
        object_registration_id: object_registration_id,
        management_cap_id: object::id(&cap),
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        gate_id: gate_id,
        linked_gate_id: linked_gate_id,
        fee_recipient: fee_recipient,
        fee_history: fee_history::new(jump_fee, transferred_on, ctx),
        management_cap_owner_address: transferred_from_character_id.to_address(),
    };
    // Transfer the management cap to the original owner character
    cap.transfer(record.management_cap_owner_address);
    record
}

/// Destroys a GateRecord
public(package) fun destroy(record: GateRecord) {
    let GateRecord {
        object_registration_id: _,
        management_cap_id: _,
        transferred_on: _,
        transferred_from_character_id: _,
        transferred_from_wallet_addr: _,
        gate_id: _,
        linked_gate_id: _,
        fee_recipient: _,
        fee_history: fee_history,
        management_cap_owner_address: _,
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

/// Updates the recipient for fees paid to jump through this gate
public(package) fun update_fee_recipient(record: &mut GateRecord, recipient: address) {
    record.fee_recipient = recipient;
}

public(package) fun object_registration_id(record: &GateRecord): ID {
    record.object_registration_id
}

public(package) fun management_cap_id(record: &GateRecord): ID {
    record.management_cap_id
}

public(package) fun transferred_on(record: &GateRecord): u64 {
    record.transferred_on
}

public(package) fun transferred_from_character_id(record: &GateRecord): ID {
    record.transferred_from_character_id
}

public(package) fun transferred_from_wallet_addr(record: &GateRecord): address {
    record.transferred_from_wallet_addr
}

public(package) fun gate_id(record: &GateRecord): ID {
    record.gate_id
}

public(package) fun linked_gate_id(record: &GateRecord): ID {
    record.linked_gate_id
}

public(package) fun current_fee(record: &GateRecord, clock: &Clock): u64 {
    record.fee_history.current_fee(clock)
}

public(package) fun fee_recipient(record: &GateRecord): address {
    record.fee_recipient
}

public(package) fun management_cap_owner_address(record: &GateRecord): address {
    record.management_cap_owner_address
}

public(package) fun set_management_cap_owner_address(
    record: &mut GateRecord,
    owner_address: address,
) {
    record.management_cap_owner_address = owner_address;
}
