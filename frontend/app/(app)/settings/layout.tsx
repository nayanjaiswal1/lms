import { SettingsMobileNav, SettingsDesktopNav } from './_components/settings-nav'

export default function SettingsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <div className="page-container min-h-dvh">
      <div className="py-6 lg:py-10">
        <header className="mb-6 space-y-1 lg:mb-8">
          <h1 className="page-title text-foreground">Settings</h1>
          <p className="text-sm text-muted-foreground">
            Manage your profile, sign-in security, privacy and connected tools.
          </p>
        </header>

        <SettingsMobileNav />

        <div className="lg:flex lg:items-start lg:gap-10">
          <SettingsDesktopNav />

          {/* Not <main>: the app shell already renders one around every page. */}
          <div className="min-w-0 flex-1">{children}</div>
        </div>
      </div>
    </div>
  )
}
