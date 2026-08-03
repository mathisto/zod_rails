import { z } from "zod";

export const ArrayRecordSchema = z.object({
  tags: z.array(z.string().pipe(z.enum(["alpha", "beta"]))).min(1).max(5),
  optional_tags: z.array(z.string()).nullable(),
  scores: z.array(z.int())
});

export type ArrayRecord = z.infer<typeof ArrayRecordSchema>;

export const ArrayRecordInputSchema = z.object({
  tags: z.array(z.string().pipe(z.enum(["alpha", "beta"]))).min(1).max(5).optional(),
  optional_tags: z.array(z.string()).nullish(),
  scores: z.array(z.int())
});

export type ArrayRecordInput = z.infer<typeof ArrayRecordInputSchema>;
