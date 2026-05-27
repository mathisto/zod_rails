import { z } from "zod";

export const ArticleSchema = z.object({
  id: z.int(),
  title: z.string().min(1),
  body: z.string().min(1),
  created_at: z.iso.datetime(),
  updated_at: z.iso.datetime()
});

export type Article = z.infer<typeof ArticleSchema>;

export const ArticleInputSchema = z.object({
  title: z.string().min(1),
  body: z.string().min(1)
});

export type ArticleInput = z.infer<typeof ArticleInputSchema>;
