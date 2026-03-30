module fta::jump_history;

use fta::blacklist::Blacklist;
use fta::jump_estimate::JumpEstimate;
use fta::multi_rolling_averager::{Self, MultiRollingAverager};
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};

public struct JumpHistoryEntry has copy, store {
    estimate: JumpEstimate,
    character_id: ID,
}

// TODO: replace with MultiRollingAverager
public struct CharacterJumpHistory has store {
    entries: LinkedTable<ID, JumpHistoryEntry>,
    averager: MultiRollingAverager<ID, JumpHistoryEntry>,
}

public struct JumpHistory has store {
    entries: LinkedTable<ID, JumpHistoryEntry>,
    averager: MultiRollingAverager<ID, JumpHistoryEntry>,
    entries_by_character: LinkedTable<ID, CharacterJumpHistory>,
}

fun new_character_jump_history(ctx: &mut TxContext): CharacterJumpHistory {
    let table = linked_table::new(ctx);
    let averager = multi_rolling_averager::new(&table, ctx);

    CharacterJumpHistory {
        entries: table,
        averager: averager,
    }
}

public(package) fun new(ctx: &mut TxContext): JumpHistory {
    let table = linked_table::new(ctx);
    let averager = multi_rolling_averager::new(&table, ctx);

    JumpHistory {
        entries_by_character: linked_table::new(ctx),
        entries: table,
        averager: averager,
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
    // Calculate the average over this period
    history
        .averager
        .average!(
            &history.entries,
            period,
            |key| history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| history.entries[*key].estimate.prepared_at(),
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
    // Calculate the average over this period
    character_history
        .averager
        .average!(
            &history.entries,
            period,
            |key| character_history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| character_history.entries[*key].estimate.prepared_at(),
            clock,
        )
}

public(package) fun fee_total(history: &mut JumpHistory, period: u64, clock: &Clock): u64 {
    history
        .averager
        .rolling_total!(
            &history.entries,
            period,
            |key| history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| history.entries[*key].estimate.prepared_at(),
            clock,
        )
}

public(package) fun fee_total_for_character(
    history: &mut JumpHistory,
    character_id: ID,
    period: u64,
    clock: &Clock,
): u64 {
    // If there are no entries for this character, return none
    if (!history.entries_by_character.contains(character_id)) {
        return 0
    };
    let character_history = &mut history.entries_by_character[character_id];
    character_history
        .averager
        .rolling_total!(
            &character_history.entries,
            period,
            |key| character_history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| character_history.entries[*key].estimate.prepared_at(),
            clock,
        )
}

public(package) fun fee_count(history: &mut JumpHistory, period: u64, clock: &Clock): u64 {
    history
        .averager
        .rolling_count!(
            &history.entries,
            period,
            |key| history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| history.entries[*key].estimate.prepared_at(),
            clock,
        )
}

public(package) fun fee_count_for_character(
    history: &mut JumpHistory,
    character_id: ID,
    period: u64,
    clock: &Clock,
): u64 {
    // If there are no entries for this character, return none
    if (!history.entries_by_character.contains(character_id)) {
        return 0
    };
    let character_history = &mut history.entries_by_character[character_id];
    character_history
        .averager
        .rolling_count!(
            &character_history.entries,
            period,
            |key| character_history.entries[*key].estimate.total_unscaled_base_fee(),
            |key| character_history.entries[*key].estimate.prepared_at(),
            clock,
        )
}
