module fta::jump_history;

use fta::blacklist::Blacklist;
use fta::jump_estimate::JumpEstimate;
use fta::rolling_averager::{Self, RollingAverager};
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};
use sui::table::{Self, Table};

public struct JumpHistoryEntry has copy, store {
    estimate: JumpEstimate,
    character_id: ID,
}

public struct CharacterJumpHistory has store {
    entries: LinkedTable<ID, JumpHistoryEntry>,
    averages: Table<u64, RollingAverager<ID, JumpHistoryEntry>>,
}

public struct JumpHistory has store {
    entries: LinkedTable<ID, JumpHistoryEntry>,
    entries_by_character: LinkedTable<ID, CharacterJumpHistory>,
    averages: Table<u64, RollingAverager<ID, JumpHistoryEntry>>,
}

fun new_character_jump_history(ctx: &mut TxContext): CharacterJumpHistory {
    CharacterJumpHistory {
        entries: linked_table::new(ctx),
        averages: table::new(ctx),
    }
}

public(package) fun new(ctx: &mut TxContext): JumpHistory {
    JumpHistory {
        entries_by_character: linked_table::new(ctx),
        entries: linked_table::new(ctx),
        averages: table::new(ctx),
    }
}

public(package) fun add(
    history: &mut JumpHistory,
    blacklist: &mut Blacklist,
    estimate: JumpEstimate,
    character_id: ID,
    ctx: &mut TxContext,
) {
    // Pay down the character's blacklist penalty based on the fee they just paid for this jump
    blacklist.pay_down_penalty(character_id, estimate.total_unscaled_base_fee());

    // Create the entry
    let entry = JumpHistoryEntry {
        estimate: estimate,
        character_id: character_id,
    };
    // If this is the first time we've seen this character, create a new CharacterJumpHistory for them
    if (!history.entries_by_character.contains(character_id)) {
        history.entries_by_character.push_back(character_id, new_character_jump_history(ctx));
    };
    // Add the entry to the character's history and the overall history
    history.entries_by_character[character_id].entries.push_back(entry.estimate.id(), copy entry);
    history.entries.push_back(entry.estimate.id(), entry);
}

public(package) fun fee_average(
    history: &mut JumpHistory,
    period: u64,
    clock: &Clock,
): Option<u64> {
    // If we don't have an averager for this period, create one
    if (!history.averages.contains(period)) {
        history.averages.add(period, rolling_averager::new(&history.entries, period));
    };
    let averager = &mut history.averages[period];
    // Calculate the average over this period
    averager.average!(
        &history.entries,
        |entry| entry.estimate.total_unscaled_base_fee(),
        |entry| entry.estimate.prepared_at(),
        clock,
    )
}

public(package) fun fee_average_for_character(
    history: &mut JumpHistory,
    character_id: ID,
    period: u64,
    clock: &Clock,
): Option<u64> {
    // If there are no entries for this character, return none
    if (!history.entries_by_character.contains(character_id)) {
        return option::none()
    };
    let character_history = &mut history.entries_by_character[character_id];
    // If we don't have an averager for this period, create one
    if (!character_history.averages.contains(period)) {
        character_history
            .averages
            .add(period, rolling_averager::new(&character_history.entries, period));
    };
    // Calculate the average over this period
    let averager = &mut character_history.averages[period];
    // Calculate the average over this period
    averager.average!(
        &history.entries,
        |entry| entry.estimate.total_unscaled_base_fee(),
        |entry| entry.estimate.prepared_at(),
        clock,
    )
}

public(package) fun fee_total(history: &mut JumpHistory, period: u64, clock: &Clock): u64 {
    // Get the average, which will update all internal values
    history.fee_average(period, clock);
    history.averages[period].rolling_total()
}

public(package) fun fee_total_for_character(
    history: &mut JumpHistory,
    character_id: ID,
    period: u64,
    clock: &Clock,
): u64 {
    // Get the average, which will update all internal values.
    // If this returns none, we have no records for this character, so return 0
    if (history.fee_average_for_character(character_id, period, clock).is_none()) {
        return 0
    };
    history.entries_by_character[character_id].averages[period].rolling_total()
}

public(package) fun fee_count(history: &mut JumpHistory, period: u64, clock: &Clock): u64 {
    // Get the average, which will update all internal values
    history.fee_average(period, clock);
    history.averages[period].rolling_count()
}

public(package) fun fee_count_for_character(
    history: &mut JumpHistory,
    character_id: ID,
    period: u64,
    clock: &Clock,
): u64 {
    // Get the average, which will update all internal values.
    // If this returns none, we have no records for this character, so return 0
    if (history.fee_average_for_character(character_id, period, clock).is_none()) {
        return 0
    };
    history.entries_by_character[character_id].averages[period].rolling_count()
}
