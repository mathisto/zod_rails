import { z } from "zod";

export const AdminUserSchema = z.object({
  id: z.int(),
  email: z.string().min(1)
});

export type AdminUser = z.infer<typeof AdminUserSchema>;

export const AdminUserInputSchema = z.object({
  email: z.string().min(1)
});

export type AdminUserInput = z.infer<typeof AdminUserInputSchema>;
