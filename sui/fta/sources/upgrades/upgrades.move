module fta::upgrades;

use fta::constants;
use fta::jump_history::JumpHistory;
use sui::clock::Clock;
use sui::linked_table::{Self, LinkedTable};
use sui::package;
use world::character::Character;

#[error(code = 1)]
const EActiveUpgradeProposalExists: vector<u8> = b"An active upgrade proposal already exists";
#[error(code = 2)]
const ENoActiveUpgradeProposal: vector<u8> = b"There is no active upgrade proposal";
#[error(code = 3)]
const EWrongCharacter: vector<u8> = b"Character does not match the sender";
#[error(code = 4)]
const EVotingClosed: vector<u8> = b"Voting for this upgrade proposal has closed";
#[error(code = 5)]
const EAlreadyVoted: vector<u8> = b"Character has already voted";
#[error(code = 6)]
const EWrongDigest: vector<u8> = b"Digest does not match the active proposal";
#[error(code = 7)]
const EVotingInProgress: vector<u8> = b"Voting for this upgrade proposal is still in progress";
#[error(code = 8)]
const EVoteFailed: vector<u8> =
    b"Voting for this upgrade proposal has failed (more votes against than in favour)";
#[error(code = 9)]
const EVotePassed: vector<u8> =
    b"Voting for this upgrade proposal has passed (more votes in favour than against)";

public struct UpgradeCap has key, store {
    id: UID,
    cap: package::UpgradeCap,
}

public struct UpgradeProposalVote has drop, store {
    voted_on: u64,
    in_favour: bool,
    weight: u64,
}

/// Represents an upgrade proposal
public struct UpgradeProposal has store {
    /// The digest of the new package being proposed
    digest: vector<u8>,
    /// The time at which the upgrade was proposed (in milliseconds since Unix Epoch)
    proposed_at: u64,
    /// The time at which voting for the upgrade closes (in milliseconds since Unix Epoch)
    voting_closes_at: u64,
    /// Track the votes
    votes: LinkedTable<ID, UpgradeProposalVote>,
}

public struct UpgradeManager has store {
    /// The currently proposed upgrade, if any
    current_proposal: Option<UpgradeProposal>,
}

/// Exchange the default UpgradeCap for a custom one with much stricter permissions.
public(package) fun new_upgrade_cap(
    original_upgrade_cap: package::UpgradeCap,
    ctx: &mut TxContext,
): UpgradeCap {
    UpgradeCap {
        id: object::new(ctx),
        cap: original_upgrade_cap,
    }
}

/// Exchange the default UpgradeCap for a custom one with much stricter permissions.
public(package) fun new_upgrade_manager(): UpgradeManager {
    UpgradeManager {
        current_proposal: option::none(),
    }
}

/// Propose a new package upgrade.
/// Only the developers (holders of the modified UpgradeCap) can call this function.
public(package) fun propose(
    upgrade_manager: &mut UpgradeManager,
    digest: vector<u8>,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    // Ensure there is not already an active proposal
    assert!(upgrade_manager.current_proposal.is_none(), EActiveUpgradeProposalExists);

    let now = clock.timestamp_ms();
    let voting_period_ms: u64 = constants::upgrade_vote_validity_duration(); // 7 days in milliseconds

    upgrade_manager
        .current_proposal
        .fill(UpgradeProposal {
            digest,
            proposed_at: now,
            voting_closes_at: now + voting_period_ms,
            votes: linked_table::new(ctx),
        });
}

/// Clears the current upgrade proposal
public(package) fun clear_proposal(upgrade_manager: &mut UpgradeManager) {
    // Only allow clearing if there is an active proposal
    assert!(upgrade_manager.current_proposal.is_some(), ENoActiveUpgradeProposal);

    let UpgradeProposal {
        digest: _,
        proposed_at: _,
        voting_closes_at: _,
        votes: votes,
    } = upgrade_manager.current_proposal.extract();
    votes.drop();
}

