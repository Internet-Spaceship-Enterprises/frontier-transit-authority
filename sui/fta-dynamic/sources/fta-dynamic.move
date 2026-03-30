// /*
// /// Module: frontier_gate_network
// module frontier_gate_network::frontier_gate_network;
// */
// module fgn::fgn_dynamic;

// use sui::clock::Clock;
// use sui::linked_table::{Self, LinkedTable};
// use sui::package::Publisher;
// use sui::table::{Self, Table};
// use sui::transfer::Receiving;
// use world::access::{Self, OwnerCap, ReturnOwnerCapReceipt};
// use world::character::Character;
// use world::energy::EnergyConfig;
// use world::gate::Gate;
// use world::in_game_id::TenantItemId;
// use world::killmail::{Killmail, LossType};
// use world::network_node::{NetworkNode};

// #[error(code = 0)]
// const EGateOwnerCapMismatch: vector<u8> = b"OwnerCap<Gate> does not belong to this Gate";
// #[error(code = 1)]
// const ENetworkNodeOwnerCapMismatch: vector<u8> =
//     b"OwnerCap<NetworkNode> does not belong to this NetworkNode";
// #[error(code = 2)]
// const EGateLinked: vector<u8> = b"To transfer a gate to FGN, the gate cannot be linked";
// #[error(code = 3)]
// const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Gate Network";
// #[error(code = 4)]
// const EGateNotYours: vector<u8> = b"You cannot modify the fee for a gate you did not assign to FGN";
// #[error(code = 5)]
// const ENotEnoughNotice: vector<u8> =
//     b"You have not provided enough notice for the fee change (takes_effect_on is too soon)";
// #[error(code = 6)]
// const EFeeChangePending: vector<u8> =
//     b"You cannot schedule a fee change when there is already a fee change pending";
// #[error(code = 7)]
// const ENoFeeActive: vector<u8> = b"No jump fee is currently active";
// #[error(code = 8)]
// const EFeeIncreaseTooLarge: vector<u8> = b"This is too large of a fee increase";
// #[error(code = 9)]
// const ETransferNetworkNodeAsWell: vector<u8> =
//     b"If the gate is connected to a network node that is not already owned by FGN, then it must be provided (use the `transfer_gate_and_network_node` function)";
// #[error(code = 10)]
// const ENoNetworkNodeProvided: vector<u8> =
//     b"If the gate is connected to a network node, then the network node must be provided";
// #[error(code = 11)]
// const ENoFeeChange: vector<u8> = b"The new fee is the same as the existing fee";

// // The minimum requirement for how long it takes for a new fee to take effect
// const FEE_CHANGE_MINIMUM_NOTICE: u64 = 604800000; // 1 week
// // The maximum fee percentage increase at a time
// // This is in thousanths of a percent
// const FEE_CHANGE_MAX_PERCENTAGE_THOUSANTHS: u64 = 20000; // 20%

// /// The OTW for the module.
// public struct FGN has drop {}

// /// Developer capability
// public struct DeveloperCap has key { id: UID }

// public struct Fee has store {
//     // The fee, in EVE tokens
//     jump_fee: u64,
//     // The timestamp (milliseconds) when the fee takes effect
//     takes_effect_on: u64,
//     // The timestamp (milliseconds) when the new fee was submitted
//     submitted_on: u64,
// }

// public struct GateRecord has store {
//     transferred_on: u64,
//     transferred_from_character_id: ID,
//     transferred_from_wallet_addr: address,
//     gate_id: ID,
//     gate_owner_cap_id: ID,
//     network_node_id: Option<ID>,
//     network_node_owner_cap_id: Option<ID>,
//     // Where the key is the update timestamp and the value is the new fee structure
//     fee_history: LinkedTable<u64, Fee>,
// }

// public struct NetworkNodeRecord has store {
//     transferred_on: u64,
//     transferred_from_character_id: ID,
//     transferred_from_wallet_addr: address,
//     network_node_id: ID,
//     network_node_owner_cap_id: ID,
// }

// // TODO: reduce the size of this to save gas fees for storage?
// public struct KillmailRecord has store {
//     killmail_id: ID,
//     key: TenantItemId,
//     killer_id: TenantItemId,
//     victim_id: TenantItemId,
//     reported_by_character_id: TenantItemId,
//     kill_timestamp: u64, // Unix timestamp in seconds
//     loss_type: LossType,
//     solar_system_id: TenantItemId,
// }

