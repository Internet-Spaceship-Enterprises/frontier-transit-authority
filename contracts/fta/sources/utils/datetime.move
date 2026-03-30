module fta::datetime;

use sui::clock::Clock;

fun is_leap_year(year: u64): bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

fun days_in_month(month: u64, is_leap_year: bool): u64 {
    match (month) {
        0 => 31,
        1 => if (is_leap_year) { 29 } else { 28 },
        2 => 31,
        3 => 30,
        4 => 31,
        5 => 30,
        6 => 31,
        7 => 31,
        8 => 30,
        9 => 31,
        10 => 30,
        11 => 31,
        _ => 0,
    }
}

/// Converts a timestamp in milliseconds since the Unix epoch to a human-readable datetime string in the format "YYYY-MM-DD HH:MM:SS" (in UTC time)
public fun datetime_from_timestamp_ms(timestamp_ms: u64): std::string::String {
    // Split the timestamp into full days, then remaining hours, minutes, and seconds
    let mut days = timestamp_ms / 1000 / 60 / 60 / 24;
    let hours = (timestamp_ms / 1000 / 60 / 60) % 24;
    let minutes = (timestamp_ms / 1000 / 60) % 60;
    let seconds = (timestamp_ms / 1000) % 60;

    // Calculate the year
    let mut year = 1970;
    while (true) {
        let days_in_year = if (is_leap_year(year)) { 366 } else { 365 };
        if (days_in_year <= days) {
            days = days - days_in_year;
            year = year + 1;
        } else {
            break
        }
    };

    // Calculate the month and day
    let mut month = 0;
    while (true) {
        let days_in_current_month = days_in_month(month, is_leap_year(year));
        if (days_in_current_month <= days) {
            days = days - days_in_current_month;
            month = month + 1;
        } else {
            break
        }
    };

    let mut datetime = std::u64::to_string(year);
    datetime.append(b"-".to_string());
    if (month < 9) {
        datetime.append(b"0".to_string());
    };
    datetime.append(std::u64::to_string(month + 1)); // month is 0-indexed, so add 1 for human-readable format
    datetime.append(b"-".to_string());
    if (days < 9) {
        datetime.append(b"0".to_string());
    };
    datetime.append(std::u64::to_string(days + 1)); // day is 0-indexed, so add 1 for human-readable format
    datetime.append(b" ".to_string());
    if (hours < 10) {
        datetime.append(b"0".to_string());
    };
    datetime.append(std::u64::to_string(hours));
    datetime.append(b":".to_string());
    if (minutes < 10) {
        datetime.append(b"0".to_string());
    };
    datetime.append(std::u64::to_string(minutes));
    datetime.append(b":".to_string());
    if (seconds < 10) {
        datetime.append(b"0".to_string());
    };
    datetime.append(std::u64::to_string(seconds));

    datetime
}

/// Gets the current datetime as a human-readable datetime string in the format "YYYY-MM-DD HH:MM:SS" (in UTC time)
public fun datetime(clock: &Clock): std::string::String {
    datetime_from_timestamp_ms(clock.timestamp_ms())
}
