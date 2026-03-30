module fta::jump_auth;

/// Used for authorizing gate extensions
public struct JumpAuth has drop {}

public(package) fun new(): JumpAuth {
    JumpAuth {}
}
