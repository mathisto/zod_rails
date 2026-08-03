import { z } from "zod";

export const ArticleSchema = z.object({
  id: z.int(),
  title: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" }),
  body: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" }),
  created_at: z.iso.datetime({ offset: true }),
  updated_at: z.iso.datetime({ offset: true })
});

export type Article = z.infer<typeof ArticleSchema>;

export const ArticleInputSchema = z.object({
  title: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" }),
  body: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" })
});

export type ArticleInput = z.infer<typeof ArticleInputSchema>;
