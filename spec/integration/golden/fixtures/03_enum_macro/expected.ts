import { z } from "zod";

export const AccountSchema = z.object({
  id: z.int(),
  role: z.enum(["member", "admin", "moderator"]),
  status: z.enum(["pending", "active", "suspended"]).nullable()
});

export type Account = z.infer<typeof AccountSchema>;

export const AccountInputSchema = z.object({
  role: z.enum(["member", "admin", "moderator"]).optional(),
  status: z.enum(["pending", "active", "suspended"]).nullish()
});

export type AccountInput = z.infer<typeof AccountInputSchema>;