// public struct FrontierGateNetwork has key {
//     id: UID,
//     // The key is the Gate ID, the value is the GateRecord
//     gate_table: Table<ID, GateRecord>,
//     network_node_table: Table<ID, NetworkNodeRecord>,
//     killmail_table: Table<ID, KillmailRecord>,
// }

// // Called only once, upon module publication. It must be
// // private to prevent external invocation.
// fun init(otw: FGN, ctx: &mut TxContext) {
//     // Claim the Publisher object.
//     let publisher: Publisher = sui::package::claim(otw, ctx);

//     // Transfer it to the publisher address
//     transfer::public_transfer(publisher, ctx.sender());

//     // Transfers the DeveloperCap to the sender (publisher).
//     transfer::transfer(
//         DeveloperCap {
//             id: object::new(ctx),
//         },
//         ctx.sender(),
//     );

//     // Create the Gate Network object and make it shared
//     // TODO: should this use a OTW?
//     transfer::share_object(FrontierGateNetwork {
//         id: object::new(ctx),
//         gate_table: table::new<ID, GateRecord>(ctx),
//         network_node_table: table::new<ID, NetworkNodeRecord>(ctx),
//         killmail_table: table::new<ID, KillmailRecord>(ctx),
//     });
// }

// fun borrow_owner_cap<T: key>(
//     receiver: UID,
//     owner_cap_ticket: Receiving<OwnerCap<T>>,
//     ctx: &TxContext,
// ): (OwnerCap<T>, access::ReturnOwnerCapReceipt) {

//     transfer::receive(receiving_id, ticket)

//     let owner_cap = access::receive_owner_cap(&mut receiver, owner_cap_ticket);
//     let return_receipt = access::create_return_receipt(
//         object::id(&owner_cap),
//         object::id_address(character),
//     );
//     (owner_cap, return_receipt)
// }

// public fun transfer_gate_and_network_node(
//     gate_network: &mut FrontierGateNetwork,
//     current_owner: &mut Character,
//     gate: &mut Gate,
//     gate_owner_cap: OwnerCap<Gate>,
//     gate_owner_cap_receipt: ReturnOwnerCapReceipt,
//     network_node: &mut NetworkNode,
//     network_node_owner_cap: OwnerCap<NetworkNode>,
//     network_node_owner_cap_receipt: ReturnOwnerCapReceipt,
//     jump_fee: u64,
//     energy_config: &EnergyConfig,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     let nn_id = object::id(network_node);
//     let nn_owner_cap_id = object::id(&network_node_owner_cap);
//     // Run some access checks to ensure this is the right owner cap for this network node
//     assert!(network_node_owner_cap.is_authorized(nn_id), ENetworkNodeOwnerCapMismatch);
//     assert!(
//         network_node.owner_cap_id() == nn_owner_cap_id,
//         ENetworkNodeOwnerCapMismatch,
//     );

//     // If the gate is connected to a network node and is online, offline it
//     if (gate.is_online()) {
//         gate.offline(network_node, energy_config, &gate_owner_cap);
//     };

//     // Do the gate transfer
//     transfer_gate(
//         gate_network,
//         current_owner,
//         gate,
//         gate_owner_cap,
//         gate_owner_cap_receipt,
//         option::some(nn_id),
//         option::some(nn_owner_cap_id),
//         jump_fee,
//         clock,
//         ctx,
//     );

//     // Transfer the network node ownership to FGN
//     network_node_owner_cap.transfer_owner_cap_with_receipt(
//         network_node_owner_cap_receipt,
//         object::id_address(gate_network),
//         ctx,
//     );

//     // Put the record in the table
//     gate_network
//         .network_node_table
//         .add(
//             object::id(network_node),
//             NetworkNodeRecord {
//                 transferred_on: clock.timestamp_ms(),
//                 transferred_from_character_id: object::id(current_owner),
//                 transferred_from_wallet_addr: ctx.sender(),
//                 network_node_id: object::id(network_node),
//                 network_node_owner_cap_id: nn_owner_cap_id,
//             },
//         );
// }

