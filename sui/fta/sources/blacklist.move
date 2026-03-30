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
                },
            );
    };

    if (permanent) {
        // Create the record to be inserted
        let record = PermanentBlacklistRecord {
            character_id: character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty_multiplier,
        };
        blacklist.records.borrow_mut(character_id).permanent.push_back(record.issued_at, record);
    } else {
        let record = TemporaryBlacklistRecord {
            character_id: character_id,
            issued_at: clock.timestamp_ms(),
            penalty_multiplier: penalty_multiplier,
            amount_due: 0, // TODO: calculate based on average fee
            paid_down: 0,
        };
        blacklist.records.borrow_mut(character_id).temporary.push_back(record.issued_at, record);
    };
}

/// Checks if a character is currently blacklisted and returns the applicable penalty multiplier
public(package) fun get_penalty_multiplier(
    blacklist: &Blacklist,
    character_id: ID,
    clock: &Clock,
): u64 {
    if (!blacklist.records.contains(character_id)) {
        return 100; // Not blacklisted, normal fee
    };
    let blacklist_character = blacklist.records.borrow(character_id);

    let mut total_penalty_multiplier = 100; // Start with normal fee

    // Add permanent penalties
    let mut key = blacklist_character.permanent.front();
    while (key.is_some()) {
        total_penalty_multiplier =
            total_penalty_multiplier + blacklist_character.permanent[*key.borrow()].penalty_multiplier;
        key = blacklist_character.permanent.next(*key.borrow());
    };

    // Add temporary penalties that have not yet expired
    key = blacklist_character.temporary.back();
    while(key.is_some()) {
        let record = &blacklist_character.temporary[*key.borrow()];
        if(record.)
        
        if (record.end == 0 || clock.timestamp_ms() <= record.end) {
            total_penalty_multiplier =
                total_penalty_multiplier + record.penalty_multiplier;
        };
        key = blacklist_character.temporary.prev(*key.borrow());
    };

    if (record.end != 0 && clock.timestamp_ms() > record.end) {
        return 1; // Blacklist expired, normal fee
    };
    record.penalty_multiplier
}
