import { z } from "zod";

export const ManagementCapSchema = z.object({
    id: z.coerce.string(),
    authorized_object_id: z.coerce.string(),
    object_registration_id: z.coerce.string(),
});

export type ManagementCapType = z.infer<typeof ManagementCapSchema>;
