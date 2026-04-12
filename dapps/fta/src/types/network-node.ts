import { z } from "zod";
import { OwnerCapType } from "../types/owner-cap";
import {
    AssemblyType,
    Assemblies,

} from "@evefrontier/dapp-kit";

export const NetworkNodeRecordSchema = z.object({
    object_registration_id: z.coerce.string(),
    management_cap_id: z.coerce.string(),
    transferred_on: z.coerce.number(),
    transferred_from_character_id: z.coerce.string(),
    transferred_from_wallet_addr: z.coerce.string(),
    network_node_id: z.coerce.string(),
    fee_recipient: z.coerce.string(),
    // fee_history
});

export type NetworkNodeRecordType = z.infer<typeof NetworkNodeRecordSchema>;

export interface NetworkNodeWithOwnerCap {
    assembly: AssemblyType<Assemblies.NetworkNode>;
    owner_cap: OwnerCapType;
}