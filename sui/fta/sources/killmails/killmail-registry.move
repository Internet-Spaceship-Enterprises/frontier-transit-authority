module fta::killmail_registry;

use fta::blacklist::Blacklist;
use fta::constants;
use fta::gate_registry::GateRegistry;
use fta::jump_history::JumpHistory;
use fta::network_node_registry::NetworkNodeRegistry;
use sui::clock::Clock;
use sui::derived_object::derive_address;
use sui::table::{Self, Table};
use world::killmail::Killmail;
use world::object_registry::ObjectRegistry;

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
    object_registry: &ObjectRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    if (registry.processed_killmails.contains(killmail.id())) {
        // Killmail has already been processed, skip it
        return
    };

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

    let mut belongs_to_fta = false;

    if (killmail.is_structure_loss()) {
        // Check if the killmail is for a gate or a network node
        if (gate_registry.registered_by_id(victim_object_id)) {
            belongs_to_fta = true;
            // The killmail is for a gate, so we need to update the gate registry
            gate_registry.destroyed(victim_object_id);
        } else if (network_node_registry.registered_by_id(victim_object_id)) {
            belongs_to_fta = true;
            // The killmail is for a network node, so we need to update the network node registry
            network_node_registry.deregister_by_id(victim_object_id);
        }
    };

    // If it was an FTA asset, we must administer punishment
    if (belongs_to_fta) {
        blacklist.add(
            killmail,
            false,
            avg_jump_fee,
            object_registry,
            clock,
            ctx,
        );
    };
}
