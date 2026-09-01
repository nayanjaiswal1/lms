"use client";

import { Download } from "lucide-react";
import { Button } from "@/components/ui/button";

// Native browser "Save as PDF" print destination — same pattern as
// CertificateActions, no PDF library needed. journal-theme.css's
// .habit-print-page rule breaks each chart in HabitPrintExport onto its
// own page.
export function HabitExportButton() {
  return (
    <Button
      aria-label="Download or print charts as PDF"
      className="touch-target rounded-full border border-border bg-background text-foreground shadow-card transition-colors duration-fast ease-smooth hover:bg-accent"
      size="icon"
      title="Download / print (PDF)"
      variant="ghost"
      onClick={() => window.print()}
    >
      <Download aria-hidden className="h-5 w-5" />
    </Button>
  );
}
