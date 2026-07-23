// ponytail: exists only so server actions can `revalidatePath(ROUTES.SHEETS, "layout")`
// and refresh whichever /sheets/[slug] page is currently mounted, not just the list.
export default function SheetsLayout({ children }: { children: React.ReactNode }) {
  return children;
}
