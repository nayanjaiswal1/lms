import { requireAnyPermission } from "@/lib/server/permissions";
import { ACCESS } from "@/lib/auth/permission-codes";
import { AlgoVisualizerPageContent } from "@/components/algo-visualizer/algo-visualizer-page-content";

export const metadata = { title: "Algorithm Visualizer" };

export default async function AlgoVisualizerPage() {
  await requireAnyPermission(ACCESS.PRACTICE);
  return <AlgoVisualizerPageContent />;
}
