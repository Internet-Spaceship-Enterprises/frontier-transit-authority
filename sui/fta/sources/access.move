module fta::access;

use fta::fta::FrontierTransitAuthority;
use sui::transfer::Receiving;
use world::access::{Self, OwnerCap};
use world::gate::Gate;

#[error(code = 1)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 2)]
const EWrongOwnerCap: vector<u8> = b"The provided OwnerCap is not the right one for this gate";
#[error(code = 3)]
const EWrongSender: vector<u8> =
    b"The returned OwnerCap receipt does not match the sender of the transaction";

public struct OwnerCapReceipt<phantom T> {
    owner_id: address,
    owner_cap_id: ID,
}

fun borrow_owner_cap<T: key>(
    fta: &mut FrontierTransitAuthority,
    cap_ticket: Receiving<OwnerCap<T>>,
    ctx: &TxContext,
): (OwnerCap<T>, OwnerCapReceipt<T>) {
    // Get the owner cap and receipt
    let owner_cap = access::receive_owner_cap(fta.uid_mut(), cap_ticket);
    let receipt = OwnerCapReceipt<T> {
        owner_id: ctx.sender(),
        owner_cap_id: object::id(&owner_cap),
    };
    (owner_cap, receipt)
}

/// Returns an OwnerCap<Gate> to the FTA
public(package) fun return_owner_cap<T: key>(
    fta: &FrontierTransitAuthority,
    owner_cap: OwnerCap<T>,
    receipt: OwnerCapReceipt<T>,
    ctx: &TxContext,
) {
    // Ensure the right thing is being returned
    assert!(object::id(&owner_cap) == receipt.owner_cap_id, EWrongOwnerCap);
    assert!(ctx.sender() == receipt.owner_id, EWrongSender);
    access::transfer_owner_cap(owner_cap, object::id(fta).to_address());
    // Consume the receipt
    let OwnerCapReceipt<T> {
        owner_id: _,
        owner_cap_id: _,
    } = receipt;
}

// Transfers an OwnerCap to a recipient outside of the FTA
public(package) fun transfer_owner_cap<T: key>(
    fta: &mut FrontierTransitAuthority,
    cap_ticket: Receiving<OwnerCap<T>>,
    recipient: address,
    ctx: &TxContext,
) {
    let (
        cap,
        OwnerCapReceipt<T> {
            owner_id: _,
            owner_cap_id: _,
        },
    ) = borrow_owner_cap(fta, cap_ticket, ctx);
    access::transfer_owner_cap(cap, recipient);
}

/// Borrows an OwnerCap<Gate> from the FTA for privileged operations
public(package) fun borrow_gate_owner_cap(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &TxContext,
): (OwnerCap<Gate>, OwnerCapReceipt<Gate>) {
    // Ensure FTA controls the gate
    assert!(fta.gate_registry().registered(gate), EGateNotInNetwork);

    // Get the owner cap and receipt
    let (owner_cap, receipt) = borrow_owner_cap(fta, cap_ticket, ctx);

    // Ensure the correct OwnerCap was passed in
    assert!(gate.owner_cap_id() == object::id(&owner_cap), EWrongOwnerCap);
    (owner_cap, receipt)
}

/// Borrows an OwnerCap<Gate> from the FTA for privileged operations, without a return receipt (DANGEROUS)
public(package) fun borrow_gate_owner_cap_no_receipt(
    fta: &mut FrontierTransitAuthority,
    gate: &Gate,
    cap_ticket: Receiving<OwnerCap<Gate>>,
    ctx: &TxContext,
): OwnerCap<Gate> {
    // Ensure FTA controls the gate
    assert!(fta.gate_registry().registered(gate), EGateNotInNetwork);

    // Get the owner cap and receipt
    let (
        owner_cap,
        OwnerCapReceipt<Gate> {
            owner_id: _,
            owner_cap_id: _,
        },
    ) = borrow_owner_cap(fta, cap_ticket, ctx);

    // Ensure the correct OwnerCap was passed in
    assert!(gate.owner_cap_id() == object::id(&owner_cap), EWrongOwnerCap);
    owner_cap
}
