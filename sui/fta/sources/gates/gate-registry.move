module fta::gate_registry;

use fta::gate_record::GateRecord;
use fta::management_cap::ManagementCap;
use sui::linked_table::{Self, LinkedTable};
use world::gate::Gate;

#[error(code = 1)]
const EGateAlreadyRegistered: vector<u8> =
    b"This gate is already registered with the Frontier Transit Authority";
#[error(code = 2)]
const EGateNotInNetwork: vector<u8> =
    b"This gate is not registered with the Frontier Transit Authority network";
#[error(code = 3)]
const EWrongManagementCap: vector<u8> = b"This management cap is not for the specified gate";

public struct GateRegistry has store {
    // Maps gate ID to gate record
    table: LinkedTable<ID, GateRecord>,
}

public(package) fun new(ctx: &mut TxContext): GateRegistry {
    GateRegistry {
        table: linked_table::new<ID, GateRecord>(ctx),
    }
}

public(package) fun registered(registry: &GateRegistry, gate: &Gate): bool {
    registry.registered_by_id(object::id(gate))
}

public(package) fun registered_by_id(registry: &GateRegistry, gate_id: ID): bool {
    registry.table.contains(gate_id)
}

public(package) fun registered_by_record(registry: &GateRegistry, record: &GateRecord): bool {
    registry.registered_by_id(record.gate_id())
}

public(package) fun add(registry: &mut GateRegistry, record: GateRecord) {
    assert!(!registry.registered_by_record(&record), EGateAlreadyRegistered);
    registry.table.push_back(record.gate_id(), record);
}

public(package) fun get(registry: &GateRegistry, gate: &Gate): &GateRecord {
    registry.get_by_id(object::id(gate))
}

public(package) fun get_mut(registry: &mut GateRegistry, gate: &Gate): &mut GateRecord {
    registry.get_by_id_mut(object::id(gate))
}

public(package) fun get_by_id(registry: &GateRegistry, gate_id: ID): &GateRecord {
    assert!(registry.registered_by_id(gate_id), EGateNotInNetwork);
    registry.table.borrow(gate_id)
}

public(package) fun get_by_id_mut(registry: &mut GateRegistry, gate_id: ID): &mut GateRecord {
    assert!(registry.registered_by_id(gate_id), EGateNotInNetwork);
    registry.table.borrow_mut(gate_id)
}

public(package) fun deregister(registry: &mut GateRegistry, gate: &Gate) {
    assert!(registry.registered(gate), EGateNotInNetwork);
    registry.table.remove(object::id(gate)).destroy();
    // TODO: deregister the auth extension
}

public(package) fun deregister_by_record(registry: &mut GateRegistry, record: &GateRecord) {
    assert!(registry.registered_by_record(record), EGateNotInNetwork);
    registry.table.remove(record.gate_id()).destroy();
    // TODO: deregister the auth extension
}

// Returns a list of the IDs of all gates managed by the FTA
public(package) fun managed_gate_ids(registry: &GateRegistry): vector<ID> {
    let mut keys = vector::empty<ID>();

    let cur_ref = registry.table.front();
    if (option::is_none(cur_ref)) {
        return keys
    };

    let mut cur = *option::borrow(cur_ref);
    vector::push_back(&mut keys, cur);

    loop {
        let next_ref = registry.table.next(cur);
        if (option::is_none(next_ref)) {
            break
        };
        cur = *option::borrow(next_ref);
        vector::push_back(&mut keys, cur);
    };

    keys
}

// Transfers a management cap for a gate to a new owner and updates the gate record to reflect the new owner
public fun transfer_management_cap(
    registry: &mut GateRegistry,
    gate: &Gate,
    cap: ManagementCap<Gate>,
    new_owner: address,
) {
    // Ensure this is the management cap for the gate
    assert!(cap.authorized_object_id() == object::id(gate), EWrongManagementCap);
    let record = registry.get_mut(gate);
    record.set_management_cap_owner_address(new_owner);
    cap.transfer(new_owner);
}
