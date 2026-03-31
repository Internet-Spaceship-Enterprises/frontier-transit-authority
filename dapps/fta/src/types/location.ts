import { z } from "zod";

export const CoordinatesSchema = z.object({
    solarsystem: z.coerce.number(),
    x: z.coerce.bigint(),
    y: z.coerce.bigint(),
    z: z.coerce.bigint(),
});

export type CoordinatesType = z.infer<typeof CoordinatesSchema>;

export type LocationRegistry = Record<string, CoordinatesType>;