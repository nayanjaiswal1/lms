import { FocusWallCanvas } from "@/components/focus-wall/focus-wall-canvas";
import { getMyFocusCategories, getMyFocusNotes } from "@/lib/server/focus-wall";
import { cn } from "@/lib/utils";

// Shared by both entry points to /focus-wall:
//  - app/(app)/focus-wall/page.tsx            — direct URL / refresh, normal sidebar shell
//  - app/(standalone)/{now,habits}/(.)focus-wall/page.tsx — intercepted from within the
//    standalone What Now?/Habits cluster, no sidebar, stays immersive
// `standalone` only changes the sizing math: the (app) shell contributes a
// mobile header + app-content padding that the (standalone) shell doesn't.
export async function FocusWallPageContent({ standalone = false }: { standalone?: boolean }) {
  const [notes, categories] = await Promise.all([getMyFocusNotes(), getMyFocusCategories()]);

  return (
    <main
      className={cn(
        "h-dvh",
        !standalone &&
          // Cancels .app-content's own padding so the wall runs edge-to-edge.
          // .app-header is `lg:hidden` (desktop uses the sidebar, no top bar),
          // so only mobile/sm subtract --header-height.
          "-mx-4 -mt-4 h-[calc(100dvh-var(--header-height)-5rem)] sm:-mx-6 sm:-my-6 sm:h-[calc(100dvh-var(--header-height))] lg:-mx-8 lg:-my-8 lg:h-dvh",
      )}
    >
      <FocusWallCanvas initialCategories={categories} initialNotes={notes} />
    </main>
  );
}
