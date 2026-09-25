import type { Metadata, Viewport } from 'next'
import { Suspense } from 'react'
import { Plus_Jakarta_Sans, JetBrains_Mono, Gochi_Hand } from 'next/font/google'
import { ThemeProvider } from 'next-themes'
import { NuqsAdapter } from 'nuqs/adapters/next'
import { FeatureFlagProvider } from '@/lib/feature-context'
import { TerminologyProvider } from '@/lib/terminology-context'
import { CurrencyProvider } from '@/lib/currency-context'
import { BrandingProvider } from '@/lib/branding-context'
import { PermissionProvider } from '@/lib/auth/permissions'
import { LabProvisioningProvider } from '@/lib/labs/provisioning-context'
import { getFeatureConfig } from '@/lib/server/features'
import { getMyPermissions } from '@/lib/server/permissions'
import { getActiveLabSession } from '@/lib/server/labs'
import { getCurrentOrgType, getCurrentOrgBranding } from '@/lib/orgs/server'
import { getPaymentsCurrency } from '@/lib/server/payments'
import { Toaster } from '@/components/ui/sonner'
import { AppMotionConfig } from '@/components/shared/app-motion-config'
import { LabProvisioningWatcher } from '@/components/labs/lab-provisioning-watcher'
import { ActiveLabsBar } from '@/components/labs/active-labs-bar'
import Loading from './loading'
import './globals.css'

// ── Fonts ──────────────────────────────────────────────────────────────────
// These set the CSS variables referenced in globals.css @theme inline:
//   --font-sans: var(--font-plus-jakarta)
//   --font-mono: var(--font-jetbrains-mono)
const plusJakarta = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-plus-jakarta',
  display: 'swap',
  // Only the weights actually used (font-normal/medium/semibold/bold) — each
  // extra weight is another font file on every first load.
  weight: ['400', '500', '600', '700'],
})

const jetbrainsMono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-jetbrains-mono',
  display: 'swap',
  weight: ['400', '500'],
})

// Focus Wall sticky notes only — handwritten feel for personal note text,
// referenced in globals.css as --font-handwritten / Tailwind's `font-handwritten`.
const gochiHand = Gochi_Hand({
  subsets: ['latin'],
  variable: '--font-gochi-hand',
  display: 'swap',
  weight: '400',
  // Only the Focus Wall uses it — don't preload it on every page.
  preload: false,
})

// ── Metadata ───────────────────────────────────────────────────────────────
// Async so the title template/siteName can pick up the current org's
// white-label branding — a plain `export const metadata` object can't read
// cookies, so it could never vary per org. Every page below sets a plain
// `title: "X"` string (no manual "— MindForge" suffix) and relies on the
// `%s | {name}` template here to append the brand once, in one place.
export async function generateMetadata(): Promise<Metadata> {
  const branding = await getCurrentOrgBranding()
  const name = branding.name || 'MindForge'
  return {
    title: {
      template: `%s | ${name}`,
      default: `${name} — Forge your knowledge`,
    },
    description: 'AI-powered learning platform. Curriculum, spaced repetition, quizzes, and projects — end to end.',
    applicationName: name,
    metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL ?? 'http://localhost:3000'),

    // Apple PWA — standalone mode with translucent status bar so our
    // app-header colour shows through (pairs with viewport-fit: cover)
    appleWebApp: {
      capable: true,
      title: name,
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
      siteName: name,
      title: name,
      description: 'AI-powered learning platform — forge your knowledge end to end.',
    },

    robots: {
      index: process.env.NODE_ENV === 'production',
      follow: process.env.NODE_ENV === 'production',
    },
  }
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
// The layout itself stays synchronous so <html>/<body> and a skeleton flush on
// the first byte. The per-user reads (one /api/me/bootstrap call + currency)
// live in AppProviders behind Suspense: previously they were awaited here, and
// app/loading.tsx sits *inside* this layout, so a slow or cold backend left the
// browser on a blank tab with nothing streamed at all.
// Reading cookies in getFeatureConfig opts the app into dynamic rendering — by
// design, since feature access is per-user.
export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html
      suppressHydrationWarning
      className={`${plusJakarta.variable} ${jetbrainsMono.variable} ${gochiHand.variable}`}
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
            <Suspense fallback={<Loading />}>
              <AppProviders>{children}</AppProviders>
            </Suspense>
          </NuqsAdapter>
          <Toaster />
        </ThemeProvider>
      </body>
    </html>
  )
}

// Resolves org features + user entitlements ONCE and feeds them to the context
// providers, so the whole tree gates without any per-component fetch.
async function AppProviders({ children }: { children: React.ReactNode }) {
  const [{ orgFeatures, entitlements, lockedInfo }, permissions, activeLabSession, orgType, currency, branding] = await Promise.all([
    getFeatureConfig(),
    getMyPermissions(),
    getActiveLabSession(),
    getCurrentOrgType(),
    getPaymentsCurrency(),
    getCurrentOrgBranding(),
  ])

  return (
    <FeatureFlagProvider
      entitlements={entitlements}
      lockedInfo={lockedInfo}
      orgFeatures={orgFeatures}
    >
      <TerminologyProvider orgType={orgType}>
        <BrandingProvider logoUrl={branding.logo_url} name={branding.name}>
          <CurrencyProvider currency={currency}>
            <PermissionProvider permissions={permissions}>
              <LabProvisioningProvider initialSession={activeLabSession}>
                <AppMotionConfig>
                  {children}
                  <LabProvisioningWatcher />
                  <ActiveLabsBar />
                </AppMotionConfig>
              </LabProvisioningProvider>
            </PermissionProvider>
          </CurrencyProvider>
        </BrandingProvider>
      </TerminologyProvider>
    </FeatureFlagProvider>
  )
}
