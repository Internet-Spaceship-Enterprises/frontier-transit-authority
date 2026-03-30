module fta::access;

use fta::fta::{FrontierTransitAuthority, get_owner_character};
use sui::transfer::Receiving;
use world::access::{OwnerCap, ReturnOwnerCapReceipt};
use world::character::Character;
use world::gate::Gate;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const EWrongOwnerCap: vector<u8> = b"The provided OwnerCap is not the right one for this gate";
#[error(code = 3)]
const EWrongCharacter: vector<u8> =
    b"The provided character is not the character that holds FTA gate ownership";

/// Borrows an OwnerCap<Gate> from the FTA for privileged operations
public(package) fun borrow_gate_owner_cap(
    fta: &FrontierTransitAuthority,
    character: &mut Character,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &TxContext,
): (OwnerCap<Gate>, ReturnOwnerCapReceipt) {
    // Ensure FTA controls the gate
    assert!(fta.gate_registered(gate), EGateNotInNetwork);
    assert!(object::id(character) == fta.get_owner_character(), EWrongCharacter);

    // Get the owner cap and receipt
    let (owner_cap, receipt) = character.borrow_owner_cap(cap_ticket, ctx);

    // Ensure the correct OwnerCap was passed in
    assert!(gate.owner_cap_id() == object::id(&owner_cap), EWrongOwnerCap);
    (owner_cap, receipt)
}

/// Returns an OwnerCap<Gate> to the FTA
public(package) fun return_gate_owner_cap(
    fta: &FrontierTransitAuthority,
    owner_cap: OwnerCap<Gate>,
    receipt: ReturnOwnerCapReceipt,
    ctx: &mut TxContext,
) {
    owner_cap.transfer_owner_cap_with_receipt(
        receipt,
        fta.get_owner_character().to_address(),
        ctx,
    );
}
