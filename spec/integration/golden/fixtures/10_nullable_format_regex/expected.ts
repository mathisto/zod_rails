import { z } from "zod";

export const ProfileSchema = z.object({
  id: z.int(),
  slug: z.string().regex(new RegExp("^[a-z\\d]+(?:-[a-z\\d]+)*(?![\\s\\S])")),
  email: z.string().regex(new RegExp("^[^@\\s]+@[^@\\s]+\\.[A-Za-z]{2,}(?![\\s\\S])")).nullable(),
  website: z.string().regex(new RegExp("^https://\\S+\\.\\S+(?![\\s\\S])")).nullable(),
  locale: z.string().regex(new RegExp("^[a-z]{2}(?![\\s\\S])"))
});

export type Profile = z.infer<typeof ProfileSchema>;

export const ProfileInputSchema = z.object({
  slug: z.string().regex(new RegExp("^[a-z\\d]+(?:-[a-z\\d]+)*(?![\\s\\S])")),
  email: z.string().regex(new RegExp("^[^@\\s]+@[^@\\s]+\\.[A-Za-z]{2,}(?![\\s\\S])")).nullish(),
  website: z.string().regex(new RegExp("^https://\\S+\\.\\S+(?![\\s\\S])")).nullish(),
  locale: z.string().regex(new RegExp("^[a-z]{2}(?![\\s\\S])")).optional()
});

export type ProfileInput = z.infer<typeof ProfileInputSchema>;
