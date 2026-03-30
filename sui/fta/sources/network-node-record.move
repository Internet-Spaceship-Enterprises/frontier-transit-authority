module fta::network_node_record;

use fta::fee_history::{Self, FeeHistory};
use sui::clock::Clock;

public struct NetworkNodeRecord has store {
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    network_node_id: ID,
    // The address that should receive the jump fee for this gate
    fee_recipient: address,
    // Where the key is the update timestamp and the value is the new fee structure
    fee_history: FeeHistory,
}

public(package) fun new(
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    network_node_id: ID,
    jump_fee: u64,
    fee_recipient: address,
    clock: &Clock,
    ctx: &mut TxContext,
): NetworkNodeRecord {
    NetworkNodeRecord {
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        network_node_id: network_node_id,
        fee_recipient: fee_recipient,
        fee_history: fee_history::new(jump_fee, clock, ctx),
    }
}

/// Destroys a NetworkNodeRecord
public(package) fun destroy(record: NetworkNodeRecord) {
    let NetworkNodeRecord {
        transferred_on: _,
        transferred_from_character_id: _,
        transferred_from_wallet_addr: _,
        network_node_id: _,
        fee_recipient: _,
        fee_history: fee_history,
    } = record;
    fee_history.destroy();
}

public(package) fun transferred_on(record: &NetworkNodeRecord): &u64 {
    &record.transferred_on
}

public(package) fun transferred_from_character_id(record: &NetworkNodeRecord): &ID {
    &record.transferred_from_character_id
}

public(package) fun transferred_from_wallet_addr(record: &NetworkNodeRecord): &address {
    &record.transferred_from_wallet_addr
}

public(package) fun network_node_id(record: &NetworkNodeRecord): &ID {
    &record.network_node_id
}

public(package) fun current_fee(record: &NetworkNodeRecord, clock: &Clock): u64 {
    record.fee_history.current_fee(clock)
}

public(package) fun fee_recipient(record: &NetworkNodeRecord): address {
    record.fee_recipient
}
