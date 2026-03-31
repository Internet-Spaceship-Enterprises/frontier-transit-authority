import { z } from "zod";
import { GateRecordSchema, GateWithOwnerCap } from "./gate";
import { NetworkNodeRecordSchema } from "./network-node";
import { CoordinatesType } from "./location";

export const FTASchema = z.object({
    id: z.coerce.string(),
    deployer_addr: z.coerce.string(),
    upgrade_cap_exchanged: z.coerce.boolean(),
    gate_registry: z.record(z.string(), GateRecordSchema),
    network_node_registry: z.record(z.string(), NetworkNodeRecordSchema),
    //jump_history: Record<string, JumpHistoryEntry>;
    //jump_history_by_character: Record<string, JumpHistoryEntry>;
    // killmail_registry: Record<string, any>;
    // blacklist: Record<string, any>;
    // character_bounties: Record<string, any>;
    // tribe_bounties: Record<string, any>;
});

export type FTAType = z.infer<typeof FTASchema>;

export interface FTAContextType {
    loading: boolean;
    error: string | null;
    fta: FTAType | null,
    gates: Record<string, GateWithOwnerCap> | null;
    locations: Record<string, CoordinatesType> | null;
    refetch: () => Promise<void>;
}
