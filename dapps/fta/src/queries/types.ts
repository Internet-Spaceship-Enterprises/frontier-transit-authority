import { TypeRepr, ObjectNodes, AsMoveObjectRef, MoveObjectData } from "@evefrontier/dapp-kit";

/** @category GraphQL Types */
export interface OwnerCap {
    id: string;
    authorized_object_id: string;
}

/** @category GraphQL Types */
export interface ObjectWithContentsNode {
    address: string;
    version: number;
    asMoveObject: {
        contents: { json: Record<string, unknown>; type: TypeRepr };
    } | null;
}

export interface OwnedAssembliesNode {
    contents: {
        type: TypeRepr;
        json: OwnerCap;
        extract: AsMoveObjectRef<MoveObjectData>
    }
}

/** @category GraphQL Types */
export interface GetOwnedAssembliesResponse {
    object: {
        objects: ObjectNodes<OwnedAssembliesNode>
    }
}