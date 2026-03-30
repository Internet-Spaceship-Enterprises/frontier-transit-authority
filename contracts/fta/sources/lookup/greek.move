module fta::greek;

#[test_only]
use std::unit_test::assert_eq;

#[error(code = 1)]
const ENumberToLarge: vector<u8> = b"Input number is too large to represent with this many words";
#[error(code = 2)]
const ENoWords: vector<u8> = b"You cannot specify 0 words";

const NUMBERS_PER_WORD: u64 = 24;

fun lookup_single(num: u64): std::string::String {
    match (num) {
        0 => b"Alpha".to_string(),
        1 => b"Beta".to_string(),
        2 => b"Gamma".to_string(),
        3 => b"Delta".to_string(),
        4 => b"Epsilon".to_string(),
        5 => b"Zeta".to_string(),
        6 => b"Eta".to_string(),
        7 => b"Theta".to_string(),
        8 => b"Iota".to_string(),
        9 => b"Kappa".to_string(),
        10 => b"Lambda".to_string(),
        11 => b"Mu".to_string(),
        12 => b"Nu".to_string(),
        13 => b"Xi".to_string(),
        14 => b"Omicron".to_string(),
        15 => b"Pi".to_string(),
        16 => b"Rho".to_string(),
        17 => b"Sigma".to_string(),
        18 => b"Tau".to_string(),
        19 => b"Upsilon".to_string(),
        20 => b"Phi".to_string(),
        21 => b"Chi".to_string(),
        22 => b"Psi".to_string(),
        23 => b"Omega".to_string(),
        _ => abort ENumberToLarge,
    }
}

public fun max(words: u8): u64 {
    if (words == 0) {
        0
    } else {
        std::u64::pow(NUMBERS_PER_WORD, words)
    }
}

public fun lookup(num: u64, words: u8): std::string::String {
    assert!(num <= std::u64::pow(NUMBERS_PER_WORD, words), ENumberToLarge);
    assert!(words > 0, ENoWords);

    let mut result = b"".to_string();
    let mut word_idx = 0;
    let mut remaining = num;
    while (word_idx < words) {
        if (word_idx > 0) {
            result.append(b" ".to_string());
        };
        let factor = std::u64::pow(NUMBERS_PER_WORD, words - word_idx - 1);
        result.append(lookup_single(remaining / factor));
        remaining = remaining % factor;
        word_idx = word_idx + 1;
    };
    result
}

#[test]
fun words_1() {
    assert_eq!(lookup(9284, 3), b"Rho Gamma Phi".to_string());
}

#[test]
fun words_2() {
    assert_eq!(lookup(18793, 4), b"Beta Iota Pi Beta".to_string());
}
