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
use world::access::OwnerCap;
use world::character::Character;
use world::gate::Gate;
use world::killmail::Killmail;
use world::object_registry::ObjectRegistry;

#[error(code = 1)]
const EKillmailAlreadyProcessed: vector<u8> = b"This killmail has already been processed";
#[error(code = 2)]
const EWrongKiller: vector<u8> =
    b"The character object provided for the killer does not match the killmail";
#[error(code = 3)]
const ENoVictim: vector<u8> = b"No victim object was provided for thekillmail";
#[error(code = 4)]
const EWrongVictim: vector<u8> =
    b"The character object provided for the victim does not match the killmail";
#[error(code = 5)]
const ELinkedGateNotProvided: vector<u8> = b"The linked gate was not provided";
#[error(code = 6)]
const ELinkedGateOwnerCapNotProvided: vector<u8> = b"The linked gate owner cap was not provided";
#[error(code = 7)]
const EUnnecessaryLinkedGateOwnerCap: vector<u8> =
    b"The linked gate owner cap was provided unnecessarily";

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
    killer: &Character,
    victim: &Option<Character>,
    linked_gate: &mut Option<Gate>,
    mut linked_gate_owner_cap: Option<OwnerCap<Gate>>,
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

    // Derive the object ID of the killer
    let killer_character_id = derive_address(object_registry.id(), killmail.killer_id()).to_id();

    // Ensure the correct killer character was passed
    assert!(killer_character_id == killer.id(), EWrongKiller);

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

    let mut deserves_punishment = false;
    let mut linked_gate_owner_cap_used = false;

    if (killmail.is_structure_loss()) {
        // Check if the killmail is for a gate or a network node
        if (gate_registry.registered_by_id(victim_object_id)) {
            assert!(linked_gate.is_some(), ELinkedGateNotProvided);
            assert!(linked_gate_owner_cap.is_some(), ELinkedGateOwnerCapNotProvided);
            deserves_punishment = true;
            // The killmail is for a gate, so we need to update the gate registry
            gate_registry.destroyed(
                victim_object_id,
                linked_gate.borrow_mut(),
                linked_gate_owner_cap.extract(),
            );
            linked_gate_owner_cap_used = true;
        } else if (network_node_registry.registered_by_id(victim_object_id)) {
            let record = network_node_registry.get_by_id_mut(victim_object_id);

            // Only punish for the kill if the network node's uptime is above the minimum requirement (node is in good standing)
            deserves_punishment =
                record.uptime_avg(constants::network_node_uptime_requirement_period(), clock) >= constants::network_node_uptime_requirement_for_blacklist();

            // The killmail is for a network node, so we need to update the network node registry
            network_node_registry.deregister_by_id(victim_object_id);
        }
    };

    if (!linked_gate_owner_cap_used) {
        assert!(linked_gate_owner_cap.is_none(), EUnnecessaryLinkedGateOwnerCap);
    };
    linked_gate_owner_cap.destroy_none();

    // If it was an FTA asset, we must administer punishment
    if (deserves_punishment) {
        // Add the character to the blacklist
        blacklist.add(
            killmail,
            false,
            avg_jump_fee,
            object_registry,
            clock,
            ctx,
        );
        // Put a bounty on the character and their tribe
        bounty_board.add(killmail, killer, clock, ctx);
    } else if (killmail.is_ship_loss()) {
        // No punishment is needed for this kill and it's a ship kill, so
        // now we should check if it was a "good" kill that we should reward

        // Ensure the victim was provided
        assert!(victim.is_some(), ENoVictim);

        let victim = victim.borrow();

        // Ensure the correct victim character was passed
        assert!(victim.id() == victim_object_id, EWrongVictim);

        // Pay out the bounty, if there is one
        bounty_board.pay(killmail, killer, victim, clock);
    };

    // TODO: once location proofs are available, check if this was for combat near an FTA asset.
    // If so, and it wasn't a bountied character/tribe, administer punishment for gate camping.
}
