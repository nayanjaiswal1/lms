import { Playfair_Display } from "next/font/google";

// Scoped to the diary view's paper theme only (see diary-theme.css) — body
// text reuses --font-journal-sans (Hanken Grotesk, journal-fonts.ts) so we
// don't load a second sans family for one feature.
export const diarySerif = Playfair_Display({
  subsets: ["latin"],
  variable: "--font-diary-serif",
  display: "swap",
  weight: ["600", "700"],
});
