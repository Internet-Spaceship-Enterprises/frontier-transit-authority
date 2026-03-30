module fta::killmail_registry;

use fta::blacklist::Blacklist;
use fta::bounty_board::BountyBoard;
use fta::constants;
use fta::gate_registry::GateRegistry;
use fta::jump_history::JumpHistory;
use fta::network_node_registry::NetworkNodeRegistry;
use sui::clock::Clock;
use sui::derived_object::derive_address;
use sui::table::{Self, Table};
use world::killmail::Killmail;
use world::object_registry::ObjectRegistry;

#[error(code = 1)]
const EKillmailAlreadyProcessed: vector<u8> = b"This killmail has already been processed";

public struct KillmailRegistry has store {
    processed_killmails: Table<ID, bool>,
}

public(package) fun new(ctx: &mut TxContext): KillmailRegistry {
    KillmailRegistry {
        processed_killmails: table::new(ctx),
    }
}

public(package) fun process_killmail(
    registry: &mut KillmailRegistry,
    killmail: &Killmail,
    gate_registry: &mut GateRegistry,
    network_node_registry: &mut NetworkNodeRegistry,
    jump_history_registry: &mut JumpHistory,
    blacklist: &mut Blacklist,
    bounty_board: &mut BountyBoard,
    object_registry: &ObjectRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure the killmail hasn't already been processed
    assert!(!registry.processed_killmails.contains(killmail.id()), EKillmailAlreadyProcessed);

    // Mark that we've processed this killmail
    registry.processed_killmails.add(killmail.id(), true);

    let victim_object_id = derive_address(object_registry.id(), killmail.victim_id()).to_id();

    // Get the average jump fee over the past X amount of time
    let avg_jump_fee_opt = jump_history_registry.fee_average(
        constants::blacklist_penalty_average_period(),
        clock,
    );

    // Use a default value if there's no jump history to calculate from
    let avg_jump_fee = if (avg_jump_fee_opt.is_none()) {
        constants::blacklist_default_avg_jump_fee()
    } else {
        *avg_jump_fee_opt.borrow()
    };

    let mut deserves_penalty = false;

    if (killmail.is_structure_loss()) {
        // Check if the killmail is for a gate or a network node
        if (gate_registry.registered_by_id(victim_object_id)) {
            deserves_penalty = true;
            // The killmail is for a gate, so we need to update the gate registry
            gate_registry.destroyed(victim_object_id);
        } else if (network_node_registry.registered_by_id(victim_object_id)) {
            let record = network_node_registry.get_by_id_mut(victim_object_id);

            // Only punish for the kill if the network node's uptime is above the minimum requirement (node is in good standing)
            deserves_penalty =
                record.uptime_avg(constants::network_node_uptime_requirement_period(), clock) >= constants::network_node_uptime_requirement_for_blacklist();

            // The killmail is for a network node, so we need to update the network node registry
            network_node_registry.deregister_by_id(victim_object_id);
        }
    };

    // If it was an FTA asset, we must administer punishment
    if (deserves_penalty) {
        blacklist.add(
            killmail,
            false,
            avg_jump_fee,
            object_registry,
            clock,
            ctx,
        );
        ERROR
        // TODO: add bounty
    };
    ERROR
    // TODO: pay bounties if the target was on the bounty board
}
