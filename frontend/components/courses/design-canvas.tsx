"use client";

import "@excalidraw/excalidraw/index.css";
import dynamic from "next/dynamic";
import { useRef } from "react";
import { useTheme } from "next-themes";
import { Skeleton } from "@/components/ui/skeleton";
import { saveDesignSceneAction } from "@/lib/design-actions";
import type { DesignScene } from "@/lib/design";

const AUTOSAVE_DEBOUNCE_MS = 1500;

// @excalidraw/excalidraw is a heavy, canvas/DOM-dependent client library —
// dynamic-imported with ssr:false per the frontend heavy-dependency rule
// (same pattern as components/shared/code-editor.tsx for Monaco). This file
// is itself only reachable from a system_design module, so the CSS import
// above never ships on pages without one. (A dynamic import() of a bare CSS
// file inside the loader below fails under Turbopack — "not an ecmascript
// client module" — so it has to be a static import instead.)
const Excalidraw = dynamic(
  async () => {
    const [{ Excalidraw: Comp }, { SYSTEM_DESIGN_LIBRARY }] = await Promise.all([
      import("@excalidraw/excalidraw"),
      import("@/lib/design-library"),
    ]);
    return function BoundExcalidraw(props: React.ComponentProps<typeof Comp>) {
      return <Comp {...props} initialData={{ ...props.initialData, libraryItems: SYSTEM_DESIGN_LIBRARY }} />;
    };
  },
  { ssr: false, loading: () => <Skeleton className="h-full w-full" /> },
);

interface DesignCanvasProps {
  moduleId: string;
  attemptId: string;
  initialScene: DesignScene;
}

// Keyed by attemptId from the parent (module-system-design-client.tsx) so
// switching attempts remounts this component with fresh initialData instead
// of needing state to resync an already-mounted Excalidraw instance.
export function DesignCanvas({ moduleId, attemptId, initialScene }: DesignCanvasProps) {
  const { resolvedTheme } = useTheme();
  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const handleChange: React.ComponentProps<typeof Excalidraw>["onChange"] = (elements, appState, files) => {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      void saveDesignSceneAction(moduleId, attemptId, {
        elements,
        appState: { viewBackgroundColor: appState.viewBackgroundColor, zoom: appState.zoom, scrollX: appState.scrollX, scrollY: appState.scrollY },
        files,
      });
    }, AUTOSAVE_DEBOUNCE_MS);
  };

  return (
    <div className="h-full w-full [&_.excalidraw]:h-full">
      <Excalidraw
        initialData={{ elements: initialScene.elements, appState: initialScene.appState, scrollToContent: true }}
        theme={resolvedTheme === "dark" ? "dark" : "light"}
        onChange={handleChange}
      />
    </div>
  );
}
