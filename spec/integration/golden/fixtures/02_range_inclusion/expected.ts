import { z } from "zod";

export const SurveySchema = z.object({
  id: z.int(),
  rating: z.int().gte(1).lte(5)
});

export type Survey = z.infer<typeof SurveySchema>;

export const SurveyInputSchema = z.object({
  rating: z.int().gte(1).lte(5)
});

export type SurveyInput = z.infer<typeof SurveyInputSchema>;
