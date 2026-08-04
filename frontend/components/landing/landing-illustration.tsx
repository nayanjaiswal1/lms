// Hand-authored hero illustration — an abstract mockup of the product itself
// (lab terminal, course card with progress, mentor chat, certificate badge)
// built from the same primitives as the app's own `.skeleton` loading state,
// rather than a stock photo or generated raster image. Same "draw the brand
// mark in code" convention as components/shared/brand-mark.tsx's FlameGlyph,
// so it themes automatically with the design tokens and needs no asset file.
import styles from "./landing-illustration.module.css";

export function LandingIllustration({ className }: { className?: string }) {
  return (
    <svg aria-hidden className={className} fill="none" viewBox="0 0 420 360" xmlns="http://www.w3.org/2000/svg">
      <rect className="fill-muted/40" height="300" rx="28" width="330" x="30" y="40" />

      {/* connector lines tying the pieces into one system */}
      <path className="stroke-border" d="M110 210 L84 244" strokeDasharray="4 5" strokeWidth="1.5" />
      <path className="stroke-border" d="M300 130 L268 108" strokeDasharray="4 5" strokeWidth="1.5" />

      {/* lab / terminal card */}
      <g className={styles.cardShadow}>
        <rect className="fill-card stroke-border" height="140" rx="14" strokeWidth="1.5" width="200" x="50" y="66" />
        <circle className="fill-muted-foreground/30" cx="68" cy="86" r="3.5" />
        <circle className="fill-muted-foreground/30" cx="80" cy="86" r="3.5" />
        <circle className="fill-muted-foreground/30" cx="92" cy="86" r="3.5" />
        <rect className="fill-ai/40" height="6" rx="3" width="140" x="66" y="108" />
        <rect className="fill-border" height="6" rx="3" width="108" x="66" y="122" />
        <rect className="fill-ai/25" height="6" rx="3" width="150" x="66" y="136" />
        <rect className="fill-border" height="6" rx="3" width="90" x="66" y="150" />
        <rect className="fill-ai/25" height="6" rx="3" width="120" x="66" y="164" />
        <rect className="fill-border" height="6" rx="3" width="70" x="66" y="178" />
      </g>

      {/* course card with progress */}
      <g className={styles.cardShadow}>
        <rect className="fill-card stroke-border" height="128" rx="14" strokeWidth="1.5" width="190" x="172" y="150" />
        <rect className="fill-primary/15" height="32" rx="9" width="32" x="192" y="170" />
        <path className="fill-primary" d="M203 178 L217 186 L203 194 Z" />
        <rect className="fill-foreground/70" height="8" rx="4" width="100" x="234" y="174" />
        <rect className="fill-muted-foreground/50" height="6" rx="3" width="70" x="234" y="190" />
        <rect className="fill-muted" height="8" rx="4" width="150" x="192" y="234" />
        <rect className="fill-primary" height="8" rx="4" width="98" x="192" y="234" />
      </g>

      {/* mentor chat bubble */}
      <g className={styles.cardShadow}>
        <rect className="fill-ai/10 stroke-ai/30" height="54" rx="16" strokeWidth="1.5" width="92" x="298" y="46" />
        <path className="fill-ai/10 stroke-ai/30" d="M316 100 L316 116 L332 100 Z" strokeWidth="1.5" />
        <circle className="fill-ai" cx="318" cy="73" r="4" />
        <circle className="fill-ai" cx="336" cy="73" r="4" />
        <circle className="fill-ai" cx="354" cy="73" r="4" />
      </g>

      {/* certificate badge */}
      <g className={styles.cardShadow}>
        <path className="fill-primary/20" d="M64 292 L80 322 L96 292 Z" />
        <path className="fill-primary/25" d="M64 292 L48 322 L64 322 Z" />
        <circle className="fill-primary/15 stroke-primary/40" cx="80" cy="270" r="32" strokeWidth="1.5" />
        <path className="stroke-primary" d="M68 270 L77 279 L94 260" fill="none" strokeLinecap="round" strokeLinejoin="round" strokeWidth="4" />
      </g>
    </svg>
  );
}