// public fun transfer_gate_only(
//     gate_network: &mut FrontierGateNetwork,
//     current_owner: &mut Character,
//     gate: &mut Gate,
//     gate_owner_cap: OwnerCap<Gate>,
//     gate_owner_cap_receipt: ReturnOwnerCapReceipt,
//     network_node: &mut Option<NetworkNode>,
//     jump_fee: u64,
//     energy_config: &EnergyConfig,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     let mut network_node_id_opt = option::none<ID>();
//     let mut network_node_owner_cap_id_opt = option::none<ID>();
//     let energy_source_id = gate.energy_source_id();
//     if (energy_source_id.is_some()) {
//         let network_node_id = *energy_source_id.borrow();
//         // If the gate is connected to a network node, assert that we already own it.
//         // Otherwise, they need to call the function that transfers NetworkNode ownership as well.
//         assert!(
//             gate_network.network_node_table.contains(network_node_id),
//             ETransferNetworkNodeAsWell,
//         );
//         // If the gate is connected to a network node, assert that a NetworkNode object was provided
//         assert!(network_node.is_some(), ENoNetworkNodeProvided);

//         network_node_id_opt = option::some(network_node_id);
//         network_node_owner_cap_id_opt =
//             option::some(gate_network
//                 .network_node_table
//                 .borrow(network_node_id)
//                 .network_node_owner_cap_id);

//         // If the gate is connected to a network node and is online, offline it
//         if (gate.is_online()) {
//             gate.offline(network_node.borrow_mut(), energy_config, &gate_owner_cap);
//         };
//     };

//     transfer_gate(
//         gate_network,
//         current_owner,
//         gate,
//         gate_owner_cap,
//         gate_owner_cap_receipt,
//         network_node_id_opt,
//         network_node_owner_cap_id_opt,
//         jump_fee,
//         clock,
//         ctx,
//     );
// }

// fun transfer_gate(
//     gate_network: &mut FrontierGateNetwork,
//     current_owner: &Character,
//     gate: &mut Gate,
//     gate_owner_cap: OwnerCap<Gate>,
//     gate_owner_cap_receipt: ReturnOwnerCapReceipt,
//     network_node_id: Option<ID>,
//     network_node_owner_cap_id: Option<ID>,
//     jump_fee: u64,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     // Ensure the gate is not linked, because we won't be able to unlink it if we
//     // don't own the other side.
//     assert!(gate.linked_gate_id().is_none(), EGateLinked);

//     let gate_id = object::id(gate);
//     let gate_owner_cap_id = object::id(&gate_owner_cap);
//     // Run some access checks to ensure this is the right owner cap for this gate
//     assert!(gate_owner_cap.is_authorized(, gate_id), EGateOwnerCapMismatch);
//     assert!(gate.owner_cap_id() == gate_owner_cap_id, EGateOwnerCapMismatch);

//     // Use the borrowed owner cap to prepare the gate
//     prepare_gate(
//         gate,
//         &gate_owner_cap,
//         ctx,
//     );

//     // Transfer the gate ownership to FGN
//     gate_owner_cap.transfer_owner_cap_with_receipt(
//         gate_owner_cap_receipt,
//         object::id_address(gate_network),
//         ctx,
//     );
//     // Record the important values
//     let mut record = GateRecord {
//         transferred_on: clock.timestamp_ms(),
//         transferred_from_character_id: object::id(current_owner),
//         transferred_from_wallet_addr: ctx.sender(),
//         gate_id: gate_id,
//         gate_owner_cap_id: gate_owner_cap_id,
//         network_node_id: network_node_id,
//         network_node_owner_cap_id: network_node_owner_cap_id,
//         fee_history: linked_table::new<u64, Fee>(ctx),
//     };

//     // Add the initial fee, taking effect immediately
//     record
//         .fee_history
//         .push_back(
//             clock.timestamp_ms(),
//             Fee {
//                 takes_effect_on: clock.timestamp_ms(),
//                 submitted_on: clock.timestamp_ms(),
//                 jump_fee: jump_fee,
//             },
//         );

//     // Put the record in the table
//     gate_network.gate_table.add(gate_id, record)
// }

// /// Prepares a gate for FGN operation
// fun prepare_gate(gate: &mut Gate, gate_owner_cap: &OwnerCap<Gate>, ctx: &mut TxContext) {
//     // TODO: set metadata name using the system/location
//     gate.update_metadata_name(gate_owner_cap, b"Frontier Gate Network".to_string());
//     // TODO: configure the authorization extension
// }

// public fun update_fee(
//     gate_network: &mut FrontierGateNetwork,
//     gate_id: ID,
//     jump_fee: u64,
//     takes_effect_on: u64,
//     clock: &Clock,
//     ctx: &mut TxContext,
// ) {
//     // Ensure that enough notice is given for the change
//     assert!(takes_effect_on - clock.timestamp_ms() >= FEE_CHANGE_MINIMUM_NOTICE, ENotEnoughNotice);

