module fta::blacklist;

// use sui::clock::Clock;
// use sui::linked_table::{Self, LinkedTable};

// public struct BlacklistRecord has store {
//     character_id: ID,
//     /// When the blacklisting started
//     start: u64,
//     /// When the blacklisting ends (if end == 0, then the blacklist is permanent)
//     end: u64,
//     /// The multiplier for jump fees for this blacklisted character.
//     /// For example, if the multiplier is 150, then the jump fee for this character will be 1.5x the normal fee.
//     /// If this is zero, then jumping is prohibited altogether.
//     penalty_multiplier: u64,
// }

// public struct Blacklist has store {
//     // All blacklisted records
//     records: LinkedTable<ID, BlacklistRecord>,
// }

// TODO: figure out a way to scale the penalty multiplier based on the severity of the offense and the duration of the blacklist.

// /// Adds a character to the blacklist with a specified penalty multiplier and duration
// public(package) fun add(
//     blacklist: &mut Blacklist,
//     character_id: ID,
//     duration: u64,
//     penalty_multiplier: u64,
//     clock: &Clock,
// ) {
//     if(blacklist.records.contains(character_id)) {
//         let record = blacklist.records.borrow_mut(character_id);
//         record.start = clock.timestamp_ms();
//         record.end = if (duration == 0) { 0 } else { clock.timestamp_ms() + duration };
//         record.penalty_multiplier = penalty_multiplier;
//         return;
//     };
//     let record = BlacklistRecord {
//         character_id: character_id,
//         start: clock.timestamp_ms(),
//         end: if (duration == 0) { 0 } else { clock.timestamp_ms() + duration },
//         penalty_multiplier,
//     };
//     blacklist.records.push_back(k, value)(character_id, record);
// }

// /// Checks if a character is currently blacklisted and returns the applicable penalty multiplier
// public(package) fun get_penalty_multiplier(
//     blacklist: &Blacklist,
//     character_id: ID,
//     clock: &Clock,
// ): u64 {
//     if (!blacklist.records.contains(character_id)) {
//         return 100; // Not blacklisted, normal fee
//     };
//     let record = blacklist.records.borrow(character_id);
//     if (record.end != 0 && clock.timestamp_ms() > record.end) {
//         return 1; // Blacklist expired, normal fee
//     };
//     record.penalty_multiplier
// }
