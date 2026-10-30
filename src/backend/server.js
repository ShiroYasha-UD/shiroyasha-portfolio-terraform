// Contact form API for shiroyasha.dev
// Browser form -> POST /api/contact -> this Express app -> Amazon SES -> your Tuta inbox
//
// Setup:  npm init -y && npm pkg set type=module
//         npm i express express-rate-limit zod @aws-sdk/client-sesv2
// Run:    node server.js   (Node 20+)

import express from "express";
import rateLimit from "express-rate-limit";
import { z } from "zod";
import { SESv2Client, SendEmailCommand } from "@aws-sdk/client-sesv2";

const PORT = Number(process.env.PORT ?? 3001);
const FROM = process.env.CONTACT_FROM ?? "contact@shiroyasha.dev"; // any address on the SES-verified domain
const TO = process.env.CONTACT_TO ?? "hello@shiroyasha.dev";       // your Tuta inbox

// No access keys in code: on EC2 the SDK picks up the instance's IAM role automatically,
// locally it uses your ~/.aws profile.
const ses = new SESv2Client({ region: process.env.AWS_REGION ?? "eu-central-1" });

const app = express();
app.set("trust proxy", 1);                 // behind Caddy, so rate limiting sees the real client IP
app.use(express.json({ limit: "10kb" }));  // reject oversized bodies early

const Contact = z.object({
  name: z.string().trim().min(1).max(100),
  email: z.email().max(200),               // zod 4; on zod 3 use z.string().email()
  message: z.string().trim().min(1).max(5000),
  website: z.string().optional(),          // honeypot: hidden in the form, humans leave it empty
});

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000,                // 15 minutes
  limit: 5,                                // 5 messages per IP per window
  standardHeaders: "draft-8",
  legacyHeaders: false,
  message: { error: "Too many messages, try again later." },
});

// Global cap across ALL visitors: stops floods from rotating IPs / VPNs.
// Real people send a handful of messages a day; anything above this is a bot.
const globalLimiter = rateLimit({
  windowMs: 24 * 60 * 60 * 1000,           // 24 hours
  limit: Number(process.env.CONTACT_DAILY_LIMIT ?? 30),
  keyGenerator: () => "global",            // one shared counter, not per IP
  standardHeaders: false,
  legacyHeaders: false,
  message: { error: "The contact form is busy right now. Please email me directly." },
});

app.post("/api/contact", limiter, globalLimiter, async (req, res) => {
  const parsed = Contact.safeParse(req.body);
  if (!parsed.success) return res.status(400).json({ error: "Please check the fields and try again." });

  const { name, email, message, website } = parsed.data;
  if (website) return res.status(204).end(); // bot filled the honeypot: pretend success, send nothing

  const safeName = name.replace(/[\r\n]+/g, " "); // no line breaks in the subject header

  try {
    await ses.send(new SendEmailCommand({
      FromEmailAddress: `Portfolio contact <${FROM}>`, // always your domain, never the visitor's address
      Destination: { ToAddresses: [TO] },
      ReplyToAddresses: [email],                        // hitting "Reply" in Tuta answers the visitor
      Content: {
        Simple: {
          Subject: { Data: `Portfolio: message from ${safeName}` },
          Body: { Text: { Data: `From: ${safeName} <${email}>\n\n${message}` } },
        },
      },
    }));
    res.status(204).end();
  } catch (err) {
    console.error("SES send failed:", err);
    res.status(502).json({ error: "Could not send the message right now." });
  }
});

// Only reachable through Caddy, never directly from the internet
app.listen(PORT, "127.0.0.1", () => console.log(`contact API on 127.0.0.1:${PORT}`));