//     // Ensure the gate is actually part of the network
//     assert!(gate_network.gate_table.contains(gate_id), EGateNotInNetwork);

//     // Load the record
//     let record = &mut gate_network.gate_table[gate_id];

//     // Ensure the sender is the entity that previously owned the gate
//     assert!(record.transferred_from_wallet_addr == ctx.sender(), EGateNotYours);

//     // Get the key for the last fee modification
//     let last_modified_key_option = record.fee_history.back();

//     // Ensure a value was found (there should always be, since one is created in the init() function)
//     assert!(option::is_some(last_modified_key_option), ENoFeeActive);

//     // Get the latest change
//     let latest_change = record.fee_history.borrow(*last_modified_key_option.borrow());

//     // Ensure that the latest change is active, not pending.
//     // This prevents scheduling a new change when the last change hasn't taken effect yet.
//     assert!(latest_change.takes_effect_on <= clock.timestamp_ms(), EFeeChangePending);

//     // Ensure there's actually a change to the fee
//     assert!(jump_fee != latest_change.jump_fee, ENoFeeChange);

//     // Ensure that either it's a fee reduction, or the increase is within the limit
//     assert!(
//         jump_fee < latest_change.jump_fee || (jump_fee - latest_change.jump_fee) * 100000 / latest_change.jump_fee <= FEE_CHANGE_MAX_PERCENTAGE_THOUSANTHS,
//         EFeeIncreaseTooLarge,
//     );

//     // Schedule the change
//     record
//         .fee_history
//         .push_back(
//             clock.timestamp_ms(),
//             Fee {
//                 jump_fee: jump_fee,
//                 takes_effect_on: takes_effect_on,
//                 submitted_on: clock.timestamp_ms(),
//             },
//         );
// }

// /// Retrieves the current per-jump fee (in EVE tokens) for a given gate
// public fun current_fee(gate_network: &FrontierGateNetwork, gate_id: ID, clock: &Clock): u64 {
//     // Ensure the gate is actually part of the network
//     assert!(gate_network.gate_table.contains(gate_id), EGateNotInNetwork);

//     // Get the gate record
//     let fee_history = &gate_network.gate_table[gate_id].fee_history;

//     // Get the key for the last fee modification
//     let last_modified_key_option = fee_history.back();

//     // Ensure a value was found (there should always be, since one is created in the init() function)
//     assert!(option::is_some(last_modified_key_option), ENoFeeActive);

//     // Borrow the value from the option
//     let latest_fee_key = *last_modified_key_option.borrow();

//     // Get the latest change
//     let latest_fee = fee_history.borrow(latest_fee_key);

//     // If the latest fee is active, use it
//     if (latest_fee.takes_effect_on <= clock.timestamp_ms()) {
//         latest_fee.jump_fee
//     } else {
//         // Otherwise, get the previous fee, which MUST be active since we don't allow
//         // setting a new fee while a fee change is pending.
//         let prev_fee_key_option = fee_history.prev(latest_fee_key);
//         assert!(option::is_some(prev_fee_key_option), ENoFeeActive);
//         let prev_fee_key = *prev_fee_key_option.borrow();

//         let prev_fee = fee_history.borrow(prev_fee_key);
//         assert!(prev_fee.takes_effect_on <= clock.timestamp_ms(), ENoFeeActive);
//         prev_fee.jump_fee
//     }
// }

// public fun gate_count(gate_network: &FrontierGateNetwork): u64 {
//     gate_network.gate_table.length()
// }

// // public fun process_killmails(gate_network: &mut FrontierGateNetwork, killmails: &vector<Killmail>) {
// //     let mut i = 0;
// //     while (i < killmails.length()) {
// //         let killmail = killmails.borrow(i);
// //         i = i+1;
// //         gate_network
// //             .killmail_table
// //             .add(
// //                 object::id(killmail),
// //                 KillmailRecord {
// //                     killmail_id: object::id(killmail),
// //                     kill_timestamp: killmail.kill_timestamp,
// //                     killer_id: killmail.killer_id,
// //                     loss_type: killmail.loss_type,
// //                     key: killmail.key,
// //                     reported_by_character_id: killmail.reported_by_character_id,
// //                     solar_system_id: killmail.solar_system_id,
// //                     victim_id: killmail.victim_id,
// //                 },
// //             );
// //     }
// // }

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
