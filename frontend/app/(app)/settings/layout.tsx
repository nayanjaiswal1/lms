import { SettingsMobileNav, SettingsDesktopNav } from './_components/settings-nav'

export default function SettingsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="page-container min-h-dvh">
      <div className="py-6 lg:py-10">
        <h1 className="text-2xl font-semibold text-foreground mb-6">Settings</h1>

        {/* Mobile tab row — hidden on lg+ */}
        <SettingsMobileNav />

        {/* Desktop two-column: sidebar + content */}
        <div className="lg:flex lg:gap-8">
          <SettingsDesktopNav />

          <main className="flex-1 min-w-0">
            {children}
          </main>
        </div>
      </div>
    </div>
  )
}
