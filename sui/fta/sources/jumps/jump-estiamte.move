module fta::jump_estimate;

use fta::blacklist::Blacklist;
use fta::constants;
use fta::gate_registry::GateRegistry;
use fta::network_node_registry::NetworkNodeRegistry;
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
    // The unscaled base fee for the source gate
    source_gate_fee: u64,
    // The unscaled base fee for the destination gate
    destination_gate_fee: u64,
    // The unscaled base fee for the source network node
    source_network_node_fee: u64,
    // The unscaled base fee for the destination network node
    destination_network_node_fee: u64,
    // The permit duration scaling factor
    scaling_factor: u64,
    // The penalty factor to apply to the base fees
    penalty_factor: u64,
    // The bounty fee for the jump, which goes into the bounty pool to pay out rewards
    bounty_fee: u64,
    // The developer fee for the jump, which goes into the developer pool to fund development work
    developer_fee: u64,
    // The duration, in milliseconds, that the permit is good for
    validity_duration: u64,
    // The factor that was used to scale up the scaling and penalty factors for integer math
    precision_factor: u64,
}

/// Gets a fee estimate for a jump from a given gate
public(package) fun new(
    gate_registry: &GateRegistry,
    network_node_registry: &NetworkNodeRegistry,
    blacklist: &Blacklist,
    character_id: ID,
    source_gate: &Gate,
    destination_gate: &Gate,
    validity_duration: u64,
    clock: &Clock,
    ctx: &mut TxContext,
): JumpEstimate {
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

    let source_gate_base_fee = gate_registry.get(source_gate).current_fee(clock);
    let destination_gate_base_fee = gate_registry.get(destination_gate).current_fee(clock);
    let source_network_node_base_fee = network_node_registry
        .get_by_id(*source_gate.energy_source_id().borrow())
        .current_fee(clock);
    let destination_network_node_base_fee = network_node_registry
        .get_by_id(*destination_gate.energy_source_id().borrow())
        .current_fee(clock);

    let scaling_factor = (
        FEE_PRECISION_FACTOR * (validity_duration_adjusted - constants::jump_base_validity_duration()) * (constants::jump_max_validity_duration_multiplier() - 1) / (constants::jump_max_validity_duration() - constants::jump_base_validity_duration()) + FEE_PRECISION_FACTOR,
    );

    // Get the penalty multiplier for this character from the blacklist.
    let penalty_factor = blacklist.get_penalty_multiplier(character_id);

    let unscaled_total_base_fee =
        source_gate_base_fee
        + destination_gate_base_fee
        + source_network_node_base_fee
        + destination_network_node_base_fee;

    // Scale it up appropriately
    let scaled_total_base_fee = unscaled_total_base_fee * scaling_factor / FEE_PRECISION_FACTOR;

    // Calculate the additional fees off the scaled base fees
    let bounty_fee = scaled_total_base_fee * constants::bounty_fee() / 100;
    let developer_fee = scaled_total_base_fee * constants::developer_fee() / 100;

    JumpEstimate {
        id: ctx.fresh_object_address().to_id(),
        prepared_at: clock.timestamp_ms(),
        character_id: character_id,
        source_gate_id: object::id(source_gate),
        destination_gate_id: object::id(destination_gate),
        source_gate_fee: source_gate_base_fee,
        destination_gate_fee: destination_gate_base_fee,
        source_network_node_fee: source_network_node_base_fee,
        destination_network_node_fee: destination_network_node_base_fee,
        scaling_factor: scaling_factor,
        bounty_fee: bounty_fee,
        developer_fee: developer_fee,
        penalty_factor: penalty_factor,
        validity_duration: validity_duration_adjusted,
        precision_factor: FEE_PRECISION_FACTOR,
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

// Gets the unscaled base fee for the source gate, which is the fee before any scaling for permit duration or penalty factors
public fun source_gate_fee_unscaled(estimate: &JumpEstimate): u64 {
    estimate.source_gate_fee
}

// Gets the unscaled base fee for the destination gate, which is the fee before any scaling for permit duration or penalty factors
public fun destination_gate_fee_unscaled(estimate: &JumpEstimate): u64 {
    estimate.destination_gate_fee
}

// Gets the unscaled base fee for the source network node, which is the fee before any scaling for permit duration or penalty factors
public fun source_network_node_fee_unscaled(estimate: &JumpEstimate): u64 {
    estimate.source_network_node_fee
}

// Gets the unscaled base fee for the destination network node, which is the fee before any scaling for permit duration or penalty factors
public fun destination_network_node_fee_unscaled(estimate: &JumpEstimate): u64 {
    estimate.destination_network_node_fee
}

// Gets the scaled base fee for the source gate, which is the fee after permit duration scaling for permit duration but before any penalty factors
public fun source_gate_fee_scaled(estimate: &JumpEstimate): u64 {
    estimate.source_gate_fee * estimate.scaling_factor / estimate.precision_factor
}

// Gets the scaled base fee for the destination gate, which is the fee after permit duration scaling for permit duration but before any penalty factors
public fun destination_gate_fee_scaled(estimate: &JumpEstimate): u64 {
    estimate.destination_gate_fee * estimate.scaling_factor / estimate.precision_factor
}

// Gets the scaled base fee for the source network node, which is the fee after permit duration scaling for permit duration but before any penalty factors
public fun source_network_node_fee_scaled(estimate: &JumpEstimate): u64 {
    estimate.source_network_node_fee * estimate.scaling_factor / estimate.precision_factor
}

// Gets the scaled base fee for the destination network node, which is the fee after permit duration scaling for permit duration but before any penalty factors
public fun destination_network_node_fee_scaled(estimate: &JumpEstimate): u64 {
    estimate.destination_network_node_fee * estimate.scaling_factor / estimate.precision_factor
}

public fun developer_fee(estimate: &JumpEstimate): u64 {
    estimate.developer_fee
}

public fun validity_duration(estimate: &JumpEstimate): u64 {
    estimate.validity_duration
}

public fun penalty_factor(estimate: &JumpEstimate): u64 {
    estimate.penalty_factor
}

public fun prepared_at(estimate: &JumpEstimate): u64 {
    estimate.prepared_at
}

// Returns the total base fee before any permit duration or penalty factor scaling
public fun total_unscaled_base_fee(estimate: &JumpEstimate): u64 {
    estimate.source_gate_fee
    + estimate.destination_gate_fee
    + estimate.source_network_node_fee
    + estimate.destination_network_node_fee
}

// Returns the total base fee WITH permit duration scaling but before any penalty factors
public fun total_scaled_base_fee(estimate: &JumpEstimate): u64 {
    estimate.total_unscaled_base_fee() * estimate.scaling_factor / estimate.precision_factor
}

/// Gets the total overall fee to be paid for an estimate
public fun total_fee(estimate: &JumpEstimate): u64 {
    (estimate.total_scaled_base_fee()
    + estimate.bounty_fee
    + estimate.developer_fee)
    * estimate.penalty_factor / 100
}

/// Gets the total bounty fee to be paid for an estimate
public fun total_bounty_fee(estimate: &JumpEstimate): u64 {
    // The bounty fee is the sum of the bounty fee and the penalty applied to the base fee
    estimate.bounty_fee + estimate.total_scaled_base_fee() * (estimate.penalty_factor() - 100) / 100
}
