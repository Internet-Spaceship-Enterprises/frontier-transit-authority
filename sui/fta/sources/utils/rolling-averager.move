module fta::rolling_averager;

use sui::clock::Clock;
use sui::linked_table::LinkedTable;

public struct RollingAverager<K: copy + drop + store, phantom V: store> has copy, drop, store {
    /// The ID of the table we're averaging over. We store this so that we can verify that the correct table is passed in during the average calculation.
    table_id: ID,
    /// The period, in milliseconds, that we average over
    period: u64,
    /// Points to the record closest to the front of the table that is within the last calculated average.
    /// This is an exclusive key, i.e. the value it points to is not included in the average, but all values after it are.
    front_key: Option<K>,
    /// Points to the record closest to the back of the table that is within the last calculated average.
    /// This is an inclusive key, i.e. the value it points to is included in the average.
    back_key: Option<K>,
    /// Tracks the rolling sum in the range (front_key, back_key]
    rolling_total: u64,
    /// Tracks the rolling number of elements in the range (front_key, back_key]
    rolling_count: u64,
}

public(package) fun new<K: copy + drop + store, V: store>(
    table: &LinkedTable<K, V>,
    period: u64,
): RollingAverager<K, V> {
    RollingAverager {
        table_id: object::id(table),
        period: period,
        front_key: option::none(),
        back_key: option::none(),
        rolling_total: 0,
        rolling_count: 0,
    }
}

public(package) fun table_id<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): ID {
    averager.table_id
}

public(package) fun period<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): u64 {
    averager.period
}

public(package) fun front_key<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): Option<K> {
    averager.front_key
}

public(package) fun back_key<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): Option<K> {
    averager.back_key
}

public(package) fun rolling_total<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): u64 {
    averager.rolling_total
}

public(package) fun rolling_count<K: copy + drop + store, V: store>(
    averager: &RollingAverager<K, V>,
): u64 {
    averager.rolling_count
}

public(package) fun set_front_key<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
    key: Option<K>,
) {
    averager.front_key = key;
}

public(package) fun set_back_key<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
    key: Option<K>,
) {
    averager.back_key = key;
}

public(package) fun add_to_rolling_total<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
    new_val: u64,
) {
    averager.rolling_total = averager.rolling_total + new_val;
}

public(package) fun subtract_from_rolling_total<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
    new_val: u64,
) {
    averager.rolling_total = averager.rolling_total - new_val;
}

public(package) fun increment_rolling_count<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
) {
    averager.rolling_count = averager.rolling_count + 1;
}

public(package) fun decrement_rolling_count<K: copy + drop + store, V: store>(
    averager: &mut RollingAverager<K, V>,
) {
    averager.rolling_count = averager.rolling_count - 1;
}

/// Gets the average value
public(package) macro fun average<$K: copy + drop + store, $V: store>(
    $averager: &mut RollingAverager<$K, $V>,
    $table: &LinkedTable<$K, $V>,
    $value_lambda: |&$V| -> u64,
    $timestamp_lambda: |&$V| -> u64,
    $clock: &Clock,
): Option<u64> {
    let averager = $averager;
    let table = $table;
    let clock = $clock;

    // Verify that the correct table is being passed in
    assert!(object::id($table) == averager.table_id());

    let cutoff = clock.timestamp_ms() - averager.period();
    // If the back key is none, that indicates that the struct has never been initialized or has never had a record entered.
    // In that case, run the first-time initialization.
    if (averager.back_key().is_none()) {
        // When first initializing, both the back and front are the back of the table
        averager.set_front_key(*table.back());
        averager.set_back_key(*table.back());
        // If there is no back, then the table is empty, return none
        if (averager.front_key().is_none()) {
            return option::none()
        };
        // Calculate the average for the first time. We do this by starting at the back and
        // working towards the front until we hit the cutoff, keeping a running total and count to calculate the average
        while (true) {
            let front_key = averager.front_key();
            // If we've reached the front of the table or the current front entry is before the cutoff, then we're done
            if (front_key.is_none() || $timestamp_lambda(&table[*front_key.borrow()]) < cutoff) {
                break
            };
            // Otherwise, we're still after the cutoff, so include this entry in the average and move the front key back
            averager.add_to_rolling_total($value_lambda(&table[*front_key.borrow()]));
            averager.increment_rolling_count();
            // This entry is still within the cutoff, move the front key back
            averager.set_front_key(*table.prev(*front_key.borrow()));
        };
    } else {
        // The table has already been initialized, now we need to move the front and back pointers

        // Move the front key forward until we hit the cutoff, removing those entries from the rolling total and count.
        while (true) {
            // Look at the next entry
            let next_key = if (averager.front_key().is_none()) {
                table.front()
            } else {
                table.next(*averager.front_key().borrow())
            };
            // If the next entry is none or it is after the cutoff, then we're done
            if (next_key.is_none() || $timestamp_lambda(&table[*next_key.borrow()]) >= cutoff) {
                break
            };
            // The next entry is before the cutoff, so remove it from the average and move the front key forward
            averager.subtract_from_rolling_total($value_lambda(&table[*next_key.borrow()]));
            averager.decrement_rolling_count();
            averager.set_front_key(*table.next(*next_key.borrow()));
        };

        // Move the back key forward until we reach the end of the table
        while (true) {
            // Look at the next entry
            let next_key = table.next(*averager.back_key().borrow());
            // If there is no next entry, then we're done
            if (next_key.is_none()) {
                break
            };
            // Add the next entry's value to the rolling total
            averager.add_to_rolling_total($value_lambda(&table[*next_key.borrow()]));
            averager.increment_rolling_count();
            averager.set_back_key(*next_key);
        };
    };

    // If there are no samples, return none to avoid dividing by zero. Otherwise, return the average.
    if (averager.rolling_count() == 0) {
        option::none()
    } else {
        option::some(averager.rolling_total() / averager.rolling_count())
    }
}
