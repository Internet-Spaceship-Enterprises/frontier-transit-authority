module fta::management_cap;

/// An object that represents management capability over an FTA-registered resource.
public struct ManagementCap<phantom T> has key {
    id: UID,
    authorized_object_id: ID,
    // This is an address unique to the registration of this object with the FTA.
    // It is needed in addition to the authorized_object_id because a resource (e.g. a gate)
    // can be transferred back to the original owner in some cases, but since FTA doesn't own
    // the ManagementCap, it we can't delete the cap when the gate gets transferred back.
    // So instead, we render it useless by tying it to a unique ID in the registration process.
    object_registration_id: ID,
}

public(package) fun new<T: key>(
    object_id: ID,
    object_registration_id: ID,
    ctx: &mut TxContext,
): ManagementCap<T> {
    let management_cap = ManagementCap<T> {
        id: object::new(ctx),
        authorized_object_id: object_id,
        object_registration_id: object_registration_id,
    };
    management_cap
}

/// Transfers a management cap to a new address.
/// There are no restrictions on this, anyone can transfer a management cap they own to any address.
public fun transfer<T>(management_cap: ManagementCap<T>, new_owner: address) {
    transfer::transfer(management_cap, new_owner);
}

public(package) fun id<T>(management_cap: &mut ManagementCap<T>): &mut UID {
    &mut management_cap.id
}

public(package) fun is_authorized<T>(
    management_cap: &ManagementCap<T>,
    object_id: ID,
    object_registration_id: ID,
): bool {
    management_cap.authorized_object_id == object_id && management_cap.object_registration_id == object_registration_id
}
