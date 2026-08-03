// Polar-to-cartesian math for the daily habit wheel's SVG wedges. Plain
// functions, no React — shared by DailyHabitWheel for both the clickable
// wedge paths and the day-number labels around the rim.

// Rounded to 2 decimals — full float precision here caused a server/client
// hydration mismatch (SSR and the browser occasionally differ in the last
// couple of significant digits of Math.cos/sin), which is invisible at SVG
// scale but React still flags as an error. Rounding makes both renders emit
// the identical string.
function round(n: number): number {
  return Math.round(n * 100) / 100;
}

export function polarToCartesian(cx: number, cy: number, r: number, angleDeg: number): { x: number; y: number } {
  const rad = ((angleDeg - 90) * Math.PI) / 180;
  return { x: round(cx + r * Math.cos(rad)), y: round(cy + r * Math.sin(rad)) };
}

// A ring boundary drawn as an open arc (stroke only, no fill) spanning
// [startAngle, endAngle] — used instead of a full <circle> because the wheel
// has a pie-slice notch cut out on one side for habit-name labels, so ring
// boundaries can't be closed circles.
// The segment under day 1 (the width of `straightSpan`, starting at
// startAngle) is drawn as a flat chord instead of following the circle —
// that's the stretch a habit's leader line runs straight into, and the
// arc's natural curve away from the line read as a kink right at the join.
export function ringArcPath(
  cx: number,
  cy: number,
  r: number,
  startAngle: number,
  endAngle: number,
  straightSpan = 0,
): string {
  const p1 = polarToCartesian(cx, cy, r, startAngle);
  const p2 = polarToCartesian(cx, cy, r, endAngle);
  if (straightSpan <= 0) {
    const largeArc = endAngle - startAngle > 180 ? 1 : 0;
    return `M ${p1.x} ${p1.y} A ${r} ${r} 0 ${largeArc} 1 ${p2.x} ${p2.y}`;
  }
  const straightEnd = startAngle + straightSpan;
  const pMid = polarToCartesian(cx, cy, r, straightEnd);
  const largeArc = endAngle - straightEnd > 180 ? 1 : 0;
  return `M ${p1.x} ${p1.y} L ${pMid.x} ${pMid.y} A ${r} ${r} 0 ${largeArc} 1 ${p2.x} ${p2.y}`;
}


export function wedgePath(
  cx: number,
  cy: number,
  innerR: number,
  outerR: number,
  startAngle: number,
  endAngle: number,
  // Day 1 of each ring borders the notch, where the habit's leader line
  // attaches — a curved outer/inner edge reads as detached from that
  // straight line, so day 1 gets flat chords instead while every other
  // day keeps the true arc.
  straight = false,
): string {
  const p1 = polarToCartesian(cx, cy, outerR, endAngle);
  const p2 = polarToCartesian(cx, cy, outerR, startAngle);
  const p3 = polarToCartesian(cx, cy, innerR, startAngle);
  const p4 = polarToCartesian(cx, cy, innerR, endAngle);
  const largeArc = endAngle - startAngle > 180 ? 1 : 0;
  return [
    `M ${p1.x} ${p1.y}`,
    straight ? `L ${p2.x} ${p2.y}` : `A ${outerR} ${outerR} 0 ${largeArc} 0 ${p2.x} ${p2.y}`,
    `L ${p3.x} ${p3.y}`,
    straight ? `L ${p4.x} ${p4.y}` : `A ${innerR} ${innerR} 0 ${largeArc} 1 ${p4.x} ${p4.y}`,
    "Z",
  ].join(" ");
}
