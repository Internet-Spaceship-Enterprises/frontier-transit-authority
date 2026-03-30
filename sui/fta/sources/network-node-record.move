module fta::network_node_record;

use fta::fee_history::{Self, FeeHistory};
use fta::management_cap;
use sui::clock::Clock;
use world::network_node::NetworkNode;

#[error(code = 1)]
const ENetworkNodeNotYours: vector<u8> =
    b"You cannot modify the configuration for a network node you did not assign to FTA";

public struct NetworkNodeRecord has store {
    management_cap_id: ID,
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
    // Create a management cap for this network node and transfer it to the original owner character
    let cap = management_cap::new<NetworkNode>(network_node_id, ctx);
    let record = NetworkNodeRecord {
        management_cap_id: object::id(&cap),
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        network_node_id: network_node_id,
        fee_recipient: fee_recipient,
        fee_history: fee_history::new(jump_fee, clock, ctx),
    };
    cap.transfer_management_cap(transferred_from_character_id.to_address());
    record
}

/// Destroys a NetworkNodeRecord
public(package) fun destroy(record: NetworkNodeRecord) {
    let NetworkNodeRecord {
        management_cap_id: _,
        transferred_on: _,
        transferred_from_character_id: _,
        transferred_from_wallet_addr: _,
        network_node_id: _,
        fee_recipient: _,
        fee_history: fee_history,
    } = record;
    fee_history.destroy();
}

/// Updates the fee associated with a NetworkNode in a NetworkNodeRecord
public(package) fun update_fee(
    record: &mut NetworkNodeRecord,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
    record.fee_history.update_fee(jump_fee, takes_effect_on, clock);
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
