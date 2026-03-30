module fta::network_node_record;

public struct NetworkNodeRecord has store {
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    network_node_id: ID,
}

public(package) fun new(
    transferred_on: u64,
    transferred_from_character_id: ID,
    transferred_from_wallet_addr: address,
    network_node_id: ID,
): NetworkNodeRecord {
    NetworkNodeRecord {
        transferred_on: transferred_on,
        transferred_from_character_id: transferred_from_character_id,
        transferred_from_wallet_addr: transferred_from_wallet_addr,
        network_node_id: network_node_id,
    }
}

/// Destroys a NetworkNodeRecord
public(package) fun destroy(record: NetworkNodeRecord) {
    let NetworkNodeRecord {
        transferred_on: _,
        transferred_from_character_id: _,
        transferred_from_wallet_addr: _,
        network_node_id: _,
    } = record;
}

public(package) fun transferred_on(record: &NetworkNodeRecord): &u64 {
    &record.transferred_on
}

public(package) fun transferred_from_character_id(record: &NetworkNodeRecord): &ID {
    &record.transferred_from_character_id
}

public(package) fun transferred_from_wallet_addr(record: &NetworkNodeRecord): &address {
    &record.transferred_from_wallet_addr
}

public(package) fun network_node_id(record: &NetworkNodeRecord): &ID {
    &record.network_node_id
}
