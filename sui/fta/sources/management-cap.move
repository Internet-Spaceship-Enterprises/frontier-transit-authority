module fta::management_cap;

/// An object that represents management capability over an FTA-registered resource.
public struct ManagementCap<phantom T> has key {
    id: UID,
    authorized_object_id: ID,
}

public(package) fun new<T: key>(object_id: ID, ctx: &mut TxContext): ManagementCap<T> {
    let management_cap = ManagementCap<T> {
        id: object::new(ctx),
        authorized_object_id: object_id,
    };
    management_cap
}

/// Transfers a management cap to a new address.
public fun transfer_management_cap<T>(management_cap: ManagementCap<T>, new_owner: address) {
    transfer::transfer(management_cap, new_owner);
}

public(package) fun id<T>(management_cap: &mut ManagementCap<T>): &mut UID {
    &mut management_cap.id
}

public(package) fun is_authorized<T>(management_cap: &ManagementCap<T>, object_id: ID): bool {
    management_cap.authorized_object_id == object_id
}
