// Facts the legal pages state about how MindForge handles data. Keep these in
// sync with the code and hosting config (render.yaml, docs/ai-connector.md,
// docs/captures.md), not with marketing copy.

export const PRIVACY_LAST_UPDATED = "October 7, 2026";

export interface Subprocessor {
  name: string;
  purpose: string;
  data: string;
  location: string;
}

export const SUBPROCESSORS: readonly Subprocessor[] = [
  { name: "Neon", purpose: "Primary database", data: "All account and content data", location: "Singapore" },
  { name: "Render", purpose: "API hosting and application logs", data: "API traffic, IP addresses, logs", location: "Singapore" },
  { name: "Vercel", purpose: "Web app hosting", data: "Requests, IP addresses, cookies", location: "Singapore and global edge" },
  { name: "Backblaze B2", purpose: "File storage", data: "Screenshots, PDFs and other files you upload", location: "United States" },
  { name: "Anthropic / Google (Gemini)", purpose: "AI features (hints, feedback, diary and journal analysis, capture reading), only when enabled", data: "The text or image you submit to an AI feature", location: "United States" },
  { name: "Brevo", purpose: "Transactional email", data: "Email address, name, message body", location: "European Union" },
  { name: "Razorpay / Stripe", purpose: "Payments", data: "Name, email, amount; card and UPI details go directly to the processor", location: "India / United States" },
  { name: "Google, GitHub", purpose: "Social sign-in, when you choose it", data: "Email and basic profile", location: "United States" },
  { name: "GitLab", purpose: "Ticket linking and code review, when your organization connects it", data: "Connection tokens (encrypted), merge request and issue content", location: "Your GitLab instance" },
  { name: "Your AI assistant (Claude, ChatGPT)", purpose: "AI Connector, only if you connect it", data: "The diary, journal, calendar, habit and course data the scopes you approve allow", location: "United States" },
];

/** Where users send privacy complaints. Read on the server at render time. */
export function grievanceContact(): { name: string; email: string } | null {
  const name = process.env.GRIEVANCE_OFFICER_NAME;
  const email = process.env.GRIEVANCE_OFFICER_EMAIL;
  return name && email ? { name, email } : null;
}

export const LEGAL_PAGES_LAST_UPDATED = "October 7, 2026";

/** Security reports go here. Read on the server at render time. */
export function securityContactEmail(): string | null {
  return process.env.SECURITY_CONTACT_EMAIL || null;
}

/** Data processing agreement requests from organizations go here. */
export function dpaContactEmail(): string | null {
  return process.env.DPA_CONTACT_EMAIL || null;
}