/// Vote on a proposal
public(package) fun vote(
    upgrade_manager: &mut UpgradeManager,
    character: &Character,
    in_favour: bool,
    jump_history: &mut JumpHistory,
    clock: &Clock,
    ctx: &TxContext,
) {
    // Only allow voting if there is an active proposal
    assert!(upgrade_manager.current_proposal.is_some(), ENoActiveUpgradeProposal);

    let proposal = upgrade_manager.current_proposal.borrow_mut();

    // Ensure voting is still open
    assert!(proposal.voting_closes_at > clock.timestamp_ms(), EVotingClosed);

    // Ensure the character voting is the sender
    assert!(character.character_address() == ctx.sender(), EWrongCharacter);

    // Ensure the character has not already voted
    assert!(!proposal.votes.contains(character.id()), EAlreadyVoted);

    // Calculate the character's vote weight
    let vote_weight = jump_history.fee_total_for_character(
        character.id(),
        constants::upgrade_vote_weight_duration(),
        clock,
    );

    // Apply a square root scaling factor to the vote weight to prevent whales from having disproportionate influence on upgrade proposals,
    // while still giving more active characters more voting power than inactive ones.
    let vote_weight_scaled = std::u64::sqrt(vote_weight);

    // Record the vote
    proposal
        .votes
        .push_back(
            character.id(),
            UpgradeProposalVote {
                voted_on: clock.timestamp_ms(),
                in_favour,
                weight: vote_weight_scaled,
            },
        );
}

/// Tallies the votes for a proposal
fun tally_votes(upgrade_manager: &UpgradeManager, clock: &Clock): (u64, u64) {
    // Only allow voting if there is an active proposal
    assert!(upgrade_manager.current_proposal.is_some(), ENoActiveUpgradeProposal);

    let proposal = upgrade_manager.current_proposal.borrow();

    // Ensure the voting is now closed
    assert!(proposal.voting_closes_at <= clock.timestamp_ms(), EVotingInProgress);

    // Tally the votes
    let mut in_favour: u64 = 0;
    let mut against: u64 = 0;

    let mut key = proposal.votes.front();
    while (key.is_some()) {
        let vote = &proposal.votes[*key.borrow()];
        if (vote.in_favour) {
            in_favour = in_favour + vote.weight;
        } else {
            against = against + vote.weight;
        };
        key = proposal.votes.next(*key.borrow());
    };
    (in_favour, against)
}

/// Clears a failed proposal after voting has concluded and the result has been determined to be a failure
public(package) fun clear_failed_proposal(upgrade_manager: &mut UpgradeManager, clock: &Clock) {
    // This tallies the votes, but also ensures the all necessary conditions have been met
    let (in_favour, against) = upgrade_manager.tally_votes(clock);

    // Ensure the vote has failed
    assert!(in_favour < against, EVotePassed);

    // Clear the failed proposal
    upgrade_manager.clear_proposal();
}

/// Checks the voting on a proposal to authorize the upgrade if it has passed
public(package) fun authorize_upgrade(
    upgrade_manager: &mut UpgradeManager,
    cap: &mut UpgradeCap,
    digest: vector<u8>,
    clock: &Clock,
): package::UpgradeTicket {
    // This tallies the votes, but also ensures the all necessary conditions have been met
    let (in_favour, against) = upgrade_manager.tally_votes(clock);

    // Ensure the vote has passed
    assert!(in_favour >= against, EVoteFailed);

    // Ensure the digest matches the active proposal
    assert!(digest == upgrade_manager.current_proposal.borrow().digest, EWrongDigest);

    // Clear the proposal so there's space for the next one
    upgrade_manager.clear_proposal();

    // Authorize the upgrade and return the UpgradeTicket
    cap.cap.authorize_upgrade(package::compatible_policy(), digest)
}

/// Commits the upgrade after it has been authorized and the new package has been published.
public fun commit_upgrade(cap: &mut UpgradeCap, receipt: package::UpgradeReceipt) {
    cap.cap.commit_upgrade(receipt)
}
