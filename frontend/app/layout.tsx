import type { Metadata, Viewport } from 'next'
import { Plus_Jakarta_Sans, JetBrains_Mono } from 'next/font/google'
import { ThemeProvider } from 'next-themes'
import { NuqsAdapter } from 'nuqs/adapters/next'
import { FeatureFlagProvider } from '@/lib/feature-context'
import { PermissionProvider } from '@/lib/auth/permissions'
import { getFeatureConfig } from '@/lib/server/features'
import { getMyPermissions } from '@/lib/server/permissions'
import { Toaster } from '@/components/ui/sonner'
import './globals.css'

// ── Fonts ──────────────────────────────────────────────────────────────────
// These set the CSS variables referenced in globals.css @theme inline:
//   --font-sans: var(--font-plus-jakarta)
//   --font-mono: var(--font-jetbrains-mono)
const plusJakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-plus-jakarta',
  display: 'swap',
  weight: ['300', '400', '500', '600', '700', '800'],
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
  weight: ['400', '500'],
})

// ── Metadata ───────────────────────────────────────────────────────────────
export const metadata: Metadata = {
  title: {
    template: '%s | MindForge',
    default: 'MindForge — Forge your knowledge',
  },
  description: 'AI-powered learning platform. Curriculum, spaced repetition, quizzes, and projects — end to end.',
  applicationName: 'MindForge',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'),

  // Apple PWA — standalone mode with translucent status bar so our
  // app-header colour shows through (pairs with viewport-fit: cover)
  appleWebApp: {
    capable: true,
    title: 'MindForge',
    statusBarStyle: 'black-translucent',
  },

  // Prevent iOS from auto-linking phone numbers / addresses in content
  formatDetection: {
    telephone: false,
    email: false,
    address: false,
  },

  openGraph: {
    type: 'website',
    siteName: 'MindForge',
    title: 'MindForge',
    description: 'AI-powered learning platform — forge your knowledge end to end.',
  },

  robots: {
    index: process.env.NODE_ENV === 'production',
    follow: process.env.NODE_ENV === 'production',
  },
}

// ── Viewport ───────────────────────────────────────────────────────────────
// viewport-fit=cover is REQUIRED for env(safe-area-inset-*) to work.
// Without it all safe area utility classes (.safe-top, .safe-bottom etc.)
// produce zero padding and content appears behind the camera notch.
//
// themeColor switches between light (amber-700) and dark (amber-400)
// matching --primary in globals.css.
export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  minimumScale: 1,
  viewportFit: 'cover',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#B45309' }, // amber-700
    { media: '(prefers-color-scheme: dark)',  color: '#F59E0B' }, // amber-400
  ],
}

// ── Root layout ────────────────────────────────────────────────────────────
// Async: resolves org features + user entitlements ONCE here and feeds them to
// FeatureFlagProvider, so the whole tree gates without any per-component fetch.
// Reading cookies in getFeatureConfig opts the app into dynamic rendering — by
// design, since feature access is per-user.
export default async function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const [{ orgFeatures, entitlements, lockedInfo }, permissions] = await Promise.all([
    getFeatureConfig(),
    getMyPermissions(),
  ])

  return (
    <html
      suppressHydrationWarning
      className={`${plusJakarta.variable} ${jetbrainsMono.variable}`}
      lang="en"
    >
      <body>
        <ThemeProvider
          disableTransitionOnChange // prevents flash-of-wrong-theme on initial load
          enableSystem
          attribute="class"
          defaultTheme="system"
        >
          <NuqsAdapter>
            <FeatureFlagProvider
              entitlements={entitlements}
              lockedInfo={lockedInfo}
              orgFeatures={orgFeatures}
            >
              <PermissionProvider permissions={permissions}>
                {children}
              </PermissionProvider>
            </FeatureFlagProvider>
          </NuqsAdapter>
          <Toaster />
        </ThemeProvider>
      </body>
    </html>
  )
}
