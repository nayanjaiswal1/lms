import { Playfair_Display, Hanken_Grotesk } from "next/font/google";

// Scoped to the habits grid view's journal theme only (see journal-theme.css)
// — everywhere else keeps --font-sans/--font-mono from app/layout.tsx.
export const journalSerif = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-journal-serif",
  display: "swap",
  weight: ["600", "700"],
});

export const journalSans = Hanken_Grotesk({
  subsets: ["latin"],
  variable: "--font-journal-sans",
  display: "swap",
  weight: ["400", "500", "600"],
});
