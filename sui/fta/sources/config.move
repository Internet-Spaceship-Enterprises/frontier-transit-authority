module fta::config;

#[error(code = 3)]
const EGateNotInNetwork: vector<u8> = b"This gate is not part of the Frontier Transit Authority";
#[error(code = 12)]
const ENoLinkedGate: vector<u8> = b"You cannot perform an operation on a gate that is not linked";

// TODO: add public functions to update gate fees
