module fta::fee_history;

use fta::constants;
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};

#[error(code = 1)]
const ENotEnoughNotice: vector<u8> =
    b"You have not provided enough notice for the fee change (takes_effect_on is too soon)";
#[error(code = 2)]
const EFeeChangePending: vector<u8> =
    b"You cannot schedule a fee change when there is already a fee change pending";
#[error(code = 3)]
const ENoFeeActive: vector<u8> = b"No jump fee is currently active";
#[error(code = 4)]
const EFeeIncreaseTooLarge: vector<u8> = b"This is too large of a fee increase";
#[error(code = 5)]
const ENoFeeChange: vector<u8> = b"The new fee is the same as the existing fee";

public struct Fee has drop, store {
    // The fee, in EVE tokens
    jump_fee: u64,
    // The timestamp (milliseconds) when the fee takes effect
    takes_effect_on: u64,
    // The timestamp (milliseconds) when the new fee was submitted
    submitted_on: u64,
}

public struct FeeHistory has store {
    history: LinkedTable<u64, Fee>,
}

public(package) fun new(
    intial_jump_fee: u64,
    created_timestamp: u64,
    ctx: &mut TxContext,
): FeeHistory {
    let mut tab = linked_table::new<u64, Fee>(ctx);
    tab.push_back(
        created_timestamp,
        Fee {
            jump_fee: intial_jump_fee,
            takes_effect_on: created_timestamp,
            submitted_on: created_timestamp,
        },
    );
    FeeHistory {
        history: tab,
    }
}

public(package) fun destroy(fee_history: FeeHistory) {
    let FeeHistory {
        history: history,
    } = fee_history;
    history.drop();
}

public(package) fun update_fee(
    fee_history: &mut FeeHistory,
    jump_fee: u64,
    takes_effect_on: u64,
    clock: &Clock,
) {
    // Ensure that enough notice is given for the change
    assert!(
        takes_effect_on - clock.timestamp_ms() >= constants::fee_change_minimum_notice(),
        ENotEnoughNotice,
    );
    // Get the key for the last fee modification
    let last_modified_key_option = fee_history.history.back();

    // Ensure a value was found (there should always be, since one is created in the init() function)
    assert!(option::is_some(last_modified_key_option), ENoFeeActive);

    // Get the latest change
    let latest_change = fee_history.history.borrow(*last_modified_key_option.borrow());

    // Ensure that the latest change is active, not pending.
    // This prevents scheduling a new change when the last change hasn't taken effect yet.
    assert!(latest_change.takes_effect_on <= clock.timestamp_ms(), EFeeChangePending);

    // Ensure there's actually a change to the fee
    assert!(jump_fee != latest_change.jump_fee, ENoFeeChange);

    // Ensure that either it's a fee reduction, or the increase is within the limit
    assert!(
        jump_fee < latest_change.jump_fee || (jump_fee - latest_change.jump_fee) * 100000 / latest_change.jump_fee <= constants::fee_change_max_percentage() * 1000,
        EFeeIncreaseTooLarge,
    );

    fee_history
        .history
        .push_back(
            clock.timestamp_ms(),
            Fee {
                jump_fee: jump_fee,
                takes_effect_on: takes_effect_on,
                submitted_on: clock.timestamp_ms(),
            },
        );
}

/// Retrieves the current per-jump fee (in EVE tokens) for a given gate
public(package) fun current_fee(fee_history: &FeeHistory, clock: &Clock): u64 {
    // Get the key for the last fee modification
    let last_modified_key_option = fee_history.history.back();

    // Ensure a value was found (there should always be, since one is created in the init() function)
    assert!(option::is_some(last_modified_key_option), ENoFeeActive);

    // Borrow the value from the option
    let latest_fee_key = *last_modified_key_option.borrow();

    // Get the latest change
    let latest_fee = fee_history.history.borrow(latest_fee_key);

    // If the latest fee is active, use it
    if (latest_fee.takes_effect_on <= clock.timestamp_ms()) {
        latest_fee.jump_fee
    } else {
        // Otherwise, get the previous fee, which MUST be active since we don't allow
        // setting a new fee while a fee change is pending.
        let prev_fee_key_option = fee_history.history.prev(latest_fee_key);
        assert!(option::is_some(prev_fee_key_option), ENoFeeActive);
        let prev_fee_key = *prev_fee_key_option.borrow();

        let prev_fee = fee_history.history.borrow(prev_fee_key);
        assert!(prev_fee.takes_effect_on <= clock.timestamp_ms(), ENoFeeActive);
        prev_fee.jump_fee
    }
}
