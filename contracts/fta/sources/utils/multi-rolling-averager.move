module fta::multi_rolling_averager;

use fta::rolling_averager::{Self, RollingAverager};
use sui::clock::Clock;
use sui::linked_table::LinkedTable;
use sui::table::{Self, Table};

#[error(code = 1)]
const EAveragerNotFound: vector<u8> = b"No averager found for the specified period";

public struct MultiRollingAverager<K: copy + drop + store, phantom V: store> has store {
    data_table_id: ID,
    averages: Table<u64, RollingAverager<K, V>>,
}

public(package) fun new<K: copy + drop + store, V: store>(
    table: &LinkedTable<K, V>,
    ctx: &mut TxContext,
): MultiRollingAverager<K, V> {
    MultiRollingAverager {
        data_table_id: object::id(table),
        averages: table::new(ctx),
    }
}

public(package) fun data_table_id<K: copy + drop + store, V: store>(
    multi_averager: &MultiRollingAverager<K, V>,
): ID {
    multi_averager.data_table_id
}

public(package) fun averages<K: copy + drop + store, V: store>(
    multi_averager: &MultiRollingAverager<K, V>,
): &Table<u64, RollingAverager<K, V>> {
    &multi_averager.averages
}

public(package) fun averages_mut<K: copy + drop + store, V: store>(
    multi_averager: &mut MultiRollingAverager<K, V>,
): &mut Table<u64, RollingAverager<K, V>> {
    &mut multi_averager.averages
}

public(package) fun destroy<K: copy + drop + store, V: store>(
    multi_averager: MultiRollingAverager<K, V>,
) {
    let MultiRollingAverager {
        data_table_id: _,
        averages: averages,
    } = multi_averager;
    averages.drop();
}

public(package) fun averager<K: copy + drop + store, V: store>(
    multi_averager: &MultiRollingAverager<K, V>,
    period: u64,
): &RollingAverager<K, V> {
    assert!(multi_averager.averages.contains(period), EAveragerNotFound);
    &multi_averager.averages[period]
}

/// Gets the average value over a specified period
public(package) macro fun average<$K: copy + drop + store, $V: store>(
    $multi_averager: &mut MultiRollingAverager<$K, $V>,
    $table: &LinkedTable<$K, $V>,
    $period: u64,
    $value_lambda: |&$K| -> u64,
    $timestamp_lambda: |&$K| -> u64,
    $clock: &Clock,
): Option<u64> {
    let multi_averager = $multi_averager;
    let averages = multi_averager.averages_mut();
    // If we don't have an averager for this period, create one
    if (!averages.contains($period)) {
        averages.add($period, rolling_averager::new($table, $period));
    };
    let averager = &mut averages[$period];
    // Calculate the average over this period
    averager.average!($table, |key| $value_lambda(key), |key| $timestamp_lambda(key), $clock)
}

/// Gets the total value over a specified period
public(package) macro fun rolling_total<$K: copy + drop + store, $V: store>(
    $multi_averager: &mut MultiRollingAverager<$K, $V>,
    $table: &LinkedTable<$K, $V>,
    $period: u64,
    $value_lambda: |&$K| -> u64,
    $timestamp_lambda: |&$K| -> u64,
    $clock: &Clock,
): u64 {
    let multi_averager = $multi_averager;
    multi_averager.average!(
        $table,
        $period,
        |key| $value_lambda(key),
        |key| $timestamp_lambda(key),
        $clock,
    );
    multi_averager.averager($period).rolling_total()
}

/// Gets the number of data points over a specified period
public(package) macro fun rolling_count<$K: copy + drop + store, $V: store>(
    $multi_averager: &mut MultiRollingAverager<$K, $V>,
    $table: &LinkedTable<$K, $V>,
    $period: u64,
    $value_lambda: |&$K| -> u64,
    $timestamp_lambda: |&$K| -> u64,
    $clock: &Clock,
): u64 {
    let multi_averager = $multi_averager;
    multi_averager.average!(
        $table,
        $period,
        |key| $value_lambda(key),
        |key| $timestamp_lambda(key),
        $clock,
    );
    multi_averager.averager($period).rolling_count()
}
