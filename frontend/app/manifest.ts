import type { MetadataRoute } from 'next'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'MindForge',
    short_name: 'MindForge',
    description: 'AI-powered learning platform — forge your knowledge end to end.',
    start_url: '/',
    scope: '/',

    // standalone = no browser chrome, feels native on mobile
    // window-controls-overlay = title bar becomes app space on desktop PWA installs
    display: 'standalone',
    display_override: ['window-controls-overlay', 'standalone', 'browser'],

    // portrait-primary default; content adapts to landscape — don't lock
    orientation: 'portrait-primary',

    // Light mode brand colours — dark mode theme-color is set per-media in layout.tsx
    background_color: '#FAFAF7', // warm off-white (--background light)
    theme_color: '#B45309',      // amber-700 (--primary light)

    categories: ['education', 'productivity'],

    // ── Icons ────────────────────────────────────────────────────────────
    // Place generated files in public/icons/. Required sizes:
    //   192×192  → Android home screen launcher
    //   512×512  → Android splash screen + PWA install prompt
    //   maskable → Android adaptive icons (content in 80% safe zone)
    //   180×180  → placed as app/apple-icon.png (Next.js handles Apple touch)
    //
    // Tool to generate: https://maskable.app  or  npx pwa-asset-generator
    icons: [
      {
        src: '/icons/icon-192.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: '/icons/icon-192-maskable.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'maskable',
      },
      {
        src: '/icons/icon-512.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: '/icons/icon-512-maskable.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable',
      },
    ],

    // ── Shortcuts — quick-launch from long-press on home screen icon ─────
    // Max 4. Each needs a 96×96 icon in public/icons/shortcuts/.
    shortcuts: [
      {
        name: 'Dashboard',
        short_name: 'Home',
        description: 'Your learning progress and streaks',
        url: '/dashboard',
        icons: [{ src: '/icons/shortcuts/dashboard.png', sizes: '96x96' }],
      },
      {
        name: 'My Learning',
        short_name: 'Learn',
        description: 'Continue your current curriculum',
        url: '/learn',
        icons: [{ src: '/icons/shortcuts/learn.png', sizes: '96x96' }],
      },
      {
        name: 'Practice Cards',
        short_name: 'Practice',
        description: 'Spaced repetition review session',
        url: '/practice',
        icons: [{ src: '/icons/shortcuts/practice.png', sizes: '96x96' }],
      },
      {
        name: 'Quick Quiz',
        short_name: 'Quiz',
        description: 'Test your knowledge',
        url: '/quiz',
        icons: [{ src: '/icons/shortcuts/quiz.png', sizes: '96x96' }],
      },
    ],

    // ── Screenshots — shown in PWA install prompt on Chrome/Edge ─────────
    // Optional but improves install conversion. Add when design is final.
    // screenshots: [
    //   { src: '/screenshots/mobile-dashboard.png', sizes: '390x844', type: 'image/png', form_factor: 'narrow' },
    //   { src: '/screenshots/desktop-dashboard.png', sizes: '1280x800', type: 'image/png', form_factor: 'wide' },
    // ],
  }
}
