module fta::blacklist;

use fta::blacklist_penalties::{Self, BlacklistPenalties};
use sui::clock::Clock;
use sui::derived_object::derive_address;
use sui::linked_table::{Self, LinkedTable};
use world::killmail::Killmail;
use world::object_registry::ObjectRegistry;

public struct PermanentBlacklistRecord has store {
    character_id: ID,
    /// When the blacklisting started
    issued_at: u64,
    /// The multiplier for jump fees for this blacklisted character.
    /// For example, if the multiplier is 150, then the jump fee for this character will be 1.5x the normal fee.
    /// If this is zero, then jumping is prohibited altogether.
    penalty_multiplier: u64,
}

public struct TemporaryBlacklistRecord has store {
    // The ID of the killmail that caused this blacklist record
    killmail_id: ID,
    // The ID of the character that is blacklisted
    character_id: ID,
    /// When the blacklisting started
    issued_at: u64,
    /// The multiplier for jump fees for this blacklisted character.
    /// For example, if the multiplier is 150, then the jump fee for this character will be 1.5x the normal fee.
    /// If this is zero, then jumping is prohibited altogether.
    penalty_multiplier: u64,
    // The amount the player owes as a penalty for their offense
    amount_due: u64,
    /// How much the character has paid down on their blacklist penalty
    paid_down: u64,
}

public struct BlacklistCharacter has store {
    permanent: LinkedTable<u64, PermanentBlacklistRecord>,
    temporary: LinkedTable<u64, TemporaryBlacklistRecord>,
    // In percent
    permanent_sum: u64,
    /// Points to the record currently being paid down
    temporary_front_pointer: Option<u64>,
    // In percent
    temporary_sum: u64,
}

public struct Blacklist has store {
    // All blacklisted records
    records: LinkedTable<ID, BlacklistCharacter>,
    penalties: BlacklistPenalties,
}

public(package) fun new(ctx: &mut TxContext): Blacklist {
    Blacklist {
        records: linked_table::new(ctx),
        penalties: blacklist_penalties::new(),
    }
}

/// Adds a blacklist record for a character.
public(package) fun add(
    blacklist: &mut Blacklist,
    killmail: &Killmail,
    permanent: bool,
    average_jump_fee: u64,
    object_registry: &ObjectRegistry,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // This derives the on-chain character ID in the same way the killmail does
    let killer_character_id = derive_address(object_registry.id(), killmail.killer_id()).to_id();

    // If there's no blacklist for this character yet, create one
    if (!blacklist.records.contains(killer_character_id)) {
        blacklist
            .records
            .push_back(
                killer_character_id,
                BlacklistCharacter {
                    permanent: linked_table::new(ctx),
                    temporary: linked_table::new(ctx),
                    permanent_sum: 0,
                    temporary_front_pointer: option::none(),
                    temporary_sum: 0,
                },
            );
    };

    // This information is not currently available from the killmail.
    // For now, use the Heavy Gate type ID for all killmails.
    // TODO: update once destroyed type ID is available from the killmail.
    let destroyed_type_id = 84955;

    let penalty = blacklist.penalties.get(destroyed_type_id);

    let blacklist_character = blacklist.records.borrow_mut(killer_character_id);
    if (permanent) {
        // Create the record to be inserted
        let record = PermanentBlacklistRecord {
            character_id: killer_character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty.destroyed_penalty_factor(),
        };
        blacklist_character.permanent.push_back(record.issued_at, record);
        // Add the new record to the permanent penalty sum
        blacklist_character.permanent_sum =
            blacklist_character.permanent_sum + 
            penalty.destroyed_penalty_factor();
    } else {
        let record = TemporaryBlacklistRecord {
            killmail_id: killmail.id(),
            character_id: killer_character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty.destroyed_penalty_factor(),
            amount_due: penalty.damaged_penalty_fee_multiplier() *average_jump_fee,
            paid_down: 0,
        };
        let issued_at = record.issued_at;
        blacklist_character.temporary.push_back(record.issued_at, record);
        // If the temporary front pointer is none, that means that all existing temporary records have been paid down.
        // So, we need to set the front pointer to the new record since it now needs to be paid down.
        if (blacklist_character.temporary_front_pointer.is_none()) {
            blacklist_character.temporary_front_pointer = option::some(issued_at);
        };
        // Add the new record to the temporary penalty sum
        blacklist_character.temporary_sum =
            blacklist_character.temporary_sum + penalty.destroyed_penalty_factor();
    };
}

/// Pays down a character's temporary blacklist penalty.
public(package) fun pay_down_penalty(blacklist: &mut Blacklist, character_id: ID, mut amount: u64) {
    // If the character is not blacklisted, nothing to pay down
    if (!blacklist.records.contains(character_id)) {
        return
    };

    // Get the blacklist for this character
    let blacklist_character = blacklist.records.borrow_mut(character_id);

    // Keep going as long as there are still outstanding penalties
    while (blacklist_character.temporary_front_pointer.is_some()) {
        // Get the oldest record that still has an outstanding penalty
        let record =
            &mut blacklist_character.temporary[
                *blacklist_character.temporary_front_pointer.borrow(),
            ];
        if (record.paid_down < record.amount_due) {
            let remaining_amount = record.amount_due - record.paid_down;
            if (amount >= remaining_amount) {
                // This payment fully pays down this record, move to the next one
                record.paid_down = record.amount_due;
                amount = amount - remaining_amount;
            } else {
                // This payment partially pays down this record, we're done after this
                record.paid_down = record.paid_down + amount;
                // Remove this from the temporary penalty sum
                blacklist_character.temporary_sum =
                    blacklist_character.temporary_sum - record.penalty_multiplier;
                break
            };
        };
        // Move to the next record
        blacklist_character.temporary_front_pointer =
            *blacklist_character
                .temporary
                .next(*blacklist_character.temporary_front_pointer.borrow());
    };
}

/// Checks if a character is currently blacklisted and returns the applicable penalty multiplier
public(package) fun get_penalty_multiplier(blacklist: &Blacklist, character_id: ID): u64 {
    if (!blacklist.records.contains(character_id)) {
        return 100 // Not blacklisted, normal fee
    };
    let blacklist_character = blacklist.records.borrow(character_id);

    // The penalty multiplier starts at 100 (normal fee) and increases based on the blacklisting records.
    100 + blacklist_character.permanent_sum + blacklist_character.temporary_sum
}
