// ponytail: exists only so server actions can `revalidatePath(ROUTES.SHEETS, "layout")`
// and refresh whichever /sheets/[slug] page is currently mounted, not just the list.
// Not a shared <main>/page-container wrapper: sheets/new and sheets/join/[slug] use
// the narrower page-container-sm, so each page under here sets its own container.
export default function SheetsLayout({ children }: { children: React.ReactNode }) {
  return children;
}
