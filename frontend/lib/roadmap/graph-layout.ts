import type { RoadmapMilestone, RoadmapModule, RoadmapPhase } from "@/lib/server/roadmap";

export interface ModuleBox {
  module: RoadmapModule;
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface MilestoneBox {
  milestone: RoadmapMilestone;
  x: number;
  y: number;
  width: number;
  height: number;
  modules: ModuleBox[];
}

export interface PhaseBox {
  phase: RoadmapPhase;
  x: number;
  y: number;
  width: number;
  height: number;
  milestones: MilestoneBox[];
}

export interface Connector {
  id: string;
  path: string;
}

export interface RoadmapLayout {
  phases: PhaseBox[];
  connectors: Connector[];
  width: number;
  height: number;
}

const TRUNK_X = 20;
const TRUNK_W = 200;
const TRUNK_H = 56;
const GROUP_X = TRUNK_X + TRUNK_W + 90;
const GROUP_COLS = 2;
const MODULE_W = 150;
const MODULE_H = 44;
const MODULE_GAP = 10;
const GROUP_PADDING = 14;
const GROUP_HEADER = 32;
const GROUP_GAP_Y = 36;
const PHASE_GAP_Y = 70;
const MARGIN = 24;

function groupSize(moduleCount: number) {
  const rows = Math.max(Math.ceil(moduleCount / GROUP_COLS), 1);
  return {
    width: GROUP_PADDING * 2 + GROUP_COLS * MODULE_W + (GROUP_COLS - 1) * MODULE_GAP,
    height: GROUP_HEADER + GROUP_PADDING * 2 + rows * MODULE_H + (rows - 1) * MODULE_GAP,
  };
}

// Curved dashed connector from the right edge of `from` to the left edge of
// `to` — mirrors the hand-drawn bezier links roadmap.sh's SVGs use between a
// trunk topic and its branches.
function connectorPath(fromX: number, fromY: number, toX: number, toY: number): string {
  const midX = (fromX + toX) / 2;
  return `M ${fromX} ${fromY} C ${midX} ${fromY}, ${midX} ${toY}, ${toX} ${toY}`;
}

// Auto-layouts one radiating "trunk" per phase: a phase box on the left with
// milestone clusters stacked and vertically centered on it, each cluster a
// bordered group containing its modules in a 2-column grid — plain SVG
// shapes + dashed bezier connectors, the same technique roadmap.sh's own
// (hand-authored) SVGs use, just computed instead of hand-positioned.
export function buildRoadmapLayout(phases: RoadmapPhase[]): RoadmapLayout {
  const phaseBoxes: PhaseBox[] = [];
  const connectors: Connector[] = [];
  let phaseY = 0;
  let maxX = 0;

  for (const phase of phases) {
    const milestoneBoxes: MilestoneBox[] = [];
    const groupHeights = phase.milestones.map((m) => groupSize(m.modules.length).height);
    const stackHeight = groupHeights.reduce((sum, h) => sum + h, 0)
      + Math.max(phase.milestones.length - 1, 0) * GROUP_GAP_Y;

    const phaseBox: PhaseBox = {
      phase,
      x: TRUNK_X,
      y: phaseY + stackHeight / 2 - TRUNK_H / 2,
      width: TRUNK_W,
      height: TRUNK_H,
      milestones: milestoneBoxes,
    };

    let cursorY = phaseY;
    for (const milestone of phase.milestones) {
      const { width, height } = groupSize(milestone.modules.length);
      const moduleBoxes: ModuleBox[] = milestone.modules.map((mod, modIdx) => {
        const col = modIdx % GROUP_COLS;
        const row = Math.floor(modIdx / GROUP_COLS);
        return {
          module: mod,
          x: GROUP_X + GROUP_PADDING + col * (MODULE_W + MODULE_GAP),
          y: cursorY + GROUP_HEADER + GROUP_PADDING + row * (MODULE_H + MODULE_GAP),
          width: MODULE_W,
          height: MODULE_H,
        };
      });

      milestoneBoxes.push({ milestone, x: GROUP_X, y: cursorY, width, height, modules: moduleBoxes });
      connectors.push({
        id: `e-${phase.id}-${milestone.id}`,
        path: connectorPath(
          phaseBox.x + phaseBox.width,
          phaseBox.y + phaseBox.height / 2,
          GROUP_X,
          cursorY + height / 2,
        ),
      });

      maxX = Math.max(maxX, GROUP_X + width);
      cursorY += height + GROUP_GAP_Y;
    }

    phaseBoxes.push(phaseBox);
    phaseY += stackHeight + PHASE_GAP_Y;
  }

  return {
    phases: phaseBoxes,
    connectors,
    width: maxX + MARGIN,
    height: Math.max(phaseY - PHASE_GAP_Y, 0) + MARGIN,
  };
}
