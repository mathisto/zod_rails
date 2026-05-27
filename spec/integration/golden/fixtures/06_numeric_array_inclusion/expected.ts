import { z } from "zod";

export const PrioritySchema = z.object({
  id: z.int(),
  level: z.int().pipe(z.union([z.literal(1), z.literal(5), z.literal(10)]))
});

export type Priority = z.infer<typeof PrioritySchema>;

export const PriorityInputSchema = z.object({
  level: z.int().pipe(z.union([z.literal(1), z.literal(5), z.literal(10)]))
});

export type PriorityInput = z.infer<typeof PriorityInputSchema>;
