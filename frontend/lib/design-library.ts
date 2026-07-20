import { convertToExcalidrawElements } from "@excalidraw/excalidraw";
import type { LibraryItem } from "@excalidraw/excalidraw/types";

// Pre-made, labeled system-design components for the whiteboard's Library
// panel — drag one onto the canvas the same way the reference product's
// "Client / Server / API Gateway / Load Balancer / DB / Cache / Queue /
// Message Queue / CDN" shelf works. Built via Excalidraw's own
// convertToExcalidrawElements skeleton helper rather than hand-authoring
// every element field (ids, seeds, versions, bound-text linkage, ...).
const SHAPES: { name: string; color: string }[] = [
  { name: "Client", color: "#1971c2" },
  { name: "Server", color: "#2f9e44" },
  { name: "API Gateway", color: "#e8590c" },
  { name: "Load Balancer", color: "#e8590c" },
  { name: "Database", color: "#9c36b5" },
  { name: "Cache", color: "#f08c00" },
  { name: "Queue", color: "#1098ad" },
  { name: "Message Queue", color: "#1098ad" },
  { name: "CDN", color: "#2f9e44" },
];

function buildLibraryItem(name: string, color: string, index: number): LibraryItem {
  const elements = convertToExcalidrawElements([
    {
      type: "rectangle",
      x: 0,
      y: index * 90,
      width: 160,
      height: 70,
      strokeColor: color,
      backgroundColor: color,
      fillStyle: "solid",
      strokeWidth: 2,
      roundness: { type: 3 },
      opacity: 15,
      label: {
        text: name,
        strokeColor: color,
        fontSize: 16,
        textAlign: "center",
        verticalAlign: "middle",
      },
    },
  ]);
  return {
    id: `system-design-${name.toLowerCase().replace(/\s+/g, "-")}`,
    status: "published",
    elements,
    created: Date.now() + index,
    name,
  };
}

export const SYSTEM_DESIGN_LIBRARY: LibraryItem[] = SHAPES.map((s, i) => buildLibraryItem(s.name, s.color, i));
