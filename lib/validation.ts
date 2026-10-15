import { z } from "zod";

const text = (max: number) => z.string().trim().max(max);
const optionalText = (max: number) =>
  z
    .string()
    .nullish()
    .transform((v) => (v ?? "").trim())
    .pipe(z.string().max(max, `Please keep this under ${max} characters`));
const checkbox = z
  .union([z.string(), z.boolean()])
  .nullish()
  .transform((v) => v === true || v === "yes" || v === "on" || v === "true");

/** Shared anti-spam fields sent by the public forms. */
const antiSpam = {
  website: optionalText(200), // honeypot – must stay empty
  startedAt: z.coerce.number().optional(),
};

export const contactSchema = z.object({
  firstName: text(80).min(1, "Please enter your first name"),
  lastName: optionalText(80),
  email: text(160).email("Please enter a valid email"),
  phone: optionalText(40),
  subject: optionalText(80),
  visitDate: optionalText(20),
  guests: z
    .union([z.number(), z.string()])
    .nullish()
    .transform((v) => {
      const n = Number(v);
      return v === "" || v == null || !Number.isFinite(n) ? null : Math.min(500, Math.max(1, Math.round(n)));
    }),
  message: text(4000).min(2, "Please write a short message"),
  source: optionalText(30),
  consent: checkbox.refine((v) => v, "Please accept the privacy note"),
  ...antiSpam,
});

export const bookingSchema = z.object({
  eventId: z.string().uuid(),
  firstName: text(80).min(1, "Please enter your first name"),
  lastName: text(80).min(1, "Please enter your last name"),
  email: text(160).email("Please enter a valid email"),
  phone: text(40).min(6, "Please enter a phone number"),
  guests: z.coerce.number().int().min(1).max(50),
  seating: optionalText(40),
  occasion: optionalText(120),
  message: optionalText(2000),
  consent: checkbox.refine((v) => v, "Please accept the privacy note"),
  marketingOptIn: checkbox,
  ...antiSpam,
});

export function looksLikeSpam(data: { website?: string; startedAt?: number }) {
  if (data.website) return true;
  if (data.startedAt && Date.now() - data.startedAt < 2500) return true; // filled in < 2.5s = bot
  return false;
}
