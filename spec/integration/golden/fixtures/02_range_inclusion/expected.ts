import { z } from "zod";

export const SurveySchema = z.object({
  id: z.int(),
  rating: z.int().min(1).max(5)
});

export type Survey = z.infer<typeof SurveySchema>;

export const SurveyInputSchema = z.object({
  rating: z.int().min(1).max(5)
});

export type SurveyInput = z.infer<typeof SurveyInputSchema>;
