import { z } from "zod";

export const UserSchema = z.object({
  id: z.int(),
  email: z.string().min(1).regex(/^[\w+\-.]+@[a-z\d-]+\.[a-z]+$/),
  name: z.string().min(2).max(100),
  age: z.int().gt(0).lt(150).nullable(),
  bio: z.string().nullable(),
  score: z.string().nullable(),
  active: z.boolean(),
  uuid: z.uuid(),
  born_on: z.iso.date().nullable(),
  metadata: z.json().nullable(),
  role: z.enum(["member", "admin"]),
  created_at: z.iso.datetime(),
  updated_at: z.iso.datetime()
});

export type User = z.infer<typeof UserSchema>;

export const UserInputSchema = z.object({
  email: z.string().min(1).regex(/^[\w+\-.]+@[a-z\d-]+\.[a-z]+$/),
  name: z.string().min(2).max(100),
  age: z.int().gt(0).lt(150).nullish(),
  bio: z.string().nullish(),
  score: z.string().nullish(),
  active: z.boolean().optional(),
  uuid: z.uuid(),
  born_on: z.iso.date().nullish(),
  metadata: z.json().nullish(),
  role: z.enum(["member", "admin"]).optional()
});

export type UserInput = z.infer<typeof UserInputSchema>;
