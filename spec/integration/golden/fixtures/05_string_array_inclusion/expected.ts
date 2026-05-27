import { z } from "zod";

export const FileReviewDecisionSchema = z.object({
  id: z.int(),
  decision: z.string().min(1).pipe(z.enum(["pending", "approved", "not_applicable"]))
});

export type FileReviewDecision = z.infer<typeof FileReviewDecisionSchema>;

export const FileReviewDecisionInputSchema = z.object({
  decision: z.string().min(1).pipe(z.enum(["pending", "approved", "not_applicable"]))
});

export type FileReviewDecisionInput = z.infer<typeof FileReviewDecisionInputSchema>;
