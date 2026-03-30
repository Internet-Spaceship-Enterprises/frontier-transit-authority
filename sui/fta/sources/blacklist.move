module fta::blacklist;

use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};

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
}

// TODO: figure out a way to scale the penalty multiplier based on the severity of the offense and the duration of the blacklist.
public(package) fun new(ctx: &mut TxContext): Blacklist {
    Blacklist {
        records: linked_table::new(ctx),
    }
}

/// Adds a blacklist record for a character.
public(package) fun add(
    blacklist: &mut Blacklist,
    character_id: ID,
    penalty_multiplier: u64,
    permanent: bool,
    penalty_amount: u64,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // If there's no blacklist for this character yet, create one
    if (!blacklist.records.contains(character_id)) {
        blacklist
            .records
            .push_back(
                character_id,
                BlacklistCharacter {
                    permanent: linked_table::new(ctx),
                    temporary: linked_table::new(ctx),
                    permanent_sum: 0,
                    temporary_front_pointer: option::none(),
                    temporary_sum: 0,
                },
            );
    };

    let blacklist_character = blacklist.records.borrow_mut(character_id);
    if (permanent) {
        // Create the record to be inserted
        let record = PermanentBlacklistRecord {
            character_id: character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty_multiplier,
        };
        blacklist_character.permanent.push_back(record.issued_at, record);
        // Add the new record to the permanent penalty sum
        blacklist_character.permanent_sum = blacklist_character.permanent_sum + penalty_multiplier;
    } else {
        let record = TemporaryBlacklistRecord {
            character_id: character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty_multiplier,
            amount_due: penalty_amount,
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
        blacklist_character.temporary_sum = blacklist_character.temporary_sum + penalty_multiplier;
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
