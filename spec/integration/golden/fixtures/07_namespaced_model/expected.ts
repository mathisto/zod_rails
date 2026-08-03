import { z } from "zod";

export const AdminUserSchema = z.object({
  id: z.int(),
  email: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" })
});

export type AdminUser = z.infer<typeof AdminUserSchema>;

export const AdminUserInputSchema = z.object({
  email: z.string().min(1).refine((value) => value.trim().length > 0, { message: "can't be blank" })
});

export type AdminUserInput = z.infer<typeof AdminUserInputSchema>;
