import { z } from "zod";

export const TicketSchema = z.object({
  id: z.int(),
  priority: z.enum(["low", "medium", "high"]).nullable()
});

export type Ticket = z.infer<typeof TicketSchema>;

export const TicketInputSchema = z.object({
  priority: z.enum(["low", "medium", "high"]).nullish()
});

export type TicketInput = z.infer<typeof TicketInputSchema>;