// Companion mockup for the "learn on your own" audience card — one course in
// progress plus a personal profile ring, echoing the real Learning Profile
// feature (skills/achievements/streak) rather than a generic person icon.
export function LearnerIllustration({ className }: { className?: string }) {
  return (
    <svg aria-hidden className={className} fill="none" viewBox="0 0 300 220" xmlns="http://www.w3.org/2000/svg">
      <rect className="fill-muted/40" height="180" rx="24" width="260" x="20" y="20" />

      <g className={styles.cardShadow}>
        <rect className="fill-card stroke-border" height="110" rx="14" strokeWidth="1.5" width="170" x="46" y="58" />
        <rect className="fill-primary/15" height="30" rx="8" width="30" x="64" y="74" />
        <path className="fill-primary" d="M74 81 L88 89 L74 97 Z" />
        <rect className="fill-foreground/70" height="8" rx="4" width="86" x="106" y="80" />
        <rect className="fill-muted-foreground/50" height="6" rx="3" width="56" x="106" y="96" />
        <rect className="fill-muted" height="8" rx="4" width="134" x="64" y="138" />
        <rect className="fill-primary" height="8" rx="4" width="90" x="64" y="138" />
      </g>

      <g className={styles.cardShadow}>
        <circle className="fill-primary/10 stroke-primary/40" cx="228" cy="50" r="22" strokeWidth="1.5" />
        <circle className="fill-primary/60" cx="228" cy="43" r="7" />
        <path className="fill-primary/60" d="M212 66 Q228 50 244 66 Z" />
      </g>
    </svg>
  );
}

// Companion mockup for the "train your cohort" audience card — an org hub
// fanned out to role seats with a shared wiki doc, matching the real
// multi-org, role-based access, and wiki features (not a stock office photo).
export function OrgIllustration({ className }: { className?: string }) {
  return (
    <svg aria-hidden className={className} fill="none" viewBox="0 0 300 220" xmlns="http://www.w3.org/2000/svg">
      <rect className="fill-muted/40" height="180" rx="24" width="260" x="20" y="20" />

      <path className="stroke-border" d="M108 100 L168 68" strokeDasharray="4 5" strokeWidth="1.5" />
      <path className="stroke-border" d="M110 110 L176 110" strokeDasharray="4 5" strokeWidth="1.5" />
      <path className="stroke-border" d="M108 122 L168 154" strokeDasharray="4 5" strokeWidth="1.5" />

      <g className={styles.cardShadow}>
        <circle className="fill-primary/15 stroke-primary/40" cx="90" cy="110" r="28" strokeWidth="1.5" />
        <rect className="fill-primary/60" height="16" rx="2" width="20" x="80" y="102" />
        <rect className="fill-card" height="5" rx="1" width="5" x="84" y="106" />
        <rect className="fill-card" height="5" rx="1" width="5" x="93" y="106" />
      </g>

      <g className={styles.cardShadow}>
        <circle className="fill-ai/15 stroke-ai/40" cx="188" cy="64" r="17" strokeWidth="1.5" />
        <circle className="fill-ai/15 stroke-ai/40" cx="204" cy="110" r="17" strokeWidth="1.5" />
        <circle className="fill-ai/15 stroke-ai/40" cx="188" cy="156" r="17" strokeWidth="1.5" />
      </g>

      <g className={styles.cardShadow}>
        <rect className="fill-card stroke-border" height="42" rx="8" strokeWidth="1.5" width="58" x="36" y="150" />
        <rect className="fill-border" height="5" rx="2" width="38" x="46" y="162" />
        <rect className="fill-border" height="5" rx="2" width="26" x="46" y="174" />
      </g>
    </svg>
  );
}
