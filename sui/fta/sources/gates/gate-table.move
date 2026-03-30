module fta::gate_table;

use fta::gate_record::GateRecord;
use sui::linked_table::{Self, LinkedTable};
use world::gate::Gate;

#[error(code = 1)]
const EGateAlreadyRegistered: vector<u8> =
    b"This gate is already registered with the Frontier Transit Authority";
#[error(code = 2)]
const EGateNotInNetwork: vector<u8> =
    b"This gate is not registered with the Frontier Transit Authority network";

public struct GateTable has store {
    // Maps gate ID to gate record
    gate_table: LinkedTable<ID, GateRecord>,
}

public(package) fun new(ctx: &mut TxContext): GateTable {
    GateTable {
        gate_table: linked_table::new<ID, GateRecord>(ctx),
    }
}

public(package) fun gate_registered(table: &GateTable, gate: &Gate): bool {
    table.gate_table.contains(object::id(gate))
}

public(package) fun gate_registered_by_id(table: &GateTable, gate_id: ID): bool {
    table.gate_table.contains(gate_id)
}

public(package) fun gate_registered_by_record(table: &GateTable, record: &GateRecord): bool {
    table.gate_table.contains(record.gate_id())
}

public(package) fun add(table: &mut GateTable, record: GateRecord) {
    assert!(!table.gate_registered_by_record(&record), EGateAlreadyRegistered);
    table.gate_table.push_back(record.gate_id(), record);
}

public(package) fun get_by_gate(table: &GateTable, gate: &Gate): &GateRecord {
    assert!(table.gate_registered(gate), EGateNotInNetwork);
    table.gate_table.borrow(object::id(gate))
}

public(package) fun get_by_gate_mut(table: &mut GateTable, gate: &Gate): &mut GateRecord {
    assert!(table.gate_registered(gate), EGateNotInNetwork);
    table.gate_table.borrow_mut(object::id(gate))
}

public(package) fun get_by_gate_id(table: &GateTable, gate_id: ID): &GateRecord {
    assert!(table.gate_registered_by_id(gate_id), EGateNotInNetwork);
    table.gate_table.borrow(gate_id)
}

public(package) fun get_by_gate_id_mut(table: &mut GateTable, gate_id: ID): &mut GateRecord {
    assert!(table.gate_registered_by_id(gate_id), EGateNotInNetwork);
    table.gate_table.borrow_mut(gate_id)
}

public(package) fun deregister(table: &mut GateTable, gate: &Gate) {
    assert!(table.gate_registered(gate), EGateNotInNetwork);
    table.gate_table.remove(object::id(gate)).destroy();
    // TODO: deregister the auth extension
}

public(package) fun deregister_by_record(table: &mut GateTable, record: &GateRecord) {
    assert!(table.gate_registered_by_record(record), EGateNotInNetwork);
    table.gate_table.remove(record.gate_id()).destroy();
    // TODO: deregister the auth extension
}

// Returns a list of the IDs of all gates managed by the FTA
public(package) fun managed_gate_ids(table: &GateTable): vector<ID> {
    let mut keys = vector::empty<ID>();

    let cur_ref = table.gate_table.front();
    if (option::is_none(cur_ref)) {
        return keys
    };

    let mut cur = *option::borrow(cur_ref);
    vector::push_back(&mut keys, cur);

    loop {
        let next_ref = table.gate_table.next(cur);
        if (option::is_none(next_ref)) {
            break
        };
        cur = *option::borrow(next_ref);
        vector::push_back(&mut keys, cur);
    };

    keys
}
