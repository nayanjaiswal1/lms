import { FocusWallCanvas } from "@/components/focus-wall/focus-wall-canvas";
import { getMyFocusNotes } from "@/lib/server/focus-wall";

export const metadata = { title: "Focus Wall — MindForge" };

export default async function FocusWallPage() {
  const notes = await getMyFocusNotes();

  return (
    // Cancels .app-content's own padding so the wall runs edge-to-edge and
    // fills the full viewport height below the app header — a floating
    // canvas tool, unlike the padded/max-width reading pages elsewhere.
    // Mobile keeps its bottom padding (bottom-nav clearance); sm/lg cancel
    // it fully since .app-content's padding-bottom there just matches p-6/p-8.
    <main className="-mx-4 -mt-4 h-[calc(100dvh-var(--header-height)-5rem)] sm:-mx-6 sm:-my-6 sm:h-[calc(100dvh-var(--header-height))] lg:-mx-8 lg:-my-8 lg:h-[calc(100dvh-var(--header-height))]">
      <FocusWallCanvas initialNotes={notes} />
    </main>
  );
}
