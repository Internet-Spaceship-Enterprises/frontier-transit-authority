import { z } from "zod";

export const OwnerCapSchema = z.object({
    type: z.coerce.string(),
    id: z.coerce.string(),
    authorized_object_id: z.coerce.string(),
    // fee_history
});

export type OwnerCapType = z.infer<typeof OwnerCapSchema>;
