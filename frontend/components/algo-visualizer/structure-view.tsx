"use client";

import { AnimatePresence, motion } from "framer-motion";
import { ArrowLeft, ArrowRight } from "lucide-react";
import type { PrimitiveArrayValue } from "@/lib/algo-visualizer/core/pointer-detect";
import { cn } from "@/lib/utils";

// Matches globals.css --duration-normal / --ease-smooth.
const EASE_SMOOTH = [0.22, 1, 0.36, 1] as const;
const MAX_CELLS = 30;

interface StructureViewProps {
  name: string;
  kind: "stack" | "queue";
  values: PrimitiveArrayValue[];
}

const CELL_BASE =
  "flex h-10 w-12 shrink-0 items-center justify-center rounded-md border-2 border-border bg-card font-mono text-sm font-semibold text-foreground transition-colors duration-normal ease-smooth";
const CELL_ACTIVE = "border-primary bg-primary/10 text-primary";
const LABEL_CLASS = "flex items-center gap-1 whitespace-nowrap text-xs font-semibold text-primary";

export function StructureView({ name, kind, values }: StructureViewProps) {
  if (values.length > MAX_CELLS) {
    return <p className="font-mono text-xs text-muted-foreground">{name} ({values.length} items — too large to draw)</p>;
  }

  const rows = values.map((v, i) => {
    // "last" means TOP for a stack, REAR for a queue — same tail position either way.
    const isLast = i === values.length - 1;
    const isFront = i === 0;
    return (
      <motion.div
        animate={{ opacity: 1, scale: 1 }}
        className={cn("flex items-center gap-2", kind === "stack" && "justify-start")}
        exit={{ opacity: 0, scale: 0.6 }}
        initial={{ opacity: 0, scale: 0.6 }}
        key={i}
        transition={{ duration: 0.2, ease: EASE_SMOOTH }}
      >
        {kind === "queue" && isFront && (
          <span className={LABEL_CLASS}>
            FRONT <ArrowRight aria-hidden className="h-3 w-3" />
          </span>
        )}
        <div className={cn(CELL_BASE, kind === "stack" ? isLast && CELL_ACTIVE : (isFront || isLast) && CELL_ACTIVE)}>
          {String(v)}
        </div>
        {kind === "stack" && isLast && (
          <span className={LABEL_CLASS}>
            <ArrowLeft aria-hidden className="h-3 w-3" /> TOP
          </span>
        )}
        {kind === "queue" && isLast && values.length > 1 && (
          <span className={LABEL_CLASS}>
            <ArrowLeft aria-hidden className="h-3 w-3" /> REAR
          </span>
        )}
      </motion.div>
    );
  });

  return (
    <div className="flex flex-col items-center gap-2">
      <p className="font-mono text-xs uppercase tracking-wide text-muted-foreground">{name}</p>
      {values.length === 0 ? (
        <p className="font-mono text-xs text-muted-foreground">empty</p>
      ) : kind === "stack" ? (
        <div className="flex min-h-[3.5rem] flex-col-reverse items-start gap-1 rounded-b-md border-x-2 border-b-2 border-border p-2">
          <AnimatePresence initial={false}>{rows}</AnimatePresence>
        </div>
      ) : (
        <div className="flex items-center gap-1 rounded-md border-y-2 border-border p-2">
          <AnimatePresence initial={false}>{rows}</AnimatePresence>
        </div>
      )}
    </div>
  );
}
