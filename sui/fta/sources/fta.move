/*
/// Module: frontier_transit_authority
module fta::fta;
*/
module fta::fta;

use fta::gate_record::GateRecord;
use fta::network_node_record::NetworkNodeRecord;
use std::hash;
use sui::bcs;
use sui::package::Publisher;
use sui::table::{Self, Table};

/// The OTW for the module.
public struct FTA has drop {}

/// Developer capability
public struct DeveloperCap has key { id: UID }

public struct FrontierTransitAuthority has key {
    id: UID,
    // The key is the Gate ID, the value is the GateRecord
    gate_table: Table<vector<u8>, GateRecord>,
    network_node_table: Table<ID, NetworkNodeRecord>,
}

// Called only once, upon module publication. It must be
// private to prevent external invocation.
fun init(otw: FTA, ctx: &mut TxContext) {
    // Claim the Publisher object.
    let publisher: Publisher = sui::package::claim(otw, ctx);

    // Transfer it to the publisher address
    transfer::public_transfer(publisher, ctx.sender());

    // Transfers the DeveloperCap to the sender (publisher).
    transfer::transfer(
        DeveloperCap {
            id: object::new(ctx),
        },
        ctx.sender(),
    );

    // Create the Transit Authority object and make it shared
    // TODO: should this use a OTW?
    transfer::share_object(FrontierTransitAuthority {
        id: object::new(ctx),
        gate_table: table::new<vector<u8>, GateRecord>(ctx),
        network_node_table: table::new<ID, NetworkNodeRecord>(ctx),
        //killmail_table: table::new<ID, KillmailRecord>(ctx),
    });
}

public(package) fun gate_table(fta: &FrontierTransitAuthority): &Table<vector<u8>, GateRecord> {
    &fta.gate_table
}

public(package) fun network_node_table(
    fta: &FrontierTransitAuthority,
): &Table<ID, NetworkNodeRecord> {
    &fta.network_node_table
}

public(package) fun add_gate_record(fta: &mut FrontierTransitAuthority, record: GateRecord) {
    fta.gate_table.add(gate_pair_hash(record.gate_a_id(), record.gate_b_id()), record);
}

public(package) fun add_network_node_record(
    fta: &mut FrontierTransitAuthority,
    record: NetworkNodeRecord,
) {
    fta.network_node_table.add(*record.network_node_id(), record);
}

// Returns a unique key for a pair of gates, regardless of the order in which they are given
public(package) fun gate_pair_hash(gate_a_id: &ID, gate_b_id: &ID): vector<u8> {
    let mut a_addr_bytes = object::id_to_bytes(gate_a_id);
    let mut b_addr_bytes = object::id_to_bytes(gate_b_id);
    let a_int = bcs::peel_u256(&mut bcs::new(a_addr_bytes));
    let b_int = bcs::peel_u256(&mut bcs::new(b_addr_bytes));

    if (a_int > b_int) {
        a_addr_bytes.append(b_addr_bytes);
        hash::sha3_256(a_addr_bytes)
    } else {
        b_addr_bytes.append(a_addr_bytes);
        hash::sha3_256(b_addr_bytes)
    }
}

public fun gate_count(gate_network: &FrontierTransitAuthority): u64 {
    gate_network.gate_table.length()
}

// public fun process_killmails(gate_network: &mut FrontierTransitAuthority, killmails: &vector<Killmail>) {
//     let mut i = 0;
//     while (i < killmails.length()) {
//         let killmail = killmails.borrow(i);
//         i = i+1;
//         gate_network
//             .killmail_table
//             .add(
//                 object::id(killmail),
//                 KillmailRecord {
//                     killmail_id: object::id(killmail),
//                     kill_timestamp: killmail.kill_timestamp,
//                     killer_id: killmail.killer_id,
//                     loss_type: killmail.loss_type,
//                     key: killmail.key,
//                     reported_by_character_id: killmail.reported_by_character_id,
//                     solar_system_id: killmail.solar_system_id,
//                     victim_id: killmail.victim_id,
//                 },
//             );
//     }
// }

// public fun prepare_for_jump(
//     gate_a: &mut Gate,
//     gate_a_owner_cap: &Receiving<OwnerCap<Gate>>,
//     network_node_a: &mut NetworkNode,
//     network_node_a_owner_cap: &Receiving<OwnerCap<NetworkNode>>,
//     gate_b: &mut Gate,
//     gate_b_owner_cap: &Receiving<OwnerCap<Gate>>,
//     network_node_b: &mut NetworkNode,
//     network_node_b_owner_cap: &Receiving<OwnerCap<NetworkNode>>,
//     energy_config: &EnergyConfig,
//     clock: &Clock,
// ) {
//     // Validate everything about Gate A
//     assert!(gate_a.energy_source_id().is_some());
//     assert!(gate_a.energy_source_id().borrow() == object::id(network_node_a));
//     assert!(gate_a.owner_cap_id() == object::id(gate_a_owner_cap), EGateOwnerCapMismatch);
//     assert!(
//         network_node_a_owner_cap.is_authorized(object::id(network_node_a)),
//         ENetworkNodeOwnerCapMismatch,
//     );
//     assert!(
//         network_node_a.owner_cap_id() == object::id(network_node_a_owner_cap),
//         ENetworkNodeOwnerCapMismatch,
//     );

//     // Validate everything about Gate B
//     assert!(gate_b.energy_source_id().is_some());
//     assert!(gate_b.energy_source_id().borrow() == object::id(network_node_b));
//     assert!(gate_b.owner_cap_id() == object::id(gate_b_owner_cap), EGateOwnerCapMismatch);
//     assert!(
//         network_node_b_owner_cap.is_authorized(object::id(network_node_b)),
//         ENetworkNodeOwnerCapMismatch,
//     );
//     assert!(
//         network_node_b.owner_cap_id() == object::id(network_node_b_owner_cap),
//         ENetworkNodeOwnerCapMismatch,
//     );

//     if (!network_node_a.is_network_node_online()) {
//         network_node_a.online(network_node_a_owner_cap, clock);
//     };
//     if (!network_node_b.is_network_node_online()) {
//         network_node_b.online(network_node_b_owner_cap, clock);
//     };
//     if (!gate_a.is_online()) {
//         gate_a.online(network_node_a, energy_config, gate_a_owner_cap);
//     };
//     if (!gate_b.is_online()) {
//         gate_b.online(network_node_b, energy_config, gate_b_owner_cap);
//     };

//     gate_a.link_gates(
//         gate_b,
//         gate_config,
//         server_registry,
//         admin_acl,
//         source_gate_owner_cap,
//         destination_gate_owner_cap,
//         distance_proof,
//         clock,
//         ctx,
//     )
// }
