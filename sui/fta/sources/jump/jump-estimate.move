module fta::jump_estimate;

use fta::constants;
use fta::fta::FrontierTransitAuthority;
use std::u64::max;
use sui::clock::Clock;
use world::gate::Gate;

#[error(code = 1)]
const EDurationTooLong: vector<u8> =
    b"The validity duration you provided exceeds the maximum duration";
#[error(code = 2)]
const EGatesNotLinked: vector<u8> = b"You cannot get a jump permit for gates that are not linked";

// A precision factor for integer math. Changing it just changes the granularity of pricing, doesn't affect overall costs.
const FEE_PRECISION_FACTOR: u64 = 1000;

public struct JumpEstimate has copy, drop, store {
    id: ID,
    prepared_at: u64,
    character_id: ID,
    source_gate_id: ID,
    destination_gate_id: ID,
    source_gate_fee: u64,
    destination_gate_fee: u64,
    source_network_node_fee: u64,
    destination_network_node_fee: u64,
    total_base_fee: u64,
    bounty_fee: u64,
    developer_fee: u64,
    penalty_factor: u64,
    // The duration, in milliseconds, that the permit is good for
    validity_duration: u64,
}

/// Gets a fee estimate for a jump from a given gate
/// TODO: with dynamic linking, require the destination gate as well
public fun new(
    fta: &FrontierTransitAuthority,
    character_id: ID,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): JumpEstimate {
    // Ensure both gates are valid and linked
    fta.check_gate_validity(source_gate);
    fta.check_gate_validity(destination_gate);

    // Ensure the gates are actually linked with each other
    assert!(
        source_gate.linked_gate_id().is_some() && source_gate.linked_gate_id().borrow() == object::id(destination_gate),
        EGatesNotLinked,
    );

    // Ensure the duration is within the limit
    assert!(validity_duration <= constants::jump_max_validity_duration(), EDurationTooLong);

    // Always grant for at least the base/minimum duration
    let validity_duration_adjusted = max(
        validity_duration,
        constants::jump_base_validity_duration(),
    );

    let source_gate_base_fee = fta.gate_table().get_by_gate(source_gate).current_fee(clock);
    let destination_gate_base_fee = fta
        .gate_table()
        .get_by_gate(destination_gate)
        .current_fee(clock);
    let source_network_node_base_fee = fta
        .network_node_table()[*source_gate.energy_source_id().borrow()]
        .current_fee(clock);
    let destination_network_node_base_fee = fta
        .network_node_table()[*destination_gate.energy_source_id().borrow()]
        .current_fee(clock);

    let scaling_factor = (
        FEE_PRECISION_FACTOR * (validity_duration_adjusted - constants::jump_base_validity_duration()) * (constants::jump_max_validity_duration_multiplier() - 1) / (constants::jump_max_validity_duration() - constants::jump_base_validity_duration()) + FEE_PRECISION_FACTOR,
    );
    // TODO: get this from blacklist
    let penalty_factor = 100;

    // Calculate the scaled fees based on the validity duration
    let scaled_source_gate_base_fee =
        penalty_factor * source_gate_base_fee * scaling_factor / FEE_PRECISION_FACTOR / 100;
    let scaled_destination_gate_base_fee =
        penalty_factor * destination_gate_base_fee * scaling_factor / FEE_PRECISION_FACTOR / 100;
    let scaled_source_network_node_base_fee =
        penalty_factor * source_network_node_base_fee * scaling_factor / FEE_PRECISION_FACTOR / 100;
    let scaled_destination_network_node_base_fee =
        penalty_factor * destination_network_node_base_fee * scaling_factor / FEE_PRECISION_FACTOR / 100;

    let total_base_fee =
        scaled_source_gate_base_fee
        + scaled_destination_gate_base_fee
        + scaled_source_network_node_base_fee
        + scaled_destination_network_node_base_fee;
    let bounty_fee = total_base_fee * constants::bounty_fee() / 100;
    let developer_fee = total_base_fee * constants::developer_fee() / 100;

    JumpEstimate {
        id: ctx.fresh_object_address().to_id(),
        prepared_at: clock.timestamp_ms(),
        character_id: character_id,
        source_gate_id: object::id(source_gate),
        destination_gate_id: object::id(destination_gate),
        source_gate_fee: scaled_source_gate_base_fee,
        destination_gate_fee: scaled_destination_gate_base_fee,
        source_network_node_fee: scaled_source_network_node_base_fee,
        destination_network_node_fee: scaled_destination_network_node_base_fee,
        total_base_fee: total_base_fee,
        bounty_fee: bounty_fee,
        developer_fee: developer_fee,
        penalty_factor: penalty_factor,
        validity_duration: validity_duration_adjusted,
    }
}

public(package) fun id(estimate: &JumpEstimate): ID {
    estimate.id
}

public(package) fun character_id(estimate: &JumpEstimate): ID {
    estimate.character_id
}

public(package) fun source_gate_id(estimate: &JumpEstimate): ID {
    estimate.source_gate_id
}

public(package) fun destination_gate_id(estimate: &JumpEstimate): ID {
    estimate.destination_gate_id
}

public(package) fun source_gate_fee(estimate: &JumpEstimate): u64 {
    estimate.source_gate_fee
}

public(package) fun destination_gate_fee(estimate: &JumpEstimate): u64 {
    estimate.destination_gate_fee
}

public(package) fun source_network_node_fee(estimate: &JumpEstimate): u64 {
    estimate.source_network_node_fee
}

public(package) fun destination_network_node_fee(estimate: &JumpEstimate): u64 {
    estimate.destination_network_node_fee
}

public(package) fun total_base_fee(estimate: &JumpEstimate): u64 {
    estimate.total_base_fee
}

public(package) fun bounty_fee(estimate: &JumpEstimate): u64 {
    estimate.bounty_fee
}

public(package) fun developer_fee(estimate: &JumpEstimate): u64 {
    estimate.developer_fee
}

public(package) fun validity_duration(estimate: &JumpEstimate): u64 {
    estimate.validity_duration
}

public(package) fun penalty_factor(estimate: &JumpEstimate): u64 {
    estimate.penalty_factor
}

public(package) fun prepared_at(estimate: &JumpEstimate): u64 {
    estimate.prepared_at
}
